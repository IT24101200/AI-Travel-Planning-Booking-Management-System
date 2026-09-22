"""
graph.py - LangGraph Multi-Agent Travel Planning Workflow
Wires the 4 agents together into an end-to-end stateful pipeline:
CoordinatorAgent -> ItineraryAgent -> BookingAgent -> ValidationAgent -> Retry / End.
"""

import sys
import os
from typing import TypedDict, Optional, Dict, Any
from langgraph.graph import StateGraph, START, END

# Ensure python can find local agent modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from agents.coordinator_agent import coordinator_plan, coordinator_retry_evaluator

# Downstream agent hooks (Owned and developed by Students B, C, and D in their respective branches)
# Fallback to pass-through nodes when downstream agents are unmerged or empty
try:
    from agents.itinerary_agent import itinerary_node
except (ImportError, AttributeError):
    def itinerary_node(state: dict) -> dict:
        """Placeholder pass-through until Student B merges itinerary_agent.py."""
        return {"itinerary": state.get("itinerary", {})}

try:
    from agents.booking_agent import booking_node
except (ImportError, AttributeError):
    def booking_node(state: dict) -> dict:
        """Placeholder pass-through until Student C merges booking_agent.py."""
        return {"booking_details": state.get("booking_details", {})}

try:
    from agents.validation_agent import validation_node
except (ImportError, AttributeError):
    def validation_node(state: dict) -> dict:
        """Placeholder pass-through until Student D merges validation_agent.py."""
        return {
            "validation_result": {"is_valid": True},
            "plan_json": state.get("plan_summary", {})
        }

from logger import log_agent_step, BACKEND_URL
import httpx


class TripPlanningState(TypedDict, total=False):
    trip_request_id: int
    customer_id: str
    destination_name: str
    raw_request_text: str
    start_date: str
    end_date: str
    traveller_count: int
    budget_ceiling: float
    currency: str
    retry_count: int
    status: str
    trip_days: int
    plan_summary: Dict[str, Any]
    target_budgets: Dict[str, Any]
    itinerary: Dict[str, Any]
    booking_details: Dict[str, Any]
    validation_result: Dict[str, Any]
    plan_json: Dict[str, Any]
    failure_reason: Optional[str]
    next_action: str


def should_retry(state: TripPlanningState) -> str:
    """Conditional routing function after evaluation."""
    action = state.get("next_action", "complete")
    if action == "retry":
        return "coordinator"
    return END


def build_travel_planning_graph():
    """Builds and compiles the 4-agent LangGraph."""
    workflow = StateGraph(TripPlanningState)

    # Register the 4 agent nodes + 1 evaluation node
    workflow.add_node("coordinator", coordinator_plan)
    workflow.add_node("itinerary", itinerary_node)
    workflow.add_node("booking", booking_node)
    workflow.add_node("validation", validation_node)
    workflow.add_node("evaluator", coordinator_retry_evaluator)

    # Linear execution flow
    workflow.add_edge(START, "coordinator")
    workflow.add_edge("coordinator", "itinerary")
    workflow.add_edge("itinerary", "booking")
    workflow.add_edge("booking", "validation")
    workflow.add_edge("validation", "evaluator")

    # Conditional branching: retry back to coordinator or finish
    workflow.add_conditional_edges(
        "evaluator",
        should_retry,
        {
            "coordinator": "coordinator",
            END: END
        }
    )

    return workflow.compile()


# Pre-compile the graph for efficient reuse
travel_app = build_travel_planning_graph()


def sync_result_to_backend(trip_id: int, final_status: str, plan_json: dict, retry_count: int, failure_reason: str = None):
    """
    Sends the finished plan and final status back to ASP.NET Core backend.
    """
    if not trip_id:
        return

    # Map state status to TripRequestStatus enum
    # Pending, Planning, Planned, Failed, Cancelled, AwaitingApproval, Approved, Rejected
    backend_status = "AwaitingApproval" if final_status == "AwaitingApproval" else (
        "Failed" if final_status == "Failed" else "Planned"
    )

    payload = {
        "status": backend_status,
        "planJson": plan_json,
        "retryCount": retry_count,
        "failureReason": failure_reason
    }

    try:
        url = f"{BACKEND_URL}/api/triprequest/{trip_id}/agent-update"
        with httpx.Client(timeout=httpx.Timeout(1.5, connect=0.5)) as client:
            client.patch(url, json=payload)
    except Exception as e:
        print(f"[Warning] Could not push final plan to backend API: {e}")


def run_travel_planning_pipeline(initial_data: dict) -> dict:
    """
    Executes the multi-agent graph with the given initial trip request payload.
    """
    trip_id = initial_data.get("trip_request_id", 0)

    # Audit log starting of pipeline
    log_agent_step(
        trip_request_id=trip_id,
        agent_name="CoordinatorAgent",
        step_name="InitializePipeline",
        input_data=initial_data,
        output_data={"message": "Multi-agent planning workflow started"},
        status="Started"
    )

    # Execute graph
    final_state = travel_app.invoke(initial_data)

    # Determine final state values
    final_status = final_state.get("status", "Planned")
    plan_json = final_state.get("plan_json")
    retries = final_state.get("retry_count", 0)
    failure_reason = final_state.get("failure_reason")

    # Sync back to backend DB
    sync_result_to_backend(
        trip_id=trip_id,
        final_status=final_status,
        plan_json=plan_json,
        retry_count=retries,
        failure_reason=failure_reason
    )

    return final_state
