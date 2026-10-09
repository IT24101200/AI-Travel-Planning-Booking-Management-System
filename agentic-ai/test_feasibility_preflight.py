from feasibility_preflight import run_preflight


def request(**overrides):
    value = {
        "start_date": "2026-10-16",
        "end_date": "2026-10-22",
        "traveller_count": 2,
        "requested_destinations": [{"destination_id": 51, "destination_name": "Colombo"}],
    }
    value.update(overrides)
    return value


def test_preflight_passes_valid_window_without_catalogue_queries():
    result = run_preflight(request())
    assert result["passed"] is True
    assert result["details"]["requested_days"] == 7
    assert result["details"]["minimum_planner_days"] == 2


def test_preflight_rejects_one_day_trip_before_itinerary_generation():
    result = run_preflight(request(end_date="2026-10-16"))
    assert result["passed"] is False
    assert result["error_code"] == "TRIP_WINDOW_TOO_SHORT"
    assert result["details"]["requested_days"] == 1


def test_preflight_reports_reversed_dates_as_invalid():
    result = run_preflight(request(start_date="2026-10-20", end_date="2026-10-16"))
    assert result["passed"] is False
    assert result["error_code"] == "INVALID_TRAVEL_DATES"
