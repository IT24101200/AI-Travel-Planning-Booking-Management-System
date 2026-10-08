from datetime import datetime, timedelta
from unittest.mock import patch

from agents.booking_agent import _compatible_timetables


def option(i, departure, arrival, price=100):
    return {"transport_id": i, "departure_time": departure,
            "arrival_time": arrival, "price": price}


def test_large_catalogue_removes_duplicate_departures_but_keeps_cheapest_inventory():
    groups = [[option(leg * 100 + i, f"2026-10-{10+leg}T09:00:00",
                      f"2026-10-{10+leg}T12:00:00", 100 - i)
               for i in range(20)] for leg in range(3)]
    plans = list(_compatible_timetables(groups, {}))
    assert len(plans) == 1  # 8,000 raw combinations were previously rejected.
    assert [o["transport_id"] for o in plans[0]] == [19, 119, 219]


def test_chronology_filters_dead_ends_before_enumerating_large_catalogue():
    groups = [[option(i, f"2026-10-{11+i}T09:00:00", f"2026-10-{11+i}T12:00:00")
               for i in range(20)],
              [option(100+i, "2026-10-10T09:00:00", "2026-10-10T12:00:00", i + 1)
               for i in range(20)]]
    assert list(_compatible_timetables(groups, {})) == []
    # One earlier first leg makes the chain possible without discarding its date.
    groups[0].append(option(99, "2026-10-09T09:00:00", "2026-10-09T12:00:00"))
    plans = list(_compatible_timetables(groups, {}))
    assert [o["transport_id"] for o in plans[0]] == [99, 100]


def test_airport_readiness_and_day_window_filter_departures_before_planning():
    groups = [[option(1, "2026-10-10T07:00:00", "2026-10-10T10:00:00"),
               option(2, "2026-10-10T08:00:00", "2026-10-10T11:00:00"),
               option(3, "2026-10-10T09:00:00", "2026-10-10T12:00:00"),
               option(4, "2026-10-10T18:00:00", "2026-10-10T21:00:00"),
               option(5, "2026-10-10T19:00:00", "2026-10-11T08:00:00")]]
    plans = list(_compatible_timetables(groups, {"airport_pickup": True,
        "airport_arrival_time": "08:00", "start_date": "2026-10-10"}))
    assert [[o["transport_id"] for o in plan] for plan in plans] == [[3]]


def test_non_airport_early_catalogue_departure_is_kept():
    rows = [option(1, "2026-10-10T07:00:00", "2026-10-10T10:00:00"),
            option(2, "2026-10-10T05:00:00", "2026-10-10T08:00:00")]
    assert [[o["transport_id"] for o in plan] for plan in _compatible_timetables([rows], {})] == [[1]]


def test_distinct_large_timetables_return_verified_package_with_search_limit_metadata():
    from agents import booking_agent
    from route_planning import plan_overnights
    from test_route_planning import LineRoads, itinerary, room, state, tour
    from tools.availability_tools import TransportSearchResult

    tours = [tour(1, 1, 80), tour(2, 2, 80.2)]
    request = {**state(5), "destination_id": 1, "destination_name": "West", "trip_request_id": 166,
        "requested_destinations": [{"destination_id": 1, "destination_name": "West"},
                                   {"destination_id": 2, "destination_name": "East"}],
        "itinerary": {**itinerary(tours), "route_destination_ids": [1, 2]}}
    rows = []
    for i in range(300):
        departure = datetime(2026, 10, 12, 9) + timedelta(minutes=i)
        rows.append({"id": i+1, "routeFrom": "West", "routeTo": "East", "type": "Van",
                     "departureTime": departure.isoformat(), "arrivalTime": (departure + timedelta(hours=1)).isoformat(),
                     "capacity": 4, "price": 50, "currency": "LKR"})
    with (
        patch.object(booking_agent, "search_hotels", return_value=[{"id": 1, "name": "Hotel", "latitude": 7, "longitude": 80.1}]),
        patch.object(booking_agent, "search_hotel_rooms", return_value=[{"id": 1, "capacity": 4, "pricePerNight": 200, "currency": "LKR"}]),
        patch.object(booking_agent, "check_room_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "search_transports", return_value=TransportSearchResult(rows)),
        patch.object(booking_agent, "check_transport_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "plan_overnights", side_effect=lambda *args: plan_overnights(*args, matrix_factory=LineRoads)) as planner,
        patch.object(booking_agent, "log_agent_step"),
    ):
        package = booking_agent.build_booking_package(request)
    assert "error" not in package, package
    assert package["persistence_status"] == "READY_FOR_PERSISTENCE"
    assert package["transport_search"] == {"evaluated_timetables": 256, "search_limited": True}
    assert planner.call_count == 256
    assert sum(s["nights"] for s in package["room_selections"]) == 4
    assert all(d["travel_minutes"] <= 600 for d in package["itinerary"]["schedule"])
