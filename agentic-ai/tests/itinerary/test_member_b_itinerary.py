"""Member B / IT24100421: preserve the handoff contract and reject invented tours."""

import pytest
from agents import itinerary_agent as agent

pytestmark = pytest.mark.member_b


@pytest.mark.parametrize("airport", [False, True])
def test_adapter_preserves_selected_starter_before_route_planning(monkeypatch, airport):
    captured = []
    monkeypatch.setattr(agent, "build_itinerary", lambda request: captured.append(request) or {"schedule": [], "total_estimated_cost": 0})
    state = {"trip_request_id": 2, "destination_id": 1, "starter_location_id": 2,
             "airport_pickup": airport, "airport_arrival_time": "18:00",
             "requested_destinations": [{"destination_id": 1}, {"destination_id": 2}]}
    agent.itinerary_node(state)
    assert captured[0]["starter_location_id"] == 2
    assert captured[0]["airport_pickup"] == airport
    assert [d["destination_id"] for d in captured[0]["requested_destinations"]] == [1, 2]


def test_invented_tour_is_rejected_even_when_model_claims_zero_cost():
    result = {"total_estimated_cost": 0, "schedule": [{"day_number": 1, "items": [
        {"tour_id": 99999, "destination_id": 1, "price": 0, "start_time": "09:00:00", "end_time": "10:00:00"},
    ]}]}
    valid, errors = agent.validate_itinerary(result, {
        "destination_id": 1, "start_date": "2026-10-10", "end_date": "2026-10-12",
        "budget_ceiling": 10000, "traveller_count": 2,
    }, [{"id": 10, "destination_id": 1, "status": "Active", "price": 1000}])
    assert not valid
    assert any("99999" in message for message in errors)
