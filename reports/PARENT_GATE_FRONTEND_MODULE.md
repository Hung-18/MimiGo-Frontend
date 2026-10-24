# Parent Gate Flutter module — R0 synthetic candidate

Date: 2026-10-24. Start: clean `3dcf74134b75234ecd1f7160ed762d0689a91b0e`.
Status: **REAL_ANDROID_VERIFIED — R0 SYNTHETIC ONLY**. Both real Backend Android scenarios PASS from `00b4f3d`; no new Security, Legal, production or manual PO approval implied. Earlier NOT RUN statements below describe the implementation checkpoint, superseded by the acceptance evidence here.
The acceptance instruction explicitly authorized creating and disposing a fresh isolated environment. Only validated Flutter test corrections/evidence are checkpointed; no runtime feature reimplementation, push, deployment or history rewrite.

## Real Android acceptance — 2026-10-24

### Isolated setup and interoperability

- Frontend started clean at `00b4f3d42401873719672a03ee971207c2d292bb`. Read the current Backend module/OpenAPI/disposable test script, Database foundation handoff/promotion package and this report. Backend checkout `c8b2337f0e03023514903a21da4afa6752cb5fea`; used its existing `_pg/bin/MimiGo.Api/release/MimiGo.Api.dll` (SHA-256 `1abcc369e9dd39a0ba9125eceb011b04a3e1126de5232041ba3722cd6f5b64a6`). No Backend build or repository write.
- Created a **fresh private PostgreSQL 18.6 cluster**, loopback only, port **55449**, database **`mimigo_conc_flutter_gate_20261024_214437`**. Applied the exact read-only 0001–0018 files using the documented runner, then exact candidate 0019–0022 in order with per-file transactions/checksum ledger entries. **22 ledger entries**, SYN-MATH-001 seed and candidate grant verifier PASS. No promotion/copy into the Database repository or persistent database.
- Application login `mimigo_conc_app` uses SCRAM, membership of `mimigo_r0_app`, and verified no superuser/createdb/createrole/replication/bypass-RLS privileges. Private bootstrap administrator trusts only its named loopback login; all other host users rejected. Application password and four distinct CSPRNG secrets remained in process environment/memory, not command lines, source or configuration files. Cluster credential verifiers disappeared with disposal.
- Separate **Development** API, loopback **5197**, PID **21324**, both Parent Gate flags true; Production disabled; auth IP permit 300/min only for this disposable run. Readiness **200**. Android emulator used **`http://10.0.2.2:5197/api/v1`**. Original Dev API **PID 12704 / 5187** retained throughout; no use/activation of mimigo_dev or mimigo_test.
- Real Android 17/API 37 x86_64, existing `Medium_Phone_API_37.0`, no wipe or saved snapshot. Native encrypted vault and FLAG_SECURE stayed enabled; PIN entry explicitly checks the native protected-window flag. Accounts, independent purpose choices, children and lessons were synthetic. No mocked transport response, proof, token or authorization.

### Exact executed outcomes

| Scenario/check | Final result and actual evidence |
|---|---|
| Registration, verification, Terms and independent onboarding | **PASS**, actual register/current Terms/mock verification, two fresh notice attempts and two ChildProfile creates through AP-3 before Android UI login. No preexisting account or forged fixture authorization. |
| Parent login / secure session | **PASS**, Android UI login, parents/me/workspace and native vault write; login alone grants no proof. |
| PIN enrollment / invalid / valid PIN | **PASS**, actual password STEP_UP + enrollment; wrong PIN **403 PARENT_GATE_FAILED**, no proof/private data/remaining-attempt count; fresh valid PIN opens Parent Area. |
| Ungated roster/workspace privacy | **PASS**, raw real JSON has only childId/childAlias/stockAvatarKey/withinProgramAgeRange/state; no DOB/age/creation/decisions. Ungated openSessions PARENT_GATE_REQUIRED + empty items; ungated child-detail **403 PARENT_GATE_REQUIRED**. |
| Gated detail and history | **PASS**, PIN proof authorizes real DOB/detail; initial history empty; after learning, protected list contains completed identity and exact endedAt. |
| Child entry and eligible learning | **PASS**, SWITCH_CHILD verification/context token, actual curriculum and SYN-MATH-001, cue answers and server feedback, explicit Complete, completed persisted readback, replay with different active session and preserved completed endedAt. |
| Child isolation / Parent endpoints | **PASS**, Child bearer gets **403 CHILD_CONTEXT_FORBIDDEN** on parents/me, roster, workspace, protected detail and history. Sibling curriculum **404 CHILD_NOT_FOUND**. No protected Parent controls/DOB in Child UI. |
| Child switch and PIN exit | **PASS**, PIN exit to Parent selection, child-bound PIN entry to sibling B, old child A bearer **401 SESSION_REVOKED**; PIN exit B returns real Parent token and permits gated details. |
| Serialized rotating refresh | **PASS**, **20 concurrent coordinator callers produce exactly one real HTTP refresh**, credential changes (boolean assertion, never printed), Parent mode retained and subsequent parents/me succeeds. |
| Revoked session / independent device session | **PASS**, second real session has distinct SID; revoke-others invalidates first session; first protected operation/refresh fails, private UI disappears and native vault clears. Second session represents another device; this was not two physical Android devices. |
| Server-clock session expiry | **PASS**, separate real Android scenario with Backend's documented BE_TEST_SHORT fixture (2s idle / 1d absolute) only in the disposable DB. After 4s wall time, AP-3 and raw refresh both **401 SESSION_REVOKED**; account UI/session/native vault clear. No clock/token mocks or guard-owned timestamp edits. Restored R0_CANDIDATE_7D_30D after the scenario. This verifies DB idle expiry, not natural five-minute JWT expiry. |
| Final static/regression/build | **PASS**, analysis clean (2.5s), **316/316** automated tests (39s, serial runner), exit 0. Main real-test APK and expiry APK compile PASS (6.5s/10.9s Gradle); final default-fixture debug APK PASS (6.0s). |
| Real Android scenario execution | **PASS**, main **35s**, expiry **8s**, each one authored scenario, each driver exit **0**. Framework tearDownAll bookkeeping is not counted as a second scenario. Both executed through the SDK integration driver against precompiled APKs. |
| iOS/physical device/manual TalkBack; exhaustive live PIN lock/recovery/change/reset; natural JWT expiry | **NOT RUN** in this acceptance cycle. Previous local candidate tests remain separate evidence. No formal Security/Legal approval. |

No Backend request/response or Database interoperability mismatch was found in the executed cases. Candidate AP-0 stateless read window, W-2 learning transaction boundary and other Backend residual risks remain OPEN. No insecure Flutter workaround, policy change, consent withdrawal, payment or real-data operation.

### Failures investigated and corrected

Initial real attempts **FAIL** at the valid-PIN retry after an expected wrong PIN: the test helper tried to type into a field left off screen by its previous submit scroll. Safe diagnostics confirmed the field stayed empty, no second server attempt and no app lifecycle/submit clearing. Corrected **only the test helper** to scroll the PIN field into view and tap/focus before typing. Retained explicit six-character, enabled-submit and native FLAG_SECURE assertions. Final complete scenario then passed; no app authorization/storage/PIN behavior changed. Temporary non-secret app diagnostics were removed; runtime diff is empty.

One diagnostic build **FAIL** from host Dart out-of-memory, and an early restart attempted installation before Android's package service was ready (**FAIL**, no scenario execution). Recovery: close only the owned headless emulator during compilation, wait for actual boot, then execute the prebuilt binary with the standard SDK integration driver. No device wipe, screenshot workaround, weakened assertion or unrelated process termination. PowerShell initially treated a harmless fixture NOTICE as terminating; the idempotent seed was reapplied with client_min_messages=warning. No migration edits or partial schema workaround.

### Commands actually used

Build-time defines in both APKs: `MIMIGO_API_MODE=live`, `MIMIGO_PARENT_GATE_ENABLED=true`, `MIMIGO_API_BASE_URL=http://10.0.2.2:5197/api/v1`, `MIMIGO_PARENT_GATE_E2E_AUTHORIZED=true`, `MIMIGO_PARENT_GATE_E2E_DATABASE=mimigo_conc_flutter_gate_20261024_214437`. Expiry additionally uses `MIMIGO_PARENT_GATE_E2E_SHORT_SESSION=true`, only after activating the Backend-documented short policy in the owned DB.

```powershell
flutter build apk --debug --no-pub -t integration_test/parent_gate_live_test.dart --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_PARENT_GATE_ENABLED=true --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5197/api/v1 --dart-define=MIMIGO_PARENT_GATE_E2E_AUTHORIZED=true --dart-define=MIMIGO_PARENT_GATE_E2E_DATABASE=mimigo_conc_flutter_gate_20261024_214437
# Saved to build/parent_gate_acceptance/gate-live.apk before compiling expiry.
flutter drive --driver=build/parent_gate_acceptance/driver.dart --target=integration_test/parent_gate_live_test.dart --use-application-binary=build/parent_gate_acceptance/gate-live.apk -d emulator-5554 --no-pub
flutter drive --driver=build/parent_gate_acceptance/driver.dart --target=integration_test/parent_gate_expiry_live_test.dart --use-application-binary=build/parent_gate_acceptance/gate-expiry.apk -d emulator-5554 --no-pub
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded
flutter build apk --debug --no-pub
```

The ignored temporary driver is the SDK adaptor only: `import 'package:integration_test/integration_test_driver.dart'; Future<void> main() => integrationDriver(responseDataCallback: (_) async {});`. It supplies no mock responses. A subsequent run must create/authorize a new disposable environment and rebuild with its actual port/database; **5197 is no longer serving this disposed environment**. The existing direct `flutter test ... -d emulator-5554` entrypoints remain available on a host with enough memory.

### Cleanup / repository evidence

- Restored the default candidate session policy before disposal. Verified ownership marker, exact normalized absolute data path, postmaster PID and listener, plus separate dotnet command/PID/listener before stopping anything. An initial cleanup guard refused PostgreSQL's forward-slash path spelling; normalized and reverified the exact path/PID/port before proceeding.
- **CLEANUP PASS**, exit 0: stopped only API **21324** and private PostgreSQL **13488**; ports **5197/55449** closed; recursively removed only the exact created `build/parent_gate_acceptance/run_20261024_214437` directory (private cluster, database, verifiers and service logs). Confirmed directory absent and original Dev API still **12704/5187**. No shared database DROP or persistent schema operation.
- Backend and Database repositories not edited. Database 0018 raw SHA-256 before application (ledger) and after testing both `45983394835972ee462ca56eb9f5cdc53df20092e2bac6ae2e86fd8f38686d17`, matching its baseline handoff. An observed Git metadata modification had no content diff and was left untouched. No reset/discard/history rewrite.
- Normal default-fixture APK restoration **PASS**, adb install exit 0 / Status: ok / cold launch 7.33s; topResumedActivity verified. Native refresh vault was verified empty at both real scenario endings. Temporary setup helpers/APKs/logs are ignored and removed after evidence capture, not checkpoint contents. No runtime credential/PIN/proof/token values in committed files or reports.
- Changed acceptance files: `integration_test/parent_gate_live_test.dart` (real assertions, refresh counter delegating all HTTP, visible PIN-focus correction and non-secret failure assertions), new `integration_test/parent_gate_expiry_live_test.dart`; existing AGENTS/work-status/S2/this report. Runtime implementation remains `00b4f3d`. Only validated test fixes/evidence are eligible for the local checkpoint; no push.

## Implementation checkpoint 00b4f3d — historical authority and activation boundary

Read the Backend `reports/PARENT_GATE_BACKEND_MODULE.md`, exact `docs/api/PARENT_GATE_OPENAPI_CANDIDATE.yaml`, relevant DTO null-omission rules and canonical SRS FR-ID-01/03/06/07, WF-01/02. Backend reports **435/435 PASS**; this is Backend-reported evidence, not a Frontend rerun. Backend/Database and `.mimigo/**` were not edited. The existing Development API was not restarted, terminated or reconfigured; no SQL/schema activation was performed.

`MIMIGO_PARENT_GATE_ENABLED` is a build-time opt-in, **false by default**. It enables the actual candidate contract only with live mode. Fixture mode remains the original explicit demo; Gate test doubles are injected by tests, never used as live fallbacks. A legacy login response while Gate is opted in is rejected, not silently downgraded.

Backend requires **both** `ParentGate:Enabled=true` and `ParentGate:R0UnapprovedSchemaAcknowledged=true`, rejects enabled Production, and treats migrations 0019–0022 as unapproved candidates. The Flutter define does not authorize or activate them. Real testing needs a separately authorized disposable `mimigo_conc_*` database/API; ordinary `mimigo_dev`, `mimigo_test` and Production must not be used for this candidate activation.

## Implemented screens and session behavior

- Login validates the new Parent device session and same-parent/session metadata from `parents/me`. Encrypted refresh restore rotates and validates before showing an authenticated screen. Parent and Child modes have distinct tokens; all seven existing curriculum/lesson/session/answer/complete operations require the exact selected Child context when Gate is enabled. Parent credentials and Parent proofs are not sent to learning routes.
- The coordinator serializes authenticated work, PIN transitions, logout and refresh. Concurrent refresh calls share one rotation; queued near-expiry requests reuse the rotated credential. The old durable refresh credential is destroyed before presentation, the replacement is saved before publication, and an uncertain/invalid rotation ends the local session instead of replaying a potentially consumed credential. Unknown Child entry/exit outcomes reconcile only through documented refresh mode, never reuse SWITCH proofs or invent a session endpoint.
- The native vault stores only refreshToken/refreshExpiresAt/sessionId/parentId/API scope. API scope mismatch clears the bundle without presenting the credential to a different server. Access tokens, PINs, passwords, Parent proofs, child profiles/DOB and learning history are not persisted. Android uses AES-GCM with an Android Keystore key and an atomic encrypted file in noBackupFilesDir; backup disabled. iOS uses nonsynchronizing WhenUnlockedThisDeviceOnly Keychain storage; **iOS build/runtime not verified on this Windows host**. No SharedPreferences/plaintext credential/proof storage or third-party service added. Platform references: [Android Keystore](https://developer.android.com/privacy-and-security/keystore), [Apple accessibility class](https://developer.apple.com/documentation/security/ksecattraccessiblewhenunlockedthisdeviceonly).
- PIN setup, change and reset share a protected input screen, require fresh password STEP_UP for their exact action, then call the documented command with its proof only in `MimiGo-Parent-Proof`. Exactly six ASCII digits; confirmation validation, service weak-PIN rejection, wrong-password/PIN feedback, timed Retry-After lockout and recovery-required guidance. No exact remaining-attempt counts or raw server messages displayed. Secret inputs clear before awaiting submission and on background/disposal; selection, suggestions, autocorrect and IME personalized learning are disabled. Duplicate submits and repeated navigation are guarded.
- Android PIN and private Parent screens acquire independent FLAG_SECURE leases before displaying inputs or protected responses. Releasing one lease cannot unprotect another. Failed native protection disables PIN input/private loading. Leases also protect recents while proof invalidation removes private UI on resume. This uses [Android FLAG_SECURE](https://developer.android.com/security/fraud-prevention/activities); no iOS screenshot-blocking claim.
- Parent Area opens only with a valid PARENT_AREA proof. It provides explicit protected profile/detail and server session-list reads, showing returned identity, state and endedAt without scores or aggregates. Change/reset requires fresh password authorization; sign out other devices uses the documented Parent-only command. Proofs remain in memory, expire automatically, and drop on background, invalid authorization or context transitions. Protected-read 403/404 responses remove previously displayed private data by discarding the proof; inactive Parent responses end the local session. Child Mode cannot render these screens or dispatch their requests.
- Entering Child Mode requires PIN verification for SWITCH_CHILD bound to the selected child, then a successful child-context creation response. The previous Parent access credential/proof is discarded. One active child per device session; another device has its own session. Switching from Child Mode first uses PARENT_AREA PIN to exit to gated Parent selection, then a separate child-bound SWITCH_CHILD PIN to enter the sibling. Leaving Child Mode uses the documented Parent token transition. Forgotten/recovery-required PIN in Child Mode offers logout/new Parent login, never password step-up or reset with a Child token.
- Basic roster/workspace now reads only alias/avatar/eligibility/state; public DOB/age/created fields are not assumed or retained even if erroneously supplied. Selection no longer requests protected child details. Protected details require the Parent Area header. Workspace openSessions remains deliberately discarded. Existing consent withdrawal and sensitive edits remain unavailable.
- Existing registration, mock verification, explicit Terms re-acceptance, independent purpose review before DOB, first/additional children, consumed-attempt recovery, age/learningEntry checks, eligible discovery, stable answer retries, explicit completion and replay remain. Completion is server-confirmed; endedAt/completed identity and new replay session remain child-scoped in process memory. No local child-data/history persistence, new lesson/media, billing or unapproved product policy.

## Exact API integration

| Operation | Credential/proof and result |
|---|---|
| POST `auth/login`; GET `parents/me` | Parent session + rotating-refresh metadata; Parent Gate status and matching session/parent identity. |
| POST `auth/sessions/refresh` | Only refreshToken in body, no bearer/proof. Exactly one mode-appropriate token in response; credential must rotate. |
| POST `auth/logout`; POST `auth/sessions/revoke-others` | Active Parent/Child bearer for logout (204); Parent-only other-device revocation (200). Local state clears even if remote logout cannot be confirmed; secure-storage failure is not reported as successful cleanup. |
| POST `auth/step-up` | Parent bearer, password and PIN_ENROLL/PIN_CHANGE/PIN_RESET; no automatic replay of password commands after stale-session responses. |
| POST `parents/me/parent-gate`; PUT `parents/me/parent-gate/pin`; POST `parents/me/parent-gate/reset` | Exact pin/pinConfirmation or newPin/newPinConfirmation; action-specific STEP_UP header; 204/204/200 respectively. |
| POST `parent-gate/verifications` | Parent/Child bearer, pin and PARENT_AREA, or SWITCH_CHILD + childId; validate proof kind/action/binding/expiry/method/singleUse and returned mode. Child PARENT_AREA supplies new Parent token. |
| POST `child-contexts` | Current bearer, single-use SWITCH_CHILD header, childId; 201 Child token/identity/mode. No reused proof after uncertain outcome. |
| GET `children`, `parents/me/learning-workspace` | Parent basic roster, no sensitive detail assumptions; gated workspace progress still discarded. |
| GET `children/{id}`, `children/{id}/learning-sessions` | Parent bearer + memory-only PARENT_AREA header; only inside authorized Parent screen. |
| Existing curriculum, lesson list/detail, session start/read, answers, complete | Child-context bearer bound to exact child; no Parent bearer/proof. Existing DTOs/idempotency unchanged. |

No contract mismatch found in static candidate/DTO review and exact request tests. **Actual Parent Gate server/runtime interoperability is still unverified**, so absence of observed mismatches is not a live compatibility claim. Lock/recovery/unavailable, missing proof, stale epoch, wrong context/child, revoked/expired session, malformed rotation and connectivity failures fail closed. No unsupported reset-from-Child, six-digit bypass, refreshed proof invention or API fallback.

## Implementation checkpoint local validation (historical)

| Executed check | Result / scope |
|---|---|
| `flutter analyze --no-pub` | **PASS**, exit 0, no issues; final run 2.9s. Includes both Android scenario sources. |
| `flutter test --no-pub --concurrency=1 --reporter expanded` | **316 PASS**, exit 0, 41s: 261 retained + **55 new** (26 session/state, 15 repository, 14 widget tests). All local HTTP/auth doubles explicitly synthetic. |
| Refresh/auth negative regressions | Twenty concurrent refresh callers use one credential once; queued proactive refresh, independent devices, wrong-mode/child no-wire dispatch, reused/malformed/ambiguous refresh, expired/revoked/unknown rotation, proof scope/expiry/background, identity mismatch, vault failures and logout ordering covered. |
| PIN/Parent/Child widgets | Protection acknowledgment/failure; enrollment/weak/mismatched PIN; ASCII-only validation; Retry-After/no remaining count; recovery without Child reset; private-data hiding after background/proof expiry/permission denial; switch/exit/revocation; generic restored Child label; duplicate taps; 320px/2x text layout. |
| Repository/regression | Exact verbs/paths/bodies/statuses/header scope; public roster without protected fields; all seven learning operations with Child bearer; completion/replay identity/endedAt; legacy-login refusal. Existing onboarding/Terms/learning fixture tests retained. |
| `flutter test integration_test/parent_gate_native_mock_test.dart -d emulator-5554 --no-pub --reporter expanded` | **2 PASS**, exit 0, final rerun 20s test phase (10.4s Gradle, successful install); Android 17/API 37 x86_64 existing AVD. First real Android Keystore refresh round-trip/delete + independent FLAG_SECURE leases. Second real Android vault/screens + **MOCK HTTP** login/enrollment/Parent Area/protected detail, Child learning completion/replay, two-child switch, PIN exit, revocation/private hiding. No live Backend calls. Earlier run also passed 2/2 in 23s. |
| Final opt-in Android debug APK | **PASS**, exit 0, 12.8s Gradle; command below compiles against the emulator host mapping without making HTTP requests. Default fixture APK also **PASS**, exit 0, 6.2s Gradle. |
| Normal app restoration | **PASS**, exit 0: installed the final default-fixture APK with `adb install -r`, launched `com.mimigo.mimigo_frontend/.MainActivity` with `am start -W` (Status: ok, cold launch 2.55s), verified topResumedActivity. Integration harness replaced; no Backend calls or existing app-data wipe. |
| Parent Gate real Backend Android E2E | **NOT RUN**, no explicitly authorized disposable enabled API/database supplied. Existing Development Learning PASS belongs to the previous module-OFF checkpoint, not this Gate candidate. |
| iOS build/device; physical-device/TalkBack manual review | **NOT RUN** on this Windows host. Native iOS source is preserved but unverified. |

Validation corrections are recorded honestly: an initial full run had 312 PASS/1 FAIL because a one-millisecond test fixture expired before adoption; corrected with an injected clock, preserving the expiry assertion. One later default-concurrency run exhausted host Dart/AVD memory (exit 4); serial full run above passed every test without weakening assertions or internal concurrency tests. First Android attempt found no connected device; started the existing AVD without wiping data. An offline/memory-heavy launch was stopped only after verifying its owned process identities, then the same AVD booted with temporary low-memory/headless arguments. A final APK attempt also exhausted Dart host memory (exit 1); closing only this task's emulator allowed the final Gate and fixture builds to pass. No unrelated process or Dev API was touched. Gradle emitted host Java native-access warnings; successful build/test exit codes are separate from those warnings. Final review identified and fixed protected-data retention after authorization denial; three additional regressions are included in the final suite.

## Implementation checkpoint commands and then-pending E2E prerequisites (historical)

Executed automated/native checks:

```powershell
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded
flutter test integration_test/parent_gate_native_mock_test.dart -d emulator-5554 --no-pub --reporter expanded
flutter build apk --debug --no-pub --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_PARENT_GATE_ENABLED=true --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```

The last command is a **compile check only**, not permission to use the module-OFF Dev API for Gate testing.

Before running real E2E, the operator must explicitly authorize and provide:

1. An already-running non-Production Gate API using an approved disposable `mimigo_conc_*` database, candidate migrations 0001–0022, restricted application role and the existing SYN-MATH-001 seed. No activation on mimigo_dev/mimigo_test.
2. Both Backend activation flags, externally supplied distinct PIN verifier/throttle/JWT/refresh secrets and compatible mock-email settings. Frontend must not create/store these secrets or change the API process.
3. Verified emulator-reachable host port, actual readiness/contract smoke and a test-appropriate auth IP limit (scenario makes more than ten auth requests/minute).
4. A disposable emulator app profile with an empty refresh vault. Test refuses to overwrite existing credentials; the scenario creates synthetic accounts/children through approved APIs only. Operator handles disposal/retention of that environment.

Exact guarded execution template; replace only the operator-supplied port/database name, **do not run against 5187 by assumption**:

```powershell
$gatePort = '<operator-provided-disposable-api-port>'
$gateDatabase = 'mimigo_conc_<operator-approved-name>'
flutter test integration_test/parent_gate_live_test.dart -d emulator-5554 --no-pub --reporter expanded --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_PARENT_GATE_ENABLED=true "--dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:$gatePort/api/v1" --dart-define=MIMIGO_PARENT_GATE_E2E_AUTHORIZED=true "--dart-define=MIMIGO_PARENT_GATE_E2E_DATABASE=$gateDatabase"
```

Authored scenario (analyzed, **not executed**): real register/mock verification/two independent child creations; UI login/password step-up/PIN enrollment; gated Parent Area; child A entry; actual Child-token Parent-detail 403; synthetic lesson answers/server completion/readback/replay/new identity; PIN child B switch; actual old child A token 401 after epoch change; PIN exit; refresh; independent device revokes the first session; first private read fails and sensitive UI disappears. No mock authorization, schema mutation or forced token expiry. Deterministic expiry/reuse cases are local automated tests; real expiry/reuse beyond these steps remains unverified.

Normal Gate-enabled app command **after those prerequisites**:

```powershell
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_PARENT_GATE_ENABLED=true "--dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:$gatePort/api/v1"
```

Without the Gate define, the existing fixture/live module-OFF application is preserved. Operator-specific endpoint overrides and activation choices stay in build-time defines; no environment secrets are checked into source.

## Changed files and limits

- New runtime: `lib/parent_gate_session.dart`, `lib/parent_gate_api.dart`, `lib/parent_gate_screens.dart`, `lib/gate_screen_security.dart`.
- Existing runtime: `lib/main.dart`, `lib/api_failure.dart`, `lib/parent_home.dart`, `lib/parent_onboarding.dart`, `lib/child_onboarding.dart`.
- Native: Android `MainActivity.kt`/`AndroidManifest.xml`; iOS `Runner/AppDelegate.swift`.
- Tests: four `test/parent_gate_*.dart` files (including explicit Backend test double), `integration_test/parent_gate_native_mock_test.dart`, `integration_test/parent_gate_live_test.dart`.
- Management: `AGENTS.md`, `reports/WORK_STATUS.md`, `reports/S2_FRONTEND_INTEGRATION.md`, this report; `.gitignore` excludes generated Android Kotlin state. No dependency addition or unrelated refactor.

Security, Legal and production gates remain **OPEN**. This implements the authorized R0 candidate, not production approval. Backend's candidate AP0/stateless window and concurrency/security limitations remain as documented by Backend; Flutter does not repair or redefine them. Native device security/physical access, legal consent/recovery policy, sensitive edits/withdrawal, production email/content, billing and media delivery are outside this scope. No aggregate progress, ranking or scores added. In-memory learning cache is temporary; protected Backend session-list reads do not authorize local history persistence or new post-withdrawal visibility rules.

Complete **23-file** diff/untracked scope reviewed, including native source and both integration scenarios. Secret-pattern scan and `git diff --check` clean; no real credentials, child data, signing keys, connection strings, unexpected binaries or unrelated changes. Generated Kotlin state is ignored; build artifacts stay ignored. Synthetic unit credentials are visibly test-only; live-scenario credentials/PINs are generated at runtime and not logged. Own temporary logs removed after evidence capture. One local feature checkpoint includes this report; obtain its hash from `git log -1` / final handoff. No push, merge, deployment or history rewrite.
