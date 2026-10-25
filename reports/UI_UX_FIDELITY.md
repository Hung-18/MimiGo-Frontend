# MimiGo UI/UX Design Fidelity

Updated 2026-10-25. Baseline: `284ed7b`. Frontend-only visual implementation; existing real Parent Gate acceptance remains historical evidence, not a new live rerun or visual PO approval.

## Implemented scope

- Shared BR1 six-color palette, navy text, accessible darker action/link colors, rounded panels/fields/buttons, spacing and responsive screen widths in `lib/mimigo_design.dart`. Baloo 2 headings/buttons and Nunito body copy are bundled offline with their original OFL notices and LicenseRegistry entries. [Font provenance, hashes and official license links](../assets/fonts/SOURCES.md).
- Welcome, registration/sign-in/verification, privacy/onboarding/review, Parent roster, PIN/private screens, Child Mode, Explorer, Learning feedback and completion/replay inherit the shared design. Public forms have clearer field icons, centered verification input and password confirmation. Confirmation validates locally and adds **no API field**; live credentials remain blank.
- Canonical live domains have colorful functional controls; Child Home uses a horizontally scrolling rail instead of shrinking touch areas. Fixture Arts stays fixture-only. Explorer availability and metadata remain server-authoritative.
- Learning choices wrap responsively, preserve selected semantics and 64dp targets, and use feedback panels only after acknowledgment. Completed styling remains inside the server-confirmed COMPLETED branch; original session identity, endedAt, replay and process-only history behavior remain intact.
- Child back targets are 64dp; controls grow with text. At 200% text, narrow notices stack their icon above the text and reduce surrounding panel padding. No forced orientation, cropped text, new content, reward, score, media playback or production claim.
- Landscape render review also found empty grid columns when a question had only two options. The grid now caps columns at the actual item count, giving both choices the available row width; the focused regression requires each to exceed 350dp at 960×540.
- Parent/Child tokens, refresh/proofs, repository payloads and native FLAG_SECURE implementation are unchanged. No protected screen screenshots, FLAG_SECURE override, Backend request or database activation was used for visual capture.

## Sources and interpretation

Actual local sources (read-only):

- `.mimigo/ba/MimiGo_BA_Handoff_R0_v0_1/04_References/MimiGo_BA_UI_81_pages.pdf` — all 81 pages rendered locally; p7–8 provide palette/font/accessibility rules. Relevant onboarding, learning and screen crosswalk pages inspected.
- `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/` — 28 flattened PNG boards. The BA crosswalk explicitly calls them references, not automatically signed final UX.
- `.mimigo/ba/MimiGo_BA_Handoff_R0_v0_1/04_References/Previous_R0_Candidate/02_UI_SCREEN_DELTA_AND_BUILD_ORDER.md`.
- Canonical `.mimigo/r0_code_kickoff/references/MimiGo_SRS_v3_0_RC5_Canonical.md` and confirmed PO decision register take precedence over contradictory historical artwork.

BR1's lotus-wing/goggles/pink-scarf Mimi is the reference; BR2 alternatives are not replacement asset authority. Exact decorative swatches: `#FFD133`, `#FF8A00`, `#1890FF`, `#4CAF50`, `#FF6FAE`, `#9C6BFF`. Darker foreground/action shades are intentional for 4.5:1 text contrast. Material icons are functional existing icons, not representations of licensed Mimi artwork. Current English app copy remains; Vietnamese glyph rendering was checked, not full Vietnamese localization.

Confirmed behavior overrides source artwork: unchecked Terms and independent child purpose choices, privacy before DOB, no child limit, six-digit PIN, authenticated/gated switching, no ungated activity, unsupported resend/purchases/scientific claims/rewards omitted, and no correctness before server feedback.

## Screen fidelity matrix

Evidence filenames below are in [public synthetic capture directory](evidence/ui_fidelity/). `public_*` are actual Android render captures; `widget_*` are desktop Flutter widget renders, not Android screenshots. Every visual harness displays a FIXTURE/no-network footer. Screenshots are viewport/scroll-position samples, not stitched full-screen claims. MATCHED applies only to specifically compared components; **no full screen is marked visually approved**.

| Screen/component | Actual reference in PNG directory above | Status | Comparison/evidence and remaining difference |
|---|---|---|---|
| Palette and font families | `Bảng thương hiệu MimiGo vui nhộn.png`; PDF p7 | MATCHED | Exact six swatches in code, Baloo 2/Nunito visible in `public_360x800_font_specimen.png`; typography family match only, not 3D logo or full branding |
| A01 Welcome | `MimiGo_ Cùng Mimi khám phá-Trang chủ.png` | PARTIAL | `public_360x800_A01_welcome.png`: yellow/navy CTA, existing-account link, rounded composition/domain previews; missing logo/Mimi/landscape artwork and approved localized copy |
| A02 Registration | `Màn hình đăng ký phụ huynh MimiGo.png` | PARTIAL | `public_360x800_A02_registration.png`: rounded white form, icon fields, pink action and confirmation; R0 notice metadata takes space, no header art, Terms deliberately unchecked |
| Existing-parent sign-in | No dedicated supplied frame | BLOCKED | `public_360x800_signin.png`; shared tokens implemented, exact screen comparison unavailable |
| A04 verification | `Nhập Mã Xác Nhận Cùng Ong Con.png` | PARTIAL | `public_360x800_A04_verification.png`: centered six-digit entry/pink CTA; one accessible field rather than six boxes, no mascot or unsupported resend |
| PRIV-ONBOARD-01 / Terms re-acceptance | Privacy explicitly MISSING in BA crosswalk; no dedicated re-acceptance frame | BLOCKED | `public_360x800_privacy_notice.png`, existing Terms widget regressions; explicit selections and R0 notice preserved, no invented legal design |
| A06 child form / A07 review | `Giao diện tạo hồ sơ bé MimiGo.png`; `Hồ sơ bé vui nhộn MimiGo.png` | PARTIAL | `public_360x800_A06_child_profile.png`, `public_360x800_A07_profile_review.png`: rounded form/review and stock choices, no licensed avatar art/full-name/gender additions |
| B02 Parent Home/selection | `Ứng dụng học tập vui nhộn cho bé.png` | PARTIAL | `public_360x800_B02_parent_child_selection.png`: readable basic alias/eligibility roster/avatar controls; no screenshot DOB/history/child cap, Parent-only actions remain gated |
| A08 PIN / protected Parent Area | A08 six-digit frame explicitly MISSING; historical `Bảng Tiến Bộ Của Bé Bảo Anh.png` contains unapproved aggregates | BLOCKED | Shared typography/error/input styling, six ASCII digits and lockout tests; no protected captures or visual approval, no aggregate dashboard invented |
| B01 Child Home | `Ứng dụng học tập vui nhộn cho bé _1222.png` | PARTIAL | `public_360x800_B01_child_home.png`: six live domain controls, scrollable rail and 64dp targets; missing branded art/content imagery, adult navigation locked |
| B03/B04 Explorer/topic/lesson | `Ứng dụng học tập bé Bảo Anh.png`; `Ứng dụng học Toán vui nhộn cho bé.png` and existing six-area boards | PARTIAL | `public_360x800_B03_curriculum.png`, `public_360x800_B04_lesson_list.png`: shared domain cards/lesson navigation, only approved synthetic metadata, no invented thumbnails/lessons |
| C01 Learning question | `Bài học đếm số vui nhộn 1-2-3.png` | PARTIAL | `public_360x800_C01_question.png`, responsive widget renders: navy question/large choices, synthetic text-only lesson and opaque media metadata retained; reference landscape illustration/video unavailable |
| C02 explanation | `Bài học đếm táo vui nhộn.png` | PARTIAL | `public_360x800_C02_explanation.png`: acknowledged feedback panel/readable choices; no unsupported media or new lesson data |
| C03 wrong / C05 completion and replay | Explicitly MISSING in BA crosswalk | BLOCKED | `public_360x800_completion.png`, `public_360x800_replay.png`: server-state styling implemented, exact visual source absent; no score/mastery summary |
| E04–E06 offline/error/loading/empty | Explicitly MISSING in BA crosswalk | BLOCKED | `public_360x800_offline_error.png`, existing state regressions: shared notices/loading/retry, no exact reference comparison available |

## Missing handoff

No SVG/AI/Figma export or reusable licensed mascot, expressions, 3D logo, landscape background, predefined avatar or lesson-thumbnail assets exist in the supplied local handoff. Flattened PNG references exist at the exact directory above; they are not standalone rights-cleared application exports. No missing original export filename/path has been supplied, so none is invented here. No screenshot artwork was extracted or redistributed.

Missing exact screen references are PRIV-ONBOARD-01, A08, C03, C04, C05, E04–E06 in that reference directory per the crosswalk, plus dedicated sign-in/re-acceptance frames. C04 Parent Coach remains outside implemented product scope. Fidelity closure requires the approved exports, provenance/reuse rights and corrected state frames. Manual PO visual approval, iOS/physical-device/TalkBack checks and production/Security/Legal gates remain open.

The reference's lesson-title speaker/video controls also depend on approved narration/media capabilities. Existing `storageRef` remains opaque metadata; no inert audio/player control or unsupported media behavior was added to simulate that part of the design.

## Validation

Executed 2026-10-25:

- Final `flutter analyze --no-pub`: **PASS**, no issues, 2.2s.
- Final `flutter test --no-pub --concurrency=1 --reporter expanded`: **327 PASS**, 48s, exit 0. Includes all 316 retained regressions and 11 focused design tests, including the final landscape width assertion. No test removed or weakened.
- `flutter test test/design_fidelity_test.dart --no-pub --concurrency=1 --reporter expanded --dart-define=MIMIGO_CAPTURE_VISUALS=true`: **11 PASS**, 2s test phase, exit 0. Actual bundled fonts/icons; contrast, 320×740/411×891/960×540 at 100%/200% text, six domain touch/navigation controls, explicit Terms, confirmation/exact registration fields, landscape feedback/completion/replay and Vietnamese glyphs.
- Final `flutter build apk --debug --no-pub`: **PASS**, Gradle 38.1s after the final landscape correction and daemon restart, exit 0. Prior design harness **PASS** (10.7s), native Gate harness **PASS** (16.2s), existing fixture navigation harness **PASS** (16.3s). Native regression runs precede the final landscape-only column fix; their portrait layouts are unchanged. Final widget regressions and normal build cover that fix.
- Android public design catalog: **PASS** at 360×800 (19s scenario, 17 PNGs) and final 411×900 (39s, 17 PNGs), exit 0. Native protection false asserted before every capture; protected widget types refused. Larger-phone captures were also inspected against the source boards; no additional overflow found. Native/fixture and landscape results are separate below.
- Existing `parent_gate_native_mock_test.dart`: **2 Android scenarios PASS**, 42s combined, exit 0. Actual Keystore vault/lease behavior and FLAG_SECURE assertions; mock HTTP enrollment, protected Parent details, child-token learning Complete/replay, switching, exit and revoked-state cleanup. No screenshots of these protected flows and no live Backend inference.
- Existing `child_fixture_test.dart`: **1 Android scenario PASS**, 37s, exit 0. Original Logic demo, five empty fixture categories and safe account return retained; no remote progress.
- First full regression attempt exposed a Material ink/CheckboxListTile assertion caused by panel decoration. Fixed the panel to own a shaped Material surface. An existing offscreen fixture helper tap was made scroll-aware; its assertions retained. Optional widget capture initially stalled due image conversion outside real async; fixed the test-only helper and reran successfully.
- Android second-size attempts encountered an AVD display-service stall and a premature retry while booting. Interrupted/unstarted attempts are **not** product passes. Recovered only the verified task-owned AVD; no data wipe, unrelated process termination or FLAG_SECURE change.
- A subsequent optional widget capture retry ran out of host heap while the emulator was active; this is **not PASS**. With the owned AVD closed, final focused capture retry **11 PASS** (2s), exit 0, and the final width-adjusted learning screenshots were visually inspected. No heap-related assertion/test change or unrelated-process cleanup.
- Native 960×540 screenshot attempt: **NOT VERIFIED**. The public capture harness stalled after ImageReader conversion under severe host memory pressure and was interrupted; no landscape Android pass or screenshot is claimed. Portrait native captures and 960×540 widget comparisons remain separate. Only this task's failed runner, owned AVD and verified idle Frontend build daemon were stopped.
- New live Backend E2E: **NOT RUN** for this presentation-only milestone. The disposable Gate environment from `284ed7b` was removed after earlier acceptance; no new candidate activation or mock-as-live claim. Native/mock evidence and historical real acceptance are separate.

## Changed files and ownership

Runtime: `lib/mimigo_design.dart`, `lib/main.dart`, `lib/child_content.dart`, `lib/parent_home.dart`, `lib/curriculum_explorer.dart`, `lib/learning_screens.dart`, `lib/parent_gate_screens.dart`, `pubspec.yaml`, licensed `assets/fonts/**`.

Tests/evidence: `test/design_fidelity_test.dart`, `test/design_test_support.dart`, `test/parent_onboarding_test.dart`, `test/widget_test.dart`, `integration_test/live_auth_test.dart` (registration confirmation helper only), `integration_test/design_fidelity_fixture_test.dart`, `integration_test/design_capture_driver.dart`, `reports/evidence/ui_fidelity/**`.

Management: this report, `reports/WORK_STATUS.md`, `AGENTS.md`. Untracked `tasks/CURRENT_TASK.md` and `tasks/TASK_STATUS.md` were found on continuation as NOT_STARTED templates; preserved untouched and excluded from this feature checkpoint. Build APKs, raw PDF renders/OCR, logs and helpers remain ignored, never staged. Backend/Database/reference baselines are read-only; no deployment, push or history rewrite.

Staged review: 68 scoped files, including the intentionally requested 34 public Android PNGs, 10 widget PNGs and two licensed font binaries. Font SHA-256 matches the provenance manifest; no APK/log/key/environment file or reference artwork staged. No high-risk credential signature found in new text; fixtures are synthetic. Authored-text whitespace check PASS; two verbatim upstream OFL line-21 trailing spaces are retained as the only `git diff --check` exceptions. No runtime API/auth/session/security implementation files were changed beyond the explicitly listed visual widgets.

Restoration: final normal `lib/main.dart` fixture APK install **PASS** (`Success`), replacing the integration harness without app-data wipe. First cold-launch wait timed out on the slow emulator although the activity resumed; follow-up `am start -W` returned **Status: ok**, PID 2843 and matching topResumedActivity. This is verified installation/resumption, not a clean cold-start performance claim. Original physical 1080×2400 / density 420 restored with no overrides. Existing Backend/Database services were never modified or stopped. The task-owned headless AVD is left running the regular fixture app. Local checkpoint hash/remaining known untracked templates are verified in the final handoff; no push.
