# PO-owned Flutter mobile MVP — 2026-11-04

Latest functional disposition: [pilot status matrix](MOBILE_PILOT_FUNCTIONAL_STATUS.md), baseline `f02a431`. Real reset UI/contract is now integrated; staging recovery is locked. Legal/pilot gates and fresh authenticated live acceptance remain open. Earlier “recovery contract absent” statements below are historical.

Latest presentation/legal disposition: [Vietnamese cleanup](UI_VIETNAMESE_CLEANUP.md), from `de096fb`. Normal registration/Terms acceptance now fail closed for placeholder/metadata-only legal content; unapproved child notices cannot collect consent. Earlier API integration remains, but its availability statements do not override this new legal-content guard. No new authenticated live acceptance is implied.

## Current: real Backend integration correction

This section supersedes the preview-first delivery below. Baseline `9155da3`, branch `feature/po-flutter-ui`. **The app is not claimed complete or authenticated-live-accepted.** Normal `lib/main.dart` always selects `LiveMimiGoApi`, staging URL and the secure Parent Gate session coordinator. Environment fixture/Gate-off switches cannot turn the normal entry into the demonstration or legacy bearer-only app. This client-only correction follows the new PO instruction; it does not activate Backend flags, migrations or cloud services.

### Local/synthetic path audit

| Source | Current disposition |
|---|---|
| `FixtureMimiGoApi` in `main.dart` | Retained regression adapter, never selected by `fromEnvironment()` or a network failure |
| `preview_app.dart`, `preview_state.dart`, `preview_learning.dart` | Historical source/tests only, no normal import or route. Sample children, generated local OTP/PIN and local `completed` list are not account/progress data |
| `mobile_demo.dart`, fixture content sources, CircleDemo | Original regression fixture only; no normal Gate-enabled navigation into these activities |
| `fixture_main.dart` | Explicit separate regression entry, not a user menu or normal mode define |
| `LearningSessionMemory` / `PendingLearningAnswers` | Real acknowledgment/readback coordination only; stable event/payload retries, child/account-scoped memory. Not durable or complete history |
| Native credential vault | Existing API-bound refresh bundle only; proofs/access/Child tokens in memory, no persisted password/PIN |
| Screenshots and preview evidence below | Historical public synthetic UI evidence; never proof of live persistence |

### Implemented correction

The PO garden/bee/cards/fonts remain shared. The welcome no longer links to new preview or registration walkthroughs. Normal registration name and child alias start blank. Generic engineering/demo banners and development/demo lesson labels are absent from normal screens; genuine server/legal staging notices remain truthful.

`LiveChildHome` loads the authenticated Child-context curriculum, uses returned domain names and availability, and routes into Domain → Topic → Lesson discovery. Missing content shows a real empty state, unavailable framework areas are locked, and errors clear stale catalog data. It has no sample profiles, featured local lessons or local progress state.

Current candidates support server-authorized `FREE` and `CORE`; removed the old Free-only catalog/detail rejection. No local Premium unlock was added. The current Core contract says the Parent workspace counts Free only: an active child's **known** outside-program-age workspace status may enter a PIN-authorized Child context to check previously purchased Core scope there. This grants no lesson or new purchase; unknown/denied/inactive remains closed. Learning APIs remain authoritative for age, consent, publication and purchased scope.

Real lesson/revision/cue/option/session IDs feed the existing start, answer, recorded-answer readback, bodyless complete and fresh-session replay APIs. Complete/endedAt require the server acknowledgment. Generic interactive choices render actual returned cue/options; no local story or answer key is inserted. Parent progress is the Gate-protected recent server session list with returned timestamps, never aggregate scores or preview memory. Answer-level session readback remains Child-only according to the current contract.

Protected settings display the authenticated Parent account. Versioned alias/avatar management keeps fresh profileVersion, strong If-Match, UUID idempotency key and locked unknown-outcome retry; existing nullable avatars are supported, DOB is never sent. Premium uses server prices/scope/eligibility/rights and explicit simulator receipts. Added owned-checkout GET readback for pending/expired/unknown outcomes and a fresh quote only after confirmed terminal status. Real payments remain unavailable.

Logout cancels outstanding native requests before serialized server logout. Transport generation guards reject late responses; cancellation never claims a server write was rolled back. Parent recovery/login also reject stale account/session results. Timeouts accommodate Render cold starts. Native storage, serialized refresh, proof expiry/background cleanup, Child tokens, stable answer retries and FLAG_SECURE remain intact.

### Per-feature status

| Feature | Status | Evidence / remaining prerequisite |
|---|---|---|
| Public current-Terms/notices read through Flutter client | LIVE_E2E_PASS | Actual staging GET; metadata only, not registration or learning acceptance |
| Invited Parent register and OTP verify/resend | API_INTEGRATED_NOT_VERIFIED | Exact candidate, real form/resend APIs; authorized OTP-capable mailbox still needed |
| General registration | BLOCKED_BACKEND | Current staging handoff reports invitation/provider restrictions; returned codes shown accurately |
| Login, refresh, restore, logout | API_INTEGRATED_NOT_VERIFIED | Normal secure session path and cancellation regressions; no approved runtime account supplied |
| Parent account/protected information read | API_INTEGRATED_NOT_VERIFIED | Actual `parents/me` data; no sample account |
| Parent account/email/password editing | BLOCKED_BACKEND | No supported available mutation contract; password-reset route locked |
| PIN enroll/verify/change/reset and Child transitions | API_INTEGRATED_NOT_VERIFIED | Existing exact candidate/proof/native security path; no real PIN attempt or flag activation here |
| Child notice/creation/recovery, roster/detail, alias/avatar edit | API_INTEGRATED_NOT_VERIFIED | Real ids, notice choices, versions and idempotency; no child created or edited here |
| Eligible Free/Core discovery and lesson detail | API_INTEGRATED_NOT_VERIFIED | Live home, current Core decoding and private-read/navigation tests; not authenticated staging evidence |
| Published eligible staging content | BLOCKED_CONTENT | Handoff has no confirmed published inventory; account/content scope needed to establish current availability. No lesson manufactured |
| Session start/answer/complete/replay/readback | API_INTEGRATED_NOT_VERIFIED | Real endpoints and acknowledgment checks; no authorized staging learning write run |
| Durable Parent history/progress | API_INTEGRATED_NOT_VERIFIED | Protected server list; cross-login persistence harness implemented, not run without approved identity/content |
| Plans, entitlement, simulator quote/settlement/status | API_INTEGRATED_NOT_VERIFIED | Real protected transport/quotes/receipts; no transaction created here |
| Cloud video/audio | BLOCKED_BACKEND | Handoff has Media OFF/R2 delivery dependencies. Existing local authorized native player preserved; storageRef never treated as URL |
| Content-specific matching/counting beyond returned cue/options | BLOCKED_CONTENT | No approved typed activity/media supplied; generic real cue choices work without inventing content |
| Privacy/DOB rights, real payment | BLOCKED_BACKEND | Staging/policy restrictions remain; no bypass or false success |

None of the private features can be called LIVE_E2E_PASS from mocks, compilation, old local acceptance or 400/401 probes. No complete-product acceptance is claimed.

### Acceptance harness / current evidence

`test/live_staging_acceptance_test.dart` separates public metadata verification from an opt-in existing-account journey. Credentials use only the operator runtime environment, never source/defines/logs. It checks ownership of an existing `SYN-` child and the actual Child catalog. Explicitly authorized learning writes require a returned approved lesson ID, submit actual cues/options, complete, logout/login, then verify the identical completed session/endedAt from protected server history. It uses no local learning cache as persistence evidence and creates no accounts/children/billing transactions.

Real public client check: **1 PASS** (29 seconds). Authenticated acceptance: **1 SKIPPED**, no authorized runtime identity supplied. Final full suite: **376 PASS / 2 opt-in staging tests SKIPPED**. `flutter analyze --no-pub`: clean. `flutter build apk --debug --no-pub`: **PASS**, exit 0, 23.3s Gradle, normal live-only entry with no API mode or Gate define. Contract/navigation evidence is in `live_integration_regression.txt`; public evidence in `live_staging_readonly.txt`. These do not replace Android device, iOS, mailbox/OTP or authenticated Backend acceptance. All preview-build evidence below is historical.

## Historical delivery at 9155da3

Branch `feature/po-flutter-ui`, clean starting checkpoint `bbbf461`. The PO explicitly authorized this implementation, commit and feature-branch push. No main checkout, merge, reset, deployment, sibling repository or `.mimigo` write. The prior API implementation, secure native storage, tests, fixture demonstration, Android/iOS projects and shared Baloo 2/Nunito design tokens remain intact.

## Delivered presentation

`lib/po/` contains a separate PO presentation and a network-free preview state model. It uses the existing Flutter/Material navigation and state primitives; no package or architecture migration. The application entry has a short bee splash and a Vietnamese welcome. The default fixture build offers the new family experience first; the original fixture flow remains available for regression and integration review.

Original Flutter vector bee, garden, fruit, animals and flower avatars provide a consistent identity without extracting copyrighted artwork from boards or relying on emoji fonts. The design extends `mimigo_design.dart`: warm cream, mint, sky, lavender and peach surfaces, pink primary actions, plum accents, 28–32dp corners, rounded cards, offline Baloo 2 headings/Nunito body, and large controls. Parent presentation is calm; Child presentation emphasizes illustrated choices and six learning areas. Content scrolls under the keyboard and at 320dp / 200% text size.

### Screen inventory

| Area | Implemented navigation and behavior |
|---|---|
| Entry | Splash → welcome → new preview / synthetic registration walkthrough / retained fixture / API registration or login according to build mode |
| Registration preview | Validated form, unchecked acknowledgment, random memory-only synthetic OTP, wrong-code feedback, resend countdown, explicit walkthrough completion with no account-created claim, family-size view |
| Live identity | Retained current-Terms loading/review, registration, six-digit verify, returning login, session recovery, secure refresh rotation and logout; new contract-backed resend countdown and staging restriction messages |
| Family preview | Select child, independently review notices before creating each sample profile, add/edit sample alias/avatar, sample age, PIN setup/verification before Child entry and Parent return |
| Live family | Existing server-authorized roster, child notice/creation/idempotent recovery, child selection, server age/eligibility/catalog/learningEntry checks, protected details and session history; new protected alias/avatar edit panel |
| Parent preview | Family dashboard, account information, settings, local preferences, privacy information, activity list from this preview only, Premium comparison/term choice/summary |
| Parent Gate | Existing real six-digit enroll/verify/change/reset, step-up, lockout, expiry/background handling and native protection retained. Preview has a separately labeled memory-only PIN practice screen; system Back from Child preview also requires it |
| Child preview | Personalized home, six subject landings, lesson detail, video unavailable state, activity play, wrong/correct feedback, completion and replay |
| Preview interactions | Counting 1–3 apples; word-to-animal matching; Hello in Vietnamese context; ordered handwashing steps; round/square classification; aquatic-animal choice. Every choice responds locally; no real Learning completion is manufactured |
| Live learning | Existing nested returned curriculum, revision detail, Child-context sessions, server answer feedback, stable clientEventId retry, readback, all-cue completion and fresh-session replay retained |
| Premium API | Explicitly opened only inside protected Parent Area after choosing a child: plans, allowed terms, server prices/versions, eligibility, entitlement, immutable same-key quote retry, SETTLED/FAILED simulator commands, confirmed results. No real payment channel |

No account/billing/privacy routes were added to Child Mode. Preview preferences do not claim audio playback or schedule device notifications. English Companion is an embedded expression in Vietnamese learning, never an app-wide locale switch. Preview activities are illustrative, not approved published content or age suitability decisions.

## Reference-to-screen mapping (28/28)

All originals were extracted to ignored `reports/evidence/po_reference/01.png` … `28.png` for inspection. The external ZIP remains the source. Tracked `inventory.txt` preserves exact filenames/dimensions; `contact_sheet.jpg` provides a compact review of all 28. Original boards are references, not shipped application assets. The mapping describes inspiration, not pixel-perfect fidelity acceptance.

| # | Reference | Classification → implementation |
|---|---|---|
| 01 | Màn hình đăng ký phụ huynh MimiGo | Screen → registration, garden header, pink CTA |
| 02 | Hồ sơ bé vui nhộn MimiGo | Alternative profile → family cards, profile summary |
| 03 | Giao diện tạo hồ sơ bé MimiGo | Screen → independent notice review, sample/profile form |
| 04 | Bảng Tiến Bộ Của Bé Bảo Anh | Screen inspiration → honest activity list / protected server history; no invented aggregate scores |
| 05 | Khám phá thế giới cùng bé | Screen → discovery domain and subject landing |
| 06 | Bảng ý tưởng thương hiệu MimiGo vui nhộn | Branding → bee, warm palette, rounded typography |
| 07 | Ứng dụng học tiếng Anh cho bé | Screen → English Companion context; canonical rules replace standalone-language assumptions |
| 08 | Ứng dụng học Toán vui nhộn cho bé | Screen → math landing and counting activity |
| 09 | Ứng dụng học tập vui nhộn cho bé | Component/alternative → child selection and learning cards |
| 10 | Gói học vui nhộn cho bé MimiGo | Screen → Free/Core comparison, term selector; board prices omitted |
| 11 | Màn hình hồ sơ bé MimiGo vui nhộn | Alternative form → avatar/name fields and server profile |
| 12 | Góc của bé_ Khám phá ngôn ngữ | Screen → language landing and animal-word match |
| 13 | Bài học đếm táo vui nhộn | Interaction → original vector apple counting with feedback |
| 14 | Cài đặt ứng dụng học tập cho bé | Screen → Parent settings; account controls kept out of Child Mode |
| 15 | Góc của bé_ Tư duy logic vui nhộn | Screen → logic landing and shape classification |
| 16 | Giao diện chọn số lượng bé đáng yêu | Screen → family-size preview without five-child cap or automatic consent/creation |
| 17 | Tạo tài khoản thành công cùng chú ong vui vẻ | Screen → honest preview walkthrough finish; real success remains acknowledgment-driven |
| 18 | Ứng dụng học tập bé Bảo Anh | Alternative → lesson list/detail hierarchy |
| 19 | Giao diện đăng ký gói học MimiGo | Screen → Premium summary and protected simulator panel; no unapproved commercial prices |
| 20 | Góc của bé_ Kho video yêu thích | Screen → video-library unavailable state; existing authorized player retained |
| 21 | Bài học đếm số vui nhộn 1-2-3 | Alternative interaction → 1–3 choices and continuation |
| 22 | MimiGo_ Cùng Mimi khám phá-Trang chủ | Screen/branding → splash, welcome, garden, bee |
| 23 | Hồ sơ bé pastel đáng yêu | Alternative → pastel profile and activity cards |
| 24 | Màn hình cài đặt ứng dụng học tập trẻ em | Alternative → settings, privacy, subscription and logout |
| 25 | Giao diện học kỹ năng sống cho bé | Screen → life-skills landing and ordered handwashing |
| 26 | Bảng thương hiệu MimiGo vui nhộn | Branding alternative → shared bee/vector family |
| 27 | Nhập Mã Xác Nhận Cùng Ong Con | Screen → six-digit OTP, resend/loading/error states |
| 28 | Ứng dụng học tập vui nhộn cho bé _1222 | Alternative → personalized Child home and featured activity |

## FE / API integration matrix

Contracts read from the local Backend's current candidates and `docs/deploy/STAGING_FE_API_AVAILABILITY.md`; that handoff is operator evidence, not a fresh authenticated Frontend run. Its 400/401 probes are not described as functional acceptance.

| Surface | Frontend integration | Current evidence / limitation |
|---|---|---|
| Health / onboarding-reference | GET public staging | Fresh read-only requests: both 200 JSON; no authenticated/business conclusion |
| Register / verify / login / refresh / logout | Existing identity/session client retained; live registration now accepts ordinary email syntax instead of forcing `.test`; staging allowlist still authoritative | Mock/unit regressions; no mailbox or account created in this session |
| Resend `POST auth/mock-email/resend` | Added uniform ACCEPTED parsing, returned cooldown, retry-after and safe error handling | Candidate contract + tests; no live resend submitted |
| Workspace / child notices / creation / selection | Existing implementations retained | Existing automated coverage; no real child mutation |
| Parent Gate / protected history | Existing proof coordinator and native protection retained, default off | Existing expiry, denial, background and session-isolation regressions; no flag activation |
| `GET/PATCH children/{id}` | Added explicit protected alias/avatar editor. Fresh profileVersion → strong If-Match + UUID Idempotency-Key. Unknown retry locks version/body/key; conflict requires explicit reread | Contract/unit coverage; DOB edits remain unavailable; no live PATCH |
| Curriculum / lesson / sessions / answers / complete | Existing contract-backed implementations retained | Existing regressions; no new staging lesson or real completion claimed |
| Premium plans / eligibility / entitlement | Added protected reads and server price/scope display | SIMULATOR only; no access inferred from labels or client age |
| Premium checkout / synthetic-settlement | Added quote + stable retry, explicit simulator SETTLED/FAILED, acknowledgment validation, independent entitlement reread | Contract/unit tests; no staging checkout, settlement or entitlement created |
| Media | Existing native private local-debug player retained | Cloud media/upload unavailable; preview shows unavailable rather than fake video playback |
| Password recovery / Google / DOB / privacy rights | Explicit unavailable UI where relevant | Current staging restriction / unresolved policy; no invented request |
| Real payment / store billing / special programs | Unavailable | Finance/provider/legal and commercial approval required; preview grants nothing |

Billing and profile panels are opened by explicit Parent actions rather than automatically fetching unrelated private surfaces on profile selection. They run inside the existing protected screen, use the same serialized authorization/refresh mechanism, and disappear with the Parent proof. No protected screenshot was taken, no FLAG_SECURE change was made, and no secret is stored in new code.

## Run and review

Preview is the default build mode. From this repository:

```powershell
flutter run --dart-define=MIMIGO_API_MODE=fixture
flutter build apk --debug --dart-define=MIMIGO_API_MODE=fixture
```

Live staging is opt-in. Gate remains false by default, as required. A controlled staging build can explicitly enable the client candidate without changing Backend flags:

```powershell
flutter run --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=https://mimigo-api-staging.onrender.com/api/v1 --dart-define=MIMIGO_PARENT_GATE_ENABLED=true
```

Host-local Android development must override the base URL with `http://10.0.2.2:<port>/api/v1`. No UI endpoint editor, saved endpoint or silent fixture fallback was added. Existing media build defines remain unchanged. SDK cache access needed tool escalation because it is outside the repository; no SDK or dependency upgrade was performed.

## Validation and limitations

- `dart format`: completed for changed Dart sources/tests.
- `flutter analyze --no-pub`: **PASS**, no issues.
- `flutter test --no-pub`: **366 PASS** including retained integration/security regressions, six activity paths, mode-transition PIN navigation, API acknowledgment/identity/version checks and narrow/large-text rendering.
- `flutter build apk --debug --no-pub --dart-define=MIMIGO_API_MODE=fixture`: **PASS**.
- Android debug build with live staging URL and `MIMIGO_PARENT_GATE_ENABLED=true`: **PASS**, compilation only; no Backend flags changed.
- `git diff --check`: **PASS**.

Evidence logs: `reports/evidence/po_analyze.txt`, `po_regression.txt`, `po_build.txt`, `po_build_live.txt`. Public widget renders are under `reports/evidence/po_mobile/`; they are synthetic UI evidence, not Android device or live API acceptance. No Android device was attached during `flutter devices`; no fresh device install, iOS build or manual PO acceptance is claimed.

Exact missing six-digit PIN/privacy/completion/error reference fidelity remains **BLOCKED** as required by the existing governance. The new UI interprets the boards coherently and does not claim exact licensed artwork recreation. Full legal text/guardian verification, privacy rights, approved content/media delivery, real payment, production readiness and authenticated staging E2E remain external gates. Retained live API screens still include technical English/status details alongside Vietnamese primary entry/navigation; further copy polish can continue without replacing their security behavior.

See [continuation](PO_FLUTTER_CONTINUATION.md) for the remaining concrete handoff.
