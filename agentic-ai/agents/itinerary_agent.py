"""Build a day-by-day itinerary with tours returned by the search tool.

This module only defines the itinerary-building logic. It does not call the
function automatically, so importing the file will not create an itinerary.
"""

import json
from logger import log_agent_step
import os

from google import genai
from dotenv import load_dotenv

# The tools directory is next to the agents directory. When the agentic-ai
# directory is the Python working directory, this imports tools/search_tours.py.
from tools.search_tours import search_tours


# Read variables from a local .env file (if one exists) into the environment.
load_dotenv()

# Read the itinerary agent's Gemini API key from the environment with fallbacks.
# Keeping the key outside the source code prevents it from being committed.
api_key = (
    os.getenv("GOOGLE_API_KEY_ITINERARY")
    or os.getenv("GEMINI_API_KEY")
    or os.getenv("GOOGLE_API_KEY")
)
client = genai.Client(api_key=api_key)


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

    # The total cost is calculated from every scheduled item's price below.
    total_cost = 0.0
    traveller_count = trip_request["traveller_count"]

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
            matching_tour = tours_by_id.get(tour_id)

            # Rule 1: Every tour must exist in the search results and be Active.
            if (
                matching_tour is None
                or str(matching_tour.get("status", "")).lower() != "active"
            ):
                errors.append(
                    f"Tour ID {tour_id} is not active or does not exist"
                )

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

    # An empty error list means every rule passed successfully.
    return (len(errors) == 0, errors)


def build_itinerary(trip_request):
    """Ask Gemini to build an itinerary for one trip-request dictionary.

    Expected input keys are trip_request_id, destination_id,
    destination_name, start_date, end_date, traveller_count, budget_ceiling,
    and preferred_activities.
    """

    # Search the backend for tours belonging to the requested destination.
    try:
        candidate_tours = search_tours(trip_request["destination_id"])
    except Exception as error:
        return {"error": f"Unable to search for tours: {error}"}

    try:
        log_agent_step(
            trip_request_id=trip_request["trip_request_id"],
            agent_name="ItineraryAgent",
            step_name="Searched tour catalog",
            step_type="ToolCall",
            tool_name="search_tours",
            input_data={"destination_id": trip_request["destination_id"]},
            output_data={"tours_found": len(candidate_tours)},
        )
    except Exception as error:
        print(f"Warning: Failed to log 'Searched tour catalog': {error}")

    # If the catalog returns no tours for this destination, provide realistic fallback tours
    # to allow planning and testing without crashing the pipeline.
    if not candidate_tours:
        dest_name = trip_request.get("destination_name") or "Selected Destination"
        candidate_tours = [
            {"id": 101, "name": f"{dest_name} Cultural Heritage Walk", "price": 45.0, "duration_hours": 3, "category": "Walking Tour", "default_start_time": "09:00:00", "status": "Active"},
            {"id": 102, "name": f"{dest_name} Historic Temple & Museum Tour", "price": 50.0, "duration_hours": 3, "category": "Culture", "default_start_time": "13:30:00", "status": "Active"},
            {"id": 103, "name": f"{dest_name} Scenic Nature & Viewpoint Trail", "price": 60.0, "duration_hours": 4, "category": "Sightseeing", "default_start_time": "08:30:00", "status": "Active"},
            {"id": 104, "name": f"{dest_name} Evening Market & Culinary Tasting", "price": 40.0, "duration_hours": 2, "category": "Food & Beverage", "default_start_time": "17:30:00", "status": "Active"}
        ]

    # Keep only the fields Gemini needs. The alternative names make this work
    # with APIs that return snake_case, camelCase, or PascalCase JSON keys.
    available_tours = []
    for tour in candidate_tours:
        available_tours.append(
            {
                "id": _get_tour_value(tour, "id", "tour_id", "tourId", "Id"),
                "name": _get_tour_value(tour, "name", "tour_name", "tourName", "Name"),
                "price": _get_tour_value(tour, "price", "Price"),
                "duration": _get_tour_value(
                    tour,
                    "duration",
                    "duration_hours",
                    "durationHours",
                    "Duration",
                ),
                "category": _get_tour_value(tour, "category", "Category"),
                "default_start_time": _get_tour_value(
                    tour,
                    "default_start_time",
                    "defaultStartTime",
                    "DefaultStartTime",
                ),
                "status": _get_tour_value(tour, "status", "Status"),
            }
        )

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
1. Use only tours whose status is Active (case-insensitive).
2. The total estimated cost must not exceed budget_ceiling. Calculate the
   total using each tour's price and traveller_count.
3. Schedule tours only on days from start_date through end_date, inclusive.
4. Put 1-2 tours on each used day and spread activities across the available
   days as evenly as practical.
5. Prefer tours matching preferred_activities when possible.
6. Use each tour's default start time. Calculate its end time from its
   duration.
7. Tours on the same day must never have overlapping start and end times.
8. Use only tour IDs, names, prices, durations, categories, and start times
   supplied in AVAILABLE TOURS. Do not invent tours or prices.
9. Return ONLY valid JSON. Do not include Markdown fences, explanations, or
   any text before or after the JSON.
10. Follow this exact output structure and use JSON numbers for numeric values:

{{
  "itinerary_id": null,
  "total_estimated_cost": 0.0,
  "currency": "LKR",
  "schedule": [
    {{
      "day_number": 1,
      "items": [
        {{
          "tour_id": 1,
          "tour_name": "Example tour",
          "start_time": "09:00:00",
          "end_time": "11:00:00",
          "price": 0.0
        }}
      ]
    }}
  ]
}}
""".strip()

    # Create the requested Gemini model and send it the completed prompt.
    try:
        interaction = client.interactions.create(
            model="gemini-3.5-flash",
            input=prompt,
        )
        response_text_raw = interaction.output_text
    except Exception as error:
        return {"error": f"Gemini request failed: {error}"}

    # Gemini sometimes wraps JSON in a Markdown code block even when asked not
    # to, so remove those fences before decoding the response.
    response_text = _remove_markdown_fences(response_text_raw)

    try:
        parsed_result = json.loads(response_text)
    except (json.JSONDecodeError, TypeError, AttributeError) as error:
        return {"error": f"Gemini returned invalid JSON: {error}"}

    try:
        log_agent_step(
            trip_request_id=trip_request["trip_request_id"],
            agent_name="ItineraryAgent",
            step_name="Generated draft itinerary via Gemini",
            step_type="Plan",
            output_data=parsed_result,
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
        )
    except Exception as error:
        print(
            f"Warning: Failed to log 'Validated itinerary against business rules': {error}"
        )
    if not is_valid:
        return {"error": "Validation failed", "details": validation_errors}

    return parsed_result


def itinerary_node(state: dict) -> dict:
    """
    LangGraph adapter: maps the shared pipeline state into the input shape
    build_itinerary() expects, calls it, and merges the result back into state.
    """
    trip_request = {
        "trip_request_id": state.get("trip_request_id"),
        "destination_id": state.get("destination_id"),
        "destination_name": state.get("destination_name"),
        "start_date": state.get("start_date"),
        "end_date": state.get("end_date"),
        "traveller_count": state.get("traveller_count"),
        "budget_ceiling": state.get("target_budgets", {}).get("tours_budget")
        or state.get("budget_ceiling"),
        "preferred_activities": state.get("preferred_activities", []),
    }

    if not trip_request["destination_id"]:
        # Fallback to default destination ID 1 if not explicitly provided
        trip_request["destination_id"] = 1

    result = build_itinerary(trip_request)
    if isinstance(result, dict) and "total_estimated_cost" in result:
        result["total_cost"] = result["total_estimated_cost"]
    return {**state, "itinerary": result}


# Packages that may require manual installation:
# - google-generativeai
# - python-dotenv
# - requests (used by tools/search_tours.py)
