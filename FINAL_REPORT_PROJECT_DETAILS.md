# Final Report Project Details

Evidence basis: this file describes the repository implementation present at the time of inspection. Primary evidence was taken from `backend/`, `agentic-ai/`, `frontend-react/`, `mobile_flutter/`, `backend.Tests/`, AI tests, configuration files, migrations and SQL schema files. Historical audit documents were not used as implementation evidence.

## 1. Project Identification

- **Title:** AI Travel Planning & Booking Management System.
- **Type:** Full-stack travel-planning, inventory, approval and booking system with an agentic AI planning subsystem.
- **Context:** The repository contains a SE3090-style university software-engineering project, but no authoritative student-registration list is stored in the current implementation.
- **Team structure:** Four student-owned business components are represented in the code and supporting project documentation: Student A (customer/trip request/coordinator), Student B (destination/tour/itinerary), Student C (hotel/room/transport), and Student D (booking/approval/payment).
- **Main stack:** ASP.NET Core 8 Web API, C#, Entity Framework Core 8, PostgreSQL/Npgsql, ASP.NET Core Identity, JWT bearer authentication, React 19 with Vite, Flutter/Dart, Python 3 service using FastAPI and LangGraph, HTTP/JSON APIs, and automated tests.
- **Client applications:** React dashboard/site for travel agents and administrators; Flutter customer application for Android and other Flutter targets.
- **Backend:** Layered ASP.NET Core Web API with controllers, DTOs, services, EF Core data access, Identity/JWT security, Swagger/OpenAPI and static media serving.
- **Database:** PostgreSQL is the configured production-style database. EF migrations and generated SQL are present. `backend/app.db` is also present as a local artifact, while runtime configuration selects PostgreSQL.
- **AI subsystem:** Four-agent LangGraph pipeline exposed through FastAPI. Gemini is used when configured; deterministic fallbacks and validation rules are implemented in Python.
- **Third-party services:** Google Gemini configuration is supported; the payment service implements a Stripe-sandbox-shaped payment flow and stores a Stripe reference. Supabase configuration/storage health endpoints and map tiles through Flutter map packages are present.
- **Repository summary:** `backend/` API and database; `backend.Tests/` C# tests; `agentic-ai/` Python service, graph, agents, tools and evaluation tests; `frontend-react/` React/Vite application; `mobile_flutter/` Flutter application and widget tests; `docs/` and root Markdown files for supporting project material.

## 2. Executive Project Overview

The system addresses the coordination problem of planning and booking a multi-part trip. A customer can create an account, manage a profile and travel preferences, browse destinations and tours, submit a request containing dates, traveller count, destination, notes and a budget, follow the request status, review a generated itinerary/package, wait for staff approval, pay after confirmation, and access confirmation/ticket information. Staff members maintain catalogues and inventory, inspect customer requests and AI activity, review proposed itineraries/bookings, approve or reject them, request revisions, inspect payment data and view revenue information.

The workflow combines a human-facing customer experience with staff operational controls. Flutter is suited to the customer journey and device features such as secure token storage, QR generation, PDF ticket creation and map display. React provides a desktop-oriented staff workspace for catalogue, inventory, customer, approval, notification and reporting operations. ASP.NET Core is the central business boundary: it authenticates users, authorizes actions, owns the PostgreSQL model, checks ownership, revalidates AI proposals, persists commercial records and exposes the REST contract. Python/FastAPI runs the planning graph and calls backend search/availability endpoints. The AI proposes; it does not independently approve or create trusted commercial records.

The primary value is an integrated path from natural-language trip intent to a database-backed, reviewable and payable travel package. Real catalogue IDs, active statuses, capacity, availability, dates, currencies and prices are checked before the proposal is persisted. A travel agent remains in the loop before confirmation and payment.

## 3. Project Scope

### In scope

- Customer registration, login, profile, preferences, notifications, destination/tour browsing, trip requests, itinerary viewing, trip history, booking status, payment and ticket/QR/PDF presentation.
- Travel-agent/admin login and dashboard functions: customer directory, destination and tour management, hotel/room management, transport management, itinerary review, booking approval, notification log access, media management, payment listing and revenue reporting.
- Trip planning using destination, dates, traveller count, activities, notes and budget.
- Accommodation and transport catalogue/availability searches.
- Human approval, rejection and revision-request workflow.
- Payment persistence and confirmation-state guard.
- PostgreSQL relational persistence, EF Core migrations, Identity tables and domain entities.
- REST APIs, Swagger, validation, role authorization, ownership checks and internal agent callback authentication.
- Four-agent LangGraph workflow, deterministic package validation, retry behavior and AgentLog persistence.
- Automated C# service/integration/security tests, Flutter widget/workflow tests and Python AI evaluation tests.
- Deployment-related assets such as `backend/Dockerfile`, environment-variable configuration, Vite, Flutter Android/iOS/desktop targets and FastAPI/uvicorn startup.

### Client and service boundaries

| Area | Responsibility |
|---|---|
| Flutter | Customer UI, navigation, secure JWT storage, API calls, trip/booking screens, map, QR and PDF ticket presentation. |
| React | Staff/travel-agent/admin UI plus public/catalogue pages; calls the ASP.NET API through `src/services/apiClient.js`. |
| ASP.NET Core | Authentication, authorization, DTO validation, domain services, trusted pricing and availability checks, approval/payment rules, persistence and reporting. |
| Python AI | Structured planning proposal, itinerary generation, database-backed inventory selection, validation, retry decision and callback/log submission. |
| PostgreSQL | Identity, customer, catalogue, workflow, booking, approval, payment and audit persistence. |
| External services | Gemini/LLM calls when keys are configured; Stripe-style sandbox payment record behavior; optional Supabase storage/health integration. |

## 4. Functional Requirements

### Authentication

- **FR-01:** A new customer can register through `POST /api/auth/register`.
- **FR-02:** A staff user can register through the staff registration route using the configured staff secret code.
- **FR-03:** Registered users can authenticate through `POST /api/auth/login` and receive a JWT.
- **FR-04:** The API validates JWT issuer, audience, lifetime and signing key.

### Customer profile and preferences

- **FR-05:** A customer can retrieve and update their own profile.
- **FR-06:** A customer can create or update one preference record containing budget range, currency, activities, dietary notes and accessibility notes.
- **FR-07:** Staff can list/search customer records with paging, sorting and search parameters.

### Trip request

- **FR-08:** An authenticated customer can submit a trip request with destination, raw request text, dates, traveller count, budget and currency.
- **FR-09:** The system persists the request and exposes customer history, detail and status views.
- **FR-10:** A customer can cancel an eligible request and view AgentLog entries for it.
- **FR-11:** Staff can search trip requests by customer, destination, status, sorting and page.
- **FR-12:** A planning trigger can invoke the AI pipeline for a request.

### Catalogue and itinerary

- **FR-13:** Users can browse destinations and tours; staff can create, update and soft-delete them.
- **FR-14:** The itinerary service creates itineraries, adds/removes tour items, returns customer itineraries and supports status changes.
- **FR-15:** Itinerary items store day number, sequence, start/end time and selection price.
- **FR-16:** The server validates active tours, destination consistency, times, overlaps, currency and trusted totals.

### Accommodation and transport

- **FR-17:** Users can search active hotels, rooms and transport options.
- **FR-18:** Staff can maintain hotels, rooms and transport options.
- **FR-19:** The system checks room dates/capacity/room count and transport capacity before proposal persistence.
- **FR-20:** Inactive hotels and transport options are retained but excluded from normal availability searches.

### AI planning

- **FR-21:** The FastAPI service accepts a structured trip-planning request synchronously or asynchronously.
- **FR-22:** LangGraph routes a request through coordinator, itinerary, booking and validation nodes.
- **FR-23:** The AI may use Gemini, but deterministic fallbacks and validation rules produce safe structured outcomes.
- **FR-24:** The pipeline logs agent steps and sends its final proposal/status to ASP.NET.
- **FR-25:** A failed budget validation can cause one economy retry; a second failure ends planning as failed.

### Booking, approval and revision

- **FR-26:** The backend creates a booking package with a unique booking reference, itinerary link, itemized tour/room/transport records, total and currency.
- **FR-27:** A newly persisted AI proposal starts at `AwaitingApproval`.
- **FR-28:** TravelAgent/Admin users can approve, reject or request revision and can inspect approval history.
- **FR-29:** Approval changes the booking to `Confirmed`; rejection changes it to `Rejected`; revision records feedback, preserves the old audit trail, discards the old itinerary and triggers new planning.
- **FR-30:** Customers can view only their own bookings and payment records.

### Payment and ticket

- **FR-31:** Payment is accepted only for a persisted `Confirmed` booking.
- **FR-32:** Payment records contain amount, currency, status, date and sandbox reference.
- **FR-33:** Customers can view booking/payment status; staff can list payments and view revenue/monthly revenue data.
- **FR-34:** Flutter provides confirmation, QR and PDF-ticket functionality through `trip_confirmation_screen.dart` and `ticket_pdf_service.dart`.

### Notifications, staff and reporting

- **FR-35:** Customers can list notifications, mark them read/unread, mark all read and request resend of failed records.
- **FR-36:** Staff can send notifications and inspect notification logs.
- **FR-37:** Staff can manage media uploads/listing/deletion where configured and inspect AI activity through trip logs.
- **FR-38:** Staff can inspect payments and revenue report data.

## 5. Non-Functional Requirements

- **Security:** Identity password hashing, JWT validation, role attributes, customer ownership checks, service-key callbacks and server-side status/pricing rules are implemented in `Program.cs`, controllers, services and `Security/AgentServiceAuthentication.cs`.
- **Usability:** Flutter separates customer tasks into focused screens; React uses a staff layout, navigation, loading/error/empty-state components and responsive helpers.
- **Responsiveness/cross-platform:** React uses Vite and responsive utilities; Flutter has Android, iOS, Windows, macOS, Linux and web platform scaffolding.
- **Maintainability:** Controllers delegate to named interfaces/services; DTOs separate transport contracts from entities; EF migrations capture schema evolution.
- **Modularity:** Four business ownership areas, separate Python agents/tools, and client/service boundaries are visible in the repository.
- **Data consistency:** PostgreSQL foreign keys, unique indexes, enum/status fields, server recalculation and serializable transactions protect core workflows.
- **Reliability:** Agent calls have timeouts and clean failure responses; FastAPI supports synchronous and background execution; ASP.NET has global exception handling and health endpoints.
- **Auditability:** `AgentLog`, `BookingApproval`, payment records, timestamps and stored `TripRequest.PlanJson` preserve workflow evidence.
- **Scalability considerations:** APIs are stateless at the HTTP layer, EF Core queries support paging, and the AI pipeline is exposed as a separate service with an async trigger.
- **Testability:** Dependency injection, service interfaces, `InternalsVisibleTo`, C# test projects, Python tests and Flutter widget tests support isolated verification.
- **Portability:** REST/JSON and JWT allow multiple clients; Flutter and React target different platforms; PostgreSQL is accessed through Npgsql/EF Core.

## 6. User Roles and Permissions

| Feature | Customer | TravelAgent | Admin |
|---|---|---|---|
| Register/login/profile/preferences | Own records | Own account | Own account |
| Browse public destinations/tours/hotels/transport | Yes | Yes | Yes |
| Create/view/cancel own trip requests | Yes | Staff search/review | Staff search/review |
| View own bookings/payments | Own records | All operational records | All operational records |
| Catalogue/inventory management | No | Yes | Yes |
| Customer directory | No | Yes | Yes |
| Approvals/revisions | No | Yes | Yes |
| Revenue/payment reporting | No | Yes | Yes |
| Delete customer/booking | No | Booking only | Customer and booking |
| Send notifications/media management | No | Yes | Yes |

Roles are enforced by ASP.NET `[Authorize(Roles = "TravelAgent,Admin")]` and `[Authorize(Roles = "Admin")]` attributes. Customer ownership is checked in controllers/services rather than relying on hidden UI controls.

## 7. Major Components and Student Ownership

### Student A — Customer and planning coordination

Responsibilities include `Customer`, `Preference`, `Notification`, `TripRequest`, `AgentLog`, profile/preferences/notification/trip-request APIs, and the coordinator agent. Main evidence: `backend/Services/CustomerService.cs`, `PreferenceService.cs`, `NotificationService.cs`, `TripRequestService.cs`, `backend/Controllers/CustomerController.cs`, `PreferenceController.cs`, `NotificationController.cs`, `TripRequestController.cs`, Flutter profile screens, and `agentic-ai/agents/coordinator_agent.py`. It integrates with Student B’s itinerary, Student C’s inventory and Student D’s validation/persistence/approval through the graph and `TripRequest` state.

### Student B — Destinations, tours and itineraries

Responsibilities include `Destination`, `Tour`, `Itinerary`, `ItineraryItem`, tour search, schedule construction and itinerary review. Evidence: `DestinationService.cs`, `TourService.cs`, `ItineraryService.cs`, the corresponding controllers, `agentic-ai/agents/itinerary_agent.py`, `tools/search_tours.py`, React destination/tour/itinerary pages and Flutter tour/itinerary screens. It integrates by supplying real active tour IDs and schedule data to booking and validation.

### Student C — Accommodation, rooms, transport and availability

Responsibilities include `Hotel`, `Room`, `TransportOption`, active-status searches and availability/capacity checks. Evidence: `HotelService.cs`, `TransportService.cs`, `AvailabilityService.cs`, `HotelController.cs`, `TransportController.cs`, `agentic-ai/tools/availability_tools.py`, `booking_agent.py`, React hotel/vendor and transport pages, and Flutter accommodation/transport/map screens. The booking agent uses backend results rather than inventing inventory.

### Student D — Booking, approval and payment

Responsibilities include `Booking`, `BookingItem`, `BookingApproval`, `Payment`, `TravelAgent`, the validation/approval-gate agent, proposal persistence, human decisions, payment guard and reporting. Evidence: `BookingService.cs`, `ApprovalService.cs`, `PaymentService.cs`, `AgentProposalPersistenceService.cs`, controllers, `validation_agent.py`, Flutter checkout/confirmation screens and React approval/revenue pages.

## 8. Final End-to-End Customer Workflow

1. Flutter opens the landing/home experience and uses `AuthGuard`/navigation to protect customer operations.
2. The customer registers and logs in. ASP.NET Identity creates the user/customer record and login returns a JWT.
3. The customer browses destinations/tours, saves preferences and opens the trip request screen.
4. The request is submitted to `POST /api/triprequest`; `TripRequestService` persists it with `Pending` status.
5. `AgentTriggerController` sends the request to FastAPI, with the backend bearer token in the pipeline payload and an internal service key used for callbacks/logs.
6. Coordinator decomposes dates, notes and budget and allocates 35% tours, 45% hotels, 15% transport and 5% buffer. A retry applies a 15% economy adjustment.
7. Itinerary Agent searches real tours, generates a day-by-day schedule and applies active-ID, item-count, overlap and budget checks.
8. Booking Agent searches active hotels/rooms and transport, checks capacity and availability, normalizes supported USD/LKR values and selects real IDs.
9. Validation Agent checks structure, IDs, dates, currencies, totals and approval-gate rules. It produces an `AwaitingApproval` proposal, not a self-approved booking.
10. ASP.NET proposal persistence starts a serializable transaction, locks the trip request for PostgreSQL, rechecks catalogue/availability/prices and atomically creates itinerary, itinerary items, booking and booking items. The trip becomes `AwaitingApproval`.
11. A travel agent sees the pending queue in React, reviews the package and submits Approved, Rejected or RevisionRequested.
12. Approved changes booking to `Confirmed`. Rejected changes it to `Rejected`. Revision records feedback, marks the old booking cancelled/itinerary discarded and starts a new planning run while preserving approval history.
13. The customer can pay only after confirmation. Payment stores a paid/failed record and sandbox reference.
14. Flutter displays booking status and confirmation, with QR and PDF ticket generation support.

```text
Customer -> Flutter -> ASP.NET: register/login/preferences/trip request
ASP.NET -> PostgreSQL: TripRequest(Pending)
ASP.NET -> FastAPI: trigger pipeline
FastAPI: Coordinator -> Itinerary -> Booking/Availability -> Validation
FastAPI -> ASP.NET: secured proposal/status/log callbacks
ASP.NET -> PostgreSQL: revalidate + transactionally persist AwaitingApproval
TravelAgent -> React -> ASP.NET: approve | reject | request revision
ASP.NET -> PostgreSQL: Confirmed / Rejected / new Planning run
Customer -> Flutter -> ASP.NET: payment after Confirmed
ASP.NET -> PostgreSQL: Payment(Paid or Failed)
Flutter: confirmation + QR/PDF ticket
```

Payment failure creates a failed payment result; it does not bypass the confirmed-status gate. Planning failure is represented by `Failed` and a failure reason. Budget failure retries once, then terminates as failed.

## 9. System Architecture

```text
Flutter customer app ----JWT/JSON----> ASP.NET Core Web API <----JWT/JSON---- React staff dashboard
                                            |
                                            +---- EF Core/Npgsql ---- PostgreSQL
                                            |
                                            +<--- HTTP JSON ---> FastAPI/LangGraph AI service
                                            |                         |
                                            |                         +--> Gemini/LLM when configured
                                            +---- payment/storage integrations where configured
```

ASP.NET is the central boundary because all trusted state changes pass through its authorization, DTO validation, domain services, database constraints and workflow state rules. FastAPI is intentionally a planning service, not the system of record. React and Flutter consume the same API contract and do not directly access PostgreSQL.

## 10. Repository Architecture

- `backend/`: ASP.NET project. `Controllers/` exposes REST routes; `Services/` contains domain/application logic; `Models/` and `Models/Enums/` define entities and states; `DTOs/` define request/response contracts; `Data/` contains `AppDbContext` and seed initialization; `Security/` contains internal agent authentication; `Migrations/` and SQL files describe schema; `Program.cs` configures middleware, Identity, JWT, DI, Swagger, CORS and health routes.
- `backend.Tests/`: xUnit-style service, integration, authorization, concurrency, approval, proposal and agent-trigger tests.
- `agentic-ai/`: `main.py` FastAPI entry point; `graph.py` LangGraph state graph; `agents/` four nodes; `tools/` backend search, availability and validation helpers; `logger.py` AgentLog client; `test_*.py` deterministic/golden/integration/security cases.
- `frontend-react/`: Vite React app. `src/pages/site` public pages, `pages/customers`, `pages/tours`, `pages/hotels`, `pages/bookings`, `pages/media` staff features; `components/layout` includes staff/navigation; `services/apiClient.js` calls backend; `lib/auth.jsx` and `RequireAuth.jsx` protect routes.
- `mobile_flutter/`: Flutter customer app. `lib/screens` groups auth, profile, tours, accommodation and booking; `services/api_service.dart` handles HTTP; secure storage/auth guard handle tokens; `ticket_pdf_service.dart`, `trip_selection_service.dart` and map/QR packages implement device-facing features; `test/` contains widget/workflow tests.
- `docs/`, `Readme/`, root Markdown: supporting project and setup material; current code and configuration take priority.

## 11. Backend Design

The backend targets `net8.0`. It uses controller-service-DTO layering with constructor dependency injection. Controllers handle HTTP, claims and role checks; services query/update EF Core entities and map to DTOs. `AppDbContext` inherits `IdentityDbContext<IdentityUser>` and maps PostgreSQL entities, indexes, foreign keys and decimal/jsonb columns. `Program.cs` registers scoped interfaces for customer, preference, notification, trip, itinerary, booking, approval, revision, payment, hotel, transport and availability services.

Authentication uses ASP.NET Identity plus JWT bearer validation. Model-state failures are returned in a consistent `{ message, errors }` shape. A global exception handler logs unhandled exceptions and returns JSON. Swagger exposes OpenAPI and a Bearer security scheme. CORS is configured, static uploads are served, and `/dbhealth`, `/supabasehealth` and `/seed-db` support operational checks. `AgentProposalPersistenceService` and `ApprovalService` use serializable transactions; the proposal service also uses a PostgreSQL advisory transaction lock.

Important services are `TripRequestService` (request lifecycle and logs), `ItineraryService` (items/status), `AvailabilityService` (room/transport availability), `BookingService` (booking lifecycle and ownership), `AgentProposalPersistenceService` (trusted atomic AI proposal persistence), `ApprovalService` (human decision/audit), `RevisionPlanningService` (new run after feedback), `PaymentService` (confirmed-only payment and revenue report), and `NotificationService` (in-app notification state).

## 12. Database Design

PostgreSQL is accessed through EF Core/Npgsql. Identity supplies `AspNetUsers`, roles, claims, logins and tokens. Integer identity keys are used for most business entities; customer/travel-agent IDs are strings tied to Identity; notification/preference/agent-log identifiers include GUID identity generation. Money uses `decimal(18,2)` and trip plans use PostgreSQL `jsonb`.

| Entity | Purpose | Important fields | Relationships | Owner |
|---|---|---|---|---|
| Customer | Customer profile/role | Id, FullName, Phone, Role, timestamps | Preference, Notifications, TripRequests, Itineraries, Bookings | A |
| Preference | One customer preference record | BudgetMin/Max, Currency, activities, dietary/accessibility notes | 1:1 Customer | A |
| Notification | In-app/delivery record | Channel, MessageType, Content, Status, ReadAt, SentAt | Customer | A |
| TripRequest | Planning workflow aggregate | CustomerId, DestinationId, dates, travellers, budget, status, RetryCount, PlanJson, FailureReason | Customer, optional Destination, AgentLogs, Itinerary | A |
| AgentLog | Agent execution evidence | TripRequestId, AgentName, StepName, Input, Output, Status, Timestamp | TripRequest | A/shared |
| Destination | Geographic catalogue node | Name, Country, description, coordinates | Tours, Hotels, TripRequests | B |
| Tour | Activity inventory | DestinationId, name/category, price/currency, duration, start, status | Destination, ItineraryItems, BookingItems | B |
| Itinerary | Proposed/accepted schedule | CustomerId, TripRequestId, dates, status, estimated cost/currency | Customer, TripRequest, Items, Booking | B |
| ItineraryItem | Scheduled tour | ItineraryId, TourId, day, sequence, start/end, price | Itinerary, Tour | B |
| Hotel | Accommodation vendor | DestinationId, name, stars, coordinates, status | Destination, Rooms | C |
| Room | Room inventory | HotelId, type, capacity, total rooms, nightly price/currency | Hotel, BookingItems | C |
| TransportOption | Transport inventory | type, provider, route, departure/arrival, capacity, price, status | BookingItems | C |
| Booking | Commercial package | BookingReference, CustomerId, ItineraryId, Status, TotalCost, Currency | Customer, Itinerary, Items, Approvals, Payments | D |
| BookingItem | Itemized commercial lines | Type, Tour/Room/Transport FK, dates, quantity, unit price, subtotal | Booking and optional inventory entities | D |
| BookingApproval | Human decision audit | BookingId, TravelAgentId, Decision, Comment, DecidedAt | Booking, TravelAgent | D |
| TravelAgent | Staff approval profile | Id, FullName, Department | IdentityUser, approvals | D |
| Payment | Payment audit/result | BookingId, Amount, Currency, Status, StripeReference, date | Booking | D |

Unique constraints include one Preference per Customer and unique BookingReference. Foreign keys use cascading, restricted or set-null delete behavior according to the business relationship; the generated SQL in `backend/supabase_schema.sql` records the exact constraints and indexes.

## 13. Database Relationship Explanation

Customer has one Preference and many Notifications, TripRequests, Itineraries and Bookings. A TripRequest optionally points to a Destination and owns AgentLogs; it is the workflow root used to connect AI execution to the commercial proposal. A TripRequest produces an Itinerary, which contains ordered ItineraryItems. Each item references a Tour, and each Tour belongs to a Destination. A Destination also owns Hotels; each Hotel owns Rooms.

An Itinerary is linked to a Booking. A Booking contains BookingItems whose item type selects a Tour, Room or TransportOption. Room items carry check-in/check-out dates; transport items carry quantity/capacity implications. Booking owns BookingApproval history and Payment records. BookingApproval references both the Booking and the TravelAgent who made the decision. Identity supplies the user and role infrastructure behind Customer and TravelAgent identities.

## 14. API Design

The API base is `/api`; responses are JSON DTOs. Public catalogue GETs are marked anonymous even though controllers have a class-level authorization attribute.

| Controller / method | Route | Auth/role | Purpose and main data |
|---|---|---|---|
| Auth POST | `/api/auth/register`, `/register-staff`, `/login` | Anonymous | Create customer/staff account or return JWT. |
| Customer GET/PUT | `/api/customer/me` | Authenticated owner | Read/update own profile. |
| Customer GET/PUT/DELETE | `/api/customer/{id}` | Read auth; update TravelAgent/Admin; delete Admin | Customer detail and staff administration. |
| Customer GET | `/api/customer` | TravelAgent/Admin | Search/paginate customer directory. |
| Preference GET/PUT | `/api/preference` | Customer owner | Read/create/update own preferences. |
| Preference GET | `/api/preference/search` | TravelAgent/Admin | Search preference data. |
| Notification GET/PATCH/POST | `/api/notification`, `/my`, `/{id}/read`, `/{id}/unread`, `/mark-all-read`, `/{id}/resend`, `/send` | Auth; send TravelAgent/Admin | List, read-state, resend and staff send operations. |
| TripRequest POST/GET/PATCH | `/api/triprequest`, `/my`, `/{id}`, `/{id}/status`, `/{id}/cancel` | Authenticated customer/owner | Create, list, detail, status, cancel. |
| TripRequest logs/search | `/{id}/logs`, `/api/AgentLog/{id}`, `/search` | Customer owner or staff | Agent activity and staff search. |
| Agent callback | `/api/triprequest/agent-log`, `/api/AgentLog`, `/{id}/agent-update` | Internal service key for callback paths | Persist logs and final plan/status. |
| Agent trigger | `/api/agenttrigger/health`, `/trigger/{id}` | Health anonymous; trigger auth | Check AI service and run pipeline. |
| Destination GET/CRUD | `/api/destination`, `/{id}` | GET anonymous; writes TravelAgent/Admin | Browse/manage destinations. |
| Tour GET/CRUD | `/api/tour`, `/{id}` | GET anonymous; writes TravelAgent/Admin | Search/manage tours; create supports image form upload. |
| Itinerary | `/api/itinerary`, `/{id}`, `/customer/{customerId}`, `/review`, `/{id}/items`, `/{id}/items/{itemId}`, `/{id}/status` | Auth; review TravelAgent/Admin | Create/view/review/edit/status. |
| Hotel/room | `/api/hotel`, `/{id}`, `/rooms/search`, `/{hotelId}/rooms`, `/{hotelId}/rooms/{roomId}`, `/{hotelId}/rooms/{roomId}/availability` | GET anonymous; writes TravelAgent/Admin | Hotel, room and availability operations. |
| Transport | `/api/transport`, `/{id}`, `/{id}/availability` | GET anonymous; writes TravelAgent/Admin | Transport search/manage/availability. |
| Booking | `/api/booking`, `/my`, `/{id}`, `/{id}/status` PUT/PATCH, `/{id}` DELETE | Auth; status/delete TravelAgent/Admin | Create/view/status/delete bookings. |
| Approval | `/api/approval`, `/pending`, `/booking/{bookingId}` | TravelAgent/Admin | Human decisions, queue and audit history. |
| Payment | `/api/payment`, `/{id}`, `/booking/{bookingId}`, `/revenue-report` | Auth; all/revenue TravelAgent/Admin | Process, view and report payments. |
| Media | `/api/media/upload`, `/api/media`, `/api/media?url=...` | TravelAgent/Admin | Upload/list/delete catalogue media. |

The AI service exposes `GET /`, `GET /health`, `POST /run-pipeline` and `POST /run-pipeline-async` on its configured FastAPI port, defaulting to 8005 in `agentic-ai/main.py`.

## 15. Authentication and Authorization Design

Registration uses `UserManager<IdentityUser>` and creates the corresponding domain profile. Login validates Identity credentials and creates a signed JWT with configured issuer/audience/expiry. `Program.cs` requires a configured JWT key and validates issuer, audience, lifetime and signing key. Roles include Customer, TravelAgent and Admin; staff registration is protected by a configured staff secret code.

Flutter stores the JWT through `flutter_secure_storage` and adds it to API requests through `api_service.dart`; `AuthGuard` and navigation protect screens. React stores/uses authenticated session data through `src/lib/auth.jsx`, `RequireAuth.jsx` and `apiClient.js`. These client checks improve usability but server-side attributes and ownership checks are authoritative.

Customer endpoints derive the current user ID from claims. Booking and payment reads reject cross-customer access. Booking creation permits the current customer, staff, or a valid internal agent service key. Agent callback routes validate `X-Agent-Service-Key` with fixed-time comparison. The Python service uses the configured backend URL and service key for logs/final callbacks; its payment helper additionally sends a bearer token and reloads the booking before payment.

## 16. Security Considerations

Implemented controls include Identity password handling and unique email, JWT validation, role authorization, customer ownership/IDOR checks, protected approval and reporting routes, internal callback key comparison, server-side customer/TripRequest matching, database foreign keys and unique booking references, validation attributes, trusted server-side price/total recomputation, active-inventory checks, approval-before-payment, secure Flutter token storage, and removal of access tokens from initial AgentLog snapshots.

The proposal persistence service rejects invalid IDs, inactive catalogue records, wrong destinations, invalid dates/times, overlaps, capacity shortages, unavailable rooms/seats, currency mismatches, reported-total mismatches and budget overruns. The validation-agent tests include prompt-injection text to confirm deterministic commercial rules remain authoritative. Secrets are represented by environment/configuration names rather than committed values.

## 17. React Application Design

React is the staff/travel-agent/admin dashboard and also contains public catalogue pages. The application uses React Router, Axios, Vite, responsive helpers and a staff layout. Main pages include `Login`, `CustomerDirectory`, `NotificationLogs`, `DestinationManagement`, `TourCatalogManagement`, `ItineraryReview`, `HotelVendorManagement`, `TransportFleetManagement`, `BookingApprovalDashboard`, `PaymentsRevenueReport` and `MediaLibrary`. Public pages include Home, About, Contact, Destinations, DestinationDetail, Experiences and Planner.

`src/services/apiClient.js` centralizes HTTP calls and auth headers. `RequireAuth.jsx`, `auth.jsx` and `StaffLayout.jsx` implement protected staff navigation. Loading, error, empty-state and error-boundary components support UI feedback. Catalogue pages support management forms, filters and media/image interactions; approval and revenue pages consume the approval/payment APIs.

## 18. Flutter Application Design

Flutter is the customer-facing application. Screens include landing, register/login, home, profile/preferences, notifications, trip request, trip history, tour search/browse, tour details, itinerary, accommodation options, transport options, trip map, booking status, checkout/payment and trip confirmation. `api_service.dart` is the backend integration layer; `app_navigation.dart`, `auth_guard.dart` and `flutter_secure_storage` support navigation and protected sessions.

The app uses `http`, `intl`, `google_fonts`, `flutter_map`/`latlong2`, `qr_flutter` and a PDF service. The trip map screen uses destination/transport coordinates where available. `trip_confirmation_screen.dart` presents final confirmation and QR information, while `ticket_pdf_service.dart` produces a customer ticket document. Screen tests cover home, preferences, notifications, itinerary, trip request, history and phase workflow behavior. The application includes Android, iOS, Windows, macOS, Linux and web project scaffolding.

## 19. Agentic AI Architecture

This is an agentic workflow because several role-specialized nodes maintain shared state, call tools, make bounded decisions and route execution conditionally. It is more than a chatbot: the output is a structured proposal tied to real catalogue records, checked by deterministic rules, logged, sent to a central API and stopped at a human approval gate.

1. **Coordinator / Planning Agent — Student A:** Inputs trip request fields and preferences; calculates duration and budget allocation; optionally asks Gemini for theme/strategy; outputs `plan_summary`, `target_budgets`, `trip_days` and planning status. On validation failure it decides whether the one retry is available. It logs decomposition and retry/termination steps.
2. **Itinerary / Domain Analysis Agent — Student B:** Inputs dates, destination, traveller count, activities and budget; calls `search_tours`; asks the configured LLM or uses deterministic behavior to create a schedule; validates active IDs, maximum two tours per day, per-traveller price, time overlap and total budget. Outputs a structured schedule with day number, sequence, times and prices. It does not directly persist the itinerary.
3. **Booking / Tool-Use Agent — Student C:** Inputs the itinerary and request; calls hotel, room, room-availability, transport and transport-availability tools; filters by active status, capacity and dates; chooses exactly one room and one transport from returned data; uses LLM selection when configured and cheapest deterministic selection otherwise. Invalid/fake IDs are rejected. It logs tool steps and package assembly.
4. **Validation / Approval Agent — Student D:** Inputs the complete proposal; deterministic Python code validates numeric fields, dates, IDs, currency, item references, totals, budget and approval behavior. It returns a validated proposal for ASP.NET persistence with `AwaitingApproval`; it never approves itself or initiates planning-time payment. Payment helper logic reloads persisted booking status and refuses non-Confirmed status.

Failures are returned as structured error codes such as `NO_VALID_TOURS`, `NO_VALID_ROOM`, `NO_VALID_TRANSPORT`, `BUDGET_EXCEEDED`, `CURRENCY_MISMATCH`, `TOTAL_MISMATCH` and invalid-reference errors. Agent steps are posted to ASP.NET `AgentLog` with agent, step, tool, status, input/output snapshots and timestamp fields that are actually persisted.

## 20. LangGraph Workflow

```text
START -> coordinator -> itinerary -> booking -> validation -> evaluator
                                                          |
                                     valid ---------------+--> END
                                     invalid, retry 0 ---+--> coordinator
                                     invalid, retry 1 ---+--> END (Failed)
```

`TripPlanningState` includes trip/customer/destination data, dates, traveller count, budget/currency, retry count, access token, planning summary, target budgets, itinerary, booking details, validation result, plan JSON, failure reason and next action. The graph uses a linear edge sequence and a conditional evaluator edge. The retry is limited to one because the coordinator changes to an economy target (15% reduction) once and then records permanent failure instead of looping indefinitely. Human approval is outside the graph: a valid graph result is synced to ASP.NET, persisted as `AwaitingApproval`, and the graph stops. Revision starts a separate trigger with human feedback.

## 21. AI Tools

| Tool/function | Agent | Input/output | Purpose |
|---|---|---|---|
| `search_tours` | Itinerary | destination/filter inputs -> active tour JSON | Provides real tour catalogue records. |
| `search_hotels` | Booking | optional destination -> active hotels | Finds accommodation vendors. |
| `search_hotel_rooms` | Booking | hotel ID -> rooms | Finds candidate rooms. |
| `check_room_availability` | Booking | hotel/room IDs and dates -> availability JSON | Verifies room dates and counts. |
| `search_transports` | Booking | no/limited filter -> active options | Finds transport inventory. |
| `check_transport_availability` | Booking | transport ID -> seats/availability | Verifies capacity. |
| `log_agent_step` | All agents | trip ID, step, input/output/status -> backend AgentLog | Audits execution. |
| `sync_result_to_backend` | Graph | trip ID, final status, plan JSON, retries -> secured PATCH | Sends final proposal/status to ASP.NET. |
| `persist_itinerary` / `create_booking` | AI tools | proposal data | Explicitly disabled for direct AI persistence; ASP.NET owns persistence. |
| `initiate_payment` | Post-approval helper | booking/token/payment data | Reloads booking, requires Confirmed, then calls payment API. |

## 22. Human-in-the-Loop Design

The AI produces a proposal, ASP.NET validates and persists it as `AwaitingApproval`, and the AI stops. React presents the pending queue to a TravelAgent/Admin. The decision is submitted to `POST /api/approval`.

- **Approved:** serializable approval transaction records an immutable `BookingApproval` row and changes booking to `Confirmed`.
- **Rejected:** approval history records the reason and booking becomes `Rejected`.
- **RevisionRequested:** approval history records feedback; the current booking becomes `Cancelled`, its itinerary becomes `Discarded`, the TripRequest returns to `Planning`, and `RevisionPlanningService` launches a new planning run. The old records remain available for audit.

AI cannot approve itself because approval endpoints require TravelAgent/Admin roles, proposal persistence creates `AwaitingApproval`, and payment service rejects any non-Confirmed booking. This separates probabilistic planning from commercial authorization and provides an auditable human decision point.

## 23. Budget Validation and Retry Logic

The customer supplies `BudgetCeiling`. Coordinator allocation is tours 35%, hotels 45%, transport 15%, buffer 5%. On retry, the effective target is `budget * 0.85`. Itinerary validation calculates tour cost as price times traveller count; backend proposal persistence calculates trusted tour, room-night and transport totals from database entities.

```text
validate proposal
  if valid -> AwaitingApproval
  else if RetryCount == 0 -> RetryCount = 1, economy planning, run graph again
  else -> Failed with FailureReason
```

The backend repeats the budget check even if the AI reports a valid total. This protects the commercial boundary from incorrect or manipulated proposal values.

## 24. Itinerary Generation Logic

The itinerary agent searches active tours for the selected destination, passes dates/travellers/budget/preferences into the generation step, then validates the returned JSON. Each scheduled item contains `tour_id`, name/price, `day_number`, `sequence_order`, `start_time` and `end_time`. At most two tours are accepted per day by the Python validator. Pairwise interval comparison rejects overlapping tours while allowing an item to start exactly when another ends. Prices are per traveller for tour-cost calculation.

ASP.NET repeats active-tour, destination, time-range, overlap, currency and trusted-price checks in `AgentProposalPersistenceService`. It creates `ItineraryItem` rows with `PriceAtSelection` and stores the itinerary’s estimated tour cost. `ItineraryService` supports subsequent item/status operations.

## 25. Accommodation and Transport Logic

The Booking Agent searches active hotels and rooms, requires room capacity for the traveller count, checks dates through the availability endpoint, and records an available room. The backend persistence layer repeats hotel-active, room-capacity, room-count and date-overlap checks. Room cost is nightly price times trip nights, with at least one night.

Transport selection uses active `TransportOption` records with provider, type, route, departure/arrival, capacity, price and status. The agent checks available seats/capacity; persistence counts active booking quantities and rejects a package when requested seats exceed capacity. Currency checks occur in Python normalization and again in ASP.NET. These rules ensure Student C’s agent uses backend inventory rather than invented hotel/room/transport IDs.

## 26. Booking Design

`Booking` links a customer and itinerary, has a unique `BookingReference`, status, total cost, currency and timestamps. `BookingItem` represents Tour, Room or Transport. Tour items carry traveller quantity, unit price and subtotal; room items carry room ID, check-in/out and room total; transport items carry transport ID, traveller quantity, unit price and subtotal. The proposal service generates references in the `ST-yyyyMMddHHmmss-XXXXXXXX` shape and checks uniqueness.

The normal lifecycle is `Draft`/creation path to `AwaitingApproval`, then `Confirmed`, `Rejected`, `Cancelled` or `Completed` according to the available status model. Trusted prices are loaded from `Tours`, `Rooms` and `TransportOptions`; reported AI totals are comparison values, not the source of truth.

## 27. Approval and Revision Design

`ApprovalService` requires the booking to be `AwaitingApproval`, ensures a TravelAgent profile exists, appends an approval record and updates status in a serializable transaction. Approval rows are permanent audit entries containing booking, agent, decision, comment and timestamp. Revision does not overwrite the old proposal; it marks the old booking/itinerary appropriately, stores feedback on the trip request and starts planning again. The new proposal returns to the same approval gate.

## 28. Payment and Checkout Design

`PaymentService.ProcessPaymentAsync` reloads the booking and refuses any status other than `Confirmed`. It chooses the supplied positive amount/currency or booking values, creates a Stripe-sandbox-shaped reference (`ch_sb_...`), stores `Paid` by default, and supports a deterministic declined-token simulation (`tok_chargeDeclined`) that records `Failed`. Payment queries enforce customer ownership unless staff roles are present. React provides staff payment/revenue views; Flutter provides checkout and status screens.

## 29. Ticket, QR and PDF Design

Flutter’s confirmation flow is represented by `booking_status_screen.dart`, `checkout_payment_screen.dart`, `trip_confirmation_screen.dart` and `ticket_pdf_service.dart`. The application includes `qr_flutter` for QR rendering and a PDF service for ticket output. The backend supplies booking reference, status, customer/package data and payment state used by the customer confirmation experience.

## 30. Notification Design

`Notification` stores customer, channel, message type, content, delivery status, read timestamp and sent timestamp. The API supports customer list/count/read/unread/mark-all-read/resend operations and staff sending. React’s `NotificationLogs` page supports staff visibility. The model includes Email, SMS, Push and InApp channel values, but this repository evidence establishes persistence and API handling; it does not establish an external email/SMS provider implementation.

## 31. Search, Filtering, Sorting and Pagination

Backend services expose search/sort/page parameters for customers, preferences, notifications, trip requests, hotels, rooms, transport and tours. Destination/tour/hotel/transport controllers expose catalogue filters such as destination, price, status, type, route, star rating, room type and capacity. Booking supports customer/status filtering; payment service returns ordered lists; staff React pages provide operational filters. Customer trip history, notification lists and catalogue screens consume paged/list responses.

## 32. Reporting and Analytics

`PaymentService.GetRevenueReportAsync` calculates total paid revenue, counts paid/pending/failed payments, groups paid revenue by year/month and returns recent payments. `PaymentsRevenueReport.jsx` consumes this staff report. Other operational evidence includes customer/trip request directories, notification logs, approval histories and AgentLog displays. No unsupported external analytics platform is claimed.

## 33. Transaction and Concurrency Design

Proposal persistence uses `IsolationLevel.Serializable` and a PostgreSQL advisory transaction lock keyed by TripRequest ID. It detects existing itinerary/booking records and returns an already-persisted result when a duplicate callback is received for a non-cancelled/non-rejected proposal. Approval processing also uses a serializable transaction and only accepts `AwaitingApproval`. Room and transport availability is rechecked inside proposal persistence using active booking items and database totals. BookingReference has a unique index and generation retry loop. These mechanisms protect duplicate callbacks, duplicate approval decisions, capacity and partial commercial persistence.

## 34. Error Handling and Recovery Paths

ASP.NET model-state errors use a standard 400 response; controllers translate not-found, invalid-operation, forbidden and service-unavailable cases. FastAPI returns structured pipeline errors; tool helpers catch connection/HTTP/JSON problems and return empty or explicit failure outcomes. No availability becomes a named package failure; over-budget planning retries once; a second failed validation becomes `Failed`; approval rejection and revision are explicit states; payment refusal/failure is recorded; duplicate proposal callbacks are handled by existing-record detection. Flutter and React include loading/error/empty-state components and display backend results through their API layers.

## 35. Agent Logging and Auditability

`AgentLog` is linked to `TripRequest` and persists GUID ID, agent name, step name, input/output strings, status and timestamp. Python logs initialization, coordinator decomposition, budget retry/termination, availability tool calls, booking package assembly and validation activity through `logger.py`. ASP.NET logs the final proposal persistence step with itinerary/booking identifiers. Staff can retrieve logs through trip-request log routes and React notification/log views. `StepType`, `ToolName` and `DurationMs` exist in the model as not-mapped fields, so only fields actually persisted to the database should be treated as database audit columns.

## 36. Software Testing Strategy

- **Backend unit/service tests:** `CustomerServiceTests`, `TourServiceTests`, `ItineraryServiceTests`, `HotelServiceTests`, `TransportServiceTests`, `AvailabilityServiceTests`, `TripRequestServiceTests` and `BookingServiceTests` exercise domain behavior.
- **Workflow/security/integration:** `ApprovalWorkflowTests`, `AgentProposalPersistenceTests`, `AgentTriggerControllerTests`, `IntegrationSecurityTests` and `ConcurrentBookingIntegrationTests` cover approval, proposal transaction, authorization and concurrency behavior.
- **AI tests:** Python tests cover itinerary golden cases, validation, search, pipeline contracts, prompt injection, real-ID/availability behavior and payment approval-gate behavior.
- **Flutter:** `flutter_test` widget tests cover home, profile preferences, notifications, itinerary, trip request, trip history, phase-one regression and phase-two workflow behavior.
- **React:** The repository contains the React build/lint scripts; no separate React test suite was identified in the current file inventory.

The test design emphasizes deterministic business rules, ownership, state transitions, database-backed IDs, capacity/availability, retry, approval and prompt-injection resistance rather than relying only on an LLM judge.

## 37. Final Test Evidence Available in Repository

The repository contains a .NET test project in `backend.Tests/backend.Tests.csproj`, named C# test classes for services, security, approval, proposal persistence, agent trigger and concurrency, Flutter tests under `mobile_flutter/test/`, and Python tests under `agentic-ai/test_*.py`. Current source files provide test cases and assertions, including approval-gate and prompt-injection assertions; no reliable stored final execution total is claimed here.

## 38. Agentic AI Evaluation Strategy

Evaluation combines golden cases and deterministic assertions. `test_itinerary_agent_golden.py` checks schedule shape, active tour IDs, maximum daily items, overlaps and budget; it includes normal, low-budget, nonexistent-destination and output-contract cases. Pipeline contract tests verify missing keys, no-tour/no-room/no-transport paths, no fake IDs, real room/transport ID preservation, redaction of access tokens and disabled direct persistence. Validation tests cover valid packages, budget exceeded, currency mismatch, total mismatch, approval status and payment gating. Prompt-injection tests verify hostile customer text cannot bypass time/budget checks or persisted booking status. This approach makes commercial and safety rules independently testable instead of treating generated text as authoritative.

## 39. Performance Testing

No k6 or dedicated load-test asset was found in the current repository inventory. The implementation includes API timeouts, paged service queries and an asynchronous FastAPI pipeline endpoint, which are architectural capabilities rather than measured performance results. No performance numbers are asserted.

## 40. Third-Party Integrations

| Integration | Purpose | Evidence/configuration |
|---|---|---|
| Google Gemini | Coordinator/itinerary/booking LLM assistance when configured; deterministic fallback otherwise | `GEMINI_API_KEY`, `GOOGLE_API_KEY_BOOKING`, `coordinator_agent.py`, `itinerary_agent.py`. |
| AIML API | Optional booking-agent chat-completion path | `AIML_API_KEY` and `booking_agent.py`. |
| Stripe sandbox-shaped flow | Payment reference/status behavior; current service uses deterministic sandbox simulation rather than a committed secret SDK integration | `PaymentService.cs`, `StripeToken`, `StripeReference`. |
| Supabase | PostgreSQL/storage health and optional catalog-image storage paths | `SUPERBASE_URL`/Supabase keys and `/supabasehealth`, `/setup-supabase-storage`. |
| Map tile/provider ecosystem | Flutter map display | `flutter_map` and `latlong2` dependencies; no separate provider URL is asserted here. |

## 41. Configuration and Environment Variables

| Variable/key | Used by | Purpose | Required/optional | Secret? |
|---|---|---|---|---|
| `SUPERBASE_URL`, `DATABASE_URL`, `ConnectionStrings:Default` | ASP.NET | PostgreSQL connection selection | One database source expected | Yes if credentials embedded |
| `Jwt:Key` / environment JWT key | ASP.NET | JWT signing | Required runtime secret | Yes |
| `Jwt:Issuer`, `Jwt:Audience`, `Jwt:ExpiryMinutes` | ASP.NET | Token validation/lifetime | Configured | No/operational |
| `StaffSecretCode` | ASP.NET | Staff registration gate | Required for staff registration | Yes |
| `AGENT_SERVICE_API_KEY` / `AgentService:ApiKey` | ASP.NET/Python | Internal agent callback header | Required for secured callbacks | Yes |
| `BACKEND_URL` / `BACKEND_API_URL` | Python | ASP.NET base URL | Optional with local default | No |
| `AGENT_BACKEND_TOKEN` | Python | Bearer token for protected helper calls | Optional/contextual | Yes |
| `GEMINI_API_KEY`, `GOOGLE_API_KEY`, `GOOGLE_API_KEY_BOOKING` | Python | LLM provider credentials | Optional; fallbacks exist | Yes |
| `AIML_API_KEY` | Python booking agent | Optional AIML chat completion | Optional | Yes |
| `PORT` | FastAPI | Listening port, default 8005 | Optional | No |
| `NEXT_PUBLIC_SUPABASE_URL`, `VITE_SUPABASE_URL`, `SUPABASE_URL` | ASP.NET health/storage | Supabase URL | Optional/configured deployment | No |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `VITE_SUPABASE_ANON_KEY`, `SUPABASE_ANON_KEY`, `SUPABASE_KEY` | ASP.NET health/storage | Supabase access key | Optional/configured deployment | Treat as secret/config value |
| React/Flutter API base constants | Client apps | Backend URL | Set in client configuration | No unless embedded credentials |

No secret values are reproduced in this file.

## 42. Deployment Architecture

The repository supports separate deployment units: PostgreSQL database; ASP.NET Core API, including `backend/Dockerfile`; FastAPI/uvicorn AI service; Vite-built React static application; and Flutter mobile/desktop/web builds. Runtime startup depends on the database and on configured API/AI URLs. Environment variables provide connection strings, JWT/service keys and provider credentials. HTTPS is a deployment concern; the current `Program.cs` explicitly leaves `UseHttpsRedirection` disabled for mobile HTTP testing. No cloud provider or deployed URL is asserted because no authoritative deployment URL is stored in the implementation.

## 43. Startup / Run Instructions

1. **PostgreSQL:** Create/provide a PostgreSQL database and set one supported connection source such as `SUPERBASE_URL`, `DATABASE_URL` or `ConnectionStrings:Default`; apply EF migrations or the supplied SQL schema as appropriate.
2. **ASP.NET:** From `backend/`, set JWT and database/service configuration, then run `dotnet restore` and `dotnet run`. Swagger is at `/swagger`; `/dbhealth` checks connectivity. Startup seeds sample data through `DbInitializer`.
3. **Python AI:** From `agentic-ai/`, install `requirements.txt`, set `BACKEND_URL`/`BACKEND_API_URL`, `AGENT_SERVICE_API_KEY` and optional LLM keys, then run `python main.py` or `uvicorn main:app --host 0.0.0.0 --port 8005`.
4. **React:** From `frontend-react/`, run `npm install`, set the API base configuration used by `apiClient.js`, then `npm run dev`; build with `npm run build` and preview with `npm run preview`.
5. **Flutter:** From `mobile_flutter/`, run `flutter pub get`, configure the backend base URL in the application constants/API service, then `flutter run`. Android output can be produced with `flutter build apk`; the repository includes platform scaffolding.

## 44. Repository and Submission Information

- Repository name: `AI-Travel-Planning-Booking-Management-System`.
- Main folders: `backend`, `backend.Tests`, `agentic-ai`, `frontend-react`, `mobile_flutter`, `docs`, `Readme`.
- API documentation pattern: backend root redirects to `/swagger`; Swagger JSON is `/swagger/v1/swagger.json`.
- React access pattern: Vite dev server or built static output; no deployed URL is stored.
- Flutter APK command: `flutter build apk` (output path should be taken from the local Flutter build).
- React deployed URL: **[ADD FINAL URL]**.
- Backend API URL: **[ADD FINAL URL]**.
- Swagger URL: **[ADD FINAL URL]**.
- Flutter APK link/location: **[ADD FINAL LINK OR REPOSITORY LOCATION]**.

## 45. Architectural Decision Records (ADR) Material

### ADR-01: Shared ASP.NET API boundary

Context: multiple clients and an AI service need one trusted business layer. Chosen approach: React, Flutter and Python communicate with ASP.NET REST endpoints. Reason: centralized authorization, validation and persistence. Consequence: clients share contracts and the backend remains the system of record.

### ADR-02: PostgreSQL with EF Core

Context: the domain has relational ownership, workflow and audit relationships. Chosen approach: PostgreSQL/Npgsql with EF Core migrations. Reason: foreign keys, transactions, indexes and JSONB support. Consequence: schema is strongly modeled and migration-driven.

### ADR-03: Identity plus JWT

Context: mobile, browser and service clients require stateless API authentication. Chosen approach: ASP.NET Identity for users/roles/passwords and JWT bearer tokens for API calls. Consequence: role and ownership checks are shared across clients.

### ADR-04: React staff client and Flutter customer client

Context: staff operations and customer device journeys have different interaction patterns. Chosen approach: React dashboard for operations and Flutter for cross-platform customer experience. Consequence: both use the common API while optimizing their own UI and device capabilities.

### ADR-05: Four-agent LangGraph workflow

Context: planning, itinerary analysis, inventory selection and commercial validation are distinct responsibilities. Chosen approach: four stateful nodes plus evaluator/retry routing. Consequence: each agent has bounded inputs/outputs and the graph is inspectable/loggable.

### ADR-06: ASP.NET-owned proposal persistence

Context: AI output must not directly create trusted commercial records. Chosen approach: Python returns a proposal; ASP.NET revalidates and atomically creates itinerary/booking records. Consequence: server-side prices, IDs, capacity and status rules remain authoritative.

### ADR-07: Human approval gate

Context: travel-agent judgment is required before commercial confirmation/payment. Chosen approach: every valid proposal stops at `AwaitingApproval`; only TravelAgent/Admin can decide. Consequence: approval history is auditable and AI cannot authorize payment.

### ADR-08: One-retry planning rule

Context: an over-budget proposal may be recoverable, but unbounded loops are undesirable. Chosen approach: one 15% economy retry, then failure. Consequence: predictable execution and explicit failure reason.

### ADR-09: Status/soft-delete catalogue design

Context: catalog items should be hidden without losing references/history. Chosen approach: Active/Inactive status for hotels, transports and tours. Consequence: historical relationships remain while searches use active inventory.

### ADR-10: Serializable commercial transitions

Context: duplicate callbacks and concurrent inventory decisions can create inconsistent packages. Chosen approach: serializable persistence/approval transactions, advisory trip lock, unique references and rechecked capacity. Consequence: stronger consistency around expensive state changes.

## 46. Diagrams Needed for Final Report

1. **High-level architecture:** Flutter -> ASP.NET; React -> ASP.NET; ASP.NET -> PostgreSQL; ASP.NET <-> FastAPI; FastAPI -> optional Gemini; ASP.NET -> payment/storage integration.
2. **End-to-end customer flow:** register -> login -> preferences -> trip request -> AI planning -> AwaitingApproval -> human decision -> Confirmed -> payment -> ticket.
3. **Agentic graph:** START -> Coordinator -> Itinerary -> Booking -> Validation -> Evaluator; retry edge to Coordinator; success/failure edges to END.
4. **Human approval:** proposal -> persistence -> AwaitingApproval -> TravelAgent decision branching to Confirmed, Rejected or RevisionRequested -> new run.
5. **Deployment:** PostgreSQL, ASP.NET container/process, FastAPI service, React static host and Flutter device/app package with environment-variable links.
6. **Trip-planning sequence:** Flutter/ASP.NET request, trigger, FastAPI nodes/tools, AgentLog callbacks, proposal callback, transaction and status polling.
7. **Payment sequence:** Flutter checkout -> ASP.NET ownership lookup -> Confirmed check -> payment service -> Payment row -> confirmation response.
8. **Component diagram:** client components, controllers, domain services, EF Core/AppDbContext, database, AI agents/tools and external providers.

Mermaid-ready edge examples are given by the ASCII diagrams in sections 8, 9 and 20; the ER diagram is intentionally not regenerated.

## 47. Technical Challenges and Engineering Solutions

| Challenge | Why it matters | Final technical solution |
|---|---|---|
| Coordinate four agents | Each stage depends on structured state from the prior stage | LangGraph `TripPlanningState`, named nodes, conditional evaluator and AgentLog. |
| Prevent unsafe AI persistence | Generated IDs/prices may not be trusted | Direct AI persistence functions are disabled; ASP.NET proposal service revalidates database records. |
| Use real inventory | A travel package must reflect available catalogue data | Search/availability tools return backend records; invalid IDs fail closed. |
| Protect capacity and duplicates | Concurrent requests can oversell rooms/seats | Serializable transaction, advisory lock, active booking count and unique reference. |
| Enforce human approval | AI should not confirm commercial state | `AwaitingApproval`, role-protected approval API and confirmed-only payment. |
| Preserve revision history | New planning should not erase prior decisions | Immutable approval rows, discarded old itinerary/cancelled booking and new proposal. |
| Consistent pricing | AI totals can be incorrect | Server reloads prices, calculates totals and compares reported values. |
| Secure cross-service callbacks | AI needs to update backend without broad user access | `X-Agent-Service-Key` fixed-time validation and bearer propagation where needed. |
| Cross-platform contracts | React, Flutter and Python need compatible data | Shared REST DTOs, JSON payloads and central ASP.NET API. |
| Prompt injection | Customer text must not change commercial rules | Deterministic validation and tests that send adversarial instructions. |

## 48. Software Engineering Practices

Evidence includes Git repository metadata, separated component ownership, controller/service/DTO separation, dependency injection, EF migrations, PostgreSQL schema scripts, environment-based configuration, Swagger/OpenAPI, security attributes, service interfaces, test projects, Flutter widget tests, Python golden/contract/security tests and optional Docker packaging. The code separates probabilistic AI generation from deterministic domain validation and central persistence.

## 49. Git / Version Control Evidence

The repository is a Git working tree and includes `.gitignore`, project folders and supporting documentation. No authoritative branch policy or per-student commit attribution is asserted in this file because individual Git history was not used to infer personal contributions. Component ownership is documented from the implementation structure and current project materials, not from fabricated commit counts.

## 50. Individual Report Evidence — Student A

- **Owned component:** Customer Profile, Preferences, Notifications, Trip Requests and Coordinator/Planning Agent.
- **Backend:** `Customer.cs`, `Preference.cs`, `Notification.cs`, `TripRequest.cs`, `AgentLog.cs`; corresponding DTOs, controllers and `CustomerService`, `PreferenceService`, `NotificationService`, `TripRequestService`.
- **Flutter:** `profile_preferences_screen.dart`, `notifications_screen.dart`, `trip_request_screen.dart`, `trip_history_screen.dart`, profile/navigation support.
- **AI:** `agents/coordinator_agent.py`, graph orchestration and retry evaluator.
- **Technical work:** structured request capture, status lifecycle, budget allocation, preference-aware planning input, logs and service integration.
- **Testing/security:** customer/trip service tests, agent-trigger/pipeline tests, token redaction and ownership-related behavior.
- **Integration:** connects request state to Student B/C/D agents and ASP.NET proposal/approval flow.
- **Challenge/solution:** coordinate natural-language request to bounded multi-agent planning with one controlled retry and audit logging.

## 51. Individual Report Evidence — Student B

- **Owned component:** Destinations, Tours, Itineraries and ItineraryItems.
- **Backend:** `Destination.cs`, `Tour.cs`, `Itinerary.cs`, `ItineraryItem.cs`, destination/tour/itinerary controllers/services/DTOs.
- **React/Flutter:** `DestinationManagement.jsx`, `TourCatalogManagement.jsx`, `ItineraryReview.jsx`, `tour_search_browse_screen.dart`, `tour_details_screen.dart`, `my_itinerary_screen.dart`.
- **AI:** `agents/itinerary_agent.py`, `tools/search_tours.py`.
- **Technical work:** active-tour search, structured schedule, day/sequence/time fields, price calculation and overlap detection.
- **Testing:** `TourServiceTests`, `ItineraryServiceTests`, itinerary golden/contract tests and overlap/budget assertions.
- **Integration/security:** supplies real tour IDs to Booking Agent and server rechecks active destination/currency/price constraints.
- **Challenge/solution:** turn a generated schedule into a safe, database-compatible itinerary using deterministic conflict and identity validation.

## 52. Individual Report Evidence — Student C

- **Owned component:** Hotels, Rooms, Transport and Availability.
- **Backend:** `Hotel.cs`, `Room.cs`, `TransportOption.cs`, hotel/transport/availability services, controllers and DTOs.
- **React/Flutter:** `HotelVendorManagement.jsx`, `TransportFleetManagement.jsx`, `accommodation_options_screen.dart`, `transport_options_screen.dart`, `trip_map_screen.dart`.
- **AI:** `agents/booking_agent.py`, `tools/availability_tools.py`.
- **Technical work:** catalogue management, active status, room capacity/date checks, transport capacity and database-backed selection.
- **Testing:** hotel, transport, availability and concurrent booking tests; AI no-room/no-transport and real-ID contract cases.
- **Integration/security:** Booking Agent uses API search/availability; proposal persistence repeats active/capacity/currency checks.
- **Challenge/solution:** prevent invented or unavailable inventory from entering a commercial package by selecting only backend-returned records.

## 53. Individual Report Evidence — Student D

- **Owned component:** Bookings, BookingItems, Approval, Payment and Validation Agent.
- **Backend:** booking/approval/payment models, `BookingService`, `AgentProposalPersistenceService`, `ApprovalService`, `PaymentService`, controllers and DTOs.
- **React/Flutter:** `BookingApprovalDashboard.jsx`, `PaymentsRevenueReport.jsx`, `booking_status_screen.dart`, `checkout_payment_screen.dart`, `trip_confirmation_screen.dart`, `ticket_pdf_service.dart`.
- **AI:** `agents/validation_agent.py`, `tools/validation_tools.py`.
- **Technical work:** atomic proposal persistence, status transitions, immutable approval audit, revision, trusted totals and confirmed-only payment.
- **Testing:** booking, approval, persistence, security, concurrency and validation/payment-gate tests.
- **Integration/security:** receives proposal from graph, persists commercial entities, exposes staff queue and feeds customer checkout/ticket flow.
- **Challenge/solution:** connect probabilistic proposals to safe human-authorized booking/payment through deterministic validation and transaction boundaries.

## 54. Individual Report Template Data

| Field | Student A | Student B | Student C | Student D |
|---|---|---|---|---|
| Technical component | Customer/profile/preferences/notifications/trips | Destination/tour/itinerary | Hotel/room/transport/availability | Booking/approval/payment |
| Agent | Coordinator | Itinerary | Booking/Tool-use | Validation/Approval |
| Backend work | Customer, preference, notification, trip services | Catalogue and itinerary services | Inventory/availability services | Persistence, approval, payment services |
| React work | Customer/log views | Destination/tour/itinerary review | Hotel/transport management | Approval/revenue pages |
| Flutter work | Profile, preferences, requests, history | Tour and itinerary screens | Accommodation, transport, map | Checkout, status, confirmation, ticket |
| Database work | Customer-related workflow/log tables | Destination/tour/itinerary relationships | Hotel/room/transport relationships | Booking, item, approval, payment tables |
| Testing evidence | Customer/trip/trigger/pipeline | Tour/itinerary/golden | Hotel/transport/availability/concurrency | Booking/approval/security/validation |
| Integration work | Starts and observes planning | Supplies itinerary | Supplies real inventory | Persists and gates commercial state |
| Security/business rules | Ownership, token redaction, retry | Active IDs, overlap, budget | Active/capacity/availability | Approval, trusted price, payment gate |
| Challenge/solution | Controlled request orchestration | Safe schedule generation | Real inventory selection | Human-authorized transaction flow |
| Potential learning themes | APIs, state, agent coordination | Domain modeling, validation | Availability and concurrency | security, transactions, payment workflow |

## 55. AI Usage Declaration Evidence

Repository evidence supports a neutral declaration structure rather than personal claims:

| Activity | AI tool/use category | Purpose | Human verification | Area |
|---|---|---|---|---|
| Runtime trip planning | Gemini/optional LLM calls | Theme, itinerary and package proposal assistance | Deterministic Python/backend validation and human approval | `agentic-ai/` |
| Software development/documentation | Not established by current source alone | Human-specific development use cannot be attributed without project logs | Add verified records manually | Entire repository |

No specific developer conversation or tool-use history is claimed unless separately documented by the team.

## 56. Individual AI Usage Log Template

Repeat for each student:

| Date | AI tool | Task | Prompt purpose | Output used | Changes made by student | Verification |
|---|---|---|---|---|---|---|
| [ADD] | [ADD] | [ADD] | [ADD] | [ADD] | [ADD] | [ADD] |

## 57. References / Technologies to Cite

The final report should cite official documentation for the exact technologies evidenced here: Microsoft ASP.NET Core 8, ASP.NET Core Identity, JWT bearer authentication, Entity Framework Core 8, Npgsql/PostgreSQL, Swagger/OpenAPI/Swashbuckle, React 19, Vite, Axios, React Router, Flutter, Dart, `flutter_secure_storage`, `qr_flutter`, `flutter_map`, `latlong2`, FastAPI, Uvicorn, Pydantic, LangGraph, Google Gemini/GenAI libraries, Stripe payment concepts, xUnit/.NET testing, `pytest`/Python testing and Git. Official URLs can be retrieved separately by the final report writer; they are not invented here.

## 58. Final Report Requirement Mapping

| Submission requirement | Relevant sections | Evidence |
|---|---|---|
| Overview and scope | 1–3 | Project stack, purpose, boundaries |
| Requirements and roles | 4–6 | FR/NFR and permission matrix |
| Full-stack architecture | 9–11, 17–18 | API, services, clients |
| Agentic AI report | 19–25, 38 | Agents, graph, tools, evaluation |
| Database/ER companion text | 12–13 | Entity/relationship tables and prose |
| API report | 14–16 | Endpoint/auth tables |
| React design | 17 | Pages, services, auth |
| Flutter design | 18 | Screens, storage, device features |
| Testing report | 36–37 | Actual test assets and evidence boundaries |
| Performance report | 39 | Available performance evidence |
| Deployment/startup | 42–44 | Docker, services, commands, placeholders |
| ADRs | 45 | Decision material |
| Security | 15–16, 33–35 | Controls, transactions, audit |
| Diagrams | 8–9, 20, 22, 46 | ASCII/Mermaid-ready flows |
| References | 57 | Technology list |
| AI declaration | 55–56 | Neutral evidence/template |
| Individual contributions | 50–54 | Student A–D evidence |
| Repository/deployed system | 44, 49 | Folder/repository evidence and manual URLs |
| APK/startup information | 18, 43–44 | Flutter build and run paths |

## 59. Information That Must Be Added Manually Later

- Final student names and registration numbers, if required.
- Final deployed React, API and Swagger URLs.
- Final demo/video, APK and signed declaration links.
- Personal reflections and verified individual AI-usage entries.
- Exact final test execution totals if the team wants to report them.
- Deployment credentials/access instructions that must never be stored in this fact file.

## 60. Master Fact Summary for Astra

The AI Travel Planning & Booking Management System is a full-stack travel platform that turns a customer’s trip intent into a structured, reviewable and payable travel package. The customer-facing application is Flutter, while the operational dashboard is React. Both clients communicate with a central ASP.NET Core 8 Web API. The API is the authoritative application boundary: it authenticates users with ASP.NET Identity and JWT, authorizes customers, travel agents and administrators, validates requests, accesses PostgreSQL through Entity Framework Core/Npgsql, owns workflow states, persists commercial records, exposes Swagger and serves operational data to both clients.

The database is relational and includes Identity tables plus Customer, Preference, Notification, TripRequest, AgentLog, Destination, Tour, Itinerary, ItineraryItem, Hotel, Room, TransportOption, Booking, BookingItem, BookingApproval, TravelAgent and Payment entities. Foreign keys express ownership and catalogue relationships. Preferences are unique per customer. Booking references are unique. Money is decimal and trip plans are stored as JSONB. Active/inactive status values allow catalogue records to be hidden from searches while retaining relationships. TripRequest is the workflow root: it stores raw intent, destination, dates, traveller count, budget, currency, status, retry count, plan JSON and failure reason. AgentLog rows connect each automated step to that request.

The system has four student-owned business areas. Student A owns customer profile, preferences, notifications, trip requests and coordination. Student B owns destinations, tours, itineraries and itinerary items. Student C owns hotels, rooms, transport and availability. Student D owns bookings, booking items, approvals, payments and validation. Each area has backend entities/services/controllers and corresponding React or Flutter surfaces. The components integrate through one API and a shared workflow rather than separate data stores.

The AI subsystem is a separate Python FastAPI service using LangGraph. Its graph state carries trip identifiers, customer and destination data, dates, traveller count, budget, currency, retries, planning summary, itinerary, booking details, validation results, plan JSON and final action. The graph executes Coordinator, Itinerary, Booking and Validation nodes followed by an evaluator. The Coordinator calculates duration, creates a budget allocation and can use Gemini to suggest a theme/strategy. The Itinerary Agent searches real active tours and produces a day-by-day schedule. It validates active IDs, daily item limits, prices and time overlaps. The Booking Agent calls backend hotel, room, room-availability, transport and transport-availability tools, filters real active inventory by capacity and availability, and chooses one room and one transport. The Validation Agent is deterministic: it checks numeric values, positive IDs, ISO dates, currency, totals, package structure and budget. LLM output is therefore a proposal input, not an authoritative booking command.

The graph has a deliberate one-retry design. A valid proposal ends with `AwaitingApproval`. If validation fails and the retry count is zero, the Coordinator applies a 15% economy adjustment and the graph returns to planning. If the second attempt fails, the pipeline ends as `Failed` with a failure reason. This prevents unbounded agent loops. The graph logs initialization, reasoning, tool calls, package assembly, validation and retry decisions using `logger.py`. Logs are sent to ASP.NET with the internal agent service header; access tokens are excluded from initial audit snapshots.

The most important architectural boundary is proposal persistence. Python direct-persistence helpers are disabled. Instead, the final proposal is sent to `AgentProposalPersistenceService` in ASP.NET. That service begins a serializable transaction, uses a PostgreSQL advisory transaction lock for the TripRequest, checks duplicate callbacks, verifies the TripRequest state and validates the proposal JSON. It reloads tours, rooms and transport options from PostgreSQL; checks active status, destination, dates, times, overlap, currency, room capacity, room availability, transport capacity and reported totals; recalculates the trusted commercial total; and rejects budget overrun. Only after these checks does it create an Itinerary, ItineraryItems, Booking and BookingItems. The TripRequest stores the plan and becomes `AwaitingApproval`. Duplicate non-cancelled/non-rejected proposals return the existing persisted result.

Human approval is intentionally outside the AI graph. React staff users access a pending approval queue and submit Approved, Rejected or RevisionRequested through a role-protected API. Approval is serializable and appends an immutable BookingApproval record. Approved changes the booking to Confirmed. Rejected changes it to Rejected. RevisionRequested records the comment, cancels the old booking, marks the old itinerary Discarded, resets the TripRequest to Planning and triggers a new planning run with feedback. This preserves the old decision history while allowing a new proposal. The AI cannot approve itself because the backend creates AwaitingApproval, approval endpoints require TravelAgent/Admin roles and payment is refused unless a booking is already Confirmed.

Payment is customer-accessible only after confirmation and is ownership-protected. PaymentService reloads the booking, checks Confirmed, creates a sandbox-style reference and stores Paid or Failed. A declined-token path demonstrates failure behavior. Staff can list payments and view total paid revenue, monthly revenue, counts and recent payments. Flutter provides checkout, booking status, confirmation, QR and PDF-ticket support through its booking screens and ticket service. React provides approval, payment/revenue, customer, notification, catalogue, inventory, itinerary and media management pages.

Security is implemented at multiple layers. Identity handles password storage and unique accounts. JWT bearer validation checks issuer, audience, lifetime and signature. Role attributes protect staff/admin operations. Claims-based ownership checks prevent customers from reading other customers’ bookings or payments. Agent callback routes use `X-Agent-Service-Key` with fixed-time comparison. The proposal service protects against fake IDs, inactive inventory, wrong destinations, invalid currencies, total manipulation, capacity exhaustion and overlaps. Database foreign keys, unique indexes, serializable transactions and advisory locks reinforce those rules. Prompt-injection tests demonstrate that hostile request text cannot disable deterministic budget, overlap or approval rules.

Testing spans backend, AI and Flutter. C# tests cover customer, trip request, tours, itineraries, hotels, transport, availability and bookings, plus authorization, agent triggers, proposal persistence, approval workflow and concurrent booking behavior. Python tests include golden itinerary cases, output-contract tests, no-inventory cases, real-ID preservation, retry/validation behavior, token redaction, payment gating and prompt-injection resistance. Flutter widget tests cover home, preferences, notifications, itinerary, requests, history and staged workflow behavior. The repository does not provide a reliable final execution total, so totals should be added only after the team runs and records the final suites.

The engineering decisions visible in the repository are consistent: shared ASP.NET business boundary; PostgreSQL and EF Core for relational integrity; React for staff operations; Flutter for cross-platform customer/device UX; four specialized LangGraph agents; server-owned proposal persistence; human approval before confirmation/payment; deterministic validation around LLM output; one bounded retry; status-based catalogue records; and serializable commercial transitions. The resulting system is best described as a multi-client travel platform with an auditable agentic planning workflow, rather than a chatbot or an AI-only booking engine.
