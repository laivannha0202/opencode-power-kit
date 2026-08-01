#!/usr/bin/env python3
"""Validate that shipped agents cannot weaken the active OPK permission mode."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DEFAULT_ROOT = Path(__file__).resolve().parent.parent
AGENT_GLOBS = (
    "opencode-global/agents/**/*.md",
    "profiles/**/agents/**/*.md",
    "templates/**/agents/**/*.md",
)
POWER_COMPATIBLE = {
    "api-strong",
    "build-strong",
    "db-strong",
    "devops-strong",
    "ecc-lite-strong",
    "hermes-lite-strong",
    "qa-strong",
    "release-strong",
}
READ_ONLY = {
    "architect-strong",
    "debug-lite",
    "debug-strong",
    "plan-lite",
    "review-lite",
    "security-strong",
    "taste-ui-strong",
    "ui-ux-strong",
}


def frontmatter(path: Path) -> str:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---\n"):
        return ""
    end = text.find("\n---", 4)
    return text[4:end] if end >= 0 else ""


def permission_block(header: str) -> str:
    match = re.search(r"(?ms)^permission:\s*\n((?:^[ \t]+.*\n?)*)", header)
    return match.group(1) if match else ""


def scalar(block: str, key: str) -> str | None:
    match = re.search(rf'(?m)^  {re.escape(key)}:\s*["\']?([a-z]+)', block)
    return match.group(1) if match else None


def bash_wildcard(block: str) -> str | None:
    match = re.search(r'(?m)^    ["\']?\*["\']?:\s*["\']?([a-z]+)', block)
    return match.group(1) if match else None


def agent_files(root: Path) -> list[Path]:
    files: set[Path] = set()
    for pattern in AGENT_GLOBS:
        files.update(root.glob(pattern))
    return sorted(path for path in files if path.is_file())


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=str(DEFAULT_ROOT))
    args = parser.parse_args()
    root = Path(args.root).resolve(strict=True)
    manifest_path = root / "scripts" / "agent-permission-exceptions.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    exceptions = manifest.get("ask_exceptions", {})
    if not isinstance(exceptions, dict):
        print("ERROR: ask_exceptions must be an object", file=sys.stderr)
        return 1
    errors: list[str] = []
    asks: list[str] = []
    power_asks: list[str] = []
    read_only_edit_allow: list[str] = []

    for name, entry in exceptions.items():
        if not isinstance(name, str) or not isinstance(entry, dict) or any(
            not isinstance(entry.get(field), str) or not entry[field].strip()
            for field in ("reason", "owner", "category", "test")
        ):
            errors.append(f"exception manifest entry {name!r} requires reason, owner, category, and test")

    files = agent_files(root)
    for path in files:
        name = path.stem
        header = frontmatter(path)
        if re.search(r"(?m)^permission:\s*\{|^[ \t]+[a-z_]+:\s*\{", header):
            errors.append(f"{path.relative_to(root)}: inline permission objects are not supported")
            continue
        block = permission_block(header)
        edit = scalar(block, "edit")
        wildcard = bash_wildcard(block)
        has_ask = bool(re.search(r'(?m):\s*["\']?ask["\']?\s*(?:#.*)?$', block))
        if has_ask:
            asks.append(name)
            if name not in exceptions:
                errors.append(f"{path.relative_to(root)}: undocumented ask permission")
        if name in POWER_COMPATIBLE and has_ask:
            power_asks.append(name)
            errors.append(f"{path.relative_to(root)}: power-compatible agent contains ask")
        if name == "build-strong" and edit == "ask":
            errors.append("build-strong: edit must inherit Power Mode, not ask")
        if name == "build-strong" and wildcard == "ask":
            errors.append("build-strong: bash wildcard must inherit Power Mode, not ask")
        if name in READ_ONLY and edit != "deny":
            read_only_edit_allow.append(name)
            errors.append(f"{path.relative_to(root)}: read-only agent edit must be deny")
        if name in READ_ONLY and wildcard != "deny":
            errors.append(f"{path.relative_to(root)}: read-only agent bash wildcard must be deny")

    stale = sorted(set(exceptions) - set(asks))
    for name in stale:
        errors.append(f"exception manifest contains stale agent: {name}")

    print(f"agents checked: {len(files)}")
    print(f"agents with ask: {len(asks)}")
    print(f"power-compatible agents with ask: {len(power_asks)}")
    print(f"read-only agents with edit allow: {len(read_only_edit_allow)}")
    print(f"undocumented exceptions: {sum('undocumented' in error for error in errors)}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
