# Student D — Booking, Approval & Payments
### Implementation brief for an AI coding agent

You are helping build **one student's component** (Student D) of a 4-person university group project: an AI Travel Planning & Booking Management System. Read this entire document before writing or changing any code.

---

## 0. How to use this document

1. This repo is shared with three other students (A, B, C). **Only touch the files and folders listed under "Files you own" in Section 6.** Everything else is someone else's work — do not create, edit, or refactor it, even if it looks incomplete. If you need something from another component (e.g. a field on `Itinerary`), treat it as read-only and flag it instead of changing it yourself.
2. Before creating any file, check whether it already exists in the repo. If it does, read it fully and continue/extend the existing implementation rather than overwriting it.
3. Follow the exact table names, field names, and status values given in Section 3 — the whole team's database depends on this staying consistent.
4. If a task requires a new EF Core migration, **stop and ask the user first** — only one team member generates a migration per week, and it must be announced to the team. Do not run `dotnet ef migrations add` unprompted.
5. Work through Section 8 (Task List) in order. Each item has a checkbox — mark it done as you complete it.
6. Write the tests listed in Section 9 alongside the code they test, not as an afterthought.
7. If anything here is ambiguous, or you're unsure whether something belongs to Student D or another student, stop and ask rather than guessing.

---

## 1. Project context (read this once, for orientation)

**What the whole system does:** a customer describes a trip in plain language (destination, dates, budget, preferences). A four-agent AI pipeline plans a day-by-day itinerary, checks real hotel/transport availability, validates the total cost, and **pauses for a human travel agent's approval** before anything is booked or charged. Once approved, payment runs through Stripe Sandbox and the customer sees a confirmed booking with a QR ticket.

**Hard architectural rule:** React (staff) and Flutter (customer) never talk to each other, and never touch the database or the AI service directly. Everything goes through one shared ASP.NET Core API.

**Stack:** ASP.NET Core Web API (.NET) · PostgreSQL · Entity Framework Core · React (staff dashboard) · Flutter (customer app) · JWT Auth (ASP.NET Core Identity) · LangGraph (Python agents) · Stripe Sandbox.

**The four components (one student each):**

| Student | Component | Tables owned | Agent owned |
|---|---|---|---|
| A | Profile, Preferences, Notifications & Trip Requests | `Customer`, `Preference`, `Notification`, `TripRequest` | Coordinator / Planning |
| B | Tours & Itineraries | `Destination`, `Tour`, `Itinerary`, `ItineraryItem` | Itinerary / Domain Analysis |
| C | Accommodation & Transport | `Hotel`, `Room`, `TransportOption` | Booking / Tool-Use |
| **D (you)** | **Booking, Approval & Payments** | **`Booking`, `BookingItem`, `BookingApproval`, `Payment`, `TravelAgent`** | **Validation / Approval** |

**The agent pipeline (assembly line, one agent per student):**
```
TripRequest ──► Coordinator(A) ──► Itinerary(B) ──► Booking(C) ──► Validation(D)
                    ▲                                                   │
                    └──────────── one retry, reduced budget ────────────┤
                                                                          ▼
                                                    Booking = AwaitingApproval
                                                                          │
                                                    ⏸ HUMAN APPROVAL GATE (React)
                                                                          │
                                                 Confirmed ──► Payment ──► Notification
```
Your agent is last. Whatever it decides, the workflow **always stops and waits for a human** before a booking becomes real or money moves.

---

## 2. Your job, in one paragraph

You are the gatekeeper. You take the priced, availability-checked package that Student C's agent proposed, create a `Booking` record for it in `AwaitingApproval` status, and stop. A travel agent reviews it in your React dashboard (with the plain-English `AgentLog` trail alongside it) and approves, rejects, or requests a revision — permanently recorded in `BookingApproval`. Only after an **Approved** decision does payment run through Stripe Sandbox and the booking become `Confirmed`. The customer then sees their confirmed trip and a QR ticket in the Flutter app.

---

## 3. Database schema you own

Database is **PostgreSQL**, accessed through the shared `AppDbContext` (EF Core). Do not create a second `DbContext`. Add your `DbSet<>` properties to the existing shared file, in a clearly separated block, and coordinate the migration per the rule in Section 0.

### `Booking`
| Field | Type | Notes |
|---|---|---|
| Id | PK | |
| BookingReference | string, unique | Human-readable. This is the QR code payload. |
| CustomerId | FK → Customer | |
| ItineraryId | FK → Itinerary | 1:1 with Itinerary |
| Status | enum | `Draft \| AwaitingApproval \| Confirmed \| Rejected \| Cancelled \| Completed` — **sole source of commercial truth** |
| TotalCost | decimal | |
| Currency | string | |
| CreatedAt | datetime | |
| UpdatedAt | datetime | update on every status change |

### `BookingItem`
| Field | Type | Notes |
|---|---|---|
| Id | PK | |
| BookingId | FK → Booking | |
| ItemType | enum | `Tour \| Room \| Transport` |
| TourId / RoomId / TransportOptionId | nullable FKs | **exactly one** must be set, matching `ItemType` — validate this in code |
| CheckInDate / CheckOutDate | date, nullable | **required when ItemType = Room** |
| Quantity | int | |
| UnitPrice | decimal | |
| Subtotal | decimal | |

### `BookingApproval`
| Field | Type | Notes |
|---|---|---|
| Id | PK | |
| BookingId | FK → Booking | |
| TravelAgentId | FK → TravelAgent | |
| Decision | enum | `Approved \| Rejected \| RevisionRequested` |
| Comment | string | |
| DecidedAt | datetime | This table is your **human-in-the-loop evidence** — rows are permanent, never updated or deleted. |

### `Payment`
| Field | Type | Notes |
|---|---|---|
| Id | PK | |
| BookingId | FK → Booking | |
| Amount | decimal | |
| Currency | string | |
| Status | enum | `Pending \| Paid \| Failed \| Refunded` |
| StripeReference | string | |
| PaymentDate | datetime | |

### `TravelAgent` (extends Identity)
| Field | Type | Notes |
|---|---|---|
| Id | PK, FK → AspNetUsers | |
| FullName | string | |
| Department | string | |
| HireDate | date | |

### Tables you read but don't own (do not modify their schema)
- `AgentLog` (shared, cross-cutting) — Id, TripRequestId, AgentName, StepDescription, CreatedAt. Written by the Python agent service. You **display** this alongside bookings in the Approval Dashboard; you don't write to it from Student D's controllers.
- `Itinerary`, `ItineraryItem`, `Tour` (Student B) — referenced by FK, read-only.
- `Room`, `TransportOption` (Student C) — referenced by FK, read-only.
- `Customer` (Student A) — referenced by FK, read-only.

### Relationship map (your slice)
```
Itinerary ─1:1─ Booking
                   ├─1:N─ BookingItem ─N:1─ Tour / Room / TransportOption
                   ├─1:N─ Payment
                   └─1:N─ BookingApproval ─N:1─ TravelAgent
```

---

## 4. Non-negotiable business rules

These are what your part is graded on. Enforce every one of these **in code**, not just in the UI:

1. **Status can never skip `AwaitingApproval`.** Valid transitions only: `Draft → AwaitingApproval → Confirmed | Rejected | Cancelled`, and `Confirmed → Completed`. Reject any attempt to jump straight to `Confirmed`.
2. **Payment only fires after `Confirmed`.** The `initiate_payment()` tool/endpoint must check the booking's current status in the database and refuse if it isn't `Confirmed` — even if something upstream (including your own AI agent) asks it to run early. This guard is what the Week-8 prompt-injection test checks.
3. **Every status transition is timestamped** (`Booking.UpdatedAt`, `BookingApproval.DecidedAt`, `Payment.PaymentDate`).
4. **`BookingApproval` rows are permanent** — a full audit trail of every human decision, never edited or deleted.
5. **`BookingReference` must be unique** and generated before the Checkout screen needs it.
6. **`BookingItem` validation:** exactly one of `TourId`/`RoomId`/`TransportOptionId` set, matching `ItemType`; `CheckInDate`/`CheckOutDate` required only when `ItemType = Room`.
7. **Stripe Sandbox integration is deliberately simple:** synchronous success/fail response only — **no webhook, no idempotency key**. This is a stated simplification, not a bug; don't add complexity beyond it.
8. **Stripe keys** live only in `user-secrets` locally and GitHub Actions secrets in CI — **never** in `appsettings.json`. Confirm `.gitignore` covers this before the first commit that touches payments.
9. **Invoice generation is a stretch goal**, not required. If time is short, skip it — it must not block the required parts (approval gate, payment status correctness).

---

## 5. Your AI agent — Validation Agent (Agent 4 of 4)

- **Input:** the priced package proposed by Student C's Booking Agent (tours + room + transport, with total cost) plus the original `TripRequest` budget ceiling.
- **Behavior:** checks the total cost against budget and business rules. Regardless of outcome, it never books or charges anything on its own — it always stops for human approval.
  - If it fits: call `create_booking()` to create the `Booking` (status `AwaitingApproval`) and its `BookingItem` rows. Do **not** set status to `Confirmed` and do **not** call `initiate_payment()` at this stage.
  - If it doesn't fit: don't create a booking. Return a clear "doesn't fit" signal so Student A's Coordinator agent can retry once with a reduced budget (`TripRequest.RetryCount` 0→1). If it still fails, that's handled upstream by A with a `FailureReason` — not your responsibility to implement, just to return a clean signal.
- **Tools (both gated behind approval):**
  - `create_booking()` — may run once validation passes; always creates in `AwaitingApproval`, never `Confirmed`.
  - `initiate_payment()` — must internally re-check `Booking.Status == Confirmed` in the database before doing anything, and refuse otherwise. This guard must hold even under adversarial prompts (prompt-injection test).
- **Location:** `agentic-ai/agents/validation_agent.py`, wired into the shared pipeline via `agentic-ai/graph.py` (shared file — coordinate before editing).
- **Logging:** write a plain-English step to `AgentLog` after each meaningful action (e.g. `"Checked total cost (LKR 42,000) against budget (LKR 45,000) — within budget, booking created and awaiting approval."`). Use the shared `agentic-ai/logger.py`.

---

## 6. Files you own

```
backend/Controllers/
  BookingController.cs
  ApprovalController.cs
  PaymentController.cs

backend/Services/
  BookingService.cs
  ApprovalService.cs
  PaymentService.cs

backend/Models/            (Booking, BookingItem, BookingApproval, Payment, TravelAgent entities)
backend/DTOs/              (request/response DTOs for the above)

frontend-react/src/pages/bookings/
  ApprovalDashboard.jsx (or .tsx)
  PaymentsReport.jsx

frontend-react/src/services/
  bookingApi.js            (API calls for your pages)

mobile-flutter/lib/screens/booking/
  checkout_screen.dart
  booking_status_screen.dart
  trip_confirmation_screen.dart

agentic-ai/agents/validation_agent.py
agentic-ai/tools/           (create_booking / initiate_payment tool implementations, your files only)

backend.Tests/              (tests for your controllers/services — see Section 9)
```

**Shared files you may read but must coordinate before editing:**
`backend/Data/AppDbContext.cs`, `agentic-ai/graph.py`, `agentic-ai/logger.py`, `frontend-react/src/components/theme.css`, `frontend-react/src/App.jsx` (routing).

**Git branches:**
- `feature/d-booking-payments` — Component D, full stack (controllers, services, React, Flutter)
- `feature/d-validation-agent` — Validation agent + approval gate

Branch off `main`, commit regularly, open a PR, get 1 review, merge only after CI passes.

---

## 7. Screens to build

### React (staff, computer) — must use the shared theme

Import `frontend-react/src/components/theme.css` and use its CSS variables. Do not hardcode hex colors. Font is **Inter** only (24px/700 page titles, 16px/600 section headers, 14px/400 body, 12px/400 small labels).

**Status badge colors (pill shape, `border-radius: 9999px`, sentence case):**
| Status | Text color | Background |
|---|---|---|
| Confirmed / Approved / Paid | `#16A34A` | `#DCFCE7` |
| AwaitingApproval / Pending / RevisionRequested | `#D97706` | `#FEF3C7` |
| Rejected / Failed / Cancelled | `#DC2626` | `#FEE2E2` |

**Buttons:** Approve = primary blue (`#2563EB`, hover `#1D4ED8`), text white. Reject = white background, red border/text (`#DC2626`), destructive style. Cancel/Back = white, grey border (`#E5E7EB`). All buttons: `border-radius: 6px`, `padding: 8px 16px`, `font-weight: 600`.

**1. Booking Approval Dashboard**
- Table of pending bookings: customer, itinerary summary, total cost, requested date.
- Show the `AgentLog` trail (plain-English steps) alongside each entry, filtered by that booking's `TripRequestId`.
- Approve / Reject / Revise actions, each requiring a comment, writing to `BookingApproval`.
- Filter, sort, pagination.

**2. Payments & Revenue Report**
- Table: `BookingReference`, customer, amount, status.
- Summary cards (e.g. total revenue, pending payments, failed payments).
- Monthly revenue chart.

### Flutter (customer, phone)

**3. Checkout & Payment** — booking summary, cost breakdown, Stripe Sandbox test card form, loading/success/error states.

**4. Booking Status** — status timeline (`Draft → AwaitingApproval → Confirmed`). Once `Confirmed`, show a **QR ticket** encoding `BookingReference` *(this is your required mobile device feature)*.

**5. Trip Confirmation** — final itinerary summary, confirmation number, downloadable ticket.

---

## 8. Task list (work in this order)

**Phase 1 — Schema & skeleton**
- [ ] Confirm the 5 tables above (Booking, BookingItem, BookingApproval, Payment, TravelAgent) with the team against the shared `AppDbContext`.
- [ ] Add entity classes under `backend/Models/`.
- [ ] Add empty route stubs: `BookingController.cs`, `PaymentController.cs`, `ApprovalController.cs`.
- [ ] Coordinate and generate the migration (only if it's your week to do so).

**Phase 2 — Core backend logic**
- [ ] Implement the booking status transition guard in `BookingService` (Rule 1 in Section 4) — write the unit test for it immediately.
- [ ] Implement `ApprovalService` — Approve/Reject/RevisionRequested, writing immutable `BookingApproval` rows.
- [ ] Sign up for Stripe Sandbox, get test keys, store them in `user-secrets` (confirm `.gitignore`).
- [ ] Implement `PaymentService` calling Stripe Sandbox synchronously (no webhook, no idempotency key), enforcing Rule 2 (only after `Confirmed`).
- [ ] Wire `BookingItem` validation (Rule 6).

**Phase 3 — React**
- [ ] Import the shared `theme.css`; build Booking Approval Dashboard per spec, including the `AgentLog` trail.
- [ ] Build Payments & Revenue Report with summary cards and monthly chart.

**Phase 4 — Validation Agent**
- [ ] Build `validation_agent.py`: cost/rule check, `create_booking()` tool, `AgentLog` writes.
- [ ] Implement `initiate_payment()` with the internal `Confirmed`-status guard (Rule 2) — this must work even if called out of order.
- [ ] Wire into the shared `graph.py` pipeline after Student C's Booking Agent.

**Phase 5 — Flutter**
- [ ] Checkout & Payment screen with Stripe Sandbox test form and all three states (loading/success/error).
- [ ] Booking Status screen with the status timeline and QR ticket generation.
- [ ] Trip Confirmation screen.

**Phase 6 — Testing & hardening**
- [ ] All tests in Section 9 passing.
- [ ] Prompt-injection test against the Validation Agent (confirm `initiate_payment()` still refuses pre-`Confirmed`).
- [ ] Budget-too-low case returns a clean signal, not a crash.

**Phase 7 — Docs & wrap-up**
- [ ] Short ADR note on the simplified Stripe integration (no webhook/idempotency key) if the team is keeping an ADR log.
- [ ] Confirm invoice generation is dropped or clearly marked stretch-only if time is short.

---

## 9. Tests you must write

| Layer | What to test |
|---|---|
| Backend unit | Booking status transition guard rejects skipping `AwaitingApproval` |
| Backend integration | Controller + DB round-trip via `WebApplicationFactory`; role-based auth (a customer can't fetch another customer's booking — IDOR check) |
| React | Component tests (Vitest + RTL): Approval Dashboard renders the pending list; Approve button fires the correct API call |
| Flutter | Widget tests for Checkout screen; navigation between Checkout → Status → Confirmation |
| Agent evaluation | 3–5 golden-case trip requests with known expected outcomes; rule-based assertion that total ≤ budget; a **prompt-injection case** confirming the agent still enforces the approval gate; a budget-too-low case confirming a clean failure, not a crash |
| End-to-end | Full path: trip request → agents complete → booking `AwaitingApproval` → approved in React → Flutter shows `Confirmed` |
| Security | JWT tampering rejected on your endpoints; IDOR blocked |

---

## 10. Quick reference — what NOT to build

- No Stripe webhook, no idempotency key (deliberate simplification).
- Invoice generation is optional (stretch goal only).
- Don't touch other students' controllers, services, models, screens, or agents.
- Don't create a second `DbContext`.
- Don't let the Validation Agent set `Confirmed` or call `initiate_payment()` directly — only the approval flow, after a human decision, does that.
