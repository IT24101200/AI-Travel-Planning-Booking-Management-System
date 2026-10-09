# AI usage and repository review evidence

Review date: **10 October 2026 (Asia/Colombo)**.
Baseline: commit `17221df`; this report describes the subsequent working-tree
changes. Source brief: user-provided `2026-AI-10.pdf`, revised 6 October 2026,
especially pages 1, 42–44 and 48. The original PDF was not modified.

## Four-member responsibility and Python tests

| Member | Name from the PDF | Registration | Agent responsibility | Dedicated test file |
| --- | --- | --- | --- | --- |
| A | Wickramasinghe H.M.D.A | IT24101200 | Coordinator, budget and retry | `agentic-ai/test_member_a_coordinator.py` |
| B | Bandara K.M.P.S | IT24100421 | Destinations and itinerary | `agentic-ai/test_member_b_itinerary.py` |
| C | Rajapaksha R.D.C.N | IT24101460 | Hotels, transport and Booking Agent | `agentic-ai/test_member_c_booking.py` |
| D | Ranasinghe K.H | IT24100120 | Validation and approval boundary | `agentic-ai/test_member_d_validation.py` |

The new files provide focused executable tests. Existing larger regression suites
remain in place and the member runner includes relevant ones. Allocated ownership
does not establish exclusive code authorship or personal use of an AI tool.

```powershell
# First-time test dependencies, from repository root:
.\agentic-ai\venv\Scripts\python.exe -m pip install -r agentic-ai/requirements-dev.txt
.\scripts\run-agent-tests.ps1 -Member A
.\scripts\run-agent-tests.ps1 -Member B
.\scripts\run-agent-tests.ps1 -Member C
.\scripts\run-agent-tests.ps1 -Member D
.\scripts\run-agent-tests.ps1 -Member All
```

Each run writes JUnit XML under `agentic-ai/test-results/`. The suite blocks real
HTTP transports and mocks catalogues/model responses. The former golden-case
script now mocks model HTTP explicitly; the prompt-injection test requires a
specific validation rejection, so an offline catalogue failure cannot count as
successful injection resistance. Manual scripts guarded by `__main__` are retained
as demonstrations, not counted as automated test cases.

An actual passing Member C test log is retained in
[member-c-test-example.json](evidence/member-c-test-example.json), with its
[reason-and-output report](evidence/member-c-test-example.md). It shows the
LKR 12,000 calculation and is explicitly labelled as mocked test evidence.

## Runtime agent evidence

`logger.py` now records a run ID, agent, step, timestamp, status, observable decision
reason, execution mode, model when its response is used, inputs and outputs.
These are concise application explanations, not private model chain-of-thought.
The local record is written before the backend audit request, so a failed audit
HTTP call does not erase the local record. Disk failures are logged and do not
abort planning.

| Mode | Meaning |
| --- | --- |
| `deterministic` | Python rules, tool lookup or search produced this stage's result. |
| `llm_response` | This code path used a model response; model is recorded. Tests may mock that response. |
| `deterministic_fallback` | Rules produced the result when no usable model result was available. This does not prove a successful model call. |
| `reused_strategy` | Coordinator reused the previous strategy during a budget retry. |

Geographic itinerary and complete transport/hotel selection are deterministic.
The Coordinator can use Gemini for strategy text. Legacy non-geographic selection
may use a model, then validates catalogue IDs and replaces prices with trusted
values. Member D's final checks are deterministic. The report must not say that
four independent LLMs were called for every trip.

Full sanitized records go to `agentic-ai/evidence/runs/<run-id>.jsonl` by default.
Set `AGENT_EVIDENCE_DIR` to a persistent private directory on the deployment host.
An ephemeral hosting filesystem is not an archive: download/retain evidence before
redeploying or use a persistent mounted directory. Local records can contain trip
notes and customer data, so generated runs/reports are ignored by Git.
Credential keys, bearer strings and API-key query values are redacted.
Pytest records carry `context: test`; normal service records carry
`context: runtime`. Set `AGENT_EVIDENCE_CONTEXT=test` for any separate mocked
demonstration. The report prints this label so model stubs are not mistaken for
live provider usage.

The existing backend still stores AgentLog Input/Output up to 4,000 characters.
The logger now writes valid JSON summaries with `_truncated: true` instead of
cutting JSON in the middle. `_evidence` is embedded in Output because StepType,
ToolName and DurationMs are currently `[NotMapped]` properties. Full large output
is available in the local JSONL; a database-only export cannot reconstruct it.
The final outcome record includes callback acceptance, retry count and stage times.

Export a real run after planning:

```powershell
cd agentic-ai
.\venv\Scripts\python.exe evidence.py --input evidence/runs/REPLACE_WITH_RUN_ID.jsonl --output evidence/reports/trip-report.md
```

Alternatively, save the JSON array from the authenticated
`GET /api/triprequest/{id}/logs` endpoint and pass that file to `--input`.
The exporter includes the source SHA-256 for matching the report to its input.
This digest is not a signature or independent proof of authenticity. Legacy logs
without metadata are explicitly reported as “not recorded”. Retain the source
file with the report and label mocked test runs as **test evidence**.

For the submission, collect at least a successful real proposal and a rejected
request. Preserve the request constraints, each agent's reason/output, failure
code or final AwaitingApproval state, backend acceptance and corresponding UI.
No new live planning request or payment was executed during this review.

## Personal development-tool usage

The PDF distinguishes this from runtime logs. The following entry is supported by
this conversation; historical proposed entries in the PDF have not been promoted
to confirmed usage.

| Date | Tool | User request and reason | Output provided | Human acceptance / verification |
| --- | --- | --- | --- | --- |
| 10 Oct 2026 | Codex; exact model version not recorded here | Review repository, retain agent reason/output evidence, explain Member C's Python/Dart, organize four members' tests and remove unnecessary files. Follow-up: missing APK images and transport loading on Pixel 8. | Evidence logger/exporter, four member test files, learning comments/guide, conservative cleanup, HTTPS media fix and paginated transport browsing. | Automated results recorded below; student review and physical-device verification remain separate. |

Retain this conversation, final diff/commit and test artifacts. Each student should
add only their actual prompt, accepted/rejected suggestion, personal correction
and observed verification. This report does not sign a declaration for any member.

## Repository findings and cleanup

The review traced Python agent orchestration/tools, ASP.NET audit and inventory
contracts, React transport services/build, Flutter image/catalogue/booking flows,
test discovery and tracked-file inventory. It is not a claim of exhaustive manual
inspection of every line or a production security audit.

- **Missing APK images:** live destination/tour responses contain Supabase URLs;
  the previous Dart resolver discarded URLs on other hosts. It now accepts HTTPS
  catalogue images, resolves relative uploads and handles old local upload URLs.
- **Transport loading:** the public API returned 40,822 active records. The old
  50-record all-pages read rejected the resulting page count over 100. The browse
  screen now requests 20 records at a time with a Load more action.
- **Coupled failures:** hotel/transport catalogues previously waited for private
  booking history. History now has independent loading/error state.
- **Wrong checkout target:** the transport selection button could choose the
  first unrelated booking or invented ID 101. It now opens itinerary review.
- **Audit limitations:** large JSON outputs were cut mid-string; some metadata
  did not survive database persistence. Structured metadata and local full-output
  records address those gaps without a schema migration.
- **Test reliability:** implicit network access caused slow/offline-dependent
  tests. Test runs now isolate network boundaries and preserve genuine assertions.

Removed only demonstrably unnecessary tracked files: `.gitkeep` files in already
populated directories, `.idea/caches/deviceStreaming.xml`, the zero-byte unused
`backend/app.db`, and unreferenced starter `react.svg`/`vite.svg` assets. Empty docs
directory placeholders, database migrations, catalogue import data, project
reports, test sources and platform scaffolding are retained. The user's pre-existing
`Readme/login` modification is excluded from this work.

## Verification results

| Check | Observed result |
| --- | --- |
| Full Python suite | 146 passed; external HTTP isolated. |
| Member C runner | 34 passed, including inventory, totals, pagination, failure classification and timetables. |
| Full Flutter suite | 180 passed. |
| Flutter static analysis | No issues found. |
| Backend .NET suite | 250 passed; existing obsolete-DTO warnings remain. |
| React Node tests | 19 passed. |
| React production build | Passed; existing bundle-size warning remains (main JS about 751 kB before gzip). |
| Android release APK | Built successfully, 63.9 MB, with the deployed backend API URL. Output: `mobile_flutter/build/app/outputs/flutter-apk/app-release.apk`. |
| Pixel 8 installation | Not verified; no Android device was connected to ADB. |

See ignored `agentic-ai/test-results/member-All.xml`,
`agentic-ai/test-results/member-C.xml`, and `backend.Tests/TestResults/*.trx` for
individual cases. The .NET result does not establish live PostgreSQL concurrency
or Stripe execution: those depend on the test's configured environment.
A successful build or mocked test does not establish successful installation on
the user's Pixel 8.
