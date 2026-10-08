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


class TransportSearchResult(list):
    """List-compatible transport results with deterministic filter diagnostics."""

    def __init__(self, values=(), diagnostics=None):
        super().__init__(values)
        self.diagnostics = diagnostics or {}


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


def _requested_route_legs(requested_destinations):
    if requested_destinations is None:
        return []
    names = [
        _normalize_route_name(item.get("destination_name", item.get("name")))
        for item in requested_destinations
        if isinstance(item, dict)
    ]
    names = [name for name in names if name]
    return list(zip(names, names[1:]))


def _route_label(source, target):
    return f"{source.title()} -> {target.title()}"


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


def _fetch_transport_pages(endpoint, base_params):
    """Read every page for one server-side query or fail closed."""

    rows = []
    page = 1
    total_pages = 1
    while page <= total_pages:
        params = dict(base_params)
        params["page"] = page
        params["pageSize"] = TRANSPORT_PAGE_SIZE
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
        elif page == 1:
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
            rows.append(transport)

        if page >= total_pages:
            break
        page += 1
    return rows


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
    requested_legs = _requested_route_legs(requested_destinations)
    diagnostics = {
        "raw_count": 0,
        "active_count": 0,
        "capacity_compatible_count": 0,
        "route_compatible_count": 0,
        "date_compatible_count": 0,
        "availability_compatible_count": None,
        "capacity_mismatch_count": 0,
        "route_mismatch_count": 0,
        "date_mismatch_count": 0,
        "availability_mismatch_count": 0,
        "route_coverage": {
            _route_label(source, target): 0
            for source, target in requested_legs
        },
        "missing_route_legs": [],
    }
    try:
        # Multi-destination requests query each ordered leg at the API. The
        # exact client-side comparison remains in place as a fail-closed guard
        # against broad/incorrect server filtering. Legacy single-destination
        # and unscoped calls retain the complete-catalogue query.
        route_queries = requested_legs or [None]
        for route in route_queries:
            params = {}
            if currency:
                params["currency"] = currency
            if route is not None:
                params["routeFrom"] = route[0]
                params["routeTo"] = route[1]
                params["status"] = "Active"

            for transport in _fetch_transport_pages(endpoint, params):
                transport_id = str(transport["id"])
                if transport_id in seen_ids:
                    continue
                seen_ids.add(transport_id)
                diagnostics["raw_count"] += 1

                if str(transport.get("status", "")).casefold() != "active":
                    continue
                diagnostics["active_count"] += 1

                route_from = _normalize_route_name(transport.get("routeFrom"))
                route_to = _normalize_route_name(transport.get("routeTo"))
                if requested_legs:
                    for source, target in requested_legs:
                        if route_from == source and route_to == target:
                            diagnostics["route_coverage"][_route_label(source, target)] += 1

                if traveller_count is not None:
                    try:
                        if int(transport.get("capacity", 0)) < int(traveller_count):
                            diagnostics["capacity_mismatch_count"] += 1
                            continue
                    except (TypeError, ValueError):
                        diagnostics["capacity_mismatch_count"] += 1
                        continue
                diagnostics["capacity_compatible_count"] += 1
                if not _transport_route_matches(transport, requested_destinations):
                    diagnostics["route_mismatch_count"] += 1
                    continue
                diagnostics["route_compatible_count"] += 1
                if not _transport_date_matches(transport, start_date, end_date):
                    diagnostics["date_mismatch_count"] += 1
                    continue
                diagnostics["date_compatible_count"] += 1
                transports.append(transport)

        diagnostics["missing_route_legs"] = [
            label
            for label, count in diagnostics["route_coverage"].items()
            if count == 0
        ]
        diagnostics["final_count"] = len(transports)
        return TransportSearchResult(transports, diagnostics)
    except TransportSearchError:
        raise
    except Exception as error:
        # A later page failure must never be represented as a complete page-one
        # result. Callers receive a stable failure and no partial catalogue.
        raise TransportSearchError("Transport search could not be completed.") from error


TRANSPORT_CATALOGUE_FAILURE_CODES = {
    "TRANSPORT_CATALOGUE_NO_ROUTE",
    "TRANSPORT_CATALOGUE_NO_DATE_MATCH",
    "TRANSPORT_CATALOGUE_NO_CAPACITY",
    "TRANSPORT_CATALOGUE_NO_AVAILABILITY",
}


def classify_transport_failure(diagnostics, availability_mismatch_count=0):
    """Return the most specific deterministic reason for zero options."""

    diagnostics = diagnostics or {}
    active_count = diagnostics.get("active_count")
    capacity_count = diagnostics.get("capacity_compatible_count")
    route_count = diagnostics.get("route_compatible_count")
    date_count = diagnostics.get("date_compatible_count")

    if active_count == 0:
        return "TRANSPORT_CATALOGUE_NO_ROUTE"
    if capacity_count == 0:
        return "TRANSPORT_CATALOGUE_NO_CAPACITY"
    if route_count == 0:
        return "TRANSPORT_CATALOGUE_NO_ROUTE"
    if date_count == 0:
        return "TRANSPORT_CATALOGUE_NO_DATE_MATCH"
    if availability_mismatch_count or diagnostics.get("availability_compatible_count") == 0:
        return "TRANSPORT_CATALOGUE_NO_AVAILABILITY"
    return "TRANSPORT_CATALOGUE_NO_AVAILABILITY"


def check_transport_availability(transport_id):
    endpoint = f"{BACKEND_BASE_URL.rstrip('/')}/api/transport/{transport_id}/availability"
    try:
        response = requests.get(endpoint, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error checking availability for transport {transport_id}: {e}")
        return None
