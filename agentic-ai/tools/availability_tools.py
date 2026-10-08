import os
import requests
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()
BACKEND_BASE_URL = os.getenv("BACKEND_API_URL") or os.getenv("BACKEND_URL", "http://127.0.0.1:5138")
HOTEL_PAGE_SIZE = 50
MAX_HOTEL_SEARCH_PAGES = 100
TRANSPORT_PAGE_SIZE = 50
MAX_TRANSPORT_SEARCH_PAGES = 100


class HotelSearchError(RuntimeError):
    """Raised when the complete paginated hotel catalogue cannot be read."""


class TransportSearchError(RuntimeError):
    """Raised when the complete paginated transport catalogue cannot be read."""


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

def _normalize_route_name(value):
    return " ".join(str(value or "").strip().split()).casefold()


def _parse_transport_datetime(value):
    if isinstance(value, datetime):
        return value
    return datetime.fromisoformat(str(value).replace("Z", "+00:00"))


def _transport_route_matches(transport, requested_destinations):
    if requested_destinations is None:
        return True

    names = [
        _normalize_route_name(item.get("destination_name", item.get("name")))
        for item in requested_destinations
        if isinstance(item, dict)
    ]
    names = [name for name in names if name]
    if not names:
        return False

    route_from = _normalize_route_name(transport.get("routeFrom"))
    route_to = _normalize_route_name(transport.get("routeTo"))
    if len(names) == 1:
        return route_from == names[0] or route_to == names[0]
    return any(
        route_from == source and route_to == target
        for source, target in zip(names, names[1:])
    )


def _transport_date_matches(transport, start_date, end_date):
    if start_date is None and end_date is None:
        return True
    if start_date is None or end_date is None:
        return False
    try:
        departure = _parse_transport_datetime(transport.get("departureTime"))
        arrival = _parse_transport_datetime(transport.get("arrivalTime"))
        start = _parse_transport_datetime(start_date)
        end = _parse_transport_datetime(end_date)
    except (TypeError, ValueError, OverflowError):
        return False
    return (
        arrival > departure
        and departure.date() >= start.date()
        and arrival.date() <= end.date()
    )


def search_transports(
    currency=None,
    requested_destinations=None,
    start_date=None,
    end_date=None,
    traveller_count=None,
):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/transport"
    transports = []
    seen_ids = set()
    page = 1
    total_pages = 1
    try:
        while page <= total_pages:
            params = {
                "page": page,
                "pageSize": TRANSPORT_PAGE_SIZE,
            }
            if currency:
                params["currency"] = currency

            response = requests.get(endpoint, params=params, timeout=10)
            response.raise_for_status()
            payload = response.json()
            if not isinstance(payload, dict) or not isinstance(payload.get("data"), list):
                raise TransportSearchError("Transport search returned an invalid page payload.")

            raw_total_pages = payload.get("totalPages")
            if isinstance(raw_total_pages, bool):
                raise TransportSearchError("Transport search returned invalid pagination metadata.")
            try:
                reported_total_pages = int(raw_total_pages)
            except (TypeError, ValueError):
                raise TransportSearchError("Transport search returned invalid pagination metadata.") from None

            if reported_total_pages < 0 or reported_total_pages > MAX_TRANSPORT_SEARCH_PAGES:
                raise TransportSearchError("Transport search pagination exceeded the safe limit.")
            if reported_total_pages == 0:
                if payload["data"]:
                    raise TransportSearchError("Transport search returned inconsistent pagination metadata.")
                total_pages = 1
            else:
                if page == 1:
                    total_pages = reported_total_pages
                elif reported_total_pages != total_pages:
                    raise TransportSearchError("Transport search returned inconsistent pagination metadata.")

            for metadata_name, expected in (("page", page), ("pageSize", TRANSPORT_PAGE_SIZE)):
                if metadata_name in payload:
                    try:
                        actual = int(payload[metadata_name])
                    except (TypeError, ValueError):
                        raise TransportSearchError("Transport search returned invalid page metadata.") from None
                    if actual != expected:
                        raise TransportSearchError("Transport search returned inconsistent page metadata.")

            for transport in payload["data"]:
                if not isinstance(transport, dict) or transport.get("id") is None:
                    raise TransportSearchError("Transport search returned an invalid transport record.")
                transport_id = str(transport["id"])
                if transport_id in seen_ids:
                    continue
                seen_ids.add(transport_id)

                if str(transport.get("status", "")).casefold() != "active":
                    continue
                if traveller_count is not None:
                    try:
                        if int(transport.get("capacity", 0)) < int(traveller_count):
                            continue
                    except (TypeError, ValueError):
                        continue
                if not _transport_route_matches(transport, requested_destinations):
                    continue
                if not _transport_date_matches(transport, start_date, end_date):
                    continue
                transports.append(transport)

            if page >= total_pages:
                break
            page += 1

        return transports
    except TransportSearchError:
        raise
    except Exception as error:
        # A later page failure must never be represented as a complete page-one
        # result. Callers receive a stable failure and no partial catalogue.
        raise TransportSearchError("Transport search could not be completed.") from error

def check_transport_availability(transport_id):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/transport/{transport_id}/availability"
    try:
        response = requests.get(endpoint, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error checking availability for transport {transport_id}: {e}")
        return None
