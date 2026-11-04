# Pilot mobile delivery — 2026-11-05

Frontend only, `feature/po-flutter-ui`, baseline `d7660ce`. This delivery continues the working client; visual PO acceptance and real-family pilot authorization remain pending. No Backend/Database/cloud/reference edits, deployment, account provisioning or secrets.

## Sources reconciled

- **FOUND and inspected:** `D:\Documents\THIẾT KẾ GIAO DIỆN CÁC MÀN-20261021T165523Z-1-001.zip`. All **28/28** PNG entries match the extracted `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/` baseline by SHA-256. Reviewed the complete contact sheet and individual Welcome, registration, OTP, child-profile and branding boards. A second 28-board archive exists at `D:\Projects\MimiGo\UI-References\THIẾT KẾ GIAO DIỆN CÁC MÀN-20261104T095728Z-1-001.zip`.
- **FOUND and inspected:** `D:\Documents\MimiGo – Phân tích UI & Đặc tả BA theo màn hình.pdf`, 81 pages; byte-identical to `.mimigo/ba/MimiGo_BA_Handoff_R0_v0_1/04_References/MimiGo_BA_UI_81_pages.pdf` (SHA-256 `b5cc7aaa386aa8c458f48e0e6cc189bd7389812740f4dd09d58c559142a22960`). Rendered cover, palette/accessibility and onboarding pages with Windows PDF renderer; reviewed pages 1 and 7–15. Source PNGs also provide the full frames split across PDF pages.
- **NOT FOUND as a ZIP:** `04_References/MimiGo_UI_28_PNGs.zip` in the actual handoff/reference, `D:\Documents`, Desktop or Downloads searches. Its 28 extracted reference boards are available and verified against the original archive above. No archive-review claim for this missing filename.
- Read `MOBILE_PRODUCT_EXPERIENCE_R2.md`, `MASCOT_ACCEPTANCE_FIX_R2.md`, `UI_UX_FIDELITY.md`, project mascot/provenance and current legal OpenAPI/DTO/service implementations. Four latest PO screenshots were not separately attached or identified among mounted handoff files; their written direction is applied, without claiming exact comparison to unidentified images.
- Reference boards are comparison material, not shipped artwork. Newly generated original garden and six-domain atlas are bundled in `assets/scenery/`; exact built-in imagegen prompts/provenance are in [asset notes](../assets/scenery/README.md). Existing Mimi atlas and offline OFL Baloo 2/Nunito remain.

## Reference → implementation

Board numbers resolve through [existing inventory](evidence/po_reference/inventory.txt). All rows are implementation comparisons, **not PO visual approval**.

| Journey | Actual reference | Result and intentional contract differences |
|---|---|---|
| Welcome | 22, BR1 26; BA A01 | Dimensional blue-sky garden, foreground flowers/depth/light, large waving Mimi, short navy headline, warm white copy, pink account action and blue sign-in. Plain text brand retained; no unlicensed 3D logo or scientific-safety claim. |
| Registration/sign-in/recovery | 01; shared BR1 typography | Rounded white forms over quiet scenery, companion header, consistent spacing/validation/buttons. Working email/password and server reset only; no Google/Apple controls. Registration remains unavailable without actual approved Terms. |
| Email/reset OTP | 27 | Garden/Mimi header, six rounded cells, pink confirmation and blue resend treatment. One native editable field retains paste/delete/autofill and one semantic target. Absolute original-code expiry plus real deadline countdown; no invented expiry after resend ACCEPTED. |
| Privacy → child profile → review | 03, 02, 11; BA A06/A07 | Three-step Parent trail, garden guide, white form, nickname, mandatory editable/calendar DOB and existing stock-avatar keys. No added gender/full-name contract, child cap or age-based profile rejection. Current Backend still requires SYN- aliases; helper makes that limitation explicit. |
| Parent Home/settings/protected history | 09, 14, 24; BR1 | Shared garden/white surfaces and child-selection cards; retained real workspace/detail selection, Gate and protected history. Screenshot ages, aggregates and charts are not fabricated. Protected windows are never captured. |
| Child Home/curriculum/program discovery | 28, 18, 08, 12, 15, 25 | Six substantial dimensional picture destinations replace flat marks; same canonical order/code mapping, returned names/availability and locked empty domains. Quiet surfaces keep text readable. Parent exit remains gated. |
| Lesson/player/feedback | 21, 13 | Shared environment surrounds retained single-question flow, large choices/count pictures, media pause/state handling and acknowledged explanations. Lesson text/content/timing remains server-owned; new drag/matching/sorting schemas are not invented. |
| Completion/replay/error | Exact C03/C05/error frames absent in BA crosswalk | Existing joyful companion and rounded confirmed-completion/replay presentation retained; shared scenery now matches character shading. No celebration before acknowledgment, scores or invented progression. Exact missing-frame fidelity remains **BLOCKED**. |

## Implementation and behavior

- Reused `PoGarden`, `GardenScene`, `PoDomainMark`, `Frame`, `PoScaffold`, existing buttons/cards and error components. Added `StorybookBackdrop`/`StorybookSurface`, `OnboardingTrail`, `SixDigitCodeField`, `CodeExpiry`; replaced old flat garden/domain painters with two bundled atlases. Background uses a Material/Ink surface so ListTile interactions stay visible.
- Preserve all seven established `MimiMood` poses: idle, greeting, guide, thinking, correct, encourage, completion. Existing bounded 1.4-second hover/tilt, reduced motion, lifecycle/TickerMode guards and disposal are retained. No continuous particles, network art or new animation engine. Artwork is decorative, excluded from semantics; companion keeps contextual labels.
- Forms retain scroll/keyboard handling, safe areas, adaptive widths, enlarged type and existing 64dp-growing child targets. DOB calendar supplements manual entry and preserves the existing date range; server decides age/lesson eligibility. Child/profile attempts, proof/vault/token isolation, immutable retry IDs, completion/replay identities and account-return clearing are unchanged.
- Legal adapter now consumes the authorized `terms.document` and approved notice `document` from reference, attempt and resume responses. It checks Boolean approval, required strings, markdown format, language, enclosing version/hash and **SHA-256 of UTF-8 body with CRLF→LF normalization**, matching Backend `LegalDocumentHash.Compute`. Missing documents remain unavailable; malformed/unapproved-with-document/hash-mismatched content raises `ApiInvalidResponse`. Duplicate purpose snapshots remain rejected. No client approval flag, fake legal row, cached consent or current-reference substitution for an attempt snapshot.
- Added `crypto 3.0.7` (cached/offline resolution) for digest validation. Test-only legal documents stay under `test/`; no test legal content is imported by normal application code.

## Verification

| Check | Result |
|---|---|
| `flutter analyze --no-pub` | **PASS**, no issues |
| `flutter test --no-pub --reporter expanded` | **428 PASS / 3 opt-in SKIPPED**, final 35s test phase; 402 retained + 26 legal/input regressions |
| Focused legal/code/recovery/onboarding | **43 PASS** |
| Actual client → staging reference | **1 PASS / 1 authenticated SKIPPED**; GET 200, approved Terms unavailable, **0/5** usable approved notice documents |
| Public staging recovery boundary | **1 PASS**; malformed-input request **400 INVALID_EMAIL**, confirm **400 INVALID_RESET_CODE**, reference **200**. No mail/account/credential write. |
| Android debug build | **PASS**, `flutter build apk --debug --no-pub`, normal entry; Gradle 21.3s |
| Android public synthetic navigation/captures | Final **1 scenario PASS**, 40s, **16 captures reviewed**, API 37 / emulator-5554; typed OTP retention, recovery, independent Privacy choices and unsent profile review included |
| Android native Gate/security regression | Final **2 PASS**, 35s test phase, 21.7s Gradle: real Keystore vault and independent FLAG_SECURE leases; MOCK HTTP Parent enrollment/proof/private reads, child-token completion/replay, two-child switch, PIN exit and revocation cleanup. Historical English session assertion corrected to current Vietnamese; no runtime authorization change. |
| Authenticated staging reopen/logout/login/child-scoped persistence | **BLOCKED / NOT_RUN**: approved existing test identity/PIN/content workflow unavailable; no credentials sought from secret stores |
| Real registration/OTP mail/reset completion/real-child onboarding | **BLOCKED / NOT_RUN**: valid approved legal release and controlled mailbox/identity prerequisites |

The first suite exposed a shared-background Material assertion, corrected with Material/Ink. OTP replacement also required the recovery test to settle keyboard scrolling before tapping; assertions and server-confirmed-return checks are retained. Historical screenshots generated automatically by tests are not new live evidence.

Android captures are public synthetic widgets with a permanent test footer and `screenProtected == false` asserted before **every** capture. They exercise actual Flutter widgets with isolated test responses, not a Cloud account or stored production records. The capture harness covers welcome/sign-in action, unavailable and test-document registration, OTP rendering and retained typed digits, recovery/code form, independent unchecked Privacy choices, child form/unsent review, seven mascot states, Parent selection, returned-domain action, question/acknowledgment/completion/replay. No Gate/private screenshot or FLAG_SECURE override. Debug emulator skipped-frame/ImageReader messages are not release performance evidence. iOS/physical-device/TalkBack acceptance is **NOT_RUN**.

Reviewed captures: [Welcome](evidence/pilot_delivery/pilot_welcome.png), [Register](evidence/pilot_delivery/pilot_register.png), [unavailable Terms](evidence/pilot_delivery/pilot_registration.png), [sign-in](evidence/pilot_delivery/pilot_login.png), [OTP](evidence/pilot_delivery/pilot_otp.png), [recovery](evidence/pilot_delivery/pilot_recovery.png), [reset code](evidence/pilot_delivery/pilot_reset_code.png), [Privacy](evidence/pilot_delivery/pilot_privacy.png), [child onboarding](evidence/pilot_delivery/pilot_child_onboarding.png), [profile review](evidence/pilot_delivery/pilot_profile_review.png), [Parent Home](evidence/pilot_delivery/pilot_parent_home.png), [Child Home](evidence/pilot_delivery/pilot_child_home.png), [lesson](evidence/pilot_delivery/pilot_lesson.png), [feedback](evidence/pilot_delivery/pilot_feedback.png), [completion](evidence/pilot_delivery/pilot_completion.png), [seven mascot states](evidence/pilot_delivery/pilot_mascot_states.png).

An intermediate rerun was interrupted after an overlapping normal build could replace the test APK during slow installation. Subsequent emulator activity/package calls also timed out; a data-preserving Android reboot restored services. Final tests run serially with the correct APK. No emulator data wipe, shared Backend restart, security override or failed-attempt-as-PASS claim.

Final regular live-only `lib/main.dart` rebuild/install/launch **PASS**, `flutter run -d emulator-5554 --no-resident --no-pub`, exit 0. The emulator is left with the normal app, not an integration/fixture target. Native mock tests clear their vault/session in teardown. No real authenticated staging operation was performed.

Reproduce: `flutter drive --driver=integration_test/pilot_delivery_driver.dart --target=integration_test/pilot_delivery_test.dart -d emulator-5554 --no-pub`; native security: `flutter test integration_test/parent_gate_native_mock_test.dart -d emulator-5554 --no-pub --reporter expanded`. Restore the normal entry with `flutter run -d emulator-5554 --no-resident --no-pub`. Actual staging checks use `flutter test test/live_staging_acceptance_test.dart --no-pub --dart-define=MIMIGO_VERIFY_PUBLIC_STAGING=true`, and the existing `MIMIGO_RUN_PUBLIC_RECOVERY_PROBE=true` malformed-input probe. Authenticated tests stay opt-in and require explicit owner credentials/workflow.

## Backend/operator handoff

1. Legal/Cloud: deploy approved non-placeholder Terms and all required purpose notices with hosted, hash-matching documents and authorized release configuration. Staging currently still supplies unavailable Terms/notice documents. The client accepts the documented additive fields and never enables agreement from metadata alone.
2. Backend: `PrivacyService` can attach legal documents to `/privacy/onboarding-reference`; inspected `ChildService` begin/resume `ToDto` paths omit them. Supply approved documents **bound to the exact attempt snapshot** through those existing response DTO fields. The client is ready for them; copying a possibly newer public notice into an old attempt would be unsafe.
3. Backend/PO: current `ChildService` still enforces `SYN-` aliases. Real-family nickname release needs verified server authority; frontend does not silently strip/fabricate a synthetic prefix. Guardian policy/consent release remains an owner gate.
4. Operator: provide an explicitly authorized existing synthetic Parent/PIN/children and eligible published lesson/media for fresh authenticated Android persistence acceptance. Earlier disposable real acceptance is historical; no new cluster, Backend flag, migration or existing Dev API restart is authorized here.
5. Recovery routes now validate input on staging; controlled mailbox delivery and valid-code redemption remain unverified. Media delivery/content rights and new interaction schemas remain Backend/content dependencies. Real payment-provider behavior is outside the supported simulator contract.

Production, Legal, Security, Content and manual PO acceptance remain open. This report does not declare a completed real-user pilot.
