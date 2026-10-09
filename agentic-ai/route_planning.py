"""Road-based destination ordering and budget-constrained overnight planning."""

from datetime import datetime, timedelta
from functools import lru_cache
from math import isfinite
import os

import requests


AIRPORTS = {
    "CMB": {"name": "Bandaranaike International Airport", "latitude": 7.1802, "longitude": 79.8842},
    "HRI": {"name": "Mattala Rajapaksa International Airport", "latitude": 6.2845, "longitude": 81.1241},
}
MAX_DRIVING_MINUTES = 600
DAY_START = 8 * 60
DAY_END = 20 * 60
EARLIEST_TRANSFER_START = 6 * 60
MAX_DAY_MINUTES = DAY_END - DAY_START


class RoutePlanningError(ValueError):
    def __init__(self, code, message, details=None):
        super().__init__(message)
        self.code = code
        self.details = details or {}


def point(record):
    try:
        lat, lon = float(record["latitude"]), float(record["longitude"])
        if not all(isfinite(n) for n in (lat, lon)) or abs(lat) > 90 or abs(lon) > 180 or (lat == 0 and lon == 0):
            raise ValueError()
        return (lat, lon)
    except (KeyError, TypeError, ValueError):
        raise RoutePlanningError("MISSING_ROUTE_COORDINATES", "Verified GPS coordinates are required for every planned tour and hotel.") from None


@lru_cache(maxsize=32)
def _road_table(points):
    if len(points) > 100:
        raise RoutePlanningError("ROUTE_TOO_LARGE", "Please request fewer destinations or activities in one plan.")
    coordinates = ";".join(f"{lon},{lat}" for lat, lon in points)
    base = os.getenv("ROUTING_BASE_URL", "https://router.project-osrm.org").rstrip("/")
    try:
        response = requests.get(f"{base}/table/v1/driving/{coordinates}", params={"annotations": "distance,duration"}, timeout=25)
        response.raise_for_status()
        data = response.json()
        if data.get("code") != "Ok":
            raise ValueError()
        size = len(points)
        distances, durations = data["distances"], data["durations"]
        if any(len(rows) != size or any(len(row) != size for row in rows) for rows in (distances, durations)):
            raise ValueError()
        return distances, durations
    except (requests.RequestException, KeyError, TypeError, ValueError):
        raise RoutePlanningError("ROAD_ROUTING_UNAVAILABLE", "Road distances and travel times could not be verified. Please retry planning later.") from None


class RoadMatrix:
    def __init__(self, records):
        self.points = tuple(dict.fromkeys(point(record) for record in records))
        self.index = {p: i for i, p in enumerate(self.points)}
        self._legs = {}
        if len(self.points) == 1:
            self.distances = self.durations = [[0]]
        else:
            self.distances, self.durations = _road_table(self.points)

    def leg(self, source, target):
        a, b = self.index[point(source)], self.index[point(target)]
        if (a, b) in self._legs:
            return self._legs[a, b]
        distance, duration = self.distances[a][b], self.durations[a][b]
        if distance is None or duration is None:
            return float("inf"), float("inf")
        distance, duration = float(distance) / 1000, float(duration) / 60
        if not isfinite(distance) or not isfinite(duration) or min(distance, duration) < 0:
            raise RoutePlanningError("ROAD_ROUTING_UNAVAILABLE", "The road routing service returned invalid travel data.")
        self._legs[a, b] = (distance, duration)
        return distance, duration


def ordered_destinations(destinations, tours, matrix, origin=None):
    """Shortest open destination path (exact through nine destinations)."""
    ids = [d["destination_id"] for d in destinations]
    representatives = {i: next(t for t in tours if t["destination_id"] == i) for i in ids}
    if len(ids) > 9:
        order, remaining = [], list(ids)
        current = origin
        while remaining:
            chosen = min(remaining, key=lambda i: matrix.leg(current, representatives[i])[0] if current else ids.index(i))
            order.append(chosen)
            remaining.remove(chosen)
            current = representatives[chosen]
        return order
    states = {}
    for index, destination in enumerate(ids):
        cost = matrix.leg(origin, representatives[destination])[0] if origin else 0
        states[(1 << index, index)] = (cost, [destination])
    for mask in range(1, 1 << len(ids)):
        for end in range(len(ids)):
            current = states.get((mask, end))
            if current is None:
                continue
            for nxt in range(len(ids)):
                if mask & (1 << nxt):
                    continue
                key = (mask | (1 << nxt), nxt)
                cost = current[0] + matrix.leg(representatives[ids[end]], representatives[ids[nxt]])[0]
                if key not in states or cost < states[key][0]:
                    states[key] = (cost, current[1] + [ids[nxt]])
    return min((value for (mask, _), value in states.items() if mask == (1 << len(ids)) - 1), key=lambda value: value[0])[1]


def airport(state):
    if not state.get("airport_pickup"):
        return None
    code = state.get("airport_code") or "CMB"
    if code not in AIRPORTS:
        raise RoutePlanningError("INVALID_AIRPORT", "Select CMB or HRI for airport pickup.")
    return {**AIRPORTS[code], "kind": "airport"}


def minutes(value, default=DAY_START):
    if not value:
        return default
    try:
        parts = str(value).split(":")
        hour, minute = int(parts[0]), int(parts[1])
        if not 0 <= hour < 24 or not 0 <= minute < 60:
            raise ValueError()
        return hour * 60 + minute
    except (ValueError, IndexError):
        raise RoutePlanningError("INVALID_TRAVEL_TIME", "Travel times must use HH:mm format.") from None


def clock(value):
    value = int(round(value))
    return f"{value // 60:02d}:{value % 60:02d}:00"


def choose_tours(state, tours, destinations):
    """Reserve coverage before spending remaining activity budget."""
    budget = float(state.get("target_budgets", {}).get("tours_budget") or state["budget_ceiling"])
    travellers = state.get("traveller_count", 1)
    chosen = []
    for destination in destinations:
        options = [t for t in tours if t["destination_id"] == destination["destination_id"] and str(t.get("status", "")).lower() == "active"]
        if not options:
            raise RoutePlanningError("ZERO_TOUR_DESTINATION", f"No active tours are available for {destination['destination_name']}.")
        chosen.append(min(options, key=lambda t: float(t["price"])))
    total = sum(float(t["price"]) * travellers for t in chosen)
    if total > budget:
        raise RoutePlanningError("BUDGET_EXCEEDED", "The activity budget cannot cover at least one journey in every selected destination. Increase the budget or select fewer destinations.")
    days = (datetime.fromisoformat(str(state["end_date"]).replace("Z", "+00:00")).date() - datetime.fromisoformat(str(state["start_date"]).replace("Z", "+00:00")).date()).days + 1
    for tour in tours:
        if tour in chosen or str(tour.get("status", "")).lower() != "active":
            continue
        cost = float(tour["price"]) * travellers
        if len(chosen) < days and total + cost <= budget:
            chosen.append(tour)
            total += cost
    return chosen


def grouped_itinerary(state, tours, destinations):
    """Build a route using an explicit starter, airport, or free optimization.

    The persisted destination order is only the customer's selection order;
    it is not a starter instruction. A selected destination pins the first
    stop, airport pickup pins the airport origin, and otherwise the optimizer
    is free to choose the most efficient open path.
    """
    selected = choose_tours(state, tours, destinations)
    requested_order = [destination["destination_id"] for destination in destinations]
    airport_origin = airport(state)
    explicit_starter_id = state.get("starter_location_id")
    if explicit_starter_id is not None and airport_origin is not None:
        raise RoutePlanningError(
            "STARTER_CONFLICT",
            "Airport pickup is already the route origin; destination starter selection is not applicable.",
        )

    try:
        explicit_starter_id = int(explicit_starter_id) if explicit_starter_id is not None else None
    except (TypeError, ValueError):
        raise RoutePlanningError("INVALID_STARTER_LOCATION", "The selected starter location is invalid.") from None

    matrix = RoadMatrix([*selected, *([airport_origin] if airport_origin else [])])
    if airport_origin:
        order = ordered_destinations(destinations, selected, matrix, airport_origin)
    elif explicit_starter_id is not None:
        if explicit_starter_id not in requested_order:
            raise RoutePlanningError(
                "INVALID_STARTER_LOCATION",
                "The selected starter location must be one of the requested destinations.",
            )
        starter = next(tour for tour in selected if tour["destination_id"] == explicit_starter_id)
        order = [explicit_starter_id]
        remaining = [
            destination
            for destination in destinations
            if destination["destination_id"] != explicit_starter_id
        ]
        if remaining:
            order.extend(ordered_destinations(remaining, selected, matrix, starter))
    else:
        order = ordered_destinations(destinations, selected, matrix)
    destination_order = {destination_id: index for index, destination_id in enumerate(order)}
    selected.sort(key=lambda t: (destination_order[t["destination_id"]], minutes(t.get("default_start_time"))))
    schedule = []
    for index, tour in enumerate(selected):
        start = minutes(tour.get("default_start_time"))
        schedule.append({"day_number": index + 1, "items": [{
            "tour_id": tour["id"], "tour_name": tour["name"],
            "destination_id": tour["destination_id"], "destination_name": tour.get("destination_name"),
            "latitude": tour["latitude"], "longitude": tour["longitude"],
            "start_time": clock(start), "end_time": clock(start + float(tour.get("duration") or 2) * 60),
            "price": tour["price"],
        }]})
    return {"itinerary_id": None, "currency": state.get("currency", "LKR"),
            "route_destination_ids": order, "schedule": schedule,
            "total_estimated_cost": sum(float(t["price"]) * state.get("traveller_count", 1) for t in selected)}


def _overnight_geometry(tours, rooms, origin, matrix_factory):
    """Prepare road data and hotel coverage independently of timetable/budget."""
    matrix = matrix_factory([*tours, *rooms, *([origin] if origin else [])])
    destination_ids = list(dict.fromkeys(t["destination_id"] for t in tours))
    representatives = [next(t for t in tours if t["destination_id"] == i) for i in destination_ids]
    hotel_coverage = {}
    for room in rooms:
        mask = 0
        for i, representative in enumerate(representatives):
            local = matrix.leg(room, representative)[0] <= 50
            midway = any(matrix.leg(representative, room)[0] <= 70 and matrix.leg(room, other)[0] <= 70 and
                         matrix.leg(representative, room)[0] + matrix.leg(room, other)[0] <= matrix.leg(representative, other)[0] * 1.25 + 10
                         for j, other in enumerate(representatives) if abs(i-j) == 1)
            if local or midway:
                mask |= 1 << i
        hotel_coverage[room["room_id"]] = mask
    return matrix, destination_ids, hotel_coverage


def plan_overnights(state, itinerary, rooms, available, matrix_factory=RoadMatrix, *, geometry_cache=None):
    """Pareto search over days, ordered tours, hotels, distance and room cost.

    Transfer-only days can use an intermediate hotel. No straight-line travel
    estimate is used to approve feasibility or the 50/70 km hotel rules.
    """
    start = datetime.fromisoformat(str(state["start_date"]).replace("Z", "+00:00")).date()
    end = datetime.fromisoformat(str(state["end_date"]).replace("Z", "+00:00")).date()
    days = (end - start).days + 1
    tours = [t for day in itinerary["schedule"] for t in day["items"]]
    windows = state.get("transport_windows", {})
    transfers = state.get("transport_events", [])
    if not tours or days < 2:
        raise RoutePlanningError("TRAVEL_TIME_INFEASIBLE", "Allow at least two days for a trip with overnight accommodation.")
    origin = airport(state)
    key = (
        tuple((tour["destination_id"], point(tour)) for tour in tours),
        tuple((room["room_id"], point(room)) for room in rooms),
        point(origin) if origin else None,
        matrix_factory,
    ) if geometry_cache is not None else None
    if geometry_cache is not None and key in geometry_cache:
        matrix, destination_ids, hotel_coverage = geometry_cache[key]
    else:
        geometry = _overnight_geometry(tours, rooms, origin, matrix_factory)
        matrix, destination_ids, hotel_coverage = geometry
        if geometry_cache is not None:
            geometry_cache[key] = geometry
    full_coverage = (1 << len(destination_ids)) - 1
    labels = [(0, origin or tours[0], 0.0, 0.0, [], [], 0, 0.0, 0)]
    budget = float(state["budget_ceiling"]) - float(itinerary["total_estimated_cost"])
    saw_budget = False
    for day_index in range(days):
        date = start + timedelta(days=day_index)
        final_day = day_index == days - 1
        buckets = {}
        for next_tour, current_hotel, cost, distance, schedule, stays, coverage, effort, next_transfer in labels:
            for count in range(3):
                end_index = next_tour + count
                if end_index > len(tours) or len(tours) - end_index > 2 * (days - day_index - 1):
                    continue
                if final_day and end_index != len(tours):
                    continue
                now = max(DAY_START, minutes(state.get("airport_arrival_time")) + 60) if day_index == 0 and origin else DAY_START
                if next_transfer < len(transfers):
                    event = transfers[next_transfer]
                    if event["departure"].date() == date:
                        _, approach_minutes = matrix.leg(current_hotel, event["source"])
                        if isfinite(approach_minutes):
                            departure_minute = event["departure"].hour * 60 + event["departure"].minute
                            needed_start = departure_minute - approach_minutes - int(approach_minutes // 120) * 20
                            earliest_start = EARLIEST_TRANSFER_START
                            if day_index == 0 and origin:
                                earliest_start = max(earliest_start, minutes(state.get("airport_arrival_time")) + 60)
                            now = max(earliest_start, min(DAY_START, needed_start))
                day_start = now
                day_limit = min(DAY_END, day_start + MAX_DAY_MINUTES)
                current, driving, km, items, legs = current_hotel, 0.0, 0.0, [], []
                transfer_index = next_transfer
                transferred_after_visits = False
                feasible = True
                def travel(target):
                    nonlocal current, driving, km, now
                    leg_km, leg_minutes = matrix.leg(current, target)
                    if not isfinite(leg_minutes):
                        return False
                    before_breaks = int(driving // 120)
                    driving += leg_minutes
                    now += leg_minutes + (int(driving // 120) - before_breaks) * 20
                    km += leg_km
                    if leg_km > 0.01:
                        legs.append({"from": endpoint(current), "to": endpoint(target),
                                     "distance_km": round(leg_km, 2), "duration_minutes": round(leg_minutes, 1)})
                    current = target
                    return driving <= MAX_DRIVING_MINUTES and now <= day_limit
                def take_transfers(destination_index=None):
                    nonlocal transfer_index, now, current, driving, km, legs
                    while transfer_index < len(transfers):
                        event = transfers[transfer_index]
                        if destination_index is not None and event["target_index"] > destination_index:
                            break
                        departure, arrival = event["departure"], event["arrival"]
                        if departure.date() > date:
                            return destination_index is None
                        if departure.date() != date or arrival.date() != date:
                            return False
                        departure_minute = departure.hour * 60 + departure.minute
                        arrival_minute = arrival.hour * 60 + arrival.minute
                        if not travel(event["source"]) or now > departure_minute:
                            return False
                        now = departure_minute
                        scheduled_minutes = (arrival - departure).total_seconds() / 60
                        if scheduled_minutes <= 0:
                            return False
                        # A booked TransportOption is a dated departure with an
                        # authoritative arrival time.  Its schedule, rather
                        # than the OSRM estimate between representative tour
                        # coordinates, controls the actual transfer duration.
                        # OSRM remains useful for distance telemetry, but its
                        # duration must not reject an otherwise valid booking.
                        leg_km, _ = matrix.leg(current, event["target"])
                        if isfinite(leg_km):
                            km += leg_km
                        driving += scheduled_minutes
                        legs.append({"from": endpoint(current), "to": endpoint(event["target"]),
                                     "distance_km": round(leg_km, 2) if isfinite(leg_km) else None,
                                     "duration_minutes": round(scheduled_minutes, 1),
                                     "scheduled": True})
                        current = event["target"]
                        now = arrival_minute
                        if driving > MAX_DRIVING_MINUTES or now > day_limit:
                            return False
                        transfer_index += 1
                    return True
                for tour in tours[next_tour:end_index]:
                    earliest, latest = windows.get(tour["destination_id"], (None, None))
                    if (earliest and date < earliest.date()) or (latest and date > latest.date()):
                        feasible = False
                        break
                    if not take_transfers(destination_ids.index(tour["destination_id"])) or not travel(tour):
                        feasible = False
                        break
                    preferred = minutes(tour.get("start_time"))
                    duration = minutes(tour["end_time"]) - preferred
                    now = max(now, preferred)
                    if earliest and date == earliest.date():
                        now = max(now, earliest.hour * 60 + earliest.minute)
                    item = {**tour, "start_time": clock(now), "end_time": clock(now + duration)}
                    now += duration + 45  # Meal/rest allowance between visits.
                    if latest and date == latest.date() and now - 45 > latest.hour * 60 + latest.minute:
                        feasible = False
                        break
                    if now > day_limit:
                        feasible = False
                        break
                    items.append(item)
                if not feasible:
                    continue
                before_transfer = transfer_index
                if not take_transfers():
                    continue
                transferred_after_visits = transfer_index > before_transfer
                if final_day and transfer_index != len(transfers):
                    continue
                choices = [None] if final_day else rooms
                for room in choices:
                    saved = (now, current, driving, km, list(legs))
                    if room is not None:
                        if not available(room, date.isoformat(), (date + timedelta(days=1)).isoformat()):
                            continue
                        following = tours[end_index] if end_index < len(tours) else None
                        if transfers and transfer_index:
                            # Overnight locations must follow actual booked transfers.
                            stage = transfers[transfer_index - 1]["target_index"]
                            if not hotel_coverage[room["room_id"]] & (1 << stage):
                                continue
                        elif transfers and origin:
                            if matrix.leg(origin, room)[0] > 50:
                                continue
                        elif transfers and not hotel_coverage[room["room_id"]] & 1:
                            continue
                        local_items = items
                        if transfers and transfer_index:
                            local_items = [item for item in items if destination_ids.index(item["destination_id"]) == stage]
                        if local_items and not transferred_after_visits:
                            to_hotel = matrix.leg(local_items[-1], room)[0]
                            local = all(matrix.leg(room, item)[0] <= 50 for item in local_items)
                            midway = following is not None and to_hotel <= 70 and matrix.leg(room, following)[0] <= 70 and to_hotel + matrix.leg(room, following)[0] <= matrix.leg(local_items[-1], following)[0] * 1.25 + 10
                            if not local and not midway:
                                continue
                        elif following is not None and not transferred_after_visits:
                            # A transfer day must move towards the next visit.
                            if point(room) != point(current) and matrix.leg(room, following)[0] >= matrix.leg(current, following)[0]:
                                continue
                        if not travel(room):
                            now, current, driving, km, legs = saved
                            continue
                    new_cost = cost + (float(room["price_per_night"]) if room else 0)
                    if new_cost > budget:
                        saw_budget = True
                        now, current, driving, km, legs = saved
                        continue
                    entry = {"day_number": day_index + 1, "date": date.isoformat(), "items": items,
                             "travel_legs": list(legs), "travel_distance_km": round(km, 2),
                             "travel_minutes": round(driving, 1), "day_start_time": clock(day_start), "day_end_time": clock(now),
                             "start_hotel_id": current_hotel.get("hotel_id"), "end_hotel_id": room.get("hotel_id") if room else None}
                    stay = {**room, "check_in": date.isoformat(), "check_out": (date + timedelta(days=1)).isoformat()} if room else None
                    new_coverage = coverage | (hotel_coverage[room["room_id"]] if room else 0)
                    if final_day and new_coverage != full_coverage:
                        now, current, driving, km, legs = saved
                        continue
                    new_effort = effort + (driving / 60) ** 2
                    label = (end_index, room or current, new_cost, distance + km, schedule + [entry], stays + ([stay] if stay else []), new_coverage, new_effort, transfer_index)
                    key = (end_index, room["room_id"] if room else None, new_coverage, transfer_index)
                    bucket = buckets.setdefault(key, [])
                    if not any(old[2] <= new_cost and old[3] <= distance + km and old[7] <= new_effort for old in bucket):
                        bucket[:] = [old for old in bucket if not (new_cost <= old[2] and distance + km <= old[3] and new_effort <= old[7])]
                        bucket.append(label)
                    now, current, driving, km, legs = saved
        previous_labels = labels
        labels = [label for bucket in buckets.values() for label in bucket]
        if not labels:
            code = "BUDGET_EXCEEDED" if saw_budget else "TRAVEL_TIME_INFEASIBLE"
            requested_names = [
                destination.get("destination_name") or str(destination["destination_id"])
                for destination in state.get("requested_destinations", [])
            ]
            route_label = " -> ".join(requested_names) or "the requested destination order"
            message = (
                "No complete hotel and journey plan fits the budget. "
                "Increase the budget or reduce destinations."
                if saw_budget
                else f"The requested route ({route_label}) cannot fit into {days} days "
                     "with the available hotel stays and booked transfer times. "
                     "The planner requires at most ten driving hours per day, a "
                     "twelve-hour day ending by 20:00, and transfer departures no "
                     "earlier than 06:00."
            )
            raise RoutePlanningError(code, message, {
                "requested_days": days,
                "failed_day": day_index + 1,
                "destination_count": len(destination_ids),
                "remaining_tours": len(tours) - min((label[0] for label in previous_labels), default=0),
                "max_driving_minutes": MAX_DRIVING_MINUTES,
                "max_day_minutes": MAX_DAY_MINUTES,
                "earliest_transfer_start": "06:00",
                "finish_by": "20:00",
                "transport_duration_source": "scheduled_arrival_minus_departure",
            })
        if len(labels) > 20000:
            raise RoutePlanningError("ROUTE_SEARCH_LIMIT", "This trip has too many hotel combinations. Please select fewer destinations.")
    # Small distance differences can be traded for more balanced driving days.
    best = min(labels, key=lambda label: (round(label[3] / 10), label[7], label[2]))
    stays = []
    for stay in best[5]:
        if stays and stays[-1]["room_id"] == stay["room_id"] and stays[-1]["check_out"] == stay["check_in"]:
            stays[-1]["check_out"] = stay["check_out"]
            stays[-1]["nights"] += 1
        else:
            stays.append({**stay, "nights": 1})
    return {**itinerary, "schedule": best[4], "travel_distance_km": round(best[3], 2),
            "travel_policy": {"max_driving_minutes": MAX_DRIVING_MINUTES, "day_start": "08:00", "earliest_transfer_start": "06:00", "max_day_minutes": MAX_DAY_MINUTES, "day_end": "20:00", "shared_hotel_radius_km": 50, "midway_hotel_radius_km": 70}}, stays


def endpoint(record):
    return {"latitude": record["latitude"], "longitude": record["longitude"],
            "name": record.get("tour_name") or record.get("hotel_name") or record.get("name"),
            "kind": "hotel" if record.get("hotel_id") else record.get("kind", "tour")}
