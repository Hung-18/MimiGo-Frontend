// Disposable R0 bridge: copy the read-only Web CMS harness, leave its
// browser-authored revision active, then exercise that revision on Android.
// Run from this repository with: node scripts/cross_system_journey.mjs
import { spawn } from "node:child_process";
import { cp, mkdir, readFile, symlink, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const frontend = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
);
const webcms = path.resolve(frontend, "../MimiGo-WebCMS");
const stageName =
  process.env.MIMIGO_JOURNEY_STAGE || `cross_system_webcms_${Date.now()}`;
if (!/^cross_system_webcms(?:_[a-z0-9]+)?$/.test(stageName))
  throw new Error(
    "Stage name must be a task-owned cross_system_webcms directory.",
  );
const stage = path.join(frontend, "build", stageName);
const evidence = path.join(
  frontend,
  "reports/evidence/cross_system_2026_10_25",
);

function once(source, oldText, newText) {
  const first = source.indexOf(oldText);
  if (first < 0 || source.indexOf(oldText, first + oldText.length) >= 0)
    throw new Error(`Upstream harness changed near: ${oldText.slice(0, 75)}`);
  return source.replace(oldText, newText);
}

async function prepare() {
  // Refuse reuse. The nested original runner owns and removes only its own
  // .real-e2e.local directory, never a shared database or process.
  await mkdir(stage);
  for (const name of ["src", "tests", "scripts", "public"])
    await cp(path.join(webcms, name), path.join(stage, name), {
      recursive: true,
    });
  for (const name of [
    "index.html",
    "vite.config.ts",
    "playwright.real.config.ts",
    "package.json",
  ])
    await cp(path.join(webcms, name), path.join(stage, name));
  await symlink(
    path.join(webcms, "node_modules"),
    path.join(stage, "node_modules"),
    "junction",
  );

  const runnerPath = path.join(stage, "scripts/real-e2e.mjs");
  let runner = await readFile(runnerPath, "utf8");
  runner = once(
    runner,
    'const backend = path.resolve(root, "../MimiGo-Backend");',
    'const backend = path.resolve(root, "../../../MimiGo-Backend");\nconst frontend = path.resolve(root, "../..");',
  );
  runner = once(
    runner,
    "function start(exe, args, env = {}) {",
    "function start(exe, args, env = {}, cwd = root) {",
  );
  runner = once(runner, "    cwd: root,", "    cwd,");
  runner = once(
    runner,
    "    windowsHide: true,",
    '    windowsHide: true,\n    shell: exe.toLowerCase().endsWith(".bat"),',
  );
  runner = once(
    runner,
    '    StaffAuth__KdfIterations: "100000",',
    '    StaffAuth__KdfIterations: "100000",\n    Auth__ExposeMockOtp: "true",\n    ParentGate__Enabled: "true",\n    ParentGate__R0UnapprovedSchemaAcknowledged: "true",\n    Security__PinVerifierKey: randomBytes(48).toString("base64"),\n    Security__PinVerifierKeyLabel: "syn-journey",\n    Security__LoginThrottleKey: randomBytes(48).toString("base64"),',
  );
  runner = once(
    runner,
    "  secretValues.push(env.Security__JwtSigningKey, env.Security__VerifierPepper);",
    "  secretValues.push(env.Security__JwtSigningKey, env.Security__VerifierPepper, env.Security__PinVerifierKey, env.Security__LoginThrottleKey);",
  );
  runner = once(
    runner,
    '  env.RateLimit__AuthPermitPerMinute = "120";',
    '  env.RateLimit__AuthPermitPerMinute = "300";',
  );
  runner = once(
    runner,
    '    "Isolated API auth limiter=120/min for the full multi-duty workflow; production default remains 10/min.",',
    '    "Isolated API auth limiter=300/min for the cross-system workflow; production default remains 10/min.",',
  );
  runner = once(
    runner,
    '      MIMIGO_REAL_PSQL: path.join(pgBin, "psql.exe"),',
    '      MIMIGO_REAL_PSQL: path.join(pgBin, "psql.exe"),\n      MIMIGO_JOURNEY_FILE: path.join(runtime, "journey.json"),',
  );
  runner = once(
    runner,
    "  const credentialCount = (",
    `  let androidCode = 1;
  if (browserCode === 0) {
    const identity = JSON.parse(await readFile(path.join(runtime, "journey.json"), "utf8"));
    fact(\`Browser-created lesson=\${identity.lesson}; revision=\${identity.revision}; active program version=\${identity.programVersion}; code=\${identity.code}.\`);
    const android = start("D:/SDKs/flutter/bin/flutter.bat", [
      "test", "integration_test/cross_system_journey_live_test.dart", "-d", "emulator-5554", "--no-pub", "--reporter", "expanded",
      "--dart-define=MIMIGO_API_MODE=live", "--dart-define=MIMIGO_PARENT_GATE_ENABLED=true",
      \`--dart-define=MIMIGO_API_BASE_URL=http://10.0.2.2:\${apiPort}/api/v1\`,
      "--dart-define=MIMIGO_PARENT_GATE_E2E_AUTHORIZED=true",
      \`--dart-define=MIMIGO_PARENT_GATE_E2E_DATABASE=\${database}\`,
      \`--dart-define=MIMIGO_JOURNEY_LESSON=\${identity.lesson}\`,
      \`--dart-define=MIMIGO_JOURNEY_REVISION=\${identity.revision}\`,
      \`--dart-define=MIMIGO_JOURNEY_PROGRAM_VERSION=\${identity.programVersion}\`,
    ], {}, frontend);
    androidCode = await android.done;
    await writeFile(path.join(evidence, "android.txt"), redact(android.output));
    fact(\`Android same-revision journey exit=\${androidCode}.\`);
  }
  const credentialCount = (`,
  );
  runner = once(
    runner,
    "  outcome = nativeCode === 0 && browserCode === 0 && browserFactsOk ? 0 : 1;",
    "  outcome = nativeCode === 0 && browserCode === 0 && androidCode === 0 && browserFactsOk ? 0 : 1;",
  );
  await writeFile(runnerPath, runner);

  const workflowPath = path.join(stage, "tests/real-browser/workflows.spec.ts");
  let workflow = await readFile(workflowPath, "utf8");
  workflow = once(
    workflow,
    'import { randomUUID } from "node:crypto";',
    'import { randomUUID } from "node:crypto";\nimport { writeFileSync } from "node:fs";',
  );
  workflow = once(
    workflow,
    "initial program fixture; UI compose/replay, member remove/add, independent publish/activate and retire",
    "initial program fixture; UI compose/replay, member remove/add, independent publish/activate",
  );
  workflow = once(
    workflow,
    `    await accessible(page);
    await page
      .getByLabel("Retirement reason code", { exact: true })
      .fill("CONTENT_DEFECT");
    await confirm(page, "Retire version");
    await expect(
      page.getByRole("status", { name: "Operation status" }),
    ).toContainText("Version retired");
    await logout(page);
  });
  await test.step("UI recall`,
    `    await accessible(page);
    writeFileSync(process.env.MIMIGO_JOURNEY_FILE!, JSON.stringify({ lesson, revision: rev, programVersion: successor, code: "SYN-WEB-ACCEPTANCE" }));
    await logout(page);
  });
  return;
  await test.step("UI recall`,
  );
  await writeFile(workflowPath, workflow);
}

let result = 1;
try {
  await prepare();
  if (process.argv.includes("--prepare-only")) {
    console.log(`Prepared ${stage}`);
    process.exitCode = 0;
  } else {
    result = await new Promise((resolve, reject) => {
      const child = spawn(process.execPath, ["scripts/real-e2e.mjs"], {
        cwd: stage,
        stdio: "inherit",
        windowsHide: true,
      });
      child.once("error", reject);
      child.once("exit", (code) => resolve(code ?? 1));
    });
  }
} finally {
  const source = path.join(stage, "reports/evidence/real-cors-2026-10-25");
  await mkdir(evidence, { recursive: true });
  for (const name of [
    "summary.txt",
    "browser.txt",
    "android.txt",
    "migrations.txt",
    "http-runner.txt",
    "http-process.txt",
  ])
    try {
      await cp(path.join(source, name), path.join(evidence, name));
    } catch (error) {
      if (error.code !== "ENOENT") throw error;
    }
}
if (!process.argv.includes("--prepare-only")) process.exitCode = result;
