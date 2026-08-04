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
const plugin = await OPKTokenGuard({});
check(
  "plugin returns object with tool.execute.before",
  plugin && typeof plugin["tool.execute.before"] === "function",
);

const hook = plugin["tool.execute.before"];

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

// --- 7. Non-bash tools untouched ---------------------------------------------
await expectNoThrow(
  "read tool on normal file allowed",
  () => hook({ tool: "read" }, { args: { path: "normal.txt" } }),
);
await expectNoThrow(
  "apply_patch safe file allowed",
  () => hook({ tool: "apply_patch" }, { args: { patchText: "*** Add File: x.ts\n" } }),
);

// --- Summary ---
console.log(`\ntoken-guard: ${pass} passed, ${fail} failed`);
if (fail > 0) {
  console.log("Failed tests:");
  for (const f of fails) console.log(`  - ${f}`);
  process.exit(1);
}
