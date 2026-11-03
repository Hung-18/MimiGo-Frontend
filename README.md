# MimiGo-Frontend
MimiGo mobile frontend and interactive learning player

## Backend connection

The app uses `https://mimigo-api-staging.onrender.com/api/v1` by default.
Override it at build time with
`-PMIMIGO_API_BASE_URL=https://<api-origin>/api/v1` (include `/api/v1` once).
Cleartext HTTP is allowed only in debug builds. Release builds require HTTPS.

The API coverage and handoff constraints are listed in `FE_ENDPOINT_COVERAGE.md`.
Free Learning catalog, lesson/cue, answer, and completion routes from the
supplied handoff are integrated. Parent history remains protected by Parent Gate.
Ordinary video playback has a separate blocker: `storageRef` is opaque and there
is no ordinary child media delivery route. Some mapped routes (such as OTP
resend and Premium/Billing) may still be unavailable when their runtime feature
gates are off.
