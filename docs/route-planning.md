# Route and overnight planning

New geographic plans complete a destination's selected journeys before moving
to the next destination. Destination order minimizes the open road path through
representative attraction coordinates (exact search through nine destinations;
nearest-neighbour ordering above nine). Airport pickup anchors the start at CMB
or HRI. There is no automatic return to the first destination or airport drop-off.

The overnight planner searches available rooms for each night, including hotels
outside the selected cities. It covers every trip night with dated stays and
requires overnight hotel coverage for each destination. A hotel can serve local
visits within 50 km by road. A midpoint hotel can serve successive destinations
within 70 km on each side when the detour is no greater than 1.25 times their
direct road distance plus 10 km. Nearby destinations may therefore share a hotel;
distant destinations receive separate stays. Transfer-only days can use an
intermediate hotel when the inventory and transport timetable allow it.

Each day runs from 08:00 to 18:00 with at most six driving hours, up to two
journeys, 20 minutes of breaks per two driving hours and a 45-minute meal/rest
allowance after a journey. Tour durations and preferred earliest start times are
preserved. Pickup allows one hour after the supplied airport arrival time.
Booked transfers are mandatory events: visits, hotel moves and road travel must
fit their departure and arrival times. A fixed transfer spanning multiple days
cannot currently be split into independently bookable overnight legs.

The search prioritizes shorter travel, balances daily driving effort within
roughly 10 km of distance, and considers actual nightly room and per-person
transport/tour prices against the complete budget. Missing inventory, infeasible
timetables, insufficient travel days or insufficient budget produce an explicit
agent failure rather than an incomplete booking. Rooms must fit the whole party;
splitting a party across several rooms is not supported by this planner.

OSRM supplies road distances, driving times and map geometry. Public attraction,
hotel and selected airport coordinates are sent to the configured service.
`ROUTING_BASE_URL` defaults to `https://router.project-osrm.org` in the agent;
Flutter uses the same default and accepts `--dart-define=ROUTING_BASE_URL=...`.
Routing failures stop planning; straight-line estimates do not approve a trip.
The table supports at most 100 distinct coordinates, the overnight search at
most 20,000 labels and transport selection at most 256 timetable combinations.
Exceeding a limit gives an explicit planning error.

The itinerary and full-route maps show all routes and destination pins in blue
(`#2563A6`) and the selected day's complete travel in light red (`#FCA5A5`),
including hotel changes. Selecting an already visible day's route preserves the
camera; an offscreen selection fits the route without zooming further in.
Transfer-only days appear in the timeline. All booked hotels are listed.

## Release steps

1. Deploy the backend with migration `20261008205014_AddAirportPickupPlanning`.
   Apply EF migrations through the existing deployment procedure before using
   the new endpoints. The backend also supports `ApplyMigrationsOnStartup=true`.
2. Deploy the agent with the updated requirements and routing module.
3. Rebuild/restart Flutter against that backend.
4. Submit a new plan to generate the optimized schedule. Stored itineraries are
   not rewritten; older plans without daily travel metadata retain their legacy
   map behavior.

Local source changes do not update an already deployed backend or agent.

## Focused verification

- `agentic-ai`: `python -m pytest test_route_planning.py test_multi_destination.py test_transport_multi_leg.py test_booking_totals.py test_validation_agent.py test_pipeline_integration_contracts.py -q`
- Backend: `dotnet test backend.Tests/backend.Tests.csproj --filter "AgentProposalPersistenceTests|TripRequestServiceTests|TransportLifecycleTests|TransportVisibilityTests"`
- `mobile_flutter`: `flutter test test/widgets/itinerary_route_preview_test.dart test/my_itinerary_screen_test.dart test/trip_request_screen_test.dart test/services/itinerary_route_service_test.dart`
