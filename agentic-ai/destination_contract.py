"""Shared multi-destination contract and deterministic coverage checks."""

from __future__ import annotations

from typing import Any


class DestinationContractError(ValueError):
    """A safe, stable error for malformed destination selections."""

    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code


def is_valid_route_order(
    planned_order: Any,
    requested_order: list[int],
    *,
    starter_location_id: Any = None,
    airport_pickup: bool = False,
) -> bool:
    """Validate route membership without inventing a starter constraint.

    A customer-selected starter must be first. With no selected starter, the
    route may be any complete permutation so the optimizer can choose the
    shortest open path. Airport pickup precedes the first destination; a
    selected starter still pins that first destination.
    """
    if not isinstance(planned_order, list) or not requested_order:
        return False
    if len(planned_order) != len(requested_order):
        return False
    try:
        planned_ids = [int(value) for value in planned_order]
        requested_ids = [int(value) for value in requested_order]
    except (TypeError, ValueError):
        return False
    if sorted(planned_ids) != sorted(requested_ids):
        return False
    if starter_location_id is None:
        return True
    try:
        return planned_ids[0] == int(starter_location_id)
    except (TypeError, ValueError):
        return False


def normalize_requested_destinations(payload: dict[str, Any], *, required: bool = False) -> list[dict[str, Any]]:
    """Return ordered ``destination_id``/``destination_name`` records.

    ``requested_destinations`` is authoritative for new callers. The legacy
    singular fields and ``destination_ids`` remain accepted for compatibility.
    IDs are never inferred from display text.
    """

    raw = payload.get("requested_destinations")
    if raw is None:
        raw = payload.get("destinations")

    selections: list[dict[str, Any]] = []
    if isinstance(raw, list):
        for index, item in enumerate(raw):
            if isinstance(item, dict):
                value = item.get("destination_id", item.get("id"))
                name = item.get("destination_name", item.get("name"))
                order = item.get("order", index)
            else:
                value = item
                name = None
                order = index
            selections.append({"destination_id": value, "destination_name": name or "", "order": order})

    if not selections:
        ids = payload.get("destination_ids") or payload.get("destinationIds") or []
        names = payload.get("destination_names") or payload.get("destinationNames") or []
        if isinstance(ids, list):
            selections = [
                {
                    "destination_id": value,
                    "destination_name": names[index] if isinstance(names, list) and index < len(names) else "",
                    "order": index,
                }
                for index, value in enumerate(ids)
            ]

    legacy_id = payload.get("destination_id")
    if legacy_id is not None and not any(item["destination_id"] == legacy_id for item in selections):
        selections.insert(
            0,
            {
                "destination_id": legacy_id,
                "destination_name": payload.get("destination_name") or "",
                "order": 0,
            },
        )

    normalized: list[dict[str, Any]] = []
    seen: set[int] = set()
    for index, item in enumerate(selections):
        try:
            destination_id = int(item["destination_id"])
        except (KeyError, TypeError, ValueError):
            raise DestinationContractError(
                "DESTINATION_ID_INVALID", "Every selected destination must have a database ID."
            ) from None
        if destination_id <= 0:
            raise DestinationContractError(
                "DESTINATION_ID_INVALID", "Every selected destination ID must be positive."
            )
        if destination_id in seen:
            raise DestinationContractError(
                "DESTINATION_DUPLICATE", f"Destination {destination_id} was selected more than once."
            )
        seen.add(destination_id)
        normalized.append(
            {
                "destination_id": destination_id,
                "destination_name": str(item.get("destination_name") or "").strip(),
                "order": index,
            }
        )

    if required and not normalized:
        raise DestinationContractError(
            "DESTINATIONS_REQUIRED", "At least one database-backed destination is required."
        )
    return normalized


def validate_destination_coverage(
    result: dict[str, Any],
    requested_destinations: list[dict[str, Any]],
    available_tours: list[dict[str, Any]],
) -> list[str]:
    """Ensure every requested destination appears in the final tour schedule."""

    errors: list[str] = []
    requested_ids = {item["destination_id"] for item in requested_destinations}
    scheduled_ids: set[int] = set()
    tours_by_id = {tour.get("id"): tour for tour in available_tours}

    for day in result.get("schedule", []):
        for item in day.get("items", []):
            tour = tours_by_id.get(item.get("tour_id"))
            destination_id = item.get("destination_id") or (tour or {}).get("destination_id")
            if destination_id is None:
                errors.append(f"Tour {item.get('tour_id')} has no destination ID.")
                continue
            try:
                destination_id = int(destination_id)
            except (TypeError, ValueError):
                errors.append(f"Tour {item.get('tour_id')} has an invalid destination ID.")
                continue
            if destination_id not in requested_ids:
                errors.append(f"Tour {item.get('tour_id')} belongs to an unrequested destination {destination_id}.")
            else:
                scheduled_ids.add(destination_id)

    for destination in requested_destinations:
        destination_id = destination["destination_id"]
        if destination_id not in scheduled_ids:
            label = destination["destination_name"] or str(destination_id)
            errors.append(f"Destination {label} ({destination_id}) is missing from the itinerary.")
    return errors
