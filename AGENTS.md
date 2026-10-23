# MimiGo Frontend agent instructions

- Work only in this repository. Backend, Database and `.mimigo/**` are read-only baselines.
- Preserve the Android/iOS Flutter client and the fixture demo. Commit or push only with explicit PO authorization. Do not deploy, add secrets or claim unverified live-runtime results.
- Keep `reports/WORK_STATUS.md` current and add a report for each assigned implementation slice.
- Live API configuration belongs in build-time defines only. Android Emulator reaches a host-local Backend through `10.0.2.2`, not `localhost`.
- VS-02 is closed with scoped PO acceptance; see `reports/VS-02_FRONTEND_CLOSEOUT.md`. Learning Content & Learning Sessions implementation must wait for the Backend's exact verified Learning API handoff. Do not invent contracts while waiting.
