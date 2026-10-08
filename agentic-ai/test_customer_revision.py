from copy import deepcopy
from unittest.mock import patch

import pytest

from agents import booking_agent, itinerary_agent
from customer_revision import room_requested
from route_planning import plan_overnights
from test_route_planning import LineRoads, itinerary, state, tour
from tools.availability_tools import TransportSearchResult


@pytest.mark.parametrize("selected_room,selected_transport", [(2, 31), (1, 30)])
def test_revision_uses_exact_dated_rooms_and_transport_even_if_cheaper_same_timetable_exists(selected_room, selected_transport):
    tours = [tour(1, 1, 80), tour(2, 2, 80.2)]
    baseline = {**itinerary(tours), "route_destination_ids": [1, 2]}
    revision = {"id": "request-1", "status": "Pending", "baseline_itinerary": baseline,
        "rooms": [{"room_id": selected_room, "check_in": "2026-10-10", "check_out": "2026-10-14"}],
        "transports": [{"transport_option_id": selected_transport, "leg_index": 0}],
        "reserved_items": [{"room_id": 1, "quantity": 1, "check_in": "2026-10-10", "check_out": "2026-10-14"},
                           {"transport_option_id": 30, "quantity": 1}]}
    request = {**state(5), "trip_request_id": 1, "destination_id": 1, "destination_name": "West",
        "requested_destinations": [{"destination_id": 1, "destination_name": "West"}, {"destination_id": 2, "destination_name": "East"}],
        "revision_request": revision, "itinerary": deepcopy(baseline)}
    rows = [{"id": i, "routeFrom": "West", "routeTo": "East", "type": "Van", "provider": f"Provider {i}",
             "departureTime": "2026-10-12T09:00:00", "arrivalTime": "2026-10-12T10:00:00", "capacity": 1,
             "price": 10 if i == 30 else 50, "currency": "LKR"} for i in (30, 31)]
    with (
        patch.object(booking_agent, "search_hotels", return_value=[{"id": 1, "name": "Current", "latitude": 7, "longitude": 80.1},
                                                                  {"id": 2, "name": "Nearby", "latitude": 7, "longitude": 80.11}]),
        patch.object(booking_agent, "search_hotel_rooms", side_effect=lambda hotel, **_: [{"id": hotel, "capacity": 2, "pricePerNight": 200 if hotel == 1 else 300, "currency": "LKR"}]),
        patch.object(booking_agent, "check_room_availability", side_effect=lambda hotel, *_args, **_kwargs: {"availableRooms": 0 if hotel == 1 else 1}),
        patch.object(booking_agent, "search_transports", return_value=TransportSearchResult(rows)),
        patch.object(booking_agent, "check_transport_availability", side_effect=lambda i: {"availableSeats": 0 if i == 30 else 1}),
        patch.object(booking_agent, "plan_overnights", side_effect=lambda *args: plan_overnights(*args, matrix_factory=LineRoads)),
        patch.object(booking_agent, "log_agent_step"),
    ):
        package = booking_agent.build_booking_package(request)
    assert "error" not in package, package
    assert [s["transport_option_id"] for s in package["transport_selections"]] == [selected_transport]
    assert {r["room_id"] for r in package["room_selections"]} == {selected_room}
    assert sum(r["nights"] for r in package["room_selections"]) == 4
    assert [t["tour_id"] for d in package["itinerary"]["schedule"] for t in d["items"]] == [1, 2]
    assert all(day["travel_minutes"] <= 600 for day in package["itinerary"]["schedule"])


def test_room_pins_are_dated_and_checkout_is_exclusive():
    revision = {"rooms": [{"room_id": 1, "check_in": "2026-10-10", "check_out": "2026-10-12"},
                           {"room_id": 2, "check_in": "2026-10-12", "check_out": "2026-10-14"}]}
    assert room_requested(revision, 1, "2026-10-10", "2026-10-12")
    assert not room_requested(revision, 1, "2026-10-10", "2026-10-13")
    assert room_requested(revision, 2, "2026-10-12", "2026-10-14")
    assert not room_requested(revision, 2, "2026-10-11", "2026-10-12")


def test_itinerary_revision_keeps_journeys_and_refreshes_catalogue_prices():
    baseline = {**itinerary([tour(1, 1, 80), tour(2, 2, 80.2)]), "route_destination_ids": [1, 2]}
    original = deepcopy(baseline)
    request = {**state(5), "trip_request_id": 1, "requested_destinations": [
        {"destination_id": 1, "destination_name": "West"}, {"destination_id": 2, "destination_name": "East"}],
        "revision_request": {"baseline_itinerary": baseline}}
    with patch.object(itinerary_agent, "search_tours", side_effect=lambda city, **_: [{**tour(city, city, 80), "price": 150}]), patch.object(itinerary_agent, "log_agent_step"):
        result = itinerary_agent.build_itinerary(request)
    assert result["total_estimated_cost"] == 300
    assert result["route_destination_ids"] == [1, 2]
    assert [t["tour_id"] for d in result["schedule"] for t in d["items"]] == [1, 2]
    assert baseline == original


def test_pipeline_failure_callback_carries_revision_id_so_original_can_be_restored():
    import graph
    revision = {"id": "request-1", "status": "Pending"}
    with patch.object(graph.travel_app, "invoke", side_effect=RuntimeError("Failure")), patch.object(graph, "log_agent_step"), patch.object(graph, "sync_result_to_backend") as callback:
        result = graph.run_travel_planning_pipeline({"trip_request_id": 1, "revision_request": revision})
    assert callback.call_args.kwargs["plan_json"]["revision_request"]["id"] == "request-1"
    assert result["status"] == "Failed"


def test_async_api_accepts_structured_revision():
    from main import TripPipelineRequest
    revision = {"id": "request-1", "rooms": [{"room_id": 2}], "transports": [{"transport_option_id": 31, "leg_index": 0}]}
    request = TripPipelineRequest(trip_request_id=1, start_date="2026-10-10", end_date="2026-10-14", budget_ceiling=100000, revision_request=revision)
    assert request.model_dump()["revision_request"] == revision
