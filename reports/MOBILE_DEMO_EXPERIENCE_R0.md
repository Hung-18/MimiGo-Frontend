# Mobile Demo Experience R0

2026-10-25 · IMPLEMENTED / VALIDATED in synthetic local scope. Baseline `58c0ede`; implementation checkpoint `15c7b68`.

## Experience

- Default fixture Welcome has a prominent Vietnamese **Khám phá bản demo** entry. No registration, developer credentials, network, PostgreSQL or harness is needed. The existing registration/sign-in/consent and real API paths remain available separately.
- Sample Parent presentation offers **Bé Mây / Bé Nắng**, a selected-child overview and explicit entry to Child Mode. These are invented display aliases, not accounts or authenticated child profiles. History/progress and Parent Area are visibly disabled with an explanation; no verification is simulated.
- Child discovery has Vietnamese copy, a fruit-story feature card and the canonical six domain cards using existing brand tokens/icons. Only Logic opens the sample story; other domains explain that no sample is available. This is a local discovery presentation, not a published or age-eligible catalog claim.
- **Giỏ trái cây vui vẻ** has introduction → story page → authored cue → fruit selection → option-specific correct/incorrect explanation → continuation. Three interactions recognize apple, select banana, then identify pear. Completion requires a response at every stop, irrespective of correctness. It has no score, mastery, ranking or entitlement.
- Replay clears selections and starts a fresh local playthrough. It never resets a server session. Back returns from the story to Child discovery; it cannot expose sample Parent selection. Leaving Child discovery asks for confirmation, discards the route's local answers and returns to the original entry screen. Reopening the demo starts with fresh sample selection.
- The existing authenticated fixture Child Home also links to this local lesson presentation without opening the sample Parent selector. The legacy shape fixture and its navigation remain available.
- Existing privacy purpose cards show readable Vietnamese descriptions for `CHILD_PROFILE_AGE` and `LEARNING_PROGRESS`; unknown codes retain their returned text. Version IDs, purpose codes, effective dates and hashes remain available in expandable technical details. Guardian and purpose choices remain independent, unchecked, required, and reset on new notice snapshots; refusal and request payload semantics are unchanged. Synthetic/non-legal warnings remain visible. These labels are UI descriptions, not replacement legal notices.

## Reuse, assets and limits

Reuses `Frame`, `MimiPanel`, `MimiNotice`, `MimiAvatar`, `MimiTileGrid`, `MimiDomainTile`, palette, bundled OFL Baloo 2/Nunito fonts and Material icons. The sample reuses existing `LearningCue`/`CueOption` models. Its tiny local presentation state machine is deliberately separate from the API player: that player requires genuine server session/answer/completion acknowledgments. No fabricated responses are passed into it, and its retry, history and server-confirmation behavior is unchanged.

Fruit silhouettes are original Flutter `CustomPainter` paths in `lib/mobile_demo.dart`; no downloaded media, extracted PNG reference art, generated mascot or external dependency. Story pages show the fruit moving from table to basket. **This is an explicitly labeled interactive storyboard, not video playback or narration.** Authored `pauseAtMs` values describe story positions; the operator advances into each cue explicitly. No media delivery is implied. No animations/autoplay are introduced, so the demo does not impose motion or timing requirements.

Layout uses growing 64dp-or-larger controls, wrapping fruit choices/domain cards, scrollable shared frames, selected-choice semantics, image labels and live feedback semantics. Disabled answer labels retain readable navy text and the selected answer has a blue border/background. Wrong feedback uses words/icons as well as color.

Exact fidelity remains **BLOCKED** for the missing six-digit PIN, privacy, completion and error reference frames documented in `UI_UX_FIDELITY.md`. Licensed mascot/logo/illustration exports, genuine media/narration, content review, finalized Vietnamese copy and manual PO visual approval remain absent. No suitability for every age 2–6 is claimed. Physical device, iOS and manual TalkBack verification are not part of this result.

## Boundaries

`MobileDemo` owns no API, transport, vault, account, consent draft or live learning cache. Its entry is exposed only when configuration mode is fixture. It cannot issue a PIN, Parent proof, Child token, payment, entitlement or Backend completion. The sample completion text explicitly says it is local and not sent/saved to the server. Local answers live only in the route and are cleared on replay/exit; no identifiers, responses or results are persisted. The demo doesn't provide a route from Child Mode to private Parent information or sibling selection.

`MIMIGO_PARENT_GATE_ENABLED` remains false by default. Authenticated Parent/Child transitions, FLAG_SECURE, proof expiry, refresh serialization, transport, live content, answer retry and completion contracts are unchanged. No protected screenshots or security-flag changes. No Backend/Database/Web CMS/reference-baseline edits, migration, secret, service activation, push or deployment. Security, Legal G2, Content G4, Finance and Production remain **OPEN**. This module is not fresh real API acceptance; historical evidence stays in `CROSS_SYSTEM_LEARNING_JOURNEY.md`.

## Launch and walkthrough

Use the installed Flutter SDK and an ordinary booted Android Emulator (the available AVD here is `Medium_Phone_API_37.0`, Android API 37 x86_64). No API host/port, account, PIN or database configuration is required. From the Frontend repository:

```powershell
flutter emulators --launch Medium_Phone_API_37.0
flutter devices
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=fixture
```

Use the device ID shown by `flutter devices` if different. Leave Parent Gate at its default false; no live build-time defines are needed. Standard Android Studio AVD launch also works as an operator entry point; this host's CLI launch required the headless fallback recorded below.

1. Tap **Khám phá bản demo** on Welcome.
2. Select either sample alias and tap **Bắt đầu khám phá**.
3. Tap **Giỏ trái cây vui vẻ** (also discoverable through **Logic**). Other domains show honest empty states.
4. Tap **Cùng chơi nào!**, read the story page, then **Dừng lại, cùng chọn nhé!**.
5. Tap a fruit. Try an incorrect answer at the first stop to see an explanation; tap **Xem tiếp câu chuyện**. Choose at all three stops; correctness is not required to finish.
6. Tap **Xếp xong giỏ rồi!** for local completion, then **Chơi lại câu chuyện** for a fresh playthrough.
7. Back returns to discovery. Back again or **Kết thúc bản demo** asks for confirmation and clears this visit. It does not unlock Parent selection.

The older synthetic registration/consent demo remains under the Parent account controls on Welcome. It is separate from the one-tap story and still requires explicit unchecked purpose choices before DOB. Do not enter real family data. History/progress, private profiles, PIN verification, consent withdrawal, sensitive edits, payments and persistent learning evidence are intentionally unavailable in this local presentation.

The unchanged real path uses build-time `MIMIGO_API_MODE=live` and `MIMIGO_API_BASE_URL=http://10.0.2.2:<authorized-port>/api/v1` for an Android Emulator. It uses actual authentication, server eligibility/curriculum, Gate rules and server-confirmed answers/completion. A local storyboard result is never real API/PostgreSQL evidence or a fallback for failed live requests.

## Validation and checkpoint

Executed on 2026-10-25:

- `flutter analyze --no-pub`: **PASS**, no issues (final 4.2s).
- Focused command below: **118/118 PASS**, 45s final run. Includes 9 new demo tests plus retained navigation, design, onboarding, Parent Home/Gate and Learning completion/retry regressions. The two initially failing presentation tests were adapted without dropping assertions: expand both technical disclosures before asserting both hashes; scroll the existing Welcome registration control into view before its duplicate-tap guard check.
- `flutter test test/mobile_demo_test.dart --no-pub --concurrency=1 --reporter expanded --dart-define=MIMIGO_CAPTURE_VISUALS=true`: **9/9 PASS**, 2s test phase, final implementation. Tests correct/incorrect answers, three mandatory interactions, locked choices after acknowledgment, replay reset, cancel/confirm exit and clean reopening, no live Welcome entry, required unchecked privacy choices and accessible technical metadata. Layout cases: 320×740, 411×891, 960×540 at 100%/200% text, real bundled fonts/icons. Checks require 64dp minimum choice height and no layout exceptions.
- Twelve public [widget renders](evidence/ui_fidelity/) named `widget_mobile_demo_home_*` / `widget_mobile_demo_feedback_*` were generated; representative narrow-phone, regular-phone feedback and landscape/large-text views were visually inspected. They are viewport/scroll-position samples, not full scroll captures, Android screenshots, live evidence, protected captures or PO approval.
- `flutter build apk --debug --no-pub --dart-define=MIMIGO_API_MODE=fixture`: **PASS**, Gradle 73s.
- `flutter test integration_test/mobile_demo_fixture_test.dart -d emulator-5554 --no-pub --dart-define=MIMIGO_API_MODE=fixture --reporter expanded`: **1/1 Android scenario PASS**, 27s test phase, real Android widgets/local state. Covers Welcome → alternate sample profile → Child discovery → all three story/cue/feedback transitions (including incorrect) → completion → fresh replay → Back → confirmed exit. No real API result is inferred.
- `flutter test integration_test/child_fixture_test.dart -d emulator-5554 --no-pub --dart-define=MIMIGO_API_MODE=fixture --reporter expanded`: **1/1 Android scenario PASS**, 44s test phase. Retains original shape feedback, five honest empty fixture categories and secure account return.
- `flutter run -d emulator-5554 --debug --no-resident --no-pub --dart-define=MIMIGO_API_MODE=fixture`: **PASS**, exit 0; normal `lib/main.dart` built (Gradle 16.1s), installed (1.7s), engine started and device sync completed. Independent `adb shell dumpsys activity activities` confirms `com.mimigo.mimigo_frontend/.MainActivity` is `topResumedActivity`. The ordinary fixture Welcome is restored; no test runner remains installed as the entry point. The task-started headless AVD is left running for the operator. This is a debug-launch result, not representative-device startup performance.

```powershell
flutter test test/mobile_demo_test.dart test/child_mode_test.dart test/design_fidelity_test.dart test/child_onboarding_test.dart test/parent_onboarding_test.dart test/parent_home_test.dart test/parent_gate_widget_test.dart test/learning_completion_widget_test.dart test/learning_hardening_widget_test.dart --no-pub --concurrency=1 --reporter expanded
```

Environment: the standard `flutter emulators --launch` exited without a running AVD. The existing AVD was then booted headlessly with its installed SDK emulator: `emulator.exe -avd Medium_Phone_API_37.0 -no-window -no-audio -gpu swiftshader -no-snapshot -memory 1536` (the Android image selected 4096MB). No AVD data wipe, global setting change, unrelated process termination or Backend restart. Initial sandboxed SDK commands stalled and were canceled; SDK-capable executions above supplied the actual results.

No full-suite/release/cross-repository E2E or fresh real-API acceptance was run for this presentation module. The unchanged real path is covered by relevant retained fake-transport/widget regressions; previous real acceptance is historical. Native FLAG_SECURE/Keystore scenarios were not rerun here. Exact reference fidelity, media/content rights review and release approvals remain open as described above.

Local source/test/public-render checkpoint: **`15c7b68`**, `feat(demo): add local Vietnamese fruit storyboard experience`. The following documentation checkpoint records this report and the two tracking files; its hash is available in the delivery response / `git log -1`. Staged implementation whitespace check PASS. Only the pre-existing `tasks/CURRENT_TASK.md` remains modified after the documentation checkpoint; its Markdown line-break whitespace is preserved and excluded from the scoped checks/commits. Build APKs and raw logs are ignored. No push or deployment.
