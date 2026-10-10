from unittest.mock import Mock, patch

import pytest
import requests

from agents.booking_agent import build_booking_package
from agents.itinerary_agent import validate_itinerary
from route_planning import choose_tours
from tools.availability_tools import check_room_availability
from tools.search_tours import unique_tours


def tour(tour_id, **changes):
    return {"id": tour_id, "destination_id": 1, "name": "Forest Walk",
            "category": "Nature", "description": "Guided walk", "price": 40800,
            "currency": "LKR", "duration": 2, "default_start_time": "09:00:00",
            "latitude": 7, "longitude": 80, "status": "Active", **changes}


def test_identical_tours_keep_one_but_same_price_and_different_data_remain():
    rows = [tour(1), tour(2), tour(3, name="Temple Visit"), tour(4, duration=3),
            tour(5, description="Private guided walk"), tour(1, name="Repeated ID")]
    assert [row["id"] for row in unique_tours(rows)] == [1, 3, 4, 5]


def test_geographic_selection_does_not_charge_identical_tours_twice():
    selected = choose_tours({"budget_ceiling": 200000, "traveller_count": 2,
                             "start_date": "2026-10-10", "end_date": "2026-10-14"},
                            [tour(1), tour(2), tour(1, description="Changed metadata")],
                            [{"destination_id": 1, "destination_name": "Kandy"}])
    assert [row["id"] for row in selected] == [1]
    assert sum(row["price"] * 2 for row in selected) == 81600


def test_repeated_tour_across_days_is_rejected_before_inventory_search():
    item = {"tour_id": 1, "destination_id": 1, "price": 40800,
            "start_time": "09:00:00", "end_time": "11:00:00"}
    itinerary = {"schedule": [{"day_number": day, "items": [dict(item)]} for day in (1, 2)]}
    state = {"destination_id": 1, "traveller_count": 1, "budget_ceiling": 200000,
             "start_date": "2026-10-10", "end_date": "2026-10-14"}
    valid, errors = validate_itinerary(itinerary, state, [tour(1)])
    assert not valid
    assert any("more than once" in error for error in errors)
    with patch("agents.booking_agent.search_hotels") as hotels:
        result = build_booking_package({**state, "itinerary": itinerary})
    assert result["error_code"] == "DUPLICATE_ITINERARY_TOUR"
    hotels.assert_not_called()


def test_room_availability_recovers_from_one_timeout():
    response = Mock()
    response.json.return_value = {"isAvailable": True}
    with patch("tools.availability_tools.requests.get", side_effect=[requests.ReadTimeout(), response]) as get:
        assert check_room_availability(1, 94, "2026-10-10", "2026-10-11") == {"isAvailable": True}
    assert get.call_count == 2


@pytest.mark.parametrize("error", [requests.ReadTimeout(), requests.HTTPError()])
def test_availability_retry_is_bounded_and_does_not_claim_availability(error):
    with patch("tools.availability_tools.requests.get", side_effect=error) as get:
        assert check_room_availability(1, 124, "2026-10-10", "2026-10-11") is None
    assert get.call_count == (2 if isinstance(error, requests.Timeout) else 1)
