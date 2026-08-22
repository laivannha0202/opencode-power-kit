#!/usr/bin/env python3
"""Static regression contract for OPK Phase-1 runtime hardening."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []


def need(cond: bool, message: str) -> None:
    if not cond:
        ERRORS.append(message)


def text(rel: str) -> str:
    path = ROOT / rel
    need(path.is_file() and not path.is_symlink(), f"missing/unsafe: {rel}")
    return path.read_text(encoding="utf-8") if path.is_file() else ""


# Primary-router config contract.
for rel in ("templates/opencode.json", "templates/opencode.power.json", "templates/opencode.safe.json"):
    try:
        data = json.loads(text(rel))
    except Exception as exc:
        ERRORS.append(f"{rel}: invalid JSON: {exc}")
        continue
    need(data.get("default_agent") == "opk-main", f"{rel}: default_agent must be opk-main")
    need(data.get("subagent_depth") == 1, f"{rel}: subagent_depth must be 1")
    bash = data.get("permission", {}).get("bash", {})
    for pattern in (
        "*.env*", "*secret*", "*private-key*", "*.pem*", "*.key*",
        "*credentials*", "*.netrc*", "*.ssh/*", "*.aws/credentials*",
        "*.kube/config*", "*opencode/auth.json*", "*claude/credentials.json*",
    ):
        need(bash.get(pattern) == "deny", f"{rel}: missing bash secret deny {pattern}")

agent = text("opencode-global/agents/opk-main.md")
need("mode: primary" in agent, "opk-main must be primary")
need("@opk-managed-agent opk-main" in agent, "opk-main managed marker missing")
need("build-strong" in agent and "review-lite" in agent, "opk-main routing contract incomplete")

# Both runtime guards must be shipped by project/global installers.
merge = text("scripts/merge-opk-project.py")
need("opk-safety-guard.js" in merge and "opk-token-guard.js" in merge, "project installer must deploy both guards")
need("agents/opk-main.md" in merge, "project installer must deploy opk-main")
global_installer = text("scripts/install-global.py")
need('self.kit / "templates" / "plugins"' in global_installer, "global installer missing authoritative template plugin source")
need('relative = f"plugins/{source.name}"' in global_installer, "global installer missing template-plugin destination mapping")

# Unattended mode must refuse stale/missing guards and router.
commands = text("scripts/opk-commands.sh")
need("_opk_require_runtime_guards" in commands, "opk auto runtime guard check missing")
need("cmp -s" in commands, "opk auto must hash/byte-match managed runtime assets")
need("opk-token-guard.js" in commands and "opk-main.md" in commands, "opk auto runtime assets incomplete")

# Shell-secret and quoted nested destructive gaps must remain covered.
token = text("templates/plugins/opk-token-guard.js")
for needle in ("isProtectedSecretPath", "findProtectedPathLiteral", "PROJECT_SECRET_PATH_PATTERNS"):
    need(needle in token, f"token guard missing {needle}")

# Check executable nested-guard structure, not historical comment wording.
safety = text("templates/plugins/opk-safety-guard.js")
for needle in (
    "function scanCommandText(command, depth = 0)",
    'if (exe === "bash" || exe === "sh" || exe === "zsh")',
    'if (exe === "eval")',
    'return scanCommandText(args.join(" "), depth + 1);',
    'if (exe === "ssh")',
    'return scanCommandText(args.slice(i).join(" "), depth + 1);',
):
    need(needle in safety, f"JS nested execution implementation missing: {needle}")

bash_guard = text("scripts/guard-rules.sh")
for needle in (
    "_opk_guard_scan_text_core() {",
    "bash|sh|zsh)",
    "eval)",
    "ssh)",
):
    need(needle in bash_guard, f"Bash nested execution implementation missing: {needle}")
need(
    bash_guard.count('_opk_guard_scan_text_core "$payload" "$((depth + 1))"') >= 3,
    "Bash nested execution recursion coverage incomplete",
)

# Shared corpus is the behavioral truth oracle for both runtimes.
corpus = json.loads(text("templates/guard/guard-corpus.json"))
verdicts = {str(c.get("cmd")): c.get("verdict") for c in corpus.get("cases", []) if isinstance(c, dict)}
need(verdicts.get('ssh user@host "rm -rf /tmp/x"') == "block", "ssh quoted destructive corpus case must block")
need(verdicts.get('eval "rm -rf /tmp/x"') == "block", "eval quoted destructive corpus case must block")

command_guard_test = text("scripts/test-command-guard.sh")
need(
    "guard-corpus.json" in command_guard_test
    and "opk_guard_check" in command_guard_test,
    "Bash guard test must execute the shared verdict corpus",
)
need(
    "sync-guard-bashrc.sh" in command_guard_test
    and "diff -q" in command_guard_test,
    "Bash guard test must enforce generated-fragment freshness",
)

safety_test = text("scripts/test-safety-plugin.mjs")
need(
    "guard-corpus.json" in safety_test
    and "for (const c of corpus.cases)" in safety_test
    and 'hook = plugin && plugin["tool.execute.before"]' in safety_test
    and 'await hook({ tool: "bash" }, { args: { command: c.cmd } });' in safety_test,
    "JS safety-plugin test must drive the shared corpus through the public hook",
)

release_gate = text("scripts/release-gate.sh")
need(
    'run_cmd "test-safety-plugin"' in release_gate
    and "scripts/test-safety-plugin.mjs" in release_gate,
    "release gate must run the JS safety-plugin behavioral test",
)
need(
    'run_cmd "test-command-guard"' in release_gate
    and "scripts/test-command-guard.sh" in release_gate,
    "release gate must run the Bash guard corpus/freshness test",
)

# Tests must prove deployment, not merely source existence.
project_test = text("scripts/test-installer-preservation.sh")
global_test = text("scripts/test-global-installer.sh")
resolved_test = text("scripts/test-opencode-resolved-config.sh")
for name, body in (("project installer", project_test), ("global installer", global_test), ("resolved config", resolved_test)):
    need("opk-token-guard.js" in body, f"{name} test missing token-guard reachability proof")
    need("opk-main" in body, f"{name} test missing opk-main proof")

# Generated BASH_ENV must embed the canonical Bash engine, not a stale copy.
generated = text("templates/guard/opk-guard-bashrc")
canonical_guard_body = bash_guard.split("\n", 1)[1] if "\n" in bash_guard else ""
need(
    bool(canonical_guard_body) and canonical_guard_body in generated,
    "generated BASH_ENV guard does not embed the canonical Bash guard",
)

# No old explicit known-gap allow should survive.
need("KNOWN SHARED GAP" not in text("templates/guard/guard-corpus.json"), "known destructive shared gap remains in corpus")

if ERRORS:
    print("hardening-contract: FAIL", file=sys.stderr)
    for error in ERRORS:
        print(f"  - {error}", file=sys.stderr)
    sys.exit(1)
print("hardening-contract: PASS")
