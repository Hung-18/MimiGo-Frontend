# MimiGo Frontend agent instructions

- Work only in this repository. Backend, Database and `.mimigo/**` are read-only baselines.
- Preserve the Android/iOS Flutter client and the fixture demo. Commit or push only with explicit PO authorization. Do not deploy, add secrets or claim unverified live-runtime results.
- Keep `reports/WORK_STATUS.md` current and add a report for each assigned implementation slice.
- Live API configuration belongs in build-time defines only. Android Emulator reaches a host-local Backend through `10.0.2.2`, not `localhost`.
- VS-02 remains closed with scoped PO acceptance; see `reports/VS-02_FRONTEND_CLOSEOUT.md`. S2 is CLOSED / PO_ACCEPTED within synthetic development scope, based on the PO's manually accepted Android Live E2E checklist and reported real Development Learning Smoke against Backend/PostgreSQL; see `reports/S2_FRONTEND_INTEGRATION.md`. Automated evidence and PO-reported E2E acceptance must remain distinct. This is not production approval.
- The accepted S2 Math slice follows only the five operations in Backend `docs/api/VS-02.2_LEARNING_OPENAPI_CANDIDATE.yaml`. Do not invent completion, billing, Premium, media delivery, hint policy or Parent Gate contracts.
- Learning retries must keep the same clientEventId and payload until acknowledged. Live failures must not fall back to fixtures. Treat media storageRef as opaque metadata; correctness/feedback comes only from answer acknowledgments or recorded session answers.
