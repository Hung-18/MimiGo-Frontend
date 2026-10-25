# Flutter Parent and Child MVP completion R1

2026-10-26. Sequential implementation from `6f8da11`. Synthetic R0 only; no new PO acceptance or production approval.

## WP1 — Parent account and Child profiles

Existing registration, verification recovery, explicit Terms/purpose review, locked creation retries, multi-child selection and server-derived eligibility were retained. Confirmed gap: a failed workspace refresh displayed both an error and first-child/empty-account guidance, and reused Child learning recovery instructions in Parent Home. Parent Home now uses safe Parent onboarding errors and shows empty-account guidance only after a successful load. Retry restores the authenticated roster without retaining stale children or exposing raw server text.

Validation: `flutter test test/parent_home_test.dart test/sign_in_test.dart test/child_onboarding_test.dart test/multi_child_entry_test.dart --no-pub --reporter expanded` — **55 PASS**. Includes new failed-roster/retry widget regression. Unsupported guardian verification, sensitive edits and legal text remain BLOCKED by approved contracts/policy.

## Boundaries

Only this repository is writable. Parent Gate defaults OFF; protected reads still require memory-only proofs and native screen protection. No PIN bypass, live fixture fallback, persistence policy, billing or Backend/Database configuration changes. Pre-existing `tasks/CURRENT_TASK.md` is excluded from commits. No push/deployment. G1, S-TB/DBQ-22, D-05, Legal G2, Content G4, Finance and Production remain OPEN. Missing PIN/privacy/completion/error reference frames remain BLOCKED for exact visual fidelity.


## WP2 — Parent Gate and protected navigation

Added an explicit protected-roster refresh/retry. Refresh clears previously selected private detail/history; failed loads no longer claim an empty roster. Existing PIN proof binding, Child token transitions, expiry/background cleanup, account reauthentication and locked fixture controls are retained. Retry is exposed only after native screen protection succeeds and cannot create a proof.

Validation: `flutter test test/parent_gate_widget_test.dart test/parent_gate_session_test.dart test/parent_gate_repository_test.dart test/child_mode_test.dart --no-pub --reporter expanded` — **70 PASS**, including new protected-roster failure/retry regression and existing expiry, revocation, denial, sibling-switch and vault checks. Sandboxed Dart formatter stalled and was interrupted; approved outside-sandbox formatter succeeded. No security runtime changed.

## WP3 — Learning discovery and eligibility

Curriculum refresh now reconciles a disappeared topic with the returned domain metadata, returning to that domain's topic list. Valid topic selections remain in place. Removed lessons are never clickable, an empty response remains empty and restored publication requires explicit topic selection. Returned names/order and six canonical framework codes remain unchanged; no fabricated age bands, paid entitlement, offline content or fixture fallback.

Validation: `flutter test test/curriculum_explorer_test.dart test/backend_modules_test.dart test/additive_onboarding_contract_test.dart test/learning_api_test.dart --no-pub --reporter expanded` — **70 PASS**. New withdrawn/restored-topic widget case plus existing HTTP denial/retry, age/permission, invalid domain and narrow 2x-text checks. This simulates catalog changes; it is not new live recall acceptance.

Canonical paid age-out remains untouched: valid periods bought before seven retain access through paid expiry; new purchase/renewal from seven is unavailable. Current Flutter contract exposes Free discovery, not a purchasing or Premium decision API. Those features remain BLOCKED by billing/entitlement contracts and Finance approval. Backend R1 adds staff discovery only, with no changed Learning integration required; G1 nullable retained-answer/title handoff is recorded for the next package.

## WP4 — Interactive learning and Parent progress

Implemented the current Learning OpenAPI `AnswerSummary.isCorrect` nullable contract for guarded retained answers. Null is displayed as **Feedback unavailable**, never as an incorrect answer or fabricated explanation. Missing/non-boolean fields still fail validation; new answer acknowledgments must still carry boolean correctness. Completed readback accepts correctness redaction while retaining immutable child/session/revision/answer identities and endedAt; contradictory non-null correctness still fails. Existing cue membership, shared in-flight work, same-event retry, server-only completion and new-session replay are retained.

Protected Parent history now clears the previous result before reload, so a failed read cannot leave a stale empty/history result looking current. PIN/proof, expiry/background and denial cleanup remain mandatory. No aggregate progress, score or exhaustive local history is invented.

Validation: `flutter test test/learning_hardening_state_test.dart test/learning_hardening_widget_test.dart test/learning_completion_state_test.dart test/learning_completion_widget_test.dart test/learning_completion_repository_test.dart test/parent_gate_widget_test.dart --no-pub --reporter expanded` — **96 PASS**. Four new cases cover redaction identity preservation, strict acknowledgment parsing, unavailable feedback presentation and protected history failure/retry. Additional non-null contradiction assertion added to retained-answer regression and rerun separately.

Dependency: Backend's future G1 rollout also mentions unavailable titles. The current approved history schema still requires non-null `lessonTitle`; no speculative title DTO or rollout flag is added. A revised exact nullable-title schema plus authorized paired G1 deployment remains required. Real guarded Android redaction/network-loss reacceptance is NOT RUN; no isolated API prerequisites were authorized for this task. Existing cross-system journey remains historical PASS.

## WP5 — Demo readiness and usability

Vietnamese labels now identify Parent entry, child reselection, add/refresh/account return, protected roster/history reads and curriculum open/retry actions. Parent Home has a shared notice that explicitly distinguishes local fixture data from authenticated synthetic API access. Existing design tokens, offline fonts and growing controls are reused. New Parent Home layout checks load the real bundled fonts and exercise 320×740 and 960×540 at 200% text, including selection/entry and a minimum 64dp primary action. Existing Explorer/player and demo accessibility tests remain intact. Broader translation, approved art/media and exact visual acceptance remain outside this slice.

Final automated checks: analysis **PASS**, no issues (23.8s); full suite **345/345 PASS** (16s test phase), including nine new R1 tests. WP4 state rerun **15 PASS**. Initial full-suite run failed 22 tests because older helpers tapped offscreen Parent/Welcome controls; three helpers now scroll before tapping, with assertions retained. The final full run has no unresolved FAIL. Additional final affected-screen suite **46 PASS**. Android checks are recorded below after completion.

## Operator walkthrough

### Fixture story — no account, API or database

```powershell
flutter devices
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=fixture
```

If needed, start the existing AVD using `flutter emulators --launch Medium_Phone_API_37.0`. Use the actual device ID from `flutter devices`.

1. On Welcome tap **Khám phá bản demo**, select Bé Mây or Bé Nắng, then **Bắt đầu khám phá**.
2. Open **Giỏ trái cây vui vẻ**. Choose once at all three stops, including a wrong option to show explanatory feedback. Finish, replay, then confirm exit.
3. Point out the local-only completion label: there is no Backend write, private Parent information, real age eligibility, video or payment. Other sample domains honestly show unavailable content. Parent/history controls remain locked.
4. The separate fixture account flow on Welcome still exercises synthetic registration, unchecked notices and profile creation. Parent Home says **DEMO / FIXTURE**. Select a child and use **Vào không gian của bé**; **Chọn bé khác** is available only before entry.

### Integrated R0 — operator-provided authorized API only

```powershell
# authorizedPort is supplied by the operator for an already-authorized R0 API.
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=live "--dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:$authorizedPort/api/v1"
```

All API configuration is build-time only. Gate remains false by default. For an independently authorized, already-configured Gate candidate environment only, add `--dart-define=MIMIGO_PARENT_GATE_ENABLED=true`; this client flag does not enable Backend flags, apply migrations or authorize a new isolated acceptance run. Do not activate shared databases or restart Dev API for the walkthrough.

Use only synthetic credentials/profiles. Sign in, inspect the **R0 / API** notice, choose a child and enter explicitly. A gated configuration requires the real child-bound PIN transition; protected history requires a fresh Parent Area proof. Explore actual returned domain/topic/lesson names. Answers, completion, endedAt and replay come only from real responses. If the service denies access or is offline, use explicit retry/account return; no fixture story is substituted. Roster refresh is **Tải lại danh sách bé**, protected refresh **Tải lại danh sách bé được phép xem**, history **Xem lịch sử học được phép truy cập**. History contains returned sessions only and no invented aggregate progress. This task ran no fresh live API journey.

## Remaining SRS dependencies

- Legal-approved notice text/guardian assurance, consent withdrawal, retention/export/erasure and sensitive edits: BLOCKED by Legal/Security and exact API policy.
- Production media delivery, approved rights/art/mascot, finalized curriculum inventory and full Vietnamese copy: Content G4/design/media contracts OPEN. Six framework domains do not promise six published lessons.
- Premium purchase/renewal, paid entitlement presentation, pricing/provider/refunds: Finance/provider/Legal and approved mobile contracts OPEN; canonical paid age-out preserved.
- G1 promotion and unavailable-title schema, S-TB/DBQ-22 trust boundary, D-05/CUR-COMP lifecycle ownership: Backend/Database/Security/PO dependencies remain OPEN; no client workaround.
- Exact missing PIN/privacy/completion/error frames: visual fidelity BLOCKED. iOS, physical device, manual TalkBack and PO visual approval: NOT RUN.

## Local checkpoints and review

| Package | Local checkpoint |
|---|---|
| WP1 | `7bf3017` — distinguish roster failure from empty account |
| WP2 | `6b754b2` — protected roster refresh |
| WP3 | `81df928` — reconcile removed topics |
| WP4 | `449382e` — retained feedback redaction/history retry |
| WP5 | Containing commit: `git log -1 --format='%h %s' -- test/parent_home_test.dart` after delivery |

Reviewed changes are confined to affected Flutter screens/models/session memory, focused test support/regressions and tracking/report files. No native security, API defaults, vault storage, platform permissions, dependency, approved-reference, Backend/Database/Web CMS or billing file was changed. Whitespace check on owned changes PASS; the supplied CURRENT_TASK has pre-existing Markdown trailing spaces and is deliberately untouched/uncommitted. Build/test logs stay under ignored `build/`. Final working tree is expected to contain only the pre-existing `tasks/CURRENT_TASK.md` modification after checkpointing.

## Final Android verification

- **PASS — build:** native Gate/mock integration APK built twice (53.6s / 40.4s Gradle); normal fixture `flutter build apk --debug --no-pub --dart-define=MIMIGO_API_MODE=fixture` succeeded (42.7s). Final normal-entry `flutter run ... --no-resident` also rebuilt successfully (12.1s).
- **BLOCKED — runtime/install:** `flutter test integration_test/parent_gate_native_mock_test.dart -d emulator-5554 --no-pub --reporter expanded` never reached assertions. Two streamed installs stalled (sandboxed, then outside sandbox), as did a manual non-streaming fallback. A scoped emulator reboot request did not resolve installation. The final ordinary fixture restoration attempt failed with ADB exit 1 and an uninstall timeout. This is not an Android Gate/test PASS or a confirmed application assertion failure. Native mock test and fresh fixture storyboard runtime are **NOT RUN to completion** in this cycle.
- **NOT RUN:** new live API, live network-loss/recall/redaction, cross-system reacceptance, iOS and physical-device tests. No disposable environment, Backend flag, database migration or existing Dev API was touched. Historical Android/live passes remain in their original reports.
- The task-started emulator closed successfully (`adb emu kill`: OK) after the failed restore; no protected capture or security setting change was used to troubleshoot. Relaunch the AVD/operator-repair its package service before the next device smoke test. Normal fixture APK remains in ignored `build/app/outputs/flutter-apk/app-debug.apk`; successful restoration/launch is not claimed.
