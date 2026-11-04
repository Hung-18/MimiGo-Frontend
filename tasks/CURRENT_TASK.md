# MimiGo — Flutter Child Media Playback Integration R1

## Outcome

Enable a real authenticated synthetic Child learning session to play an eligible private MP4 through the existing Backend 0048 Child Media Host, using Flutter's existing Parent Gate, Child session and lesson runtime.

No Staff credentials, direct MinIO URLs or fabricated server success.

## Authoritative inputs

Read selectively:
- Frontend TASK_STATUS and Flutter Functional R2 handoff.
- Backend `BACKEND_CHILD_MEDIA_TRUST_INTEGRATION_R2.md`.
- Actual Backend Child Media Host HTTP contracts.
- Existing Flutter lesson player, session and API clients.
- Relevant SRS requirements and confirmed PO business deltas.

## WP1 — Contract and playback integration

Verify the exact authenticated Child media endpoint, headers, errors, supported Range behavior and current private-host availability.

Integrate with the existing Flutter architecture, avoiding duplicate media players or authentication stacks.

Use a player/data-source approach capable of attaching the required Child authorization to media requests, including seek requests.

Do not expose this capability in normal/public builds.

## WP2 — Learning journey behavior

Preserve:
- Parent Gate and Child identity.
- Immutable lesson revision.
- Existing cue-pause and mini-game timing.
- Existing answer/completion behavior.
- Eligibility and recall denial.
- No mid-session payment.
- Safe replay and error handling.

Handle loading, buffering, seeking, expired sessions, denied media, interrupted connectivity and unavailable storage.

Do not invent resume/abandon or emergency recall policies.

## WP3 — Focused verification

Test:
- Authenticated synthetic Child playback.
- Range requests with Child authorization.
- Cross-child and non-Child denial.
- Logout/revocation and expired session behavior.
- No token or storage-key leakage.
- Cue and mini-game compatibility.
- Fixture/demo backward compatibility.
- Disabled ordinary/public configuration.

Run focused tests, Flutter analyzer and Android builds.

Attempt actual isolated-host integration if the existing test infrastructure supports it. Clearly separate mocked, device, and real HTTP evidence.

Do not perform the postponed full four-repository E2E.

## WP4 — Delivery

Update TASK_STATUS.md.

Create `reports/FLUTTER_CHILD_MEDIA_PLAYBACK_R1.md` with:
- Exact API and playback implementation.
- Test evidence.
- Real HTTP versus mocked coverage.
- Android runtime limitations.
- Remaining Security, Content, Legal and Production gates.
- The unresolved end-to-end fixture trigger-bypass limitation.
- Commit and working-tree status.

Commit validated Flutter-only changes locally.

Preserve existing modifications. No push or deployment.

## Acceptance

A synthetic authorized Child can play eligible media using Child credentials, while unauthorized requests fail closed.

If actual Android/device playback is not tested, report it as NOT RUN rather than claiming final client acceptance.