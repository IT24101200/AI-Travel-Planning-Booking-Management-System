from unittest.mock import patch
from datetime import datetime
import pytest

from route_planning import (RoutePlanningError, grouped_itinerary, plan_overnights, ordered_destinations, airport)


class LineRoads:
    """Deterministic road network in km; no real routing requests."""
    def __init__(self, records):
        pass

    def leg(self, a, b):
        distance = abs(float(a["longitude"]) - float(b["longitude"])) * 100
        return distance, distance * 1.5  # 40 km/h.


def tour(i, city, x, hour=9):
    return {"id": i, "tour_id": i, "name": f"Tour {i}", "tour_name": f"Tour {i}",
            "destination_id": city, "destination_name": str(city), "latitude": 7, "longitude": x,
            "price": 100, "duration": 2, "default_start_time": f"{hour:02d}:00:00",
            "start_time": f"{hour:02d}:00:00", "end_time": f"{hour+2:02d}:00:00", "status": "Active"}


def room(i, x, price=200):
    return {"room_id": i, "hotel_id": i, "hotel_name": f"Hotel {i}", "latitude": 7,
            "longitude": x, "price_per_night": price}


def state(days=5, budget=100000):
    return {"start_date": "2026-10-10", "end_date": f"2026-10-{9+days}",
            "budget_ceiling": budget, "traveller_count": 1, "currency": "LKR"}


def itinerary(tours):
    return {"total_estimated_cost": len(tours) * 100, "schedule": [{"day_number": i+1, "items": [t]} for i, t in enumerate(tours)]}


def test_destination_order_avoids_round_trip_between_east_and_west():
    destinations = [{"destination_id": i, "destination_name": str(i)} for i in (1, 2, 3)]
    tours = [tour(1, 1, 81.7), tour(2, 2, 80), tour(3, 3, 81.8)]
    roads = LineRoads(tours)
    order = ordered_destinations(destinations, tours, roads)
    points = {t["destination_id"]: t for t in tours}
    distance = sum(roads.leg(points[a], points[b])[0] for a, b in zip(order, order[1:]))
    assert distance <= 181


def test_all_journeys_in_a_city_are_contiguous():
    destinations = [{"destination_id": i, "destination_name": str(i)} for i in (1, 2, 3)]
    tours = [tour(1, 1, 81.7), tour(2, 2, 80), tour(3, 3, 81.8), tour(4, 1, 81.71), tour(5, 2, 80.01), tour(6, 3, 81.81)]
    with patch("route_planning.RoadMatrix", LineRoads):
        plan = grouped_itinerary(state(7), tours, destinations)
    visits = [d["items"][0]["destination_id"] for d in plan["schedule"]]
    compressed = [city for i, city in enumerate(visits) if i == 0 or city != visits[i-1]]
    assert compressed == plan["route_destination_ids"] == [1, 2, 3]
    assert len(compressed) == len(set(compressed)) == 3


def test_grouped_itinerary_preserves_customer_destination_order():
    destinations = [{"destination_id": i, "destination_name": str(i)} for i in (1, 2)]
    tours = [tour(1, 1, 81.7), tour(2, 2, 80)]
    with patch("route_planning.RoadMatrix", LineRoads):
        plan = grouped_itinerary(state(5), tours, destinations)

    assert plan["route_destination_ids"] == [1, 2]
    assert [item["destination_id"] for day in plan["schedule"] for item in day["items"]] == [1, 2]


def test_nearby_destinations_can_share_a_hotel_and_stays_cover_all_nights():
    plan, stays = plan_overnights(state(4), itinerary([tour(1, 1, 80), tour(2, 2, 80.3)]), [room(1, 80.15)], lambda *_: True, LineRoads)
    assert len(stays) == 1
    assert stays[0]["nights"] == 3
    assert stays[0]["check_in"] == "2026-10-10"
    assert stays[0]["check_out"] == "2026-10-13"
    assert all(day["travel_minutes"] <= 600 for day in plan["schedule"])


def test_distant_destinations_use_multiple_hotels_without_revisiting_city():
    plan, stays = plan_overnights(state(5), itinerary([tour(1, 1, 80), tour(2, 2, 82)]), [room(1, 80), room(2, 82)], lambda *_: True, LineRoads)
    assert {stay["hotel_id"] for stay in stays} == {1, 2}
    assert sum(stay["nights"] for stay in stays) == 4
    assert sum(len(day["items"]) for day in plan["schedule"]) == 2


def test_midway_hotel_within_70km_can_balance_two_journeys():
    plan, stays = plan_overnights(state(3), itinerary([tour(1, 1, 80), tour(2, 2, 81.3)]), [room(1, 80.65)], lambda *_: True, LineRoads)
    assert stays[0]["hotel_id"] == 1
    assert all(day["travel_minutes"] <= 600 for day in plan["schedule"])


def test_long_route_uses_intermediate_hotel_and_transfer_day():
    plan, stays = plan_overnights(state(5), itinerary([tour(1, 1, 80), tour(2, 2, 84)]), [room(1, 80), room(2, 82), room(3, 84)], lambda *_: True, LineRoads)
    assert 2 in {stay["hotel_id"] for stay in stays}
    assert any(not day["items"] and day["travel_legs"] for day in plan["schedule"])
    assert all(day["travel_minutes"] <= 600 for day in plan["schedule"])


def test_ten_hour_driving_transfer_fits_with_breaks_before_twenty_hundred():
    tours = [tour(1, 1, 80), tour(2, 2, 84)]
    departure, arrival = datetime(2026, 10, 12, 8), datetime(2026, 10, 12, 18)
    request = {**state(5), "transport_windows": {1: (None, departure), 2: (arrival, None)},
        "transport_events": [{"source": tours[0], "target": tours[1], "target_index": 1,
            "departure": departure, "arrival": arrival}]}
    plan, _ = plan_overnights(request, itinerary(tours), [room(1, 80), room(2, 84)], lambda *_: True, LineRoads)
    transfer = next(day for day in plan["schedule"] if day["date"] == "2026-10-12")
    assert transfer["travel_minutes"] == 600
    assert transfer["day_end_time"] == "18:00:00"
    assert plan["travel_policy"]["max_driving_minutes"] == 600


@pytest.mark.parametrize("distance_km", [650, 800])
def test_very_distant_destinations_split_driving_across_hotel_nights(distance_km):
    end = 80 + distance_km / 100
    tours = [tour(1, 1, 80), tour(2, 2, end)]
    rooms = [room(1, 80), room(2, (80 + end) / 2), room(3, end)]
    plan, stays = plan_overnights(state(6), itinerary(tours), rooms, lambda *_: True, LineRoads)
    assert {stay["hotel_id"] for stay in stays} == {1, 2, 3}
    assert sum(stay["nights"] for stay in stays) == 5
    assert [item["tour_id"] for day in plan["schedule"] for item in day["items"]] == [1, 2]
    assert all(day["travel_minutes"] <= 600 for day in plan["schedule"])
    assert all(day["day_end_time"] <= "20:00:00" for day in plan["schedule"])
    assert any(not day["items"] and day["travel_legs"] for day in plan["schedule"])


def test_very_distant_destinations_without_intermediate_hotel_are_rejected():
    with pytest.raises(RoutePlanningError) as error:
        plan_overnights(state(6), itinerary([tour(1, 1, 80), tour(2, 2, 88)]),
            [room(1, 80), room(2, 88)], lambda *_: True, LineRoads)
    assert error.value.code == "TRAVEL_TIME_INFEASIBLE"


def test_more_than_ten_hours_driving_is_rejected_even_with_time_in_day():
    tours = [tour(1, 1, 80), tour(2, 2, 84.1)]
    request = {**state(5), "transport_events": [{"source": tours[0], "target": tours[1], "target_index": 1,
        "departure": datetime(2026, 10, 12, 8), "arrival": datetime(2026, 10, 12, 20)}]}
    with pytest.raises(RoutePlanningError) as error:
        plan_overnights(request, itinerary(tours), [room(1, 80), room(2, 84.1)], lambda *_: True, LineRoads)
    assert error.value.code == "TRAVEL_TIME_INFEASIBLE"


@pytest.mark.parametrize("budget,rooms,code", [(250, [room(1, 80, 500)], "BUDGET_EXCEEDED"), (100000, [room(1, 85)], "TRAVEL_TIME_INFEASIBLE")])
def test_infeasible_plan_is_rejected_with_reason(budget, rooms, code):
    with pytest.raises(RoutePlanningError) as error:
        plan_overnights(state(3, budget), itinerary([tour(1, 1, 80)]), rooms, lambda *_: True, LineRoads)
    assert error.value.code == code


def test_airport_arrival_time_is_included_and_late_arrival_is_rejected():
    request = {**state(3), "airport_pickup": True, "airport_code": "CMB", "airport_arrival_time": "23:00"}
    assert airport(request)["name"] == "Bandaranaike International Airport"
    with pytest.raises(RoutePlanningError):
        plan_overnights(request, itinerary([tour(1, 1, 80)]), [room(1, 80)], lambda *_: True, LineRoads)


def test_hotel_move_waits_for_booked_transfer_day_and_time():
    tours = [tour(1, 1, 80), tour(2, 2, 82)]
    departure, arrival = datetime(2026, 10, 12, 9), datetime(2026, 10, 12, 15)
    request = {**state(5), "transport_windows": {1: (None, departure), 2: (arrival, None)},
        "transport_events": [{"source": tours[0], "target": tours[1], "target_index": 1,
            "departure": departure, "arrival": arrival}]}
    plan, stays = plan_overnights(request, itinerary(tours), [room(1, 80), room(2, 82)], lambda *_: True, LineRoads)
    assert stays[0]["hotel_id"] == 1
    assert stays[0]["check_out"] == "2026-10-12"
    transfer = next(day for day in plan["schedule"] if day["date"] == "2026-10-12")
    assert transfer["end_hotel_id"] == 2
    assert transfer["travel_minutes"] == 360
    assert all(day["end_hotel_id"] == 1 for day in plan["schedule"] if day["date"] < "2026-10-12")


def test_transfer_timetable_uses_authoritative_scheduled_duration():
    tours = [tour(1, 1, 80), tour(2, 2, 82)]
    request = {**state(5), "transport_events": [{"source": tours[0], "target": tours[1], "target_index": 1,
        "departure": datetime(2026, 10, 12, 9), "arrival": datetime(2026, 10, 12, 10)}]}
    plan, _ = plan_overnights(request, itinerary(tours), [room(1, 80), room(2, 82)], lambda *_: True, LineRoads)
    transfer_day = next(day for day in plan["schedule"] if day["date"] == "2026-10-12")
    assert transfer_day["travel_minutes"] == 60
    scheduled_leg = next(leg for leg in transfer_day["travel_legs"] if leg.get("scheduled"))
    assert scheduled_leg["duration_minutes"] == 60


def test_early_booked_transfer_includes_hotel_approach_and_preserves_daily_span():
    tours = [tour(1, 1, 80), tour(2, 2, 82)]
    request = {**state(5), "transport_events": [{"source": tours[0], "target": tours[1], "target_index": 1,
        "departure": datetime(2026, 10, 12, 7), "arrival": datetime(2026, 10, 12, 13)}]}
    plan, _ = plan_overnights(request, itinerary(tours), [room(1, 79.9), room(2, 82)], lambda *_: True, LineRoads)
    transfer = next(day for day in plan["schedule"] if day["date"] == "2026-10-12")
    assert transfer["day_start_time"] == "06:45:00"
    assert transfer["travel_minutes"] == 375
    assert transfer["day_end_time"] <= "18:45:00"
    assert all(day["day_start_time"] == "08:00:00" for day in plan["schedule"] if day["date"] != "2026-10-12")


def test_booked_transfer_cannot_force_start_before_six():
    tours = [tour(1, 1, 80), tour(2, 2, 82)]
    request = {**state(5), "transport_events": [{"source": tours[0], "target": tours[1], "target_index": 1,
        "departure": datetime(2026, 10, 12, 6), "arrival": datetime(2026, 10, 12, 12)}]}
    with pytest.raises(RoutePlanningError) as error:
        plan_overnights(request, itinerary(tours), [room(1, 79.9), room(2, 82)], lambda *_: True, LineRoads)
    assert error.value.code == "TRAVEL_TIME_INFEASIBLE"


def test_early_airport_pickup_still_waits_for_arrival_allowance():
    destination = tour(1, 1, 80)
    request = {**state(3), "airport_pickup": True, "airport_code": "CMB", "airport_arrival_time": "05:30",
        "transport_events": [{"source": airport({"airport_pickup": True}), "target": destination, "target_index": 0,
            "departure": datetime(2026, 10, 10, 7), "arrival": datetime(2026, 10, 10, 8)}]}
    plan, _ = plan_overnights(request, itinerary([destination]), [room(1, 80)], lambda *_: True, LineRoads)
    assert plan["schedule"][0]["day_start_time"] == "07:00:00"
    with pytest.raises(RoutePlanningError):
        plan_overnights({**request, "airport_arrival_time": "06:30"}, itinerary([destination]),
            [room(1, 80)], lambda *_: True, LineRoads)


@pytest.mark.parametrize("duplicate_departures", [1, 300])
def test_geographic_booking_and_validation_use_dated_hotels_and_transfer(duplicate_departures):
    from agents import booking_agent
    from agents.validation_agent import validate_and_build_booking
    from tools.availability_tools import TransportSearchResult
    tours = [tour(1, 1, 80), tour(2, 2, 82)]
    draft = {**itinerary(tours), "route_destination_ids": [1, 2], "currency": "LKR"}
    request = {**state(5), "customer_id": "customer", "trip_request_id": 7, "destination_id": 1,
        "destination_name": "West", "requested_destinations": [
            {"destination_id": 1, "destination_name": "West", "order": 0},
            {"destination_id": 2, "destination_name": "East", "order": 1}], "itinerary": draft}
    hotels = [{"id": i, "name": f"Hotel {i}", "latitude": 7, "longitude": x} for i, x in [(1, 80), (2, 82)]]
    transports = TransportSearchResult([{"id": 10, "type": "Van", "provider": "Transfer", "capacity": 4,
        "routeFrom": "West", "routeTo": "East", "departureTime": "2026-10-12T09:00:00",
        "arrivalTime": "2026-10-12T15:00:00", "price": 50, "currency": "LKR"}])
    transports = TransportSearchResult([{**transports[0], "id": 10 + i, "price": 50 + i}
                                        for i in range(duplicate_departures)])
    with (
        patch.object(booking_agent, "search_hotels", return_value=hotels),
        patch.object(booking_agent, "search_hotel_rooms", side_effect=lambda hotel_id, **_: [
            {"id": hotel_id, "capacity": 4, "pricePerNight": 200, "currency": "LKR"}]),
        patch.object(booking_agent, "check_room_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "search_transports", return_value=transports),
        patch.object(booking_agent, "check_transport_availability", return_value={"isAvailable": True}),
        patch.object(booking_agent, "plan_overnights", side_effect=lambda *args: plan_overnights(*args, matrix_factory=LineRoads)),
        patch.object(booking_agent, "log_agent_step"),
    ):
        package = booking_agent.build_booking_package(request)
    assert "error" not in package, package
    assert [stay["hotel_id"] for stay in package["room_selections"]] == [1, 2]
    assert package["total_cost"] == 1050  # Two tours, four hotel nights, one transfer.
    assert package["transport_search"] == {"evaluated_timetables": 1, "search_limited": False}
    assert package["transport_selections"][0]["transport_option_id"] == 10
    payload, checks = validate_and_build_booking({**request, "booking_details": package})
    assert len([item for item in payload["items"] if item["itemType"] == 1]) == 2
