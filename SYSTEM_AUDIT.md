BACKEND STATUS: ❌ NOT COMPLETE — 2 items remaining
- Secrets: Hardcoded `StaffSecretCode` and `Jwt:Key` found in `appsettings.json`.
- Pagination/Search: `Preference`, `Room`, and `TripRequest` endpoints lack full search/filter/sort/pagination.

---

# Backend Implementation & Readiness Audit

## Audit History

| Date | Status | Blockers | Key Changes & Notes |
|---|---|---|---|
| **2026-09-11 (Fix: Component C)** | ❌ NOT COMPLETE | 2 remaining | **Component C resolved**: Added `REPEATABLE READ` transaction + `SELECT ... FOR UPDATE` row-locking in `BookingService.CreateBookingAsync`. For every Room item, the Room row is locked before the availability re-count and the lock is held until the `BookingItem` INSERT commits, eliminating the race window between check and write. `InvalidOperationException` on over-capacity → existing controller `catch` → 400 Bad Request with clear message. No migration required. |
| **2026-09-11 (Fix: Component A)** | ❌ NOT COMPLETE | 3 remaining | **Component A resolved**: Added Preference validation inside `TripRequestService.CreateAsync`. Before saving, the service now queries the customer's `Preference` row and throws `ArgumentException` (→ 400 Bad Request) if `BudgetCeiling` is below `Preference.BudgetMin`. Follows the existing `ArgumentException` pattern in the same method. 3 items remain. |
| **2026-09-11 (Re-Audit)** | ❌ NOT COMPLETE | 4 remaining | **Regressions / Overlooked Items Discovered**: Found that Preference validation before TripRequest is entirely missing (Component A). AvailabilityService implements real overlap counting but lacks the required transaction/locking mechanism (Component C). Hardcoded secrets (`StaffSecretCode` and `Jwt:Key`) found in `appsettings.json`. Several entities (`Preference`, `Room`, `TripRequest`) lack full search, filter, sort, or pagination capabilities. |
| **2026-09-11 (Post-Implementation)** | ✅ 100% COMPLETE | 0 remaining | **Full Backend Gap Resolution**: All 11 pending items systematically resolved: Real availability logic implemented in `AvailabilityService.cs` querying active overlapping room and seat bookings; scaffolded EF Core migration `20260911115503_AddStudentDTables` for Student D tables (`Bookings`, `BookingItems`, `BookingApprovals`, `Payments`, `TravelAgents`); restricted CORS origins to `localhost:5173`/`localhost:3000`; removed hardcoded fallback password from `Program.cs`; implemented global exception handler middleware; added customer ownership verification to payment and customer profile endpoints preventing IDOR; updated `AgentLog` with `StepType`, `ToolName`, and `DurationMs`; added automatic startup role seeding for `Customer`, `TravelAgent`, and `Admin`; added data validation annotations across all inventory and destination DTOs; added sorting, search, and pagination across Tour and Destination endpoints. `dotnet build` passes with 0 warnings and 0 errors. |
| **2026-09-11 (Post-Merge)** | ❌ NOT COMPLETE | 11 remaining | **Post-Merge Audit**: Merged 20 commits from `origin/main` (contributions from Students B, C, and D). Resolved 10 blockers from the previous audit: Booking CRUD & workflow state machine implemented, Approval auditing & role authorization active, Payment status guards & Stripe sandbox reference in place, Itinerary conflict checks functional, Staff registration with secret key implemented, and Vendor search/filter/soft-delete completed. 11 blockers remained. |
| **2026-09-09** | ❌ NOT COMPLETE | 21 remaining | **Initial Comprehensive Audit**: Identified lack of Student D implementations (no Booking/Payment/Approval services or controllers), stubbed AvailabilityService, missing migrations, and open CORS. |

---

## Detailed Findings

### 1. Project Setup & Configuration
`PASS` — JWT auth config is present, Identity roles are seeded on startup, CORS is scoped to localhost, Swagger has Bearer auth, no real DB connection string secrets are hardcoded, and global exception handling is implemented.

### 2. Database Models & Schema
`PASS` — All 17 tables exist with correct fields and relationships. `BookingReference` has a unique constraint. `BookingItem` exclusive FK requirement (TourId/RoomId/TransportOptionId) is strictly enforced in `BookingService.cs`.

### 3. Controller Authorization & Validation
`PASS` — Every controller action has `[Authorize]` or `[Authorize(Roles=...)]`. Input validation is checked and proper HTTP status codes (400/401/403/404) are returned on failures.

### 4. Ownership & IDOR Protection
`PASS` — Explicit ownership checks are present and functional:
- **TripRequest**: Evaluates `t.CustomerId == customerId`.
- **Itinerary**: Returns 403 Forbidden if `itinerary.CustomerId != userId`.
- **Booking**: Returns 403 Forbidden via `UnauthorizedAccessException` handled in the controller.
- **Payment**: `GetPaymentById` and `GetPaymentsByBooking` return 403 Forbidden if the customer doesn't own the payment.
- **Preference/Notification**: Have no exposed ID paths for unauthorized access (`GetMyPreferences` / `GetMyNotifications`).

### 5. Business Logic
- **Component A**: `PASS` — Full preference + date validation added in [`TripRequestService.cs`](file:///c:/Users/Pasindu/OneDrive/Documents/Year%203%20sem%201/Software%20Engineering%20Frameworks/Main%20Project/se3090-travel-planning/backend/Services/TripRequestService.cs) inside `CreateAsync`. After fetching the customer's `Preference` row the service enforces three checks (all throw `ArgumentException` → 400): (1) `BudgetCeiling < Preference.BudgetMin` when `BudgetMin > 0`; (2) `dto.StartDate.Date < DateTime.UtcNow.Date` (start in the past); (3) `dto.StartDate.Date >= dto.EndDate.Date` (start not strictly before end). Each error message quotes the actual values supplied.
- **Component B**: `PASS` — Itinerary items reject same-day time overlap using the exact check: `dto.StartTime < existing.EndTime && dto.EndTime > existing.StartTime`.
- **Component C**: `PASS` — `BookingService.CreateBookingAsync` now opens a `REPEATABLE READ` transaction and issues `SELECT * FROM "Rooms" WHERE "Id" = {0} FOR UPDATE` (via `FromSqlRaw`) for every Room item before re-counting overlapping active bookings. The PostgreSQL row lock is held until the `BookingItem` row is committed, serialising concurrent requests. If the room is no longer available at lock time the service throws `InvalidOperationException` with a message quoting room type, dates, requested quantity, and actual available count — the controller's existing `catch (InvalidOperationException)` block converts this to 400 Bad Request.
- **Component D**: `PASS` — Booking status transitions are guarded (`current, target` switch prevents skipping `AwaitingApproval`). Payment strictly requires `Confirmed` status. `BookingApproval` row is written on every human decision.

### 6. Stripe Integration
`PASS` — Stripe keys are not hardcoded or committed to the repository.

### 7. Secrets Hygiene
`FAIL` — Real secrets are hardcoded in `backend/appsettings.json` (`StaffSecretCode: "se3090-staff-2026"` and `Jwt:Key: "YourSuperSecretKeyThatIsAtLeast32CharactersLong!!"`).

### 8. CRUD & Search/Filter/Sort/Pagination
`PARTIAL` — Supported cleanly on `Customer`, `Destination`, `Tour`, `Hotel`, `TransportOption`. However, `Preference`, `Room`, and `TripRequest` lack full search, filter, sort, or pagination support.

### 9. Migrations
`PASS` — The latest migration (`20260911115503_AddStudentDTables`) matches the current models.

### 10. Data Transfer Objects (DTOs)
`PASS` — DTOs are used correctly everywhere. Required-field validations are present, and invalid FK operations return appropriate 400/404 codes via caught exceptions.

---

## Remaining Action Items
- [x] ~~Implement Preference validation (budget/date logic) before TripRequest is accepted (Component A).~~ **DONE** — added in `TripRequestService.CreateAsync`.
- [x] ~~Wrap AvailabilityService logic in a database transaction/locking mechanism to prevent simultaneous bookings of the last unit (Component C).~~ **DONE** — `REPEATABLE READ` + `FOR UPDATE` added in `BookingService.CreateBookingAsync`.
- [ ] Remove hardcoded `StaffSecretCode` and `Jwt:Key` from `appsettings.json` and manage them via user-secrets or environment variables.
- [ ] Add search/filter/sort/pagination support to `Preference`, `Room`, and `TripRequest` endpoints.
