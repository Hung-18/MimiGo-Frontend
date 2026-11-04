# Mobile Product Experience R2

**PO rejected the mascot/visual result at `bada990`.** The implementation and
test results below are historical evidence, not visual acceptance. The scoped
character replacement and subsequent Android review are recorded in
[Mascot acceptance correction](MASCOT_ACCEPTANCE_FIX_R2.md).

Implemented on `feature/po-flutter-ui`, starting at verified `8967e0a`, 2026-11-04–05. Existing internal-auth documentation changes were preserved and excluded from this delivery. Frontend only; no deployment or shared-service changes.

## Screens and visual system

- Welcome: original illustrated garden, prominent Mimi, Parent account actions and shorter introduction. Registration availability and approved-document checks remain authoritative.
- Parent Home: compact adult header, full-card child selection with press feedback, clearer protected-management grouping. Selection still loads authenticated child detail and checks workspace permissions. No aggregate progress or protected history is projected onto Home.
- Child Home: original illustrated destinations for the canonical six domain codes, server ordering/names/availability, locked unavailable destinations and contextual empty/age states. Parent exit still uses the existing Gate callback. Arts is not added as a fabricated seventh live domain.
- Authentication: consistent compact Parent welcome in sign-in/registration/recovery, contextual OTP companion, responsive shared form spacing, constrained recovery width, one-time-code autofill and warm error panels. Existing validation, cooldown, resend, legal blocks and server-only success are retained.
- Learning: normal live non-video sessions show one question at a time, 80dp minimum answer targets, exact numeric labels supplemented by matching dot groups, explicit selection feedback, previous-question navigation and an acknowledged-answer next action. Saved explanations stay visible until the child moves on. Completion remains disabled until the existing server-owned requirements are satisfied.
- Completion: confirmed completion foregrounds happy Mimi and replay; saved answers expand explicitly for review. Replay still requests a new server session. No score, reward, badge, purchase success or historical record is invented.
- Shared `PoGarden`, `PoCard`, `PoDomainMark`, `ActivityChoice`, `SessionTrail` and error treatment also improve retained fixture/preview presentations. Existing local activity examples remain isolated from the normal app.

All artwork is original Flutter canvas/vector composition: bee, clouds, sun, trees, path, flowers, counting blocks, books, conversation bubble, bag, classification shapes, discovery magnifier and celebration accents. No reference-board crops, emoji replacements, network artwork or new animation packages. Existing shared tokens and offline OFL Baloo 2/Nunito remain intact. All 28 reference PNGs and the project contact sheet were available and reviewed as visual direction. Exact missing PIN/privacy/completion/error reference fidelity remains **BLOCKED**, independently of these original designs.

## Mascot and motion

`MimiMood`: idle, greeting, guide, thinking, correct, encourage, completion. Reusable `MimiBee` changes eyes, smile, gesture, wing flutter and hovering. Greeting waves; waiting stays calm; incorrect acknowledgments receive encouragement; confirmed correct answers and completion receive short joyful reactions.

Motion uses a bounded 1.4-second burst on entry/state change, then rests. It deliberately avoids perpetual idle loops. Cards gently scale on press; acknowledged session-trail changes interpolate for 420ms; next-question scrolling is gentle. Reduced motion/accessibility navigation suppresses these nonessential effects. Mascot controllers stop on inactive lifecycle/disabled route TickerMode, resume unfinished bursts only when appropriate, and dispose their observer/controller. Decorations stay calm and static. No flashing, sound dependency or success effect before acknowledgment.

## Interaction and contract boundaries

Focused navigation is session-scoped presentation memory. Previous answers remain available; retries keep their existing request/event identity. Private video timing and pause-cue behavior retain the existing presentation and are not bypassed by the new navigation. Dot groups render only exact integer labels 1–10; arbitrary returned labels and explanations are preserved.

The trail counts unique cues with acknowledged answers in the current session, regardless of correctness. It is not a score, mastery estimate or Parent history summary. Age eligibility remains server-owned; larger targets and single-focus presentation apply without adding age bands, collecting private roster age data or changing lesson complexity. No API models, auth/proof/vault behavior, persistence, endpoint definitions or network transport changed.

## Validation and visual review

- `flutter analyze`: **PASS**, no issues.
- `flutter test`: **401 PASS / 3 opt-in SKIPPED**; includes all retained API/auth/Gate/session/retry/media/consent regressions and 11 new R2 checks. The completion reopen regression now explicitly expands the saved-answer review before asserting the retained answer identity; it still verifies no implicit replay and locked Parent controls.
- R2 checks: focused two-question progression, explanation review, Back/replay state; server-correct/incorrect reactions; pending acknowledgment/completion cannot celebrate; bounded motion/background/disposal; reduced motion/TickerMode; card press/navigation; 320×640 and 960×540 at 200% text; Parent login/registration/OTP/recovery at 320dp/200% text.
- `flutter build apk --debug`: **PASS**, normal entry, Gradle 25.7s; APK at `build/app/outputs/flutter-apk/app-debug.apk`.
- Android emulator `emulator-5554`, Android 17/API 37: **1 public synthetic scenario PASS**, final walkthrough 18s. Exercised welcome sign-in action, authenticated-shaped Parent selection callback, real Child Home widget with synthetic API responses, available-domain action, answer acknowledgment, focused completion and replay. This does not authenticate to a real Backend.
- Five Android captures reviewed: [welcome](evidence/mobile_r2/r2_welcome.png), [Parent Home](evidence/mobile_r2/r2_parent_home.png), [Child garden](evidence/mobile_r2/r2_garden.png), [feedback](evidence/mobile_r2/r2_feedback.png), [completion](evidence/mobile_r2/r2_completion.png). Every capture asserts native screen protection is false; no Gate/private surface is captured or security disabled. Fixture watermark is test-only.

Android debug startup emitted emulator/first-frame scheduling messages. No profile/release FPS benchmark, iOS device acceptance, manual PO visual approval or Cloud E2E success is claimed.

## Backend-dependent work

Approved legal documents/guardian policy still gate registration/child onboarding. Real mailbox delivery/recovery deployment, approved authenticated test identity, eligible published content and an authorized real persisted-learning journey remain external prerequisites; see the existing pilot-status report. Rich new activity schemas, delivered lesson illustrations/media and unsupported domain content cannot be manufactured by this pass. Parent progress/history continues through its existing protected contract rather than invented Home statistics. Security, Legal, Content, Finance and Production approvals remain open.

## Reproduce on Android

From this repository with the emulator running:

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter drive --driver=integration_test/mobile_experience_r2_driver.dart --target=integration_test/mobile_experience_r2_test.dart -d emulator-5554
```

The last command installs the isolated public synthetic test target and regenerates only `reports/evidence/mobile_r2/r2_*.png`. It makes no live account/content/payment/learning writes. Use `flutter run -d emulator-5554` afterward to restore the normal live-only entry. Normal app inspection: welcome → Parent sign-in/registration availability; with a separately authorized test account, existing Parent selection → Gate → Child garden → returned domain/topic/lesson → select/send → review → next → complete → replay. Do not capture protected surfaces. For an authorized host-local API, use its build-time `MIMIGO_API_BASE_URL=http://10.0.2.2:<port>/api/v1`; never use emulator localhost or change Backend flags.

Commit and push to this feature branch are explicitly authorized by the R2 handoff. Existing unrelated documentation remains outside the commit.
