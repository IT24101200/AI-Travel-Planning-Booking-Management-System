import json
import os
import requests
from dotenv import load_dotenv
from logger import log_agent_step
from tools.availability_tools import (
    search_hotels, search_hotel_rooms, check_room_availability,
    search_transports, check_transport_availability
)

load_dotenv()
aiml_api_key = os.getenv("AIML_API_KEY")

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
    destination_id = state.get("destination_id", 1)
    start_date = state.get("start_date")
    end_date = state.get("end_date")
    traveller_count = state.get("traveller_count", 1)
    currency = str(state.get("currency", "USD")).upper()

    itinerary = state.get("itinerary", {})
    if not isinstance(itinerary, dict) or itinerary.get("error"):
        return {
            "status": "AvailabilityFailed",
            "error_code": "INVALID_ITINERARY",
            "error": itinerary.get("error", "A valid persisted itinerary is required."),
        }
    if not itinerary.get("itinerary_id"):
        return {
            "status": "AvailabilityFailed",
            "error_code": "MISSING_ITINERARY_ID",
            "error": "A persisted itinerary ID is required before inventory selection.",
        }
    
    # 1. Search Hotels (fallback to all active hotels if destination has no specific hotel)
    hotels = search_hotels(destination_id)
    if not hotels:
        hotels = search_hotels(None)
    available_rooms = []
    
    for hotel in hotels:
        rooms = search_hotel_rooms(hotel.get("id"))
        for room in rooms:
            if room.get("capacity", 1) >= traveller_count:
                avail = check_room_availability(hotel.get("id"), room.get("id"), start_date, end_date)
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

    # 2. Search Transports
    transports = search_transports()
    available_transports = []
    for t in transports:
        if t.get("capacity", 1) >= traveller_count:
            avail = check_transport_availability(t.get("id"))
            is_trans_avail = avail and (avail.get("isAvailable") is True or avail.get("availableSeats", 0) >= traveller_count)
            if is_trans_avail:
                available_transports.append({
                    "transport_id": t.get("id"),
                    "type": t.get("type"),
                    "provider": t.get("provider"),
                    "price": t.get("price"),
                    "currency": t.get("currency")
                })

    log_agent_step(
        trip_request_id=trip_id,
        agent_name="BookingAgent",
        step_name="Checked transport availability",
        step_type="ToolCall",
        tool_name="check_transport_availability",
        output_data={"available_transports": len(available_transports)}
    )

    if not available_rooms:
        return {
            "status": "AvailabilityFailed",
            "error_code": "NO_VALID_ROOM",
            "error": "No database-backed room is available for the requested dates.",
        }
    if not available_transports:
        return {
            "status": "AvailabilityFailed",
            "error_code": "NO_VALID_TRANSPORT",
            "error": "No database-backed transport option is available.",
        }

    # Normalize available rooms and transports to the requested currency (1 USD = 300 LKR)
    normalized_rooms = []
    for room in available_rooms:
        r_copy = dict(room)
        r_curr = str(room.get("currency") or "USD").upper()
        p = float(room.get("price_per_night") or 0.0)
        if r_curr == "USD" and currency == "LKR":
            r_copy["price_per_night"] = round(p * 300.0, 2)
            r_copy["currency"] = "LKR"
        elif r_curr == "LKR" and currency == "USD":
            r_copy["price_per_night"] = round(p / 300.0, 2)
            r_copy["currency"] = "USD"
        else:
            r_copy["currency"] = currency
        normalized_rooms.append(r_copy)

    normalized_transports = []
    for option in available_transports:
        t_copy = dict(option)
        t_curr = str(option.get("currency") or "USD").upper()
        p = float(option.get("price") or 0.0)
        if t_curr == "USD" and currency == "LKR":
            t_copy["price"] = round(p * 300.0, 2)
            t_copy["currency"] = "LKR"
        elif t_curr == "LKR" and currency == "USD":
            t_copy["price"] = round(p / 300.0, 2)
            t_copy["currency"] = "USD"
        else:
            t_copy["currency"] = currency
        normalized_transports.append(t_copy)

    available_rooms = normalized_rooms
    available_transports = normalized_transports

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
        itinerary_cost = float(itinerary.get("total_cost", 0.0))
        room_cost = float(best_room.get("price_per_night", 0.0)) * nights
        transport_cost = float(best_transport.get("price", 0.0)) * traveller_count
        total_pkg_cost = itinerary_cost + room_cost + transport_cost
        parsed_result = {
            "booking_package_id": None,
            "total_package_cost": round(total_pkg_cost, 2),
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
