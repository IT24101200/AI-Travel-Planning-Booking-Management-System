import json
import os
import requests
from decimal import Decimal
from dotenv import load_dotenv
from logger import log_agent_step
from tools.availability_tools import (
    search_hotels, search_hotel_rooms, check_room_availability,
    search_transports, check_transport_availability, HotelSearchError,
    TransportSearchError, classify_transport_failure
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
}


def _booking_failure(trip_id, code, message, diagnostics=None):
    """Return a safe failure and persist the Booking Agent's final outcome."""

    output_data = {
        "agent_outcome": "Failed",
        "error_code": code,
        "error": message,
    }
    if diagnostics:
        output_data["transport_diagnostics"] = diagnostics
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
    trip_id = state.get("trip_request_id")
    destination_id = state.get("destination_id")
    start_date = state.get("start_date")
    end_date = state.get("end_date")
    traveller_count = state.get("traveller_count", 1)
    currency = str(state.get("currency", "LKR")).upper()

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
            "INVALID_ITINERARY",
            itinerary.get("error", "A valid itinerary proposal is required."),
        )
    
    # 1. Search only inventory belonging to the requested destination.
    try:
        hotels = search_hotels(destination_id, currency=currency)
    except HotelSearchError as error:
        return _booking_failure(trip_id, "HOTEL_SEARCH_INCOMPLETE", str(error))
    available_rooms = []
    
    for hotel in hotels:
        rooms = search_hotel_rooms(hotel.get("id"), currency=currency)
        for room in rooms:
            if room.get("capacity", 1) >= traveller_count:
                avail = check_room_availability(hotel.get("id"), room.get("id"), start_date, end_date, currency=currency)
                is_room_avail = avail and (avail.get("isAvailable") is True or avail.get("availableRooms", 0) > 0)
                if is_room_avail:
                    available_rooms.append({
                        "hotel_id": hotel.get("id"),
                        "hotel_name": hotel.get("name"),
                        "room_id": room.get("id"),
                        "room_type": room.get("roomType"),
                        "price_per_night": room.get("pricePerNight"),
                        "currency": room.get("currency")
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
    requested_destinations = state.get("requested_destinations")
    if requested_destinations is None:
        requested_destinations = [{
            "destination_id": destination_id,
            "destination_name": state.get("destination_name", ""),
        }]
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
    for t in transports:
        if t.get("capacity", 1) >= traveller_count:
            avail = check_transport_availability(t.get("id"))
            is_trans_avail = avail and (avail.get("isAvailable") is True or avail.get("availableSeats", 0) >= traveller_count)
            if is_trans_avail:
                available_transports.append({
                    "transport_id": t.get("id"),
                    "type": t.get("type"),
                    "provider": t.get("provider"),
                    "route_from": t.get("routeFrom"),
                    "route_to": t.get("routeTo"),
                    "departure_time": t.get("departureTime"),
                    "arrival_time": t.get("arrivalTime"),
                    "price": t.get("price"),
                    "currency": t.get("currency")
                })
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

    log_agent_step(
        trip_request_id=trip_id,
        agent_name="BookingAgent",
        step_name="Checked transport availability",
        step_type="ToolCall",
        tool_name="check_transport_availability",
        output_data={"available_transports": len(available_transports)}
    )

    if not available_rooms:
        return _booking_failure(
            trip_id,
            "NO_VALID_ROOM",
            "No suitable room is available for the requested dates.",
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
    try:
        if aiml_api_key:
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
    return {**state, "booking_details": result}
