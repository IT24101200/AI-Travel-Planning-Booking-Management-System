import os
import requests
from dotenv import load_dotenv

load_dotenv()
BACKEND_BASE_URL = os.getenv("BACKEND_API_URL") or os.getenv("BACKEND_URL", "http://127.0.0.1:5138")
HOTEL_PAGE_SIZE = 50
MAX_HOTEL_SEARCH_PAGES = 100


class HotelSearchError(RuntimeError):
    """Raised when the complete paginated hotel catalogue cannot be read."""


def search_hotels(destination_id=None, currency=None):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/hotel"
    hotels = []
    seen_ids = set()
    page = 1
    total_pages = 1

    try:
        while page <= total_pages:
            params = {
                "page": page,
                "pageSize": HOTEL_PAGE_SIZE,
            }
            if destination_id:
                params["destinationId"] = destination_id
            if currency:
                params["currency"] = currency

            response = requests.get(endpoint, params=params, timeout=10)
            response.raise_for_status()
            hotels_data = response.json()

            if isinstance(hotels_data, list):
                # Compatibility with older list-shaped catalog responses.
                if page != 1:
                    raise HotelSearchError("Hotel search returned an invalid later page.")
                page_hotels = hotels_data
                total_pages = 1
            elif isinstance(hotels_data, dict):
                page_hotels = hotels_data.get("data")
                raw_total_pages = hotels_data.get("totalPages")
                if not isinstance(page_hotels, list):
                    raise HotelSearchError("Hotel search returned an invalid page payload.")
                if page == 1:
                    try:
                        total_pages = int(raw_total_pages)
                    except (TypeError, ValueError):
                        raise HotelSearchError("Hotel search returned invalid pagination metadata.")
                    if total_pages < 1 or total_pages > MAX_HOTEL_SEARCH_PAGES:
                        raise HotelSearchError("Hotel search pagination exceeded the safe limit.")
            else:
                raise HotelSearchError("Hotel search returned an invalid response.")

            for hotel in page_hotels:
                if not isinstance(hotel, dict):
                    continue
                if str(hotel.get("status", "")).lower() != "active":
                    continue
                hotel_id = hotel.get("id")
                if hotel_id is None:
                    continue
                key = str(hotel_id)
                if key in seen_ids:
                    continue
                seen_ids.add(key)
                hotels.append(hotel)

            if page >= total_pages:
                break
            page += 1

        return hotels
    except HotelSearchError:
        raise
    except Exception as error:
        # Do not claim a partial catalogue is complete after any page fails.
        raise HotelSearchError("Hotel search could not be completed.") from error

def search_hotel_rooms(hotel_id, currency=None):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/hotel/{hotel_id}/rooms"
    try:
        response = requests.get(endpoint, params={"currency": currency} if currency else {}, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error searching rooms for hotel {hotel_id}: {e}")
        return []

def check_room_availability(hotel_id, room_id, check_in, check_out, currency=None):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/hotel/{hotel_id}/rooms/{room_id}/availability"
    try:
        params = {"checkIn": check_in, "checkOut": check_out}
        if currency:
            params["currency"] = currency
        response = requests.get(endpoint, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error checking availability for room {room_id}: {e}")
        return None

def search_transports(currency=None):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/transport"
    try:
        response = requests.get(endpoint, params={"currency": currency} if currency else {}, timeout=10)
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
