#!/usr/bin/env node
// ============================================================================
// test-token-guard.mjs
//
// Behavioral unit test cho opk-token-guard.js.
// Since the plugin exports a single default (CommonJS), all tests go
// through the plugin's tool.execute.before hook using mock PluginInput.
// Chạy: node scripts/test-token-guard.mjs
// Exit 0 = pass, 1 = fail.
// ============================================================================
import { createRequire } from "node:module";
import { spawnSync } from "node:child_process";
const require = createRequire(import.meta.url);
const OPKTokenGuard = require("../templates/plugins/opk-token-guard.js");

let pass = 0;
let fail = 0;
const fails = [];

function check(name, cond) {
  if (cond) {
    pass++;
    console.log(`  [ok]   ${name}`);
  } else {
    fail++;
    fails.push(name);
    console.log(`  [FAIL] ${name}`);
  }
}

function expectThrow(name, fn) {
  try {
    const r = fn();
    if (r && typeof r.then === "function") {
      return r.then(
        () => check(name + " (expected throw)", false),
        () => check(name + " (threw)", true),
      );
    }
    check(name + " (expected throw)", false);
  } catch (e) {
    check(name + " (threw)", true);
  }
  return undefined;
}

function expectNoThrow(name, fn) {
  try {
    const r = fn();
    if (r && typeof r.then === "function") {
      return r.then(
        () => check(name + " (allowed)", true),
        () => check(name + " (unexpected block)", false),
      );
    }
    check(name + " (allowed)", true);
  } catch (e) {
    check(name + ` (unexpected block: ${e.message})`, false);
  }
  return undefined;
}

// --- 1. Plugin export exists + shape ---
check("OPKTokenGuard export exists", typeof OPKTokenGuard === "function");

// Runtime module must expose one distinct callable factory under dynamic import.
// CJS interop may alias the same function as `default` / `module.exports`; that
// is fine as long as helpers are not exposed as additional plugin factories.
const forbiddenHelperExports = [
  "findTokenLeak",
  "guardTokenCall",
  "isTokenStorePath",
  "isProtectedSecretPath",
  "findProtectedPathLiteral",
];
for (const name of forbiddenHelperExports) {
  check(`runtime export does not expose helper: ${name}`, !(name in OPKTokenGuard));
}

const tokenNamespace = await import(
  new URL("../templates/plugins/opk-token-guard.js", import.meta.url).href
);
const tokenCallableExports = Object.values(tokenNamespace).filter(
  (value) => typeof value === "function",
);
const distinctTokenCallableExports = [...new Set(tokenCallableExports)];
check(
  "dynamic import exposes exactly one distinct token-guard factory",
  distinctTokenCallableExports.length === 1,
);

const plugin = await OPKTokenGuard({});
check(
  "plugin returns object with tool.execute.before",
  plugin && typeof plugin["tool.execute.before"] === "function",
);

const hook = plugin["tool.execute.before"];


// --- 1b. Agent shell env: sanitize child, preserve OpenCode/provider auth ----
check(
  "plugin returns shell.env hook",
  typeof plugin["shell.env"] === "function",
);
const shellEnvHook = plugin["shell.env"];

const savedOpenAIKey = process.env.OPENAI_API_KEY;
const savedServiceToken = process.env.OPK_TEST_SERVICE_TOKEN;

try {
  process.env.OPENAI_API_KEY =
    "sk-opk-test-abcdefghijklmnopqrstuvwxyz012345";
  process.env.OPK_TEST_SERVICE_TOKEN =
    "opk-test-service-token-value";

  const agentEnvOutput = {
    env: {
      SAFE_FLAG: "keep-me",
      OPENAI_API_KEY: "prior-plugin-secret-value",
    },
  };

  await shellEnvHook(
    {
      cwd: process.cwd(),
      sessionID: "session-opk-test",
      callID: "call-opk-test",
    },
    agentEnvOutput,
  );

  check(
    "agent shell blanks known provider API key",
    agentEnvOutput.env.OPENAI_API_KEY === "",
  );
  check(
    "agent shell blanks suffix-matched token",
    agentEnvOutput.env.OPK_TEST_SERVICE_TOKEN === "",
  );
  check(
    "agent shell preserves non-secret injected env",
    agentEnvOutput.env.SAFE_FLAG === "keep-me",
  );
  check(
    "shell.env does not mutate OpenCode/provider process.env",
    process.env.OPENAI_API_KEY ===
      "sk-opk-test-abcdefghijklmnopqrstuvwxyz012345",
  );

  // Mirror OpenCode's runtime merge: { ...process.env, ...extra.env }.
  const mergedAgentEnv = {
    ...process.env,
    ...agentEnvOutput.env,
  };
  const child = spawnSync(
    process.execPath,
    [
      "-e",
      "process.stdout.write((process.env.OPENAI_API_KEY || '') + '|' + (process.env.OPK_TEST_SERVICE_TOKEN || ''))",
    ],
    {
      env: mergedAgentEnv,
      encoding: "utf8",
    },
  );
  check(
    "merged agent child environment contains no secret values",
    child.status === 0 && child.stdout === "|",
  );

  // Manual OpenCode PTY invokes shell.env with cwd only.
  const ptyEnvOutput = {
    env: {
      OPENAI_API_KEY: "manual-terminal-value",
    },
  };
  await shellEnvHook(
    { cwd: process.cwd() },
    ptyEnvOutput,
  );
  check(
    "manual PTY environment is not sanitized",
    ptyEnvOutput.env.OPENAI_API_KEY === "manual-terminal-value",
  );
} finally {
  if (savedOpenAIKey === undefined) delete process.env.OPENAI_API_KEY;
  else process.env.OPENAI_API_KEY = savedOpenAIKey;

  if (savedServiceToken === undefined) {
    delete process.env.OPK_TEST_SERVICE_TOKEN;
  } else {
    process.env.OPK_TEST_SERVICE_TOKEN = savedServiceToken;
  }
}


// --- 2. Environment dumps blocked ---
await expectThrow(
  "printenv blocked",
  () => hook({ tool: "bash" }, { args: { command: "printenv" } }),
);
await expectThrow(
  "bare env blocked",
  () => hook({ tool: "bash" }, { args: { command: "env" } }),
);
await expectThrow(
  "bare set blocked",
  () => hook({ tool: "bash" }, { args: { command: "set" } }),
);
await expectNoThrow(
  "env PREFIX=value cmd allowed",
  () => hook({ tool: "bash" }, { args: { command: "env PREFIX=x make test" } }),
);


await expectThrow(
  "cat /proc/self/environ blocked",
  () => hook(
    { tool: "bash" },
    { args: { command: "cat /proc/self/environ" } },
  ),
);
await expectThrow(
  "python read /proc/$PPID/environ blocked",
  () => hook(
    { tool: "bash" },
    {
      args: {
        command:
          "python3 -c 'open(\"/proc/$PPID/environ\", \"rb\").read()'",
      },
    },
  ),
);
await expectNoThrow(
  "python os.environ relies on sanitized child env",
  () => hook(
    { tool: "bash" },
    {
      args: {
        command:
          "python3 -c 'import os; print(os.environ.get(\"OPENAI_API_KEY\", \"\"))'",
      },
    },
  ),
);
await expectNoThrow(
  "node process.env relies on sanitized child env",
  () => hook(
    { tool: "bash" },
    {
      args: {
        command:
          "node -e 'console.log(process.env.OPENAI_API_KEY || \"\")'",
      },
    },
  ),
);

// --- 3. echo/printf expanding secret env vars blocked ----------------------
await expectThrow(
  "echo $OPENAI_API_KEY blocked",
  () => hook({ tool: "bash" }, { args: { command: "echo $OPENAI_API_KEY" } }),
);
await expectThrow(
  "printf ${ANTHROPIC_API_KEY} blocked",
  () => hook({ tool: "bash" }, { args: { command: "printf '%s' ${ANTHROPIC_API_KEY}" } }),
);
await expectThrow(
  "echo $GITHUB_TOKEN blocked",
  () => hook({ tool: "bash" }, { args: { command: "echo $GITHUB_TOKEN" } }),
);
await expectThrow(
  "echo $FOO_API_KEY (suffix match) blocked",
  () => hook({ tool: "bash" }, { args: { command: "echo $FOO_API_KEY" } }),
);
await expectNoThrow(
  "echo $PATH allowed",
  () => hook({ tool: "bash" }, { args: { command: "echo $PATH" } }),
);
await expectNoThrow(
  "echo $HOME allowed",
  () => hook({ tool: "bash" }, { args: { command: "echo $HOME" } }),
);

// --- 4. Exporting a secret with literal value blocked ----------------------
await expectThrow(
  "export OPENAI_API_KEY=sk-... blocked",
  () => hook({ tool: "bash" }, { args: { command: "export OPENAI_API_KEY=sk-abcdefghijklmnopqrstuvwxyz0123" } }),
);
await expectThrow(
  "export GITHUB_TOKEN=ghp_... blocked",
  () => hook({ tool: "bash" }, { args: { command: "export GITHUB_TOKEN=ghp_abcdefghijklmnopqrstuvwxyz0123456789" } }),
);
await expectNoThrow(
  "export DEBUG=1 allowed",
  () => hook({ tool: "bash" }, { args: { command: "export DEBUG=1" } }),
);

// --- 5. Inline credentials blocked ------------------------------------------
await expectThrow(
  "curl with Bearer token blocked",
  () => hook({ tool: "bash" }, { args: { command: "curl -H 'Authorization: Bearer abcdefghijklmnopqrstuvwxyz0123456789' https://api.example.com" } }),
);
await expectThrow(
  "curl with sk- key blocked",
  () => hook({ tool: "bash" }, { args: { command: "curl https://api.openai.com/v1 -H 'Authorization: Bearer sk-abcdefghijklmnopqrstuvwxyz0123456789'" } }),
);
await expectThrow(
  "AWS key inline blocked",
  () => hook({ tool: "bash" }, { args: { command: "aws configure set aws_access_key_id AKIAIOSFODNN7EXAMPLE" } }),
);
await expectNoThrow(
  "curl with no credentials allowed",
  () => hook({ tool: "bash" }, { args: { command: "curl https://api.example.com/v1/health" } }),
);
await expectNoThrow(
  "git log allowed",
  () => hook({ tool: "bash" }, { args: { command: "git log --oneline -5" } }),
);

// --- 6. Token store file access blocked (read/write/edit/bash) --------------
await expectThrow(
  "read ~/.ssh/id_rsa blocked",
  () => hook({ tool: "read" }, { args: { path: "/home/user/.ssh/id_rsa" } }),
);
await expectThrow(
  "read .aws/credentials blocked",
  () => hook({ tool: "read" }, { args: { path: "/home/user/.aws/credentials" } }),
);
await expectThrow(
  "write ~/.netrc blocked",
  () => hook({ tool: "write" }, { args: { path: "/home/user/.netrc" } }),
);
await expectThrow(
  "edit ~/.kube/config blocked",
  () => hook({ tool: "edit" }, { args: { path: "/home/user/.kube/config" } }),
);
await expectThrow(
  "read opencode auth.json blocked",
  () => hook({ tool: "read" }, { args: { path: "/home/user/.local/share/opencode/auth.json" } }),
);
await expectThrow(
  "read opencode config auth blocked",
  () => hook({ tool: "read" }, { args: { path: "/home/user/.config/opencode/auth.json" } }),
);
await expectThrow(
  "cat ~/.ssh/id_ed25519 blocked",
  () => hook({ tool: "bash" }, { args: { command: "cat ~/.ssh/id_ed25519" } }),
);
await expectThrow(
  "head ~/.aws/credentials blocked",
  () => hook({ tool: "bash" }, { args: { command: "head -3 ~/.aws/credentials" } }),
);
await expectNoThrow(
  "read README.md allowed",
  () => hook({ tool: "read" }, { args: { path: "README.md" } }),
);
await expectNoThrow(
  "read package.json allowed",
  () => hook({ tool: "read" }, { args: { path: "package.json" } }),
);
await expectNoThrow(
  "write src/auth.json (project file) allowed",
  () => hook({ tool: "write" }, { args: { path: "src/auth.json" } }),
);
await expectNoThrow(
  "cat ~/.zshrc allowed",
  () => hook({ tool: "bash" }, { args: { command: "cat ~/.zshrc" } }),
);


// --- 6a. Traversal/canonicalization cannot turn token-store paths safe --------
await expectThrow(
  "read ../.ssh/config blocked",
  () => hook({ tool: "read" }, { args: { path: "../.ssh/config" } }),
);
await expectThrow(
  "read foo/../.aws/credentials blocked",
  () => hook({ tool: "read" }, { args: { path: "foo/../.aws/credentials" } }),
);
await expectThrow(
  "read tmp/../.config/opencode/auth.json blocked",
  () => hook(
    { tool: "read" },
    { args: { path: "tmp/../.config/opencode/auth.json" } },
  ),
);
await expectThrow(
  "write ./../.netrc blocked",
  () => hook({ tool: "write" }, { args: { path: "./../.netrc" } }),
);
await expectThrow(
  "edit safe/../../.kube/config blocked",
  () => hook(
    { tool: "edit" },
    { args: { path: "safe/../../.kube/config" } },
  ),
);
await expectThrow(
  "Windows-style .ssh traversal blocked",
  () => hook(
    { tool: "read" },
    { args: { path: "tmp\\..\\.ssh\\config" } },
  ),
);
await expectNoThrow(
  "safe lexical normalization src/../README.md allowed",
  () => hook(
    { tool: "read" },
    { args: { path: "src/../README.md" } },
  ),
);

// --- 6b. Project secret path protection ------------------------------------
await expectThrow(
  "read .env blocked",
  () => hook({ tool: "read" }, { args: { path: ".env" } }),
);
await expectThrow(
  "read .env.production blocked",
  () => hook({ tool: "read" }, { args: { path: "config/.env.production" } }),
);
await expectNoThrow(
  "read .env.example allowed",
  () => hook({ tool: "read" }, { args: { path: ".env.example" } }),
);
await expectNoThrow(
  "read nested .env.example allowed",
  () => hook({ tool: "read" }, { args: { path: "config/.env.example" } }),
);
await expectNoThrow(
  "write .env.example allowed",
  () => hook({ tool: "write" }, { args: { path: ".env.example" } }),
);
await expectThrow(
  "read .env.example.local remains blocked",
  () => hook({ tool: "read" }, { args: { path: ".env.example.local" } }),
);
await expectNoThrow(
  "token guard allows cat .env.example literal",
  () => hook({ tool: "bash" }, { args: { command: "cat .env.example" } }),
);
await expectThrow(
  "safe example cannot mask real .env in mixed command",
  () => hook(
    { tool: "bash" },
    { args: { command: "cat .env .env.example" } },
  ),
);
await expectThrow(
  "safe example cannot mask .env.production in mixed command",
  () => hook(
    { tool: "bash" },
    { args: { command: "cat .env.production .env.example" } },
  ),
);
await expectThrow(
  "cat .env blocked",
  () => hook({ tool: "bash" }, { args: { command: "cat .env" } }),
);
await expectThrow(
  "grep TOKEN .env blocked",
  () => hook({ tool: "bash" }, { args: { command: "grep TOKEN .env" } }),
);
await expectThrow(
  "python open .env blocked",
  () => hook({ tool: "bash" }, { args: { command: "python3 -c 'print(open(\".env\").read())'" } }),
);
await expectThrow(
  "cat project secret blocked",
  () => hook({ tool: "bash" }, { args: { command: "cat config/secrets" } }),
);
await expectThrow(
  "cat private pem blocked",
  () => hook({ tool: "bash" }, { args: { command: "cat certs/private.pem" } }),
);
await expectNoThrow(
  "normal config read via bash allowed",
  () => hook({ tool: "bash" }, { args: { command: "cat config/app.yaml" } }),
);

// --- 7. Non-bash tools untouched ---------------------------------------------
await expectNoThrow(
  "read tool on normal file allowed",
  () => hook({ tool: "read" }, { args: { path: "normal.txt" } }),
);

await expectThrow(
  "apply_patch traversal into .ssh blocked",
  () => hook(
    { tool: "apply_patch" },
    {
      args: {
        patchText: "*** Update File: safe/../.ssh/config\n@@\n-old\n+new\n",
      },
    },
  ),
);

await expectNoThrow(
  "apply_patch safe file allowed",
  () => hook({ tool: "apply_patch" }, { args: { patchText: "*** Add File: x.ts\n" } }),
);
await expectNoThrow(
  "apply_patch .env.example allowed",
  () => hook(
    { tool: "apply_patch" },
    { args: { patchText: "*** Update File: .env.example\n@@\n-old\n+new\n" } },
  ),
);
await expectThrow(
  "apply_patch .env.example.local remains blocked",
  () => hook(
    { tool: "apply_patch" },
    { args: { patchText: "*** Update File: .env.example.local\n@@\n-old\n+new\n" } },
  ),
);

// --- Summary ---
console.log(`\ntoken-guard: ${pass} passed, ${fail} failed`);
if (fail > 0) {
  console.log("Failed tests:");
  for (const f of fails) console.log(`  - ${f}`);
  process.exit(1);
}
