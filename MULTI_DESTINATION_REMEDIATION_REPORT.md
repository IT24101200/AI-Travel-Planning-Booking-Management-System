# Multi-Destination Remediation Report

## Root Cause

The first confirmed data-loss boundary was the Flutter submit payload in `mobile_flutter/lib/screens/profile/trip_request_screen.dart`.

The UI already tracked multiple selected names, but the request contained only:

```json
{"destinationId": 11}
```

The previous `_resolveDestinationId()` returned the first database ID parsed from the entire destination text. The ASP.NET DTO, `TripRequest` model, database schema, agent dispatch payload, FastAPI state, coordinator, itinerary search, and persistence validation were also singular, so later layers could not recover Colombo or Jaffna.

## Data Flow Before/After

| Boundary | Before | After |
| --- | --- | --- |
| Flutter selection | Set of names in UI | Ordered structured selections |
| Flutter JSON | `destinationId` only | `destinationId` plus `destinationIds` and `destinations[]` |
| ASP.NET create DTO | One nullable ID | Ordered list input with legacy singular field |
| TripRequest storage | One FK | Legacy primary FK plus `DestinationSelectionsJson` JSONB |
| Backend → AI | `destination_id`, `destination_name` | Legacy fields plus `destination_ids` and `requested_destinations[]` |
| FastAPI graph | One destination | One normalized ordered destination list in shared state |
| Catalogue search | One `search_tours()` call | One call per selected destination |
| Itinerary | Could contain only the first destination | Tour metadata includes destination ID/name and coverage is validated |
| Callback/PlanJson | No structured request list | `requested_destinations` and `destination_ids` are included |
| Persistence | Tour checked against one FK | Every tour must belong to a requested destination; multi-destination coverage is required |
| Flutter history | Mostly inferred from raw text | Structured destination names are rendered first, with raw-text fallback |

## Files Changed

- Flutter request contract and rendering:
  - `mobile_flutter/lib/screens/profile/trip_request_screen.dart`
  - `mobile_flutter/lib/screens/profile/trip_history_screen.dart`
  - `mobile_flutter/test/trip_request_screen_test.dart`
- ASP.NET contract, storage, dispatch, validation, and tests:
  - `backend/DTOs/TripRequestCreateDto.cs`
  - `backend/DTOs/TripRequestDto.cs`
  - `backend/DTOs/TripRequestDestinationDto.cs`
  - `backend/Models/TripRequest.cs`
  - `backend/Models/TripRequestDestinationSelection.cs`
  - `backend/Services/TripRequestService.cs`
  - `backend/Services/AgentProposalPersistenceService.cs`
  - `backend/Services/RevisionPlanningService.cs`
  - `backend/Controllers/AgentTriggerController.cs`
  - `backend/Controllers/TripRequestController.cs`
  - `backend/Data/AppDbContext.cs`
  - `backend/Migrations/20261007034736_AddTripRequestDestinations.cs`
  - `backend/Migrations/20261007034736_AddTripRequestDestinations.Designer.cs`
  - `backend/Migrations/AppDbContextModelSnapshot.cs`
  - `backend.Tests/TripRequestServiceTests.cs`
- Python AI contract and tests:
  - `agentic-ai/destination_contract.py`
  - `agentic-ai/main.py`
  - `agentic-ai/graph.py`
  - `agentic-ai/agents/coordinator_agent.py`
  - `agentic-ai/agents/itinerary_agent.py`
  - `agentic-ai/agents/validation_agent.py`
  - `agentic-ai/test_multi_destination.py`

No payment, authentication, or infrastructure implementation was changed.

## Coordinator Contract

The authoritative input is now:

```json
{
  "requested_destinations": [
    {"destination_id": 11, "destination_name": "Anuradhapura", "order": 0},
    {"destination_id": 22, "destination_name": "Colombo", "order": 1},
    {"destination_id": 33, "destination_name": "Jaffna", "order": 2}
  ]
}
```

The coordinator preserves the ordered records in graph state and `plan_summary`. Legacy `destination_id`/`destination_name` inputs normalize to a one-item list.

## Itinerary Search

`build_itinerary()` calls the catalogue once for each requested destination. Each returned tour is tagged with its authoritative destination ID/name. The deterministic fallback schedules destinations round-robin so inventory from one location cannot consume the entire trip before the other locations are considered.

If a multi-destination request has no active tours for one destination, the result is an explicit `ZERO_TOUR_DESTINATION` failure. A single destination retains the existing `NO_VALID_TOURS` behavior.

## Validation

Deterministic validation now rejects:

- invalid or non-positive destination IDs;
- duplicate destination selections;
- tours belonging to an unrequested destination;
- an itinerary missing any requested destination;
- a final backend proposal whose destination contract does not match the persisted TripRequest;
- a multi-destination package where the persisted tour set does not cover every requested destination.

The checks use IDs and catalogue metadata, not a joined display string.

## DB/API

Inspection found no existing junction table or multi-destination field. The existing singular `TripRequests.DestinationId` remains as the primary/legacy FK. The migration adds:

```text
TripRequests.DestinationSelectionsJson jsonb NULL
```

The JSONB value stores ordered `{ Id, Name, Order }` records. Unknown IDs are rejected before a TripRequest is saved. The API returns `DestinationIds`, `DestinationNames`, and `Destinations`, while retaining `DestinationId` and `DestinationName` for older clients.

The migration must be applied to the deployed database before enabling multi-destination production requests.

## Backward Compatibility

- Existing clients sending only `destinationId` continue to create a single-destination request.
- Existing rows with only the singular FK are read as one destination.
- Existing AI payloads with singular fields normalize to one destination.
- Existing single-destination itinerary and booking behavior remains supported.
- New callers should send `destinations[]` and `destinationIds`; the first ID is retained only for legacy consumers.

## Tests

Passed:

- `python -m pytest -q` — **35 passed**
- `dotnet test backend.Tests/backend.Tests.csproj --no-restore -c Release` — **139 passed**
- `flutter test` — **98 passed**
- `python -m compileall -q agentic-ai` — passed
- `git diff --check` — passed

The added regression coverage includes the exact three-destination case, missing Jaffna coverage, legacy single destination, unknown destination ID, zero-tour destination behavior, backend order/name persistence, and Flutter payload order.

Flutter analysis was attempted twice. The analyzer exited with an analysis-server JSON `FormatException` before source diagnostics were emitted. Flutter test compilation and execution passed; this is recorded as a tooling limitation rather than an analyzer pass.

## Exact E2E

Requested scenario:

```text
Destinations: Anuradhapura, Colombo, Jaffna
Duration: 6 days
Travellers: 2
Budget: 350000 LKR
```

The local deterministic cross-layer verification used destination IDs `11`, `22`, and `33` for those names.

| Checkpoint | Result |
| --- | --- |
| Flutter payload | `destinationIds = [11, 22, 33]`; structured names/order preserved |
| Backend create service | all three IDs validated and persisted; primary `DestinationId = 11` retained for compatibility |
| Persisted test row | `DestinationSelectionsJson` contained Anuradhapura → Colombo → Jaffna in order |
| AI catalogue calls | calls observed in order `[11, 22, 33]` |
| Itinerary output | one scheduled tour for each of 11, 22, and 33 |
| Missing-destination validator | a schedule without Jaffna was rejected |

The exact AI checkpoint passed as `test_exact_three_destinations_are_searched_and_scheduled_in_order`; the backend persistence checkpoint passed as `CreateAsync_MultipleDestinations_PreservesIdsNamesAndOrder`; the Flutter checkpoint passed as `TripRequestScreen submits every selected destination in order`.

## Limitations

This workspace did not have a local backend/AI HTTP listener or a configured local database/authentication environment. The configured backend agent URL points to the remote deployment, and no authenticated production request was sent. Therefore the evidence above is a local deterministic contract E2E, not a live authenticated HTTP E2E or production database write.

Lodging and transport availability remain selected from the primary destination because the existing inventory APIs are singular. The complete requested destination list is preserved through the booking state and final proposal, while destination-specific tour coverage is enforced. Extending hotels and transport to per-destination legs is a separate domain change.

## Final Status

**Remediated and regression-tested locally.** The first data-loss boundary is fixed, all selected destination IDs remain available through the backend/AI contracts, multi-destination itinerary coverage is fail-closed, single-destination behavior remains compatible, and the database migration is ready for controlled deployment.
