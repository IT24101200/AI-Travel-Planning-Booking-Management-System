"""Build a day-by-day itinerary with tours returned by the search tool.

This module only defines the itinerary-building logic. It does not call the
function automatically, so importing the file will not create an itinerary.
"""

import json
from copy import deepcopy
from logger import log_agent_step
import os

from dotenv import load_dotenv

# The tools directory is next to the agents directory. When the agentic-ai
# directory is the Python working directory, this imports tools/search_tours.py.
from tools.search_tours import search_tours, unique_tours
from route_planning import grouped_itinerary, RoutePlanningError
from destination_contract import (
    DestinationContractError,
    normalize_requested_destinations,
    validate_destination_coverage,
)


# Read variables from a local .env file (if one exists) into the environment.
load_dotenv()

def _get_tour_value(tour, *possible_names):
    """Return a tour field while allowing common API naming variations."""
    for name in possible_names:
        if name in tour:
            return tour[name]
    return None


def _remove_markdown_fences(text):
    """Remove optional ```json ... ``` wrappers from a Gemini response."""
    cleaned = text.strip()

    if cleaned.startswith("```"):
        # Remove the first fence line, which may be either ``` or ```json.
        first_newline = cleaned.find("\n")
        if first_newline != -1:
            cleaned = cleaned[first_newline + 1 :]

        # Remove the closing fence if Gemini included one.
        if cleaned.rstrip().endswith("```"):
            cleaned = cleaned.rstrip()[:-3]

    return cleaned.strip()


def validate_itinerary(result, trip_request, available_tours):
    """Check a generated itinerary using deterministic Python rules.

    The function returns two values as a tuple: a Boolean that says whether
    the itinerary is valid, and a list containing any validation errors.
    """
    errors = []

    # Build a lookup table so each scheduled tour ID can be checked quickly.
    tours_by_id = {tour.get("id"): tour for tour in available_tours}
    requested_destinations = normalize_requested_destinations(trip_request)

    # The total cost is calculated from every scheduled item's price below.
    total_cost = 0.0
    traveller_count = trip_request["traveller_count"]
    scheduled_tour_ids = set()

    for day in result.get("schedule", []):
        day_number = day.get("day_number")
        items = day.get("items", [])

        # Rule 4: A day may contain at most two scheduled tours.
        if len(items) > 2:
            errors.append(
                f"Day {day_number} has too many tours scheduled ({len(items)})"
            )

        for item in items:
            tour_id = item.get("tour_id")
            tour_key = str(tour_id)
            if tour_key in scheduled_tour_ids:
                errors.append(f"Tour ID {tour_id} is scheduled more than once")
            scheduled_tour_ids.add(tour_key)
            matching_tour = tours_by_id.get(tour_id)

            # Rule 1: Every tour must exist in the search results and be Active.
            if (
                matching_tour is None
                or str(matching_tour.get("status", "")).lower() != "active"
            ):
                errors.append(
                    f"Tour ID {tour_id} is not active or does not exist"
                )

            if matching_tour is not None:
                item_destination_id = item.get("destination_id") or matching_tour.get("destination_id")
                if item_destination_id is not None:
                    try:
                        if int(item_destination_id) not in {
                            destination["destination_id"] for destination in requested_destinations
                        }:
                            errors.append(
                                f"Tour ID {tour_id} belongs to an unrequested destination {item_destination_id}"
                            )
                    except (TypeError, ValueError):
                        errors.append(f"Tour ID {tour_id} has an invalid destination ID")

            # Rule 2: Tour prices are per traveller, so multiply each price by
            # the number of travellers before adding it to the trip total.
            total_cost += float(item.get("price", 0)) * traveller_count

        # Rule 3: Compare every pair of items scheduled on the same day.
        # Converting HH:MM:SS into seconds makes the times easy to compare.
        for first_index in range(len(items)):
            for second_index in range(first_index + 1, len(items)):
                first_item = items[first_index]
                second_item = items[second_index]

                first_start_parts = [
                    int(part) for part in first_item["start_time"].split(":")
                ]
                first_end_parts = [
                    int(part) for part in first_item["end_time"].split(":")
                ]
                second_start_parts = [
                    int(part) for part in second_item["start_time"].split(":")
                ]
                second_end_parts = [
                    int(part) for part in second_item["end_time"].split(":")
                ]

                first_start = (
                    first_start_parts[0] * 3600
                    + first_start_parts[1] * 60
                    + first_start_parts[2]
                )
                first_end = (
                    first_end_parts[0] * 3600
                    + first_end_parts[1] * 60
                    + first_end_parts[2]
                )
                second_start = (
                    second_start_parts[0] * 3600
                    + second_start_parts[1] * 60
                    + second_start_parts[2]
                )
                second_end = (
                    second_end_parts[0] * 3600
                    + second_end_parts[1] * 60
                    + second_end_parts[2]
                )

                # Two tours overlap when each starts before the other ends.
                # Equality is allowed, so one tour may start as another ends.
                if first_start < second_end and second_start < first_end:
                    errors.append(
                        f"Day {day_number} has overlapping items: "
                        f"{first_item.get('tour_name')} and "
                        f"{second_item.get('tour_name')}"
                    )

    # Finish Rule 2 by comparing the calculated total with the budget ceiling.
    budget_ceiling = float(trip_request["budget_ceiling"])
    if total_cost > budget_ceiling:
        errors.append(
            f"Total cost {total_cost} exceeds budget {budget_ceiling}"
        )

    errors.extend(
        validate_destination_coverage(result, requested_destinations, available_tours)
    )

    # An empty error list means every rule passed successfully.
    return (len(errors) == 0, errors)


def build_itinerary(trip_request):
    """Build a catalogue-backed itinerary using routes or a validated LLM draft.

    ``requested_destinations`` is an ordered list. Singular destination fields
    are accepted for backward compatibility and normalized to a one-item list.
    """

    try:
        requested_destinations = normalize_requested_destinations(
            trip_request, required=True
        )
    except DestinationContractError as error:
        return {
            "status": "ItineraryFailed",
            "error_code": error.code,
            "error": str(error),
        }

    # Search the backend separately for every requested destination. A single
    # broad catalogue query would allow one destination to silently dominate.
    candidate_tours = []
    destination_counts = {}
    try:
        for destination in requested_destinations:
            try:
                destination_tours = search_tours(
                    destination["destination_id"],
                    currency=trip_request.get("currency", "LKR"),
                )
            except TypeError:
                # Preserve compatibility with deterministic/offline test providers.
                destination_tours = search_tours(destination["destination_id"])

            destination_tours = destination_tours or []
            destination_counts[destination["destination_id"]] = len(destination_tours)
            if not destination_tours:
                if len(requested_destinations) == 1:
                    return {
                        "status": "ItineraryFailed",
                        "error_code": "NO_VALID_TOURS",
                        "error": "No database-backed tours are available for the requested destination.",
                    }
                return {
                    "status": "ItineraryFailed",
                    "error_code": "ZERO_TOUR_DESTINATION",
                    "error": (
                        f"No active tours are available for destination "
                        f"{destination['destination_name'] or destination['destination_id']}."
                    ),
                    "destination_id": destination["destination_id"],
                }

            for tour in destination_tours:
                # The backend catalogue is authoritative. Test/offline
                # providers that omit destination metadata inherit the query ID.
                normalized_tour = dict(tour)
                normalized_tour.setdefault("destination_id", destination["destination_id"])
                normalized_tour.setdefault(
                    "destination_name", destination["destination_name"]
                )
                candidate_tours.append(normalized_tour)
    except Exception as error:
        return {"error": f"Unable to search for tours: {error}"}

    try:
        log_agent_step(
            trip_request_id=trip_request["trip_request_id"],
            agent_name="ItineraryAgent",
            step_name="Searched tour catalog",
            step_type="ToolCall",
            tool_name="search_tours",
            input_data={
                "destination_ids": [
                    destination["destination_id"] for destination in requested_destinations
                ]
            },
            output_data={
                "tours_found": len(candidate_tours),
                "tours_by_destination": destination_counts,
            },
        )
    except Exception as error:
        print(f"Warning: Failed to log 'Searched tour catalog': {error}")

    # Inventory must always come from the backend. Never fabricate tour IDs.
    if not candidate_tours:
        return {
            "status": "ItineraryFailed",
            "error_code": "NO_VALID_TOURS",
            "error": "No active tours are available for the selected destination.",
        }

    req_curr = (trip_request.get("currency") or "LKR").upper()
    available_tours = []
    for tour in candidate_tours:
        raw_price = float(_get_tour_value(tour, "price", "Price") or 0.0)
        tour_curr = str(_get_tour_value(tour, "currency", "Currency") or "LKR").upper()
        # ASP.NET has already converted the catalogue response into the
        # requested transaction currency. Python never performs FX itself.
        norm_price = round(raw_price, 2)

        available_tours.append(
            {
                "id": _get_tour_value(tour, "id", "tour_id", "tourId", "Id"),
                "name": _get_tour_value(tour, "name", "tour_name", "tourName", "Name"),
                "price": norm_price,
                "currency": req_curr,
                "duration": _get_tour_value(
                    tour,
                    "duration",
                    "duration_hours",
                    "durationHours",
                    "Duration",
                ),
                "category": _get_tour_value(tour, "category", "Category"),
                "description": _get_tour_value(tour, "description", "Description"),
                "image_url": _get_tour_value(tour, "image_url", "imageUrl", "ImageUrl"),
                "destination_id": _get_tour_value(
                    tour, "destination_id", "destinationId", "DestinationId"
                ),
                "destination_name": _get_tour_value(
                    tour, "destination_name", "destinationName", "DestinationName"
                ),
                "default_start_time": _get_tour_value(
                    tour,
                    "default_start_time",
                    "defaultStartTime",
                    "DefaultStartTime",
                ),
                "status": _get_tour_value(tour, "status", "Status"),
                "latitude": _get_tour_value(tour, "latitude", "Latitude"),
                "longitude": _get_tour_value(tour, "longitude", "Longitude"),
            }
        )

    # Collapse repeated IDs and exact tour data before either planner runs.
    available_tours = unique_tours(available_tours)

    revision = trip_request.get("revision_request") or {}
    if revision:
        # Hotel/transport changes preserve the customer's selected journeys.
        # Refresh catalogue fields; the booking planner rebuilds dates and routes.
        baseline = deepcopy(revision.get("baseline_itinerary") or {})
        by_id = {tour["id"]: tour for tour in available_tours}
        total = 0.0
        for day in baseline.get("schedule", []):
            for item in day.get("items", []):
                tour = by_id.get(item.get("tour_id"))
                if not tour or str(tour.get("status")).lower() != "active":
                    return {"status": "ItineraryFailed", "error_code": "REVISION_TOUR_UNAVAILABLE",
                            "error": "A journey from your current itinerary is no longer available."}
                item.update({key: tour[key] for key in ("price", "currency", "duration", "latitude", "longitude", "destination_id", "destination_name")})
                item["tour_name"] = tour["name"]
                total += tour["price"] * trip_request["traveller_count"]
        baseline["total_estimated_cost"] = round(total, 2)
        return baseline

    if len(requested_destinations) > 1 or trip_request.get("airport_pickup") or all(t.get("latitude") is not None for t in available_tours):
        try:
            result = grouped_itinerary(trip_request, available_tours, requested_destinations)
            log_agent_step(
                trip_request_id=trip_request["trip_request_id"], agent_name="ItineraryAgent",
                step_name="Planned geographic itinerary", step_type="Plan",
                reason="Preserve every destination and the chosen starter; use road travel times and the trip date window.",
                output_data=result,
            )
            return result
        except RoutePlanningError as error:
            return {"status": "ItineraryFailed", "error_code": error.code, "error": str(error)}

    # JSON formatting keeps the structured trip and tour data unambiguous in
    # the prompt. default=str safely represents date-like values if supplied.
    trip_json = json.dumps(trip_request, indent=2, default=str)
    tours_json = json.dumps(available_tours, indent=2, default=str)

    # Give Gemini both the available data and strict scheduling/output rules.
    prompt = f"""
You are an itinerary-planning agent. Create a day-by-day travel schedule.

TRIP DETAILS:
{trip_json}

AVAILABLE TOURS:
{tours_json}

Rules:
Never schedule the same tour ID more than once during the trip.
1. Use only tours whose status is Active (case-insensitive).
2. Include at least one tour from every requested destination. Do not silently
   drop a destination because another has more tours.
3. Preserve each tour's destination_id and destination_name in the output.
4. The total estimated cost must not exceed budget_ceiling. Calculate the
   total using each tour's price and traveller_count.
5. Schedule tours only on days from start_date through end_date, inclusive.
6. Put 1-2 tours on each used day and spread activities across the available
   days as evenly as practical.
7. Prefer tours matching preferred_activities when possible.
8. Use each tour's default start time. Calculate its end time from its
   duration.
9. Tours on the same day must never have overlapping start and end times.
10. Use only tour IDs, names, prices, durations, categories, destination IDs,
   destination names, and start times
   supplied in AVAILABLE TOURS. Do not invent tours or prices.
11. Return ONLY valid JSON. Do not include Markdown fences, explanations, or
   any text before or after the JSON.
12. Follow this exact output structure and use JSON numbers for numeric values:

{{
  "itinerary_id": null,
  "total_estimated_cost": 0.0,
  "currency": "{trip_request.get('currency', 'LKR')}",
  "schedule": [
    {{
      "day_number": 1,
      "items": [
        {{
          "tour_id": 1,
           "tour_name": "Example tour",
           "destination_id": 1,
           "destination_name": "Example destination",
          "start_time": "09:00:00",
          "end_time": "11:00:00",
          "price": 0.0
        }}
      ]
    }}
  ]
}}
""".strip()

    # Construct Gemini lazily so importing the shared graph never requires a key.
    api_key = (
        os.getenv("GOOGLE_API_KEY_ITINERARY")
        or os.getenv("GEMINI_API_KEY")
        or os.getenv("GOOGLE_API_KEY")
    )
    if not api_key:
        return {
            "status": "ConfigurationFailed",
            "error_code": "MISSING_ITINERARY_API_KEY",
            "error": "Itinerary Agent is not configured.",
        }

    parsed_result = None
    execution_mode = "llm_response"
    try:
        import httpx
        url = f"https://generativelanguage.googleapis.com/v1beta/interactions?key={api_key}"
        with httpx.Client(timeout=4.0) as client:
            resp = client.post(url, json={"model": "gemini-3.8-flash", "input": prompt})
            if resp.status_code == 200:
                data = resp.json()
                raw_text = data.get("output_text") or (data.get("outputs", [{}])[0].get("text") if "outputs" in data else None)
                if raw_text:
                    response_text = _remove_markdown_fences(raw_text)
                    parsed_result = json.loads(response_text)
            else:
                print(f"[Warning] Itinerary Agent Gemini API returned HTTP {resp.status_code}, using deterministic fallback.")
    except Exception as error:
        print(f"[Warning] Itinerary Agent Gemini call failed ({error}), using deterministic scheduling fallback.")

    if not isinstance(parsed_result, dict) or not parsed_result.get("schedule"):
        execution_mode = "deterministic_fallback"
        # Deterministic fallback: schedule available tours across trip days
        days_count = 3
        try:
            from datetime import datetime
            d1 = datetime.fromisoformat(str(trip_request["start_date"]).replace("Z", "+00:00")).date()
            d2 = datetime.fromisoformat(str(trip_request["end_date"]).replace("Z", "+00:00")).date()
            days_count = max(1, (d2 - d1).days + 1)
        except Exception:
            days_count = 3
        schedule = []
        total_cost = 0.0
        tour_indexes = {
            destination["destination_id"]: 0 for destination in requested_destinations
        }
        tours_by_destination = {
            destination["destination_id"]: [
                tour
                for tour in available_tours
                if tour.get("destination_id") == destination["destination_id"]
            ]
            for destination in requested_destinations
        }
        traveller_count = trip_request.get("traveller_count", 1)
        budget_limit = float(trip_request.get("budget_ceiling") or 1000000)

        for day_num in range(1, days_count + 1):
            day_items = []
            # Round-robin destinations so the first days cannot consume all
            # inventory from only the first selected location.
            destination = requested_destinations[(day_num - 1) % len(requested_destinations)]
            destination_id = destination["destination_id"]
            destination_tours = tours_by_destination[destination_id]
            destination_index = tour_indexes[destination_id]
            if destination_index < len(destination_tours):
                t = destination_tours[destination_index]
                price = float(t.get("price") or 0.0)
                item_cost = price * traveller_count
                if total_cost + item_cost <= budget_limit:
                    tour_indexes[destination_id] += 1
                    start = str(t.get("default_start_time") or "09:00:00")
                    if len(start) == 5:
                        start += ":00"
                    dur = float(t.get("duration") or 2.0)
                    try:
                        s_parts = [int(p) for p in start.split(":")]
                        end_hour = min(23, s_parts[0] + int(dur))
                        end = f"{end_hour:02d}:{s_parts[1]:02d}:00"
                    except Exception:
                        end = "12:00:00"
                    total_cost += item_cost
                    day_items.append({
                        "tour_id": t["id"],
                        "tour_name": t["name"],
                        "destination_id": destination_id,
                        "destination_name": destination["destination_name"],
                        "start_time": start,
                        "end_time": end,
                        "price": price
                    })
            schedule.append({
                "day_number": day_num,
                "items": day_items
            })
        has_items = any(len(day.get("items", [])) > 0 for day in schedule)
        if not has_items and len(available_tours) > 0:
            return {
                "error": "Validation failed",
                "details": [f"Budget ceiling {budget_limit} is too low to schedule any tours."]
            }
        parsed_result = {
            "itinerary_id": None,
            "total_estimated_cost": round(total_cost, 2),
            "currency": trip_request.get("currency", "LKR"),
            "schedule": schedule
        }

    # A model may omit metadata even though it selected a valid tour. Fill it
    # from the authoritative catalogue before deterministic validation.
    tours_by_id = {tour.get("id"): tour for tour in available_tours}
    for day in parsed_result.get("schedule", []):
        for item in day.get("items", []):
            tour = tours_by_id.get(item.get("tour_id"))
            if tour is not None:
                item.setdefault("destination_id", tour.get("destination_id"))
                item.setdefault("destination_name", tour.get("destination_name"))

    try:
        log_agent_step(
            trip_request_id=trip_request["trip_request_id"],
            agent_name="ItineraryAgent",
            step_name="Generated draft itinerary",
            step_type="Plan",
            output_data=parsed_result,
            reason="Schedule only catalogue tours, then validate dates, prices and overlaps.",
            execution_mode=execution_mode,
            model="gemini-3.8-flash" if execution_mode == "llm_response" else None,
        )
    except Exception as error:
        print(f"Warning: Failed to log 'Generated draft itinerary via Gemini': {error}")

    # Check Gemini's proposed schedule with plain Python before returning it.
    is_valid, validation_errors = validate_itinerary(
        parsed_result,
        trip_request,
        available_tours,
    )

    try:
        log_agent_step(
            trip_request_id=trip_request["trip_request_id"],
            agent_name="ItineraryAgent",
            step_name="Validated itinerary against business rules",
            step_type="Validation",
            output_data={"passed": is_valid, "errors": validation_errors},
            status="Success" if is_valid else "Failed",
        )
    except Exception as error:
        print(
            f"Warning: Failed to log 'Validated itinerary against business rules': {error}"
        )
    if not is_valid:
        return {"error": "Validation failed", "details": validation_errors}

    parsed_result["currency"] = trip_request.get("currency", "LKR")
    return parsed_result


def itinerary_node(state: dict) -> dict:
    """
    LangGraph adapter: maps the shared pipeline state into the input shape
    build_itinerary() expects, calls it, and merges the result back into state.
    """
    requested_destinations = normalize_requested_destinations(state)
    primary_destination = requested_destinations[0] if requested_destinations else {}
    trip_request = {
        "trip_request_id": state.get("trip_request_id"),
        "destination_id": state.get("destination_id") or primary_destination.get("destination_id"),
        "destination_name": state.get("destination_name") or primary_destination.get("destination_name"),
        "requested_destinations": requested_destinations,
        "starter_location_id": state.get("starter_location_id"),
        "start_date": state.get("start_date"),
        "end_date": state.get("end_date"),
        "traveller_count": state.get("traveller_count"),
        "budget_ceiling": state.get("target_budgets", {}).get("tours_budget")
        or state.get("budget_ceiling"),
        "preferred_activities": state.get("preferred_activities", []),
        "currency": state.get("currency", "LKR"),
        "airport_pickup": state.get("airport_pickup", False),
        "airport_code": state.get("airport_code", "CMB"),
        "airport_arrival_time": state.get("airport_arrival_time", "08:00"),
    }

    if not requested_destinations:
        return {
            **state,
            "itinerary": {
                "error_code": "DESTINATION_REQUIRED",
                "error": "A real database-backed destination is required before itinerary planning can start.",
            },
        }

    result = build_itinerary(trip_request)
    if not isinstance(result, dict):
        result = {
            "status": "ItineraryFailed",
            "error_code": "INVALID_ITINERARY_OUTPUT",
            "error": "Itinerary Agent returned an invalid result.",
        }
    if result.get("error"):
        log_agent_step(
            trip_request_id=state.get("trip_request_id", 0), agent_name="ItineraryAgent",
            step_name="Itinerary planning rejected", step_type="Outcome",
            output_data=result, status="Failed",
        )
        return {"itinerary": result, "status": result.get("status", "ItineraryFailed")}

    # Persistence is deliberately deferred until the final validation result.
    # ASP.NET owns the transaction and assigns the real ItineraryId.
    result["itinerary_id"] = None
    result["currency"] = state.get("currency", "LKR")
    result["total_cost"] = result["total_estimated_cost"]
    return {**state, "itinerary": result}


# Packages that may require manual installation:
# - python-dotenv
# - requests (used by tools/search_tours.py)
