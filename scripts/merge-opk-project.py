#!/usr/bin/env python3
# ============================================================================
# merge-opk-project.py
#
# Cài OPK vào một project mà KHÔNG ghi đè cấu hình tùy chỉnh của user.
#
#   - AGENTS.md / OPENCODE.md: dùng managed marker, idempotent, giữ nội dung
#     tùy chỉnh ngoài marker.
#   - .opencode/opencode.json: giữ nguyên model/provider/MCP/formatter/LSP/
#     custom agents/commands/plugins và mọi key không thuộc OPK. Thêm
#     AGENTS.md + OPENCODE.md vào instructions nếu thiếu. Thêm plugin OPK
#     cần thiết nếu thiếu. Chỉ dùng permission mặc định khi project chưa có
#     permission. Backup trước mọi thay đổi.
#   - Safety plugin: copy vào .opencode/plugins/ (backup nếu đã tồn tại OPK
#     plugin; KHÔNG ghi đè plugin tùy chỉnh không thuộc OPK).
#
# Exit 0 = ok, 1 = error.
# ============================================================================
from __future__ import annotations

import json
import os
import shutil
import sys
import time
from pathlib import Path

MARKER_OPEN = "<!-- >>> opencode-power-kit managed:v2 -->"
MARKER_CLOSE = "<!-- <<< opencode-power-kit managed:v2 -->"

KIT_DIR = Path(__file__).resolve().parent.parent
PROJECT_DIR = Path.cwd()
DRY_RUN = False

# Safety plugin detect marker
OPK_PLUGIN_MARKER = "@opk-plugin opk-safety-guard"


def log(msg: str) -> None:
    print(f"[merge] {msg}")


def backup_path(target: Path) -> Path:
    """Tạo backup file với timestamp chống collision (nanosecond + pid)."""
    ts = time.strftime("%Y%m%d-%H%M%S") + f"-{time.time_ns() % 1_000_000:06d}"
    bp = target.with_suffix(target.suffix + f".opk-bak.{ts}.{os.getpid()}")
    return bp


def strip_jsonc(text: str) -> str:
    out = []
    i = 0
    n = len(text)
    in_block = in_line = in_string = False
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if in_string:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(nxt)
                i += 2
                continue
            if c == '"':
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


def merge_md(filename: str) -> bool:
    """Trả về True nếu file bị thay đổi."""
    template = KIT_DIR / "templates" / filename
    target = PROJECT_DIR / filename
    if not template.is_file():
        log(f"thiếu template {filename}, bỏ qua")
        return False

    template_text = template.read_text(encoding="utf-8").strip()
    block = f"{MARKER_OPEN}\n{template_text}\n{MARKER_CLOSE}"

    if not target.exists():
        if not DRY_RUN:
            target.write_text(block + "\n", encoding="utf-8")
        log(f"{filename}: tạo mới từ template (managed block)")
        return True

    existing = target.read_text(encoding="utf-8")
    if MARKER_OPEN in existing:
        # Replace existing managed block content.
        before = existing[: existing.index(MARKER_OPEN)]
        after = existing[existing.index(MARKER_CLOSE) + len(MARKER_CLOSE):]
        new_text = before + block + after
        if new_text == existing:
            log(f"{filename}: không đổi (managed block đã khớp)")
            return False
        if not DRY_RUN:
            bp = backup_path(target)
            shutil.copy2(target, bp)
            target.write_text(new_text, encoding="utf-8")
        log(f"{filename}: cập nhật managed block (backup: {bp.name if not DRY_RUN else '<dry>'})")
        return True

    # No marker. Is it the stock OPK template (unchanged)?
    if existing.strip() == template_text:
        if not DRY_RUN:
            target.write_text(block + "\n", encoding="utf-8")
        log(f"{filename}: migrate stock template -> managed block")
        return True

    # Custom user file: append managed block, do not touch existing content.
    if MARKER_OPEN in existing:
        return False  # already handled above
    new_text = existing.rstrip() + f"\n\n{MARKER_OPEN}\n{template_text}\n{MARKER_CLOSE}\n"
    if not DRY_RUN:
        bp = backup_path(target)
        shutil.copy2(target, bp)
        target.write_text(new_text, encoding="utf-8")
    log(f"{filename}: giữ nguyên nội dung user + append OPK managed block (backup: {bp.name if not DRY_RUN else '<dry>'})")
    return True


def merge_opencode_json() -> bool:
    template = KIT_DIR / "templates" / "opencode.json"
    target = PROJECT_DIR / ".opencode" / "opencode.json"
    if not template.is_file():
        log("thiếu templates/opencode.json, bỏ qua json merge")
        return False

    default_perm = json.loads(strip_jsonc(template.read_text(encoding="utf-8"))).get("permission")
    default_plugins = json.loads(strip_jsonc(template.read_text(encoding="utf-8"))).get("plugin", [])

    if target.exists():
        try:
            cur = json.loads(strip_jsonc(target.read_text(encoding="utf-8")))
        except Exception as e:  # noqa: BLE001
            log(f"LỖI parse {target}: {e} — backup và thay bằng merge an toàn")
            cur = {}
    else:
        cur = {}

    changed = False

    # instructions: add AGENTS.md + OPENCODE.md if missing
    inst = list(cur.get("instructions", []))
    for needed in ("AGENTS.md", "OPENCODE.md"):
        if needed not in inst:
            inst.append(needed)
            changed = True
    if "instructions" not in cur or cur.get("instructions") != inst:
        cur["instructions"] = inst
        changed = True

    # plugins: union with default OPK plugins, keep user plugins
    plugs = list(cur.get("plugin", []))
    for p in default_plugins:
        if p not in plugs:
            plugs.append(p)
            changed = True
    if "plugin" not in cur or cur.get("plugin") != plugs:
        cur["plugin"] = plugs
        changed = True

    # permission: only add default if project has none
    if "permission" not in cur and default_perm is not None:
        cur["permission"] = default_perm
        changed = True

    # Copy $schema if missing
    if "$schema" not in cur:
        cur["$schema"] = "https://opencode.ai/config.json"
        changed = True

    if not changed:
        log(".opencode/opencode.json: không đổi (giữ nguyên cấu hình user)")
        return False

    if not DRY_RUN:
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists():
            bp = backup_path(target)
            shutil.copy2(target, bp)
            log(f".opencode/opencode.json: backup -> {bp.name}")
        target.write_text(json.dumps(cur, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    log(".opencode/opencode.json: merge hoàn tất (giữ model/provider/MCP/custom keys)")
    return True


def install_safety_plugin() -> bool:
    template = KIT_DIR / "templates" / "plugins" / "opk-safety-guard.js"
    target = PROJECT_DIR / ".opencode" / "plugins" / "opk-safety-guard.js"
    if not template.is_file():
        log("thiếu templates/plugins/opk-safety-guard.js, bỏ qua")
        return False

    if target.exists():
        content = target.read_text(encoding="utf-8")
        if OPK_PLUGIN_MARKER in content:
            # OPK plugin: safe to update.
            if not DRY_RUN:
                bp = backup_path(target)
                shutil.copy2(target, bp)
                shutil.copy2(template, target)
            log(f"safety plugin: cập nhật OPK plugin (backup: {bp.name if not DRY_RUN else '<dry>'})")
            return True
        else:
            log("safety plugin: file tồn tại nhưng KHÔNG phải OPK plugin — bỏ qua (không ghi đè)")
            return False

    if not DRY_RUN:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(template, target)
    log("safety plugin: cài mới vào .opencode/plugins/")
    return True


def main() -> int:
    global DRY_RUN, PROJECT_DIR
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--dry-run":
            DRY_RUN = True
        elif a == "--project-dir":
            i += 1
            PROJECT_DIR = Path(args[i]).resolve()
        elif a == "--kit-dir":
            i += 1
            # KIT_DIR already resolved; ignore override but accept
        i += 1

    if DRY_RUN:
        log("DRY RUN — không ghi file")

    log(f"kit:  {KIT_DIR}")
    log(f"project: {PROJECT_DIR}")

    chang = False
    chang |= merge_md("AGENTS.md")
    chang |= merge_md("OPENCODE.md")
    chang |= merge_opencode_json()
    chang |= install_safety_plugin()

    if not chang:
        log("không có thay đổi cần thiết.")
    else:
        log("hoàn tất." if not DRY_RUN else "dry run hoàn tất.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
