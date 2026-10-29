# MimiGo-Frontend
MimiGo mobile frontend and interactive learning player

## Backend connection

The debug app uses `http://10.0.2.2:5187/api/v1` by default, which reaches an API
running on the Android emulator host. Override it at build time with
`-PMIMIGO_API_BASE_URL=https://<api-origin>/api/v1` (include `/api/v1` once).
Cleartext HTTP is allowed only in debug builds. Release builds require HTTPS.

The connected baseline flows are parent registration (current Terms ID is read
from the API), mock email verification, parent login, child onboarding, child
roster selection, and Free learning (catalog, lesson detail, resumable session,
answer replay, and completion).
Mock verification, resend, password recovery, social login, Parent Gate, Premium,
lesson playback, and CMS are constrained by the backend handoff: several are
development-only, gated off, or not mapped. The UI reports unavailable password
recovery and social sign-in instead of pretending those operations succeeded.
