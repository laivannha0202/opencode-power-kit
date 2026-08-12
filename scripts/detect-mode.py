#!/usr/bin/env python3
# ============================================================================
# detect-mode.py
#
# Thin CLI wrapper around the single-source classification engine
# (scripts/opk_mode.py). Prints one of:
#   POWER | SAFE | CUSTOM
# and exits 0. On missing file / parse error / BROKEN config it prints a
# diagnostic to stderr and exits 1. strip_jsonc is re-exported for tests
# that import detect_mode.
# ============================================================================
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from opk_mode import classify, load_config, strip_jsonc  # noqa: F401,E402  (re-exported for tests)


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: detect-mode.py <config.json>", file=sys.stderr)
        return 1
    path = Path(sys.argv[1])
    try:
        data = load_config(path)
    except ValueError as error:
        print(f"detect-mode: JSON parse lỗi: {error}", file=sys.stderr)
        return 1
    mode, _, classification_error = classify(data, None)
    if mode == "BROKEN":
        print(f"detect-mode: BROKEN: {classification_error}", file=sys.stderr)
        return 1
    print(mode)
    return 0


if __name__ == "__main__":
    sys.exit(main())
