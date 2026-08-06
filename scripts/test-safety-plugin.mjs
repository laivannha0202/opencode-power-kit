#!/usr/bin/env node
// ============================================================================
// test-safety-plugin.mjs  —  opencode-power-kit v2.2.0
//
// Parity test for the JS safety plugin (templates/plugins/opk-safety-guard.js).
// Reads the shared verdict corpus (templates/guard/guard-corpus.json) and
// asserts findDangerousCommand returns null for "allow" cases and a message
// for "block" cases. Exit code 0 = full parity with the Bash engine.
//
// Run: node scripts/test-safety-plugin.mjs
// ============================================================================

import { createRequire } from "node:module";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const require = createRequire(import.meta.url);
const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");

const plugin = require(join(ROOT, "templates/plugins/opk-safety-guard.js"));
const corpus = JSON.parse(
  readFileSync(join(ROOT, "templates/guard/guard-corpus.json"), "utf8"),
);

let pass = 0;
let fail = 0;

for (const c of corpus.cases) {
  const got = plugin.findDangerousCommand(c.cmd) ? "block" : "allow";
  if (got === c.verdict) {
    pass += 1;
  } else {
    fail += 1;
    console.error(`MISMATCH expect=${c.verdict} got=${got} cmd=[${c.cmd}]`);
  }
}

console.log(`safety-plugin corpus parity: ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
