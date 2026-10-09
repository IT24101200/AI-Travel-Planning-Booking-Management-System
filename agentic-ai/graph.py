"""
graph.py - LangGraph Multi-Agent Travel Planning Workflow
Wires the 4 agents together into an end-to-end stateful pipeline:
CoordinatorAgent -> ItineraryAgent -> BookingAgent -> ValidationAgent -> Retry / End.
"""

import sys
import os
import logging
from typing import TypedDict, Optional, Dict, Any
from langgraph.graph import StateGraph, START, END

# Ensure python can find local agent modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from agents.coordinator_agent import coordinator_plan, coordinator_retry_evaluator
from agents.itinerary_agent import itinerary_node
from agents.booking_agent import booking_node
from agents.validation_agent import validation_node
from feasibility_preflight import preflight_node
from destination_contract import normalize_requested_destinations
from logger import log_agent_step, BACKEND_URL, agent_service_headers
import httpx

logger = logging.getLogger("AgentService")


class TripPlanningState(TypedDict, total=False):
    trip_request_id: int
    customer_id: str
    destination_id: Optional[int]
    destination_name: str
    destination_ids: list[int]
    requested_destinations: list[dict[str, Any]]
    starter_location_id: Optional[int]
    raw_request_text: str
    revision_feedback: Optional[str]
    revision_request: Optional[Dict[str, Any]]
    preferred_activities: Optional[list[str]]
    start_date: str
    end_date: str
    traveller_count: int
    budget_ceiling: float
    currency: str
    airport_pickup: bool
    airport_code: str
    airport_arrival_time: str
    retry_count: int
    status: str
    trip_days: int
    plan_summary: Dict[str, Any]
    target_budgets: Dict[str, Any]
    preflight: Dict[str, Any]
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


def after_preflight(state: TripPlanningState) -> str:
    """Skip itinerary/LLM work when a deterministic request check fails."""
    return "evaluator" if state.get("status") == "PreflightFailed" else "itinerary"


def build_travel_planning_graph():
    """Builds and compiles the 4-agent LangGraph."""
    workflow = StateGraph(TripPlanningState)

    # Register the 4 agent nodes, deterministic preflight, and evaluation node.
    workflow.add_node("coordinator", lambda state: _run_logged_node("CoordinatorAgent", coordinator_plan, state))
    workflow.add_node("preflight", lambda state: _run_logged_node("CoordinatorAgent", preflight_node, state))
    workflow.add_node("itinerary", lambda state: _run_logged_node("ItineraryAgent", itinerary_node, state))
    workflow.add_node("booking", lambda state: _run_logged_node("BookingAgent", booking_node, state))
    workflow.add_node("validation", lambda state: _run_logged_node("ValidationAgent", validation_node, state))
    workflow.add_node("evaluator", lambda state: _run_logged_node("CoordinatorEvaluator", coordinator_retry_evaluator, state))

    # Linear execution flow
    workflow.add_edge(START, "coordinator")
    workflow.add_edge("coordinator", "preflight")
    workflow.add_conditional_edges(
        "preflight",
        after_preflight,
        {"itinerary": "itinerary", "evaluator": "evaluator"},
    )
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


def _run_logged_node(agent_name: str, node, state: TripPlanningState) -> dict:
    trip_id = state.get("trip_request_id", 0)
    logger.info("%s started for TripRequest #%s", agent_name, trip_id)
    try:
        result = node(state)
        logger.info(
            "%s completed for TripRequest #%s with status=%s",
            agent_name,
            trip_id,
            result.get("status", "unknown"),
        )
        return result
    except Exception:
        logger.exception("%s failed for TripRequest #%s", agent_name, trip_id)
        log_agent_step(
            trip_request_id=trip_id,
            agent_name=agent_name,
            step_name="AgentFailure",
            input_data={
                key: value
                for key, value in state.items()
                if key not in {"access_token", "auth_token", "authorization"}
            },
            output_data={
                "message": "The AI planning stage failed.",
                "error_code": "AGENT_STAGE_FAILURE",
            },
            status="Failed",
        )
        raise


# Pre-compile the graph for efficient reuse
travel_app = build_travel_planning_graph()


def sync_result_to_backend(trip_id: int, final_status: str, plan_json: dict, retry_count: int, failure_reason: str = None) -> bool:
    """
    Sends the finished plan and final status back to ASP.NET Core backend.
    """
    if not trip_id:
        return False

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
        logger.info("Final callback started for TripRequest #%s", trip_id)
        with httpx.Client(timeout=httpx.Timeout(10.0, connect=3.0)) as client:
            response = client.patch(url, json=payload, headers=agent_service_headers())
            if response.is_success:
                logger.info("Final callback completed for TripRequest #%s: HTTP %s", trip_id, response.status_code)
                return True
            logger.warning("Final callback rejected for TripRequest #%s: HTTP %s", trip_id, response.status_code)
    except Exception as e:
        logger.exception("Final callback failed for TripRequest #%s: %s", trip_id, e)
    return False


def run_travel_planning_pipeline(initial_data: dict) -> dict:
    """
    Executes the multi-agent graph with the given initial trip request payload.
    """
    trip_id = initial_data.get("trip_request_id", 0)
    logger.info("Pipeline started for TripRequest #%s", trip_id)

    # Never persist credentials in AgentLog input snapshots.
    safe_initial_data = {
        key: value
        for key, value in initial_data.items()
        if key not in {"access_token", "auth_token", "authorization"}
    }

    # Normalize once at the graph boundary so every downstream node receives
    # the same ordered, structured destination list.
    requested_destinations = normalize_requested_destinations(safe_initial_data)
    if requested_destinations:
        safe_initial_data["requested_destinations"] = requested_destinations
        safe_initial_data["destination_ids"] = [
            destination["destination_id"] for destination in requested_destinations
        ]

    # Audit log starting of pipeline
    log_agent_step(
        trip_request_id=trip_id,
        agent_name="CoordinatorAgent",
        step_name="InitializePipeline",
        input_data=safe_initial_data,
        output_data={"message": "Multi-agent planning workflow started"},
        status="Started"
    )

    # Execute graph
    try:
        final_state = travel_app.invoke(safe_initial_data)
    except Exception:
        logger.exception("Pipeline failed for TripRequest #%s", trip_id)
        failure_reason = "The AI planning pipeline failed before completion."
        failed_state = {
            "status": "Failed",
            "retry_count": initial_data.get("retry_count", 0),
            "plan_json": {"revision_request": initial_data["revision_request"]} if initial_data.get("revision_request") else {},
            "failure_reason": failure_reason,
        }
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="Pipeline",
            step_name="PipelineFailure",
            input_data=safe_initial_data,
            output_data={
                "message": failure_reason,
                "error_code": "PIPELINE_FAILURE",
            },
            status="Failed",
        )
        sync_result_to_backend(
            trip_id=trip_id,
            final_status="Failed",
            plan_json=failed_state["plan_json"],
            retry_count=failed_state["retry_count"],
            failure_reason=failure_reason,
        )
        return failed_state

    # Determine final state values
    final_status = final_state.get("status", "Planned")
    plan_json = final_state.get("plan_json") or {}
    if initial_data.get("revision_request"):
        plan_json["revision_request"] = initial_data["revision_request"]
    final_state["plan_json"] = plan_json
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

    logger.info("Pipeline completed for TripRequest #%s with status=%s", trip_id, final_status)

    return final_state
