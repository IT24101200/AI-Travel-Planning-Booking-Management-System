"""Booking prices must agree with deterministic commercial validation."""

import json
from unittest.mock import Mock, patch

import pytest

from agents import booking_agent
from agents.validation_agent import validate_and_build_booking


@pytest.mark.parametrize("use_llm", [False, True])
def test_package_recalculates_schedule_and_backend_prices(use_llm):
    state = {
        "trip_request_id": 86,
        "customer_id": "customer-1",
        "destination_id": 41,
        "start_date": "2026-10-13T00:00:00Z",
        "end_date": "2026-10-19T00:00:00Z",
        "traveller_count": 2,
        "budget_ceiling": 300000,
        "currency": "LKR",
        "itinerary": {
            "total_estimated_cost": 59500,
            "schedule": [{"items": [{"tour_id": 15, "price": 29750}]}],
        },
    }
    response = Mock()
    response.json.return_value = {"choices": [{"message": {"content": json.dumps({
        "total_package_cost": 66300,
        "total_cost": 66300,
        "selected_room": {"room_id": 30, "price_per_night": 1},
        "selected_transport": {"transport_id": 40, "price": 1},
        "itinerary": {"schedule": []},
    })}}]}

    with (
        patch.object(booking_agent, "aiml_api_key", "test-key" if use_llm else None),
        patch.dict("os.environ", {"GOOGLE_API_KEY_BOOKING": "", "GEMINI_API_KEY": "", "GOOGLE_API_KEY": ""}),
        patch.object(booking_agent.requests, "post", return_value=response),
        patch.object(booking_agent, "log_agent_step"),
        patch.object(booking_agent, "search_hotels", return_value=[{"id": 21, "name": "KCC"}]),
        patch.object(booking_agent, "search_hotel_rooms", return_value=[{
            "id": 30, "capacity": 2, "roomType": "Double", "pricePerNight": 10000, "currency": "LKR",
        }]),
        patch.object(booking_agent, "check_room_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "search_transports", return_value=[{
            "id": 40, "capacity": 2, "price": 3150, "currency": "LKR",
        }]),
        patch.object(booking_agent, "check_transport_availability", return_value={"isAvailable": True}),
    ):
        package = booking_agent.build_booking_package(state)

    assert package["total_package_cost"] == 125800
    assert package["total_cost"] == 125800
    assert package["selected_room"]["price_per_night"] == 10000
    assert package["selected_transport"]["price"] == 3150
    assert package["itinerary"] == state["itinerary"]
    payload, _ = validate_and_build_booking({**state, "booking_details": package})
    assert payload["totalCost"] == 125800
