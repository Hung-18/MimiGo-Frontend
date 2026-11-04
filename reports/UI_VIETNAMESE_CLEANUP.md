# Vietnamese mobile UI cleanup — 2026-11-04

Baseline `de096fb`; clean start on `feature/po-flutter-ui`. Focused presentation/legal-availability pass. No redesign, Backend/Database/Web CMS/cloud/`.mimigo` changes, activation, deployment or real account/child/payment mutation.

## Normal-screen review

| Area | Result |
|---|---|
| Welcome, login, registration, OTP/resend, session recovery | Vietnamese headings/actions/validation/loading; removed prominent staging instructions, mock OTP output and technical account descriptions. Normal identity fields remain blank |
| Account Terms | Metadata-only or placeholder Terms cannot be accepted. Shows an honest unavailable state; form/checkbox/submit do not collect an invalid registration acceptance |
| Child notices, profile entry/review, uncertain-request resume | Natural purpose names, dates and state labels. Unapproved/incomplete notices cannot enable consent or DOB entry. Version/hash metadata stays under optional details |
| Parent home, selection, private account/profile, PIN management | Vietnamese labels, state text and guidance; compact PIN explanation; private values remain gated. Removed internal session/profile vocabulary and repetitive engineering warnings |
| Curriculum, lesson/player, choices/feedback, completion/replay | Vietnamese controls/loading/empty/error states; localized display states and dates. Session/lesson identifiers and skill/revision metadata no longer occupy primary learning UI. Server-authored lesson/question/option content is not invented or rewritten |
| Premium, entitlement, checkout, profile edit | Vietnamese labels/status/timestamps; retained the necessary explicit **trial payment / no real money** notice. Removed raw SETTLED/FAILED, simulator jargon, API labels and version codes from primary actions |
| Platform controls | Flutter SDK `flutter_localizations` and Vietnamese locale; built-in Material navigation, editing and accessibility text follow Vietnamese. `intl` is its locked transitive dependency |

Shared mascot, garden, typography/fonts, colors, cards, navigation structure and growing child targets remain. Explicit legacy fixture/preview entry points remain outside the normal app; this report does not relabel sample data as real data.

## Errors and diagnostics

`user_messages.dart` centralizes safe Vietnamese guidance. It does not display arbitrary Backend messages. `ApiFailure` still retains code/status/requestId and the original response for debugging; an optional, initially collapsed **Chi tiết kỹ thuật** view exposes safe correlation details. No PIN, password, token or proof is logged or rendered by this work.

Errors still remain errors: no successful registration, saved answer, completion, entitlement or payment is inferred. Existing retry/readback behavior and identifiers remain unchanged. Tests now inspect the retained error object when checking exact error codes rather than requiring raw codes in the primary UI.

The diagnostic expansion and its selectable text have isolated storage buckets. This fixes a real bool/scroll-offset type collision found during testing when an error appears on a previously scrolled page. New tests cover opening details and resetting them for a different error.

## Legal and forthcoming-contract boundary

The current adapter receives Terms version/hash metadata and unapproved notice records, not a verified full legal document. **Normal registration and Terms re-acceptance are blocked while that remains true.** Current `R0_MOCK_TERMS_V1` is never rendered as valid Terms. Normal child consent is also blocked for unapproved/missing full notice content. Existing sign-in remains available.

`ApprovedLegalDocument` is a presentation seam for the forthcoming verified adapter, **not invented Backend JSON fields**. It requires full content, an approval assertion and matching version/hash, and rejects placeholder version codes. The current wire parser never populates it. Once the actual approved handoff arrives, an adapter can supply the document to the prepared readable/explicit-choice UI. Tests provide clearly test-only documents to retain coverage of valid future acceptance, version changes, identity checks and lost-response recovery.

Password recovery remains explicitly unavailable via the existing help dialog and centralized availability message. No reset endpoint, payload, OTP policy or success flow was invented. Registration/Terms API methods themselves remain unchanged; no mock legal acceptance is silently submitted.

This is a deliberate unavailable state, not a claim that Legal approved the current metadata. Future registration/password-reset integration still needs the exact approved contract and real acceptance testing.

## Validation

- `dart format`: changed sources/tests formatted.
- `flutter analyze --no-pub`: **PASS**, no issues.
- Full suite: **383 PASS**, **2 opt-in staging tests SKIPPED**.
- Focused Vietnamese/live/PIN suite: **31 PASS**; includes the seven new localization/legal/diagnostic tests.
- `flutter build apk --debug --no-pub`: **PASS**, normal live entry.
- Public widget render inspected: `reports/evidence/vi_cleanup/registration_unavailable.png`. This is synthetic public UI evidence, not a protected screen capture or live API acceptance.

Evidence: `vi_cleanup_regression.txt`, `vi_cleanup_targeted.txt` and `vi_cleanup_validation.txt` in `reports/evidence/`. Existing server-contract, refresh/proof, isolation, stable retry and acknowledgment-only learning/completion tests remain in the suite. No fresh authenticated staging E2E, emulator install, iOS run, manual PO acceptance or product-completion claim is made.
