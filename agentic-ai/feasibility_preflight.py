"""Cheap, deterministic checks that run before itinerary generation."""

from datetime import datetime


def _trip_days(start_date, end_date):
    try:
        start = datetime.fromisoformat(str(start_date).replace("Z", "+00:00")).date()
        end = datetime.fromisoformat(str(end_date).replace("Z", "+00:00")).date()
    except (TypeError, ValueError, OverflowError):
        return None
    return (end - start).days + 1


def run_preflight(state):
    """Return a safe result without querying inventory or invoking an LLM.

    This deliberately checks only facts that are independent of catalogue
    contents. Hotel, room, route, date, capacity, and availability feasibility
    remain fail-closed checks in BookingAgent and the final validator.
    """

    destinations = state.get("requested_destinations") or []
    trip_days = _trip_days(state.get("start_date"), state.get("end_date"))
    details = {
        "requested_destinations": len(destinations),
        "minimum_planner_days": 2,
        "max_driving_minutes": 600,
        "max_day_minutes": 720,
        "earliest_transfer_start": "06:00",
        "finish_by": "20:00",
    }
    if trip_days is None:
        return {
            "passed": False,
            "error_code": "INVALID_TRAVEL_DATES",
            "error": "Enter a valid start and end date for the trip.",
            "details": details,
        }
    details["requested_days"] = trip_days
    if trip_days < 1:
        return {
            "passed": False,
            "error_code": "INVALID_TRAVEL_DATES",
            "error": "The trip end date must be on or after the start date.",
            "details": details,
        }
    if trip_days < 2:
        return {
            "passed": False,
            "error_code": "TRIP_WINDOW_TOO_SHORT",
            "error": "The planner needs at least two travel days for overnight accommodation. Add a travel day or reduce the request.",
            "details": details,
        }
    if not destinations:
        return {
            "passed": False,
            "error_code": "DESTINATION_REQUIRED",
            "error": "Select at least one database-backed destination before planning.",
            "details": details,
        }
    try:
        traveller_count = int(state.get("traveller_count", 0) or 0)
    except (TypeError, ValueError):
        traveller_count = 0
    if traveller_count < 1:
        return {
            "passed": False,
            "error_code": "TRAVELLER_COUNT_INVALID",
            "error": "The number of travellers must be at least one.",
            "details": details,
        }
    return {
        "passed": True,
        "error_code": None,
        "error": None,
        "details": details,
    }


def preflight_node(state):
    result = run_preflight(state)
    trip_id = state.get("trip_request_id", 0)
    # Import lazily to keep this pure helper easy to test and avoid logger
    # initialization during module import.
    from logger import log_agent_step

    if result["passed"]:
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="CoordinatorAgent",
            step_name="PreflightFeasibilityPassed",
            step_type="Validation",
            output_data=result["details"],
            status="Success",
        )
        return {"trip_days": result["details"]["requested_days"], "preflight": result, "status": "InPlanning"}

    output = {"error_code": result["error_code"], "error": result["error"], **result["details"]}
    log_agent_step(
        trip_request_id=trip_id,
        agent_name="CoordinatorAgent",
        step_name="PreflightFeasibilityFailed",
        step_type="Validation",
        output_data=output,
        status="Failed",
    )
    return {
        "preflight": result,
        "status": "PreflightFailed",
        "failure_reason": result["error"],
        "validation_result": {
            "is_valid": False,
            "error_code": result["error_code"],
            "error": result["error"],
            "upstream_error_code": result["error_code"],
            "planning_diagnostics": result["details"],
        },
        "next_action": "fail",
    }
