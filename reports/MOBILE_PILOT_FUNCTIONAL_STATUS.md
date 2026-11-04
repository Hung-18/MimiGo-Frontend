# Mobile functional completion — 2026-11-04

Baseline `f02a431`, `feature/po-flutter-ui`. **NOT READY for a real-parent/real-child pilot.** No usable account was fabricated or provisioned. No authenticated Cloud journey passed in this slice. Existing visual identity, mascot, native screen protection, secure refresh vault, memory-only proofs and server-backed Learning remain intact. Backend, Database, Web CMS, `.mimigo` and Cloud resources were read-only.

## Implemented and reviewed

The requested Markdown reset handoff does not exist in the local Backend checkout. Read its actual `docs/api/PASSWORD_RESET_OPENAPI_CANDIDATE.yaml`, implementation and `reports/PARENT_AUTH_P0_COMPLETION_20261104.md`. Added the exact public request/confirm operations to the existing native HTTP transport: strict 202/200 and response-status validation, no bearer/proof, no mock OTP consumption, existing cancellation/timeouts/error envelope/Retry-After retained.

Login now opens a complete Vietnamese recovery route with the entered email preserved. Request acceptance opens six-digit code/new password/confirmation fields. It says **if eligible**, not “email sent”: the contract deliberately gives the same ACCEPTED answer for unknown, throttled, disallowed and delivery-failed accounts. Resend uses the same request endpoint after the returned cooldown; successful resend clears the old code. Invalid/expired/used code stays editable; failures never navigate to success. Rate-limit feedback, duplicate-request/back guards, disposable controllers/timer and 10–128-character validation are implemented. Only confirmed `PASSWORD_RESET` returns to login, clears the old login password and announces success. It does not auto-login. PIN is unchanged; the Backend owns all-session revocation.

Reviewed normal `Page` routing and the connected welcome/login/register/OTP/privacy/onboarding/resume/Parent Home/Gate/settings/Child Home/explorer/lesson/player/profile/Premium actions. Existing contract/security tests cover these routes. Normal entry remains live-only; historical fixture/demo entry is isolated. No frontend entitlement, generated lesson or local progress substitute was introduced.

## Screen/action status matrix

Primary status below is the current end-user journey, not a claim that a mocked test passed on Render. `INTEGRATED_NOT_VERIFIED` means implementation/contract tests exist but a fresh authorized authenticated Cloud run is absent. No complete journey qualifies as `REAL_API_E2E_PASS` in this slice.

| Screen / visible action | Status | Boundary / evidence |
|---|---|---|
| Welcome → login / registration, Back | INTEGRATED_NOT_VERIFIED | Normal routes connected; public reference GET through actual Flutter adapter PASS |
| Register form, reload Terms, submit | LEGAL_BLOCKED | Form/API/validation/recovery ready, but current placeholder/metadata cannot enable form acceptance or POST |
| OTP entry → verify → login | INTEGRATED_NOT_VERIFIED | Real verify/login; no invented code or mock display; requires lawful registration or authorized pending account |
| OTP resend / cooldown / retry | INTEGRATED_NOT_VERIFIED | Existing real resend candidate; controlled-mailbox restriction is not public product policy |
| Forgot password → request | BACKEND_BLOCKED | NEW integration; staging malformed request returns 503 CLOUD_SURFACE_LOCKED |
| Reset code / password / confirmation / resend / return | BACKEND_BLOCKED | NEW integration; staging confirm returns 503 CLOUD_SURFACE_LOCKED. Seven contract/widget tests PASS; no mail/reset/live-login claim |
| Login / session restore / refresh | INTEGRATED_NOT_VERIFIED | Existing coordinator/vault/serialized refresh; no authorized credentials supplied or account created |
| Terms re-acceptance / reload | LEGAL_BLOCKED | Requires full approved version/hash-bound document and fresh choice; no auto-replay of child creation |
| Parent Home / roster / selection / refresh | INTEGRATED_NOT_VERIFIED | Server workspace/detail, fail-closed entry status; never expose workspace openSessions |
| Parent Gate enroll / verify / change / password reset / recover | INTEGRATED_NOT_VERIFIED | Existing six-digit contract, step-up, memory-only proof, lockout/expiry; Child exit cannot bypass PIN |
| Child notices / guardian/purpose choices / DOB | LEGAL_BLOCKED | Unapproved/missing full notices cannot enable choices or DOB entry |
| Child review / create / uncertain retry / attempt resume | LEGAL_BLOCKED | Real attempt/version/key contracts retained; unknown write retries identically, roster check on uncertain outcomes |
| Child profile detail / alias/avatar save / retry | INTEGRATED_NOT_VERIFIED | Protected server detail, strong version/If-Match/key, no DOB patch |
| Parent account view / PIN / revoke other devices | INTEGRATED_NOT_VERIFIED | Protected Parent-only area; account email/name edits not offered |
| Parent account email/name change | NOT_IMPLEMENTED | No verified edit contract; accurately unavailable copy rather than dead submit |
| Consent withdrawal / sensitive privacy requests | NOT_IMPLEMENTED | Deliberately unavailable; no invented guardian/recovery/privacy policy |
| Enter Child / return to Parent / choose another child | INTEGRATED_NOT_VERIFIED | PIN/context token transition, server eligibility; no Child account/billing controls |
| Child Home / refresh / domains / topics / lesson detail | INTEGRATED_NOT_VERIFIED | Actual nested child curriculum only, canonical Vietnamese labels; empty/locked states retained |
| Free / entitlement-protected Core discovery | INTEGRATED_NOT_VERIFIED | Server access authoritative; no local Premium unlock or fabricated age eligibility |
| No eligible/published lessons | CONTENT_BLOCKED | Genuine empty state where returned. No authenticated catalog was available to establish staging publication coverage |
| Lesson video / play / pause / cue timing | BACKEND_BLOCKED | Existing restricted local private-media integration preserved; no verified staging delivery contract/source. Opaque storageRef is never treated as playable URL |
| Lesson start / interactive choices / answer retry/readback | INTEGRATED_NOT_VERIFIED | Real lesson/cue/option/session IDs; server feedback, stable clientEventId/payload; generic rendering of real choices, no invented minigame content |
| Finish / completion feedback / replay | INTEGRATED_NOT_VERIFIED | Bodyless complete after every cue answered; server status/endedAt only; replay creates new server session |
| Return later / Parent recent history / refresh | INTEGRATED_NOT_VERIFIED | Gate-protected server history (up to 20), not cached complete history or aggregate scores; fresh authenticated persistence journey still required |
| Premium plans / eligibility / entitlement / quote / receipt | INTEGRATED_NOT_VERIFIED | Server price/scope/rights; protected simulator explicitly labeled, no real payment |
| Real payment / automatic renewal | NOT_IMPLEMENTED | Real processing disabled; no auto-renewal promise or action |
| Logout / expiry / reauthentication / pending cancellation | INTEGRATED_NOT_VERIFIED | Existing server logout plus local cleanup/cancellation, late-response guards, Child/account memory isolation retained |

Resolved `FRONTEND_DEFECT`: Forgot Password was a permanently unavailable dialog despite an existing handoff. Replaced it with the real flow. Removed the stale global “recovery unavailable” capability; only clients without a recovery adapter retain the truthful fallback. No other observed, independently fixable frontend defect was left open by this pass. This does not assert manual Android acceptance of every screen.

## Owner actions required before pilot

All paths below are relative to `https://mimigo-api-staging.onrender.com/api/v1`. These are prerequisites for owners, **not changes made or authorization to activate them**.

1. **Legal + Product + Database/Backend:** approve full Terms and child-purpose/privacy text and delivery mechanism; replace `R0_MOCK_TERMS_V1` lawfully. Backend report says `ck_terms_version_r0_not_approved` and `ck_notice_r0_not_approved` currently force unapproved rows, tables store hashes only. Owners need an approved forward release and a version/hash-bound full-document contract; `GET /privacy/onboarding-reference` metadata alone cannot provide readable approved consent. Current FE legal seam is ready for that adapter, not invented wire fields. Current R0 notice parser accepts unapproved snapshots only and must be updated with the approved handoff, not silently switched to real consent.
2. **Database + Backend/Cloud operator:** review/execute candidate 0070 under the owner's approved procedure, deploy reset implementation, set `Auth__PasswordResetEnabled=true` and `CloudSurface__PasswordReset__DatabaseMigrationDigest` to the approved 0070 digest. Existing Identity and Brevo provider/no-SandboxDrop prerequisites apply. Check `GET /health/ready`; readiness may report `CLOUD_PASSWORD_RESET_SCHEMA_MISSING`. Both `POST /auth/password-reset/request` and `/confirm` are currently locked in our probe.
3. **Email owner:** verify sender/domain, SPF/DKIM/DMARC and Render egress authorization, provider credentials/quota and authorized `EmailDelivery__Brevo__TestRecipients`. Recovery ACCEPTED never proves delivery. General recipients require owner approvals/`UnrestrictedRecipients` policy, not a Flutter bypass. Actual mailbox request → delivered code → confirm → login → old-session rejection remains unverified.
4. **Registration owner:** the current controlled path requires `CloudSurface__ControlledRegistrationEnabled`, real Brevo delivery and allowlisted mailbox; resend requires `Auth__ResendEnabled`. Real public registration flags `CloudSurface__RealParentRegistrationEnabled` / `Auth__RealParentRegistration` require the documented Legal/Security/EmailProvider/PrivacyNotice references and release. Do not enable them just to unblock this task. Actual routes are `POST /auth/register`, `/auth/mock-email/verify`, `/auth/mock-email/resend`, `/auth/login`, `/auth/sessions/refresh`, `/auth/logout`. Mock-email names are real contract paths, not mock frontend behavior.
5. **Privacy/Security/PO:** approve guardian verification, child-data purposes, retention/withdrawal handling and pilot participant procedure. No real-child onboarding until this is resolved. Parent email OTP alone is not guardian authority. Account availability does not imply child-data authorization.
6. **Backend/content owner:** retain authorized Identity/Parent Gate/ParentChild/Catalog/Learning groups; provide a separately authorized synthetic Parent/PIN/child and published eligible lessons. Protected endpoints include `POST /parent-gate/verifications`, `/child-contexts`; `GET /parents/me/learning-workspace`, `/children/{id}/curriculum`, `/children/{id}/lessons/{lessonId}`; `POST /children/{id}/learning-sessions`, `.../{sessionId}/answers`, `.../{sessionId}/complete`; `GET .../{sessionId}` and Gate-protected `GET /children/{id}/learning-sessions`. Verify complete → logout → restore/relogin → server history using that approved workflow, then repeat under lawful pilot conditions. No seed/publication/account mutation was authorized or performed here.
7. **Media owner:** activate/provide the verified private-media delivery handoff and published playable assets before video acceptance. Billing remains simulator-only; real payments are outside this pilot slice.

## Verification and limits

- `flutter analyze --no-pub`: PASS, no issues.
- Full suite: **390 PASS, 3 opt-in tests SKIPPED**; new reset suite **7 PASS**. Mock HTTP/widget tests are not Cloud E2E.
- Safe real Cloud probe: **1 PASS**; both reset routes 503 CLOUD_SURFACE_LOCKED, reference GET 200. Malformed email only, no account/email/password/child/payment mutation. `reports/evidence/pilot_public_probe.txt`.
- Existing actual Flutter public reference probe: **1 PASS, 1 authenticated test SKIPPED**. `reports/evidence/pilot_public_client.txt`.
- `flutter build apk --debug --no-pub`: PASS, exit 0, Gradle 31.0s; normal live entry. No fresh device installation, private screenshot, authenticated Cloud journey or manual PO acceptance claimed.
- No credentials, codes, tokens or raw private responses printed/persisted. The only synthetic values added are isolated unit/widget transport inputs.

Continue from this report: owners resolve legal/deployment/mail/content gates; supply approved test workflow; run authenticated Android persistence and recovery acceptance. Do not weaken unavailable states to produce a pilot-ready claim.
