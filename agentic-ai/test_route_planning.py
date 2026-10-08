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
    assert compressed == plan["route_destination_ids"]
    assert len(compressed) == len(set(compressed)) == 3


def test_nearby_destinations_can_share_a_hotel_and_stays_cover_all_nights():
    plan, stays = plan_overnights(state(4), itinerary([tour(1, 1, 80), tour(2, 2, 80.3)]), [room(1, 80.15)], lambda *_: True, LineRoads)
    assert len(stays) == 1
    assert stays[0]["nights"] == 3
    assert stays[0]["check_in"] == "2026-10-10"
    assert stays[0]["check_out"] == "2026-10-13"
    assert all(day["travel_minutes"] <= 360 for day in plan["schedule"])


def test_distant_destinations_use_multiple_hotels_without_revisiting_city():
    plan, stays = plan_overnights(state(5), itinerary([tour(1, 1, 80), tour(2, 2, 82)]), [room(1, 80), room(2, 82)], lambda *_: True, LineRoads)
    assert {stay["hotel_id"] for stay in stays} == {1, 2}
    assert sum(stay["nights"] for stay in stays) == 4
    assert sum(len(day["items"]) for day in plan["schedule"]) == 2


def test_midway_hotel_within_70km_can_balance_two_journeys():
    plan, stays = plan_overnights(state(3), itinerary([tour(1, 1, 80), tour(2, 2, 81.3)]), [room(1, 80.65)], lambda *_: True, LineRoads)
    assert stays[0]["hotel_id"] == 1
    assert all(day["travel_minutes"] <= 360 for day in plan["schedule"])


def test_long_route_uses_intermediate_hotel_and_transfer_day():
    plan, stays = plan_overnights(state(5), itinerary([tour(1, 1, 80), tour(2, 2, 84)]), [room(1, 80), room(2, 82), room(3, 84)], lambda *_: True, LineRoads)
    assert 2 in {stay["hotel_id"] for stay in stays}
    assert any(not day["items"] and day["travel_legs"] for day in plan["schedule"])
    assert all(day["travel_minutes"] <= 360 for day in plan["schedule"])


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
    assert transfer["travel_minutes"] == 300
    assert all(day["end_hotel_id"] == 1 for day in plan["schedule"] if day["date"] < "2026-10-12")


def test_transfer_timetable_must_allow_actual_road_travel_and_breaks():
    tours = [tour(1, 1, 80), tour(2, 2, 82)]
    request = {**state(5), "transport_events": [{"source": tours[0], "target": tours[1], "target_index": 1,
        "departure": datetime(2026, 10, 12, 9), "arrival": datetime(2026, 10, 12, 10)}]}
    with pytest.raises(RoutePlanningError) as error:
        plan_overnights(request, itinerary(tours), [room(1, 80), room(2, 82)], lambda *_: True, LineRoads)
    assert error.value.code == "TRAVEL_TIME_INFEASIBLE"


def test_geographic_booking_and_validation_use_dated_hotels_and_transfer():
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
    payload, checks = validate_and_build_booking({**request, "booking_details": package})
    assert len([item for item in payload["items"] if item["itemType"] == 1]) == 2
