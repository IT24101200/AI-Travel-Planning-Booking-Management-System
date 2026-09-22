"""
coordinator_agent.py - Student A's Core Planning & Routing Agent
This agent oversees the trip planning lifecycle:
1. Decomposes raw customer requests into structured trip goals.
2. Allocates budget across activities, hotels, and transportation.
3. Coordinates downstream specialist agents (Itinerary, Booking, Validation).
4. Handles retry logic when budget constraints are exceeded.
"""

import os
import json
import logging
from datetime import datetime
from dotenv import load_dotenv

# Shared audit logger
from logger import log_agent_step

load_dotenv()
logger = logging.getLogger("CoordinatorAgent")

# Retrieve Gemini API key if present
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()


def calculate_days(start_date_str: str, end_date_str: str) -> int:
    """Helper to calculate total trip days from ISO date strings."""
    try:
        d1 = datetime.fromisoformat(start_date_str.replace("Z", ""))
        d2 = datetime.fromisoformat(end_date_str.replace("Z", ""))
        days = (d2.date() - d1.date()).days
        return max(1, days)
    except Exception:
        return 3  # Default fallback days


def call_gemini_for_planning(prompt: str) -> str:
    """
    Calls Google Gemini API to generate intelligent trip decomposition.
    Falls back gracefully if the API key is not configured or an error occurs.
    """
    if not GEMINI_API_KEY:
        return None

    try:
        import google.generativeai as genai
        genai.configure(api_key=GEMINI_API_KEY)
        
        # Use gemini-1.5-flash for fast and cost-effective planning
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)
        if response and response.text:
            return response.text.strip()
    except Exception as e:
        logger.warning(f"Gemini API call failed, using rule-based planning fallback: {e}")

    return None


def coordinator_plan(state: dict) -> dict:
    """
    Coordinator Agent Node:
    Decomposes the customer request and sets target budgets.
    """
    trip_id = state.get("trip_request_id", 0)
    customer_id = state.get("customer_id", "Unknown")
    raw_text = state.get("raw_request_text", "")
    dest_name = state.get("destination_name") or "Selected Destination"
    start_date = state.get("start_date", "")
    end_date = state.get("end_date", "")
    travellers = state.get("traveller_count", 1)
    budget = float(state.get("budget_ceiling", 1000.0))
    currency = state.get("currency", "USD")
    retry_count = state.get("retry_count", 0)

    days = calculate_days(start_date, end_date)

    # 1. Budget Breakdown allocation rules (Spec Section 9)
    # If this is a retry run, apply an economy adjustment (-15%)
    discount_factor = 0.85 if retry_count > 0 else 1.0
    effective_budget = budget * discount_factor

    tours_budget = round(effective_budget * 0.35, 2)
    hotels_budget = round(effective_budget * 0.45, 2)
    transport_budget = round(effective_budget * 0.15, 2)
    buffer_budget = round(effective_budget * 0.05, 2)

    # 2. Call Gemini for high-level trip theme and strategy
    prompt = f"""
    You are the Lead Travel Planning Coordinator AI.
    Analyze this customer trip request:
    - Destination: {dest_name}
    - Duration: {days} days ({start_date} to {end_date})
    - Travellers: {travellers}
    - Total Budget: {budget} {currency} (Target for activities/stay: {effective_budget} {currency})
    - Customer Notes: {raw_text}
    - Retry Attempt: {retry_count}

    Provide a concise JSON object with:
    {{
      "trip_theme": "Brief title or theme",
      "planning_strategy": "2-3 sentences explaining the strategy",
      "target_daily_budget": {round(effective_budget / days, 2)}
    }}
    Return ONLY valid JSON.
    """

    gemini_result = call_gemini_for_planning(prompt)
    strategy_info = {}
    if gemini_result:
        try:
            # Strip potential markdown formatting
            clean_json = gemini_result.replace("```json", "").replace("```", "").strip()
            strategy_info = json.loads(clean_json)
        except Exception:
            strategy_info = {
                "trip_theme": f"Custom Adventure in {dest_name}",
                "planning_strategy": gemini_result[:200]
            }

    if not strategy_info:
        strategy_info = {
            "trip_theme": f"Custom {days}-Day Getaway in {dest_name}",
            "planning_strategy": f"Allocated balanced budget for {travellers} traveller(s) across tours, lodging, and transport.",
            "target_daily_budget": round(effective_budget / days, 2)
        }

    plan_summary = {
        "destination": dest_name,
        "days": days,
        "travellers": travellers,
        "currency": currency,
        "total_budget": budget,
        "effective_target_budget": effective_budget,
        "budget_breakdown": {
            "tours_budget": tours_budget,
            "hotels_budget": hotels_budget,
            "transport_budget": transport_budget,
            "buffer": buffer_budget
        },
        "theme": strategy_info.get("trip_theme"),
        "strategy": strategy_info.get("planning_strategy"),
        "status": "InPlanning"
    }

    # Audit log this reasoning step
    log_agent_step(
        trip_request_id=trip_id,
        agent_name="CoordinatorAgent",
        step_name="DecomposeAndAllocateBudget",
        input_data={
            "raw_text": raw_text,
            "budget": budget,
            "currency": currency,
            "days": days,
            "retry_count": retry_count
        },
        output_data=plan_summary,
        status="Success"
    )

    # Return updated state
    return {
        "status": "InPlanning",
        "plan_summary": plan_summary,
        "target_budgets": plan_summary["budget_breakdown"],
        "trip_days": days
    }


def coordinator_retry_evaluator(state: dict) -> dict:
    """
    Evaluates whether to retry after a downstream validation failure.
    Rule from Spec §9 & STUDENT_A.md:
    - If total cost exceeded budget and retry_count == 0: adjust target and retry ONCE.
    - If retry_count >= 1: fail pipeline permanently.
    """
    trip_id = state.get("trip_request_id", 0)
    current_retries = state.get("retry_count", 0)
    validation = state.get("validation_result", {})
    is_valid = validation.get("is_valid", True)

    if is_valid:
        # All good, trip successfully validated!
        return {
            "status": "AwaitingApproval",
            "next_action": "complete"
        }

    if current_retries < 1:
        # Retry once with economy discount
        new_retry_count = current_retries + 1
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="CoordinatorAgent",
            step_name="TriggerRetryOptimization",
            input_data={"current_retry": current_retries, "validation_error": validation.get("error")},
            output_data={"decision": "Retry with budget tightening (-15%)", "new_retry_count": new_retry_count},
            status="Retrying"
        )
        return {
            "retry_count": new_retry_count,
            "status": "InPlanning",
            "next_action": "retry"
        }
    else:
        # Second attempt failed -> permanent failure
        failure_msg = validation.get("error", "Total package cost exceeded budget ceiling after retry optimization.")
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="CoordinatorAgent",
            step_name="TerminateTripPlanning",
            input_data={"retry_count": current_retries, "validation_error": failure_msg},
            output_data={"status": "Failed", "reason": failure_msg},
            status="Failed"
        )
        return {
            "status": "Failed",
            "failure_reason": failure_msg,
            "next_action": "fail"
        }
