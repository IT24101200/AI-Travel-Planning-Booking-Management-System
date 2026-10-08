from unittest.mock import patch

from agents import booking_agent
from tools.availability_tools import TransportSearchResult


DESTINATIONS = [
    {"destination_id": 51, "destination_name": "Colombo", "order": 0},
    {"destination_id": 54, "destination_name": "Dambulla", "order": 1},
    {"destination_id": 56, "destination_name": "Arugam Bay", "order": 2},
]


def _state():
    return {
        "trip_request_id": 152,
        "destination_id": 51,
        "destination_name": "Colombo",
        "requested_destinations": DESTINATIONS,
        "start_date": "2026-10-15",
        "end_date": "2026-10-21",
        "traveller_count": 3,
        "currency": "LKR",
        "budget_ceiling": 250000,
        "itinerary": {"schedule": [], "total_cost": 0},
    }


def _transport(transport_id, route_from, route_to, price):
    return {
        "id": transport_id,
        "type": "Van",
        "provider": "Demo Private Transfer",
        "routeFrom": route_from,
        "routeTo": route_to,
        "departureTime": "2026-10-15T06:30:00",
        "arrivalTime": "2026-10-15T10:00:00",
        "capacity": 8,
        "price": price,
        "currency": "LKR",
        "status": "Active",
    }


def _run(transport_rows):
    with (
        patch.object(booking_agent, "search_hotels", return_value=[{"id": 1, "name": "Hotel"}]),
        patch.object(
            booking_agent,
            "search_hotel_rooms",
            return_value=[{"id": 2, "capacity": 3, "pricePerNight": 10000, "currency": "LKR"}],
        ),
        patch.object(booking_agent, "check_room_availability", return_value={"isAvailable": True}),
        patch.object(
            booking_agent,
            "search_transports",
            return_value=TransportSearchResult(transport_rows),
        ),
        patch.object(booking_agent, "check_transport_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "log_agent_step"),
    ):
        return booking_agent.build_booking_package(_state())


def test_multi_leg_selection_contains_one_transport_per_adjacent_leg():
    result = _run([
        _transport(10, "Colombo", "Dambulla", 6500),
        _transport(20, "Dambulla", "Arugam Bay", 8500),
    ])

    assert [item["transport_id"] for item in result["transport_selections"]] == [10, 20]
    assert [item["leg_index"] for item in result["transport_selections"]] == [0, 1]
    assert [item["transport_option_id"] for item in result["transport_selections"]] == [10, 20]
    assert "selected_transport" not in result
    assert result["persistence_status"] == "READY_FOR_PERSISTENCE"


def test_multi_leg_selection_fails_closed_with_missing_leg_details():
    result = _run([_transport(10, "Colombo", "Dambulla", 6500)])

    assert result["error_code"] == "TRANSPORT_CATALOGUE_NO_ROUTE"
    assert "Dambulla -> Arugam Bay" in result["error"]
    assert result["transport_diagnostics"]["missing_transport_legs"] == [
        "Dambulla -> Arugam Bay"
    ]
    assert "selected_transport" not in result
