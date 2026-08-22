#!/usr/bin/env node
// Read-only runtime compatibility checker for OPK local plugins.
// It intentionally validates only public loader/runtime behavior.

import { lstatSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import { pathToFileURL } from "node:url";

function fail(message) {
  throw new Error(message);
}

function parseArgs(argv) {
  const args = { safety: "", token: "" };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--safety") {
      args.safety = argv[++i] || "";
    } else if (arg === "--token") {
      args.token = argv[++i] || "";
    } else if (arg === "-h" || arg === "--help") {
      console.log(
        "Usage: check-runtime-plugins.mjs --safety PATH [--token PATH]",
      );
      process.exit(0);
    } else {
      fail(`unknown argument: ${arg}`);
    }
  }
  if (!args.safety && !args.token) {
    fail("at least one of --safety/--token is required");
  }
  return args;
}

function requireRegularFile(path, label) {
  let st;
  try {
    st = lstatSync(path);
  } catch (error) {
    fail(`${label} missing: ${path} (${error.code || error.message})`);
  }
  if (st.isSymbolicLink()) fail(`${label} must not be a symlink: ${path}`);
  if (!st.isFile()) fail(`${label} is not a regular file: ${path}`);
}

async function loadFactory(path, marker, label) {
  const absolute = resolve(path);
  requireRegularFile(absolute, label);

  const source = readFileSync(absolute, "utf8");
  if (!source.includes(marker)) {
    fail(`${label} missing managed marker ${marker}`);
  }

  let namespace;
  try {
    // Dynamic import is intentionally used because this is the compatibility
    // shape OpenCode uses for local JavaScript plugins.
    namespace = await import(pathToFileURL(absolute).href);
  } catch (error) {
    fail(`${label} dynamic import failed: ${error.message}`);
  }

  const callables = Object.values(namespace).filter(
    (value) => typeof value === "function",
  );
  const distinct = [...new Set(callables)];
  if (distinct.length !== 1) {
    fail(
      `${label} must expose exactly one distinct callable factory; got ${distinct.length}`,
    );
  }

  let hooks;
  try {
    hooks = await distinct[0]({});
  } catch (error) {
    fail(`${label} factory failed to instantiate: ${error.message}`);
  }
  if (!hooks || typeof hooks !== "object") {
    fail(`${label} factory did not return a hook object`);
  }
  return hooks;
}

async function expectBlocked(hook, input, output, label) {
  let blocked = false;
  try {
    await hook(input, output);
  } catch {
    blocked = true;
  }
  if (!blocked) fail(`${label}: expected BLOCK`);
}

async function expectAllowed(hook, input, output, label) {
  try {
    await hook(input, output);
  } catch (error) {
    fail(`${label}: expected ALLOW, got ${error.message}`);
  }
}

async function checkSafety(path) {
  const hooks = await loadFactory(
    path,
    "@opk-plugin opk-safety-guard",
    "safety guard",
  );
  const hook = hooks["tool.execute.before"];
  if (typeof hook !== "function") {
    fail("safety guard missing tool.execute.before hook");
  }

  await expectBlocked(
    hook,
    { tool: "bash" },
    { args: { command: "rm -rf /tmp/opk-runtime-check" } },
    "safety destructive command smoke",
  );
  await expectAllowed(
    hook,
    { tool: "bash" },
    { args: { command: "git status --short" } },
    "safety normal command smoke",
  );
  await expectBlocked(
    hook,
    { tool: "read" },
    { args: { path: ".env" } },
    "safety secret read smoke",
  );
  await expectAllowed(
    hook,
    { tool: "read" },
    { args: { path: "README.md" } },
    "safety normal read smoke",
  );
}

async function checkToken(path) {
  const hooks = await loadFactory(
    path,
    "@opk-plugin opk-token-guard",
    "token guard",
  );
  const toolHook = hooks["tool.execute.before"];
  const envHook = hooks["shell.env"];
  if (typeof toolHook !== "function") {
    fail("token guard missing tool.execute.before hook");
  }
  if (typeof envHook !== "function") {
    fail("token guard missing shell.env hook");
  }

  await expectBlocked(
    toolHook,
    { tool: "read" },
    { args: { path: ".env" } },
    "token secret path smoke",
  );
  await expectAllowed(
    toolHook,
    { tool: "read" },
    { args: { path: ".env.example" } },
    "token env example smoke",
  );
  await expectBlocked(
    toolHook,
    { tool: "bash" },
    { args: { command: "echo $OPK_RUNTIME_CHECK_TOKEN" } },
    "token shell expansion smoke",
  );

  const name = "OPK_RUNTIME_CHECK_TOKEN";
  const old = process.env[name];
  try {
    process.env[name] = "opk-runtime-check-secret-value";
    const output = { env: { SAFE_RUNTIME_CHECK: "keep" } };
    await envHook(
      {
        cwd: process.cwd(),
        sessionID: "opk-runtime-check-session",
        callID: "opk-runtime-check-call",
      },
      output,
    );
    if (output.env[name] !== "") {
      fail("token guard shell.env did not blank agent secret env");
    }
    if (output.env.SAFE_RUNTIME_CHECK !== "keep") {
      fail("token guard shell.env changed a safe env value");
    }
    if (process.env[name] !== "opk-runtime-check-secret-value") {
      fail("token guard shell.env mutated parent process.env");
    }
  } finally {
    if (old === undefined) delete process.env[name];
    else process.env[name] = old;
  }
}

const args = parseArgs(process.argv.slice(2));

try {
  if (args.safety) await checkSafety(args.safety);
  if (args.token) await checkToken(args.token);
  const checked = [
    args.safety ? "safety" : "",
    args.token ? "token" : "",
  ].filter(Boolean).join("+");
  console.log(`RUNTIME_PLUGINS=PASS checked=${checked}`);
} catch (error) {
  console.error(`RUNTIME_PLUGINS=FAIL ${error.message}`);
  process.exit(1);
}
