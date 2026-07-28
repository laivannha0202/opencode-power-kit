#!/usr/bin/env python3
"""
validate-formatting.py — Formatting guard for opencode-power-kit.

Checks minimum line counts, document integrity, and the Linux-only
local-validation distribution contract.

Exit 0 on PASS, 1 on FAIL.
"""

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# ── Minimum line counts ───────────────────────────────────────────
MIN_LINES: dict[str, int] = {
    "README.md": 300,
    "docs/LOCAL_VALIDATION.md": 40,
    "docs/WEAK_MODEL_GUIDE.md": 30,
}


def check_line_counts() -> int:
    fails = 0
    for rel_path, minimum in MIN_LINES.items():
        full = REPO_ROOT / rel_path
        if not full.exists():
            print(f"FAIL  {rel_path}: missing (min {minimum} lines)")
            fails += 1
            continue
        lines = full.read_text(encoding="utf-8").count("\n")
        if lines < minimum:
            print(f"FAIL  {rel_path}: {lines} lines, need >= {minimum}")
            fails += 1
        else:
            print(f"ok    {rel_path}: {lines} lines >= {minimum}")
    return fails


def check_linux_only_layout() -> int:
    fails = 0
    artifacts = sorted(
        p.relative_to(REPO_ROOT).as_posix()
        for suffix in ("*.ps1", "*.cmd", "*.bat")
        for p in REPO_ROOT.rglob(suffix)
        if ".git" not in p.parts and ".tmp" not in p.parts and ".test" not in p.parts
    )
    if artifacts:
        print(f"FAIL  Windows runtime artifacts found: {', '.join(artifacts)}")
        fails += 1
    else:
        print("ok    no .ps1/.cmd/.bat runtime artifacts")

    workflow_dir = REPO_ROOT / ".github" / "workflows"
    workflows = []
    if workflow_dir.is_dir():
        workflows = sorted([*workflow_dir.glob("*.yml"), *workflow_dir.glob("*.yaml")])
    if workflows:
        print("FAIL  GitHub Actions workflows must be disabled for local-only validation")
        fails += 1
    else:
        print("ok    GitHub Actions workflows disabled")

    return fails


def check_long_lines() -> int:
    """Check for abnormally long lines (>2000 chars) that aren't URLs/badges."""
    fails = 0
    for rel_path in ["README.md", "docs/LOCAL_VALIDATION.md"]:
        full = REPO_ROOT / rel_path
        if not full.exists():
            continue
        for i, line in enumerate(full.read_text(encoding="utf-8").splitlines(), 1):
            if len(line) > 2000:
                # Allow if it's a URL or badge
                stripped = line.strip()
                if not (stripped.startswith("http") or "[![" in stripped):
                    print(f"FAIL  {rel_path}:{i}: {len(line)} chars (>2000)")
                    fails += 1
    return fails


def check_local_validation_content() -> int:
    """Check LOCAL_VALIDATION.md has required sections."""
    full = REPO_ROOT / "docs" / "LOCAL_VALIDATION.md"
    if not full.exists():
        return 0
    text = full.read_text(encoding="utf-8")
    required = ["Full validation pipeline", "Linux-only", "Các lệnh validation", "release-gate.sh"]
    fails = 0
    for keyword in required:
        if keyword not in text:
            print(f"FAIL  docs/LOCAL_VALIDATION.md: missing '{keyword}'")
            fails += 1
        else:
            print(f"ok    docs/LOCAL_VALIDATION.md: contains '{keyword}'")
    return fails


def main() -> int:
    print("=" * 60)
    print("  validate-formatting.py — Formatting Guard")
    print("=" * 60)
    print()

    fails = 0

    print("[line counts]")
    fails += check_line_counts()
    print()

    print("[Linux-only layout]")
    fails += check_linux_only_layout()
    print()

    print("[long line check]")
    fails += check_long_lines()
    print()

    print("[LOCAL_VALIDATION content]")
    fails += check_local_validation_content()
    print()

    print("=" * 60)
    if fails:
        print(f"RESULT: FAIL ({fails} check(s) failed)")
        print("=" * 60)
        return 1
    else:
        print("RESULT: PASS")
        print("=" * 60)
        return 0


if __name__ == "__main__":
    sys.exit(main())
