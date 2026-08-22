#!/usr/bin/env python3
"""Static contract for deterministic required OpenCode CI + latest canary."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VERSIONS = ROOT / "scripts/upstream-versions.sh"
WORKFLOW = ROOT / ".github/workflows/ci.yml"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(f"[FAIL] {message}")


versions = VERSIONS.read_text(encoding="utf-8")
workflow = WORKFLOW.read_text(encoding="utf-8")

pins = re.findall(
    r'^\s*:\s*"\$\{OPK_OPENCODE_VERSION:=([0-9]+\.[0-9]+\.[0-9]+)\}"\s*$',
    versions,
    flags=re.MULTILINE,
)
require(len(pins) == 1, "expected exactly one semver OPK_OPENCODE_VERSION pin")
pin = pins[0]
require(
    re.search(
        r"^export\s+OPK_OPENCODE_VERSION(?:\s|$)",
        versions,
        flags=re.MULTILINE,
    )
    is not None,
    "OPK_OPENCODE_VERSION must be exported",
)

required_marker = "  release-gate:\n"
canary_marker = "  opencode-latest-canary:\n"
require(workflow.count(required_marker) == 1, "required release-gate job missing/duplicated")
require(workflow.count(canary_marker) == 1, "latest canary job missing/duplicated")

required_start = workflow.index(required_marker)
canary_start = workflow.index(canary_marker)
require(required_start < canary_start, "canary must be a separate job after required lane")
required = workflow[required_start:canary_start]
canary = workflow[canary_start:]

require(
    "unset OPK_OPENCODE_VERSION" in required,
    "required CI must ignore external OpenCode pin overrides",
)
require(
    "source scripts/upstream-versions.sh" in required,
    "required CI must read the central upstream pin",
)
require(
    'npm install -g "opencode-ai@${OPK_OPENCODE_VERSION}"' in required,
    "required CI must install exact central OpenCode pin",
)
require(
    'actual="$(opencode --version)"' in required
    and '[[ "$actual" != "$OPK_OPENCODE_VERSION" ]]' in required,
    "required CI must verify the installed OpenCode version",
)
require(
    "bash scripts/release-gate.sh" in required,
    "required pinned lane must run the full release gate",
)
require(
    "opencode-ai@latest" not in required,
    "required lane must never install @latest",
)
require(
    re.search(r"npm install -g\s+opencode-ai(?:\s|$)", required) is None,
    "required lane contains an unversioned opencode-ai install",
)

require(
    "continue-on-error: true" in canary,
    "latest compatibility job must be non-blocking",
)
require(
    "npm install -g opencode-ai@latest" in canary,
    "canary must intentionally track OpenCode latest",
)
require(
    "bash scripts/test-opencode-resolved-config.sh" in canary,
    "canary must exercise the real OpenCode resolved-config compatibility smoke",
)
require(
    "bash scripts/release-gate.sh" not in canary,
    "latest canary should stay focused instead of duplicating the entire release gate",
)

# There should be exactly one intentional use of @latest in the whole workflow.
require(
    workflow.count("opencode-ai@latest") == 1,
    "workflow must contain exactly one @latest install, in the canary",
)

print(f"test-ci-opencode-pin: OK (required={pin}, latest canary=non-blocking)")
