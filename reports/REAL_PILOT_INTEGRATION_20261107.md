# Real Pilot Flutter integration - 2026-11-07

Continues feature/po-flutter-ui at 676f033. Existing 28-board design and completed screens retained; no repeat visual audit or new visual acceptance claim. User authorized this local commit. No push, deployment, Backend/Database/.mimigo writes, account provisioning, child creation, staff action or publication performed.

## Implementation delivered

- Normal app targets https://mimigo-api-pilot.onrender.com/api/v1 through the existing build-time configuration. Parent Gate remains mandatory for normal entry; legacy constructor defaults and explicit fixture entry retained. Parent/Child bearer separation, serialized refresh, API-bound platform refresh vault, memory-only proofs and logout/restore remain in place.
- Existing approved-document reader displays server Terms and separate version/hash-bound notices. Independent choices and guardian declaration remain unchecked. Live continuation additionally requires BOTH CHILD_PROFILE_AGE and LEARNING_PROGRESS snapshots. No public-current document is substituted into an attempt snapshot.
- Real nickname input and protected alias edit accept 1-30 characters and reject contact/URL shapes according to the pilot Backend validator. No synthetic prefix or identity inserted.
- Cloud creation/protected detail now accept omitted DOB and withheld age. Creation still checks returned identity/alias/avatar and any returned DOB against the immutable submitted request. Protected screens and success views omit unavailable age/DOB; no reconstruction or fabricated age.
- Private playback requests GET children/{childId}/lessons/{lessonId}/media with the current matching Child bearer for EVERY load/retry. Validates VIDEO/video MIME, asset identity presence, HTTPS URL and future expiry. Signed URL and context token remain memory-only. Storage/native player receives NO API Authorization header. Legacy local HTTP adapter stays debug/local-origin constrained. Lifecycle/session changes stop playback; interrupted loading can retry. Server media/consent errors have truthful Vietnamese presentation; native error URLs/headers never rendered.
- Existing server-filtered curriculum/lesson detail, idempotent answers, bodyless complete, endedAt/session identity, replay and gated persisted history retained. Completion remains server-confirmed. Existing denial/stale-response/account-isolation regressions retained; local memory is not a durable progress index. Consent withdrawal mutation/rights fulfilment is outside this requested state-handling slice; no new consent policy invented.

## Contract sources and live status

Read Backend docs/api/PILOT_FE_CONTRACT_DELTA_20261107.md, docs/deploy/REAL_PILOT_JOURNEYS_20261107.md and current V1Endpoints/ChildService/DTO legal/media implementations. No separate later pilot amendment file found in docs/api; current implementations checked for additive shapes.

The handoff's recorded unapproved-child-notice status is superseded by this task's real public GET: Terms approved + document present; exactly TWO approved notices with documents (CHILD_PROFILE_AGE, LEARNING_PROGRESS). Actual Flutter parser additionally validated approved availability and SHA-256 body hashes. This is public reference evidence only, not authenticated onboarding or legal/guardian-authority acceptance.

## Verification

- flutter analyze --no-pub: PASS, no issues.
- flutter test --no-pub --reporter expanded: 440 PASS / 4 opt-in SKIPPED (evidence/real_pilot_final_tests.txt); player suite 3 PASS. Subsequently added opt-in Pilot acceptance harness: 1 SKIPPED as intended without authorization; final analyzer clean.
- flutter test test/real_pilot_contract_test.dart --no-pub --reporter expanded --dart-define=MIMIGO_VERIFY_PUBLIC_PILOT=true: 7 PASS, including ONE real public Pilot GET; other cases are isolated transport tests, not real identities/media. Evidence: evidence/real_pilot_public.txt.
- New regressions cover normal pilot configuration, DOB/age omission, fresh Child grants, sibling refusal, no storage bearer, unsafe/expired grants, server 403/503 propagation, real nickname/contact rejection and native player session revocation.
- Initial suite failed only the historical staging URL assertion; updated to authorized pilot URL. A new test initially omitted await on its authentication helper; corrected before successful final checks. No assertions weakened.
- Android debug build: PASS, exit 0; final direct build 2,543ms Gradle, app-debug.apk produced. Initial PowerShell stderr warning wrapping obscured exit status; direct invocation verified exit 0. Redirection-only cmd wrappers were cancelled; no build failure is concealed.
- No fresh Android device/iOS/real media bytes/authenticated family E2E or manual PO acceptance claimed.

## Exact remaining integration issues and acceptance dependencies

1. Backend current ChildService.BeginAttemptAsync/GetAttemptAsync use static ToDto(NoticeRef), which emits notice metadata without document. Public PrivacyService attaches documents separately. The Flutter review correctly requires approved document bodies from the EXACT attempt/resume snapshot. Backend must deliver those version/hash-bound bodies on the attempt responses; public approval alone cannot unblock this path safely. This is source-verified; live authenticated attempt response NOT_RUN, so deployed parity remains to be confirmed.
2. Authorized real Parent + controlled mailbox/OTP and PIN workflow required to verify login/refresh/vault restore/revocation, separate child creation/selection and guardian declarations on Android. No supplied real credentials were accessed or manufactured. Public Terms/notices are now available; older staging legal-unavailable reports do not describe the Pilot public endpoint today.
3. Real staff/content owner must supply an age-eligible published FOUNDER_PILOT lesson with independently verified private video and rights clearance. New client grant/decoder path is implemented; actual signed object playback bytes and server cue timing require that content and authorized Child context. Frontend does not provision staff, clear rights or publish content.
4. With authorized participant/content, run create/select -> PIN Child entry -> returned curriculum -> signed playback -> answer every cue -> complete -> server readback -> logout/relogin -> gated history; verify same child/session/endedAt and sibling isolation. Then owner-prepared withdrawn-consent/expired-session cases. This acceptance is NOT_RUN; tests and historical local acceptance are not substituted.
5. iOS/physical-device/native playback and accessibility/manual visual acceptance remain NOT_RUN. Missing exact PIN/privacy/completion/error reference frames remain BLOCKED as already documented. No production, independent Security or Legal approval implied.

Implementation is complete for the available Flutter contracts; whole real-pilot acceptance remains OPEN with the explicit attempt-document handoff and owner-controlled runtime prerequisites above.

Pilot acceptance harness: test/live_pilot_acceptance_test.dart uses explicit MIMIGO_PILOT_EXISTING_ACCOUNT_AUTHORIZED=true and runtime MIMIGO_PILOT_TEST_EMAIL/PASSWORD/PIN/CHILD_ID, with no synthetic nickname assumption. It reads owned roster/protected history and Child catalog. Writes require separate MIMIGO_PILOT_LEARNING_WRITE_AUTHORIZED=true plus MIMIGO_PILOT_TEST_LESSON_ID; it records actual first-option answers, completes and verifies persisted session/endedAt after logout/login. Do not run learning writes without participant/operator authorization. Optional MIMIGO_PILOT_MEDIA_READ_AUTHORIZED=true checks fresh grant only, not video bytes/device playback. Harness remains SKIPPED/NOT_RUN against real participants.
