# S2 Learning Flutter integration

Date: 2026-10-23. Baseline: accepted VS-02 checkpoint `23bbada2f3ac5d975b7f47428b67936977f08209`.

**Status: CLOSED / PO_ACCEPTED — synthetic development scope only.** In the 2026-10-23 closeout instruction the PO confirmed clean analysis, 60 automated tests PASS, a successful Android build, real Learning Dev Smoke PASS, and manually accepted Parent → Child → Math → Lesson → Session → Answer → Feedback → Persisted Readback against the real Development Backend/PostgreSQL. This closes the previous runtime acceptance blocker; it does not establish production readiness or convert the earlier automated Android attempt into a pass.

## Evidence attribution at closeout

| Evidence source | Result and limit |
|---|---|
| Agent-run automated analysis/tests during implementation; reconfirmed by PO | Analysis clean; 60 automated tests PASS. Existing command results retained; no repeat at documentation-only closeout. |
| Agent-run Android checks during implementation; build reconfirmed by PO | Debug APK build/install/launch succeeded; fixture regression passed. |
| PO-reported real Learning Dev Smoke | PASS against the real Development Backend/PostgreSQL. No new smoke run or transcript is claimed by this Frontend closeout. |
| PO manual Android Live E2E checklist | PO_ACCEPTED: Parent → Child → Math → Lesson → Session → Answer → Feedback → Persisted Readback. Synthetic development scope only. |
| Earlier agent-run automated S2 Android scenario | Historical attempt stopped at an empty HTTP 404 before Learning interaction. It was not rerun after the runtime became available; its controlled lost-ack scenario is not newly claimed as device-verified by the manual acceptance. |

## Contract and boundaries

Read the exact Backend `docs/api/VS-02.2_LEARNING_OPENAPI_CANDIDATE.yaml`, relevant `LearningDtos.cs`/`LearningService.cs`, and `reports/VS-02.2_LEARNING_SLICE.md` (including the operator-verified PostgreSQL update). Backend's 15/15 `mimigo_test` result is its evidence; the Frontend did not rerun Backend tests. Migration 0017 and `SYN-MATH-001` readiness on Development were reported by the PO. Backend and Database files were read-only.

The existing authenticated `LiveMimiGoApi` now implements only these five Learning operations, using the same bearer token and selected child ID:

| Method | Path under `/api/v1` | Body |
|---|---|---|
| GET | `/children/{childId}/lessons` | none |
| GET | `/children/{childId}/lessons/{lessonId}` | none |
| POST | `/children/{childId}/learning-sessions` | `{lessonId}` |
| GET | `/children/{childId}/learning-sessions/{sessionId}` | none |
| POST | `/children/{childId}/learning-sessions/{sessionId}/answers` | `{clientEventId,cueId,optionId,usedHint:false}` |

No parent ID, correctness, attempt number, entitlement or completion state is supplied by the client. The server decides eligibility; Flutter selects MATH/FREE entries from actual returned results. `SYN-MATH-001` is not hardcoded as a live catalog item or lesson ID.

## Implemented experience

1. **Child Mode → Math:** loading, real eligible-lesson list, server disclaimer, authoritative emptyReason (`NO_ELIGIBLE_CONTENT` / `CHILD_OUTSIDE_PROGRAM_AGE`), safe errors/retry and Back to Child Mode.
2. **Lesson detail:** returned title/code/objective and Development/demo label. Cues/options are decoded without any correctness or feedback property. Opaque media metadata is decoded, but no storageRef is opened or treated as a playable URL.
3. **Start or revisit session:** POST start/reuse then GET recorded state/answers. Child/lesson/session/revision identity is checked before showing questions. Back to Math, Back to Child Mode and Flutter system Back routing work.
4. **Interactive questions:** cue and option ordering follow server seq/position. User selects an option and submits. Controls disable during submission; no hint feature or retry cap is invented. Only the returned AnswerResponse supplies feedbackText and isCorrect.
5. **Safe answer retry:** UUID v4 generated once per intentional attempt. Immutable payload retained by child/session/cue in root memory across response failures and Back/revisit. Pending choices stay locked; retry resends the same body. Acknowledgment is matched to the submitted session/cue/option/usedHint before clearing it. A 409 does not silently generate a replacement event ID.
6. **Persisted answer revisit:** GET session shows recorded option labels, server-assigned attempt numbers and server isCorrect. It does not fabricate explanatory feedbackText because SessionDetail does not supply that field. Replaying a pending event can obtain the original answer feedback.

The accepted Parent Area restriction remains. Return to account entry clears local token, account/child state and pending answer payloads and requires fresh parent authentication. There is no refresh/revocation or Parent Gate workaround.

Fixture/live switching remains intact. Fixture mode retains the existing Logic shape demo and empty Math category; no new S2 mock lesson was introduced. A live error never falls back to that demo or a fake catalog/result.

## Automated test evidence retained from implementation

| Command / check | Actual result |
|---|---|
| `flutter analyze --no-pub` | Passed, no issues. |
| `flutter test --no-pub` | Passed, **60 tests** (31 prior regressions + 12 Learning API/model tests + 17 Learning widget/queue tests). |
| Android fixture regression, `flutter test integration_test/child_fixture_test.dart -d emulator-5554 --no-pub` | Passed, **1 scenario**, Android 17 / API 37 x86_64; debug APK built and installed. |
| Earlier automated S2 live Android scenario | Historical: attempted after readiness HTTP 200; debug APK built/installed and auth/ChildProfile setup succeeded, then catalog returned empty HTTP 404. Not an automated pass. Superseded for scope acceptance by the later PO manual Android Live E2E, attributed separately above. |
| Final normal Android debug build/install/launch | Passed, exit 0: `flutter run -d emulator-5554 --debug --no-resident --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1`. Normal `lib/main.dart` installed after final code changes. |

API tests exercise all five exact paths, bearer reuse, body fields, 201/200 start/reuse and answer decoding, identical replay payloads, 401/403/404/409/503 envelopes, request IDs, timeout/connectivity, malformed JSON/types and empty HTTP 404 status retention. Widget tests cover catalog/detail/start/read/answer errors, loading/duplicate-submit prevention, no pre-answer correctness, opaque media, persisted readback, lost-ack retry across Back/revisit (including a response arriving after disposal), 409 retention, revision mismatch and queue isolation/clearing. Learning test data is synthetic test-double data only, never a live fallback.

## Initial Development runtime discrepancy (historical)

This section preserves the original agent-run attempt. The PO later reported real Learning Dev Smoke PASS and manually accepted the full Android journey; the old 404 is no longer an open acceptance blocker. No Frontend runtime repair, new probe or rerun is claimed at closeout.

The already-running Development API at `127.0.0.1:5187` returned:

```text
GET /api/v1/health/ready -> 200 {status:ready, service:mimigo-backend, mode:R0_SYNTHETIC}
Android live test: reference/register/verify/login/attempt/create/login/me/list/detail -> OK
Android Learning catalog -> invalid JSON response, X-Request-Id=e8f5a1f3028c4fc9adfef78fd18aa1f1
Independent catalog route probe -> HTTP 404, body length 0
Probe X-Request-Id=b6015cd2908b40c0ba57c32ebd6ce387
```

The probe used the documented path with a UUID and no token; a mapped authenticated route should return its documented error envelope. Backend source `V1Endpoints.cs` maps this exact route, while the running endpoint returned no envelope. A final route check at 19:21 +07:00 still returned HTTP 404. This is a runtime/contract discrepancy to resolve with the Backend operator, not a reason to change the Flutter route or fabricate lessons. The client now preserves HTTP status/request ID even for malformed/empty error responses. Backend runtime/configuration was not restarted or changed by the Frontend.

One generated synthetic parent/child pair was created through existing API operations during this attempt. No Learning session/answer POST was reached; no S2 live persistence is claimed. No credentials, OTP, token or connection string were saved to source/reports.

The prepared automated Android scenario includes catalog, detail, session reuse/readback and answer feedback with controlled test-wrapper loss of one real server acknowledgment, followed by Back/revisit and exact event replay. That scenario was not rerun after the earlier blocked attempt. The later PO-reported manual checklist covers the accepted live journey and persisted readback; it does not provide a new automated transcript or controlled-loss test result.

## Files changed

- `lib/main.dart`: five methods on the existing authenticated client, live Math and lesson navigation, pending queue lifetime, safe transport/error response handling.
- `lib/api_failure.dart`: existing shared failure types extracted for model/screen reuse; re-exported from main for compatibility. Invalid responses can preserve HTTP status.
- `lib/learning_models.dart`: exact contract models, request serialization, LearningApi and scoped in-memory pending answer queue.
- `lib/learning_screens.dart`: catalog, detail, session questions, server feedback and recorded answers.
- `lib/child_content.dart`: updated comment for categories outside the Math slice; existing fixture behavior unchanged.
- `test/learning_api_test.dart`, `test/learning_widget_test.dart`, `test/learning_test_data.dart`: focused tests and synthetic data.
- `test/sign_in_test.dart`, `test/child_mode_test.dart`: adapted existing test doubles/assertions to the now-supported live Math catalog request.
- `integration_test/s2_learning_live_test.dart`: opt-in S2 live scenario; `integration_test/live_auth_test.dart` updated to allow the new Math catalog instead of asserting all categories are unavailable.
- `AGENTS.md`, `reports/WORK_STATUS.md`, this report: authorized contract, state, attributed evidence and product limitations. No dependencies or Backend/Database code changed. One local checkpoint is authorized by the S2 closeout instruction; no push.

## Outstanding product limitations

- The synthetic development Math slice is PO_ACCEPTED. Production security/legal/content approval and release readiness are outside this acceptance. Other live categories remain unavailable; fixture Logic feedback stays local.
- In-memory pending event IDs survive screen navigation, not process termination or explicit account-session clearing. No durable/offline queue or automatic background retries were introduced.
- The API has no pinned-old-revision detail route. If a resumed session and current lesson detail have different revision IDs, Flutter stops safely instead of mixing prompts/options from different revisions. Republish policy remains a Backend/BA decision.
- No completion/abandon, billing/Premium, media playback/delivery, parent progress dashboard, hint rules or production authentication was added. Sessions remain server-owned IN_PROGRESS. Physical-device/iOS behavior is unverified.

Android live run:

```powershell
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```

Prepared automated S2 E2E (not rerun at closeout):

```powershell
flutter test integration_test/s2_learning_live_test.dart -d emulator-5554 --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```

## S2 Frontend checkpoint closeout — 2026-10-23

- Disposition: **PO_ACCEPTED / CLOSED**, strictly within synthetic development scope. The PO's current instruction is the acceptance source; no additional signoff or unprovided runtime transcript is invented.
- Reviewed all 15 changed/untracked S2 source, test and report files against the accepted VS-02 baseline. No real password, bearer token, database connection string, private key, signing secret, accidental artifact or unrelated modification was found. `unit-token`, `synthetic-pass`, dummy UUIDs and `.invalid` metadata are synthetic test values; live test credentials are generated in memory.
- Build outputs/APKs, caches, IDE/SDK-local configuration and `.mimigo/**` remain excluded by existing ignore rules. No file deletion or artifact cleanup was needed. Fixture/live behavior and all application/test source are unchanged by this closeout; only the three requested management files were updated.
- The PO authorized one local checkpoint containing the S2 implementation and this closeout, with message **`chore(frontend): close PO-accepted S2 learning integration`**. The final handoff reports its actual hash and post-commit status; `git log -1 --format=%H` identifies the containing checkpoint.
- No push, history rewrite, Backend/Database change, new feature or contract work is part of closeout.
