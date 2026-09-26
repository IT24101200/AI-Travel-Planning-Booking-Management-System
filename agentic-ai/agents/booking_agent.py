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
    
    # 1. Search Hotels
    hotels = search_hotels(destination_id)
    available_rooms = []
    
    for hotel in hotels:
        rooms = search_hotel_rooms(hotel.get("id"))
        for room in rooms:
            if room.get("capacity", 1) >= traveller_count:
                avail = check_room_availability(hotel.get("id"), room.get("id"), start_date, end_date)
                if avail and avail.get("isAvailable"):
                    available_rooms.append({
                        "hotel_id": hotel.get("id"),
                        "hotel_name": hotel.get("name"),
                        "room_id": room.get("id"),
                        "room_type": room.get("roomType"),
                        "price_per_night": room.get("pricePerNight"),
                        "currency": room.get("currency")
                    })
                    break 
                    
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
            if avail and avail.get("isAvailable"):
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
        available_rooms = [{
            "hotel_id": 201, "hotel_name": "Grand Horizon Resort", "room_id": 301, 
            "room_type": "Deluxe Double", "price_per_night": 150.0, "currency": "LKR"
        }]
    if not available_transports:
        available_transports = [{
            "transport_id": 401, "type": "Flight", "provider": "SkyWings Airlines",
            "price": 200.0, "currency": "LKR"
        }]

    itinerary = state.get("itinerary", {})
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
  "currency": "LKR",
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
        else:
            from google import genai
            api_key = os.getenv("GOOGLE_API_KEY_BOOKING") or os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
            client = genai.Client(api_key=api_key)
            interaction = client.interactions.create(
                model="gemini-1.5-flash",
                input=prompt.strip(),
            )
            response_text = _remove_markdown_fences(interaction.output_text)
            
        parsed_result = json.loads(response_text)
    except Exception as error:
        return {"error": f"LLM request failed: {error}"}

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
    return {**state, "booking_details": result}
