from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

import graph
from agents import booking_agent, coordinator_agent, itinerary_agent, validation_agent
from main import app
from route_planning import AIRPORTS, plan_overnights
from test_route_planning import LineRoads, tour
from tools.availability_tools import TransportSearchResult


@pytest.mark.parametrize("airport_pickup", [False, True])
@pytest.mark.parametrize("endpoint", ["/run-pipeline", "/run-pipeline-async"])
def test_selected_starter_survives_http_graph_itinerary_booking_and_validation(airport_pickup, endpoint):
    # The unconstrained optimizer chooses [2, 1, 3]. The customer instead
    # requires [1, ...], whose best remaining order is [3, 2].
    tours = [tour(1, 1, 81.7), tour(2, 2, 80), tour(3, 3, 81.8)]
    hotels = [{"id": t["destination_id"], "name": f"Hotel {t['destination_id']}",
               "latitude": t["latitude"], "longitude": t["longitude"]} for t in tours]
    transports = [
        {"id": 10, "routeFrom": "1", "routeTo": "3", "departureTime": "2026-10-11T12:00:00", "arrivalTime": "2026-10-11T13:00:00"},
        {"id": 11, "routeFrom": "3", "routeTo": "2", "departureTime": "2026-10-13T09:00:00", "arrivalTime": "2026-10-13T15:00:00"},
    ]
    if airport_pickup:
        transports.insert(0, {"id": 12, "routeFrom": AIRPORTS["CMB"]["name"], "routeTo": "1",
            "departureTime": "2026-10-10T07:00:00", "arrivalTime": "2026-10-10T12:00:00"})
    transports = TransportSearchResult([{**row, "type": "Van", "provider": "Test operator",
        "capacity": 4, "price": 50, "currency": "LKR"} for row in transports])
    request = {
        "trip_request_id": 187, "customer_id": "test-customer", "destination_id": 1,
        "starter_location_id": 1, "airport_pickup": airport_pickup, "airport_arrival_time": "06:00",
        "requested_destinations": [{"destination_id": i, "destination_name": str(i)} for i in [1, 2, 3]],
        "start_date": "2026-10-10", "end_date": "2026-10-15",
        "traveller_count": 2, "budget_ceiling": 100000, "currency": "LKR",
    }
    with (
        patch("route_planning.RoadMatrix", LineRoads),
        patch.object(coordinator_agent, "call_gemini_for_planning", return_value=None),
        patch.object(itinerary_agent, "search_tours", side_effect=lambda city, **_: [t for t in tours if t["destination_id"] == city]),
        patch.object(booking_agent, "search_hotels", return_value=hotels),
        patch.object(booking_agent, "search_hotel_rooms", side_effect=lambda hotel, **_: [
            {"id": hotel, "capacity": 4, "pricePerNight": 200, "currency": "LKR"}]),
        patch.object(booking_agent, "search_transports", return_value=transports),
        patch.object(booking_agent, "check_room_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "check_transport_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "plan_overnights", side_effect=lambda *args, **kwargs: plan_overnights(*args, matrix_factory=LineRoads, **kwargs)),
        patch.object(graph, "sync_result_to_backend", return_value=True) as callback,
        patch.object(graph, "log_agent_step"),
        patch("logger.log_agent_step"),
        patch.object(coordinator_agent, "log_agent_step"),
        patch.object(itinerary_agent, "log_agent_step"),
        patch.object(booking_agent, "log_agent_step"),
        patch.object(validation_agent, "log_agent_step"),
        TestClient(app) as client,
    ):
        response = client.post(endpoint, json=request)

    assert response.status_code == (202 if endpoint.endswith("-async") else 200)
    callback.assert_called_once()
    result = callback.call_args.kwargs
    assert result["final_status"] == "AwaitingApproval", result
    assert result["retry_count"] == 0
    plan = result["plan_json"]
    assert plan["itinerary"]["route_destination_ids"] == [1, 3, 2]
    visits = [item["destination_id"] for day in plan["itinerary"]["schedule"] for item in day["items"]]
    assert visits == [1, 3, 2]
    legs = plan["booking_details"]["transport_selections"]
    assert [leg["transport_option_id"] for leg in legs] == ([12, 10, 11] if airport_pickup else [10, 11])
    assert len(plan["booking_details"]["room_selections"]) >= 3


@pytest.mark.parametrize("route", [[2, 1, 3], [1, 3]])
def test_route_contract_failure_is_diagnosed_without_an_ineffective_budget_retry(route):
    state = {
        "trip_request_id": 187, "destination_id": 1, "starter_location_id": 1,
        "requested_destinations": [{"destination_id": i} for i in [1, 2, 3]],
        "itinerary": {"route_destination_ids": route}, "retry_count": 0,
    }
    with (
        patch.object(booking_agent, "log_agent_step"),
        patch.object(validation_agent, "log_agent_step"),
        patch.object(coordinator_agent, "log_agent_step"),
        patch.object(booking_agent, "search_hotels") as hotels,
    ):
        booked = booking_agent.booking_node(state)
        validated = validation_agent.validation_node(booked)
        evaluated = coordinator_agent.coordinator_retry_evaluator({**booked, **validated})

    hotels.assert_not_called()
    assert booked["status"] == "AvailabilityFailed"
    diagnostics = validated["validation_result"]["planning_diagnostics"]
    assert diagnostics["planned_destination_ids"] == route
    assert diagnostics["requested_destination_ids"] == [1, 2, 3]
    assert diagnostics["starter_location_id"] == 1
    assert evaluated["status"] == "Failed"
    assert evaluated["next_action"] == "fail"
