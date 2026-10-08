"""Student D - deterministic package validation and human approval gate.

The validation agent is intentionally not LLM-driven. Upstream agents may use
LLMs to propose a package, but commercial rules are enforced with normal code.
On success this node returns a validated proposal. ASP.NET persists the
commercial records in one transaction and stops at AwaitingApproval.
"""

from __future__ import annotations

from datetime import datetime
from decimal import Decimal, InvalidOperation
from typing import Any

from logger import log_agent_step
from destination_contract import DestinationContractError, normalize_requested_destinations


class PackageValidationError(ValueError):
    """A safe, expected package validation failure with a stable error code."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def _decimal(value: Any, field: str) -> Decimal:
    try:
        result = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        raise PackageValidationError(
            "INVALID_NUMBER", f"{field} must be a valid number."
        ) from None
    if not result.is_finite() or result < 0:
        raise PackageValidationError(
            "INVALID_NUMBER", f"{field} must be a non-negative finite number."
        )
    return result


def _positive_int(value: Any, field: str) -> int:
    if isinstance(value, bool):
        raise PackageValidationError("INVALID_REFERENCE", f"{field} is invalid.")
    try:
        result = int(value)
    except (TypeError, ValueError):
        raise PackageValidationError("INVALID_REFERENCE", f"{field} is invalid.") from None
    if result <= 0:
        raise PackageValidationError(
            "INVALID_REFERENCE", f"{field} must be a positive database ID."
        )
    return result


def _currency(value: Any, field: str) -> str:
    result = str(value or "").strip().upper()
    if result not in {"LKR", "USD"}:
        raise PackageValidationError("INVALID_CURRENCY", f"{field} must be LKR or USD.")
    return result


def _trip_nights(start: Any, end: Any) -> int:
    try:
        start_date = datetime.fromisoformat(str(start).replace("Z", "+00:00")).date()
        end_date = datetime.fromisoformat(str(end).replace("Z", "+00:00")).date()
    except ValueError:
        raise PackageValidationError(
            "INVALID_DATES", "Trip dates must use ISO-8601 format."
        ) from None
    if end_date < start_date:
        raise PackageValidationError(
            "INVALID_DATES", "Trip end date cannot be before the start date."
        )
    return max(1, (end_date - start_date).days)


def _require_mapping(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise PackageValidationError(
            "INVALID_PACKAGE", f"{field} must be a JSON object."
        )
    return value


def validate_and_build_booking(state: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    """Validate upstream state and return (BookingCreateDto payload, checks)."""

    booking = _require_mapping(state.get("booking_details"), "booking_details")
    if booking.get("error"):
        raise PackageValidationError(
            "UPSTREAM_BOOKING_FAILED", str(booking["error"])
        )

    itinerary = _require_mapping(
        booking.get("itinerary") or state.get("itinerary"), "itinerary"
    )
    try:
        # Legacy pipeline fixtures may not carry a destination at the booking
        # validation stage. Enforce complete coverage only when a destination
        # contract is actually present; the itinerary agent still requires one
        # before searching inventory.
        requested_destinations = normalize_requested_destinations(state, required=False)
    except DestinationContractError as error:
        raise PackageValidationError(error.code, str(error)) from None
    customer_id = str(state.get("customer_id") or "").strip()
    if not customer_id:
        raise PackageValidationError(
            "MISSING_CUSTOMER", "customer_id is required to create a booking."
        )

    travellers = _positive_int(state.get("traveller_count", 1), "traveller_count")
    nights = _trip_nights(state.get("start_date"), state.get("end_date"))
    request_currency = _currency(state.get("currency"), "request currency")
    package_currency = _currency(
        booking.get("currency") or itinerary.get("currency") or request_currency,
        "package currency",
    )
    if request_currency != package_currency:
        raise PackageValidationError(
            "CURRENCY_MISMATCH",
            f"Package currency {package_currency} does not match budget currency "
            f"{request_currency}.",
        )

    budget = _decimal(state.get("budget_ceiling"), "budget_ceiling")
    reported_total = _decimal(
        booking.get("total_cost", booking.get("total_package_cost")),
        "booking total",
    )
    if reported_total <= 0:
        raise PackageValidationError(
            "INVALID_TOTAL", "Booking total must be greater than zero."
        )

    items: list[dict[str, Any]] = []
    calculated_total = Decimal("0")
    schedule = itinerary.get("schedule", [])
    if not isinstance(schedule, list):
        raise PackageValidationError(
            "INVALID_ITINERARY", "itinerary.schedule must be a list."
        )
    for day in schedule:
        day_map = _require_mapping(day, "itinerary day")
        day_items = day_map.get("items", [])
        if not isinstance(day_items, list):
            raise PackageValidationError(
                "INVALID_ITINERARY", "Each itinerary day must contain an items list."
            )
        for tour in day_items:
            tour_map = _require_mapping(tour, "tour item")
            tour_id = _positive_int(
                tour_map.get("tour_id") or tour_map.get("tourId"), "tour_id"
            )
            price = _decimal(tour_map.get("price"), f"tour {tour_id} price")
            calculated_total += price * travellers
            items.append(
                {
                    "itemType": 0,
                    "tourId": tour_id,
                    "quantity": travellers,
                    "unitPrice": float(price),
                }
            )

    if len(requested_destinations) > 1:
        requested_ids = {destination["destination_id"] for destination in requested_destinations}
        scheduled_ids = {
            int(item.get("destination_id"))
            for day in schedule
            for item in day.get("items", [])
            if item.get("destination_id") is not None
        }
        missing_ids = requested_ids - scheduled_ids
        if missing_ids:
            raise PackageValidationError(
                "MISSING_DESTINATION_COVERAGE",
                "The itinerary does not contain every requested destination: "
                + ", ".join(str(destination_id) for destination_id in sorted(missing_ids)),
            )

    selections = booking.get("room_selections")
    legacy_room = selections is None
    if selections is None:
        selections = [{**_require_mapping(booking.get("selected_room"), "selected_room"),
                       "check_in": state.get("start_date"), "check_out": state.get("end_date")}]
    if not isinstance(selections, list) or not selections:
        raise PackageValidationError("INVALID_ROOM_STAYS", "At least one dated hotel stay is required.")
    expected_check_in = datetime.fromisoformat(str(state["start_date"]).replace("Z", "+00:00")).date()
    trip_end = datetime.fromisoformat(str(state["end_date"]).replace("Z", "+00:00")).date()
    for value in selections:
        room = _require_mapping(value, "room stay")
        room_id = _positive_int(room.get("room_id") or room.get("roomId"), "room_id")
        check_in = datetime.fromisoformat(str(room["check_in"]).replace("Z", "+00:00")).date()
        check_out = datetime.fromisoformat(str(room["check_out"]).replace("Z", "+00:00")).date()
        same_day_legacy = legacy_room and check_in == check_out == trip_end
        if check_in != expected_check_in or (check_out <= check_in and not same_day_legacy) or check_out > trip_end:
            raise PackageValidationError("INVALID_ROOM_STAYS", "Hotel stays must cover every trip night exactly once, in date order.")
        expected_check_in = check_out
        room_price = _decimal(room.get("price_per_night", room.get("pricePerNight")), "room price_per_night")
        room_total = room_price * max(1, (check_out - check_in).days)
        calculated_total += room_total
        items.append({"itemType": 1, "roomId": room_id,
                      "checkInDate": check_in.isoformat(), "checkOutDate": check_out.isoformat(),
                      "quantity": 1, "unitPrice": float(room_total)})
    if expected_check_in != trip_end:
        raise PackageValidationError("INVALID_ROOM_STAYS", "Hotel stays do not cover the complete trip.")

    route_ids = itinerary.get("route_destination_ids")
    if route_ids is not None:
        if sorted(route_ids) != sorted(d["destination_id"] for d in requested_destinations):
            raise PackageValidationError("INVALID_DESTINATION_ORDER", "The optimized route must contain every requested destination exactly once.")
        visited = []
        for day in schedule:
            if _decimal(day.get("travel_minutes", 0), "daily driving") > 360:
                raise PackageValidationError("TRAVEL_TIME_INFEASIBLE", "A day exceeds six hours driving.")
            for item in day.get("items", []):
                destination = item.get("destination_id")
                if not visited or visited[-1] != destination:
                    visited.append(destination)
        if visited != route_ids:
            raise PackageValidationError("DESTINATION_BACKTRACKING", "Complete a destination's journeys before travelling to the next destination.")

    if len(requested_destinations) > 1 or state.get("airport_pickup"):
        selections = booking.get("transport_selections")
        expected_count = len(requested_destinations) - 1 + int(bool(state.get("airport_pickup")))
        if not isinstance(selections, list) or len(selections) != expected_count:
            raise PackageValidationError(
                "TRANSPORT_LEG_COVERAGE_INCOMPLETE",
                "A multi-leg transport plan must provide exactly one selection for every adjacent destination leg.",
            )

        normalized_selections: dict[int, dict[str, Any]] = {}
        for selection_value in selections:
            selection = _require_mapping(selection_value, "transport selection")
            leg_index = selection.get("leg_index", selection.get("legIndex"))
            if isinstance(leg_index, bool):
                raise PackageValidationError(
                    "TRANSPORT_LEG_COVERAGE_INCOMPLETE",
                    "Each transport selection must contain a non-negative leg_index.",
                )
            try:
                leg_index = int(leg_index)
            except (TypeError, ValueError):
                raise PackageValidationError(
                    "TRANSPORT_LEG_COVERAGE_INCOMPLETE",
                    "Each transport selection must contain a non-negative leg_index.",
                ) from None
            if leg_index < 0 or leg_index >= expected_count or leg_index in normalized_selections:
                raise PackageValidationError(
                    "TRANSPORT_LEG_COVERAGE_INCOMPLETE",
                    "Transport leg indexes must be unique and exactly cover every adjacent destination leg.",
                )
            transport_id = _positive_int(
                selection.get("transport_option_id")
                or selection.get("transportOptionId")
                or selection.get("transport_id")
                or selection.get("transportId"),
                "transport_option_id",
            )
            transport_price = _decimal(
                selection.get("price", selection.get("unit_price", selection.get("unitPrice"))),
                "transport price",
            )
            normalized_selections[leg_index] = {
                "transport_option_id": transport_id,
                "transport_price": transport_price,
            }

        for leg_index in range(expected_count):
            selection = normalized_selections[leg_index]
            calculated_total += selection["transport_price"] * travellers
            items.append(
                {
                    "itemType": 2,
                    "transportOptionId": selection["transport_option_id"],
                    "transportLegIndex": leg_index,
                    "quantity": travellers,
                    "unitPrice": float(selection["transport_price"]),
                }
            )
    else:
        transport = _require_mapping(
            booking.get("selected_transport"), "selected_transport"
        )
        transport_id = _positive_int(
            transport.get("transport_id") or transport.get("transportId"),
            "transport_id",
        )
        transport_price = _decimal(transport.get("price"), "transport price")
        calculated_total += transport_price * travellers
        items.append(
            {
                "itemType": 2,
                "transportOptionId": transport_id,
                "quantity": travellers,
                "unitPrice": float(transport_price),
            }
        )

    if abs(calculated_total - reported_total) > Decimal("0.01"):
        raise PackageValidationError(
            "TOTAL_MISMATCH",
            f"Reported package total {reported_total} {package_currency} does not "
            f"match recalculated total {calculated_total} {package_currency}.",
        )
    if reported_total > budget:
        raise PackageValidationError(
            "BUDGET_EXCEEDED",
            f"Package total {reported_total} {package_currency} exceeds budget "
            f"ceiling {budget} {request_currency}.",
        )

    payload = {
        "tripRequestId": int(state.get("trip_request_id") or 0),
        "customerId": customer_id,
        "totalCost": float(reported_total),
        "currency": package_currency,
        "items": items,
    }
    checks = {
        "schema_valid": True,
        "currency_valid": True,
        "total_recalculated": float(calculated_total),
        "within_budget": True,
        "approval_gate_enforced": True,
    }
    return payload, checks


def validation_node(state: dict[str, Any]) -> dict[str, Any]:
    """LangGraph node for Student D's validation and approval gate."""

    trip_id = int(state.get("trip_request_id") or 0)
    try:
        payload, checks = validate_and_build_booking(state)
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="ValidationAgent",
            step_name="Validated package against commercial rules",
            step_type="Validation",
            input_data={
                "budget_ceiling": state.get("budget_ceiling"),
                "currency": state.get("currency"),
            },
            output_data=checks,
        )

        result = {
            "is_valid": True,
            "checks": checks,
            "status": "AwaitingApproval",
        }
        plan_json = {
            "trip_request_id": trip_id,
            "customer_id": state.get("customer_id"),
            "requested_destinations": state.get("requested_destinations", []),
            "destination_ids": state.get("destination_ids", []),
            "airport_pickup": state.get("airport_pickup", False),
            "airport_code": state.get("airport_code", "CMB"),
            "plan_summary": state.get("plan_summary", {}),
            "itinerary": state.get("itinerary", {}),
            "booking_details": state.get("booking_details", {}),
            "validation": result,
        }
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="ValidationAgent",
            step_name="Prepared validated proposal for backend persistence",
            step_type="Validation",
            output_data={"status": "AwaitingApproval", "total": payload["totalCost"]},
        )
        return {
            "validation_result": result,
            "plan_json": plan_json,
            "status": "AwaitingApproval",
        }
    except PackageValidationError as error:
        code = getattr(error, "code", "BOOKING_CREATION_FAILED")
        message = str(error)
        booking_details = state.get("booking_details")
        upstream_error_code = (
            booking_details.get("error_code")
            if isinstance(booking_details, dict)
            else None
        )
        failure_output = {"is_valid": False, "error_code": code, "error": message}
        if upstream_error_code:
            failure_output["upstream_error_code"] = upstream_error_code
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="ValidationAgent",
            step_name="Rejected package before approval gate",
            step_type="Validation",
            output_data=failure_output,
            status="Failed",
        )
        validation_result = {
            "is_valid": False,
            "error_code": code,
            "error": message,
        }
        if upstream_error_code:
            validation_result["upstream_error_code"] = upstream_error_code
        return {
            "validation_result": validation_result,
            "status": "ValidationFailed",
        }
    except Exception as error:
        # Unexpected failures are still fail-closed and never create a fake
        # successful result or continue to payment.
        message = f"Unexpected validation failure: {error}"
        log_agent_step(
            trip_request_id=trip_id,
            agent_name="ValidationAgent",
            step_name="Validation agent failed safely",
            step_type="Validation",
            output_data={"is_valid": False, "error": message},
            status="Failed",
        )
        return {
            "validation_result": {
                "is_valid": False,
                "error_code": "VALIDATION_ERROR",
                "error": message,
            },
            "status": "ValidationFailed",
        }
