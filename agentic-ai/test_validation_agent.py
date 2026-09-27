"""Deterministic tests for Student D's validation and approval gate."""

from unittest.mock import patch

from agents.validation_agent import validate_and_build_booking, validation_node
from tools.validation_tools import BackendToolError, initiate_payment


def _state(**overrides):
    state = {
        "trip_request_id": 7,
        "customer_id": "customer-1",
        "start_date": "2026-10-01T00:00:00Z",
        "end_date": "2026-10-04T00:00:00Z",
        "traveller_count": 2,
        "budget_ceiling": 1500,
        "currency": "USD",
        "access_token": "test-token",
        "plan_summary": {"trip_theme": "Kandy heritage"},
        "itinerary": {
            "itinerary_id": 22,
            "currency": "USD",
            "schedule": [
                {
                    "day_number": 1,
                    "items": [
                        {"tour_id": 10, "price": 50},
                        {"tour_id": 11, "price": 75},
                    ],
                }
            ],
        },
        "booking_details": {
            # Tours: (50 + 75) * 2 = 250
            # Room: 100 * 3 nights = 300
            # Transport: 200 * 2 travellers = 400
            "total_package_cost": 950,
            "total_cost": 950,
            "currency": "USD",
            "selected_room": {"room_id": 30, "price_per_night": 100},
            "selected_transport": {"transport_id": 40, "price": 200},
        },
    }
    state["booking_details"]["itinerary"] = state["itinerary"]
    state.update(overrides)
    return state


def test_valid_package_builds_backend_dto_with_exactly_one_fk_per_item():
    payload, checks = validate_and_build_booking(_state())

    assert payload["itineraryId"] == 22
    assert payload["totalCost"] == 950
    assert [item["itemType"] for item in payload["items"]] == [0, 0, 1, 2]
    for item in payload["items"]:
        assert sum(
            key in item for key in ("tourId", "roomId", "transportOptionId")
        ) == 1
    assert checks["within_budget"] is True
    assert checks["approval_gate_enforced"] is True


def test_over_budget_package_returns_clean_retry_signal():
    state = _state(budget_ceiling=900)
    result = validation_node(state)

    assert result["validation_result"]["is_valid"] is False
    assert result["validation_result"]["error_code"] == "BUDGET_EXCEEDED"
    assert result["status"] == "ValidationFailed"


def test_currency_mismatch_is_rejected():
    state = _state()
    state["booking_details"]["currency"] = "LKR"
    result = validation_node(state)

    assert result["validation_result"]["is_valid"] is False
    assert result["validation_result"]["error_code"] == "CURRENCY_MISMATCH"


def test_unpersisted_itinerary_is_rejected():
    state = _state()
    state["itinerary"]["itinerary_id"] = None
    result = validation_node(state)

    assert result["validation_result"]["is_valid"] is False
    assert result["validation_result"]["error_code"] == "INVALID_REFERENCE"


def test_total_mismatch_is_rejected():
    state = _state()
    state["booking_details"]["total_cost"] = 951
    result = validation_node(state)

    assert result["validation_result"]["is_valid"] is False
    assert result["validation_result"]["error_code"] == "TOTAL_MISMATCH"


@patch("agents.validation_agent.log_agent_step")
@patch("agents.validation_agent.create_booking")
def test_success_creates_only_awaiting_approval_booking(create_mock, _log_mock):
    create_mock.return_value = {
        "id": 55,
        "bookingReference": "TRV-20260927-ABC123",
        "status": "AwaitingApproval",
    }

    result = validation_node(_state())

    assert result["validation_result"]["is_valid"] is True
    assert result["validation_result"]["status"] == "AwaitingApproval"
    assert result["plan_json"]["booking"]["requires_human_approval"] is True
    sent_payload = create_mock.call_args.args[0]
    assert "status" not in sent_payload
    assert create_mock.call_count == 1


class _FakeResponse:
    def __init__(self, status_code, body):
        self.status_code = status_code
        self._body = body
        self.text = str(body)

    def json(self):
        return self._body


class _FakeClient:
    def __init__(self, booking_status):
        self.booking_status = booking_status
        self.payment_posts = 0

    def get(self, *_args, **_kwargs):
        return _FakeResponse(200, {"id": 55, "status": self.booking_status})

    def post(self, *_args, **_kwargs):
        self.payment_posts += 1
        return _FakeResponse(201, {"id": 99, "status": "Paid"})


def test_payment_tool_refuses_before_human_confirmation():
    client = _FakeClient("AwaitingApproval")
    try:
        initiate_payment(55, 950, "USD", access_token="token", client=client)
    except BackendToolError as error:
        assert "not 'Confirmed'" in str(error)
    else:
        raise AssertionError("Payment tool bypassed the human approval gate.")
    assert client.payment_posts == 0


def test_payment_tool_allows_persisted_confirmed_booking():
    client = _FakeClient("Confirmed")
    result = initiate_payment(
        55, 950, "USD", access_token="token", client=client
    )

    assert result["status"] == "Paid"
    assert client.payment_posts == 1

