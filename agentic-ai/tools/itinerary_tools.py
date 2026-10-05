"""Backend persistence tools for Student B's itinerary agent."""

from __future__ import annotations

import os
from typing import Any

import httpx


class ItineraryPersistenceError(RuntimeError):
    """Raised when a generated itinerary cannot be safely persisted."""


def _backend_url() -> str:
    base = os.getenv("BACKEND_API_URL") or os.getenv(
        "BACKEND_URL", "http://127.0.0.1:5138"
    )
    base = base.rstrip("/")
    return base[:-4] if base.lower().endswith("/api") else base


def _message(response: httpx.Response) -> str:
    try:
        body = response.json()
        if isinstance(body, dict):
            return str(body.get("message") or body.get("detail") or body)
        return str(body)
    except ValueError:
        return response.text or f"HTTP {response.status_code}"


def persist_itinerary(
    state: dict[str, Any],
    itinerary: dict[str, Any],
    *,
    client: httpx.Client | None = None,
) -> int:
    """Persist an itinerary and all scheduled items through the backend API."""

    token = str(state.get("access_token") or state.get("auth_token") or "").strip()
    if not token:
        raise ItineraryPersistenceError("Itinerary persistence requires an authenticated backend token.")

    headers = {"Authorization": f"Bearer {token}"}
    owns_client = client is None
    http = client or httpx.Client(timeout=15.0)
    try:
        response = http.post(
            f"{_backend_url()}/api/itinerary",
            headers=headers,
            json={
                "customerId": state.get("customer_id"),
                "tripRequestId": state.get("trip_request_id"),
                "startDate": state.get("start_date"),
                "endDate": state.get("end_date"),
                "currency": state.get("currency"),
            },
        )
        if response.status_code not in (200, 201):
            raise ItineraryPersistenceError(
                f"Itinerary creation failed ({response.status_code}): {_message(response)}"
            )
        created = response.json()
        itinerary_id = created.get("id") if isinstance(created, dict) else None
        if not isinstance(itinerary_id, int) or itinerary_id <= 0:
            raise ItineraryPersistenceError(
                "Itinerary API did not return a positive database ID."
            )

        for day in itinerary.get("schedule", []):
            for sequence, item in enumerate(day.get("items", []), start=1):
                item_response = http.post(
                    f"{_backend_url()}/api/itinerary/{itinerary_id}/items",
                    headers=headers,
                    json={
                        "tourId": item.get("tour_id"),
                        "dayNumber": day.get("day_number"),
                        "sequenceOrder": sequence,
                        "startTime": item.get("start_time"),
                        "endTime": item.get("end_time"),
                    },
                )
                if item_response.status_code not in (200, 201):
                    raise ItineraryPersistenceError(
                        f"Itinerary item persistence failed ({item_response.status_code}): "
                        f"{_message(item_response)}"
                    )
        return itinerary_id
    finally:
        if owns_client:
            http.close()

