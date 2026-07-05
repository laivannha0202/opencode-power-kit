#!/usr/bin/env python3
"""
validate-formatting.py — Formatting guard for opencode-power-kit.

Checks minimum line counts, proper YAML structure for workflow files,
no collapsed/merged lines in key documents, and no billing references
in docs where they don't belong.

Exit 0 on PASS, 1 on FAIL.
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# ── Minimum line counts ───────────────────────────────────────────
MIN_LINES: dict[str, int] = {
    "README.md": 300,
    "docs/LOCAL_VALIDATION.md": 40,
    "docs/WEAK_MODEL_GUIDE.md": 30,
    ".github/workflows/ci.yml": 100,
    ".github/workflows/verify.yml": 50,
}

# ── Files that must NOT contain "billing" (case-insensitive) ───────
BILLING_FREE: list[str] = [
    "README.md",
]

# ── Workflow YAML checks ──────────────────────────────────────────
WORKFLOW_DIR = REPO_ROOT / ".github" / "workflows"
COLLAPSED_PATTERNS: list[tuple[str, str]] = [
    (r"name:\s*ci", r"\bon:"),       # "name: ci" then "on:" on same line
    (r"name:\s*verify", r"\bon:"),   # "name: verify" then "on:" on same line
]


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


def check_billing_free() -> int:
    fails = 0
    for rel_path in BILLING_FREE:
        full = REPO_ROOT / rel_path
        if not full.exists():
            continue
        text = full.read_text(encoding="utf-8").lower()
        if "billing" in text:
            # Find actual lines
            for i, line in enumerate(full.read_text(encoding="utf-8").splitlines(), 1):
                if "billing" in line.lower():
                    print(f"FAIL  {rel_path}:{i} contains 'billing' — {line.strip()}")
                    fails += 1
    return fails


def check_docs_no_billing() -> int:
    """Check docs/ files that should not mention billing."""
    fails = 0
    doc_dir = REPO_ROOT / "docs"
    for f in doc_dir.iterdir():
        if not f.is_file() or f.suffix.lower() not in {".md", ".markdown"}:
            continue
        text = f.read_text(encoding="utf-8").lower()
        if "billing" in text:
            for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                if "billing" in line.lower():
                    print(f"WARN  {f.name}:{i} contains 'billing' — {line.strip()}")
    return fails


def check_workflow_yaml() -> int:
    fails = 0
    if not WORKFLOW_DIR.exists():
        print("FAIL  .github/workflows/ directory missing")
        return 1

    for yml in WORKFLOW_DIR.glob("*.yml"):
        lines = yml.read_text(encoding="utf-8").splitlines()

        # Check for collapsed lines (name + on on same line)
        for name_pat, on_pat in COLLAPSED_PATTERNS:
            for i, line in enumerate(lines):
                if re.search(name_pat, line, re.IGNORECASE) and re.search(on_pat, line, re.IGNORECASE):
                    print(f"FAIL  {yml.name}:{i+1} collapsed line detected (name/on merged): {line.strip()}")
                    fails += 1

        text = "\n".join(lines)

        # Must have workflow_dispatch
        if "workflow_dispatch" not in text:
            print(f"FAIL  {yml.name}: missing workflow_dispatch")
            fails += 1

        # Must NOT have push:/pull_request:/schedule:
        for bad in ["push:", "pull_request:", "schedule:"]:
            # Only check under "on:" block
            if re.search(rf"^\s+{bad}\s*$", text, re.MULTILINE):
                print(f"FAIL  {yml.name}: contains '{bad}' (should be manual-only)")
                fails += 1

        print(f"ok    {yml.name}: YAML structure valid")

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
    required = ["Full validation pipeline", "workflow_dispatch", "Các lệnh validation"]
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

    print("[billing-free (README)]")
    fails += check_billing_free()
    print()

    print("[docs billing warnings]")
    fails += check_docs_no_billing()
    print()

    print("[workflow YAML]")
    fails += check_workflow_yaml()
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
