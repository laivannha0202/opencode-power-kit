#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VERSION = "2.3.0"
DATE = "2026-08-17"

errors: list[str] = []


def read(rel: str) -> str:
    p = ROOT / rel
    if not p.is_file():
        errors.append(f"missing {rel}")
        return ""
    return p.read_text(encoding="utf-8")


if read("VERSION").strip() != VERSION:
    errors.append(f"VERSION must equal {VERSION}")

readme = read("README.md")
if f"version-{VERSION}-blue.svg" not in readme:
    errors.append("README version badge is stale")

validator = read("scripts/validate-opencode-pack.py")
if f'EXPECTED_VERSION = "{VERSION}"' not in validator:
    errors.append("validate-opencode-pack EXPECTED_VERSION is stale")

verify = read("verify.sh")
if f"expected exactly {VERSION}" not in verify or f'== "{VERSION}"' not in verify:
    errors.append("verify.sh exact VERSION contract is stale")

changelog = read("CHANGELOG.md")
if not re.search(rf"^## \[{re.escape(VERSION)}\] - {DATE}$", changelog, re.MULTILINE):
    errors.append(f"CHANGELOG missing [{VERSION}] - {DATE}")

m = re.search(
    r"^## \[Unreleased\]\s*(.*?)(?=^## \[)",
    changelog,
    re.MULTILINE | re.DOTALL,
)
if not m:
    errors.append("CHANGELOG missing Unreleased section")
elif m.group(1).strip():
    errors.append("CHANGELOG Unreleased must be empty after cutting release metadata")

note = read(f"docs/releases/v{VERSION}.md")
for needle in (
    "# OpenCode Power Kit v2.3.0",
    "opk-main",
    "Superpowers `v6.3.0`",
    "BMAD Method `v6.11.0`",
    "GitHub Actions",
):
    if needle not in note:
        errors.append(f"release note missing: {needle}")

gate = read("scripts/release-gate.sh")
if "test-release-metadata" not in gate:
    errors.append("release gate does not run test-release-metadata")

if 'EXPECTED_VERSION = "2.2.0"' in validator:
    errors.append("validator still expects 2.2.0")
if "expected exactly 2.2.0" in verify:
    errors.append("verify still expects 2.2.0")

if errors:
    print("release-metadata-contract: FAIL")
    for e in errors:
        print(f"  - {e}")
    raise SystemExit(1)

print("release-metadata-contract: PASS")
