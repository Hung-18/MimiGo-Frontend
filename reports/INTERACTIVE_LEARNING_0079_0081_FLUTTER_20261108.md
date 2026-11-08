# Flutter interactive learning contract — 2026-11-08

Baseline `d495f4b`, `feature/po-flutter-ui`. Frontend only. Read the current Backend `docs/api/VS-02.2_LEARNING_OPENAPI_CANDIDATE.yaml`, `ChildLessonMediaService` and `LearningService`, plus Database 0079, 0080 and 0081 reports. Database 0082 is a CMS draft-read contract and adds no Child-learning route. No Backend, Database, `.mimigo` or cloud mutation. The existing fixture Learning path, Parent Gate, consent and auth flows remain separate.

## Implemented

- Live learning uses `cue-states` as the only attempt/resume authority. `RETRY_AVAILABLE` permits a second choice (including the same wrong option), while `CORRECT` and `EXHAUSTED` resolve a checkpoint. Only the server's first unresolved `resumePoint` is answerable. Resolved feedback, authored explanation and correct option are displayed after EXHAUSTED; no score or locally inferred attempt count is used.
- A required question-audio reference and every required answer-image reference must be present in the rights-filtered lesson detail. The client requests fresh session-scoped 0081 grants and decodes every answer image before enabling a choice. Missing/failed media blocks the checkpoint with a retry message; there is no text-only live fallback. The question audio plays at the checkpoint and has a replay control. Authored hint text/audio and optional answer audio have separate controls.
- The video uses `playback-state` for safe resume and `playback-events` for START, heartbeat PROGRESS, checkpoint PAUSE, interruption BACKGROUND and ENDED. The in-memory ledger retains the exact event ID/sequence/body on an ambiguous POST; 409 out-of-order re-reads server state. CLAMPED/REJECTED snaps back to the server position. Completion is offered only after all server cue states resolve and, when required, the server accepts video end. A successful completion response alone displays COMPLETED and its endedAt.
- Each question/answer asset GET sends `?sessionId=` with the matching Child token to the API, then passes the short-lived signed URL to storage without that bearer. URLs are never persisted; audio replay requests a new grant, expired grants trigger a reload, and rights/media/auth denial stops media and blocks interaction. The video has no forward seek control that could evade the 0080 frontier.

## Verification

- Focused new contract tests: **7 PASS** (video START/server sequence and no early completion, missing-media widget block, cue-state parsing, idempotent ledger, media requirements, route/body, 0081 Child grant and later rights denial).
- New + retained learning/media focused suites: **55 PASS**.
- Full retained Flutter suite after the live-route switch: **449 PASS / 5 opt-in SKIPPED**. Generated historical fixture screenshots were restored to their tracked baseline.
- `flutter analyze --no-pub`: **PASS**, no issues.
- `flutter build apk --debug --no-pub`: **PASS**, final `app-debug.apk` produced.
- Disposable Backend/Neon and real Android media journey: **NOT RUN**. The available historical fixture/native player tests do not contain an 0080-enabled Cloud session and were not reported as live acceptance.

## Acceptance status

| Area | Status | Remaining evidence |
|---|---|---|
| Flutter 0079/0080/0081 routes, state gating, media block and idempotent event handling | **PASS locally** | Focused tests and analyzer/build above. |
| Native audio decode, signed images/video, interruption and video-end completion with a published interactive lesson | **PARTIAL** | Needs a disposable or authorized real Child session with a rights-cleared lesson carrying required audio/images/video and cue timing. Native signed bytes were not exercised in this slice. |
| Real Pilot family acceptance and persisted readback | **BLOCKED** | Authorized Parent/Child/PIN, the approved attempt-bound notice documents, and a published age-eligible interactive lesson are required. No fictional guardian or Child was created. |

Actual acceptance should check two wrong taps of the same option -> EXHAUSTED with correct answer/explanation; interruption/resume at the server position; PAUSE at each checkpoint; ENDED accepted before completion; persisted session/endedAt after re-entry; and 404 MEDIA_NOT_AVAILABLE after rights withdrawal. CMS authoring, media upload, review and publishing are not claimed as live accepted by this report.
