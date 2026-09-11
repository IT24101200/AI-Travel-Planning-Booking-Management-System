# AI Travel Planning & Booking Management System
## SE3090 Assignment 1 — Complete Project Master Document

**Stack:** ASP.NET Core Web API (.NET) · PostgreSQL · Entity Framework Core · React (staff dashboard) · Flutter (customer app) · JWT Auth · LangGraph (Python agents) · Stripe Sandbox
**Team:** 4 students · **Components:** 4 · **Agents:** 4 · **Database tables:** 17

---

## Table of Contents
1. Project Overview
2. Team & Component Ownership
3. User Roles & Domain Scope
4. Database Schema
5. Screen-by-Screen Breakdown
6. Backend Functionality
7. Repository & VS Code Architecture
8. Branching Strategy
9. Agentic AI Design
10. User Workflow
11. 9-Week Timeline
12. Spec Alignment Check
13. Testing Plan
14. Third-Party Integration
15. Risk Register
16. Prioritized Action List

---

# 1. Project Overview

Customers describe the trip they want — destination, dates, budget, preferences. A four-agent AI workflow plans a day-by-day itinerary, checks real hotel and transport availability, validates the total cost against the customer's budget and the system's business rules, and **pauses for a travel agent's approval** before anything is booked or charged. Once approved, payment is processed through Stripe Sandbox and the customer sees their confirmed booking, complete with a QR ticket, back in the Flutter app.

The system satisfies the assignment's integration rule directly: React and Flutter never talk to each other, and never talk to the database or the AI service directly — everything routes through one shared ASP.NET Core API.

---

# 2. Team & Component Ownership

| Student | Component | Tables owned | Agent owned |
|---|---|---|---|
| **A** | Profile, Preferences, Notifications & Trip Requests | Customer, Preference, Notification, TripRequest | Coordinator / Planning |
| **B** | Tours & Itineraries | Destination, Tour, Itinerary, ItineraryItem | Itinerary / Domain Analysis |
| **C** | Accommodation & Transport | Hotel, Room, TransportOption | Booking / Tool-Use |
| **D** | Booking, Approval & Payments | Booking, BookingItem, BookingApproval, Payment, TravelAgent | Validation / Approval |

Each agent is tied to the component holding its data — this keeps each student's two pieces of work (component + agent) one coherent story to defend in the viva.

---

# 3. User Roles & Domain Scope

| Role | Responsibilities |
|---|---|
| **Customer** | Sets preferences, submits trip requests, reviews/pays for proposed bookings, tracks status |
| **Travel Agent** | Reviews AI-proposed bookings, approves/rejects/requests revisions, manages tours/hotels/transport |
| **Admin** | Identity role only — manages system-wide settings and travel agent accounts, no separate profile table |

**Domain complexity checklist (spec §4):**
- ✅ 3+ user roles with different permissions
- ✅ 4 major business components, one per student, with real relational data
- ✅ CRUD + status workflows + search/filter/sort/pagination + reporting, in every component
- ✅ Genuinely different purposes for React (staff/admin/approval) vs. Flutter (customer-facing/operational)
- ✅ One meaningful third-party integration (Stripe Sandbox)
- ✅ One complete cross-platform workflow (trip request → agents → approval → confirmed status)

---

# 4. Database Schema — 17 Tables

`Customer` and `TravelAgent` extend ASP.NET Core Identity (`AspNetUsers`/`AspNetRoles`) — authentication isn't duplicated here. **Admin is an Identity role only**, no profile table.

## 4.1 Identity-Linked

**`Customer`** — Id (PK, FK→AspNetUsers), FullName, Phone, JoinedAt, LastActiveAt
**`TravelAgent`** — Id (PK, FK→AspNetUsers), FullName, Department, HireDate

## 4.2 Component A — Profile, Preferences, Notifications & Trip Requests

**`Preference`** — Id (PK), CustomerId (FK, unique), BudgetMin, BudgetMax, Currency, PreferredActivities (text), DietaryNotes, AccessibilityNotes, UpdatedAt

**`Notification`** — Id (PK), CustomerId (FK), Channel (Email/SMS/InApp), MessageType, Content, Status (delivery: Pending/Sent/Failed), ReadAt (nullable — read state), SentAt

**`TripRequest`** — Id (PK), CustomerId (FK), DestinationId (FK, nullable), RawRequestText, StartDate, EndDate, TravellerCount, BudgetCeiling, Currency, Status (Pending/Planning/AwaitingApproval/Completed/Failed), **RetryCount** (int, default 0 — the Coordinator's one retry), **PlanJson** (text, nullable — the Coordinator Agent's structured plan, persisted per spec §9.1 "shared state"), FailureReason, CreatedAt

## 4.3 Component B — Tours & Itineraries

**`Destination`** — Id (PK), Name, Country, Description, ImageUrl, Latitude, Longitude

**`Tour`** — Id (PK), DestinationId (FK), Name, Category, Description, Price, Currency, DurationHours, DefaultStartTime, Latitude/Longitude (nullable), Status (Active/Inactive — soft delete), CreatedAt, UpdatedAt

**`Itinerary`** — Id (PK), CustomerId (FK), TripRequestId (FK), StartDate, EndDate, Status (Draft/Proposed/Accepted/Discarded), TotalEstimatedCost, Currency, CreatedAt

**`ItineraryItem`** — Id (PK), ItineraryId (FK), TourId (FK), DayNumber, SequenceOrder, StartTime, EndTime (enables overlap checking), PriceAtSelection (price snapshot)

## 4.4 Component C — Accommodation & Transport

**`Hotel`** — Id (PK), DestinationId (FK), Name, Address, Latitude, Longitude, StarRating, Status *(price lives on Room only — one source of truth)*

**`Room`** — Id (PK), HotelId (FK), RoomType, Capacity, TotalRooms, PricePerNight, Currency

**`TransportOption`** — Id (PK), Type (Flight/Bus/Car/Train), Provider, RouteFrom, RouteTo, DepartureTime, ArrivalTime, Capacity, Price, Currency, Status *(one row per dated departure — a stated, deliberate simplification)*

## 4.5 Component D — Booking, Approval & Payments

**`Booking`** — Id (PK), **BookingReference** (unique, human-readable — the QR payload), CustomerId (FK), ItineraryId (FK), Status (Draft/AwaitingApproval/Confirmed/Rejected/Cancelled/Completed — sole source of commercial truth), TotalCost, Currency, CreatedAt, UpdatedAt

**`BookingItem`** — Id (PK), BookingId (FK), ItemType (Tour/Room/Transport), TourId/RoomId/TransportOptionId (nullable FKs — exactly one set, matching ItemType), CheckInDate/CheckOutDate (required when ItemType=Room), Quantity, UnitPrice, Subtotal

**`BookingApproval`** — Id (PK), BookingId (FK), TravelAgentId (FK), Decision (Approved/Rejected/RevisionRequested), Comment, DecidedAt — **this is your human-in-the-loop evidence**

**`Payment`** — Id (PK), BookingId (FK), Amount, Currency, Status (Pending/Paid/Failed/Refunded), StripeReference, PaymentDate

## 4.6 Cross-Cutting

**`AgentLog`** — Id (PK), TripRequestId (FK), AgentName, StepDescription (plain-English sentence), **StepType** (Plan/ToolCall/Validation/Approval/Result), **ToolName** (nullable — which tool was called, e.g. `check_hotel_availability`), **InputJson** (nullable — what was sent into that step), **OutputJson** (nullable — what came back), **DurationMs** (nullable int — how long the step took), CreatedAt. Written directly by the Python agent service after each meaningful step. The plain-English `StepDescription` stays for the React dashboard's readable trail; the new structured columns satisfy spec §9.1's requirement to persist tool calls, timings and validation results, not just a human-readable log.

## 4.7 Relationship Map

```
AspNetUsers ─1:1─ Customer                 AspNetUsers ─1:1─ TravelAgent
                     │
                     ├─1:1─ Preference
                     ├─1:N─ Notification
                     └─1:N─ TripRequest
                              ├─1:N─ AgentLog
                              └─1:N─ Itinerary
                                        ├─1:N─ ItineraryItem ─N:1─ Tour
                                        └─1:1─ Booking
                                                 ├─1:N─ BookingItem ─N:1─ Tour/Room/TransportOption
                                                 ├─1:N─ Payment
                                                 └─1:N─ BookingApproval

Destination ─1:N─ Tour        Destination ─1:N─ Hotel ─1:N─ Room
```

---

# 5. Screen-by-Screen Breakdown

### Shared — Authentication (built together, Week 1)

**React — Login:** email/password form, validation, error state, redirects to role-appropriate dashboard on success
**Flutter — Login / Register / Logout:** login form, registration form (name, email, phone, password), secure JWT token storage (`flutter_secure_storage`), logout clears token and returns to login

*Owner: Student A drives this build since it's closest to the Customer/Profile component, but it ships as part of Week 1's shared scaffolding — everyone else's screens sit behind it. Required by spec §8 ("Registration, login, logout, secure token storage and protected screens") — it is not optional and not any one student's individual component.*

### Student A — Customer Profile, Preferences, Notifications, Trip Requests

**React — Customer Directory (staff-facing):** table (name, email, join date, total trips, last active), search/filter/sort/pagination, "view profile" action
**React — Notification Logs:** table (recipient, channel, message type, status, timestamp), filter by status/date, resend on failed entries

**Flutter — Profile & Preferences:** form (name, email, phone, budget range slider, preferred activity tags, dietary/accessibility notes), save with validation
**Flutter — Trip Request:** form (destination, start/end date, traveller count, budget, free-text preferences), "Plan my trip" → triggers agent workflow, loading/progress state
**Flutter — Notifications:** list with read/unread indicator, mark-all-read
**Flutter — Trip History:** trip cards with status badge (Planning/Awaiting Approval/Confirmed/Completed/Cancelled)

### Student B — Tours & Itineraries

**React — Tour Catalog Management:** table (name, destination, price, duration, category, status), add/edit/delete, image field, search/filter/sort/pagination
**React — Itinerary Review:** list of AI-drafted itineraries, day-by-day view, edit-before-release, approve/send-back

**Flutter — Tour Search & Browse:** search bar + filter chips (destination, dates, budget, category), tour cards, loading/empty/error states
**Flutter — Tour Details:** description, included activities, price breakdown, photo gallery, "add to itinerary"
**Flutter — My Itinerary:** day-by-day timeline, "request changes" (feeds back into the agent workflow)

### Student C — Accommodation & Transport

**React — Hotel & Vendor Management:** table (name, location, star rating, price/night via Room, room count, status), add/edit/delete, search/filter/sort/pagination
**React — Transport Fleet Management:** table (type, route, capacity, price, provider), add/edit/delete, filter by type/route

**Flutter — Accommodation Options:** hotel matches with price, rating, distance; select preferred
**Flutter — Transport Options:** transport choices with times/price; select preferred
**Flutter — Trip Map** *(device feature)*: interactive map pinning hotel + tour + transport locations for the selected itinerary

### Student D — Booking, Approval & Payments

**React — Booking Approval Dashboard:** pending bookings table (customer, itinerary summary, total cost, requested date), **AgentLog trail shown alongside each entry**, Approve/Reject/Revise with comment field, filter/sort/pagination
**React — Payments & Revenue Report:** payments table (BookingReference, customer, amount, status), summary cards, monthly revenue chart

**Flutter — Checkout & Payment:** booking summary, cost breakdown, Stripe sandbox card form, loading/success/error states
**Flutter — Booking Status:** status timeline (Draft→Awaiting Approval→Confirmed), **QR ticket** using `BookingReference` once confirmed *(device feature)*
**Flutter — Trip Confirmation:** final itinerary summary, confirmation number, downloadable ticket

---

# 6. Backend Functionality

**A — Profile, Preferences, Notifications & Trip Requests.** Validates preference values (budget, dates) before accepting a trip request. `TripRequest` is the workflow's entry point and tracks its own `RetryCount` and `FailureReason`. Notification endpoints log every delivery attempt for the audit trail and are where the third-party email/SMS calls live.

**B — Tours & Itineraries.** Owns the tour catalog and the logic that assembles multiple tours into a conflict-free day-by-day itinerary — no two items may overlap in `StartTime`/`EndTime` on the same day. Search supports destination/date/budget filtering with pagination.

**C — Accommodation & Transport.** Owns real inventory — room counts, transport capacity — with an availability check that counts existing overlapping bookings and subtracts from `TotalRooms`, wrapped in a database transaction to prevent two customers booking the last room simultaneously.

**D — Booking, Approval & Payments.** The gatekeeper. Status transitions are enforced in code — no booking may skip `AwaitingApproval`. Payment only fires after `Confirmed`. Every transition is timestamped for the audit trail, and `BookingApproval` rows are the permanent record of every human decision.

---

# 7. Repository & VS Code Architecture

```
your-repo/
├── backend/
│   ├── Controllers/
│   │   ├── CustomerController.cs, NotificationController.cs,
│   │   │   TripRequestController.cs                          → Student A
│   │   ├── TourController.cs, ItineraryController.cs         → Student B
│   │   ├── HotelController.cs, TransportController.cs        → Student C
│   │   └── BookingController.cs, ApprovalController.cs,
│   │       PaymentController.cs                               → Student D
│   ├── Models/                     → same grouping as Controllers
│   ├── DTOs/                       → per-component, same split
│   ├── Services/
│   │   ├── CustomerService.cs, NotificationService.cs,
│   │   │   TripRequestService.cs                              → Student A
│   │   ├── TourService.cs, ItineraryService.cs                → Student B
│   │   ├── HotelService.cs, TransportService.cs,
│   │   │   AvailabilityService.cs                              → Student C
│   │   └── BookingService.cs, ApprovalService.cs,
│   │       PaymentService.cs                                   → Student D
│   ├── Data/
│   │   ├── AppDbContext.cs         → shared
│   │   ├── Seed/DatabaseSeeder.cs  → shared
│   │   └── Migrations/
│   ├── Program.cs
│   └── backend.csproj
├── backend.Tests/                  → tests per component, see Section 13
├── frontend-react/src/
│   ├── pages/
│   │   ├── customers/ → A   ├── tours/ → B   ├── hotels/ → C   ├── bookings/ → D
│   ├── components/     → shared (Week 1)
│   ├── services/        → one API file per component
│   └── App.jsx          → shared routing + role guards
├── mobile-flutter/lib/
│   ├── screens/
│   │   ├── profile/ → A   ├── tours/ → B   ├── accommodation/ → C   ├── booking/ → D
│   ├── widgets/         → shared
│   └── services/
├── agentic-ai/
│   ├── agents/
│   │   ├── coordinator_agent.py → A   ├── itinerary_agent.py → B
│   │   ├── booking_agent.py → C        ├── validation_agent.py → D
│   ├── tools/           → one file per agent, same ownership
│   ├── logger.py        → shared — writes AgentLog rows
│   └── graph.py         → shared — wires all 4 agents together
├── docs/
│   ├── adr/    ├── diagrams/    └── api/
├── .github/workflows/backend-ci.yml
├── .gitignore     ⚠️ set up before the first commit
└── README.md
```

---

# 8. Branching Strategy

| Branch | Purpose | Owner |
|---|---|---|
| `main` | Protected — PR + 1 review + passing CI required | Whole team |
| `feature/shared-setup` | Week 1: scaffolding, Identity, `AppDbContext`, CI, shared components | Whole team |
| `feature/a-customer-profile` | Component A, full stack | Student A |
| `feature/a-coordinator-agent` | Coordinator agent + retry logic | Student A |
| `feature/b-tour-catalog` | Component B, full stack | Student B |
| `feature/b-itinerary-agent` | Itinerary agent + tour search tool | Student B |
| `feature/c-hotel-transport` | Component C, full stack | Student C |
| `feature/c-trip-map` | Isolated — most likely to break | Student C |
| `feature/c-booking-agent` | Booking agent + availability tools | Student C |
| `feature/d-booking-payments` | Component D, full stack | Student D |
| `feature/d-validation-agent` | Validation agent + approval gate | Student D |

**Lifecycle:** branch off `main` → commit regularly → PR → 1 review → merge → CI runs → branch deleted. **One shared rule:** only one person generates a migration per week, announced first — the most common way small teams lose a weekend to conflicts.

---

# 9. Agentic AI Design

**Agent 1 — Coordinator / Planning (A).** Receives `TripRequest`, builds a structured plan, delegates to Agent 2. If Agent 4 reports the package doesn't fit budget, retries **once** with a reduced ceiling (`RetryCount` 0→1); if it still fails, stops with a clear `FailureReason`. No tools — its output is a routing decision, which is what makes it a real agent rather than a fixed pipeline.

**Agent 2 — Itinerary / Domain Analysis (B).** Builds a conflict-free day-by-day itinerary. Tool: `search_tours(destination, dateRange, budget)` — read-only, allow-listed.

**Agent 3 — Booking / Tool-Use (C).** Checks real room and transport availability for the exact dates, never invents an option. Tools: `check_hotel_availability(...)`, `check_transport_availability(...)`.

**Agent 4 — Validation / Approval (D).** Checks total cost + availability, and — regardless of outcome — **stops for human approval** before anything is booked. Tools: `create_booking()`, `initiate_payment()`, both gated behind approval.

```
TripRequest ──► Coordinator ──► Itinerary ──► Booking ──► Validation
                    ▲                                          │
                    └──────── one retry, reduced budget ───────┤
                                                                 ▼
                                                Booking = AwaitingApproval
                                                                 │
                                                 ⏸ HUMAN APPROVAL GATE
                                                                 │
                                              Confirmed ──► Payment ──► Notification
```

*Note: login/auth happens before any of this — every endpoint in this chain is JWT-protected and only runs for an authenticated Customer.*

## 9.1 Agent Input/Output Contracts

Each agent's contract is owned by the student who owns that agent — this table is what gets defended at the viva when asked "what exactly does your agent receive and return?"

| Agent | Owner | Input | Output |
|---|---|---|---|
| Coordinator / Planning | A | `TripRequest` (destination, dates, budget, traveller count, preferences) | Structured plan (ordered steps) + delegation instruction to Itinerary Agent, saved to `TripRequest.PlanJson` |
| Itinerary / Domain Analysis | B | Plan + destination/dates/budget/preferences | Day-by-day itinerary, no overlapping `StartTime`/`EndTime` on any day |
| Booking / Tool-Use | C | Draft itinerary | Priced package with confirmed room + transport availability for the exact dates |
| Validation / Approval | D | Priced package + `Preference.BudgetMax` | Pass → `Booking` created as `AwaitingApproval`. Fail → routed back to Coordinator for the one retry, or `TripRequest.FailureReason` set |

## 9.2 Deterministic Validation Checklist

Collected in one place — owned by **Student D**, but each rule is supplied by the component that owns the data it checks:

| Rule | Checked by (component) |
|---|---|
| No two itinerary items overlap in time on the same day | B |
| Room count and transport capacity not exceeded for the dates | C |
| Total package cost ≤ customer's `BudgetMax` | D |
| Referenced tours/hotels/transport are `Active` (not soft-deleted) | B, C |
| Agent output matches the required JSON structure before it's accepted | D |

If every check passes, the booking moves to `AwaitingApproval`. If any check fails, the Coordinator gets one retry with a reduced budget ceiling before `TripRequest.Status` becomes `Failed` with a `FailureReason`.

## 9.3 Worked Example (for the report and viva)

*"Plan a 5-day trip to Kandy for 2 travellers, budget LKR 150,000, starting 10 September."*

1. **Flutter submission** — customer logs in, fills the Trip Request form, submits.
2. **ASP.NET Core** — validates JWT, customer role, dates and budget; saves `TripRequest`.
3. **Coordinator Agent (A)** — builds the plan: retrieve destination → search tours → check availability → calculate cost → validate → request approval. Saves plan to `PlanJson`.
4. **Itinerary Agent (B)** — searches Kandy tours matching the budget, assembles a 5-day, conflict-free schedule.
5. **Booking Agent (C)** — checks real hotel room and transport availability for 10–15 September, prices the package.
6. **Validation Agent (D)** — runs the checklist in §9.2. If total > LKR 150,000, Coordinator retries once with a lower ceiling.
7. **Human approval** — booking becomes `AwaitingApproval`; travel agent reviews in React alongside the `AgentLog` trail, approves.
8. **Final execution** — `Booking.Status` → `Confirmed`, Stripe Sandbox charges the customer, `Payment` row created.
9. **Flutter status update** — customer sees `Confirmed` and a QR ticket showing their `BookingReference`.

---

# 10. User Workflow

A customer registers or logs in through the Flutter app, with a JWT issued and stored securely on the device. Once authenticated, they set their travel preferences, and submit a trip request describing their destination, dates, traveller count, and budget. The request is saved as a `TripRequest` and handed to the Agentic AI subsystem. The Coordinator Agent reads the objective and builds a structured plan, delegating the itinerary step to the Itinerary Agent, which searches the tour catalog and builds a day-by-day schedule with no overlapping time slots, matching the customer's preferences. That draft passes to the Booking Agent, which checks real room and transport availability for the exact dates and proposes a concrete, priced package. The Validation Agent checks the total against the budget and business rules; if it doesn't fit, the Coordinator tries once more with a reduced budget before stopping with a clear explanation. When a package passes, the booking is created in Awaiting Approval status and the workflow halts — nothing is booked or charged until a person acts. A travel agent reviews the proposal in the React dashboard, alongside a plain-language log of what each agent did, and approves, rejects, or requests a revision with a comment, permanently recorded. On approval, the booking moves to Confirmed, payment is processed through Stripe Sandbox, an invoice is generated, and the customer is notified. The customer sees the update immediately in the Flutter app — status changes to Confirmed and a QR ticket appears showing their booking reference. Every major step is written to a log tied to the original trip request, so any booking can be traced back to the reasoning that produced it.

---

# 11. 9-Week Timeline

**Order: Backend → React → Flutter, with agent work starting week 5 so it isn't left to the end.**

| Week | Student A | Student B | Student C | Student D |
|---|---|---|---|---|
| **W1** 31 Jul–6 Aug | Draft TripRequest/Customer schema, user stories | Draft Tour/Itinerary schema, user stories | Draft Hotel/Transport schema, user stories | Draft Booking/Payment schema, research Stripe Sandbox |
| *Deliverable* | Repo live · ER diagram v1 · shared scaffolding merged to `main` · CI running |
| **W2** 7–13 Aug | TripRequestController, CustomerController skeleton | TourController, ItineraryController skeleton | HotelController, TransportController skeleton | BookingController, PaymentController skeleton |
| *Deliverable* | Auth working · migrations applied · 4 skeleton APIs · CI green |
| **W3** 14–20 Aug | Trip request submission logic, preference validation | Itinerary conflict-checking, tour search/filter/pagination | AvailabilityService (room+dates), concurrency transaction | Booking status workflow, Stripe Sandbox call integration |
| *Deliverable* | Backend functionally complete for all 4 components, tested, Swagger live |
| **W4** 21–27 Aug | React — Customer Directory, Notification Logs | React — Tour Catalog, Itinerary Review | React — Hotel & Vendor Mgmt, Transport Fleet | React — Booking Approval Dashboard, Payments Report |
| *Deliverable* | React shell live with auth + protected routes |
| **W5** 28 Aug–3 Sep | Finish React; **start Coordinator Agent** | Finish React; **start Itinerary Agent** | Finish React; **start Booking Agent** | Finish React; **start Validation Agent** |
| *Deliverable* | React fully functional, tested, deployed to staging · all 4 agents scaffolded |
| **W6** 4–10 Sep | Flutter — Trip Request, Profile screens; continue Coordinator | Flutter — Tour Search, Tour Details; continue Itinerary Agent | Flutter — Accommodation, Transport Options; continue Booking Agent | Flutter — Checkout screen; continue Validation Agent |
| *Deliverable* | Flutter shell working with auth · agents advancing individually |
| **W7** 11–17 Sep | Finish Notifications, Trip History | Finish My Itinerary | Finish Trip Map (device feature) | Finish Booking Status, QR Confirmation |
| *Deliverable* | Flutter complete · all 4 agents wired into one workflow with the retry + approval gate working end-to-end |
| **W8** 18–24 Sep | Performance testing (k6) on trip-request endpoints | Agent evaluation — itinerary golden cases | Agent evaluation — availability golden cases + concurrency test | Agent evaluation — validation/approval enforcement, prompt-injection test |
| *Deliverable* | Full cross-platform workflow verified · everything deployed · Flutter APK built |
| **W9** 25–30 Sep | Individual report + AI log + reflection + viva prep | Same, for Component B | Same, for Component C | Same, for Component D |
| *Deliverable* | Consolidated PDF · demo video (with cached fallback run) · links checked in incognito · submitted by group leader |

---

# 12. Spec Alignment Check

| § | Requirement | Covered where |
|---|---|---|
| §1 | One shared API/DB across React & Flutter | Enforced by design from W2 onward |
| §2 | Mandatory tech stack | Throughout |
| §3 | 4 components, 1 owner each, distinct agent per student | Section 2 |
| §4 | 3+ roles, 4 components, CRUD+workflows, distinct client purposes, 1 third-party, 1 cross-platform workflow | Section 3 |
| §5 | Secure ASP.NET Core backend | W2–W3 |
| §6 | PostgreSQL, normalized, migrations | Section 4, W1–W2 |
| §7 | React app | W4–W5 |
| §8 | Flutter app + device feature | W6–W7 (QR ticket + Trip Map) |
| §9 | 4 distinct agents, plan/delegate/tools/validate/approve | Section 9, W5–W7 |
| §10 | Required cross-platform workflow pattern | Section 10, W7–W8 |
| §11 | Third-party integration | Section 14, W3 |
| §12 | Testing across all layers + agent evaluation | Section 13 |
| §13 | Git, GitHub Actions CI | Section 8, W1 onward |
| §14 | Deployment, README, ADR | W1 (ADR start) → W5 (React live) → W8 (full deploy) → W9 (finalize) |
| §15 | Submission format, single PDF | W9 |
| §17 | Demo + viva readiness | W9, cached fallback run |
| §18 | AI usage disclosure & logging | Logged continuously, declared W9 |

---

# 13. Testing Plan

| Layer | What to test |
|---|---|
| **Backend unit** | Preference/TripRequest validation (A) · itinerary time-conflict rejection (B) · `AvailabilityService` room-count math (C) · booking status transition guard rejects skipping `AwaitingApproval` (D) |
| **Backend integration** | Controller + DB round-trip per component via `WebApplicationFactory`; role-based authorization (customer can't fetch another customer's data — IDOR check) |
| **Concurrency** | Fire two simultaneous booking requests at the last available room; confirm exactly one succeeds |
| **Database** | Migrations apply cleanly; FK violations rejected; `BookingReference` uniqueness enforced |
| **React** | Component tests (Vitest + RTL) for Booking Approval Dashboard (renders pending list, Approve button fires the right call); protected-route redirect; form validation |
| **Flutter** | Widget tests for the Trip Request form; navigation tests; mocked API integration tests |
| **End-to-end** | One scripted Postman/Newman run covering the full path: submit trip request → agents complete → booking Awaiting Approval → staff approves in React → Flutter shows Confirmed |
| **Performance** | k6 script against `/api/trip-requests` and `/api/hotels/availability` under concurrent load — response time, success rate |
| **Agent evaluation** | 3–5 golden-case trip requests with known expected outcomes; rule-based assertions (total ≤ budget, no time overlaps, referenced tours/hotels are `Active`); a prompt-injection case confirming the Validation Agent still enforces rules; a budget-too-low case confirming the retry then a clean `FailureReason`, not a crash |
| **Security** | JWT tampering rejected; IDOR attempts blocked on every personal-data endpoint |

**Agent evaluation rule to remember:** LLM-as-judge can support your evidence, but the rule-based assertions above must be the primary method — not the only one.

---

# 14. Third-Party Integration

**Stripe Sandbox** for payment processing — central to Component D, not a bolt-on. Called directly from the backend for a synchronous success/fail response; **no webhook, no idempotency key** (a stated, deliberate simplification — mention it in your ADR if asked). Keys live in user-secrets locally and GitHub secrets in CI, never in `appsettings.json`.

---

# 15. Risk Register

| Risk | Severity | Mitigation |
|---|---|---|
| Team still building Git/VS Code comfort while learning 4 new technologies | High | Week 1 is shared scaffolding only, done together |
| Academic workload alongside a 9-week project | High | Scope in this document exists specifically to protect against this |
| Stripe keys committed to source | Medium | `.gitignore` set up before the first commit |
| Live LLM calls failing during the demo | Medium | Keep a cached known-good run as a fallback |
| Student D carries booking + approval + payments | Medium | Invoice generation can drop to a stretch goal without losing required marks if time runs short |

---

# 16. Prioritized Action List

**Week 1, together, before any solo coding:**
1. Scaffold all four projects, get Identity/JWT auth working
2. Create the shared `AppDbContext`, agree the schema in Section 4 as a team
3. Confirm `RoomId`/`CheckInDate`/`CheckOutDate` on `BookingItem` and lat/lng on `Destination`/`Hotel` — both are hard blockers if missed
4. Set up `.gitignore` **before** the first commit

**Weeks 2–7, per component, in the order shown in Section 11:**
5. Backend → React → Flutter → agent, in that sequence, for each component
6. `AgentLog` writing wired up as soon as the first agent exists
7. `BookingReference` generation ready before the Checkout screen needs it
8. The Coordinator's one-retry logic — this is what makes it a real agent, not just a pipeline

**Weeks 8–9:**
9. The concurrency test on the last-room scenario
10. Database seeder populated with enough demo data for a clean walkthrough
11. ADRs written for: the flat transport model, the one-retry decision, the simplified Stripe integration, the soft-delete strategy, **the React state-management choice, the Flutter state-management choice, and the cloud deployment platform** (spec §14.2 requires these explicitly — don't skip them)
12. Demo rehearsed with a cached agent run as a fallback in case live AI calls fail on the day
