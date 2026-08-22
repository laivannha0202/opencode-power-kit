#!/usr/bin/env node
// ============================================================================
// test-safety-plugin.mjs
//
// Runtime behavioral test for templates/plugins/opk-safety-guard.js.
//
// Important:
// - The runtime plugin must expose only ONE distinct callable factory when
//   loaded through dynamic import (the path OpenCode uses for local plugins).
// - Guard behavior is tested through the real `tool.execute.before` hook.
// - No private helper function needs to be exported from the runtime module.
//
// Run: node scripts/test-safety-plugin.mjs
// ============================================================================

import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");
const PLUGIN_PATH = join(ROOT, "templates/plugins/opk-safety-guard.js");

let pass = 0;
let fail = 0;

function check(name, condition) {
  if (condition) {
    pass += 1;
    console.log(`  [ok]   ${name}`);
  } else {
    fail += 1;
    console.error(`  [FAIL] ${name}`);
  }
}

const OPKSafetyGuard = require(PLUGIN_PATH);
check("CommonJS export is one plugin factory", typeof OPKSafetyGuard === "function");

const forbiddenHelperExports = [
  "findDangerousCommand",
  "guardToolCall",
  "isSensitivePath",
  "extractPatchPaths",
];
for (const name of forbiddenHelperExports) {
  check(`runtime export does not expose helper: ${name}`, !(name in OPKSafetyGuard));
}

const namespace = await import(pathToFileURL(PLUGIN_PATH).href);
const callableExports = Object.values(namespace).filter(
  (value) => typeof value === "function",
);
const distinctCallableExports = [...new Set(callableExports)];

check(
  "dynamic import exposes exactly one distinct callable plugin factory",
  distinctCallableExports.length === 1,
);

if (distinctCallableExports.length !== 1) {
  console.error(
    "  callable exports:",
    Object.entries(namespace)
      .filter(([, value]) => typeof value === "function")
      .map(([name]) => name)
      .join(", ") || "(none)",
  );
}

let hook = null;
try {
  const plugin = await OPKSafetyGuard({});
  hook = plugin && plugin["tool.execute.before"];
  check("plugin returns tool.execute.before hook", typeof hook === "function");
} catch (error) {
  check(`plugin factory instantiation failed: ${error?.message || error}`, false);
}

const corpus = JSON.parse(
  readFileSync(join(ROOT, "templates/guard/guard-corpus.json"), "utf8"),
);

if (typeof hook === "function") {
  for (const c of corpus.cases) {
    let blocked = false;
    try {
      await hook({ tool: "bash" }, { args: { command: c.cmd } });
    } catch {
      blocked = true;
    }
    const got = blocked ? "block" : "allow";
    if (got === c.verdict) {
      pass += 1;
    } else {
      fail += 1;
      console.error(`MISMATCH expect=${c.verdict} got=${got} cmd=[${c.cmd}]`);
    }
  }

  let sensitiveReadBlocked = false;
  try {
    await hook({ tool: "read" }, { args: { path: ".env" } });
  } catch {
    sensitiveReadBlocked = true;
  }
  check("read .env is blocked through public hook", sensitiveReadBlocked);

  let safeReadAllowed = true;
  try {
    await hook({ tool: "read" }, { args: { path: "README.md" } });
  } catch {
    safeReadAllowed = false;
  }
  check("read README.md is allowed through public hook", safeReadAllowed);

  let sensitivePatchBlocked = false;
  try {
    await hook(
      { tool: "apply_patch" },
      { args: { patchText: "*** Update File: .env\n@@\n-old\n+new\n" } },
    );
  } catch {
    sensitivePatchBlocked = true;
  }
  check("apply_patch touching .env is blocked through public hook", sensitivePatchBlocked);
}

console.log(`\nsafety-plugin runtime test: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
