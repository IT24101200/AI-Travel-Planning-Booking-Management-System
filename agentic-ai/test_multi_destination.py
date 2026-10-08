import os
from unittest.mock import patch

import pytest

from agents.itinerary_agent import build_itinerary, validate_itinerary
from destination_contract import DestinationContractError, normalize_requested_destinations


DESTINATIONS = [
    {"destination_id": 11, "destination_name": "Anuradhapura", "order": 0},
    {"destination_id": 22, "destination_name": "Colombo", "order": 1},
    {"destination_id": 33, "destination_name": "Jaffna", "order": 2},
]


def _tour(tour_id, destination_id, destination_name):
    return {
        "id": tour_id,
        "name": f"{destination_name} tour",
        "destination_id": destination_id,
        "destination_name": destination_name,
        "price": 100,
        "duration_hours": 2,
        "category": "Culture",
        "default_start_time": "09:00:00",
        "status": "Active",
        "latitude": 7.0,
        "longitude": 80.0 + destination_id / 100,
    }


def _request(destinations=DESTINATIONS):
    return {
        "trip_request_id": 700,
        "destination_id": destinations[0]["destination_id"] if destinations else None,
        "destination_name": destinations[0]["destination_name"] if destinations else "",
        "requested_destinations": destinations,
        "start_date": "2026-10-10",
        "end_date": "2026-10-16",
        "traveller_count": 2,
        "budget_ceiling": 350000,
        "currency": "LKR",
        "preferred_activities": [],
    }


class _UnavailableLlmResponse:
    status_code = 503


class _UnavailableLlmClient:
    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return False

    def post(self, *_args, **_kwargs):
        return _UnavailableLlmResponse()


class _OfflineRoads:
    def __init__(self, records):
        pass

    def leg(self, a, b):
        distance = abs(a['longitude'] - b['longitude']) * 100
        return distance, distance * 1.5


def test_exact_three_destinations_are_searched_and_scheduled_in_order():
    tours = [
        _tour(101, 11, "Anuradhapura"),
        _tour(202, 22, "Colombo"),
        _tour(303, 33, "Jaffna"),
    ]
    calls = []

    def search(destination_id, **_kwargs):
        calls.append(destination_id)
        return [tour for tour in tours if tour["destination_id"] == destination_id]

    with patch("route_planning.RoadMatrix", _OfflineRoads), patch("agents.itinerary_agent.search_tours", side_effect=search), patch(
        "httpx.Client", return_value=_UnavailableLlmClient()
    ), patch.dict(os.environ, {"GOOGLE_API_KEY_ITINERARY": "test-key"}):
        result = build_itinerary(_request())

    scheduled_ids = [
        item["destination_id"]
        for day in result["schedule"]
        for item in day["items"]
    ]
    assert calls == [11, 22, 33]
    assert scheduled_ids == [11, 22, 33]
    assert result["schedule"][0]["items"][0]["destination_name"] == "Anuradhapura"


def test_validation_rejects_missing_jaffna_coverage():
    request = _request()
    available = [
        _tour(101, 11, "Anuradhapura"),
        _tour(202, 22, "Colombo"),
        _tour(303, 33, "Jaffna"),
    ]
    itinerary = {
        "schedule": [
            {
                "day_number": 1,
                "items": [
                    {
                        "tour_id": 101,
                        "destination_id": 11,
                        "start_time": "09:00:00",
                        "end_time": "11:00:00",
                        "price": 100,
                    },
                    {
                        "tour_id": 202,
                        "destination_id": 22,
                        "start_time": "11:00:00",
                        "end_time": "13:00:00",
                        "price": 100,
                    },
                ],
            }
        ]
    }

    valid, errors = validate_itinerary(itinerary, request, available)

    assert not valid
    assert any("Jaffna" in error for error in errors)


def test_single_destination_legacy_contract_still_works():
    request = _request(DESTINATIONS[:1])
    request.pop("requested_destinations")
    with patch("route_planning.RoadMatrix", _OfflineRoads), patch(
        "agents.itinerary_agent.search_tours",
        return_value=[_tour(101, 11, "Anuradhapura")],
    ), patch("httpx.Client", return_value=_UnavailableLlmClient()), patch.dict(
        os.environ, {"GOOGLE_API_KEY_ITINERARY": "test-key"}
    ):
        result = build_itinerary(request)

    assert result["schedule"][0]["items"][0]["destination_id"] == 11


def test_unknown_destination_id_is_rejected_by_contract():
    with pytest.raises(DestinationContractError) as error:
        normalize_requested_destinations(
            {"requested_destinations": [{"destination_id": 0, "destination_name": "Unknown"}]},
            required=True,
        )

    assert error.value.code == "DESTINATION_ID_INVALID"


def test_zero_tour_destination_fails_explicitly():
    def search(destination_id, **_kwargs):
        if destination_id == 33:
            return []
        return [_tour(destination_id + 100, destination_id, str(destination_id))]

    with patch("agents.itinerary_agent.search_tours", side_effect=search):
        result = build_itinerary(_request())

    assert result["error_code"] == "ZERO_TOUR_DESTINATION"
    assert result["destination_id"] == 33
