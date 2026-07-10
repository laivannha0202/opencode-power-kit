#!/usr/bin/env python3
# ============================================================================
# detect-mode.py
#
# Parse một OpenCode config JSON/JSONC và xác định mode:
#   POWER  - permission == "allow" (hoặc permission["*"]=="allow")
#            và bash/edit/write/task không bắt buộc ask/deny
#   SAFE   - permission["*"] == "ask" và bash["*"] == "ask"
#            và edit/task là ask
#   CUSTOM - không khớp hai profile trên
#
# In ra một trong: POWER | SAFE | CUSTOM
# Exit 0 on success, 1 on error.
# ============================================================================
import json
import sys
from pathlib import Path


def strip_jsonc(text: str) -> str:
    """Loại bỏ comment // và /* */ (không hoàn hảo nhưng đủ cho config OPK)."""
    out = []
    i = 0
    n = len(text)
    in_block = False
    in_line = False
    in_string = False
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_string:
            out.append(c)
            if c == "\\":
                if i + 1 < n:
                    out.append(nxt)
                    i += 2
                    continue
            elif c == '"':
                in_string = False
            i += 1
            continue
        if in_block:
            if c == "*" and nxt == "/":
                in_block = False
                i += 2
                continue
            i += 1
            continue
        if in_line:
            if c == "\n":
                in_line = False
            i += 1
            continue
        if c == '"':
            in_string = True
            out.append(c)
            i += 1
            continue
        if c == "/" and nxt == "*":
            in_block = True
            i += 2
            continue
        if c == "/" and nxt == "/":
            in_line = True
            i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def mode_of(perm) -> str:
    if isinstance(perm, str):
        if perm == "allow":
            return "POWER"
        if perm == "ask":
            return "SAFE"
        return "CUSTOM"
    if not isinstance(perm, dict):
        return "CUSTOM"

    top = perm.get("*")
    bash = perm.get("bash") if isinstance(perm.get("bash"), dict) else {}
    bash_wild = bash.get("*") if isinstance(bash, dict) else None
    write = perm.get("write")
    edit = perm.get("edit")
    task = perm.get("task")

    power_ok = (
        top == "allow"
        and (bash_wild in (None, "allow"))
        and (write in (None, "allow"))
        and (edit in (None, "allow"))
        and (task in (None, "allow"))
    )
    if power_ok:
        return "POWER"

    safe_ok = (
        top == "ask"
        and (bash_wild in (None, "ask"))
        and (edit in (None, "ask"))
        and (task in (None, "ask"))
    )
    if safe_ok:
        return "SAFE"

    return "CUSTOM"


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: detect-mode.py <config.json>", file=sys.stderr)
        return 1
    p = Path(sys.argv[1])
    if not p.is_file():
        print(f"detect-mode: file không tồn tại: {p}", file=sys.stderr)
        return 1
    try:
        data = json.loads(strip_jsonc(p.read_text(encoding="utf-8")))
    except Exception as e:  # noqa: BLE001
        print(f"detect-mode: JSON parse lỗi: {e}", file=sys.stderr)
        return 1
    perm = data.get("permission", {})
    print(mode_of(perm))
    return 0


if __name__ == "__main__":
    sys.exit(main())
