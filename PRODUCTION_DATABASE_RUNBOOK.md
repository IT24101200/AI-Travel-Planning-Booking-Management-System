# Production database runbook

The application must use the production PostgreSQL connection string as its database source of truth.

## Required environment configuration

- `SUPABASE_DB_CONNECTION`: PostgreSQL connection string used by the API.
- `SUPABASE_URL`: Supabase HTTP URL used only by Supabase integrations.
- `SUPABASE_SERVICE_ROLE_KEY`: server-side Supabase integration key where required.
- `SeedDatabaseOnStartup=false`: production must never seed automatically.
- `ApplyMigrationsOnStartup=false`: keep disabled by default; apply reviewed migrations through the deployment process.

The old `SUPERBASE_URL` spelling is not a supported database configuration key.

## Migration procedure

1. Back up the production database.
2. Review the generated EF migration in `backend/Migrations`.
3. Apply it from a controlled deployment job with `dotnet ef database update` or the approved equivalent.
4. Deploy the API only after the migration succeeds.
5. Confirm `/api/health` and `/api/dbhealth` from the deployed environment.

Do not enable automatic seeding to repair an empty table. If the database is empty, add approved records through the staff UI or an explicitly reviewed data-import process.

## Destination integrity checks

- Destination names are normalized and uniquely constrained case-insensitively.
- Invalid coordinates are rejected by the API.
- Delete requests with tour or hotel references return `409` and leave the destination intact.
- Counts shown in staff screens are database query results; unavailable counts are not replaced with estimates.
