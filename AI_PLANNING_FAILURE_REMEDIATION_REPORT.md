# AI PLANNING FAILURE REMEDIATION REPORT

## Scope

This remediation covers the Flutter → ASP.NET backend → FastAPI agent workflow, including trip-request dispatch, preference loading, agent status presentation, retry behavior, error safety, and regression coverage.

The referenced `SYSTEM_AUDIT_REPORT.md` and `FLUTTER_REMEDIATION_REPORT.md` were not present in this checkout. They had been removed by the earlier requested working-tree cleanup, so this report is based on the current source, tests, and deployed health checks.

## Root Cause

The main failure mode was an asynchronous acknowledgment being treated as if it represented completion of the full AI pipeline:

- The old ASP.NET create path dispatched the AI request through fire-and-forget work and used a 120-second connection budget. A missing or non-success acknowledgment could mark the trip request `Failed`, even though the AI service is designed to acknowledge quickly and continue in the background.
- The old proxy returned upstream response bodies and exception details directly and forwarded the caller's JWT to the AI service as `access_token`. That created an unnecessary cross-service authentication dependency and exposed implementation details to clients.
- FastAPI's graph exception path could rethrow without persisting a failed pipeline state or notifying the backend callback endpoint.
- The Flutter workflow card interpreted a pipeline-level failure as four stage failures even when no agent-stage logs existed.

The corrected flow treats the AI endpoint response as an acknowledgment only. The backend now waits up to 15 seconds for that acknowledgment, preserves accepted status such as HTTP 202, and lets the callback/log stream represent actual pipeline progress.

## Preference 404

No saved preference is a valid first-use state, not a server error. `PreferenceController` now returns HTTP 204 No Content when the user has no preference record. Flutter accepts 204 as a successful empty response and keeps generic, user-safe handling for other failures.

## RenderFlex Overflow

The overflow was in `mobile_flutter/lib/widgets/agent_workflow_card.dart`, where the card header and agent rows placed long labels, roles, status text, and the agent-count badge in constrained horizontal rows. The card now uses `Expanded`/`Flexible`, bounded text lines, and ellipsis overflow handling. The header and agent rows have narrow-screen widget coverage.

## False Agent Status

The card now distinguishes these states:

- A pipeline dispatch failure with no stage logs renders agents as `NOT STARTED`.
- An explicit failed stage log renders that individual stage as `FAILED`.
- Successful and in-progress logs continue to map to their existing visual states.

This prevents a transport/dispatch problem from falsely claiming that all four agents ran and failed.

## Retry and Idempotency

- A failed trip request can transition back to `Planning`; retry clears the prior failure reason and increments the retry count.
- A duplicate async trigger while the request is already `Planning` returns a conflict instead of starting another pipeline.
- Flutter exposes a guarded `Retry planning` action only for failed requests and disables it while the request is in flight.
- The trigger endpoint and AI callback paths use generic client-facing errors while retaining correlated server-side logging.

## Files Changed

Backend and tests:

- `backend/Controllers/AgentTriggerController.cs` — bounded async acknowledgment, safe errors, 202 preservation, retry/duplicate guards, and removal of JWT payload forwarding.
- `backend/Controllers/TripRequestController.cs` — awaited acknowledgment dispatch with the shorter connection timeout and safe failure handling.
- `backend/Controllers/PreferenceController.cs` — 204 for an absent preference.
- `backend/Services/AgentServiceTimeouts.cs`, `backend/appsettings.json` — acknowledgment timeout reduced from 120 seconds to 15 seconds.
- `backend/Services/RevisionPlanningService.cs` — removed AI-service JWT payload forwarding and aligned timeout/base-URL handling.
- `backend/Services/TripRequestService.cs` — clears failure state and permits failed-to-planning retry transition.
- `backend.Tests/AgentServiceTimeoutsTests.cs`, `backend.Tests/AgentTriggerControllerTests.cs`, `backend.Tests/PreferenceControllerTests.cs` — timeout, safe proxy response, accepted response, retry, and 204 coverage.

AI service and tests:

- `agentic-ai/main.py` — removes the access-token request field, returns HTTP 202 for background pipeline acknowledgment, uses safe errors, and disables development reload in the service entry point.
- `agentic-ai/graph.py` — persists safe failed-stage/pipeline state and reports callback success or rejection without leaking exception details.
- `agentic-ai/logger.py` — normalizes backend URLs so `/api/api` is not produced.
- `agentic-ai/test_pipeline_integration_contracts.py` — async 202, token-removal, and safe callback/exception contract coverage.

Flutter and tests:

- `mobile_flutter/lib/services/api_service.dart` — finite request timeouts, safe status/error mapping, 204 preference handling, agent trigger/retry API, and test seams for logs/tours.
- `mobile_flutter/lib/screens/booking/booking_status_screen.dart` — removed an unused import found during final static analysis.
- `mobile_flutter/lib/screens/profile/trip_request_screen.dart` — safe preference/submission messages.
- `mobile_flutter/lib/screens/tours/my_itinerary_screen.dart` — safe failure messages, retry action, and deterministic stream handling in tests.
- `mobile_flutter/lib/widgets/agent_workflow_card.dart` — corrected stage-state mapping and responsive layout.
- `mobile_flutter/test/services/api_service_workflow_test.dart` — 204 preference and accepted 202 trigger tests.
- `mobile_flutter/test/widgets/agent_workflow_card_test.dart` — narrow-width and false-all-failed regression tests.
- `mobile_flutter/test/my_itinerary_screen_test.dart`, `mobile_flutter/test/phase_one_regression_test.dart`, `mobile_flutter/test/trip_request_screen_test.dart` — deterministic API fixtures and workflow regressions.
- `mobile_flutter/macos/Flutter/GeneratedPluginRegistrant.swift`, `mobile_flutter/windows/flutter/generated_plugin_registrant.cc`, and `mobile_flutter/windows/flutter/generated_plugins.cmake` — regenerated platform plugin registration artifacts preserved from the Flutter verification/build.

## Verification

Passed:

- `python -m pytest -q` — 30 passed.
- `dotnet test backend.Tests/backend.Tests.csproj --no-restore` — 136 passed.
- `flutter test --reporter compact` — 97 passed.
- `flutter build apk --debug` — succeeded; output: `mobile_flutter/build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check` — passed.

Static analysis:

- Direct Dart analysis completed successfully with no errors and 21 style infos.
- `flutter analyze` itself crashed in the analyzer language-server transport with a `FormatException` while reading a truncated JSON message on this Windows workspace path; this was an analyzer tooling failure rather than a source diagnostic.

## Deployment Verification

Before local remediation changes were deployed, the following read-only checks were completed:

- AI service health endpoint returned HTTP 200 and reported healthy; Gemini configuration was present without printing secret values.
- Backend agent-proxy health endpoint returned HTTP 200.
- A safe diagnostic POST to the deployed `/run-pipeline-async` endpoint returned HTTP 200 in approximately 0.125 seconds, confirming network reachability and immediate acknowledgment of the deployed version.

The local fixes have not been deployed from this workspace. An authenticated end-to-end run through the deployed Flutter app, callback completion, and persisted itinerary was therefore not claimed as verified.

## Remaining Risks

- A staging credential set and authenticated end-to-end environment were not available for a full callback-to-itinerary verification.
- The legacy `agentic-ai/tools/validation_tools.py` helper still contains optional token support for its separate/deprecated helper path; the active pipeline request and backend dispatch paths no longer send `access_token`.
- The remediation requires deployment of the backend, AI service, and Flutter build before production users receive the changes.
- Existing generated/platform and working-tree changes were preserved; nothing was staged or committed by this remediation.
