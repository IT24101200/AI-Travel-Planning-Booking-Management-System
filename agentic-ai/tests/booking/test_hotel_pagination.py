from unittest.mock import Mock, patch

import pytest

from tools.availability_tools import HotelSearchError, search_hotels


def _response(payload, status_code=200):
    response = Mock()
    response.status_code = status_code
    response.raise_for_status.return_value = None
    response.json.return_value = payload
    return response


def _hotel(hotel_id):
    return {"id": hotel_id, "name": f"Hotel {hotel_id}", "status": "Active"}


def test_search_hotels_collects_all_pages_and_deduplicates_ids():
    first_page = {"data": [_hotel(i) for i in range(1, 11)], "totalPages": 2}
    second_page = {
        "data": [_hotel(10)] + [_hotel(i) for i in range(11, 16)],
        "totalPages": 2,
    }
    responses = [_response(first_page), _response(second_page)]

    with patch("tools.availability_tools.requests.get", side_effect=responses) as get:
        hotels = search_hotels(destination_id=7, currency="LKR")

    assert [hotel["id"] for hotel in hotels] == list(range(1, 16))
    assert get.call_count == 2
    assert get.call_args_list[0].kwargs["params"]["page"] == 1
    assert get.call_args_list[1].kwargs["params"]["page"] == 2
    assert get.call_args_list[0].kwargs["params"]["pageSize"] == 50


def test_search_hotels_with_one_page_makes_one_request():
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response({"data": [_hotel(1)], "totalPages": 1}),
    ) as get:
        hotels = search_hotels()

    assert [hotel["id"] for hotel in hotels] == [1]
    assert get.call_count == 1


def test_search_hotels_rejects_malformed_pagination_metadata():
    with patch(
        "tools.availability_tools.requests.get",
        return_value=_response({"data": [_hotel(1)], "totalPages": "unknown"}),
    ):
        with pytest.raises(HotelSearchError):
            search_hotels()


def test_search_hotels_does_not_return_partial_results_when_later_page_fails():
    first_page = _response({"data": [_hotel(i) for i in range(1, 11)], "totalPages": 2})
    failed_page = Mock()
    failed_page.raise_for_status.side_effect = RuntimeError("network failure")

    with patch("tools.availability_tools.requests.get", side_effect=[first_page, failed_page]):
        with pytest.raises(HotelSearchError):
            search_hotels()
