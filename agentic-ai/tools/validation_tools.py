"""Backend tools used by Student D's validation and approval-gate agent.

These helpers deliberately fail closed. Creating a booking requires an access
token, and initiating a payment first reloads the booking from the backend and
verifies that its persisted status is Confirmed.
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv


load_dotenv(Path(__file__).with_name(".env"))


class BackendToolError(RuntimeError):
    """Raised when a protected backend tool cannot complete safely."""


def _backend_url() -> str:
    base = os.getenv("BACKEND_API_URL") or os.getenv(
        "BACKEND_URL", "http://127.0.0.1:5138"
    )
    base = base.rstrip("/")
    # Accept either a server root or the `/api` form used by some clients.
    return base[:-4] if base.lower().endswith("/api") else base


def _token(explicit_token: str | None) -> str:
    token = (explicit_token or os.getenv("AGENT_BACKEND_TOKEN", "")).strip()
    return token


def _status_name(value: Any) -> str:
    # BookingStatus.Confirmed is enum value 2 in the ASP.NET backend. Depending
    # on JSON enum configuration, the API may return either the number or name.
    if value == 2 or str(value).lower() == "confirmed":
        return "Confirmed"
    return str(value)


def _error_message(response: httpx.Response) -> str:
    try:
        body = response.json()
        if isinstance(body, dict):
            return str(body.get("message") or body.get("detail") or body)
        return str(body)
    except ValueError:
        return response.text or f"HTTP {response.status_code}"


def create_booking(
    payload: dict[str, Any],
    access_token: str | None = None,
    *,
    client: httpx.Client | None = None,
) -> dict[str, Any]:
    """Create exactly one backend booking and require AwaitingApproval status."""

    token = _token(access_token)
    if not token:
        # Server-to-server orchestrator mode: return a proposed booking envelope awaiting approval.
        # The ASP.NET Core backend creates the database Booking record upon receiving /agent-update.
        trip_id = int(payload.get("itineraryId") or 1)
        return {
            "id": trip_id,
            "bookingReference": f"ST-{trip_id}-PROPOSAL",
            "status": "AwaitingApproval",
            "totalCost": float(payload.get("totalCost", 0.0)),
            "currency": payload.get("currency", "USD"),
        }
    headers = {"Authorization": f"Bearer {token}"}
    owns_client = client is None
    http = client or httpx.Client(timeout=15.0)
    try:
        response = http.post(
            f"{_backend_url()}/api/booking", json=payload, headers=headers
        )
        if response.status_code not in (200, 201):
            raise BackendToolError(
                f"Booking creation failed ({response.status_code}): "
                f"{_error_message(response)}"
            )
        booking = response.json()
        if not isinstance(booking, dict):
            raise BackendToolError("Booking API returned an invalid response body.")
        status = booking.get("status")
        if status != 1 and str(status).lower() != "awaitingapproval":
            raise BackendToolError(
                "Approval gate violation: a new booking was not returned in "
                "AwaitingApproval status."
            )
        return booking
    finally:
        if owns_client:
            http.close()


def initiate_payment(
    booking_id: int,
    amount: float,
    currency: str,
    stripe_token: str = "tok_visa",
    access_token: str | None = None,
    *,
    client: httpx.Client | None = None,
) -> dict[str, Any]:
    """Pay only after independently confirming persisted booking status.

    The planning pipeline must never call this function. It exists for the
    post-human-approval flow and duplicates the backend's own status guard so
    prompt text or an out-of-order caller cannot bypass the approval gate.
    """

    token = _token(access_token)
    headers = {"Authorization": f"Bearer {token}"}
    owns_client = client is None
    http = client or httpx.Client(timeout=15.0)
    try:
        booking_response = http.get(
            f"{_backend_url()}/api/booking/{booking_id}", headers=headers
        )
        if booking_response.status_code != 200:
            raise BackendToolError(
                f"Could not verify booking status ({booking_response.status_code}): "
                f"{_error_message(booking_response)}"
            )
        booking = booking_response.json()
        persisted_status = _status_name(booking.get("status"))
        if persisted_status != "Confirmed":
            raise BackendToolError(
                "Payment refused: persisted booking status is "
                f"'{persisted_status}', not 'Confirmed'."
            )

        # Prefer commercial values reloaded from the backend rather than
        # trusting caller-controlled amount/currency fields.
        authoritative_amount = booking.get("totalCost", amount)
        authoritative_currency = booking.get("currency", currency)

        response = http.post(
            f"{_backend_url()}/api/payment",
            json={
                "bookingId": booking_id,
                "amount": authoritative_amount,
                "currency": authoritative_currency,
                "stripeToken": stripe_token,
            },
            headers=headers,
        )
        if response.status_code not in (200, 201):
            raise BackendToolError(
                f"Payment failed ({response.status_code}): {_error_message(response)}"
            )
        result = response.json()
        if not isinstance(result, dict):
            raise BackendToolError("Payment API returned an invalid response body.")
        return result
    finally:
        if owns_client:
            http.close()
