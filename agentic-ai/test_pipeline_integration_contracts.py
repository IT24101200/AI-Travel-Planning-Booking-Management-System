"""Focused integration-contract tests for the A -> B -> C -> D pipeline."""

import os
from unittest.mock import patch

from fastapi import BackgroundTasks

from agents import booking_agent, itinerary_agent
from tools.itinerary_tools import ItineraryPersistenceError, persist_itinerary


def _state():
    return {
        "trip_request_id": 123,
        "customer_id": "customer-1",
        "destination_id": 5,
        "destination_name": "Kandy",
        "start_date": "2026-10-10T00:00:00Z",
        "end_date": "2026-10-14T00:00:00Z",
        "traveller_count": 2,
        "budget_ceiling": 2000,
        "currency": "USD",
        "access_token": "test-token",
        "itinerary": {
            "itinerary_id": 42,
            "total_estimated_cost": 200,
            "total_cost": 200,
            "currency": "USD",
            "schedule": [],
        },
    }


def _tour():
    return {
        "id": 15,
        "name": "Kandy Heritage Walk",
        "price": 100,
        "duration_hours": 3,
        "category": "Heritage",
        "default_start_time": "09:00:00",
        "status": "Active",
    }


def test_itinerary_module_imports_without_gemini_key():
    assert callable(itinerary_agent.itinerary_node)


@patch("agents.itinerary_agent.search_tours", return_value=[_tour()])
def test_missing_gemini_key_returns_clean_configuration_failure(_search):
    request = {
        "trip_request_id": 123,
        "destination_id": 5,
        "destination_name": "Kandy",
        "start_date": "2026-10-10T00:00:00Z",
        "end_date": "2026-10-14T00:00:00Z",
        "traveller_count": 2,
        "budget_ceiling": 700,
        "currency": "USD",
        "preferred_activities": [],
    }
    with patch.dict(
        os.environ,
        {
            "GOOGLE_API_KEY_ITINERARY": "",
            "GEMINI_API_KEY": "",
            "GOOGLE_API_KEY": "",
        },
    ):
        result = itinerary_agent.build_itinerary(request)

    assert result["error_code"] == "MISSING_ITINERARY_API_KEY"
    assert result["status"] == "ConfigurationFailed"


@patch("agents.itinerary_agent.search_tours", return_value=[])
def test_no_tours_returns_clean_failure_without_fake_ids(_search):
    result = itinerary_agent.build_itinerary(
        {
            "trip_request_id": 123,
            "destination_id": 5,
            "destination_name": "Kandy",
            "start_date": "2026-10-10",
            "end_date": "2026-10-14",
            "traveller_count": 2,
            "budget_ceiling": 700,
            "currency": "USD",
            "preferred_activities": [],
        }
    )

    assert result["error_code"] == "NO_VALID_TOURS"
    assert "101" not in str(result)


@patch("agents.itinerary_agent.build_itinerary")
def test_itinerary_node_returns_proposal_without_persisting(build_mock):
    build_mock.return_value = {
        "itinerary_id": None,
        "total_estimated_cost": 200,
        "currency": "USD",
        "schedule": [],
    }
    result = itinerary_agent.itinerary_node(_state())

    assert result["itinerary"]["itinerary_id"] is None
    assert result["itinerary"]["currency"] == "USD"
    assert result["itinerary"]["schedule"] == []


class _Response:
    def __init__(self, status_code, body):
        self.status_code = status_code
        self._body = body
        self.text = str(body)

    def json(self):
        return self._body


class _ItineraryClient:
    def __init__(self):
        self.calls = []

    def post(self, url, **kwargs):
        self.calls.append((url, kwargs))
        if url.endswith("/api/itinerary"):
            return _Response(201, {"id": 42})
        return _Response(200, {"id": 9})


def test_direct_itinerary_persistence_is_disabled():
    state = _state()
    itinerary = {
        "schedule": [
            {
                "day_number": 1,
                "items": [
                    {
                        "tour_id": 15,
                        "start_time": "09:00:00",
                        "end_time": "12:00:00",
                    }
                ],
            }
        ]
    }
    client = _ItineraryClient()

    try:
        persist_itinerary(state, itinerary, client=client)
    except ItineraryPersistenceError as error:
        assert "Direct AI itinerary persistence is disabled" in str(error)
    else:
        raise AssertionError("AI must not persist itineraries directly.")
    assert client.calls == []


@patch("agents.booking_agent.search_hotels", return_value=[])
@patch("agents.booking_agent.search_transports", return_value=[])
def test_no_rooms_returns_clean_failure_without_fallback_ids(_transport, _hotels):
    result = booking_agent.build_booking_package(_state())

    assert result["error_code"] == "NO_VALID_ROOM"
    assert "301" not in str(result)


@patch("agents.booking_agent.check_transport_availability", return_value={"isAvailable": True})
@patch(
    "agents.booking_agent.search_transports",
    return_value=[{"id": 7, "capacity": 4, "price": 100, "currency": "USD"}],
)
@patch("agents.booking_agent.check_room_availability", return_value={"isAvailable": True})
@patch(
    "agents.booking_agent.search_hotel_rooms",
    return_value=[{"id": 10, "capacity": 2, "pricePerNight": 100, "currency": "USD"}],
)
@patch(
    "agents.booking_agent.search_hotels",
    return_value=[{"id": 6, "name": "Real Hotel", "status": "Active"}],
)
def test_no_transport_returns_clean_failure_without_fallback_ids(
    _hotels, _rooms, _room_availability, _transports, _transport_availability
):
    _transport_availability.return_value = {"isAvailable": False}
    result = booking_agent.build_booking_package(_state())

    assert result["error_code"] == "TRANSPORT_CATALOGUE_NO_AVAILABILITY"
    assert "401" not in str(result)


class _LlmResponse:
    def raise_for_status(self):
        return None

    def json(self):
        return {
            "choices": [
                {
                    "message": {
                        "content": (
                            '{"total_package_cost": 800, "currency": "USD", '
                            '"itinerary": {}, '
                            '"selected_room": {"hotel_id": 6, "room_id": 10, '
                            '"price_per_night": 100}, '
                            '"selected_transport": {"transport_id": 7, '
                            '"price": 100}}'
                        )
                    }
                }
            ]
        }


@patch("agents.booking_agent.requests.post", return_value=_LlmResponse())
@patch("agents.booking_agent.check_transport_availability", return_value={"isAvailable": True})
@patch(
    "agents.booking_agent.search_transports",
    return_value=[{"id": 7, "capacity": 4, "price": 100, "currency": "USD"}],
)
@patch("agents.booking_agent.check_room_availability", return_value={"isAvailable": True})
@patch(
    "agents.booking_agent.search_hotel_rooms",
    return_value=[{"id": 10, "capacity": 2, "pricePerNight": 100, "currency": "USD"}],
)
@patch(
    "agents.booking_agent.search_hotels",
    return_value=[{"id": 6, "name": "Real Hotel", "status": "Active"}],
)
def test_successful_booking_package_preserves_real_ids_currency_and_itinerary(
    _hotels,
    _rooms,
    _room_availability,
    _transports,
    _transport_availability,
    _llm,
):
    with patch.object(booking_agent, "aiml_api_key", "test-key"):
        state = _state()
        result = booking_agent.build_booking_package(state)

    assert result["selected_room"]["room_id"] == 10
    assert result["selected_transport"]["transport_id"] == 7
    assert result["currency"] == "USD"
    assert result["itinerary"] is state["itinerary"]


def test_pipeline_initialization_redacts_access_token():
    import graph

    captured = {}

    def fake_log_agent_step(**kwargs):
        captured.update(kwargs.get("input_data") or {})

    class _App:
        def invoke(self, initial_data):
            return {"status": "Failed", "retry_count": 0}

    with patch.object(graph, "log_agent_step", side_effect=fake_log_agent_step), patch.object(
        graph, "travel_app", _App()
    ), patch.object(graph, "sync_result_to_backend"):
        graph.run_travel_planning_pipeline(
            {"trip_request_id": 123, "access_token": "secret-jwt"}
        )

    assert "access_token" not in captured
    assert "secret-jwt" not in str(captured)


def test_fastapi_request_does_not_accept_user_access_token():
    from main import TripPipelineRequest

    request = TripPipelineRequest(
        trip_request_id=123,
        customer_id="customer-1",
        destination_id=5,
        start_date="2026-10-10T00:00:00Z",
        end_date="2026-10-14T00:00:00Z",
        traveller_count=2,
        budget_ceiling=2000,
        currency="USD",
    )

    assert "access_token" not in request.model_dump()


def test_fastapi_async_endpoint_acknowledges_without_running_graph():
    from main import TripPipelineRequest, run_pipeline_async

    payload = TripPipelineRequest(
        trip_request_id=123,
        start_date="2026-10-10T00:00:00Z",
        end_date="2026-10-14T00:00:00Z",
        budget_ceiling=2000,
    )
    tasks = BackgroundTasks()
    with patch("main.run_travel_planning_pipeline") as run_pipeline:
        response = run_pipeline_async(payload, tasks)

    assert response.status_code == 202
    assert response.body is not None
    assert len(tasks.tasks) == 1
    run_pipeline.assert_not_called()


def test_pipeline_exception_returns_safe_failed_callback():
    import graph

    callback = {}

    class _FailingApp:
        def invoke(self, _initial_data):
            raise RuntimeError("provider secret should not reach the callback")

    with patch.object(graph, "travel_app", _FailingApp()), patch.object(
        graph, "sync_result_to_backend", side_effect=lambda **kwargs: callback.update(kwargs)
    ):
        result = graph.run_travel_planning_pipeline(
            {"trip_request_id": 123, "retry_count": 1, "access_token": "secret-jwt"}
        )

    assert result["status"] == "Failed"
    assert callback["final_status"] == "Failed"
    assert "secret" not in str(callback)
