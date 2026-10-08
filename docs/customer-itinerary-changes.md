# Customer hotel and transport changes

On My Itinerary, select **Edit** or **Change hotels or transport**. Each hotel stay and transport leg has its own dropdown. Choose alternatives, optionally add instructions, then select **Request changes**. The screen follows the agent workflow and loads the newest itinerary and matching booking when the revised proposal is ready.

Hotel choices are active rooms with sufficient capacity for the party and availability for the existing stay dates. Alternative hotels must be at most **15 km by road** from that stay's original hotel. Distances come from OSRM, including hotels in nearby destinations. The displayed price covers the complete stay in the trip currency.

Transport alternatives must have the same directed route, vehicle type and departure date as that booking leg, with enough available seats. Providers and departure times may differ. The displayed price covers all travellers. Final timetable feasibility is checked by the agents and backend.

## API

- `GET /api/itinerary/{id}/changes/options`: owned active booking's dated hotel and leg groups, current selections, and available alternatives.
- `POST /api/itinerary/{id}/changes`: authenticated customer submits changes. The server validates inventory IDs and membership in the relevant dropdown group, saves structured instructions, and triggers the existing agent pipeline.

Example request:

```json
{
  "notes": "Please use these hotel and transfer choices.",
  "hotels": [{ "bookingItemId": 101, "roomId": 21 }],
  "transports": [{ "bookingItemId": 102, "transportOptionId": 31 }]
}
```

Only changed items need to be sent. The backend pins all stays and transfers, retaining the other existing selections. Room pins include check-in and exclusive check-out dates; transport pins include leg indices. Notes go to the coordinator as revision feedback. This flow preserves selected journeys, destinations, trip dates and budget; it does not promise arbitrary changes to those fields from free-text notes.

## Persistence and failure behavior

The canonical `revision_request` is stored inside existing `TripRequest.PlanJson`; **no database migration is required**. It contains a unique request ID, source booking, baseline journeys, dated room choices and per-leg transport choices. Agent callback IDs must match the current request, preventing stale results from replacing a newer plan.

The original booking remains active during replanning. Its inventory is excluded when rechecking availability for its replacement. A successful proposal must preserve the journey set, use the requested rooms for every occupied night, use the exact requested transport IDs per leg, fit the budget and pass existing travel checks. The backend then atomically discards the original itinerary, cancels its booking and creates a revised proposal awaiting approval, preserving both versions for audit.

A failed revision restores the original trip status and retains its itinerary and booking, with a visible failure reason. Paid bookings or payments in progress require staff assistance. Approval decisions and new payments are blocked while a customer revision is pending.

Deploy the backend and agent service together before using the updated Flutter client. Existing `ROUTING_BASE_URL` configures OSRM; the default is `https://router.project-osrm.org`. Road-routing failures return a retryable error rather than approximating the 15 km limit.
