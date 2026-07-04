#!/usr/bin/env python3
"""
audit-upstreams.py
OpenCode Power Kit — scan repo for upstream dependency references.

Scans for:
- GitHub URLs (github.com)
- git+https references
- npm package references (npx, npm install)
- pip/pipx references
- Cargo references

Outputs a structured report of all upstream dependencies found.
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple


class UpstreamRef(NamedTuple):
    file: str
    line: int
    ref_type: str  # github, git+https, npm, pip, cargo
    value: str


# Patterns to scan
PATTERNS = {
    "github": re.compile(r"github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+"),
    "git+https": re.compile(r"git\+https://github\.com/[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+"),
    "npm_npx": re.compile(r"(?:npx|npm install|npm i -g)\s+[a-zA-Z0-9._@/-]+"),
    "pip_pipx": re.compile(r"(?:pip install|pipx install)\s+[a-zA-Z0-9._-]+"),
    "cargo": re.compile(r"cargo install\s+[a-zA-Z0-9._-]+"),
}

# Files/dirs to skip
SKIP_DIRS = {".git", "node_modules", ".tmp", ".opk-trash", "vendor"}
SKIP_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".svg", ".ico", ".woff", ".woff2", ".ttf", ".eot"}


def rg_search(pattern: str, path: str) -> list[UpstreamRef]:
    """Use ripgrep to search for pattern in path."""
    results = []
    try:
        proc = subprocess.run(
            ["rg", "-n", "--no-heading", "-e", pattern, path, "--glob", "!.git", "--glob", "!node_modules", "--glob", "!.tmp"],
            capture_output=True, text=True, timeout=30
        )
        for line in proc.stdout.strip().split("\n"):
            if not line:
                continue
            parts = line.split(":", 2)
            if len(parts) >= 3:
                filepath = parts[0]
                try:
                    lineno = int(parts[1])
                except ValueError:
                    continue
                content = parts[2]
                # Extract the actual match
                for ref_type, pat in PATTERNS.items():
                    m = pat.search(content)
                    if m:
                        results.append(UpstreamRef(filepath, lineno, ref_type, m.group()))
                        break
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return results


def scan_repo(root: str) -> dict[str, list[UpstreamRef]]:
    """Scan entire repo for upstream references."""
    all_refs: dict[str, list[UpstreamRef]] = {}

    # Scan for GitHub URLs
    for ref in rg_search(r"github\.com/", root):
        all_refs.setdefault("github", []).append(ref)

    # Scan for git+https
    for ref in rg_search(r"git\+https://", root):
        all_refs.setdefault("git+https", []).append(ref)

    # Scan for npm/npx
    for ref in rg_search(r"(?:npx|npm install|npm i -g)\s+", root):
        all_refs.setdefault("npm", []).append(ref)

    # Scan for pip/pipx
    for ref in rg_search(r"(?:pip install|pipx install)\s+", root):
        all_refs.setdefault("pip", []).append(ref)

    # Scan for cargo
    for ref in rg_search(r"cargo install\s+", root):
        all_refs.setdefault("cargo", []).append(ref)

    return all_refs


def format_report(refs: dict[str, list[UpstreamRef]]) -> str:
    """Format scan results as a text report."""
    total = sum(len(v) for v in refs.values())
    lines = [f"Found {total} upstream references across {len(refs)} categories:\n"]

    for ref_type, ref_list in sorted(refs.items()):
        lines.append(f"## {ref_type.upper()} ({len(ref_list)} references)")
        seen = set()
        for ref in sorted(ref_list, key=lambda r: (r.file, r.line)):
            key = f"{ref.file}:{ref.line}:{ref.value}"
            if key not in seen:
                seen.add(key)
                lines.append(f"  {ref.file}:{ref.line}  →  {ref.value}")
        lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Scan repo for upstream dependency references."
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit with error if references found (for CI)."
    )
    parser.add_argument(
        "--write",
        metavar="FILE",
        help="Write report to FILE instead of stdout."
    )
    parser.add_argument(
        "path",
        nargs="?",
        default=".",
        help="Directory to scan (default: current directory)."
    )
    args = parser.parse_args()

    root_path = Path(args.path).resolve()

    print(f"Scanning {root_path} for upstream references...\n")

    refs = scan_repo(str(root_path))
    total = sum(len(v) for v in refs.values())

    report = format_report(refs)
    print(report)

    if args.write:
        write_path = Path(args.write)
        write_path.parent.mkdir(parents=True, exist_ok=True)
        write_path.write_text(report, encoding="utf-8")
        print(f"Report written to {write_path}")

    if args.check:
        if total > 0:
            print(f"ERROR: {total} upstream references found. Review and document in docs/UPSTREAM_AUDIT.md")
            sys.exit(1)
        else:
            print("OK: No upstream references found.")
            sys.exit(0)


if __name__ == "__main__":
    main()
