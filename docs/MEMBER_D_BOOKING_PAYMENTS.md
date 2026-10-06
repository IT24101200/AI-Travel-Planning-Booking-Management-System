# Member D: Booking and Payments

## Responsibility

Member D owns the booking and payment workflow, including payment validation,
Stripe test-gateway handling, duplicate-payment protection, booking status
changes, and the booked-inventory presentation in the Flutter application.

## Evidence in the repository

| Area | Evidence |
| --- | --- |
| Booking service | `backend.Tests/BookingServiceTests.cs` |
| Payment service | `backend.Tests/PaymentServiceTests.cs` |
| Booked inventory UI | `mobile_flutter/test/booked_inventory_pages_test.dart` |
| Trip history UI | `mobile_flutter/test/trip_history_screen_test.dart` |
| Individual runner | `scripts/run-member-d-booking-payments.ps1` |

## Run independently

From the repository root on Windows PowerShell:

```powershell
.\scripts\run-member-d-booking-payments.ps1
```

Run only one side when demonstrating it separately:

```powershell
.\scripts\run-member-d-booking-payments.ps1 -BackendOnly
.\scripts\run-member-d-booking-payments.ps1 -FlutterOnly
```

## CI evidence

The workflow `.github/workflows/member-d-booking-payments.yml` runs these
checks as a dedicated job when this branch is pushed or a pull request is
opened. The pull request should reference the relevant issue with `Closes #N`.
