# Member C: accommodation, transport and agent communication

Owner from `2026-AI-10.pdf`, page 1: **Rajapaksha R.D.C.N — IT24101460**.
This guide describes the current source, including changes after the PDF's
6 October 2026 revision. Ownership is the allocated responsibility, not a claim
that every line in a shared file was authored by one student.

## Follow one trip through the system

```mermaid
sequenceDiagram
    participant F as Flutter customer
    participant API as ASP.NET API
    participant A as Coordinator (A)
    participant B as Itinerary (B)
    participant C as Booking Agent (C)
    participant D as Validation (D)
    F->>API: Trip request: dates, destinations, starter, budget
    API->>A: Authenticated planning request through FastAPI/LangGraph
    A->>B: Shared state: target_budgets and trip constraints
    B->>API: Search real tours for every destination
    B->>C: Shared state: itinerary and route_destination_ids
    C->>API: Search hotels, rooms, transport and availability
    C->>D: Shared state: booking_details and adjusted itinerary
    D->>D: Recalculate price and validate constraints
    D->>A: validation_result: valid or failure code
    A->>API: Final callback: proposal or failure
    API->>API: Revalidate and persist proposal transactionally
    API-->>F: AwaitingApproval and itemized itinerary
    Note over API,F: Staff approval precedes payment; Python does not charge the customer.
```

The diagram's agent-to-agent arrows represent **LangGraph state updates**, not
HTTP calls or agents chatting with each other. `agentic-ai/graph.py` owns the
execution order. `TripPlanningState` lists the shared fields; a node returns a
dictionary whose values update those fields while other fields survive.
The graph runs preflight, A, B, C, D, then A's evaluator. A retry loops back to A.
Do not remove a field when an adapter rebuilds a request: that was the cause of
the starter-location failure fixed in commit `17221df`.

## Your Python code, in reading order

| File / function | What to learn |
| --- | --- |
| `agentic-ai/agents/booking_agent.py::booking_node` | Receives graph state and returns `booking_details`, status and the updated itinerary. |
| `build_booking_package` | Validates the route, queries inventory, chooses candidates and calculates a proposal. |
| `agentic-ai/tools/availability_tools.py` | Converts backend responses to candidate records; reads catalogue pages and checks dates/capacity. |
| `_inventory_map` | Executes independent read requests with at most four workers, preserving input order. It does not reserve anything. |
| `_compatible_timetables` | Discards impossible times and duplicate schedules, then generates chronological combinations. |
| `agentic-ai/route_planning.py::plan_overnights` | Fits journeys, transfers and overnight stays inside the date/time/budget constraints. |
| `agentic-ai/agents/validation_agent.py` | Member D independently checks C's result before it becomes a proposal. |
| `backend/Services/AgentProposalPersistenceService.cs` | Loads trusted database records and commits the validated proposal. |

### The decisions your agent makes

1. Confirm that destination IDs exist in the request and B supplied an itinerary.
   Every selected destination must occur in the route. An explicit starter must
   remain first even when there is airport pickup.
2. Fetch hotels and rooms. Capacity must accommodate the party, the room must be
   active, and geographic candidates need coordinates. Nearby/intermediate
   hotels may be outside the destination's city.
3. For geographic plans, delay room availability checking until actual check-in
   and check-out dates are known. Checking availability for the entire trip first
   would wrongly exclude a hotel that is available for its two-night segment.
4. Construct all required transport legs in the planned order. Airport pickup
   adds an airport-to-first-destination leg. Keep one real option for each leg.
5. Compare feasible timetables and overnight plans. The current package search
   ranks candidates by **road distance first, then accommodation/transport cost**.
   The search is bounded at 256 timetable combinations and reports the limit.
   This is not a guarantee of a globally best route across all possible inputs.
6. Recheck chosen stays and calculate prices from catalogue data. The model cannot
   invent an ID, change a price, or replace B's itinerary with a different one.
7. Return all `room_selections` and `transport_selections`. Singular
   `selected_room`/`selected_transport` fields support older one-stop packages;
   they must not be used to display only the first item of a multi-stop trip.

The geographic/multi-leg path uses deterministic search. A legacy single-location
path can ask an LLM to choose from available candidates and otherwise picks the
cheapest eligible options. The audit now identifies those execution modes.
An agent is a workflow role; it does not imply an LLM is called at every step.

### Work through the price by hand

For two travellers, one LKR 500 tour each, a room at LKR 3,000 for three nights,
and LKR 1,000 transport seats each:

`tour 500 × 2 + room 3,000 × 3 + transport 1,000 × 2 = LKR 12,000`.

Room cost is per room-night; transport/tour cost follows the current per-traveller
contract. `test_member_c_booking.py` checks this example even if the mocked model
claims a total of 1. For multiple stays and legs, sum each selection separately.

### Availability is not a reservation

`AvailabilityService` checks room overlap with
`existing.CheckInDate < requestedCheckOut && existing.CheckOutDate > requestedCheckIn`.
A stay ending on the next guest's check-in date does not overlap. Capacity reads
can become stale before a booking is saved, so the backend checks again under its
transaction and inventory-locking rules. Python's availability cache is scoped to
one request and must never serve as proof that inventory is reserved.

## Your Dart flow

| File | Role and boundary |
| --- | --- |
| `lib/screens/accommodation/accommodation_options_screen.dart` | Available hotel catalogue, map, published rate and separate paid Booked tab. |
| `lib/services/hotel_catalog_service.dart` | Finds a display rate from room data; this is not date-specific availability or a guaranteed price. |
| `lib/screens/accommodation/transport_options_screen.dart` | Loads one catalogue page at a time; private booking history is independent. Selecting transport leads to itinerary review. |
| `lib/services/api_service.dart` | Builds HTTP requests, attaches authentication to API requests, handles responses and resolves public image URLs. |
| `lib/services/trip_selection_service.dart` | In-memory selections and active booking context; does not write a reservation. |
| `lib/services/booked_inventory_service.dart` | Extracts every room/transport item from paid bookings for the Booked tabs. |
| `lib/utils/transport_leg_utils.dart` | Sorts legs by the server's leg index, keeping older unindexed items after indexed legs. |
| `lib/widgets/itinerary_change_dialog.dart` | Requests changes to an existing itinerary through the backend revision process. |
| `lib/widgets/trip_confirmation_details.dart` | Renders every persisted stay and transport leg after payment. |

The catalogue screens, planned itinerary and paid-booking screens represent
different lifecycle stages. Selecting a catalogue card does not immediately
change the AI's stored proposal. Review/request changes through the itinerary;
checkout uses the actual approved booking ID. A fallback ID such as `101` must
never be used to invent a checkout destination.

Physical-device images must resolve to a reachable public server. The catalogue
uses Supabase HTTPS URLs; those are valid even though the host differs from the
API host. `AppNetworkImage` never attaches the API bearer token to images.

## Practise for the demonstration

Run from the repository root:

```powershell
.\scripts\run-agent-tests.ps1 -Member C
```

Explain a valid package, an unavailable room, an invented model ID and a missing
transport leg. Show the actual test output and one runtime audit record. Be ready
to answer: Which stage chose it? Which rule justified it? Which real database ID
was used? Which stage can approve it? Which stage takes payment?

For Flutter:

```powershell
cd mobile_flutter
flutter test test/booked_inventory_pages_test.dart test/transport_pagination_test.dart test/services/hotel_catalog_service_test.dart test/transport_leg_utils_test.dart test/widgets/trip_confirmation_details_test.dart
```

Start with `test_member_c_booking.py`, then read `test_transport_multi_leg.py`,
`test_transport_timetables.py` and `test_starter_route_pipeline.py`. The last test
runs real graph nodes with external services mocked; it is integration-contract
evidence, not proof of live model or payment-provider execution.
