"""Golden-case tests for the itinerary agent."""

# The backend must be running locally before this script is executed.

import sys

from agents.itinerary_agent import build_itinerary
from tools.search_tours import search_tours


KANDY_DESTINATION_ID = 2


def _normal_trip_request():
    """Return a fresh normal-case trip request for Kandy."""
    return {
        "trip_request_id": 1,
        "destination_id": KANDY_DESTINATION_ID,
        "destination_name": "Kandy",
        "start_date": "2026-10-01",
        "end_date": "2026-10-05",
        "traveller_count": 2,
        "budget_ceiling": 150000,
        "preferred_activities": ["Heritage", "Tea"],
    }


def _get_tour_value(tour, *possible_names):
    """Return a tour field while allowing API naming variations."""
    for name in possible_names:
        if name in tour:
            return tour[name]
    return None


def _time_to_seconds(value):
    """Convert an HH:MM:SS time string into seconds after midnight."""
    hours, minutes, seconds = (int(part) for part in value.split(":"))
    return hours * 3600 + minutes * 60 + seconds


def _assert_rule_based_validity(result, trip_request):
    """Apply the deterministic itinerary rules to a successful result."""
    assert "error" not in result, result.get("error")

    schedule = result.get("schedule")
    assert isinstance(schedule, list), "schedule must be a list"
    assert schedule, "schedule must contain at least one day"

    destination_tours = search_tours(trip_request["destination_id"])
    active_tour_ids = {
        _get_tour_value(tour, "id", "tour_id", "tourId", "Id")
        for tour in destination_tours
        if str(_get_tour_value(tour, "status", "Status") or "").lower()
        == "active"
    }
    assert active_tour_ids, "the destination must have active tours"

    total_cost = 0.0
    for day in schedule:
        items = day.get("items", [])
        assert len(items) <= 2, (
            f"day {day.get('day_number')} contains more than two tours"
        )

        for item in items:
            assert item.get("tour_id") in active_tour_ids, (
                f"tour {item.get('tour_id')} is not active for the destination"
            )
            total_cost += float(item.get("price", 0)) * trip_request[
                "traveller_count"
            ]

        for first_index in range(len(items)):
            for second_index in range(first_index + 1, len(items)):
                first_item = items[first_index]
                second_item = items[second_index]
                first_start = _time_to_seconds(first_item["start_time"])
                first_end = _time_to_seconds(first_item["end_time"])
                second_start = _time_to_seconds(second_item["start_time"])
                second_end = _time_to_seconds(second_item["end_time"])

                assert not (
                    first_start < second_end and second_start < first_end
                ), (
                    f"day {day.get('day_number')} contains overlapping tours: "
                    f"{first_item.get('tour_name')} and "
                    f"{second_item.get('tour_name')}"
                )

    assert total_cost <= trip_request["budget_ceiling"], (
        f"total cost {total_cost} exceeds budget "
        f"{trip_request['budget_ceiling']}"
    )


def test_normal_case_produces_valid_itinerary():
    trip_request = _normal_trip_request()
    result = build_itinerary(trip_request)
    _assert_rule_based_validity(result, trip_request)


def test_impossibly_low_budget_fails_validation():
    trip_request = _normal_trip_request()
    trip_request["budget_ceiling"] = 100

    result = build_itinerary(trip_request)

    assert "error" in result, (
        "an itinerary that cannot fit the budget must return an error"
    )


def test_nonexistent_destination_returns_clean_error():
    trip_request = _normal_trip_request()
    trip_request["destination_id"] = 99999
    trip_request["destination_name"] = "Nonexistent destination"

    result = build_itinerary(trip_request)

    assert "error" in result, "a nonexistent destination must return an error"


def test_output_contract_shape():
    trip_request = _normal_trip_request()
    result = build_itinerary(trip_request)

    assert "error" not in result, result.get("error")
    assert set(result) == {
        "itinerary_id",
        "total_estimated_cost",
        "currency",
        "schedule",
    }

    for day in result["schedule"]:
        assert {"day_number", "items"}.issubset(day)
        assert isinstance(day["items"], list)

        for item in day["items"]:
            assert {
                "tour_id",
                "tour_name",
                "start_time",
                "end_time",
                "price",
            }.issubset(item)


def main():
    tests = [
        test_normal_case_produces_valid_itinerary,
        test_impossibly_low_budget_fails_validation,
        test_nonexistent_destination_returns_clean_error,
        test_output_contract_shape,
    ]
    passed = 0

    for test in tests:
        try:
            test()
        except Exception as error:
            print(f"FAIL: {test.__name__} — {type(error).__name__}: {error}")
        else:
            passed += 1
            print(f"PASS: {test.__name__}")

    print(f"{passed}/{len(tests)} passed")
    return 0 if passed == len(tests) else 1


if __name__ == "__main__":
    sys.exit(main())
