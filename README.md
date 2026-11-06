# MimiGo-Frontend
MimiGo mobile frontend and interactive learning player

PO-owned mobile experience: `feature/po-flutter-ui` (starting checkpoint `bbbf461`).

```powershell
# Normal app: Real Pilot API, secure sessions and Parent Gate
flutter run
flutter build apk --debug
```

The normal entry always uses the real API and Parent Gate. `MIMIGO_API_MODE=fixture` cannot select sample content in that entry. The default URL is `https://mimigo-api-pilot.onrender.com/api/v1`; override only with build-time `MIMIGO_API_BASE_URL`. Android Emulator host-local APIs use `10.0.2.2`, not `localhost`. API failures never select fixture data. Backend restrictions remain authoritative. Legacy fixtures have a separate regression entry `lib/fixture_main.dart`, with no normal menu link.

Read-only real staging verification (no account/child/transaction writes):

```powershell
flutter test test/live_staging_acceptance_test.dart --dart-define=MIMIGO_VERIFY_PUBLIC_STAGING=true
```

Authenticated acceptance is opt-in through the approved operator runtime environment, never credential dart-defines: `MIMIGO_STAGING_EXISTING_ACCOUNT_AUTHORIZED=true`, `MIMIGO_STAGING_TEST_EMAIL`, `MIMIGO_STAGING_TEST_PASSWORD`, `MIMIGO_STAGING_TEST_PIN`, `MIMIGO_STAGING_TEST_CHILD_ID`. It requires an existing `SYN-` child and creates no account or child. Learning writes additionally require `MIMIGO_STAGING_LEARNING_WRITE_AUTHORIZED=true` and an explicit `MIMIGO_STAGING_TEST_LESSON_ID`. Without authorization the authenticated test is **SKIPPED**, not a pass. The harness performs no billing writes.

[Implementation, screen inventory, all 28 references and API status](reports/PO_FLUTTER_MVP.md) · [Current validation](reports/WORK_STATUS.md) · [Continuation](reports/PO_FLUTTER_CONTINUATION.md).

Real Pilot public legal verification (read-only):

```sh
flutter test test/real_pilot_contract_test.dart --dart-define=MIMIGO_VERIFY_PUBLIC_PILOT=true
```

Pilot playback uses the Child bearer to obtain a fresh signed URL from the lesson media endpoint. Storage receives no API bearer. Grants stay in memory; retry requests a fresh grant. `MIMIGO_CHILD_MEDIA_ENABLED=false` disables playback explicitly. The optional local media origin remains a debug-only regression adapter.
