# Flutter MVP functional completion

2026-10-27. Baseline: Flutter `17c8dcb` after Functional R2 and Child Media R1; Backend `55f0f1c` and Database `59dbd7b` are read-only frozen inputs. This slice checked the remaining confirmed client surface and ran focused verification. No additional independently implementable Flutter route or write was identified, so no runtime behavior was changed. This is a source and automated-build disposition, not end-to-end or production acceptance.

## Completed supported journeys

| Journey | Actual client behavior | Evidence boundary |
| --- | --- | --- |
| Parent authentication and profiles | Registration/returning login, account Terms re-acceptance, independent child notice and creation, roster, child selection, server age and `learningEntry` checks. Uncertain creation retries keep the original request. | Real API client and prior isolated Android/Backend acceptance are documented in earlier reports; this slice used focused tests only. |
| Parent Gate and settings | Gated PIN enrollment/verification, password step-up for change/reset, Child context, protected profile/history reads, other-session revocation, expiry/background cleanup and protected screen handling. Gate remains disabled by default. | Existing R0 candidate integration and mock/widget tests. No candidate activation here. |
| Child discovery and learning | Server-returned eligible curriculum/lesson/revision, Child-scoped start or existing session, recorded-answer readback, server feedback, stable event retry, all-cue completion, endedAt and new-session replay. Empty/denied/expired/error paths fail closed. Fixture remains explicitly local. | Real API integrations already present; focused tests here are test-double evidence. |
| Private video | Debug-only local media host, validated lesson/revision path and in-memory Child bearer on native requests, cue pause, bounded seek, buffering and safe retry/teardown. | Native platform mock tests pass. Fresh Flutter real HTTP/device playback was not run. |
| Progress and history | Gate-protected session list and returned state/timestamps; known Child session readback during learning. No aggregate progress or fabricated score. | Parent Gate candidate only; default-off configuration exposes no protected history. |

## External dependencies and disabled operations

- Frozen VS-01, Learning and Parent Gate API candidates have no subscription entitlement, purchase, billing, settings profile-edit or aggregate-progress operation for Flutter. The client presents returned Free catalog/entry eligibility only. A service contract and product approval are required before these can be implemented honestly.
- The protected history API needs an enabled Parent Gate candidate and valid Parent proof. This task does not authorize Backend flags, migrations or persistent activation. Sensitive DOB edits, consent withdrawal, privacy export/deletion and unconfirmed learning retry/skip/hint/abandon/mastery policy remain unavailable.
- Ordinary/production video delivery is absent. The Backend 0048 private host is a separately gated local synthetic route; Security trust, Content inventory/rights, Legal privacy and paired rollout remain open. No Staff credentials, MinIO URL or opaque storage key are used by Flutter.
- No independently confirmed story media, mini-game protocol or approved inventory exists beyond the server cue/option behavior and local fixture storyboard. The client does not label fixture interaction as saved learning or invent a live write.
- Real paired Android playback and release acceptance need a disposable host/device setup. The earlier synthetic Backend media fixture requires trigger bypass and is not proof of a normal enrollment path. iOS/device/manual visual acceptance and production approval remain open.

## Verification in this slice

- `flutter test test/child_media_access_test.dart test/child_media_player_test.dart test/parent_home_test.dart test/parent_gate_widget_test.dart test/learning_completion_state_test.dart test/learning_completion_widget_test.dart --no-pub`: **67 PASS**, exit 0. Tests cover gated media authorization/seek/disposal, roster/Gate behavior and server-owned completion. They use mocks and do not send real HTTP bytes.
- `flutter analyze --no-pub`: **PASS**, no issues.
- `flutter build apk --debug --no-pub --dart-define=MIMIGO_API_MODE=fixture`: **PASS**, exit 0; `build/app/outputs/flutter-apk/app-debug.apk` built. This is a compile check, with no install or launch.
- Release compile: the Child Media R1 attempt **FAILED** because generated `GeneratedPluginRegistrant.java` in the main Android source set references dev-only `integration_test`, while the release compile classpath omits it. A fresh `flutter build apk --release --no-pub --dart-define=MIMIGO_API_MODE=fixture` made no progress or output after Gradle startup and was interrupted; it supplies no new PASS or FAIL verdict. The generated file still contains that reference. No safe small fix was established: moving the test plugin into production dependencies or editing a generated file would compromise the intended configuration. Release build remains unresolved.
- No broad security suite, previous unchanged full suite, real device or real HTTP run was performed here.

## Local delivery

No Flutter runtime files changed in this slice. This report and `reports/WORK_STATUS.md` / `tasks/TASK_STATUS.md` are the validated local checkpoint; its hash is the commit containing this report. The pre-existing `tasks/CURRENT_TASK.md` modification is preserved and excluded. No Backend, Database or `.mimigo/**` edits, push or deployment.
