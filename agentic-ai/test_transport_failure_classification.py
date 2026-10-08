from unittest.mock import patch

from agents import booking_agent, coordinator_agent, validation_agent
from tools.availability_tools import (
    TransportSearchResult,
    classify_transport_failure,
    search_transports,
)


DESTINATIONS = [
    {"destination_id": 50, "destination_name": "Batticaloa"},
    {"destination_id": 51, "destination_name": "Colombo"},
    {"destination_id": 34, "destination_name": "Ella"},
]


def _response(payload):
    class Response:
        def raise_for_status(self):
            return None

        def json(self):
            return payload

    return Response()


def _transport(
    transport_id,
    route_from="Colombo",
    route_to="Ella",
    day=15,
    capacity=12,
):
    return {
        "id": transport_id,
        "status": "Active",
        "capacity": capacity,
        "routeFrom": route_from,
        "routeTo": route_to,
        "departureTime": f"2026-10-{day:02d}T08:00:00",
        "arrivalTime": f"2026-10-{day:02d}T10:00:00",
        "price": 3500,
        "currency": "LKR",
    }


def _search(**kwargs):
    return search_transports(
        requested_destinations=DESTINATIONS,
        start_date="2026-10-15",
        end_date="2026-10-21",
        traveller_count=3,
        **kwargs,
    )


def test_no_route_match_is_classified_without_a_retry_candidate():
    rows = [_transport(index, "Kandy", "Galle") for index in range(1, 23)]
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response({"data": rows, "totalPages": 1}),
    ):
        result = _search()

    assert result == []
    assert result.diagnostics["active_count"] == 22
    assert result.diagnostics["route_compatible_count"] == 0
    assert classify_transport_failure(result.diagnostics) == "TRANSPORT_CATALOGUE_NO_ROUTE"


def test_route_match_with_date_mismatch_is_classified_as_no_date_match():
    rows = [
        _transport(27, day=13),
        _transport(28, day=13),
    ]
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response({"data": rows, "totalPages": 1}),
    ):
        result = _search()

    assert result == []
    assert result.diagnostics["route_compatible_count"] == 2
    assert result.diagnostics["date_compatible_count"] == 0
    assert result.diagnostics["missing_route_legs"] == ["Batticaloa -> Colombo"]
    assert classify_transport_failure(result.diagnostics) == "TRANSPORT_CATALOGUE_NO_DATE_MATCH"


def test_route_and_date_match_with_insufficient_capacity_is_classified():
    rows = [_transport(90, day=15, capacity=2)]
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response({"data": rows, "totalPages": 1}),
    ):
        result = _search()

    assert result == []
    assert result.diagnostics["capacity_compatible_count"] == 0
    assert classify_transport_failure(result.diagnostics) == "TRANSPORT_CATALOGUE_NO_CAPACITY"


def test_transient_transport_failure_remains_retryable():
    with patch.object(coordinator_agent, "log_agent_step"):
        result = coordinator_agent.coordinator_retry_evaluator(
            {
                "trip_request_id": 150,
                "retry_count": 0,
                "validation_result": {
                    "is_valid": False,
                    "error_code": "UPSTREAM_BOOKING_FAILED",
                    "upstream_error_code": "TRANSPORT_SEARCH_INCOMPLETE",
                    "error": "Transport search could not be completed.",
                },
            }
        )

    assert result["next_action"] == "retry"
    assert result["retry_count"] == 1


def test_non_retryable_catalogue_failure_terminates_once():
    with patch.object(coordinator_agent, "log_agent_step") as log_step:
        result = coordinator_agent.coordinator_retry_evaluator(
            {
                "trip_request_id": 150,
                "retry_count": 0,
                "validation_result": {
                    "is_valid": False,
                    "error_code": "UPSTREAM_BOOKING_FAILED",
                    "upstream_error_code": "TRANSPORT_CATALOGUE_NO_DATE_MATCH",
                    "error": "No suitable transport is available for the selected route and travel dates.",
                },
            }
        )

    assert result["status"] == "Failed"
    assert result["next_action"] == "fail"
    assert result["failure_code"] == "TRANSPORT_CATALOGUE_NO_DATE_MATCH"
    assert [call.kwargs["step_name"] for call in log_step.call_args_list] == [
        "TerminateTripPlanning"
    ]


def test_zero_transport_candidates_log_tool_success_and_booking_failure():
    state = {
        "trip_request_id": 150,
        "destination_id": 50,
        "destination_name": "Batticaloa",
        "requested_destinations": DESTINATIONS,
        "start_date": "2026-10-15",
        "end_date": "2026-10-21",
        "traveller_count": 3,
        "currency": "LKR",
        "itinerary": {"schedule": [], "total_cost": 100},
    }
    transport_result = TransportSearchResult(
        [],
        {
            "active_count": 22,
            "capacity_compatible_count": 22,
            "route_compatible_count": 2,
            "date_compatible_count": 0,
            "route_mismatch_count": 20,
            "date_mismatch_count": 2,
            "missing_route_legs": ["Batticaloa -> Colombo"],
        },
    )
    with patch.object(booking_agent, "log_agent_step") as log_step, patch.object(
        booking_agent, "search_hotels", return_value=[{"id": 1, "name": "Hotel"}]
    ), patch.object(
        booking_agent,
        "search_hotel_rooms",
        return_value=[{"id": 2, "capacity": 3, "pricePerNight": 100, "currency": "LKR"}],
    ), patch.object(
        booking_agent,
        "check_room_availability",
        return_value={"isAvailable": True},
    ), patch.object(
        booking_agent, "search_transports", return_value=transport_result
    ):
        result = booking_agent.build_booking_package(state)

    assert result["error_code"] == "TRANSPORT_CATALOGUE_NO_ROUTE"
    assert result["agent_status"] == "Failed"
    assert [call.kwargs.get("status", "Success") for call in log_step.call_args_list] == [
        "Success",
        "Success",
        "Failed",
    ]
    assert log_step.call_args_list[-1].kwargs["step_type"] == "Outcome"


def test_validation_preserves_upstream_transport_failure_code():
    with patch.object(validation_agent, "log_agent_step"):
        result = validation_agent.validation_node(
            {
                "trip_request_id": 150,
                "booking_details": {
                    "status": "AvailabilityFailed",
                    "error_code": "TRANSPORT_CATALOGUE_NO_DATE_MATCH",
                    "error": "No suitable transport is available for the selected route and travel dates.",
                },
            }
        )

    assert result["validation_result"]["is_valid"] is False
    assert result["validation_result"]["upstream_error_code"] == "TRANSPORT_CATALOGUE_NO_DATE_MATCH"
