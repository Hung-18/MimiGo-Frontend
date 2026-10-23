# MimiGo Frontend work status

**Updated:** 2026-10-23<br>
**Current slice:** VS-02 — Frontend closeout<br>
**State:** CLOSED — scoped PO acceptance recorded from the PO's closeout instruction after Android Emulator testing. Acceptance covers synthetic authentication, ChildProfile flows and demo category navigation. This is not production-readiness approval.

## Acceptance and next focus

- Live-verified synthetic scope: register, mock email verification, login, `parents/me`, explicit consent/onboarding attempt, ChildProfile create/list/detail, replay/conflict handling and safe account return.
- Fixture-only scope: Logic's local shape mini-game and feedback. No Backend learning progress is claimed. All six categories navigate; the other five fixture categories and all live categories remain honest empty states.
- Closeout validation: `flutter analyze --no-pub` passed and `flutter test --no-pub` passed all 31 tests. Existing Android live/fixture evidence is preserved; Android scenarios were not rerun for this documentation/checkpoint-only closeout.
- The PO authorized a single clean local VS-02 checkpoint. No push, deployment or history rewrite is authorized.
- Next focus: **Learning Content & Learning Sessions**. Wait for the Backend's exact verified Learning API handoff before implementing any new endpoint, DTO, session or progress behavior.
- Closeout report: `reports/VS-02_FRONTEND_CLOSEOUT.md`.

## Boundaries

- Fixture is the default client mode. The original VS-01 no-media shape interaction is available under Logic and clearly labeled DEMO / FIXTURE; no demo progress is sent or saved.
- Live mode targets the documented `/api/v1` contract. Android tests verified registration, mock email verification, login, `parents/me`, consent attempt, child creation, returning sign-in, list and detail using the actual Development API.
- Parent PIN, consent withdrawal, Terms re-acceptance, token refresh/revocation and production email are not Backend-supported flows and remain unavailable in live mode.

## Configuration

Android Emulator local Backend: `--dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1`.

Exact Android Emulator command:

```powershell
flutter run -d emulator-5554 --debug --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:5187/api/v1
```

See `VS-02_FRONTEND_INTEGRATION.md` for implementation evidence, verification and blockers.

## Latest verification

- Landing page exposes both registration and **Already have an account? Sign in**.
- Registration verification and returning sign-in share `login` → `parents/me`; returning parents load their child list before entering the Parent Area. Selecting a child fetches authenticated detail.
- All six category controls are interactive; each category has a Back to Child Mode action. The Logic demo supports local triangle/circle feedback and Back to Logic/Child Mode; the Flutter system Back route follows the same hierarchy.
- Direct Parent Area navigation is disabled in Child Mode in both modes. Return to account entry asks for confirmation, clears the local token and account/child state, and requires a fresh parent login. This performs no server logout or revocation.
- `flutter analyze`: passed, no issues.
- `flutter test`: passed, 31 tests, including 14 new content/navigation/session checks plus the existing 17 authentication/fixture regressions.
- Android live integration test: passed, 1 scenario. Includes the existing authentication/consent/create/replay flow, all six live empty states, account-return cancellation/confirmation, local token clearing and a fresh login before Parent Area access.
- Android fixture integration test: passed, 1 scenario. Includes all categories, the Logic game and feedback, five honest empty states, Back navigation and account return.
- Normal live application was rebuilt, installed and launched with `flutter run ... --no-resident` after the test run.
- Published live learning content/progress and Parent Gate/step-up remain blocked by absent Backend endpoints. No speculative route or curriculum was added. Physical-device/iOS runs and recovery after a deliberately interrupted response remain untested.
- Latest evidence: `reports/evidence/VS-02.3_CHILD_NAVIGATION.md`; earlier authentication evidence remains in `reports/evidence/VS-02.3_ANDROID_LIVE_AUTH.md`. Test credentials stay in memory; reports contain no secrets.
