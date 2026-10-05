import os
import requests
from dotenv import load_dotenv

load_dotenv()
BACKEND_BASE_URL = os.getenv("BACKEND_API_URL") or os.getenv("BACKEND_URL", "http://127.0.0.1:5138")

def search_hotels(destination_id=None):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/hotel"
    try:
        params = {"destinationId": destination_id} if destination_id else {}
        response = requests.get(endpoint, params=params, timeout=10)
        response.raise_for_status()
        hotels_data = response.json()
        hotels = hotels_data.get("data", []) if isinstance(hotels_data, dict) else hotels_data
        return [h for h in hotels if isinstance(h, dict) and str(h.get("status", "")).lower() == "active"]
    except Exception as e:
        print(f"Error searching hotels: {e}")
        return []

def search_hotel_rooms(hotel_id):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/hotel/{hotel_id}/rooms"
    try:
        response = requests.get(endpoint, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error searching rooms for hotel {hotel_id}: {e}")
        return []

def check_room_availability(hotel_id, room_id, check_in, check_out):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/hotel/{hotel_id}/rooms/{room_id}/availability"
    try:
        response = requests.get(endpoint, params={"checkIn": check_in, "checkOut": check_out}, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error checking availability for room {room_id}: {e}")
        return None

def search_transports():
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/transport"
    try:
        response = requests.get(endpoint, timeout=10)
        response.raise_for_status()
        transports_data = response.json()
        transports = transports_data.get("data", []) if isinstance(transports_data, dict) else transports_data
        return [t for t in transports if isinstance(t, dict) and str(t.get("status", "")).lower() == "active"]
    except Exception as e:
        print(f"Error searching transports: {e}")
        return []

def check_transport_availability(transport_id):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/transport/{transport_id}/availability"
    try:
        response = requests.get(endpoint, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error checking availability for transport {transport_id}: {e}")
        return None
