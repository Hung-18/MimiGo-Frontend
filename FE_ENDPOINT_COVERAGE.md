# MimiGo Android FE API coverage

**API source of truth:** the supplied `API_ENDPOINTS.md`, `API_AVAILABILITY_MATRIX.md`, `AUTH_AND_PERMISSIONS.md`, `FE_INTEGRATION_GUIDE.md`, and `HANDOFF_GAPS.md`. Route presence, feature flags, authentication requirements, and missing media/history capabilities are tracked separately. No mock runtime data or invented endpoint is used.

## Ordinary Parent API

| Method/path after `/api/v1` | FE integration | Availability from handoff |
|---|---|---|
| `GET /privacy/onboarding-reference` | Terms and child-consent reference | Mapped, anonymous. |
| `POST /auth/register` | Parent registration | Mapped; OTP delivery remains constrained to the configured development mode. |
| `POST /auth/mock-email/verify` | OTP verification | Mapped; mock-email flow, not a production mail provider. |
| `POST /auth/mock-email/resend` | Resend verification | Mapped only when `Auth:ResendEnabled` is on; default OFF. |
| `POST /auth/login` | Parent login | Mapped, ordinary Parent JWT. |
| `POST /auth/sessions/refresh` | Automatic single-flight refresh after an authenticated API returns 401; encrypted access/refresh tokens are replaced together | Implemented from supplied LIVE contract. If refresh fails, the local session is cleared. |
| `POST /auth/logout` | Parent Profile and Settings logout | Implemented; local credentials are cleared even if the server cannot be reached. |
| `GET /parents/me` | Parent profile read | Mapped, authenticated Parent. |
| `POST /parents/me/terms-acceptances` | Terms screen explicit checkbox and confirmation | Mapped, authenticated Parent; sends the current `termsVersionId` and `termsAccepted: true`. Registration also submits the current terms version after the user checks the registration consent box. |
| `POST /children/onboarding-attempts` | Child onboarding start | Mapped, authenticated Parent. |
| `GET /children/onboarding-attempts/{attemptId}` | Validate the current onboarding attempt before child submission | Mapped, authenticated Parent; expired/consumed attempt errors are returned by the server. |
| `POST /children` | Create child with DOB, guardian affirmation, purpose choices and idempotency | Mapped, authenticated Parent. |
| `GET /children` | Child roster | Mapped, authenticated Parent. |
| `GET /children/{childId}` | Parent profile child detail | Mapped, authenticated Parent; profile screen refreshes display values from this route. In Gate mode, requires `PARENT_AREA` proof. |
| `GET /children/{childId}/curriculum` | Home domain/topic filter options | Mapped Free Learning route; only domains/topics with eligible lessons are returned. |
| `GET /children/{childId}/lessons` | Home lesson list and server-side domain/topic filters | Mapped Free Learning route; eligible published lessons only. Empty list can be valid if no lesson is seeded/published for the child. |
| `GET /children/{childId}/lessons/{lessonId}` | Lesson content and cues | Mapped Free Learning route. `storageRef` is opaque, not a playable media URL. |
| `POST /children/{childId}/learning-sessions` | Start/resume lesson session | Mapped; repeat requests resume according to handoff semantics. |
| `GET /children/{childId}/learning-sessions/{sessionId}` | Read session answers/state | Mapped. |
| `POST /children/{childId}/learning-sessions/{sessionId}/answers` | Submit cue answer with `clientEventId` | Mapped, idempotent replay supported. |
| `POST /children/{childId}/learning-sessions/{sessionId}/complete` | Complete session | Mapped; backend requires every cue to have at least one answer. |
| `GET /children/{childId}/learning-sessions` | Parent progress/history | Now called by the progress flow; returns `403 PARENT_GATE_REQUIRED` in ordinary mode and remains gated in the UI. |
| `GET /parents/me/learning-workspace` | Progress workspace readiness/status | Mapped and called by Progress; open session items are hidden behind `PARENT_GATE_REQUIRED` in ordinary mode. It does not provide a mastery score or playable video. |
| `GET /health`, `GET /health/ready` | Available API client probes | Mapped, anonymous. `/health` returned HTTP 200 during the current task; readiness/DB state has not been probed. |

## Features that remain gated or incomplete

| Feature | Handoff constraint | FE behavior |
|---|---|---|
| Actual lesson video/audio playback | No ordinary child media delivery URL; `storageRef` is opaque. Private/isolated media routes are not normal app playback endpoints. | Cue interaction can use lesson API data; do not claim the lesson video is playable. |
| Parent learning history / progress | History requires Parent Gate proof; Parent Gate routes are default-off candidates. | Keep progress history unavailable with a clear gate message; do not fabricate empty progress. |
| Parent Gate and Child Mode | Candidate routes/default-off and require the approved security/session contract. | UI remains locked; PIN/proof is not locally simulated. |
| Premium/Billing | Read/write routes are mapped as R0 synthetic candidates but `Billing:Enabled` defaults OFF. Checkout additionally requires Parent Gate proof and synthetic-settlement enablement; no real payment provider. | Plan reads may show backend unavailable when switch is off. Checkout is not presented as a real purchase and cannot claim success. |
| Notifications and favorites | No mapped routes in supplied handoff. | Integration gaps, with no mock lists. |
| Parent/child profile updates/deletion | No approved update/delete route in supplied handoff. | Read/add only; no invented edit/delete API. |
| Forgot/reset password and social login | No ordinary mapped routes in supplied handoff. | Shown unavailable; no simulated completion. |
| CMS | Staff/CMS routes are gated and separate from Parent auth; publication also has media/review blockers. | Not part of the child/parent app flows; no Parent token is used for CMS. |

## Staging check

The configured origin is `https://mimigo-api-staging.onrender.com/api/v1`. A read-only request to `/health` previously returned HTTP 200 with `{"status":"ok","service":"mimigo-backend","mode":"R0_SYNTHETIC"}`. This verifies only that the service responded at that time; DB readiness, current feature flags, credentials, child seed/catalog data, and video playback still need environment/account checks. Use `/health/ready` and an approved test account to confirm those separately.
