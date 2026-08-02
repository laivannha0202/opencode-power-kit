#!/usr/bin/env python3
"""Reject legacy project config paths outside explicit migration/test history."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LEGACY = ".opencode/opencode.json"
ALLOW_LEGACY = {
    "scripts/merge-opk-project.py",
    "scripts/check-opencode-config-paths.py",
    "scripts/integration-test.sh",
}
ALLOW_PREFIXES = ("docs/releases/",)
SCAN_ROOT_FILES = (
    "bin/opk",
    "install.sh",
    "install-global.sh",
    "bootstrap.sh",
    "verify.sh",
    "doctor.sh",
    "setup.sh",
    "uninstall.sh",
    "update-bmad.sh",
)


def candidates() -> list[Path]:
    files = [ROOT / name for name in SCAN_ROOT_FILES]
    files.extend(ROOT.glob("scripts/*"))
    return sorted(path for path in files if path.is_file() and not path.name.startswith("test-"))


def main() -> int:
    errors: list[str] = []
    for path in candidates():
        relative = path.relative_to(ROOT).as_posix()
        if relative in ALLOW_LEGACY or relative.startswith(ALLOW_PREFIXES):
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        for number, line in enumerate(text.splitlines(), 1):
            if LEGACY in line and "legacy" not in line.lower():
                errors.append(f"{relative}:{number}: production code treats {LEGACY} as active config")

    installer = (ROOT / "install-global.sh").read_text(encoding="utf-8")
    helper = (ROOT / "scripts" / "install-global.py").read_text(encoding="utf-8")
    combined = installer + helper
    if re.search(r"export\s+OPENCODE_CONFIG_DIR=.*(?:OPK_KIT_DIR|opencode-global)", combined):
        errors.append("global installer exports OPENCODE_CONFIG_DIR into the tracked kit")

    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print("OpenCode config path contract: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
