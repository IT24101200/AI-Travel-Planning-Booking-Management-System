from unittest.mock import Mock, patch

import pytest

from tools.availability_tools import TransportSearchError, search_transports


def _response(payload, status_code=200):
    response = Mock()
    response.status_code = status_code
    response.raise_for_status.return_value = None
    response.json.return_value = payload
    return response


def _transport(transport_id, route_from="Colombo", route_to="Kandy", day=10):
    return {
        "id": transport_id,
        "status": "Active",
        "capacity": 10,
        "routeFrom": route_from,
        "routeTo": route_to,
        "departureTime": f"2026-10-{day:02d}T08:00:00",
        "arrivalTime": f"2026-10-{day:02d}T10:00:00",
    }


def test_search_transports_collects_all_pages_and_deduplicates_ids():
    first = {"data": [_transport(i) for i in range(1, 11)], "totalPages": 3}
    second = {"data": [_transport(10)] + [_transport(i) for i in range(11, 21)], "totalPages": 3}
    third = {"data": [_transport(21), _transport(22)], "totalPages": 3}

    with patch(
        "tools.availability_tools.requests.get",
        side_effect=[_response(first), _response(second), _response(third)],
    ) as get:
        result = search_transports()

    assert [item["id"] for item in result] == list(range(1, 23))
    assert get.call_count == 3
    assert get.call_args_list[0].kwargs["params"]["pageSize"] == 50
    assert get.call_args_list[2].kwargs["params"]["page"] == 3


def test_transport_after_first_page_is_discoverable():
    with patch(
        "tools.availability_tools.requests.get",
        side_effect=[
            _response({"data": [_transport(1)], "totalPages": 2}),
            _response({"data": [_transport(22)], "totalPages": 2}),
        ],
    ):
        result = search_transports()

    assert result[-1]["id"] == 22


def test_multi_leg_search_sends_each_ordered_route_to_backend():
    with patch(
        "tools.availability_tools.requests.get",
        side_effect=[
            _response({"data": [_transport(1, "Colombo", "Dambulla")], "totalPages": 1}),
            _response({"data": [_transport(2, "Dambulla", "Arugam Bay")], "totalPages": 1}),
        ],
    ) as get:
        result = search_transports(
            currency="LKR",
            requested_destinations=[
                {"destination_name": "Colombo"},
                {"destination_name": "Dambulla"},
                {"destination_name": "Arugam Bay"},
            ],
        )

    assert [item["id"] for item in result] == [1, 2]
    assert get.call_args_list[0].kwargs["params"]["routeFrom"] == "colombo"
    assert get.call_args_list[0].kwargs["params"]["routeTo"] == "dambulla"
    assert get.call_args_list[1].kwargs["params"]["routeFrom"] == "dambulla"
    assert get.call_args_list[1].kwargs["params"]["routeTo"] == "arugam bay"


def test_one_page_makes_one_request():
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response({"data": [_transport(1)], "totalPages": 1}),
    ) as get:
        search_transports()
    assert get.call_count == 1


def test_later_page_failure_never_returns_partial_results():
    failed = Mock()
    failed.raise_for_status.side_effect = RuntimeError("network failure")
    with patch(
        "tools.availability_tools.requests.get",
        side_effect=[
            _response({"data": [_transport(1)], "totalPages": 2}),
            failed,
        ],
    ):
        with pytest.raises(TransportSearchError):
            search_transports()


@pytest.mark.parametrize(
    "payload",
    [
        {"data": [_transport(1)], "totalPages": "unknown"},
        {"data": [_transport(1)], "totalPages": 101},
        {"data": [_transport(1)], "totalPages": 2, "page": 9},
    ],
)
def test_malformed_pagination_metadata_fails_safely(payload):
    with patch("tools.availability_tools.requests.get", return_value=_response(payload)):
        with pytest.raises(TransportSearchError):
            search_transports()


def test_route_and_date_filtering_is_deterministic():
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response(
            {
                "data": [
                    _transport(1, "Colombo", "Kandy", 10),
                    _transport(2, "Unrelated", "Other", 10),
                    _transport(3, "Colombo", "Kandy", 20),
                ],
                "totalPages": 1,
            }
        ),
    ):
        result = search_transports(
            requested_destinations=[
                {"destination_id": 1, "destination_name": "  Kandy  "}
            ],
            start_date="2026-10-10",
            end_date="2026-10-12",
        )

    assert [item["id"] for item in result] == [1]


def test_more_than_one_hundred_pages_fails_before_partial_catalogue_is_returned():
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response({"data": [], "totalPages": 101}),
    ):
        with pytest.raises(TransportSearchError):
            search_transports()
