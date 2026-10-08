# Demo travel catalogue importer

This is an explicit, isolated importer for the Sri Lankan demo catalogue. It
is not called by ASP.NET startup and does not use the destructive application
seed/reset endpoints.

```powershell
# Read-only planning is the default.
dotnet run --project tools/DemoTravelCatalogueImporter/DemoTravelCatalogueImporter.csproj

# Writes require both an approved target classification and this explicit flag.
dotnet run --project tools/DemoTravelCatalogueImporter/DemoTravelCatalogueImporter.csproj -- --apply
```

The importer reads `backend/.env` without printing credential values. It uses
`SUPABASE_DB_CONNECTION` first, then `DATABASE_URL`. An apply requires both
`DEMO_CATALOGUE_ENVIRONMENT=DEMO|DEVELOPMENT|TEST` and
`DEMO_CATALOGUE_WRITE_ENABLED=true`. Missing or conflicting settings remain
blocked. Any authoritative production/shared signal always wins and is
reported as an environment conflict.

The project-safe sample defaults are `UNKNOWN` and `false`. Set the real local
values only after independently confirming that the configured database is a
dedicated demo/development/test target. Never commit `backend/.env` or real
credentials.

The catalogue data is deliberately conservative. Hotel identity sources are
recorded, but a hotel is not import-ready until its latitude and longitude
have been rechecked from a point-level source. Missing phone/email values stay
null. Prices, inventory, transport schedules, durations, fares, and capacities
are demo operational values.

## Transport coverage policy

Transport coverage is generated for every ordered pair of current selectable
destinations with valid coordinates. Each pair receives one local 07:00
departure every day from `BusinessClock.Today + 1` through `+60`, using the
exact canonical destination names. The importer does not claim these rows are
live public timetables or bookable provider inventory.

The deterministic demo private-transfer model is:

* road distance = Haversine distance × 1.30 road factor;
* duration = road distance ÷ 45 km/h, rounded up to a 30-minute block;
* fare = ceil((LKR 2,500 + road distance × LKR 35) / LKR 500) × LKR 500;
* capacity = 8 seats, classified as demo capacity.

This model intentionally uses real destination identities and stored verified
coordinates while clearly classifying generated schedules, fares, durations,
and capacity as demo operational data.
