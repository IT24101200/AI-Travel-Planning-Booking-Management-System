# Project Flow Audit — AI Travel Planning & Booking Management System

**Audit date:** 5 October 2026  
**Audit mode:** Strict read-only repository audit  
**Source of truth:** Current checked-out implementation. Markdown claims are treated as supporting evidence only.

## 1. Executive Verdict

**Overall status: MAJOR FLOW GAPS**

**Main answer: PARTIALLY.** The repository contains a substantial implementation of the intended architecture, but the demonstrated customer journey is not proven or safe end-to-end in the current checkout.

The intended diagram is directionally accurate for the main happy-path architecture, but it is not accurate as an implementation diagram because:

- trip-request creation returns immediately and starts AI in a background task;
- the Python service has synthetic/fallback booking behavior;
- itinerary/booking persistence is split between Python tools and an anonymous ASP.NET `agent-update` side effect;
- revision has no continuation route;
- payment creates a locally generated Stripe-like reference rather than calling Stripe;
- Flutter still contains demo fallback booking data and a local approval helper;
- several sensitive agent endpoints are anonymous.

The backend build passes, but current verification is not green: `dotnet test` reports 8 failures out of 37, React build/lint fail, Flutter analysis timed out, and Python tests could not run because Python is not available on PATH.

## 2. Architecture Actually Implemented

### 2.1 Real runtime topology

```text
Flutter
  └─ mobile_flutter/lib/services/api_service.dart
       └─ HTTP + Bearer JWT
            └─ ASP.NET Core controllers/services/EF Core
                 └─ PostgreSQL provider in production configuration

React
  └─ frontend-react/src/services/apiClient.js
       └─ Axios + localStorage Bearer JWT
            └─ ASP.NET Core controllers/services/EF Core

ASP.NET TripRequestController
  └─ fire-and-forget HTTP call to FastAPI /run-pipeline-async
       └─ LangGraph graph.py
            └─ Coordinator → Itinerary → Booking → Validation → Evaluator
                 ├─ search tours / hotels / rooms / transport through backend HTTP
                 ├─ optional Gemini calls for coordinator/itinerary/booking proposals
                 └─ agent-log and agent-update HTTP calls to ASP.NET
```

Flutter and React do not contain direct database access. Flutter does not directly call the Python service; its trip request goes to ASP.NET. This satisfies the intended client boundary structurally.

### 2.2 Actual ownership boundaries

| Student | Actual implementation boundary | Assessment |
|---|---|---|
| A | Customer/profile, preferences, notifications, trip requests, coordinator | Coherent; also owns shared trip-request-to-agent trigger code in `TripRequestController` |
| B | Destination, tour, itinerary, itinerary items, itinerary agent | Coherent; persistence is duplicated/bridged through both Python and ASP.NET agent-update paths |
| C | Hotel, rooms, transport, availability, booking agent | Coherent; booking agent uses backend HTTP inventory tools, while ASP.NET booking service repeats capacity checks |
| D | Booking, booking items, approvals, payment, validation agent | Coherent in domain ownership; payment implementation is a simulation, not a verified Stripe API integration |

## 3. End-to-End Flow Matrix

| Step | Expected behavior | Actual implementation/evidence | Status | Problem |
|---|---|---|---|---|
| 1. Open Flutter | App opens to customer landing/application | `mobile_flutter/lib/main.dart:50-72` defines landing and protected routes | PASS | Runtime build not independently verified |
| 2. Register | Customer account, profile, JWT created | `ApiService.register()` posts `/auth/register` (`api_service.dart:267-296`); `AuthController.Register()` creates Identity user, Customer, welcome notifications, JWT (`AuthController.cs:35-108`) | PASS | Registration transaction/error rollback is not fully handled if profile save fails after Identity creation |
| 3. Login | JWT issued and stored securely | `ApiService.login()` posts `/auth/login` and stores token/user ID/name (`api_service.dart:299-318`); backend signs JWT (`AuthController.cs:180-263`) | PASS | React has no registration flow; it depends on existing staff credentials |
| 4. Browse tours/destinations | Real catalogue data | Flutter calls `/destination` and `/tour`; backend public GET actions exist (`api_service.dart:355-399`, `TourController.cs`, `DestinationController.cs`) | PASS/PARTIAL | Flutter TODO still lists incomplete filtering/sorting; some UI content remains local/static |
| 5. Save profile/preferences | Persist customer data and preferences | `/customer/me` and `/preference` calls attach JWT (`api_service.dart:325-352`); controllers scope to current user | PASS | No independent Flutter analyzer/test verification in this audit |
| 6. Submit trip request | Form posts destination/dates/travellers/budget/preferences | `trip_request_screen.dart:236-245` posts `TripRequest`; backend validates dates, destination existence, preference minimum budget, and stores request (`TripRequestService.cs:18-113`) | PASS/PARTIAL | Free-text preferences are placed in `RawRequestText`; preferred activity tags are not sent as a typed field |
| 7. Persist TripRequest | Customer-owned row with status/retry/plan/failure fields | `TripRequestService.CreateAsync()` sets `CustomerId`, `Pending`, `RetryCount=0`, `CreatedAt` and saves | PASS | No durable workflow/job record for background trigger failure |
| 8. Start AI | ASP.NET routes request to Python | `TripRequestController.Create()` calls `TriggerAgentPipelineAsync(result)` (`TripRequestController.cs:40-64`); background task posts `/run-pipeline-async` (`TripRequestController.cs:366-432`) | PARTIAL | Fire-and-forget; HTTP 201 is returned even if agent service is offline. Backend silently invokes a local fallback when Python is unavailable |
| 9. Review AI plan | Itinerary is persisted with real IDs and items | Python has `persist_itinerary()` (`tools/itinerary_tools.py:33-95`), but no-token mode returns synthetic `trip_request_id`; automatic ASP.NET payload omits access token, so persistence is deferred to anonymous `agent-update` | PARTIAL | Duplicate/alternative persistence paths; persistence failure is logged asynchronously and not returned to customer |
| 10. Choose accommodation/transport | Real availability-backed choices | Booking agent calls `/api/hotel`, room availability, `/api/transport`, transport availability (`tools/availability_tools.py:8-60`) and filters active rows | PARTIAL | Search fallback broadens to any active hotel/transport and booking agent may use LLM proposal only after DB candidate selection; exact transport date/route matching is not enforced in the shown tool API |
| 11. See map | Selected real entities plotted | Flutter map and selection holder exist; Flutter TODO says real pins still need verification | PARTIAL | Current report cannot prove map coordinates derive from persisted selected hotel/tour/transport rather than inferred/default values |
| 12. Wait for approval | Booking is persisted as `AwaitingApproval`; human review required | `BookingService.CreateBookingAsync()` always creates `AwaitingApproval` (`BookingService.cs:188-206`); React calls `/Approval` | PASS for backend gate / PARTIAL overall | Python has synthetic proposal fallback and anonymous `agent-update`; actual automatic end-to-end evidence is missing |
| 13. Pay after approval | Only confirmed booking can be paid | `PaymentService.ProcessPaymentAsync()` rejects non-Confirmed (`PaymentService.cs:21-38`); Flutter disables Pay until local status is Confirmed | PASS backend guard / PARTIAL client | Payment service generates fake `ch_sb_...` reference; no Stripe SDK/API call |
| 14. Get ticket | Paid/confirmed booking data and reference available | Flutter QR uses `bookingReference`; PDF service consumes booking map (`booking_status_screen.dart:454-476`, `trip_confirmation_screen.dart:27-44,338-342`) | PARTIAL | Confirmation screen has hardcoded demo fallback; QR eligibility is based on Confirmed/Completed, not Paid |
| 15. Travel/confirmation | Customer sees current confirmed/paid status | Flutter fetches `/booking/{id}` or `/booking/my` and navigates to confirmation | PARTIAL | Payment does not update Booking to a paid state; no proof of fresh cross-client status update after approval/payment |

## 4. Four-Agent Flow

### 4.1 Coordinator — Student A

- **File/node:** `agentic-ai/agents/coordinator_agent.py`, `coordinator_plan()` and `coordinator_retry_evaluator()`; graph registration in `agentic-ai/graph.py:90-94`.
- **Inputs:** trip request ID, customer ID, destination, raw text, dates, traveller count, budget, currency, retry count.
- **Outputs:** `plan_summary`, `target_budgets`, `trip_days`, `status`, retry decision/failure reason.
- **State read/written:** reads request and retry fields; writes planning summary, budget allocation, status, retry count, failure reason.
- **Tools/API:** optional Gemini HTTP call in `call_gemini_for_planning()`; audit logging through `logger.log_agent_step()`.
- **LLM/determinism:** optional Gemini; deterministic budget allocation and rule-based fallback when Gemini is absent/unavailable.
- **Retry:** applies `discount_factor = 0.85` when `retry_count > 0` (`coordinator_agent.py:77-89`). Evaluator routes once back to coordinator when `current_retries < 1` and otherwise returns Failed (`coordinator_agent.py:174-224`).
- **Risk:** the reduced budget changes Coordinator target allocations, but the full downstream impact is not proven; `TripRequest` update is asynchronous.

### 4.2 Itinerary — Student B

- **File/node:** `agentic-ai/agents/itinerary_agent.py`, `itinerary_node()`.
- **Inputs:** destination ID, dates, traveller count, budget, currency, preferred activities.
- **Outputs:** itinerary structure with schedule, tour IDs, times, prices, currency, `itinerary_id`.
- **Tools/API:** `tools/search_tours.py` reads active tours through backend HTTP; `tools/itinerary_tools.py` posts itinerary and items through ASP.NET.
- **Validation:** deterministic active-tour, budget, overlap, and daily-count checks in `validate_itinerary()`.
- **Persistence:** with a usable access token, Python posts `/api/itinerary` then `/api/itinerary/{id}/items`; without a token it returns `trip_request_id` as a synthetic ID and expects ASP.NET `/agent-update` to materialize data.
- **AgentLog:** calls shared logger for search, generation, and validation; backend `AgentLog` currently persists `StepName`, `Input`, `Output`, `Status`, while `StepType`, `ToolName`, and `DurationMs` are `[NotMapped]` in `AgentLog.cs:24-35`.
- **Risk:** Python itinerary persistence and ASP.NET agent-update persistence can both participate in one run, creating duplicate itinerary/booking records when the manually-triggered path passes a token.

### 4.3 Booking/availability — Student C

- **File/node:** `agentic-ai/agents/booking_agent.py`, `booking_node()`.
- **Inputs:** itinerary state, trip dates, destination, traveller count, currency.
- **Outputs:** `booking_details`, selected room, selected transport, package total, copied itinerary.
- **Tools/API:** `search_hotels()`, `search_hotel_rooms()`, `check_room_availability()`, `search_transports()`, `check_transport_availability()`.
- **Real-data behavior:** candidate hotels/transport are fetched from backend and filtered to active; room availability is checked against backend availability endpoint.
- **LLM/determinism:** optional LLM chooses among fetched candidates; deterministic fallback selects cheapest fetched available room/transport. It does not invent IDs when candidate sets exist.
- **Failure handling:** returns `AvailabilityFailed` for missing itinerary/error/missing selections; tool failures return empty candidates.
- **AgentLog:** logs availability and package assembly, but backend storage does not persist structured fields claimed in the master document.
- **Risk:** route/date semantics for transport are thin: `check_transport_availability()` accepts only transport ID; availability endpoint does not accept the requested trip date in the inspected code.

### 4.4 Validation/approval — Student D

- **File/node:** `agentic-ai/agents/validation_agent.py`, `validation_node()`.
- **Inputs:** booking package, itinerary, customer ID, travellers, dates, request/package currency, budget.
- **Outputs:** validation result, checks, booking ID/reference, `plan_json`, `AwaitingApproval` status.
- **Checks:** numeric/date/currency validity, persisted itinerary ID presence, tour/room/transport reference shape, recalculated total, budget ceiling, and exact one-FK-per-item payload.
- **Persistence/API:** `tools/validation_tools.create_booking()` posts `/api/booking` when token exists. Without a token it returns a synthetic `ST-{itineraryId}-PROPOSAL` envelope. On `BackendToolError`, `validation_node()` also fabricates a successful proposal (`validation_agent.py:250-261`).
- **Approval gate:** validation never calls payment and labels the proposal as requiring human approval.
- **Risk:** synthetic success output is not a persisted booking and can be written into `PlanJson`; this is a critical auditability/integration weakness even though ASP.NET `BookingService` itself is guarded.

### 4.5 Fallback-node risk

`graph.py:14-45` catches `ImportError`/`AttributeError` and substitutes pass-through nodes for Itinerary, Booking, or Validation. A missing import or module attribute can therefore produce a graph that still compiles and completes with incomplete state. This is **HIGH risk** and contradicts the requirement that an agent node be genuinely functional. Current modules import successfully in static inspection, but the fallback remains executable failure behavior.

## 5. Persistence Chain

```text
TripRequest.Id
  → Python state trip_request_id
  → Itinerary.TripRequestId / Itinerary.CustomerId
  → Itinerary.Id
  → Booking.ItineraryId / Booking.CustomerId
  → Booking.Id + BookingReference
  → BookingApproval.BookingId
  → Payment.BookingId
```

### Verified generation and transfer points

1. **TripRequest ID:** generated by EF in `TripRequestService.CreateAsync()` and returned by `POST /api/TripRequest`.
2. **AI state ID:** backend sends `trip_request_id` to FastAPI in `TripRequestController.cs:387-400`.
3. **Itinerary ID:** real when `POST /api/itinerary` succeeds; otherwise Python no-token mode uses the TripRequest ID as a synthetic value. ASP.NET `AgentUpdate()` separately creates a real itinerary and receives its EF ID (`TripRequestController.cs:257-263`).
4. **Itinerary items:** Python can post real item IDs through `itinerary_tools.py`; ASP.NET `AgentUpdate()` can also add items from `PlanJson` (`TripRequestController.cs:267-301`).
5. **Booking ID/reference:** normally generated by `BookingService.CreateBookingAsync()` (`BookingService.cs:74-75,188-206`). Python no-token mode or validation error fallback can instead expose a synthetic ID/reference in state.
6. **BookingApproval ID:** generated by EF in `ApprovalService.CreateApprovalAsync()` and attached to the current authenticated travel-agent user.
7. **Payment ID:** generated by EF in `PaymentService.ProcessPaymentAsync()`.

### Persistence verdict

**PARTIAL, not a clean single chain.** The current code has two persistence strategies:

- token-bearing agent path: Python can create itinerary/items and booking directly;
- automatic backend-trigger path: Python returns synthetic envelopes and anonymous `agent-update` creates itinerary/items/booking asynchronously.

The second path is the one automatic TripRequest creation actually uses, because the automatic payload at `TripRequestController.cs:387-401` does not include `access_token`. It can work if `PlanJson` has the exact expected shape, but it is not transactional with TripRequest status update and failures are only logged.

## 6. Human Approval Gate

### Verdict: PASS at the ASP.NET commercial boundary; FAIL/PARTIAL for whole-system proof

Strong backend evidence:

- `BookingService.CreateBookingAsync()` sets every created booking to `AwaitingApproval` (`BookingService.cs:188-206`).
- `ValidateStatusTransition()` permits Draft → AwaitingApproval and AwaitingApproval → Confirmed/Rejected/Cancelled, but not Draft → Confirmed (`BookingService.cs:305-327`).
- `ApprovalService.CreateApprovalAsync()` accepts decisions only while booking is `AwaitingApproval`, persists `BookingApproval`, and maps Approved → Confirmed, Rejected → Rejected, RevisionRequested → AwaitingApproval (`ApprovalService.cs:21-79`).
- `PaymentService.ProcessPaymentAsync()` rejects any booking not in Confirmed state (`PaymentService.cs:26-38`).
- React approval page calls `POST /api/Approval` through `decideApproval()` (`frontend-react/src/services/apiClient.js:197-208`).

Important bypass/weaknesses:

- `POST /api/Booking` is available to any authenticated user and trusts caller-supplied `CustomerId`; it does not require staff role or enforce that a customer creates only for self (`BookingController.cs:29-55`).
- `PATCH /api/TripRequest/{id}/agent-update` is `[AllowAnonymous]` and can set arbitrary accepted enum status/PlanJson, then starts background itinerary/booking persistence (`TripRequestController.cs:230-363`).
- `POST /api/TripRequest/agent-log` is `[AllowAnonymous]`, allowing unauthenticated audit-log spoofing (`TripRequestController.cs:211-224`).
- Flutter checkout contains a “Student Demo Helper: Simulate Agent Approval” button that changes local status to Confirmed without calling the approval endpoint (`checkout_payment_screen.dart:420-435`). Backend payment still rejects an actually unconfirmed server booking, but the UI is misleading and can generate a demo confirmation object.

## 7. Retry, Failure, and Revision Paths

### Retry path

**PARTIAL.** The LangGraph evaluator does implement one retry:

```text
retry_count 0 + validation_result.is_valid false
    → retry_count 1
    → coordinator
    → effective budget × 0.85

retry_count >= 1 + invalid
    → Failed + failure_reason
    → graph END
```

Evidence: `coordinator_agent.py:174-224`, graph edge `graph.py:104-110`.

Problems:

- The evaluator defaults `validation_result` to `{}` and `is_valid` to `True` if missing (`coordinator_agent.py:183-186`), which is unsafe if a downstream node fails to write validation state.
- In the successful no-token path, synthetic validation output can make the pipeline appear successful without a persisted booking.
- Retry persistence depends on the final anonymous `agent-update`; failure to reach that endpoint only prints a warning from `graph.py:142-145`.
- A retry can persist another itinerary/booking through the asynchronous update path; deduplication by TripRequest is not enforced.

### Failure path

**PARTIAL.** Python returns `Failed`/`failure_reason` for validation failure and `graph.py` maps it to TripRequest status `Failed`. However, `sync_result_to_backend()` does not check the PATCH response status and failure of persistence is not surfaced to Flutter. ASP.NET background fallback exceptions are logged but do not update TripRequest to Failed.

### Revision path

**FAIL — UI-supported but workflow-incomplete.** `ApprovalService` records `RevisionRequested` but leaves Booking in `AwaitingApproval` (`ApprovalService.cs:73-75`). No endpoint starts a new TripRequest/agent run from a revision comment. Flutter’s `requestItineraryChanges()` explicitly throws because the API has no supported customer revision contract (`api_service.dart:462-470`). The React button records a decision, but there is no continuation into a revised proposal.

### Rejection path

**PASS for payment guard.** Rejected status is persisted by `ApprovalService`; `PaymentService` rejects payment because status is not Confirmed. A direct booking status route also cannot change Rejected to Confirmed under `ValidateStatusTransition()`.

## 8. Payment and Ticket Path

### Intended status order

```text
TripRequest planning
  → Booking AwaitingApproval
  → human Approved
  → Booking Confirmed
  → Payment Paid or Failed
  → Flutter confirmation / QR / PDF
```

### Actual behavior

- Payment API: Flutter `ApiService.createPayment()` posts `/payment` (`api_service.dart:546-556`).
- Server guard: `PaymentService` requires `BookingStatus.Confirmed`.
- Stripe behavior: `PaymentService` creates `ch_sb_<random>` and sets Paid, or Failed only when token equals `tok_chargeDeclined` (`PaymentService.cs:43-64`). There is no Stripe SDK/API request, publishable-key usage, webhook, or server-side Stripe charge.
- Duplicate payment: there is no guard against creating multiple Paid payment rows for one booking; repeated successful calls create multiple Payment records.
- Booking status after payment: PaymentService does not transition Booking status or maintain a paid marker; Payment row status is the only persisted payment result.
- Flutter success: checkout treats any 200/201 non-Failed response as success, sets local `paymentStatus=Paid`, and navigates to confirmation (`checkout_payment_screen.dart:177-203`).
- QR: `BookingStatusScreen` displays `QrImageView(data: reference)` for Confirmed or Completed (`booking_status_screen.dart:191-192,454-476`). This means QR eligibility is based on confirmation, not successful payment.
- PDF: `TicketPdfService` uses the booking map, but `TripConfirmationScreen` has hardcoded fallback booking data (`trip_confirmation_screen.dart:14-25`).

### Verdict

**PARTIAL.** Approval-before-payment is server-enforced, but Stripe is simulated, payment is not idempotent, and QR/confirmation can be available for Confirmed but unpaid bookings. This differs from a strict “payment success then ticket” interpretation.

## 9. Flutter Integration

### Real API-backed areas

- Auth: `/auth/register`, `/auth/login`; secure storage via `flutter_secure_storage` (`api_service.dart:50-78,267-318`).
- Profile/preferences: `/customer/me`, `/preference`.
- Catalogue: `/destination`, `/tour`, `/tour/{id}`.
- Trip requests: `/triprequest` and `/triprequest/my`.
- Itinerary reads/items/status: `/itinerary/customer/{userId}`, `/itinerary/{id}`, `/itinerary/{id}/items`.
- Hotel/transport lists: `/hotel`, `/transport`.
- Bookings/payments/notifications: `/booking/my`, `/booking/{id}`, `/payment`, `/notification/my`.

### Mock/demo/disconnected areas

- `ApiService` exposes mock delegates for nearly every major feature, mainly for tests; this is acceptable only if production delegates are always unset.
- `CheckoutPaymentScreen` has a hardcoded booking fallback with status Confirmed and fixed costs (`checkout_payment_screen.dart:48-64`).
- `TripConfirmationScreen` has a hardcoded fallback with `ST-2026-98214` (`trip_confirmation_screen.dart:14-25`).
- `MyItineraryScreen` creates a booking client-side if it cannot find one, using fallback user ID `customer-1`, cost `1712`, and tour ID `1` (`my_itinerary_screen.dart:306-329`). This bypasses the intended AI-generated booking path and can create a customer-provided booking directly.
- The trip-request screen only creates the TripRequest and navigates to itinerary; it does not call `AgentTriggerController` directly (`trip_request_screen.dart:236-251`). The backend’s automatic fire-and-forget trigger is therefore essential.
- `acceptItinerary()` attempts a customer status update but comments that backend forbids customer acceptance (`api_service.dart:453-460`).
- Request changes are explicitly unsupported and do not persist comments (`api_service.dart:462-470`).
- Flutter progress documentation still lists real map pins, real transport data, loaders, release signing, APK build, and final cross-platform checks as unfinished.

## 10. React Integration

### Real API wiring

`frontend-react/src/services/apiClient.js` maps staff operations to live API calls:

| React feature | Method | Backend route |
|---|---|---|
| Booking queue | `fetchBookings()` | `GET /api/Booking` |
| Agent logs | `fetchAgentLogs()` | `GET /api/TripRequest/{id}/logs` |
| Decision | `decideApproval()` | `POST /api/Approval` |
| Payments | `fetchPayments()` | `GET /api/Payment` |
| Revenue | `fetchRevenueSummary()` | `GET /api/Payment/revenue-report` |
| Itinerary review | `fetchItinerariesForReview()` | `GET /api/Itinerary/review` |
| Catalogue management | `fetchTours`, `fetchHotels`, `fetchTransport` | corresponding GET routes |

Axios attaches `localStorage.accessToken` (`apiClient.js` request interceptor). `/staff/*` is guarded by `RequireAuth`, which allows roles classified as staff/admin/agent/travelagent (`App.jsx:95-114`, `RequireAuth.jsx:5-18`).

### React risks

- Current installed dependency tree has no `react-responsive` (`npm ls react-responsive` returned empty), so the Vite build cannot resolve `src/lib/useResponsive.js`.
- `AuthContext` includes a comment describing offline/demo behavior, but current `login()` returns null if backend login fails; role inference is only used after a successful response.
- UI role guard is not security; ASP.NET role attributes are the actual approval control.
- Lint reports 36 errors and 6 warnings, including undefined `useCallback` in `src/lib/hooks.js`, unused symbols, and state updates inside effects.

## 11. API Contract Matrix

| Feature | Caller method | HTTP | URL | Backend method/service | Auth | Status |
|---|---|---:|---|---|---|---|
| Register | `ApiService.register` | POST | `/api/auth/register` | `AuthController.Register` | Anonymous | PASS |
| Login | `ApiService.login` | POST | `/api/auth/login` | `AuthController.Login` | Anonymous | PASS |
| Profile | `getProfile/updateProfile` | GET/PUT | `/api/customer/me` | `CustomerController` | Customer JWT | PASS |
| Preferences | `getPreferences/updatePreferences` | GET/PUT | `/api/preference` | `PreferenceController` | Customer JWT | PASS |
| Tours | `getTours/getTour` | GET | `/api/tour[/id]` | `TourController`/`TourService` | Public GET | PASS/PARTIAL |
| Trip request | `createTripRequest` | POST | `/api/triprequest` | `TripRequestController.Create` | Any authenticated user; customer existence required | PASS/PARTIAL |
| Manual AI trigger | No normal Flutter call | POST | `/api/AgentTrigger/trigger/{id}` | `AgentTriggerController.TriggerPipeline` | Authenticated, owner/staff | UNUSED by Flutter |
| Automatic AI trigger | ASP.NET background task | POST | FastAPI `/run-pipeline-async` | `main.py.run_pipeline_async` | No service auth | PARTIAL |
| Itinerary list | `getMyItineraries` | GET | `/api/itinerary/customer/{userId}` | `ItineraryController.GetByCustomer` | Owner/staff | PASS |
| Itinerary create | `createItinerary`/agent | POST | `/api/itinerary` | `ItineraryController.Create` | Owner/staff | PASS/PARTIAL |
| Add itinerary item | `addItineraryItem`/agent | POST | `/api/itinerary/{id}/items` | `ItineraryController.AddItem` | Owner/staff | PASS |
| Request changes | `requestItineraryChanges` | — | None | No backend continuation | — | FAIL |
| Hotel/transport | `getHotels/getTransportOptions` and Python tools | GET | `/api/hotel`, `/api/transport` | controllers/services | Public GET | PARTIAL |
| Booking create | `createBooking`/validation/Flutter fallback | POST | `/api/booking` | `BookingController.CreateBooking` | Any authenticated user | PARTIAL/SECURITY RISK |
| Booking read | `getBooking/getMyBookings` | GET | `/api/booking/{id}`, `/api/booking/my` | `BookingController` | Owner/staff | PASS |
| Approval | React `decideApproval` | POST | `/api/Approval` | `ApprovalController.SubmitApproval` → `ApprovalService` | TravelAgent/Admin | PASS |
| Payment | `createPayment`/validation tool | POST | `/api/payment` | `PaymentController.ProcessPayment` → `PaymentService` | Any authenticated user; booking ownership not checked | PARTIAL/SECURITY RISK |
| Agent logs | React/Flutter/Python | GET/POST | `/api/TripRequest/{id}/logs`, `/api/triprequest/agent-log` | `TripRequestController` | GET owner/staff; POST anonymous | PARTIAL/SECURITY RISK |
| Agent update | Python `sync_result_to_backend` | PATCH | `/api/triprequest/{id}/agent-update` | `TripRequestController.AgentUpdate` | Anonymous | CRITICAL SECURITY RISK |

## 12. Database Integrity

### Relationships and constraints

- Customer → Preference is intended one-to-one with unique `Preference.CustomerId` (`AppDbContext.cs:55-60`).
- Customer → TripRequest and TripRequest → AgentLog/Itinerary use foreign keys; TripRequest → Itinerary is cascade (`AppDbContext.cs:155-158`).
- Itinerary → ItineraryItem is cascade; ItineraryItem → Tour is restrict (`AppDbContext.cs:168-177`).
- Booking has a unique `BookingReference` index (`AppDbContext.cs:181-205`).
- Booking → BookingItem/Approval/Payment is cascade; inventory references use `SetNull` (`AppDbContext.cs:218-276`).
- There is no unique database constraint enforcing one Booking per Itinerary, despite the documented intended 1:1 relationship. `Booking.ItineraryId` is configured `.WithMany()` and has no unique index (`AppDbContext.cs:202-205`).
- There is no unique/partial constraint preventing multiple successful Payment rows for one Booking.
- BookingItem nullable FKs are not database-constrained to exactly one non-null reference; code checks this in `BookingService.cs:41-55`.
- `TravelAgent.HireDate` is `[NotMapped]` in EF mapping (`AppDbContext.cs:279-285`), so the documented persisted field is not actually in the database.

### Transactions/concurrency

`BookingService.CreateBookingAsync()` opens a RepeatableRead transaction and uses PostgreSQL `FOR UPDATE` for rooms and transport (`BookingService.cs:77-186`). It recounts active Draft/AwaitingApproval/Confirmed bookings before insert. This is a credible production concurrency design.

However, current tests do not prove it: two concurrency tests fail during WebApplicationFactory startup because the app attempts to write Windows Event Log without permission, and booking fixture tests fail on SQLite FK setup. SQLite behavior is not equivalent to PostgreSQL row locking.

## 13. Test / Build Results

Commands executed without source changes:

| Command | Result | Classification |
|---|---|---|
| `dotnet build backend\backend.csproj --no-restore -v:minimal` | Passed; 0 warnings, 0 errors | PASS |
| `dotnet test backend.Tests\backend.Tests.csproj --no-restore --verbosity minimal` | Failed; 8 failed, 29 passed, 37 total | Product/test-environment mixed |
| `npm.cmd run build` | Failed; unresolved `react-responsive`; unresolved runtime `/images/tea-plantation.jpg` warning; large chunk warning | Dependency/configuration failure |
| `npm.cmd run lint` | Failed; 36 errors, 6 warnings | Product code quality failure |
| `npm.cmd ls react-responsive --depth=0` | Empty dependency result | Installed dependency tree inconsistent with `package.json` |
| `flutter analyze` | Timed out after 60 seconds | UNVERIFIED/environment/tooling |
| `python -m pytest -q` in `agentic-ai` | Could not start; `python` not recognized | UNVERIFIED/environment |

### Backend failure classification

- **2 concurrency tests:** environment/configuration problem first: the test host fails when `Program.cs:228` logs a warning through Windows Event Log (`Cannot open log for source '.NET Runtime'. Access is denied`). The underlying concurrency behavior remains unverified.
- **6 BookingService tests:** test fixture/product integration issue: `BookingServiceTests.SeedDependenciesAsync()` fails with SQLite foreign-key constraint violation before the intended booking assertion. The service logic is not proven by those tests.

## 14. Security Findings

| Severity | Finding | Evidence | Impact |
|---|---|---|---|
| **CRITICAL** | Anonymous agent-update endpoint can change TripRequest status/PlanJson and trigger itinerary/booking creation | `TripRequestController.cs:230-363`, `[AllowAnonymous]` | Unauthenticated caller can inject plan data and initiate commercial records |
| **HIGH** | Anonymous agent-log endpoint allows audit-log spoofing | `TripRequestController.cs:214-224` | Audit trail cannot be trusted; arbitrary TripRequest IDs/log contents can be written |
| **HIGH** | Any authenticated caller can create a booking using arbitrary CustomerId | `BookingController.cs:29-55` | Customer A can create records for Customer B; booking ownership is not enforced at creation |
| **HIGH** | Payment creation does not enforce current user owns booking | `PaymentController.cs:28-50`, `PaymentService.cs:26-64` | Customer A can attempt payment on any Confirmed booking ID; server uses caller-supplied booking ID |
| **HIGH** | Python validation has synthetic booking success fallback | `validation_agent.py:250-261`, `validation_tools.py:65-76` | System can claim AwaitingApproval without a persisted Booking |
| **HIGH** | Graph silently substitutes pass-through nodes on import/runtime import failure | `graph.py:14-45` | Broken agent deployment can look like a successful pipeline |
| **MEDIUM** | CORS policy is `AllowAny` | `backend/Program.cs:199-207,264-265` | Cross-origin callers are unrestricted; unsuitable for production |
| **MEDIUM** | Staff registration is anonymous and allows self-selected Admin with shared secret | `AuthController.cs:115-174` | Admin privilege provisioning is not controlled by an existing admin workflow |
| **MEDIUM** | Placeholder JWT/staff configuration is present in appsettings and fallback DB password is empty | `backend/appsettings.json`, `Program.cs:70-87,103-123` | Deployment fails or uses unsafe/default configuration if secrets are not supplied |
| **MEDIUM** | Payment uses no idempotency key and permits duplicate Payment rows | `PaymentService.cs:43-64` | Retries can produce duplicate paid records/charges in a real provider integration |
| **LOW** | Demo fallback IDs and ticket data remain in Flutter | `checkout_payment_screen.dart:48-64`, `trip_confirmation_screen.dart:14-25` | Misleading demo state and possible false ticket display |

Positive controls verified:

- JWT issuer/audience/signature/lifetime validation configured in `Program.cs:103-124`.
- Customer ownership enforced for customer profile, trip requests, itineraries, bookings, payments reads, and notifications in the inspected controllers/services.
- Approval routes require `TravelAgent` or `Admin`.
- Payment server guard requires Confirmed status.
- Uploaded tour media has dedicated controller and magic-byte logic documented in Student B, but full path-traversal/runtime verification was not executed; mark upload hardening UNVERIFIED.

## 15. Documentation Contradictions

| Claim | Document | Actual code/evidence | Verdict/correction |
|---|---|---|---|
| Student A 100% complete | `STUDENT_A.md:34-41,84` | Automatic AI/persistence/approval/payment chain is not end-to-end proven; agent-update/log are anonymous | Overstated; change to component implemented, integration pending |
| Student B full agent work substantially complete | `STUDENT_B.md:111-135,480` | Same document admits itinerary persistence/full four-agent verification was pending; current code has dual persistence paths | Contradictory; retain pending integration status |
| AgentLog contains StepType/ToolName/DurationMs persisted | Master plan §4.6 and `SYSTEM_AUDIT.md` | `AgentLog.cs:28-35` marks these `[NotMapped]`; SQL schema has only StepName/Input/Output/Status | False for database persistence; document actual schema |
| Stripe Sandbox integration | Master plan §14; PaymentController comments | `PaymentService.cs:43-64` generates local `ch_sb_` reference and checks token string; no Stripe API/SDK call | Simulation, not Stripe integration |
| Flutter checkout is real | `FLUTTER_IMPLEMENTATION.md`, `flutter_progress_and_todo.md` | Hardcoded confirmed fallback and local approval helper remain | Partial/demo mode, not fully real |
| Request changes feeds agent workflow | Master plan screen description | `ApiService.requestItineraryChanges()` throws; no revision endpoint | UI-supported but workflow-incomplete |
| Customer submission triggers agent workflow in Flutter | Master plan §5 | Flutter only posts TripRequest; ASP.NET background task triggers agent | Diagram/document should show server-side asynchronous trigger |
| All endpoints are JWT protected | Master plan §9 note | `agent-log` and `agent-update` are anonymous | Incorrect and security-critical |
| Full cross-platform workflow verified | Master plan §3/§10/§12; Student A/Flutter docs | No current runtime evidence; backend tests/frontend build fail | Unverified, should not be claimed |
| Availability service was fully transaction-safe | `SYSTEM_AUDIT.md` | `AvailabilityService` reads availability; transactional locking is in `BookingService`, not availability query itself | Clarify read check versus atomic booking reservation |
| Booking/Itinerary one-to-one | Master plan schema | EF mapping uses `.WithMany()` and no unique ItineraryId index | Model does not enforce documented 1:1 |

## 16. Critical Blockers

1. **Anonymous `agent-update` can create/alter commercial workflow data.** It must be authenticated server-to-server or otherwise strongly signed and must validate allowed state transitions.
2. **Automatic AI completion is asynchronous and not durable.** A 201 response does not prove AI started or that PlanJson/Itinerary/Booking persisted. There is no job status/error propagation to Flutter.
3. **Synthetic booking fallback violates real persistence.** Validation must fail closed when booking creation fails; it must never return a fake ID/reference as success.
4. **Revision path has no continuation.** `RevisionRequested` leaves the same booking waiting, but no revised proposal can be generated or submitted.
5. **Flutter contains direct fallback booking creation and local approval simulation.** These can make a demo appear to follow the flow while bypassing AI/human approval.
6. **Payment is not Stripe.** The project requirement says Stripe Sandbox, but current code only simulates success/failure and generates a local reference.
7. **Current verification is not green.** Backend test failures, React build failure, React lint failure, and unverified Flutter/Python execution prevent release/demo confidence.

## 17. High Priority Issues

- Enforce booking creation ownership and restrict creation to the AI/backend orchestration path or staff role.
- Enforce payment booking ownership and one successful payment per booking.
- Add a unique Booking.ItineraryId constraint if 1:1 is intended.
- Make agent persistence one path only: create itinerary/items and booking transactionally, return real IDs, then update TripRequest status.
- Persist structured AgentLog fields or correct the documentation to the actual schema.
- Replace pass-through graph fallbacks with startup failure/explicit failed node.
- Make failed background AI runs update TripRequest to Failed with a visible FailureReason.
- Align Flutter DTO parsing with actual backend response envelopes, especially paginated `/triprequest/my` and `/booking` responses.
- Resolve React dependency lock/install mismatch and lint failures.
- Run agent tests in an isolated Python environment without live paid AI calls.

## 18. Medium / Low Issues

- Restrict CORS and enable HTTPS for deployed environments.
- Remove or protect `/seed-db` and other operational endpoints.
- Replace hardcoded Flutter fallback content and customer-visible support/demo text.
- Decide whether QR is allowed after Confirmed or only after Paid; implement one rule consistently.
- Add explicit notification creation for approval, rejection, revision, payment success, and payment failure. Current persisted notifications are real DB rows, but external delivery is not implemented/proven.
- Add ADRs/API documentation/workflow diagrams; current `docs/` inventory is empty.
- Build and sign APK; replace `com.example` application identity.
- Verify uploaded media path traversal/content limits and external map/image request policy.

## 19. Flow Diagram Corrections

### A. Code SHOULD CHANGE TO MATCH FLOW

1. Remove Flutter hardcoded booking/confirmation defaults and local “Agent approved” helper.
2. Remove direct Flutter fallback `POST /booking` from `MyItineraryScreen`; only use the AI-created persisted booking.
3. Make validation fail closed on backend booking errors; do not synthesize booking IDs/references.
4. Secure `agent-update` and `agent-log`; do not leave them anonymous.
5. Implement a real revision route: create revised TripRequest/version or reopen a controlled planning run with the approval comment.
6. Use a real Stripe test integration or change the project flow/documentation to explicitly call it a payment simulation.
7. Enforce payment ownership/idempotency and persist a consistent paid/failed commercial state.
8. Make AI workflow persistence transactional and make background failure visible to the customer.

### B. FLOW DIAGRAM SHOULD CHANGE TO MATCH CODE

1. Change `TripRequest → AI` to `TripRequest persisted → ASP.NET background dispatch → FastAPI`; the Flutter screen does not call Python or wait synchronously.
2. Show `AgentUpdate` as the current asynchronous persistence bridge, including its current risk, until it is replaced.
3. Show QR/confirmation as currently available after Confirmed, not strictly after Paid, unless code is changed.
4. Show revision as “decision recorded; no continuation currently” rather than a complete revised-planning loop.

### C. DESIGN DECISION REQUIRED

1. Decide whether itinerary is automatically AI-created or customer-created/edited before booking. Current code supports both.
2. Decide whether Booking is strictly one per Itinerary. Current documentation says yes; EF does not enforce it.
3. Decide whether transport inventory is date-specific. The master document says one row per dated departure, but the availability tool checks only transport ID.
4. Decide whether “payment success” means external Stripe confirmation or local sandbox simulation.
5. Decide whether customer acceptance of an itinerary is required in addition to travel-agent approval. Flutter attempts customer acceptance while backend forbids it.

## 20. Exact Fix Order

1. **Stabilize and secure the backend boundary first:** protect agent-update/log, enforce ownership for booking/payment, and remove unsafe operational exposure.
2. **Choose one persistence owner:** preferably Python validates/proposes, ASP.NET transactionally persists itinerary/items/booking, and returns real IDs; remove synthetic fallback.
3. **Fix TripRequest workflow durability:** create a job/status mechanism, persist Failed/FailureReason on every trigger failure, and make retry state authoritative in the database.
4. **Implement revision semantics:** define new proposal/version behavior, comment persistence, and the route back through the agents.
5. **Fix booking commercial integrity:** unique itinerary relationship if intended, item constraints, availability reservation semantics, payment idempotency and ownership.
6. **Replace payment simulation or rename it explicitly:** integrate Stripe test API/server SDK with secret management, or document the deliberate simulation as a reduced scope.
7. **Remove Flutter demo/bypass behavior:** no default confirmed booking, no local approval, no direct fallback booking creation; make loading/error states reflect server state.
8. **Repair React installation and lint:** synchronize lockfile/node_modules, fix dependency resolution, then fix lint errors.
9. **Repair backend test harness:** disable Event Log provider under tests and correct SQLite fixture FK graph; add PostgreSQL-backed integration tests for locking and enum/decimal behavior.
10. **Run isolated Python and Flutter verification:** all golden/security/flow tests, `flutter analyze`, `flutter test`, and debug APK build.
11. **Execute the complete acceptance scenarios:** happy path, over-budget retry, rejection, revision, payment failure, unauthorized approval, IDOR, and capacity.
12. **Update documentation only after evidence exists:** status reports, diagrams, API contracts, ADRs, and viva/demo script.

## 21. Final Acceptance Checklist

- [PASS] Shared ASP.NET API boundary exists for Flutter and React.
- [PASS] Customer registration/login/JWT issuance exists.
- [PASS] Flutter stores JWT in secure storage and attaches it to HTTP calls.
- [PASS] Customer profile/preference/trip-request ownership checks exist.
- [PARTIAL] TripRequest validation and persistence.
- [PARTIAL] Automatic AI dispatch; background and fallback behavior is unsafe/non-durable.
- [PASS] Four graph nodes are registered in normal imports.
- [HIGH RISK] Graph can silently substitute pass-through nodes.
- [PARTIAL] One-retry logic; database persistence and downstream effect are not fully proven.
- [PARTIAL] Itinerary persistence; duplicate/synthetic paths exist.
- [PARTIAL] Real room/transport availability; backend checks exist, date/route and runtime concurrency proof are incomplete.
- [PASS] Backend Booking creation defaults to AwaitingApproval.
- [PASS] Backend approval role guard and BookingApproval audit row exist.
- [FAIL] Revision continuation workflow.
- [PASS] Backend rejects payment before Confirmed.
- [FAIL] Real Stripe integration; current implementation simulates it.
- [PARTIAL] Payment persistence; duplicate payment and ownership gaps remain.
- [PARTIAL] QR/PDF path; real reference support exists, but fallback/demo data and paid-state mismatch remain.
- [PARTIAL] React approval/dashboard API wiring.
- [FAIL] React production build in current environment.
- [FAIL] React lint.
- [UNVERIFIED] Flutter analyzer/tests/build.
- [UNVERIFIED] Python agent tests in this environment.
- [FAIL] Verified full cross-platform acceptance journey.

## 22. Viva / Demo Risk

| Risk | Likelihood | Impact | Exact mitigation |
|---|---|---|---|
| React app fails to start/build because `react-responsive` is missing | High | Demo staff dashboard unavailable | Recreate dependency tree from lockfile, verify build before demo, keep a tested local build artifact only as fallback |
| AI service unavailable or times out | High | Trip request remains Pending/Planning with no visible resolution | Start FastAPI first, add health check, seed a verified run, and make fallback explicit rather than silently claiming success |
| Anonymous agent-update creates malformed/duplicate records | Medium/High | Wrong booking/itinerary data or security incident | Secure endpoint and use one transactional persistence path before demo |
| Flutter opens demo Confirmed booking | High | Demonstration does not prove real flow | Remove fallback/helper, require real booking ID/status, test empty/error paths |
| Payment appears successful but is not Stripe | High | Viva examiner can identify simulation | Either complete test Stripe integration or openly present payment as deliberate simulation and adjust requirement claim |
| Backend test suite fails during setup | High | No credible QA evidence | Fix Event Log test provider and FK fixtures, then rerun all tests against PostgreSQL for critical scenarios |
| Revision button records no continuation | High | Examiner tests recovery path and finds dead end | Implement revision lifecycle or remove claim from demo/diagram |
| Python/Flutter tools unavailable on demo machine | Medium | AI/mobile evidence cannot be reproduced | Provide pinned environment/setup commands and verify from a clean machine before presentation |

## 23. Final Answer to the Main Question

**Does the current project actually work according to the intended customer flow?**

**PARTIALLY.**

Top three reasons:

1. The core backend approval gate is implemented correctly enough to block pre-approval payment, but the surrounding AI-to-persistence chain uses asynchronous anonymous update calls and synthetic fallbacks, so a real persisted end-to-end run is not proven.
2. The payment path is a local simulation rather than a Stripe sandbox integration, and Flutter still contains demo/default booking and local approval behavior that can bypass the intended user journey visually.
3. Current quality evidence is not release-ready: 8/37 backend tests fail, React build/lint fail, Flutter verification timed out, Python tests could not execute, and the revision workflow is incomplete.

