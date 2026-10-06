# Phase 6 local demo guide

This guide uses the intended local architecture. It does not contain secrets
or demo passwords.

## Required local configuration

Copy `.env.example` to a local `.env` and fill in values locally. The required
values are:

- `DATABASE_URL` or `ConnectionStrings__Default`
- `JWT__KEY` (at least 32 characters)
- `STAFFSECRETCODE`
- `AGENT_SERVICE_URL`
- `AGENT_SERVICE_API_KEY` (the same value for ASP.NET and Python)
- `STRIPE_SECRET_KEY` (`sk_test_...` only)
- `GOOGLE_API_KEY_ITINERARY` or `GEMINI_API_KEY`, if live Gemini planning is enabled
- `ALLOWED_ORIGINS`
- `VITE_API_BASE_URL`

Flutter receives its API URL through `--dart-define=API_BASE_URL=...`. A
publishable Stripe key, if required by the client, must be `pk_test_...`; the
server-only `STRIPE_SECRET_KEY` must never be passed to Flutter.

## Checking hosted Python startup

Run this twice in PowerShell to compare the first response with the next one:

```powershell
curl.exe -sS --max-time 120 -w '\nHTTP %{http_code}; total %{time_total}s\n' https://ai-travel-planning-booking-management-focq.onrender.com/health
```

A slow first request followed by a fast healthy response suggests a cold start.
Confirm it in the Python service's Render logs by looking for startup messages
at the same time. Avoid calling the health endpoint while waiting for the service
to become idle, because those calls keep it active.

The ASP.NET backend waits up to 120 seconds for Python health checks and
asynchronous pipeline acceptance, and 180 seconds for synchronous planning.
Override these on the backend Render service with
`AgentService__ConnectionTimeoutSeconds` and `AgentService__PipelineTimeoutSeconds`.
Redeploy the backend after applying the code changes. Automatic trip dispatch
still happens in the background, so creating a trip does not wait for Python startup.

## Startup order

1. Start PostgreSQL and ensure the target database exists.
2. Apply migrations from the repository root:

   ```powershell
   dotnet ef database update --project backend
   ```

3. Start ASP.NET:

   ```powershell
   cd backend
   dotnet run --launch-profile http
   ```

   Backend: `http://localhost:5138`; health: `/health`; database health:
   `/dbhealth`; Swagger is available in Development.

4. Start FastAPI in a second terminal:

   ```powershell
   cd agentic-ai
   .\venv\Scripts\Activate.ps1
   uvicorn main:app --reload --port 8005
   ```

   FastAPI health: `http://localhost:8005/health`.

5. Start React in a third terminal:

   ```powershell
   cd frontend-react
   npm ci
   npm run dev
   ```

   React: normally `http://localhost:5173`.

6. Start Flutter in a fourth terminal after the Flutter SDK is healthy:

   ```powershell
   cd mobile_flutter
   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5138/api
   ```

   Use `http://localhost:5138/api` for Windows/web and `10.0.2.2` for an
   Android emulator. Use the host LAN address for a physical device.

## Demo data and payment

The backend seed initializer supplies catalog/demo records when the database
is empty. Review the seed output before a demonstration and use only clearly
synthetic local accounts. A real Stripe Test Mode key and Stripe test payment
method are required to prove the paid/ticket path; local fake payment IDs are
not evidence of a live payment.

The `/seed-db` endpoint is Development-only. It is not routed in production.
