# R2 mascot acceptance correction — 2026-11-05

Baseline `bada990`, branch `feature/po-flutter-ui`. The PO rejected the geometric
bee and explicitly authorized this scoped correction, emulator review, commit
and push. Visual PO acceptance remains pending; automated evidence cannot grant it.

## Actual available sources

All paths below were inspected in this repository. The `.mimigo` sources remain
read-only. The numbered review copies are ignored local inspection files, mapped
by `reports/evidence/po_reference/inventory.txt`; they are not shipped assets.

| Original reference path | Review copy | Use |
|---|---|---|
| `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/Bảng thương hiệu MimiGo vui nhộn.png` | `reports/evidence/po_reference/26.png` | Primary character identity, views and expressions; actual imagegen input |
| `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/Bảng ý tưởng thương hiệu MimiGo vui nhộn.png` | `reports/evidence/po_reference/06.png` | Earlier character/brand variant comparison |
| `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/MimiGo_ Cùng Mimi khám phá-Trang chủ.png` | `reports/evidence/po_reference/22.png` | Welcome composition and identity comparison |
| `.mimigo/ui_reference/THIẾT KẾ GIAO DIỆN CÁC MÀN/Màn hình đăng ký phụ huynh MimiGo.png` | `reports/evidence/po_reference/01.png` | Registration reference, inspected in contact sheet |

No standalone original transparent mascot, layered source, SVG, Rive or Lottie
mascot was found. Existing launcher PNGs and historical screenshots are not
character animation sources. The boards are references, not reusable licensed
artwork or automatic acceptance. The replacement is newly generated transparent
reference-based artwork, not a recovered original or a board crop.

## Root cause and correction

The old `_MimiPainter` drew a flat yellow oval, purple stripes/stick arms, tiny
eyes and white oval wings. It omitted the aviator cap/goggles, hair tuft, lotus
wings/scarf/backpack, boots, dimensional shading and expressive brown eyes that
define Mimi. Colors or animation speed could not repair that silhouette or face.

Replaced that painter with `assets/mascot/mimi_poses.png`: one RGBA atlas containing
seven matching character poses. `lib/po/mimi_world.dart` keeps the existing
`MimiBee`/`MimiMood` interface so Welcome, Registration, Parent Home, Child Mode,
feedback, completion and retained fixtures share the same identity. Asset
provenance, actual dimensions, runtime cost and exact generation/edit prompts:
[`assets/mascot/README.md`](../assets/mascot/README.md).

Idle rests friendly; greeting waves; guide points; thinking holds a hand at the
chin; correct lifts hands joyfully; encourage offers a reassuring open hand;
completion smiles with happy closed eyes. Each state has a short gentle rigid
hover/tilt, then rests after the existing 1.4-second burst. There is no face/body
stretching, perpetual ticker, network artwork or added package. Background,
disabled TickerMode, reduced motion and disposal behavior remain guarded. This
is pose-based animation, not a rigged wing/blink system. No profile/release FPS
benchmark or physical-device performance acceptance is claimed.

Hero text now has a solid light surface, separated from the garden; Mimi fits
inside a dedicated stage. Welcome loses redundant vertical spacers and its
forced heading break. Registration alone uses a compact page heading instead
of the large multi-line display heading. No unrelated feature redesign.

Real authentication/Backend/Terms/session behavior is untouched. Unavailable or
unapproved Terms still prevent form entry/consent/submission. No synthetic terms,
account, lesson, permission or completion is added to normal runtime. Seven-state
presentation does not manufacture success before server acknowledgments.

## Validation and Android evidence

`flutter analyze --no-pub`: **PASS**, no issues. Final full regression suite:
**402 PASS / 3 opt-in SKIPPED** (401 retained plus one seven-pose asset/mapping
regression). Focused R2 suite: **12 PASS**. Existing checks cover acknowledgment
ordering, retries/replay, Terms/legal blocking, Gate/security, background/disposal,
reduced motion and 320dp/landscape layouts at 200% text. `git diff --check`: PASS.

Final Android walkthrough: **1 public synthetic scenario PASS**, 21s, on
`emulator-5554`, API 37; debug build/install PASS. Exercised welcome sign-in,
unavailable-Terms registration, all seven poses, Parent selection, available
Child domain, acknowledged feedback, completion and replay. Reviewed all seven
final emulator captures:

- [Welcome](evidence/mobile_r2/r2_welcome.png)
- [Registration / unavailable Terms](evidence/mobile_r2/r2_registration.png)
- [Parent Home](evidence/mobile_r2/r2_parent_home.png)
- [Child Mode](evidence/mobile_r2/r2_garden.png)
- [Learning feedback](evidence/mobile_r2/r2_feedback.png)
- [Completion](evidence/mobile_r2/r2_completion.png)
- [Seven character states](evidence/mobile_r2/r2_mascot_states.png)

Screenshots are public synthetic Android presentation evidence, not live
authentication/learning acceptance. The harness
asserts native `screenProtected == false` before every capture. No protected Gate
or private window is captured, and FLAG_SECURE is never disabled.

The first Android review passed and exposed residual atlas background haze.
That generated image was replaced with a second built-in background extraction
edit. Sampled gutter pixels in the final PNG have alpha 0. Final captures replace
the intermediate screenshots rather than leaving both labeled as final.

The debug emulator emitted first-frame skipped-frame/ImageReader messages, but
the assertions, screenshot transfer and runner completed successfully. This is
not a release/profile performance measurement. No new live E2E or iOS evidence.

Normal live-only `lib/main.dart` debug build/install/launch restored successfully
with `flutter run -d emulator-5554 --no-resident` after the harness; no fixture
entry or mode switch is left installed. The normal build uses its existing
configuration; no authenticated session or remote operation was exercised.

Exact reproduction:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
flutter drive --driver=integration_test/mobile_experience_r2_driver.dart --target=integration_test/mobile_experience_r2_test.dart -d emulator-5554
flutter run -d emulator-5554 --no-resident
```

Existing unrelated internal-auth report/status edits are preserved and excluded
from the feature checkpoint. No Backend, Database, `.mimigo`, deployment, secret,
Gate activation or shared-service changes.
