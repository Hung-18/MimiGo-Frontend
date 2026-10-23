# VS-02 — Flutter integration and Android verification

**Date:** 2026-10-23<br>
**Current status:** **VS-02 CLOSED — scoped PO acceptance.** The PO accepted synthetic authentication, ChildProfile and demo category navigation after Android Emulator testing, as communicated in the closeout instruction. Live authentication/profile evidence and fixture-only learning evidence remain separate. All six categories navigate; Logic's shape demo is fixture-only and all live learning content remains unavailable. This does not establish production readiness. See `VS-02_FRONTEND_CLOSEOUT.md` for acceptance, final checks, checkpoint review and outstanding work.

The VS-02.2 and initial VS-02.3 records below describe earlier observations. Their DB/NDK blockers were resolved before the latest successful run; they are retained as historical evidence.

## Scope and evidence reviewed

- Existing VS-01 Flutter fixture implementation and report.
- Current frontend Git state and local handoff/instruction material.
- Backend `reports/VS-02_BACKEND_RUNTIME.md`, especially §4, plus the candidate OpenAPI and DTOs where needed.
- At initial VS-02.2 handoff, Backend verdict was `PARTIALLY_READY`; its later PostgreSQL smoke passed. The latest Android run below also used a ready Development API.

## Implementation

`lib/main.dart` now has a contract-shaped `MimiGoApi` boundary with two implementations:

- `FixtureMimiGoApi` is the default, remains process-memory-only, and preserves the working VS-01 demo.
- `LiveMimiGoApi` uses JSON camelCase `/api/v1` HTTP calls, validates required response fields, uses `Authorization: Bearer <accessToken>` only after login, reads `X-Request-Id`, and converts malformed JSON, HTTP envelopes, timeouts, socket failures and HTTP transport errors into safe `ApiFailure` values.

Supported routes are integrated:

| Flow | Contract use |
|---|---|
| Onboarding reference | `GET /privacy/onboarding-reference` before registration; Terms id is never hardcoded in the live request. |
| Parent registration | `POST /auth/register` with display name, current Terms id and an explicit Terms checkbox. |
| Mock verification and login | `POST /auth/mock-email/verify`, then `POST /auth/login`, then authenticated `GET /parents/me`. Mock OTP is displayed only when Backend explicitly returns its development-only field. |
| PII-free onboarding attempt | Authenticated `POST /children/onboarding-attempts`; no child alias/DOB is collected before it succeeds. |
| Consent and child create | Notice versions come from the attempt response. Guardian assertion and every displayed core-purpose checkbox begin unchecked; the final create sends `attemptId`, `purposeChoices`, DOB, optional stock avatar and a stable body `idempotencyKey`. Network retries retain the exact request. |
| Retrieval | Authenticated `GET /children` and `GET /children/{childId}` are used for profile refresh and selection. |

Bearer tokens are kept only in client memory. No credentials, database strings or tokens are stored in source or Git.

## Mobile configuration

- Android has `INTERNET` permission.
- `android/app/src/debug/AndroidManifest.xml` permits cleartext **only in debug** because the local development Backend runs HTTP. Release configuration must use HTTPS.
- The live default is `http://10.0.2.2:5187/api/v1`, not `localhost`. Example:

```powershell
flutter run --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```

The contract client is mobile-targeted (`dart:io`). Flutter Web is intentionally not a supported live target because Backend has no CORS configuration.

## Fixture-only / unsupported features

The following are clearly not represented as production functionality: fixture Parent Gate/PIN, consent withdrawal, Terms re-acceptance, token refresh/revocation/logout and production email delivery. In live mode the Child shell does not enable the fixture PIN because Backend supplies no step-up/PIN route. This avoids presenting a local mock as parental authentication.

## Verification executed

| Command | Result |
|---|---|
| `dart format lib\\main.dart test\\widget_test.dart` | Passed. |
| `flutter analyze --no-pub` | Passed: `No issues found!` |
| `flutter test --no-pub` | Passed: 4 tests (fixture registration→verify→login→attempt→create→list/detail; emulator default; consent gate; leap-day age). |
| `flutter devices` | No Android emulator/device attached; Windows, Chrome and Edge only. |
| `flutter build apk --debug --no-pub` | Not passed: local Android SDK could not install/find required NDK `28.2.13676358`; Gradle failed before compiling/package validation. No source or SDK workaround was applied. |

## VS-02.2 contract notes and blockers (historical)

1. Backend §4 and the candidate OpenAPI/DTOs matched for the integrated shapes. `idempotencyKey` is a **body field**, not a request header; the client follows that rule.
2. `stockAvatarKey` is sent lower-case/hyphenated (`bear-blue`), per contract.
3. Backend `/health/ready`, onboarding reference and full register→child flow have not been verified against a live DB-backed Backend. Therefore this report does not claim successful live API integration.
4. Backend has no CORS configuration, Parent PIN/step-up, logout/refresh/revocation, consent withdrawal or Terms re-acceptance endpoint. These are not faked in live mode.
5. A live Android run requires a started emulator, Backend running on the host at a reachable port, and completion of Backend’s live-DB smoke steps. The debug APK build additionally requires the local Android NDK dependency to be available.

## VS-02.2 next steps (historical)

1. Operator configures the disposable Backend DB role/connection and obtains Backend `SMOKE PASS` as specified in its VS-02 report.
2. Install/repair Android NDK `28.2.13676358`, then rerun the debug APK build.
3. Start an Android emulator and Backend at `127.0.0.1:5187`; run Flutter with the documented `10.0.2.2` defines.
4. Exercise the full live flow and capture request IDs/results, including an idempotent replay after a controlled transport interruption. Do not treat fixture or contract-test results as live acceptance evidence.

---

## VS-02.3 — Initial Android verification attempt (2026-10-23; historical)

### Actual Android Emulator evidence

- Device: `sdk gphone64 x86 64`, `emulator-5554`, Android 17 / API 37.
- Exact run command:

```powershell
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```

- The live-configured debug APK built successfully, installed successfully and launched with the UI label `Live-contract mode`.
- The Emulator reached `10.0.2.2:5187`: ICMP succeeded and `nc -z -w 3 10.0.2.2 5187` connected.
- Pressing **Create a parent account** in the installed live app caused the Backend to log `GET /api/v1/privacy/onboarding-reference` from `10.0.2.2`.
- This session's Development API returned `503` with `{code:"DB_NOT_CONFIGURED", message:"The service is not configured.", requestId}`. The APK visibly displayed `DB_NOT_CONFIGURED · request 60bb88e927574b77a51753f111e328df: The service is not configured.`

This is actual device verification of the Android host mapping, live client configuration, request route and safe error-envelope presentation.

### Minimal source correction

The device error test exposed that `_MimiGoAppState` used its context above `MaterialApp` to find a `ScaffoldMessenger`. `lib/main.dart` now supplies a `GlobalKey<ScaffoldMessengerState>` to `MaterialApp` and uses that key for root asynchronous errors. This is a targeted error-handling correction; fixture behavior and API flow implementations are unchanged.

### Full-flow / idempotency status

- **Not device-verified:** registration, mock verification, login, consent attempt, child create, list, detail and an idempotent replay through the Flutter APK.
- **Why:** although Backend evidence `D:\Projects\MimiGo\MimiGo-Backend\reports\evidence\VS-02_live_smoke_20261023_144628.txt` records `SMOKE PASS` on `mimigo_dev` with restricted role `mimigo_r0_dev`, its connection string was not available to this session. Starting the prebuilt Development API without supplying a connection string correctly returned `DB_NOT_CONFIGURED`; no credential was guessed, read or persisted.
- Backend smoke evidence, not Flutter device evidence, records the supported API flow including child-create replay `201` then `200`, list/detail `200`, and a conflict `409`.

### VS-02.3 verification

| Command / action | Result |
|---|---|
| `flutter devices` | Emulator detected as `emulator-5554`. |
| `flutter build apk --debug --no-pub` | Passed after required local NDK became available. |
| Live-configured debug APK build | Passed with the two `MIMIGO_*` defines above. |
| Install and launch on Emulator | Passed. |
| Emulator request to `10.0.2.2:5187` | Reached Backend; route observed in Backend log. |
| Live error envelope presentation | Passed: visible `DB_NOT_CONFIGURED` code, request id and safe message. |
| `flutter analyze --no-pub` | Passed: `No issues found!` |
| `flutter test --no-pub` | Passed: 4 tests. |

### Remaining blocker and next step

Supply the restricted Development API connection string through the approved operator/session mechanism, start the Backend at `127.0.0.1:5187`, then rerun the exact command above. Complete and record the synthetic Flutter flow using a fresh `@example.test` email and `SYN-` child alias, including a retry of the identical child-create payload. Do not infer Flutter E2E success from Backend smoke evidence alone.

---

## VS-02.3 — Returning-parent sign-in completion (2026-10-23)

### Changes

- The landing screen now exposes **Create a parent account** and **Already have an account? Sign in**. Returning sign-in opens directly without fetching registration reference data.
- Added a sign-in form with email validation, a required password, initially blank fields, disabled controls during submission, an explicit progress indicator, and inline safe API errors. `INVALID_CREDENTIALS` displays **Email or password is incorrect** with the request ID. Passwords are passed unchanged; email whitespace is trimmed.
- Both registration verification and returning sign-in call the existing `MimiGoApi.login` and then `parentMe` through a shared authentication method. Returning parents also load `listChildren` before the Parent Area is shown; failures keep the sign-in form available. Parent Area supports empty and existing-profile results; selecting a child invokes the existing `getChild` before opening Child Mode.
- The authenticated parent's `currentTermsAccepted` flag disables adding a child if current Terms acceptance is missing. There is no new Terms re-acceptance workflow.
- Successfully completed mock email verification is retained within the OTP screen so retrying a temporary login/parent-check failure does not consume the same OTP again. The temporary registration password is cleared from root state once authentication completes.
- Landing wording now says **Development API mode. Use synthetic test accounts only.** It no longer carries a stale Backend runtime-verification claim.
- Added Flutter SDK `integration_test` as a development dependency and an opt-in live Android scenario. Fixtures remain the default configuration. The live scenario uses the actual `LiveMimiGoApi` throughout and a fresh client for returning sign-in.

### Verification results

| Check | Actual result |
|---|---|
| Development readiness `GET http://127.0.0.1:5187/api/v1/health/ready` | HTTP 200, `status: ready`, `mode: R0_SYNTHETIC`. Used the already-running API; no Backend configuration or credentials changed. |
| `flutter analyze` | Passed, no issues. |
| `flutter test` | Passed, 17 tests. Includes landing navigation, validation without API calls, loading/duplicate-submit prevention, wrong-password recovery, parent/list failures, empty/existing profiles, detail selection, unavailable Terms, safe server/network/invalid-response errors, OTP authentication retry, and original fixture/consent/date tests. |
| `flutter test integration_test/live_auth_test.dart -d emulator-5554 --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1` | Passed, 1 live scenario; Android 17 / API 37, x86_64. Built and installed a debug test APK. |
| Normal `flutter run -d emulator-5554 --debug --no-resident` with the same two defines | Passed: rebuilt the normal app, installed and launched it after testing. |
| Normal app landing UI hierarchy | Both registration and returning-parent sign-in controls visible; updated Development mode text visible and stale runtime text absent. |

### Actual Android live flow

The Android test registered a unique generated `@example.test` parent through the registration UI, verified the returned Development mock OTP, authenticated and fetched `parents/me`. It loaded the PII-free attempt, asserted that the guardian and purpose choices were initially unchecked, affirmed them and created a `SYN-` child through review. The UI reached that child's home screen.

The test then recreated the app with a **fresh live adapter**, opened the returning-parent sign-in entry point and submitted a wrong password. It verified the visible error and stayed outside the Parent Area. Correcting the password invoked `login` → `parents/me` → `children`, opened the Parent Area with the created profile, and selecting it fetched `children/{childId}` and opened Child Mode.

The identical child-create body was replayed through the live Dart adapter **on Android**, returning the same child ID with one matching list entry. Changing the payload under the same key produced `409 IDEMPOTENCY_CONFLICT`. This verifies replay/conflict behavior at the Android adapter; it does not exercise a deliberately dropped HTTP response or inspect the replay header, which the existing client does not expose.

The first two test attempts reached child creation but stopped at an Android keyboard refocus issue in the test's password-correction step. Explicitly refocusing and settling the platform input connection resolved the test issue; no authentication contract or product workaround was introduced. The final complete run exited 0. All three attempts used generated synthetic accounts/children; those test rows were retained without destructive cleanup. No password, OTP, bearer token or connection string appears in committed-source candidates or this evidence.

### Changed files in this continuation

- `lib/main.dart`: sign-in navigation/form, shared authentication, authenticated parent/list routing, Terms gate, OTP retry handling and updated mode text.
- `test/sign_in_test.dart`: 13 focused authentication/navigation/error regression tests; original `test/widget_test.dart` retained.
- `integration_test/live_auth_test.dart`: repeatable opt-in Android live flow with secret-free operation tracing.
- `pubspec.yaml`, `pubspec.lock`: Flutter SDK integration-test dependency and resolved dependencies.
- `reports/WORK_STATUS.md`, `reports/VS-02_FRONTEND_INTEGRATION.md`, `reports/evidence/VS-02.3_ANDROID_LIVE_AUTH.md`: current results and reproducible commands.

No Backend, Database, SQL, route, DTO or API contract was changed. No commit or push was performed.

### Current limitations

No blocker remains for the tested Development flows while the API is ready on port 5187. Physical Android devices, iOS, production authentication, persistent sessions, token refresh/revocation, Parent PIN/step-up, and recovery after a deliberately interrupted create response were not verified by this run. Unverified-email, malformed-response, offline and timeout sign-in paths are covered with widget test doubles; the actual device run verified wrong-password handling against Backend.

### Android live run command

```powershell
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```

---

## VS-02.3 — Child Mode navigation completion (2026-10-23, 16:11 +07:00)

### Scope and available content

Inspected the current ChildHome, root navigation, fixture adapter, previous VS-01 demo evidence, existing tests and the implemented Backend `V1Endpoints.cs`/candidate OpenAPI. The current app had inert category Chips and no lesson catalog. Backend supplies account/onboarding/profile endpoints only; it supplies no learning content, sessions or progress API.

Restored the earlier VS-01 **Find the circle** fictional mini-game under Logic in fixture mode. It retains the existing triangle/circle interaction and local feedback. This is a demo navigation entry, not a new curriculum lesson or Backend lesson record. No media, invented lesson library, remote lesson ID, score or durable progress was added.

| Category | Navigation | Fixture content | Live content |
|---|---|---|---|
| Language | Functional | Content not available yet | Content not available yet |
| Math | Functional | Content not available yet | Content not available yet |
| Logic | Functional | Find the circle — DEMO / FIXTURE, local feedback only | Content not available yet |
| Life skills | Functional | Content not available yet | Content not available yet |
| Arts | Functional | Content not available yet | Content not available yet |
| Discovery | Functional | Content not available yet | Content not available yet |

### Implementation and security boundary

- Replaced the six inert Chips with 64dp category buttons, added category/demo screens and explicit Back to Child Mode/Back to Logic controls. `PopScope` handles the Flutter system Back route through the same hierarchy.
- Added a small local content source boundary with loading, safe error/retry and empty states. Fixture content is explicitly labeled **DEMO / FIXTURE — local example. No learning progress is saved or sent.** The live source returns no content and makes no speculative request. A second UI guard prevents live mode from displaying a demo even if it is accidentally given a fixture source.
- Removed the existing fixture-only direct jump to Parent Area. The Parent Area button is now disabled in Child Mode in both modes; no PIN/step-up contract was invented.
- Added **Return to account entry** with confirmation/cancellation. Confirmation clears the local client bearer token and root account, child, draft and consent-attempt state. Late profile refresh results are ignored after the session changes. Parent Area requires the existing fresh `login` → `parents/me` → child-list sequence. `clearSession()` is a client-memory operation only; no Backend logout/revocation endpoint is called or claimed.
- Existing registration, verification, consent, profile creation/list/detail, idempotency and mock/live configuration remain in place.

### Verification executed

| Check | Result |
|---|---|
| `flutter analyze` | Passed, no issues. |
| `flutter test` | Passed, 31 tests. The original 17 authentication/fixture tests remain green. |
| New widget coverage | All six live category empty states; fixture Logic navigation/feedback/reset; five other fixture empty states; controlled loading/error/retry; stale category completion; live fixture rejection; system Back; Parent Area disabled; confirmed/cancelled account return; local auth clearing and fresh sign-in. |
| Live Android integration test | Passed, 1 scenario on `emulator-5554`, Android 17 / API 37. Actual ready Development API at `10.0.2.2:5187` used for the existing auth/consent/profile flow. All six category views were empty, no fixture demo appeared, and navigation caused no extra API calls. Cancellation retained Child Mode; confirmation cleared local auth; a subsequent login/parent check/list was required for Parent Area. |
| Fixture Android integration test | Passed, 1 scenario. All categories, Logic game feedback, five empty views, Back route and account return verified against the in-memory fixture. |
| Normal live `flutter run ... --no-resident` | Passed: rebuilt, installed and launched the normal app after both integration tests. |

The live test also rechecked wrong-password handling and existing child-create replay/conflict behavior. A new synthetic `@example.test` parent and `SYN-` child were created through the API and retained. Fixture data stayed in process memory. No real credentials, tokens or OTPs are recorded here.

Content loading/error injection is **widget-test evidence**, not a successful Backend lesson fetch: there is no learning endpoint to fetch from or fail. Android verifies the real live unavailable state and the separately labeled fixture interaction. No live lesson playback or Backend learning progress is claimed.

### Changed files in this continuation

- `lib/main.dart`: category/demo navigation, interactive ChildHome controls, Back handling, disabled Parent Area shortcut, confirmed account return and client-memory session clearing.
- `lib/child_content.dart`: category definitions, restored shape demo, explicit fixture/live content boundaries, loading/error/retry/empty widgets.
- `test/child_mode_test.dart`: 14 new content/navigation/session tests.
- `integration_test/live_auth_test.dart`: extended existing live scenario with category and safe account-return checks.
- `integration_test/child_fixture_test.dart`: Android fixture content/navigation scenario.
- `reports/WORK_STATUS.md`, `reports/VS-02_FRONTEND_INTEGRATION.md`, `reports/evidence/VS-02.3_CHILD_NAVIGATION.md`: evidence and current blockers.

### Remaining blockers

All six live categories await implemented Backend learning/catalog endpoints with actual content responses. Five fixture categories have no existing demo lessons. Direct Parent Area entry from Child Mode awaits a real Parent Gate/step-up contract. The safe alternative is confirmed account return and fresh parent authentication. Production progress, physical-device/iOS behavior and predictive-back gestures were not verified in this continuation. Backend/Database repositories were read-only; no commit or push occurred.

Android live command remains:

```powershell
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```
