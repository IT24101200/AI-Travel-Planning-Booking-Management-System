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
    """Deprecated: proposal persistence is owned by ASP.NET."""
    raise ItineraryPersistenceError(
        "Direct AI itinerary persistence is disabled; submit the final proposal to ASP.NET."
    )

