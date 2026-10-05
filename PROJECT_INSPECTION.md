# AI Travel Planning & Booking Management System — Current Project Inspection

**Inspection date:** 5 October 2026  
**Repository:** `AI-Travel-Planning-Booking-Management-System`

## 1. Executive summary

This is a multi-client travel planning and booking platform for Sri Lankan travel. A customer uses the Flutter application to register, save preferences, submit a trip request, browse tours, select accommodation and transport, pay after approval, and receive a QR/PDF ticket. Staff and travel agents use the React dashboard to manage the catalogue, review itineraries, approve bookings, inspect AI logs, and view payment/revenue data.

The shared ASP.NET Core API is the system boundary. It owns authentication, authorization, PostgreSQL/EF Core persistence, business rules, booking status transitions, availability checks, payment handling, notifications, and the handoff to the Python agent service. The Python service is designed as a LangGraph pipeline:

```text
Flutter customer request
        ↓
ASP.NET Core API / TripRequest
        ↓
Coordinator (A) → Itinerary (B) → Booking/availability (C) → Validation/approval gate (D)
        ↓                                      
Booking AwaitingApproval → human travel-agent decision in React
        ↓
Confirmed → Stripe sandbox payment → notification → Flutter QR/PDF confirmation
```

The repository contains substantial implementation across all four student components. It is not yet a clean, verified release: the backend build passes, but backend tests currently have 8 failures; the React build is blocked by a missing installed dependency; React lint fails; Flutter verification timed out; and the documented full cross-platform agent-to-approval workflow has not been proven from the current checkout.

## 2. Repository structure

| Area | Current contents | Purpose |
|---|---|---|
| `backend/` | ASP.NET Core 8 Web API, Identity, EF Core, PostgreSQL provider, controllers, services, DTOs, models, migrations | Shared API and business/data layer |
| `backend.Tests/` | 37 xUnit tests covering services, authorization/workflows, and concurrency | Backend verification |
| `frontend-react/` | React 19 + Vite staff/admin client | Staff catalogue, customer, approval, media, and revenue screens |
| `mobile_flutter/` | Flutter customer application for Android/iOS/desktop/web targets | Customer-facing travel and booking experience |
| `agentic-ai/` | FastAPI service, LangGraph graph, four agent modules, tools, logger, evaluation scripts | AI planning and booking proposal workflow |
| `docs/` | Present but currently no tracked files in the repository inventory | Intended architecture/API/ADR documentation area |
| Root Markdown files | Master specification, student reports, audit, Flutter implementation/progress documents | Project requirements, ownership, and status evidence |

The repository also contains local `backend/app.db`, generated frontend assets, platform scaffolding, migrations, and image assets. Dependency/build folders were excluded from the inspection inventory.

## 3. Technology and integration design

- **Backend:** ASP.NET Core 8, C#, Entity Framework Core 8, ASP.NET Identity, JWT bearer authentication, Swagger/OpenAPI.
- **Database:** PostgreSQL in the intended deployment configuration, with EF Core migrations. The repository also contains a local SQLite-style `app.db` artifact and SQLite-based test setup.
- **Customer client:** Flutter/Dart, secure token storage, HTTP API calls, QR generation, PDF ticket generation, interactive map support.
- **Staff client:** React/Vite, React Router, Axios, responsive layout support, local image assets, staff dashboard pages.
- **AI service:** Python/FastAPI, LangGraph, Gemini integration when configured, deterministic rule validation, HTTP tools into the ASP.NET API.
- **Payment:** Stripe sandbox/test-token flow represented in the backend and Flutter checkout; the design intentionally omits webhooks and idempotency keys.
- **Shared boundary:** React and Flutter are intended to communicate only with the ASP.NET API. The Python service communicates with the backend through HTTP and records agent activity as `AgentLog` rows.

## 4. Data model and business domain

The master documentation defines 17 business tables plus ASP.NET Identity tables. The current `AppDbContext` exposes the expected sets:

### Identity and Student A

- `Customer` — Identity-linked customer profile.
- `Preference` — one-to-one budget, activity, dietary, and accessibility preferences.
- `Notification` — channel, message type, delivery/read status, and timestamps.
- `TripRequest` — customer request, dates, traveller count, budget, workflow status, retry count, plan JSON, and failure reason.
- `AgentLog` — cross-cutting agent execution/audit trail.

### Student B

- `Destination` — destination metadata, image, coordinates.
- `Tour` — catalogue item, category, price, duration, status, image/coordinates.
- `Itinerary` — customer/trip-request day-by-day plan and total estimated cost.
- `ItineraryItem` — ordered tour selection with day and time boundaries and price snapshot.

### Student C

- `Hotel` — destination-linked accommodation vendor.
- `Room` — capacity, total inventory, room type, nightly price.
- `TransportOption` — dated transport option, provider, route, capacity, price, and status.

### Student D

- `Booking` — commercial record with unique human-readable `BookingReference`, status, customer, itinerary, total cost, and timestamps.
- `BookingItem` — tour/room/transport line item; code validates that the matching nullable FK is used.
- `BookingApproval` — permanent travel-agent decision record and comment.
- `Payment` — amount, status, Stripe reference, and payment date.
- `TravelAgent` — Identity-linked staff profile.

Important domain rules implemented or represented in code include unique booking references, itinerary time-overlap checks, active inventory filtering, room/transport availability calculation, booking status guards, approval before payment, customer ownership checks, and agent retry/failure state.

## 5. Student ownership and current implementation

### Student A — Profile, preferences, notifications, trip requests, Coordinator Agent

**Backend:** `CustomerController`, `PreferenceController`, `NotificationController`, `TripRequestController`, related DTOs/services, Identity-linked customer data, preference validation, trip-request lifecycle, notification read/resend operations, and agent-log access.

**React:** customer directory and notification audit-log pages. These include search/filter/pagination-style management views and staff actions such as notification resend.

**Flutter:** profile/preferences, trip-request planner, notifications, and trip history screens.

**AI:** `coordinator_agent.py` receives the request, calculates trip days, creates a structured planning state, coordinates downstream nodes, and implements the retry/reduced-budget decision. `graph.py` persists final status/plan data back through the backend update endpoint and removes access tokens from initial audit snapshots.

**Assessment:** the component is broadly implemented and documented as complete. Its real release readiness still depends on the full downstream pipeline, backend availability, and the unresolved frontend/mobile verification items.

### Student B — Tours, destinations, itineraries, Itinerary Agent

**Backend:** `DestinationController`, `TourController`, `ItineraryController`, corresponding services and DTOs. The code supports catalogue management, search/filtering, image upload handling, itinerary item management, dynamic total-cost recalculation, and conflict detection for overlapping itinerary items.

**React:** destination management, tour catalogue management, and itinerary review. The review view supports editing/removing items before release and status updates.

**Flutter:** tour search/browse, tour details, and day-by-day “My Itinerary” timeline.

**AI:** `itinerary_agent.py` searches active tours through `tools/search_tours.py`, builds a schedule, and applies deterministic checks for active IDs, budget, maximum daily tour count, and time overlaps. Golden cases and prompt-injection evaluation scripts are present.

**Important current limitation:** the Student B document explicitly records that the generated itinerary was returned in LangGraph state but was not yet persisted as backend `Itinerary` and `ItineraryItem` rows at the time of that evidence. It also states that full four-agent verification remained pending. The current `itinerary_tools.py` does contain persistence support, so this should be re-tested and reconciled before claiming end-to-end completion.

### Student C — Accommodation, transport, Booking Agent

**Backend:** `HotelController`, room endpoints within `HotelController`, `TransportController`, `HotelService`, `TransportService`, and `AvailabilityService`. The intended design treats room price as the source of truth, counts overlapping bookings, checks transport capacity, and uses transaction/locking logic for last-room/last-seat concurrency.

**React:** hotel/vendor management and transport fleet management pages with create/edit/delete/search-style operations.

**Flutter:** accommodation options, transport options, and interactive trip map. The Flutter progress document still flags real rating/distance data, real transport times, and real selected-item map pins as work to verify or improve.

**AI:** `booking_agent.py` searches hotels/rooms/transports, checks availability, prices a package, and rejects missing persisted itinerary IDs or invalid upstream itinerary data.

**Assessment:** backend implementation is substantial and the intended concurrency design is present, but the backend concurrency tests currently fail during test-host startup because of Windows Event Log permissions. The agent depends on a persisted itinerary ID, so itinerary persistence is a key cross-component contract.

### Student D — Booking, approval, payments, Validation Agent

**Backend:** `BookingController`, `ApprovalController`, `PaymentController`, `BookingService`, `ApprovalService`, `PaymentService`, booking/payment DTOs and models. The backend enforces the approval gate, records approval decisions, protects payment until the booking is confirmed, and exposes pending approvals and revenue-report endpoints.

**React:** booking approval dashboard with agent-log trail, approval/rejection/revision actions, payment listing, and revenue reporting.

**Flutter:** checkout/payment, booking status timeline, trip confirmation, QR ticket, and PDF ticket download.

**AI:** `validation_agent.py` is deliberately deterministic rather than LLM-driven. It validates numbers, currencies, dates, inventory references, budget, item shape, persisted itinerary data, and booking status. Its success path creates an `AwaitingApproval` booking and never approves or charges it.

**Assessment:** this component has the intended core business safeguards, but several backend unit tests fail while seeding SQLite test data due to foreign-key failures. Those failures must be corrected before the component can be called fully verified.

## 6. Client applications

### React staff dashboard

The route/page inventory shows a complete staff-oriented surface: login, customer directory, notification logs, destination management, tour catalog, itinerary review, hotel/vendor management, transport fleet, booking approval, payments/revenue, media library, and shared staff layout/auth components. The public-facing site also includes home, destinations, experiences, planner, about, and contact pages.

Current verification:

- Vite transformed 142 modules and produced most build assets.
- Production build **failed** because `react-responsive` could not be resolved from `src/lib/useResponsive.js`, despite being declared in `package.json`; the installed `node_modules` state is inconsistent with the manifest.
- `npm run lint` **failed with 36 errors and 6 warnings**. Main categories are unused imports/variables, missing `useCallback` in `src/lib/hooks.js`, React state updates inside effects, and hook dependency warnings.

### Flutter customer app

The route and file inventory covers onboarding/authentication, home, profile/preferences, trip request, notifications, trip history, tour search/details, itinerary, accommodation, transport, map, checkout, booking status, confirmation, QR, and PDF ticket functionality. Dependencies include secure storage, HTTP, QR generation, PDF-related support, Google fonts, and map packages.

The Flutter progress document reports that Phase 2 booking/payment work and 54 related tests were completed, but it still lists unverified work: catalogue filters/sorting, real option data, real map pins, loading/error states, external-request policy, release signing/application ID, APK build, and the final cross-platform workflow. `flutter analyze` timed out during this inspection, so the claimed 54 tests and analyzer state were not independently verified here.

## 7. AI subsystem status

The graph is structurally wired as:

```text
coordinator → itinerary → booking → validation → evaluator
                                      ↘ retry to coordinator or end
```

All four agent modules now exist in the checkout, and the booking/validation code is no longer merely an empty file. However, `graph.py` still contains fallback pass-through implementations for import failures, and the Student B evidence explicitly says the full four-agent, database-backed, human-approval run was not yet demonstrated. The critical acceptance test is not merely “the graph invokes”; it is:

1. Flutter submits a real `TripRequest`.
2. Coordinator and downstream agents produce a valid plan.
3. `Itinerary` and `ItineraryItem` rows exist with real IDs.
4. Booking Agent checks real inventory and creates a valid package.
5. Validation creates `Booking` in `AwaitingApproval`.
6. React staff approval changes it to `Confirmed`.
7. Payment succeeds only after confirmation.
8. Flutter displays the updated status and QR/PDF ticket.

## 8. Verification results from this inspection

| Check | Result | Evidence/current issue |
|---|---|---|
| `dotnet build backend/backend.csproj --no-restore` | **Passed** | 0 warnings, 0 errors |
| `dotnet test backend.Tests/backend.Tests.csproj --no-restore` | **Failed: 8/37** | 2 concurrency tests fail because the test host cannot write Windows Event Log; 6 booking tests fail during SQLite FK seeding |
| `npm run build` | **Failed** | `react-responsive` cannot be resolved from installed dependencies; also reports unresolved `/images/tea-plantation.jpg` runtime asset and a large chunk warning |
| `npm run lint` | **Failed** | 36 errors, 6 warnings |
| `flutter analyze` | **Unverified** | Command timed out after 60 seconds |
| Python agent tests | **Unverified** | Python executable is not available on the current PATH |
| Git worktree | **Clean** | No uncommitted changes at inspection start |

## 9. Main risks and inconsistencies

1. **Documentation overstates readiness.** Student A and the Flutter implementation document say 100% complete, while Student B and the Flutter TODO retain explicit integration gaps. Use executable evidence and the end-to-end acceptance flow as the authoritative status.
2. **Backend test environment is unstable.** Tests use SQLite while production targets PostgreSQL; seed relationships and logging configuration produce failures that obscure actual booking-rule verification.
3. **React dependencies are not reproducible from the current checkout.** `react-responsive` is declared but unavailable to Vite. The lockfile and installed modules should be synchronized in a clean install.
4. **CORS is currently `AllowAnyOrigin`,** even though the audit history says it was previously restricted. This is acceptable for local development but not production security.
5. **The backend uses placeholder configuration values** in `appsettings.json` and falls back to a local PostgreSQL connection with an empty password. Environment/user secrets must be supplied for a real run.
6. **Flutter still has release/deployment TODOs** and relies on environment-defined API and Stripe publishable-key values.
7. **External-service boundaries need documentation.** The Flutter TODO calls out image/map tile requests that may conflict with the assignment’s “shared ASP.NET API” boundary.
8. **The `docs/` area is not populated in the current inventory,** despite the master document expecting ADRs, diagrams, API docs, CI, and deployment documentation.

## 10. Recommended current priority order

1. Make the test harness deterministic: disable Windows Event Log provider in tests and correct the booking-test fixture FK seed graph.
2. Reconcile and verify itinerary persistence, then run the complete four-agent workflow against PostgreSQL with real seeded IDs.
3. Run a clean frontend dependency installation from `package-lock.json`; fix the missing `react-responsive` resolution and the React lint errors.
4. Run Flutter dependency resolution, analyzer, all tests, and an Android APK build; record actual results rather than relying on the progress document.
5. Execute the cross-platform acceptance test from Flutter → AI → React approval → payment → QR/PDF confirmation.
6. Restrict CORS, move all secrets to environment/user-secrets, confirm HTTPS for deployment, and protect or remove operational endpoints such as `/seed-db`.
7. Add the missing ADR/API/diagram/CI/deployment documentation and update all student status documents to match verified reality.

## 11. Overall current assessment

**Overall status: feature-rich implementation in integration-hardening stage.**

The project has the intended architecture, all four student domains are represented in backend, React, Flutter, and AI code, and the core travel/approval concept is credible. The strongest completed areas are the backend domain model, API/service decomposition, booking approval rules, deterministic validation approach, and breadth of client screens. The main remaining work is verification and integration reliability: fixing the failing backend tests, restoring a reproducible React build/lint state, independently verifying Flutter, and proving the real four-agent workflow with persisted itinerary/booking data and human approval.

