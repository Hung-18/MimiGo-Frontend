# Public synthetic visual evidence

Captured 2026-10-25. Source mapping, comparison findings, omissions and exact validation results: [UI/UX fidelity report](../../UI_UX_FIDELITY.md).

- `public_360x800_*`: 17 Android Emulator PNGs, public catalog scenario PASS (19s).
- `public_411x900_*`: 17 Android Emulator PNGs, final public catalog scenario PASS (39s).
- `widget_*`: Flutter desktop widget renders with actual bundled Baloo 2, Nunito and Material icon fonts. These verify responsive typography/layout; they are **not Android screenshots**. Transparent areas in these widget-only images can appear black in image viewers; the Android images show actual window backgrounds.

Fixtures reuse existing synthetic lesson response data. No Backend requests, real families or production progress. The FIXTURE/no-network footer is test-harness labeling, not a runtime product footer. Basic synthetic alias/avatar/eligibility is shown; no live account, proof, PIN, token or protected DOB/history capture.

Android capture asserts `screenProtected == false` and refuses PIN/Parent Area widgets before every image. Widget capture also refuses protected widget types. FLAG_SECURE was never disabled for screenshots. PIN/private native behavior is verified separately without screenshots.

Viewport/scroll positions vary deliberately to show the relevant fields/choices. Images are implementation evidence, not source artwork or PO visual approval. Missing licensed artwork and state frames keep full-screen fidelity PARTIAL/BLOCKED. No flattened reference pixels are bundled into the app or committed here.

Reproduce public fixture captures (requires Flutter/Android toolchains and a booted emulator; close the emulator during build on memory-constrained hosts):

```powershell
flutter build apk --debug --no-pub -t integration_test/design_fidelity_fixture_test.dart
flutter drive --driver=integration_test/design_capture_driver.dart --target=integration_test/design_fidelity_fixture_test.dart --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk -d emulator-5554 --no-pub
```

Widget comparison renders:

```powershell
flutter test test/design_fidelity_test.dart --no-pub --concurrency=1 --reporter expanded --dart-define=MIMIGO_CAPTURE_VISUALS=true
```

The driver validates capture integrity only; reference-match decisions require the comparisons recorded in the report.
