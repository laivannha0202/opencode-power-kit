#!/usr/bin/env python3
from __future__ import annotations

import os
import stat
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OLD_SP = "6.2.0"
NEW_SP = "6.3.0"
OLD_BMAD = "6.10.0"
NEW_BMAD = "6.11.0"

errors: list[str] = []


def text(rel: str) -> str:
    p = ROOT / rel
    if not p.is_file():
        errors.append(f"missing {rel}")
        return ""
    return p.read_text(encoding="utf-8")


pins = text("scripts/upstream-versions.sh")
if f"OPK_SUPERPOWERS_VERSION:={NEW_SP}" not in pins:
    errors.append("central Superpowers pin is not 6.3.0")
if f"OPK_BMAD_VERSION:={NEW_BMAD}" not in pins:
    errors.append("central BMAD pin is not 6.11.0")

for name in ("opencode.json", "opencode.power.json", "opencode.safe.json"):
    body = text(f"templates/{name}")
    if f"superpowers.git#v{NEW_SP}" not in body:
        errors.append(f"templates/{name} not pinned to Superpowers v{NEW_SP}")

third_party = text("THIRD_PARTY.md")
for needle in (f"OPK_SUPERPOWERS_VERSION={NEW_SP}", f"OPK_BMAD_VERSION={NEW_BMAD}"):
    if needle not in third_party:
        errors.append(f"THIRD_PARTY.md missing {needle}")

prereq_path = ROOT / "scripts/check-bmad-runtime-prereqs.sh"
prereq = text("scripts/check-bmad-runtime-prereqs.sh")
if prereq_path.is_file() and not (prereq_path.stat().st_mode & stat.S_IXUSR):
    errors.append("check-bmad-runtime-prereqs.sh is not executable")
for needle in ("Node >=20.12.0", "command -v uv", "BMAD_RUNTIME_PREREQS=PASS"):
    if needle not in prereq:
        errors.append(f"BMAD prereq contract missing {needle}")

for rel in ("install.sh", "update-bmad.sh"):
    body = text(rel)
    if "check-bmad-runtime-prereqs.sh" not in body:
        errors.append(f"{rel} does not invoke BMAD prereq gate")

release_gate = text("scripts/release-gate.sh")
if "detect-mode.py uses shared JSON/JSONC parser" not in release_gate:
    errors.append("release gate still uses stale detect-mode parser heuristic")
if "test-phase2-upstream-contract" not in release_gate:
    errors.append("release gate does not run Phase-2 upstream contract")

changelog = text("CHANGELOG.md")
if "Phase-2 upstream compatibility" not in changelog:
    errors.append("CHANGELOG missing Phase-2 upstream compatibility note")

# Current-state references must not retain old pins. Historical release notes and
# CHANGELOG are intentionally excluded so release history remains immutable.
contextual_stale: list[str] = []
proc = subprocess.run(
    ["git", "-C", str(ROOT), "ls-files", "-z"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=False,
)
if proc.returncode == 0:
    for raw in proc.stdout.split(b"\0"):
        if not raw:
            continue
        rel = os.fsdecode(raw)
        if rel in ("CHANGELOG.md", "RELEASES.md") or rel.startswith("docs/releases/"):
            continue
        p = ROOT / rel
        if not p.is_file():
            continue
        try:
            body = p.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        for lineno, line in enumerate(body.splitlines(), 1):
            low = line.lower()
            if OLD_SP in line and ("superpower" in low or "opk_superpowers_version" in low):
                contextual_stale.append(f"{rel}:{lineno}: stale Superpowers {OLD_SP}")
            if OLD_BMAD in line and ("bmad" in low or "opk_bmad_version" in low):
                contextual_stale.append(f"{rel}:{lineno}: stale BMAD {OLD_BMAD}")
errors.extend(contextual_stale)

if errors:
    print("phase2-upstream-contract: FAIL")
    for e in errors:
        print(f"  - {e}")
    raise SystemExit(1)

print("phase2-upstream-contract: PASS")
