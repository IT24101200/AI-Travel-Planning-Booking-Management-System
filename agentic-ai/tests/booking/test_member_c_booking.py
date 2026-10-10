"""Member C / IT24101460: ground selections in available rooms and vehicles."""

import json
from unittest.mock import Mock
import pytest
from agents import booking_agent as agent

pytestmark = pytest.mark.member_c


@pytest.fixture
def inventory(monkeypatch):
    monkeypatch.setattr(agent, "aiml_api_key", "test-only-key")
    monkeypatch.setattr(agent, "search_hotels", lambda *a, **k: [{"id": 10, "name": "Test Hotel"}])
    monkeypatch.setattr(agent, "search_hotel_rooms", lambda *a, **k: [
        {"id": 20, "capacity": 2, "pricePerNight": 3000, "currency": "LKR"}])
    monkeypatch.setattr(agent, "check_room_availability", lambda *a, **k: {"isAvailable": True})
    monkeypatch.setattr(agent, "search_transports", lambda *a, **k: [
        {"id": 30, "capacity": 4, "price": 1000, "currency": "LKR"}])
    monkeypatch.setattr(agent, "check_transport_availability", lambda *a, **k: {"isAvailable": True})
    return {"trip_request_id": 3, "destination_id": 1, "start_date": "2026-10-10",
            "end_date": "2026-10-13", "traveller_count": 2, "budget_ceiling": 50000,
            "itinerary": {"schedule": [{"items": [{"tour_id": 40, "price": 500}]}]}}


@pytest.mark.parametrize("room_id,transport_id,code", [
    (999, 30, "INVALID_ROOM_SELECTION"), (20, 999, "INVALID_TRANSPORT_SELECTION"),
    (20, 30, None),
])
def test_model_ids_are_checked_and_model_prices_are_replaced(monkeypatch, inventory, room_id, transport_id, code):
    response = Mock()
    response.json.return_value = {"choices": [{"message": {"content": json.dumps({
        "selected_room": {"room_id": room_id, "price_per_night": 1},
        "selected_transport": {"transport_id": transport_id, "price": 1},
        "itinerary": {"schedule": []}, "total_package_cost": 1,
    })}}]}
    monkeypatch.setattr(agent.requests, "post", lambda *a, **k: response)
    result = agent.build_booking_package(inventory)
    if code:
        assert result["error_code"] == code
    else:
        # Two travellers: tours 1,000 + three room nights 9,000 + seats 2,000.
        assert result["total_package_cost"] == 12000
        assert result["itinerary"] == inventory["itinerary"]
        assert result["selected_room"]["price_per_night"] == 3000


def test_unavailable_rooms_stop_before_model_selection(monkeypatch, inventory):
    monkeypatch.setattr(agent, "check_room_availability", lambda *a, **k: {"isAvailable": False})
    model = Mock()
    monkeypatch.setattr(agent.requests, "post", model)
    assert agent.build_booking_package(inventory)["error_code"] == "NO_VALID_ROOM"
    model.assert_not_called()
