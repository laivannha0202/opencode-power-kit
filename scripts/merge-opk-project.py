#!/usr/bin/env python3
"""Merge OPK-managed project settings without replacing user configuration."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import shutil
import stat
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

MARKER_OPEN = "<!-- >>> opencode-power-kit managed:v2 -->"
MARKER_CLOSE = "<!-- <<< opencode-power-kit managed:v2 -->"
OPK_PLUGIN_MARKER = "@opk-plugin opk-safety-guard"
KIT_DIR = Path(__file__).resolve().parent.parent


def log(message: str) -> None:
    print(f"[merge] {message}")


def strip_jsonc(text: str) -> str:
    output: list[str] = []
    index = 0
    in_block = in_line = in_string = False
    while index < len(text):
        char = text[index]
        following = text[index + 1] if index + 1 < len(text) else ""
        if in_string:
            output.append(char)
            if char == "\\" and following:
                output.append(following)
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
            continue
        if in_block:
            if char == "*" and following == "/":
                in_block = False
                index += 2
            else:
                index += 1
            continue
        if in_line:
            if char == "\n":
                in_line = False
                output.append(char)
            index += 1
            continue
        if char == '"':
            in_string = True
            output.append(char)
            index += 1
        elif char == "/" and following == "*":
            in_block = True
            index += 2
        elif char == "/" and following == "/":
            in_line = True
            index += 2
        else:
            output.append(char)
            index += 1
    if in_block or in_string:
        raise ValueError("unterminated JSONC comment or string")
    return "".join(output)


def parse_config(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
    except Exception as error:
        raise ValueError(f"cannot parse {path}: {error}") from error
    if not isinstance(data, dict):
        raise ValueError(f"config root must be an object: {path}")
    return data


def timestamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S") + f"-{time.time_ns() % 1_000_000_000:09d}-{os.getpid()}"


def backup_path(path: Path) -> Path:
    return path.with_name(f"{path.name}.opk-bak.{timestamp()}")


def reject_unsafe_path(project: Path, path: Path, *, allow_missing: bool = True) -> None:
    project_real = project.resolve(strict=True)
    if project.is_symlink() or not project_real.is_dir():
        raise ValueError(f"project directory is not a real directory: {project}")
    relative = path.relative_to(project)
    current = project
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError(f"refusing symlink path: {current}")
        if current.exists() and current != path and not current.is_dir():
            raise ValueError(f"parent path is not a directory: {current}")
    if path.exists() and not path.is_file():
        raise ValueError(f"config target is not a regular file: {path}")
    if not allow_missing and not path.exists():
        raise ValueError(f"required path does not exist: {path}")
    parent_real = path.parent.resolve(strict=path.parent.exists())
    if parent_real != project_real and project_real not in parent_real.parents:
        raise ValueError(f"path escapes project: {path}")


def backup(path: Path) -> Path:
    destination = backup_path(path)
    if destination.exists() or destination.is_symlink():
        raise ValueError(f"backup collision: {destination}")
    shutil.copy2(path, destination, follow_symlinks=False)
    return destination


def atomic_write(path: Path, data: dict[str, Any]) -> None:
    descriptor = -1
    temporary = ""
    try:
        descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.tmp.", dir=path.parent)
        os.fchmod(descriptor, 0o644)
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            descriptor = -1
            json.dump(data, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        temporary = ""
        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        if temporary:
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


def dedupe(values: Any) -> list[Any]:
    if not isinstance(values, list):
        return []
    result: list[Any] = []
    for value in values:
        if value not in result:
            result.append(value)
    return result


def union_values(primary: Any, secondary: Any) -> list[Any]:
    return dedupe([*dedupe(primary), *dedupe(secondary)])


def merge_missing(root: dict[str, Any], legacy: dict[str, Any]) -> dict[str, Any]:
    merged = dict(legacy)
    merged.update(root)
    merged["plugin"] = union_values(root.get("plugin"), legacy.get("plugin"))
    merged["instructions"] = union_values(root.get("instructions"), legacy.get("instructions"))
    if not merged["plugin"]:
        merged.pop("plugin", None)
    if not merged["instructions"]:
        merged.pop("instructions", None)
    return merged


def merge_watcher(config: dict[str, Any], profile: dict[str, Any]) -> None:
    wanted = profile.get("watcher", {}).get("ignore", [])
    current = config.get("watcher")
    if not isinstance(current, dict):
        current = {}
    current["ignore"] = union_values(current.get("ignore"), wanted)
    config["watcher"] = current


def merge_compaction(config: dict[str, Any], profile: dict[str, Any]) -> None:
    wanted = profile.get("compaction", {})
    current = config.get("compaction")
    if not isinstance(current, dict):
        current = {}
    current["auto"] = wanted.get("auto", True)
    current["prune"] = wanted.get("prune", True)
    if "reserved" not in current and "reserved" in wanted:
        current["reserved"] = wanted["reserved"]
    config["compaction"] = current


def apply_managed(config: dict[str, Any], template: dict[str, Any], mode: str | None) -> dict[str, Any]:
    result = dict(config)
    result.setdefault("$schema", "https://opencode.ai/config.json")
    if mode is None:
        result["plugin"] = union_values(result.get("plugin"), template.get("plugin"))
        if not result["plugin"]:
            result.pop("plugin", None)
        if "instructions" in result:
            result["instructions"] = dedupe(result["instructions"])
    if mode is not None or "permission" not in result:
        result["permission"] = template.get("permission", result.get("permission"))
    merge_compaction(result, template)
    merge_watcher(result, template)
    return result


def archive_legacy(project: Path, legacy: Path) -> Path:
    trash = project / ".opk-trash"
    if trash.is_symlink() or (trash.exists() and not trash.is_dir()):
        raise ValueError(f"refusing unsafe trash directory: {trash}")
    trash.mkdir(mode=0o700, exist_ok=True)
    archive = trash / f"legacy-config-{timestamp()}"
    archive.mkdir(mode=0o700)
    destination = archive / "opencode.json"
    os.replace(legacy, destination)
    return destination


def merge_project_config(project: Path, mode: str | None, dry_run: bool) -> bool:
    root = project / "opencode.json"
    legacy = project / ".opencode" / "opencode.json"
    reject_unsafe_path(project, root)
    reject_unsafe_path(project, legacy)

    try:
        root_data = parse_config(root) if root.exists() else {}
    except ValueError as error:
        if dry_run:
            raise
        recovery = backup(root)
        raise ValueError(f"{error}; unchanged original preserved, recovery backup: {recovery}") from error
    try:
        legacy_data = parse_config(legacy) if legacy.exists() else {}
    except ValueError as error:
        if dry_run:
            raise
        recovery = backup(legacy)
        raise ValueError(f"{error}; unchanged original preserved, recovery backup: {recovery}") from error
    current = merge_missing(root_data, legacy_data) if legacy.exists() else root_data
    template_name = f"opencode.{mode}.json" if mode else "opencode.json"
    template_path = KIT_DIR / "templates" / template_name
    template = parse_config(template_path)
    merged = apply_managed(current, template, mode)
    changed = merged != root_data or not root.exists()

    if dry_run:
        log(f"opencode.json: {'would update' if changed else 'unchanged'}")
        if legacy.exists():
            log("legacy .opencode/opencode.json: would archive after verification")
        return changed or legacy.exists()

    root_backup = backup(root) if root.exists() and (changed or legacy.exists()) else None
    legacy_backup = backup(legacy) if legacy.exists() else None
    if root_backup:
        log(f"opencode.json: backup -> {root_backup.name}")
    if legacy_backup:
        log(f"legacy config: backup -> {legacy_backup.name}")
    if changed:
        atomic_write(root, merged)
    if parse_config(root) != merged:
        raise RuntimeError("root config verification failed after atomic write")
    if legacy.exists():
        destination = archive_legacy(project, legacy)
        log(f"legacy config archived -> {destination.relative_to(project)}")
    log("opencode.json: merge complete; user model/provider/MCP/custom keys preserved")
    return changed or legacy.exists()


def merge_markdown(project: Path, filename: str, dry_run: bool) -> bool:
    template = KIT_DIR / "templates" / filename
    target = project / filename
    if not template.is_file():
        return False
    template_text = template.read_text(encoding="utf-8").strip()
    block = f"{MARKER_OPEN}\n{template_text}\n{MARKER_CLOSE}"
    existing = target.read_text(encoding="utf-8") if target.exists() else ""
    if MARKER_OPEN in existing and MARKER_CLOSE in existing:
        before = existing[: existing.index(MARKER_OPEN)]
        after = existing[existing.index(MARKER_CLOSE) + len(MARKER_CLOSE) :]
        updated = before + block + after
    elif not existing or existing.strip() == template_text:
        updated = block + "\n"
    else:
        updated = existing.rstrip() + f"\n\n{block}\n"
    if updated == existing:
        return False
    if not dry_run:
        if target.exists():
            backup(target)
        target.write_text(updated, encoding="utf-8")
    log(f"{filename}: {'would update' if dry_run else 'updated managed block'}")
    return True


def install_safety_plugin(project: Path, dry_run: bool) -> bool:
    template = KIT_DIR / "templates" / "plugins" / "opk-safety-guard.js"
    target = project / ".opencode" / "plugins" / "opk-safety-guard.js"
    if not template.is_file():
        return False
    reject_unsafe_path(project, target)
    if target.exists() and OPK_PLUGIN_MARKER not in target.read_text(encoding="utf-8"):
        log("safety plugin: custom file exists; preserving it")
        return False
    if dry_run:
        return True
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        backup(target)
    shutil.copy2(template, target)
    log("safety plugin: installed in .opencode/plugins/")
    return True


def project_from_argument(raw: str) -> Path:
    lexical = Path(raw).absolute()
    if lexical.is_symlink() or not lexical.is_dir():
        raise ValueError(f"invalid project directory: {lexical}")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical:
        raise ValueError(f"project path contains a symlink: {lexical}")
    return resolved


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-dir", default=os.getcwd())
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--mode", choices=("power", "safe"))
    parser.add_argument("--migrate-only", action="store_true")
    args = parser.parse_args()
    try:
        project = project_from_argument(args.project_dir)
        directory_fd = os.open(project, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(directory_fd, fcntl.LOCK_EX)
            merge_project_config(project, args.mode, args.dry_run)
            if not args.migrate_only and args.mode is None:
                merge_markdown(project, "AGENTS.md", args.dry_run)
                merge_markdown(project, "OPENCODE.md", args.dry_run)
                install_safety_plugin(project, args.dry_run)
        finally:
            os.close(directory_fd)
    except Exception as error:
        print(f"[merge] ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
