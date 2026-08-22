#!/usr/bin/env python3
"""Release metadata contract with VERSION as the current-version source."""

from __future__ import annotations

import os
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEMVER_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
DATE_RE = r"[0-9]{4}-[0-9]{2}-[0-9]{2}"

errors: list[str] = []


def read(rel: str) -> str:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"missing {rel}")
        return ""
    return path.read_text(encoding="utf-8")


version = read("VERSION").strip()
if not SEMVER_RE.fullmatch(version):
    errors.append(f"VERSION must be X.Y.Z semver, got {version!r}")

readme = read("README.md")
if "(./VERSION)" not in readme:
    errors.append("README must link its version badge/text to ./VERSION")
if re.search(
    r"img\.shields\.io/badge/version-[0-9]+\.[0-9]+\.[0-9]+-",
    readme,
):
    errors.append("README must not hardcode the current numeric version badge")

validator = read("scripts/validate-opencode-pack.py")
if re.search(
    r'(?m)^\s*EXPECTED_VERSION\s*=\s*["\'][0-9]+\.[0-9]+\.[0-9]+["\']',
    validator,
):
    errors.append("validate-opencode-pack must read VERSION, not EXPECTED_VERSION")
if 'KIT_ROOT / "VERSION"' not in validator:
    errors.append("validate-opencode-pack does not read the VERSION source")

verify = read("verify.sh")
if 'VERSION_FILE="${KIT_DIR}/VERSION"' not in verify:
    errors.append("verify.sh does not read VERSION_FILE from the kit root")

# Current-version-looking source headers are forbidden. Historical release
# sections/comments lower in files remain valid documentation.
header_surfaces = (
    "bin/opk",
    "verify.sh",
    "scripts/validate-opencode-pack.py",
    "scripts/test-command-guard.sh",
    "templates/plugins/opk-safety-guard.js",
    "templates/plugins/opk-token-guard.js",
)
header_patterns = (
    re.compile(r"(?i)\bOpenCode Power Kit CLI v[0-9]+\.[0-9]+\.[0-9]+\b"),
    re.compile(r"(?i)\bopencode-power-kit v[0-9]+\.[0-9]+\.[0-9]+\b"),
    re.compile(r"(?m)^\s*//\s*@version\s+[0-9]+\.[0-9]+\.[0-9]+\s*$"),
)
for rel in header_surfaces:
    text = read(rel)
    header = "\n".join(text.splitlines()[:20])
    for pattern in header_patterns:
        if pattern.search(header):
            errors.append(f"{rel} has a stale independent version header")
            break

changelog = read("CHANGELOG.md")
release_headings = re.findall(
    rf"^## \[([0-9]+\.[0-9]+\.[0-9]+)\] - ({DATE_RE})$",
    changelog,
    re.MULTILINE,
)
release_date = ""
if not release_headings:
    errors.append("CHANGELOG has no released semver heading")
elif version and release_headings[0][0] != version:
    errors.append(
        "first CHANGELOG release must match VERSION: "
        f"{release_headings[0][0]} != {version}"
    )
else:
    release_date = release_headings[0][1]

unreleased = re.search(
    r"^## \[Unreleased\]\s*(.*?)(?=^## \[)",
    changelog,
    re.MULTILINE | re.DOTALL,
)
if not unreleased:
    errors.append("CHANGELOG missing Unreleased section")
elif unreleased.group(1).strip():
    errors.append(
        "CHANGELOG Unreleased must be empty after cutting release metadata"
    )

if version:
    note_rel = f"docs/releases/v{version}.md"
    note = read(note_rel)
    if f"# OpenCode Power Kit v{version}" not in note:
        errors.append(f"{note_rel} heading does not match VERSION")
    if release_date and f"Release date: {release_date}" not in note:
        errors.append(
            f"{note_rel} release date does not match CHANGELOG ({release_date})"
        )

# Public CLI version must be produced from the same VERSION source.
opk = ROOT / "bin/opk"
if opk.is_file() and version:
    env = os.environ.copy()
    env["OPK_KIT_DIR"] = str(ROOT)
    proc = subprocess.run(
        [str(opk), "version"],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        errors.append(
            f"bin/opk version failed ({proc.returncode}): {proc.stderr.strip()}"
        )
    elif proc.stdout.strip() != f"opk {version}":
        errors.append(
            "bin/opk version does not reflect VERSION: "
            f"got {proc.stdout.strip()!r}, want {f'opk {version}'!r}"
        )

gate = read("scripts/release-gate.sh")
if "test-release-metadata" not in gate:
    errors.append("release gate does not run test-release-metadata")

release_process = read("docs/RELEASE_PROCESS.md")
if "single source of truth" not in release_process.lower():
    errors.append("release process does not document VERSION as single source")

if errors:
    print("release-metadata-contract: FAIL")
    for error in errors:
        print(f"  - {error}")
    raise SystemExit(1)

print(
    "release-metadata-contract: PASS "
    f"(VERSION={version}, changelog_date={release_date})"
)
