# P0 mobile visual fidelity — 2026-11-05

Baseline `72029c2`, `feature/po-flutter-ui`. Frontend implementation and agent-run verification; **PO visual/final pilot acceptance remains open**. Existing internal-auth report/status edits are preserved and excluded from this delivery.

## Reference reconciliation and mapping

Found the actual October archive at `D:\Documents\THIẾT KẾ GIAO DIỆN CÁC MÀN-20261021T165523Z-1-001.zip`; **28/28** image entries match `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/` by SHA-256. Reviewed all 28 in the contact sheet and individual Welcome, registration, OTP, child form and Child Home boards. Prior `04_References/MimiGo_UI_28_PNGs.zip` is absent from mounted handoff directories; the original verified archive/extracted boards are available instead. No missing-ZIP review claim.

The actual `D:\Documents\MimiGo – Phân tích UI & Đặc tả BA theo màn hình.pdf` is the same 81-page PDF as the mounted BA reference (SHA-256 `b5cc7aaa386aa8c458f48e0e6cc189bd7389812740f4dd09d58c559142a22960`). Re-inspected rendered palette/font/accessibility pages 7–8, plus original source boards. Read `PILOT_MOBILE_DELIVERY.md` and retained its API/operator boundaries. Numbered board references below resolve through [the existing source inventory](evidence/po_reference/inventory.txt).

| Screen | Actual source | Composition delivered and functional adaptation |
|---|---|---|
| Welcome | 22 / BR1 26 | Full scenic sky/garden header, yellow/blue text-rendered wordmark, large greeting Mimi and floating white action panel. Primary account action precedes sign-in; short copy and small picture previews replace a text-heavy page and repeated hero card. No copied 3D logo or unapproved science/safety claims. |
| Register / login | 01 / BR1 | Mimi and wordmark above the rounded form, title inside the white panel, consistent field icons and working password reveal controls. Approved legal preview opens a reader; no unsupported social login. Actual API validation and blank live credentials retained. |
| OTP | 27 | Scenic companion header above floating form, six native-input cells, real initial-code expiry/countdown, existing server resend/cooldown/error controls. No fabricated renewed expiry after an ACCEPTED resend. |
| Recovery / confirmed success | No dedicated original recovery frame; 01/27 shared composition | Same form shell through request/code/password confirmation. Correct Mimi and a persistent success notice appear on return to login only after successful reset confirmation. Email acceptance remains neutral and never claims delivery. Exact dedicated-frame fidelity unavailable. |
| Child form / review | 03, 02, 11 | Scenic Mimi header, white form with three-step Parent trail, existing nickname/DOB/calendar/avatar inputs and explicit review. No invented gender/full-name field, fixed child cap, age-based profile rejection or local persistence. Backend SYN- alias restriction remains visible. |
| Parent Home | 09, 14, 24 | Short scenic companion banner and real child-selection cards leave more room for the roster; public metadata remains separated from protected account/history operations. No screenshot-derived ages, scores or aggregates. |
| Child discovery | 28, 18, 08, 12, 15, 25 | Short scenic banner and prominent picture destinations on quiet surfaces; compact all-lessons control, smaller domain atlas tiles and more choices in the first viewport. Server canonical order/names/availability and gated exit retained. |
| Player / question / feedback | 21, 13 | Readable compact metadata and media-unavailable guidance, large existing question/answer targets, image-led companion header, contextual acknowledged explanations and same server answer/completion paths. Available private video/cue timing is unchanged. |
| Completion / progress | Exact C03/C05/error frames absent in BA crosswalk | White celebration surface, centered joyful Mimi/result/endedAt and replay. Existing trail counts acknowledged cues only; no invented score, aggregate progress, badges or automatic next lesson. Exact missing-frame visual fidelity remains **BLOCKED**. |
| Approved Terms / Privacy | Dedicated privacy/reacceptance frame absent | Fullscreen scrollable/selectable server document with explicit fresh checkbox, Agree, Disagree and Close; no client-created legal content. Same visual tokens and safe areas. |

## Implementation and consent safeguards

Reusable `StorybookCanvas`, `StorybookForm`, `StorybookBanner` and `MimiWordmark` establish one hierarchy across auth/onboarding/recovery. Existing `PoGarden` delegates to the new banner; `Frame` opts into illustrated forms without changing orchestration, networking or data models. Scenery is concentrated in headers; lists and forms own opaque reading surfaces. Existing garden/domain assets, offline OFL Baloo 2/Nunito and all seven established Mimi poses are reused; no new reference crops or unlicensed exports.

`ApprovedDocumentCard` previews actual approved content and opens the full reader. Each opening starts with an unchecked choice. Agree requires that checkbox; Disagree clears that document's acceptance, while Close/system dismissal grants no decision. Callers recheck current version/hash and busy/denied state after awaiting the dialog. Privacy decisions remain independent of guardian assertion, other purposes and other children; replacing an attempt snapshot clears old choices. No agreement is persisted until the existing authenticated API operation confirms it.

The full original document body remains selectable in the reader. The preview's two-line excerpt is never substituted for submitted version/hash authority. Existing parser digest validation, legal availability checks, immutable creation/answer retry payloads, server eligibility, Parent proofs/vault/token boundaries and account-return clearing are retained. No Backend/Database/cloud/`.mimigo` write, new API contract, fixture fallback or production-mode fake success.

Mimi keeps its existing bounded 1.4-second reactions, reduced-motion behavior, route/lifecycle guards and disposal. Reader controls scroll with content at large type rather than overflowing a pinned footer. Discovery controls and the shared toolbar have 64dp targets, verified by measured widget bounds; 320dp/200%/landscape checks remain. Debug emulator observation is separate from release/profile FPS or physical-device performance acceptance. Debug logs include skipped frames during startup/capture; release/profile performance acceptance is **NOT_RUN**, not inferred from passing screenshots.

## Before / after Android evidence

**Before:** fresh baseline walkthrough at `72029c2`, **1 scenario PASS / 42s / 16 PNGs**. **After:** final **1 scenario PASS / 72s** (77s including teardown), **19 reviewed PNGs**, Android API 37, 1080×2400 / 420dpi. Captures use public synthetic presentations with the test footer; the fullscreen legal modal obscures that footer but explicitly labels its title/body as test-only. Native `screenProtected == false` is asserted before every capture. No protected Gate/private window is captured or FLAG_SECURE disabled. These are actual Android renders, not Cloud authentication/persistence evidence.

| Journey | Before | After |
|---|---|---|
| Welcome | [before](evidence/visual_p0/before/pilot_welcome.png) | [after](evidence/visual_p0/after/pilot_welcome.png) |
| Register | [before](evidence/visual_p0/before/pilot_register.png) | [after](evidence/visual_p0/after/pilot_register.png) |
| Login | [before](evidence/visual_p0/before/pilot_login.png) | [after](evidence/visual_p0/after/pilot_login.png) |
| OTP | [before](evidence/visual_p0/before/pilot_otp.png) | [after](evidence/visual_p0/after/pilot_otp.png) |
| Recovery / code | [before](evidence/visual_p0/before/pilot_recovery.png) | [after](evidence/visual_p0/after/pilot_recovery.png) |
| Privacy | [before](evidence/visual_p0/before/pilot_privacy.png) | [after](evidence/visual_p0/after/pilot_privacy.png) |
| Child creation form | [before](evidence/visual_p0/before/pilot_child_onboarding.png) | [after](evidence/visual_p0/after/pilot_child_onboarding.png) |
| Parent Home | [before](evidence/visual_p0/before/pilot_parent_home.png) | [after](evidence/visual_p0/after/pilot_parent_home.png) |
| Child discovery | [before](evidence/visual_p0/before/pilot_child_home.png) | [after](evidence/visual_p0/after/pilot_child_home.png) |
| Lesson | [before](evidence/visual_p0/before/pilot_lesson.png) | [after](evidence/visual_p0/after/pilot_lesson.png) |
| Feedback | [before](evidence/visual_p0/before/pilot_feedback.png) | [after](evidence/visual_p0/after/pilot_feedback.png) |
| Completion | [before](evidence/visual_p0/before/pilot_completion.png) | [after](evidence/visual_p0/after/pilot_completion.png) |

Additional interaction evidence: [fresh legal choice](evidence/visual_p0/after/pilot_legal_reader.png), [server-shaped OTP resend/cooldown](evidence/visual_p0/after/pilot_otp_resend.png), [confirmed recovery result](evidence/visual_p0/after/pilot_recovery_success.png), [profile review](evidence/visual_p0/after/pilot_profile_review.png) and [seven Mimi states](evidence/visual_p0/after/pilot_mascot_states.png). The legal content in test captures explicitly identifies itself as test-only; it is never supplied to the live application.

## Verification and Cloud handoff

- Analyzer: **PASS**, no issues (final run 64.5s).
- Full suite: **433 PASS / 3 opt-in SKIPPED**, 27s test phase. Five reader regressions add agreement/decline/close/fresh choice, independent purpose/guardian behavior, obsolete reader rejection and 320dp/200% scrolling. Existing reset regression now explicitly holds confirmation pending and proves no success before its acknowledgment. Existing API/auth/Gate/media/retry/completion regressions retained.
- Final layout/reader/animation checks after target-size correction: **28 PASS**, including measured 64dp discovery controls.
- Normal Android debug build: **PASS**, final `flutter build apk --debug --no-pub --target=lib/main.dart`, Gradle 111.7s. Final QA target build also **PASS**, 36.4s. Toolchain emits existing SDK XML/native-access warnings; neither build failed. Final walkthrough **PASS**, 19 captures. Normal APK restored with `adb install -r` (**Success**) and `am start -W` (**Status: ok**, cold launch 9380ms). Normal and QA APKs have distinct SHA-256 hashes; the emulator is left on the normal application, with disk data preserved.
- Android native security: **2 scenarios PASS / 62s** using `parent_gate_native_mock_test.dart`: actual encrypted vault roundtrip/delete and FLAG_SECURE; mocked HTTP Gate enrollment/proofs/private reads, child-token completion/replay, PIN switch/exit and revocation cleanup. No protected screenshots. Native platform results do not establish Cloud authorization/persistence.
- Actual Cloud client reference: **1 PASS / 1 authenticated case SKIPPED**, 19s; HTTP 200, `terms=false`, approved notices **0/5**. Malformed-input-only recovery probe: **1 PASS**, HTTP 400 `INVALID_EMAIL` and 400 `INVALID_RESET_CODE`, reference HTTP 200. No account, mailbox or child write was performed. Authenticated Cloud registration, actual mailbox delivery/reset, child creation, reopen/logout/login and child-scoped persisted progress: **BLOCKED / NOT_RUN** without the owner-authorized legal release, controlled mailbox/existing identity and published content workflow. No local fixtures are reported as Cloud E2E.
- First after attempt lost its VM connection before captures; not counted as PASS. The emulator subsequently stalled in activity/logging/reboot services under host memory pressure. Only the identified test AVD is restarted with preserved disk data, no data wipe/snapshot rewrite, and a smaller transient memory allocation. Optional timing instrumentation was removed during isolation. No Backend service was restarted.

Remaining owner dependencies are the existing concrete ones: approved non-placeholder Terms/all required hosted Privacy documents in `/privacy/onboarding-reference`; exact attempt-bound legal bodies in `ChildService` begin/resume `ToDto` responses (public reference text must not be grafted onto an old attempt); Backend authority to remove the SYN- alias restriction; guardian/purpose release policy; an authorized Parent/PIN/children and eligible published lesson/private media for fresh authenticated acceptance. Recovery validation availability does not prove mailbox delivery or valid-code redemption. New matching/sorting schemas and actual payment-provider behavior are not manufactured by this delivery.

Reproduce in PowerShell: set `$env:MIMIGO_VISUAL_PHASE='before'` with `flutter drive --driver=integration_test/p0_visual_driver.dart --target=integration_test/pilot_delivery_test.dart -d emulator-5554 --no-pub`. After: set the phase to `after` with target `integration_test/p0_acceptance_test.dart`. Final run used its prebuilt immutable APK via `--use-application-binary=build/p0-capture.apk`; do not overlap APK builds/installations. Restore a separately saved normal-entry APK using `adb install -r`, then `adb shell am start -W -n com.mimigo.mimigo_frontend/.MainActivity`. Manual PO visual acceptance, Legal/Security/Content/Production approval, TalkBack, iOS and physical-device acceptance remain open.
