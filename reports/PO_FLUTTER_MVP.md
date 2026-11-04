# PO-owned Flutter mobile MVP — 2026-11-04

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
