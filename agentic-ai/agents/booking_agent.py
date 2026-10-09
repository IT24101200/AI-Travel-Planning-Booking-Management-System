"""Member C: select available hotels and every transport leg for B's itinerary.

This agent proposes inventory. Member D validates the proposal; ASP.NET persists
it for staff approval. Selection here does not reserve inventory or take payment.
See docs/MEMBER_C_LEARNING_GUIDE.md for the end-to-end walkthrough.
"""

import json
import os
import requests
from datetime import datetime, timedelta
from decimal import Decimal
from concurrent.futures import ThreadPoolExecutor
from dotenv import load_dotenv
from logger import log_agent_step
from customer_revision import room_requested, reserved_quantity, transport_requested
from destination_contract import is_valid_route_order
from route_planning import plan_overnights, RoutePlanningError, AIRPORTS, point, minutes, EARLIEST_TRANSFER_START, DAY_END
from tools.availability_tools import (
    search_hotels, search_hotel_rooms, check_room_availability,
    search_transports, check_transport_availability, HotelSearchError,
    TransportSearchError, classify_transport_failure,
    _normalize_route_name, _requested_route_legs, _route_label
)

load_dotenv()
aiml_api_key = os.getenv("AIML_API_KEY")

_TRANSPORT_FAILURE_MESSAGES = {
    "TRANSPORT_CATALOGUE_NO_ROUTE":
        "No suitable transport is available for the selected route.",
    "TRANSPORT_CATALOGUE_NO_DATE_MATCH":
        "No suitable transport is available for the selected route and travel dates.",
    "TRANSPORT_CATALOGUE_NO_CAPACITY":
        "No suitable transport is available for the selected party size.",
    "TRANSPORT_CATALOGUE_NO_AVAILABILITY":
        "No suitable transport is available for the selected travel dates.",
    "TRANSPORT_MULTI_LEG_SCHEMA_REQUIRED":
        "The selected multi-leg transport plan requires a database schema update before it can be booked.",
}

MAX_TIMETABLE_PLANS = 256
INVENTORY_WORKERS = 4


def _inventory_map(function, values):
    """Bound concurrent reads while preserving catalogue order and errors."""
    values = list(values)
    if len(values) < 2:
        return [function(value) for value in values]
    with ThreadPoolExecutor(max_workers=INVENTORY_WORKERS) as executor:
        return list(executor.map(function, values))


def _compatible_timetables(groups, state):
    """Yield distinct, chronological schedules without building a Cartesian product.

    Equal schedules are interchangeable after route/capacity/availability checks;
    keep their cheapest database option. Backward reachability removes options
    with no possible continuation before enumerating complete schedules.
    """
    ready = None
    if state.get("airport_pickup"):
        start = datetime.fromisoformat(str(state["start_date"]).replace("Z", "+00:00"))
        ready = start.replace(tzinfo=None, hour=0, minute=0, second=0, microsecond=0)
        ready += timedelta(minutes=minutes(state.get("airport_arrival_time")) + 60)
    distinct = []
    for index, group in enumerate(groups):
        schedules = {}
        for option in group:
            try:
                departure = datetime.fromisoformat(str(option["departure_time"]).replace("Z", "+00:00")).replace(tzinfo=None)
                arrival = datetime.fromisoformat(str(option["arrival_time"]).replace("Z", "+00:00")).replace(tzinfo=None)
            except (KeyError, TypeError, ValueError):
                continue
            if (arrival <= departure or arrival.date() != departure.date()
                    or departure.hour * 60 + departure.minute < EARLIEST_TRANSFER_START
                    or arrival.hour * 60 + arrival.minute > DAY_END
                    or (index == 0 and ready is not None and departure < ready)):
                continue
            key = (departure, arrival)
            previous = schedules.get(key)
            if previous is None or Decimal(str(option["price"])) < Decimal(str(previous[2]["price"])):
                schedules[key] = (departure, arrival, option)
        distinct.append(sorted(schedules.values(), key=lambda row: (Decimal(str(row[2]["price"])), row[0], row[1])))
    if not distinct:
        return
    for index in range(len(distinct) - 2, -1, -1):
        if not distinct[index + 1]:
            return
        latest_next_departure = max(row[0] for row in distinct[index + 1])
        distinct[index] = [row for row in distinct[index] if row[1] <= latest_next_departure]

    def extend(index, previous_arrival, selected):
        if index == len(distinct):
            yield tuple(selected)
            return
        for departure, arrival, option in distinct[index]:
            if previous_arrival is None or departure >= previous_arrival:
                yield from extend(index + 1, arrival, [*selected, option])

    yield from extend(0, None, [])


def _booking_failure(trip_id, code, message, diagnostics=None):
    """Return a safe failure and persist the Booking Agent's final outcome."""

    output_data = {
        "agent_outcome": "Failed",
        "error_code": code,
        "error": message,
    }
    if diagnostics:
        output_data["transport_diagnostics"] = diagnostics
        output_data["planning_diagnostics"] = diagnostics
    log_agent_step(
        trip_request_id=trip_id,
        agent_name="BookingAgent",
        step_name="Booking Agent failed",
        step_type="Outcome",
        output_data=output_data,
        status="Failed",
    )
    result = {
        "status": "AvailabilityFailed",
        "agent_status": "Failed",
        "error_code": code,
        "error": message,
    }
    if diagnostics:
        result["transport_diagnostics"] = diagnostics
        result["planning_diagnostics"] = diagnostics
    return result

def _remove_markdown_fences(text):
    cleaned = text.strip()
    if cleaned.startswith("```"):
        first_newline = cleaned.find("\n")
        if first_newline != -1:
            cleaned = cleaned[first_newline + 1 :]
        if cleaned.rstrip().endswith("```"):
            cleaned = cleaned.rstrip()[:-3]
    return cleaned.strip()

def build_booking_package(state):
    """Read shared trip constraints and return a priced package or coded failure."""
    trip_id = state.get("trip_request_id")
    destination_id = state.get("destination_id")
    start_date = state.get("start_date")
    end_date = state.get("end_date")
    traveller_count = state.get("traveller_count", 1)
    currency = str(state.get("currency", "LKR")).upper()
    revision = state.get("revision_request") or {}

    if not isinstance(destination_id, int) or destination_id <= 0:
        return _booking_failure(
            trip_id,
            "DESTINATION_REQUIRED",
            "A real database-backed destination is required before inventory can be selected.",
        )

    itinerary = state.get("itinerary", {})
    if not isinstance(itinerary, dict) or itinerary.get("error"):
        return _booking_failure(
            trip_id,
            itinerary.get("error_code", "INVALID_ITINERARY"),
            itinerary.get("error", "A valid itinerary proposal is required."),
        )

    requested_destinations = state.get("requested_destinations")
    if requested_destinations is None:
        requested_destinations = [{
            "destination_id": destination_id,
            "destination_name": state.get("destination_name", ""),
        }]
    requested_order = [item["destination_id"] for item in requested_destinations]
    planned_order = itinerary.get("route_destination_ids")
    if planned_order is not None and not is_valid_route_order(
        planned_order,
        requested_order,
        starter_location_id=state.get("starter_location_id"),
        airport_pickup=bool(state.get("airport_pickup")),
    ):
        return _booking_failure(
            trip_id,
            "INVALID_DESTINATION_ORDER",
            "The planned route must include every selected destination and respect the selected route origin.",
            diagnostics={
                "requested_destination_ids": requested_order,
                "planned_destination_ids": planned_order,
                "starter_location_id": state.get("starter_location_id"),
                "airport_pickup": bool(state.get("airport_pickup")),
            },
        )
    
    geographic = bool(itinerary.get("route_destination_ids"))
    # Geographic plans may use a nearby or intermediate hotel in another city.
    try:
        hotels = search_hotels(None if geographic else destination_id, currency=currency)
    except HotelSearchError as error:
        return _booking_failure(trip_id, "HOTEL_SEARCH_INCOMPLETE", str(error))
    available_rooms = []
    
    room_catalogues = _inventory_map(
        lambda hotel: search_hotel_rooms(hotel.get("id"), currency=currency), hotels
    )
    for hotel, rooms in zip(hotels, room_catalogues):
        for room in rooms:
            if revision and room.get("id") not in {pin["room_id"] for pin in revision.get("rooms", [])}:
                continue
            if room.get("capacity", 1) >= traveller_count and str(room.get("status", "Active")).lower() == "active":
                if geographic:
                    try:
                        point(hotel)
                    except RoutePlanningError:
                        continue
                avail = {"isAvailable": True} if geographic else check_room_availability(hotel.get("id"), room.get("id"), start_date, end_date, currency=currency)
                is_room_avail = avail and (avail.get("isAvailable") is True or avail.get("availableRooms", 0) > 0)
                if is_room_avail:
                    available_rooms.append({
                        "hotel_id": hotel.get("id"),
                        "hotel_name": hotel.get("name"),
                        "room_id": room.get("id"),
                        "room_type": room.get("roomType"),
                        "price_per_night": room.get("pricePerNight"),
                        "currency": room.get("currency"),
                        **({"latitude": hotel["latitude"], "longitude": hotel["longitude"], "destination_id": hotel.get("destinationId")} if geographic else {}),
                    })
                    
    log_agent_step(
        trip_request_id=trip_id,
        agent_name="BookingAgent",
        step_name="Checked hotel availability",
        step_type="ToolCall",
        tool_name="check_hotel_availability",
        output_data={"available_rooms": len(available_rooms)}
    )

    # 2. Search transports from the complete, route/date-compatible catalogue.
    if geographic:
        by_id = {d["destination_id"]: d for d in requested_destinations}
        requested_destinations = [by_id[i] for i in itinerary["route_destination_ids"]]
    if state.get("airport_pickup"):
        requested_destinations = [{"destination_name": AIRPORTS[state.get("airport_code") or "CMB"]["name"]}, *requested_destinations]
    try:
        transports = search_transports(
            currency=currency,
            requested_destinations=requested_destinations,
            start_date=start_date,
            end_date=end_date,
            traveller_count=traveller_count,
        )
    except TransportSearchError as error:
        return _booking_failure(trip_id, "TRANSPORT_SEARCH_INCOMPLETE", str(error))

    transport_diagnostics = dict(getattr(transports, "diagnostics", {}) or {})
    available_transports = []
    availability_mismatch_count = 0
    requested_legs = _requested_route_legs(requested_destinations)
    eligible_transports = [t for t in transports if t.get("capacity", 1) >= traveller_count]
    transport_availability = _inventory_map(
        lambda option: check_transport_availability(option.get("id")), eligible_transports
    )
    for t, avail in zip(eligible_transports, transport_availability):
        if t.get("capacity", 1) >= traveller_count:
            is_trans_avail = avail and (avail.get("availableSeats", 0) + reserved_quantity(revision, "transport_option_id", t.get("id")) >= traveller_count
                if "availableSeats" in avail else avail.get("isAvailable") is True)
            if is_trans_avail:
                option = {
                    "transport_id": t.get("id"),
                    "type": t.get("type"),
                    "provider": t.get("provider"),
                    "route_from": t.get("routeFrom"),
                    "route_to": t.get("routeTo"),
                    "departure_time": t.get("departureTime"),
                    "arrival_time": t.get("arrivalTime"),
                    "price": t.get("price"),
                    "currency": t.get("currency")
                }
                if requested_legs:
                    route_from = _normalize_route_name(t.get("routeFrom"))
                    route_to = _normalize_route_name(t.get("routeTo"))
                    option["leg_index"] = next(
                        (
                            index
                            for index, (source, target) in enumerate(requested_legs)
                            if route_from == source and route_to == target
                        ),
                        None,
                    )
                if transport_requested(revision, option):
                    available_transports.append(option)
            else:
                availability_mismatch_count += 1

    if not transport_diagnostics:
        # Keep tests and older integrations that return a plain list safe while
        # real catalogue searches provide the full funnel diagnostics.
        transport_diagnostics = {
            "active_count": len(transports),
            "capacity_compatible_count": len(transports),
            "route_compatible_count": len(transports),
            "date_compatible_count": len(transports),
            "route_mismatch_count": 0,
            "date_mismatch_count": 0,
            "capacity_mismatch_count": 0,
            "missing_route_legs": [],
        }
    transport_diagnostics["availability_mismatch_count"] = availability_mismatch_count
    transport_diagnostics["availability_compatible_count"] = len(available_transports)
    transport_diagnostics["final_count"] = len(available_transports)

    if requested_legs:
        options_by_leg = {
            index: [option for option in available_transports if option.get("leg_index") == index]
            for index in range(len(requested_legs))
        }
        missing_legs = [
            _route_label(source, target)
            for index, (source, target) in enumerate(requested_legs)
            if not options_by_leg[index]
        ]
        transport_diagnostics["required_leg_count"] = len(requested_legs)
        transport_diagnostics["available_leg_count"] = len(requested_legs) - len(missing_legs)
        transport_diagnostics["missing_transport_legs"] = missing_legs

    log_agent_step(
        trip_request_id=trip_id,
        agent_name="BookingAgent",
        step_name="Checked transport availability",
        step_type="ToolCall",
        tool_name="check_transport_availability",
        output_data={"available_transports": len(available_transports)}
    )

    if revision and (not available_rooms or not available_transports or transport_diagnostics.get("missing_transport_legs")):
        return _booking_failure(trip_id, "REQUESTED_OPTION_UNAVAILABLE",
            "A requested hotel or transport is no longer available. Your current itinerary is preserved; choose another option and request changes again.")

    if not available_rooms:
        return _booking_failure(
            trip_id,
            "NO_VALID_ROOM",
            "No suitable room is available for the requested dates.",
        )
    if requested_legs and transport_diagnostics.get("missing_transport_legs"):
        missing = transport_diagnostics["missing_transport_legs"]
        only_airport_missing = state.get("airport_pickup") and all(
            leg.startswith(AIRPORTS[state.get("airport_code") or "CMB"]["name"] + " -> ")
            for leg in missing
        )
        remedy = (
            " or turn off airport pickup and request a new plan."
            if only_airport_missing else " and request a new plan."
        )
        return _booking_failure(
            trip_id,
            "TRANSPORT_CATALOGUE_NO_ROUTE",
            "No available transport covers: " + "; ".join(missing) + ". Add matching transport inventory" + remedy,
            diagnostics=transport_diagnostics,
        )
    if not available_transports:
        transport_error_code = classify_transport_failure(
            transport_diagnostics,
            availability_mismatch_count=availability_mismatch_count,
        )
        transport_error = _TRANSPORT_FAILURE_MESSAGES.get(
            transport_error_code,
            "No suitable transport is available for the selected route and travel dates.",
        )
        return _booking_failure(
            trip_id,
            transport_error_code,
            transport_error,
            diagnostics=transport_diagnostics,
        )

    if requested_legs or geographic:
        # A multi-leg proposal is selected completely and deterministically.
        # Keep one database-backed option per adjacent destination leg; never
        # collapse a true multi-leg trip to one selected_transport object.
        selected_transports = [
            min(
                [option for option in available_transports if option.get("leg_index") == index],
                key=lambda option: float(option.get("price", 0)),
            )
            for index in range(len(requested_legs))
        ] if requested_legs else [min(available_transports, key=lambda option: float(option.get("price", 0)))]
        try:
            from datetime import datetime
            d1 = datetime.fromisoformat(str(start_date).replace("Z", "+00:00")).date()
            d2 = datetime.fromisoformat(str(end_date).replace("Z", "+00:00")).date()
            nights = max(1, (d2 - d1).days)
        except Exception:
            nights = 1
        selected_room = min(available_rooms, key=lambda room: float(room.get("price_per_night", 0)))
        room_selections = None
        transport_search = None
        if geographic:
            availability_cache = {}
            geometry_cache = {}
            def room_available(room, check_in, check_out):
                if not room_requested(revision, room["room_id"], check_in, check_out):
                    return False
                key = (room["room_id"], check_in, check_out)
                if key not in availability_cache:
                    result = check_room_availability(room["hotel_id"], room["room_id"], check_in, check_out, currency=currency)
                    availability_cache[key] = bool(result and (
                        result.get("availableRooms", 0) + reserved_quantity(revision, "room_id", room["room_id"], check_in, check_out) > 0
                        if "availableRooms" in result else result.get("isAvailable") is True))
                return availability_cache[key]
            try:
                groups = [[option for option in available_transports if option.get("leg_index") == index]
                          for index in range(len(requested_legs))] if requested_legs else [available_transports]
                combinations = _compatible_timetables(groups, state) if requested_legs else [tuple(selected_transports)]
                candidates = []
                last_error = None
                evaluated = 0
                search_limited = False
                for combination in combinations:
                    if evaluated >= MAX_TIMETABLE_PLANS:
                        search_limited = True
                        break
                    evaluated += 1
                    windows = {}
                    events = []
                    route_ids = itinerary["route_destination_ids"]
                    representatives = {item["destination_id"]: item for day in itinerary["schedule"] for item in day["items"]}
                    offset = int(bool(state.get("airport_pickup")))
                    valid_times = True
                    for leg_index, option in enumerate(combination if requested_legs else []):
                        departure = datetime.fromisoformat(str(option["departure_time"]).replace("Z", "+00:00")).replace(tzinfo=None)
                        arrival = datetime.fromisoformat(str(option["arrival_time"]).replace("Z", "+00:00")).replace(tzinfo=None)
                        target_index = leg_index + 1 - offset
                        events.append({"source": representatives[route_ids[leg_index - offset]] if leg_index >= offset else {**AIRPORTS[state.get("airport_code") or "CMB"], "kind": "airport"},
                            "target": representatives[route_ids[target_index]], "target_index": target_index,
                            "departure": departure, "arrival": arrival})
                        if target_index >= 0:
                            target = route_ids[target_index]
                            windows[target] = (arrival, windows.get(target, (None, None))[1])
                        if leg_index >= offset:
                            source = route_ids[leg_index - offset]
                            windows[source] = (windows.get(source, (None, None))[0], departure)
                        elif state.get("airport_pickup"):
                            ready = datetime.fromisoformat(str(start_date).replace("Z", "+00:00")).replace(tzinfo=None, hour=0, minute=0, second=0)
                            ready += timedelta(minutes=minutes(state.get("airport_arrival_time")) + 60)
                            valid_times &= departure >= ready
                    if not valid_times:
                        last_error = RoutePlanningError("TRANSPORT_TIMETABLE_INFEASIBLE", "Airport pickup transport departs before you are ready after arrival.")
                        continue
                    transport_cost = sum(float(t["price"]) * traveller_count for t in combination)
                    try:
                        plan, stays = plan_overnights({**state, "transport_windows": windows, "transport_events": events,
                            "budget_ceiling": float(state["budget_ceiling"]) - transport_cost}, itinerary, available_rooms, room_available,
                            geometry_cache=geometry_cache)
                        cost = transport_cost + sum(float(r["price_per_night"]) * r["nights"] for r in stays)
                        candidates.append((plan["travel_distance_km"], cost, plan, stays, list(combination)))
                    except RoutePlanningError as error:
                        last_error = error
                if not candidates:
                    if search_limited:
                        raise RoutePlanningError("ROUTE_SEARCH_LIMIT", "No feasible package was found within the transport search limit. Please narrow the travel dates or destinations.")
                    raise last_error or RoutePlanningError("TRANSPORT_TIMETABLE_INFEASIBLE", "No transport timetable fits the journeys and hotel stays.")
                transport_search = {"evaluated_timetables": evaluated, "search_limited": search_limited}
                _, _, itinerary, room_selections, selected_transports = min(candidates, key=lambda candidate: candidate[:2])
                if any(not room_available(room, room["check_in"], room["check_out"]) for room in room_selections):
                    raise RoutePlanningError("NO_VALID_ROOM", "A selected hotel is no longer available for the complete stay. Please retry.")
                selected_room = room_selections[0]
            except RoutePlanningError as error:
                diagnostics = dict(getattr(error, "details", {}) or {})
                diagnostics.update({
                    "evaluated_timetables": evaluated if "evaluated" in locals() else 0,
                    "search_limited": search_limited if "search_limited" in locals() else False,
                })
                return _booking_failure(trip_id, error.code, str(error), diagnostics=diagnostics)
        tour_cost = sum(
            (Decimal(str(tour["price"])) * traveller_count
             for day in itinerary.get("schedule", [])
             for tour in day.get("items", [])),
            Decimal("0"),
        )
        total_cost = (
            tour_cost
            + (sum((Decimal(str(r["price_per_night"])) * r["nights"] for r in room_selections), Decimal("0")) if room_selections is not None else Decimal(str(selected_room["price_per_night"])) * nights)
            + sum(Decimal(str(option["price"])) * traveller_count for option in selected_transports)
        )
        multi_leg_package = {
            "booking_package_id": None,
            "currency": currency,
            "itinerary": itinerary,
            "selected_room": dict(selected_room),
            **({"room_selections": room_selections} if room_selections is not None else {}),
            **({"transport_selections": [
                {
                    **dict(option),
                    "transport_option_id": option.get("transport_id"),
                }
                for option in selected_transports
            ]} if requested_legs else {"selected_transport": dict(selected_transports[0])}),
            "total_package_cost": float(total_cost),
            "total_cost": float(total_cost),
            "persistence_status": "READY_FOR_PERSISTENCE",
            **({"transport_search": transport_search} if transport_search is not None else {}),
        }
        try:
            log_agent_step(
                trip_request_id=trip_id,
                agent_name="BookingAgent",
                step_name="Selected complete multi-leg transport plan",
                step_type="Plan",
                output_data=multi_leg_package,
                reason="Choose a feasible complete timetable and hotel stays; rank candidates by road distance, then cost. Respect dates, capacity and budget.",
            )
        except Exception as error:
            print(f"Warning: Failed to log multi-leg transport selection: {error}")
        return multi_leg_package

    itinerary_json = json.dumps(itinerary, indent=2, default=str)
    rooms_json = json.dumps(available_rooms, indent=2, default=str)
    transports_json = json.dumps(available_transports, indent=2, default=str)
    
    prompt = f"""
You are a booking agent. Your job is to select exactly one hotel room and exactly one transport option from the available lists, and combine them with the draft itinerary into a final priced booking package.

DRAFT ITINERARY:
{itinerary_json}

AVAILABLE ROOMS:
{rooms_json}

AVAILABLE TRANSPORTS:
{transports_json}

Rules:
1. Select exactly one room and one transport option from the available lists.
2. Do not invent any rooms or transports.
3. Calculate the new total cost by adding the itinerary total_cost, the transport price (multiplied by {traveller_count} travellers), and the room price_per_night (multiplied by the number of nights between {start_date} and {end_date}). Assume 1 night if dates are the same.
4. Return ONLY valid JSON matching this exact structure:

{{
  "booking_package_id": null,
  "total_package_cost": 0.0,
  "currency": "{currency}",
  "itinerary": <insert the unmodified DRAFT ITINERARY schedule here>,
  "selected_room": {{
    "hotel_id": 1,
    "room_id": 1,
    "hotel_name": "Name",
    "price_per_night": 0.0
  }},
  "selected_transport": {{
    "transport_id": 1,
    "type": "Flight",
    "provider": "Name",
    "price": 0.0
  }}
}}
"""

    nights = 1
    try:
        from datetime import datetime
        d1 = datetime.fromisoformat(str(start_date).replace("Z", "+00:00")).date()
        d2 = datetime.fromisoformat(str(end_date).replace("Z", "+00:00")).date()
        nights = max(1, (d2 - d1).days)
    except Exception:
        nights = 1

    parsed_result = None
    selected_model = None
    try:
        if aiml_api_key:
            selected_model = "gpt-4o-mini (AIML API)"
            response = requests.post(
                "https://api.aimlapi.com/v1/chat/completions",
                headers={
                    "Authorization": f"Bearer {aiml_api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": "gpt-4o-mini",
                    "messages": [{"role": "user", "content": prompt.strip()}]
                },
                timeout=30
            )
            response.raise_for_status()
            response_text = _remove_markdown_fences(response.json()["choices"][0]["message"]["content"])
            parsed_result = json.loads(response_text)
        else:
            api_key = os.getenv("GOOGLE_API_KEY_BOOKING") or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
            if api_key:
                selected_model = "gemini-3.8-flash"
                import httpx
                url = f"https://generativelanguage.googleapis.com/v1beta/interactions?key={api_key}"
                with httpx.Client(timeout=4.0) as client:
                    resp = client.post(url, json={"model": "gemini-3.8-flash", "input": prompt.strip()})
                    if resp.status_code == 200:
                        data = resp.json()
                        raw_text = data.get("output_text") or (data.get("outputs", [{}])[0].get("text") if "outputs" in data else None)
                        if raw_text:
                            response_text = _remove_markdown_fences(raw_text)
                            parsed_result = json.loads(response_text)
                    else:
                        print(f"[Warning] Booking Agent Gemini API returned HTTP {resp.status_code}, using deterministic selection fallback.")
    except Exception as error:
        print(f"[Warning] Booking Agent LLM request failed ({error}), using deterministic selection fallback.")

    if not isinstance(parsed_result, dict) or not parsed_result.get("selected_room"):
        selected_model = None
        # Deterministic fallback: pick cheapest available room and transport
        best_room = min(available_rooms, key=lambda r: float(r.get("price_per_night", 0)))
        best_transport = min(available_transports, key=lambda t: float(t.get("price", 0)))
        parsed_result = {
            "booking_package_id": None,
            "currency": currency,
            "itinerary": itinerary,
            "selected_room": {
                "hotel_id": best_room.get("hotel_id"),
                "room_id": best_room.get("room_id"),
                "hotel_name": best_room.get("hotel_name"),
                "price_per_night": best_room.get("price_per_night")
            },
            "selected_transport": {
                "transport_id": best_transport.get("transport_id"),
                "type": best_transport.get("type"),
                "provider": best_transport.get("provider"),
                "price": best_transport.get("price")
            }
        }

    selected_room = parsed_result.get("selected_room") or {}
    selected_transport = parsed_result.get("selected_transport") or {}
    valid_room_ids = {room.get("room_id") for room in available_rooms}
    valid_transport_ids = {option.get("transport_id") for option in available_transports}
    if selected_room.get("room_id") not in valid_room_ids:
        return {
            "status": "AvailabilityFailed",
            "error_code": "INVALID_ROOM_SELECTION",
            "error": "Selected room was not returned by the backend availability search.",
        }
    if selected_transport.get("transport_id") not in valid_transport_ids:
        return {
            "status": "AvailabilityFailed",
            "error_code": "INVALID_TRANSPORT_SELECTION",
            "error": "Selected transport was not returned by the backend availability search.",
        }
    # Preserve Student B's persisted itinerary exactly; do not trust the LLM to
    # reproduce its database ID or schedule without alteration.
    parsed_result["itinerary"] = itinerary
    parsed_result["currency"] = currency

    # The model selects inventory; database prices and quantities determine cost.
    # Itinerary producers may expose total_estimated_cost rather than total_cost,
    # so calculate from the preserved schedule instead of either summary field.
    selected_room = next(room for room in available_rooms
                         if room["room_id"] == selected_room["room_id"])
    selected_transport = next(option for option in available_transports
                              if option["transport_id"] == selected_transport["transport_id"])
    parsed_result["selected_room"] = dict(selected_room)
    parsed_result["selected_transport"] = dict(selected_transport)
    tour_cost = sum(
        (Decimal(str(tour["price"])) * traveller_count
         for day in itinerary.get("schedule", [])
         for tour in day.get("items", [])),
        Decimal("0"),
    )
    total_cost = (
        tour_cost
        + Decimal(str(selected_room["price_per_night"])) * nights
        + Decimal(str(selected_transport["price"])) * traveller_count
    )
    parsed_result["total_package_cost"] = float(total_cost)
    parsed_result["total_cost"] = float(total_cost)

    try:
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="BookingAgent",
            step_name="Assembled priced booking package",
            step_type="Plan",
            output_data=parsed_result,
            reason="Select available catalogue inventory; restore trusted prices and recalculate tours per traveller, rooms per night and transport per traveller.",
            execution_mode="llm_response" if selected_model else "deterministic_fallback",
            model=selected_model,
        )
    except Exception as error:
        print(f"Warning: Failed to log 'Assembled priced booking package': {error}")

    return parsed_result


def booking_node(state: dict) -> dict:
    """
    LangGraph adapter: receives pipeline state, checks availability, 
    and returns a concrete, priced booking package.
    """
    result = build_booking_package(state)
    if isinstance(result, dict) and "total_package_cost" in result and "total_cost" not in result:
        result["total_cost"] = result["total_package_cost"]
    return {**state, "booking_details": result,
            "status": result.get("status", state.get("status", "InPlanning")),
            "itinerary": result.get("itinerary", state.get("itinerary", {}))}
