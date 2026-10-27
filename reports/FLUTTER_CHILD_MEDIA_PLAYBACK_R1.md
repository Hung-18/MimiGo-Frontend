# Flutter Child Media Playback R1

2026-10-27. This is a debug-only, synthetic Flutter pairing to the exact Backend 0048 R2 local Child Media Host. It is not an ordinary API route or a production media release.

## WP1 — contract and implementation

The Backend handoff exposes only `GET /private/media/children/lessons/{lessonId}/revisions/{revisionId}/main-video` on its separately gated loopback host. Each full or one-Range request needs a signed Child `Bearer` JWT. Full bytes return 200; valid closed, open or suffix Range returns 206. Invalid or unsatisfiable Range returns 416; withheld/changed/unavailable content returns generic 404; a missing dependency or private storage failure returns 503. The Backend admission and version checks happen for each HTTP request. The client supplies neither Child, asset, bucket, key, storageRef nor version in the URL. The normal API still has no media route.

The Flutter `LiveMimiGoApi` now constructs that exact URL from the loaded lesson and immutable revision and obtains the in-memory Child bearer from the existing `GateSessionCoordinator.authorized(childId:)`. Only a `MAIN_VIDEO` in an active, validated learning session starts the player. The `video_player` native network source is configured with an `Authorization` header; its Android HTTP data-source factory applies that header as a default request property, including follow-on Range requests. Actual device Range traffic was not captured in this slice. No URL or UI string receives the token or opaque storage reference. The player is disposed when the Gate session changes Child/mode/token or expires, the app backgrounds, the lesson is left, or the session ends. Retry obtains a fresh Child bearer and creates a new source. Native errors are rendered only as a generic retry state, because plugin error text may contain sensitive request detail.

Activation requires **all** of `MIMIGO_API_MODE=live`, `MIMIGO_PARENT_GATE_ENABLED=true`, `MIMIGO_CHILD_MEDIA_ENABLED=true`, a debug Flutter build, and `MIMIGO_CHILD_MEDIA_BASE_URL` pointing to an exact local HTTP origin (`10.0.2.2` for Android Emulator, localhost/loopback for local runners). The media flag defaults false, invalid/nonlocal origins fail closed, and release/profile builds cannot enable it. Fixture mode remains the existing storyboard/question demo. No Backend flag, database candidate migration, Staff credentials or persistent host activation was performed.

## WP2 — learning behavior

The existing lesson/session/answer/completion/replay code remains authoritative. The player pauses at the first unanswered cue's `pauseAtMs`, reveals that cue, and resumes after its server-acknowledged answer. Forward seek stops at the next unanswered cue; rewind remains available. Saved answers remain visible and the existing completion rules still require server-acknowledged answers for every cue. Playback progress cannot mark a cue answered or a session completed. Native buffering shows an indicator. Media denial, expiry, interruption, 416, 503 or connectivity failure stops video and offers a new authenticated retry without displaying native error text or claiming playback success. Content eligibility, revision validation, recall denial and completion remain decided by existing Backend operations and the private media host. No resume/abandon, emergency recall, mid-session purchase or download policy was added.

## WP3 — evidence

| Scope | Result and limit |
| --- | --- |
| Flutter media access and native player platform tests | **5 PASS**. Focused mock-platform tests check default-off/nonlocal refusal, Parent/cross-child denial, exact selector-free URL, Child header on native source, bounded seek/cue pause, Gate revocation disposal and absent visible bearer. The lesson-level test also confirms the cue stays hidden until playback reaches it and a response is recorded only by the server answer path. They do not send real HTTP bytes. |
| Existing Learning widget regressions | **49 PASS** in the combined focused run (54 total). Lesson, hardening and completion suites exercised fixture behavior, answer retry, denials and server-confirmed completion with media default off. |
| Real Backend 0048 HTTP | Backend's accepted R2 evidence uses a separate Kestrel process, disposable PostgreSQL 0048 and private versioned MinIO, including actual full/Range bytes and denials. This is **Backend handoff evidence**, not a Flutter rerun. |
| Android/device playback | NOT RUN against the isolated host. No host was listening on the checked local media port. The Backend fixture needs disabled triggers to construct a synthetic Child context, so its successful HTTP test is not a normal Parent Gate enrollment journey. Native seek headers, video decoding and device behavior need a paired disposable-host/device run before client acceptance. |
| Android builds | Ordinary fixture debug and explicitly gated Child media debug APKs **PASS**. The first debug attempt failed in Kotlin's cross-drive incremental cache (pub cache C:, checkout D:); `kotlin.incremental=false` in `android/gradle.properties` resolved it, then both builds passed. An optional release compile check **FAILED** because the generated Java registrant references the dev-only `integration_test` plugin, which is absent from `compileReleaseJavaWithJavac`. No release APK or production readiness is claimed. |

Final `flutter analyze --no-pub` is clean. iOS build and device runtime were not run from this Windows workspace.

## WP4 — local checkpoints

Validated Flutter implementation and tests: local commit `e69c023`. This report and WORK_STATUS/TASK_STATUS are the following local documentation checkpoint, with its hash in the delivery response. After that checkpoint, the only remaining working-tree modification is the pre-existing, user-supplied `tasks/CURRENT_TASK.md`, preserved and excluded. No push or deployment.

## Remaining gates

Security/DBQ-22 must approve the separate process, JWT key, dedicated login and secret/network boundaries. DBQ-34 versioned verifier trust and in-flight recall/cache/fan-out policy remain open. Content G4 inventory/editorial and Legal G2 rights/privacy review, G1 paired adoption and Production/G5 are open. Backend's synthetic `MATCH`, publication and provenance are not those approvals. The end-to-end fixture trigger-bypass limitation remains unresolved. The ordinary API and production delivery remain disabled. No push or deployment.
