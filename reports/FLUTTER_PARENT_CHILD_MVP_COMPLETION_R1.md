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
