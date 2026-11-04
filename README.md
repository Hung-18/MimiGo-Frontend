# MimiGo-Frontend
MimiGo mobile frontend and interactive learning player

PO-owned mobile experience: `feature/po-flutter-ui` (starting checkpoint `bbbf461`).

```powershell
# Network-free PO review: welcome → Khám phá giao diện mới
flutter run --dart-define=MIMIGO_API_MODE=fixture
flutter build apk --debug --dart-define=MIMIGO_API_MODE=fixture

# Controlled staging; use only authorized accounts and synthetic child data
flutter run --dart-define=MIMIGO_API_MODE=live --dart-define=MIMIGO_API_BASE_URL=https://mimigo-api-staging.onrender.com/api/v1 --dart-define=MIMIGO_PARENT_GATE_ENABLED=true
```

API mode is selected at build time and never falls back to preview. Parent Gate is disabled unless explicitly enabled in the client build. For Android Emulator host-local APIs use `10.0.2.2`, not `localhost`. Preview creates no cloud accounts, transactions or entitlements.

[Implementation, screen inventory, all 28 references and API status](reports/PO_FLUTTER_MVP.md) · [Current validation](reports/WORK_STATUS.md) · [Continuation](reports/PO_FLUTTER_CONTINUATION.md).
