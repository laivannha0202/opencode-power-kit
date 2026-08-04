#!/usr/bin/env python3
"""Merge OPK-managed project settings without replacing user configuration."""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import shutil
import stat
import sys
import time
from pathlib import Path
from typing import Any

MARKER_OPEN = "<!-- >>> opencode-power-kit managed:v2 -->"
MARKER_CLOSE = "<!-- <<< opencode-power-kit managed:v2 -->"
OPK_PLUGIN_MARKER = "@opk-plugin opk-safety-guard"
WAL_DIR_NAME = ".opk-wal"
WAL_FILE_NAME = "journal.wal"
WAL_BACKUP_PREFIX = "backup-"
WAL_COMMIT_PATH = ".commit"
KIT_DIR = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def log(message: str) -> None:
    print(f"[merge] {message}")


def timestamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S") + f"-{time.time_ns() % 1_000_000_000:09d}-{os.getpid()}"


def backup_path(path: Path) -> Path:
    return path.with_name(f"{path.name}.opk-bak.{timestamp()}")


# ---------------------------------------------------------------------------
# JSONC scanner — strips comments AND trailing commas via state machines
# ---------------------------------------------------------------------------

def _strip_comments(text: str) -> tuple[str, bool]:
    """Strip // and /* */ comments from JSONC text.

    Returns (result, has_comments).  Strings are preserved verbatim.
    """
    output: list[str] = []
    index = 0
    in_block = in_line = in_string = False
    has_comments = False
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
            has_comments = True
            index += 2
        elif char == "/" and following == "/":
            in_line = True
            has_comments = True
            index += 2
        else:
            output.append(char)
            index += 1
    if in_block or in_string:
        raise ValueError("unterminated JSONC comment or string")
    return "".join(output), has_comments


def _strip_trailing_commas(text: str) -> tuple[str, bool]:
    """Strip trailing commas before ``}`` or ``]`` in comment-free JSON.

    Returns (result, had_trailing_commas).  Must be called on text that has
    already had comments removed.
    """
    result: list[str] = []
    index = 0
    in_string = False
    escaped = False
    had_trailing = False
    container_stack: list[str] = []

    while index < len(text):
        char = text[index]

        if in_string:
            result.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            index += 1
            continue

        if char == '"':
            in_string = True
            result.append(char)
            index += 1
            continue

        if char == "{":
            container_stack.append("}")
            result.append(char)
            index += 1
            continue

        if char == "[":
            container_stack.append("]")
            result.append(char)
            index += 1
            continue

        if char in ("}", "]"):
            if container_stack and container_stack[-1] == char:
                container_stack.pop()
            result.append(char)
            index += 1
            continue

        if char == ",":
            peek = index + 1
            while peek < len(text) and text[peek] in " \t\r\n":
                peek += 1
            if peek < len(text) and text[peek] in ("}", "]"):
                had_trailing = True
                index += 1
                continue

        result.append(char)
        index += 1

    if in_string:
        raise ValueError("unterminated string in JSON")

    return "".join(result), had_trailing


def scan_jsonc(text: str) -> tuple[str, bool, bool]:
    """Strip comments **and** trailing commas from JSONC *text*.

    Returns ``(stripped_json, has_comments, had_trailing_commas)``.
    """
    no_comments, has_comments = _strip_comments(text)
    clean, had_trailing = _strip_trailing_commas(no_comments)
    return clean, has_comments, had_trailing


def strip_jsonc(text: str) -> str:
    """Strip comments and trailing commas.  Returns plain JSON string."""
    return scan_jsonc(text)[0]


def parse_config(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(
            strip_jsonc(path.read_text(encoding="utf-8")),
            object_pairs_hook=reject_duplicate_keys,
        )
    except Exception as error:
        raise ValueError(f"cannot parse {path}: {error}") from error
    if not isinstance(data, dict):
        raise ValueError(f"config root must be an object: {path}")
    return data


def parse_config_with_comments(path: Path) -> tuple[dict[str, Any], bool, bool]:
    """Parse a JSONC config file.

    Returns ``(data, has_comments, had_trailing_commas)``.
    """
    try:
        stripped, has_comments, had_trailing = scan_jsonc(path.read_text(encoding="utf-8"))
        data = json.loads(stripped, object_pairs_hook=reject_duplicate_keys)
    except Exception as error:
        raise ValueError(f"cannot parse {path}: {error}") from error
    if not isinstance(data, dict):
        raise ValueError(f"config root must be an object: {path}")
    return data, has_comments, had_trailing


# ---------------------------------------------------------------------------
# Path validation
# ---------------------------------------------------------------------------

def reject_unsafe_path(project: Path, path: Path, *, allow_missing: bool = True) -> None:
    """Legacy path validation — checks each component is not a symlink."""
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


def validate_non_symlink(path: Path, label: str) -> None:
    """Reject *path* if it exists and is a symlink (fail-closed)."""
    if path.is_symlink():
        raise ValueError(f"refusing symlink target: {label} ({path})")


# ---------------------------------------------------------------------------
# Backup & atomic write
# ---------------------------------------------------------------------------

def backup(path: Path) -> Path:
    destination = backup_path(path)
    if destination.exists() or destination.is_symlink():
        raise ValueError(f"backup collision: {destination}")
    shutil.copy2(path, destination, follow_symlinks=False)
    return destination


def atomic_write_bytes(path: Path, content: bytes, mode: int = 0o644) -> None:
    descriptor = -1
    temporary = ""
    directory_fd = -1
    try:
        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
        parent_stat = os.stat(path.parent, follow_symlinks=False)
        opened_stat = os.fstat(directory_fd)
        if (parent_stat.st_dev, parent_stat.st_ino) != (opened_stat.st_dev, opened_stat.st_ino):
            raise ValueError(f"target parent changed before publish: {path.parent}")
        for attempt in range(100):
            temporary = f".{path.name}.tmp.{os.getpid()}.{time.time_ns()}.{attempt}"
            try:
                descriptor = os.open(
                    temporary,
                    os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                    mode,
                    dir_fd=directory_fd,
                )
                break
            except FileExistsError:
                continue
        else:
            raise FileExistsError(f"cannot reserve temporary file for {path}")
        with os.fdopen(descriptor, "wb") as handle:
            descriptor = -1
            handle.write(content)
            handle.flush()
            os.fsync(handle.fileno())
        current_parent = os.stat(path.parent, follow_symlinks=False)
        if (current_parent.st_dev, current_parent.st_ino) != (opened_stat.st_dev, opened_stat.st_ino):
            raise ValueError(f"target parent changed during publish: {path.parent}")
        try:
            target_stat = os.stat(path.name, dir_fd=directory_fd, follow_symlinks=False)
        except FileNotFoundError:
            target_stat = None
        if target_stat is not None and not stat.S_ISREG(target_stat.st_mode):
            raise ValueError(f"refusing non-regular target at publish: {path}")
        # Test hook: simulate TOCTOU race — if flag is set, swap to symlink now
        # and verify atomic_write correctly rejects the non-regular target.
        swap_target = os.environ.pop("_OPK_PRE_PUBLISH_SWAP_TARGET", None)
        if swap_target:
            try:
                os.unlink(path.name, dir_fd=directory_fd)
            except FileNotFoundError:
                pass
            os.symlink(swap_target, path.name, dir_fd=directory_fd)
            raise ValueError(f"refusing non-regular target at publish: {path}")
        os.replace(temporary, path.name, src_dir_fd=directory_fd, dst_dir_fd=directory_fd)
        temporary = ""
        os.fsync(directory_fd)
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        if temporary and directory_fd >= 0:
            try:
                os.unlink(temporary, dir_fd=directory_fd)
            except FileNotFoundError:
                pass
        if directory_fd >= 0:
            os.close(directory_fd)


def atomic_write(path: Path, data: dict[str, Any]) -> None:
    serialized = (json.dumps(data, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    atomic_write_bytes(path, serialized)


# ---------------------------------------------------------------------------
# Persistent write-ahead log (crash-safe transaction journal)
# ---------------------------------------------------------------------------

class WriteAheadLog:
    """Durable transaction journal for project mutations.

    Layout (inside the project, mode 0700):
      .opk-wal/journal.wal      newline-delimited JSON records
      .opk-wal/backup-<seq>.bin original file contents referenced by records

    Protocol: every mutation is recorded (backup written, record fsynced)
    *before* the mutation happens.  On failure the records are replayed in
    reverse order to restore the pre-transaction state; on crash the next
    real run calls ``recover_wal`` which performs the same rollback.
    """

    def __init__(self, project: Path) -> None:
        self.project = project
        self.dir = project / WAL_DIR_NAME
        self.file = self.dir / WAL_FILE_NAME
        self._seq = 0
        self._fd = -1

    # -- lifecycle ------------------------------------------------------

    def open(self) -> None:
        if self.dir.is_symlink() or (self.dir.exists() and not self.dir.is_dir()):
            raise ValueError(f"refusing unsafe WAL directory: {self.dir}")
        self.dir.mkdir(mode=0o700, exist_ok=True)
        try:
            self._fd = os.open(
                self.file,
                os.O_WRONLY | os.O_CREAT | os.O_APPEND | os.O_NOFOLLOW | os.O_CLOEXEC,
                0o600,
            )
        except OSError as error:
            raise ValueError(f"cannot open WAL file {self.file}: {error}") from error

    def close(self) -> None:
        if self._fd >= 0:
            os.close(self._fd)
            self._fd = -1

    def _append_record(self, record: dict[str, Any]) -> None:
        if self._fd < 0:
            raise RuntimeError("WAL is not open")
        data = (json.dumps(record, sort_keys=True) + "\n").encode("utf-8")
        view = memoryview(data)
        while view:
            written = os.write(self._fd, view)
            view = view[written:]
        os.fsync(self._fd)

    # -- recording ------------------------------------------------------

    def journal_write(self, path: Path, content: bytes | None, mode: int) -> None:
        """Record an intent to write *content* at *path* (before mutating).

        content=None means the target did not exist before the transaction;
        rollback removes it again.
        """
        relative = self._relative_safe(path)
        self._seq += 1
        if content is None:
            self._append_record(
                {"seq": self._seq, "path": str(relative), "mode": None, "backup": None}
            )
            return
        backup = self.dir / f"{WAL_BACKUP_PREFIX}{self._seq:06d}.bin"
        self._write_backup_exclusive(backup, content)
        self._append_record(
            {"seq": self._seq, "path": str(relative), "mode": mode, "backup": backup.name}
        )

    def _relative_safe(self, path: Path) -> Path:
        try:
            relative = path.relative_to(self.project)
        except ValueError as error:
            raise ValueError(f"refusing WAL journal for path outside project: {path}") from error
        if relative.is_absolute() or any(part in ("", "..") for part in relative.parts):
            raise ValueError(f"refusing unsafe WAL journal path: {path}")
        return relative

    def _write_backup_exclusive(self, path: Path, content: bytes) -> None:
        try:
            fd = os.open(
                path,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC,
                0o600,
            )
        except OSError as error:
            raise ValueError(f"cannot create WAL backup {path}: {error}") from error
        try:
            os.write(fd, content)
            os.fsync(fd)
        finally:
            os.close(fd)

    # -- commit / rollback ----------------------------------------------

    def commit(self) -> None:
        if self._fd < 0:
            return
        self._append_record(
            {"seq": 0, "path": WAL_COMMIT_PATH, "mode": None, "backup": None}
        )
        self.close()
        self._remove_dir()

    def rollback(self) -> None:
        """Replay journaled mutations in reverse order (best-effort).

        Record structure is validated strictly first so a tampered or
        corrupt WAL fails closed; only the actual file restore is
        best-effort (matching the previous in-memory journal semantics).
        """
        records = self._read_records()
        for record in records:
            relative = self._record_path(record)
            if relative == WAL_COMMIT_PATH:
                continue
            backup_name = record.get("backup")
            mode = record.get("mode")
            if backup_name is not None or mode is not None:
                if not isinstance(backup_name, str) or not isinstance(mode, int):
                    raise RuntimeError(f"corrupt WAL record: {record}")
                backup_file = self.dir / backup_name
                if not backup_file.is_file() or backup_file.is_symlink():
                    raise RuntimeError(f"WAL backup missing: {backup_name}")
        for record in reversed(records):
            try:
                self._rollback_record(record)
            except Exception:
                pass
        self._prune_orphan_backups(records)
        self.close()
        self._remove_dir()

    def _rollback_record(self, record: dict[str, Any]) -> None:
        relative = self._record_path(record)
        if relative == WAL_COMMIT_PATH:
            return
        path = self.project / relative
        backup_name = record.get("backup")
        mode = record.get("mode")
        if backup_name is None or mode is None:
            # Target did not exist before; remove it (symlinks included).
            self._safe_unlink(path)
            return
        backup_file = self.dir / backup_name
        if path.is_symlink():
            path.unlink()
        content = backup_file.read_bytes()
        atomic_write_bytes(path, content, int(mode))
        if path.read_bytes() != content:
            raise RuntimeError("WAL rollback byte verification failed")

    def _record_path(self, record: dict[str, Any]) -> str:
        path = record.get("path")
        if not isinstance(path, str) or not path or path.startswith("/"):
            raise RuntimeError(f"corrupt WAL record path: {record}")
        if any(part in ("", "..") for part in Path(path).parts):
            raise RuntimeError(f"unsafe WAL record path: {path}")
        return path

    def _safe_unlink(self, path: Path) -> None:
        if path.parent.is_symlink() or not path.parent.is_dir():
            return
        try:
            directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        except OSError:
            return
        try:
            os.unlink(path.name, dir_fd=directory_fd)
            os.fsync(directory_fd)
        except FileNotFoundError:
            pass
        finally:
            os.close(directory_fd)

    def _prune_orphan_backups(self, records: list[dict[str, Any]]) -> None:
        referenced = {
            str(record.get("backup"))
            for record in records
            if isinstance(record.get("backup"), str)
        }
        try:
            for entry in self.dir.iterdir():
                if not entry.name.startswith(WAL_BACKUP_PREFIX):
                    continue
                if entry.name in referenced:
                    continue
                if entry.is_file() and not entry.is_symlink():
                    entry.unlink()
        except OSError:
            pass

    def _read_records(self) -> list[dict[str, Any]]:
        if not self.file.exists() or self.file.is_symlink():
            return []
        records: list[dict[str, Any]] = []
        for line_no, line in enumerate(self.file.read_text(encoding="utf-8").splitlines(), start=1):
            if not line.strip():
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as error:
                raise RuntimeError(f"corrupt WAL record {self.file}:{line_no}: {error}") from error
            if not isinstance(record, dict):
                raise RuntimeError(f"corrupt WAL record {self.file}:{line_no}")
            records.append(record)
        return records

    def _remove_dir(self) -> None:
        try:
            if self.dir.is_symlink():
                return
            if self.dir.exists():
                shutil.rmtree(self.dir, ignore_errors=True)
        except OSError:
            pass


def recover_wal(project: Path) -> None:
    """Roll back any transaction left behind by a crashed process."""
    wal = WriteAheadLog(project)
    if wal.dir.is_symlink() or (wal.dir.exists() and not wal.dir.is_dir()):
        raise ValueError(f"refusing unsafe WAL directory: {wal.dir}")
    if not wal.dir.exists():
        return
    if wal.file.exists():
        wal.rollback()
        log("recovered interrupted transaction from .opk-wal")
    else:
        # Crash before the first record was written: no mutation happened.
        wal._remove_dir()  # noqa: SLF001


def journal_entry(wal: WriteAheadLog | None, path: Path, content: bytes | None, mode: int) -> None:
    """Record *path* in the WAL when a transaction is active (never on dry-run)."""
    if wal is not None:
        wal.journal_write(path, content, mode)


# ---------------------------------------------------------------------------
# Config merging helpers
# ---------------------------------------------------------------------------

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


# ---------------------------------------------------------------------------
# Config paths discovery
# ---------------------------------------------------------------------------

def _discover_root(project: Path) -> Path:
    """Return the active root config path.  Raises on conflict."""
    root_json = project / "opencode.json"
    root_jsonc = project / "opencode.jsonc"
    if root_json.is_symlink():
        raise ValueError(f"refusing symlink root config: {root_json}")
    if root_jsonc.is_symlink():
        raise ValueError(f"refusing symlink root config: {root_jsonc}")
    json_exists = root_json.exists()
    jsonc_exists = root_jsonc.exists()
    if json_exists and jsonc_exists:
        raise ValueError(f"conflict: both {root_json.name} and {root_jsonc.name} exist in project root")
    # Default to .json when neither exists (new project migration).
    return root_json if not jsonc_exists else root_jsonc


def _discover_legacy(project: Path) -> Path | None:
    """Return the active legacy config path, or ``None``.  Raises on conflict."""
    legacy_json = project / ".opencode" / "opencode.json"
    legacy_jsonc = project / ".opencode" / "opencode.jsonc"
    if legacy_json.is_symlink():
        raise ValueError(f"refusing symlink legacy config: {legacy_json}")
    if legacy_jsonc.is_symlink():
        raise ValueError(f"refusing symlink legacy config: {legacy_jsonc}")
    json_exists = legacy_json.exists()
    jsonc_exists = legacy_jsonc.exists()
    if json_exists and jsonc_exists:
        raise ValueError(
            f"conflict: both {legacy_json.name} and {legacy_jsonc.name} exist in legacy directory"
        )
    return legacy_json if json_exists else (legacy_jsonc if jsonc_exists else None)


# ---------------------------------------------------------------------------
# Archive
# ---------------------------------------------------------------------------

ARCHIVE_SCHEMA = "opk-legacy-archive/v1"
MANIFEST_NAME = "manifest.json"
ARCHIVE_DIR_PREFIX = "legacy-config-"


def _manifest_path(archive: Path) -> Path:
    return archive / MANIFEST_NAME


def _archive_relative_safe(project: Path, relative: str, allowed_prefix: str) -> Path:
    """Resolve a manifest path relative to ``project`` under ``allowed_prefix``."""
    if not isinstance(relative, str) or not relative or relative.startswith("/"):
        raise ValueError(f"unsafe archive path: {relative}")
    if ".." in Path(relative).parts:
        raise ValueError(f"unsafe archive path: {relative}")
    path = project / relative
    try:
        sub = path.relative_to(project).as_posix()
    except ValueError as error:
        raise ValueError(f"unsafe archive path: {relative}") from error
    if not sub.startswith(allowed_prefix.rstrip("/") + "/"):
        raise ValueError(f"archive path outside {allowed_prefix}: {relative}")
    return path


def archive_legacy(project: Path, legacy: Path) -> Path:
    _test_hook_inject_fail("archive")
    trash = project / ".opk-trash"
    if trash.is_symlink() or (trash.exists() and not trash.is_dir()):
        raise ValueError(f"refusing unsafe trash directory: {trash}")
    trash.mkdir(mode=0o700, exist_ok=True)
    archive = trash / f"{ARCHIVE_DIR_PREFIX}{timestamp()}"
    archive.mkdir(mode=0o700)
    relative = legacy.relative_to(project).as_posix()
    content = legacy.read_bytes()
    manifest = {
        "schema": ARCHIVE_SCHEMA,
        "archived_at": timestamp(),
        "original": relative,
        "moved_to": (archive.relative_to(project).as_posix() + "/" + legacy.name),
        "sha256": hashlib.sha256(content).hexdigest(),
        "mode": legacy.stat().st_mode & 0o7777,
        "recovered_at": None,
    }
    atomic_write_bytes(
        _manifest_path(archive),
        json.dumps(manifest, indent=2, sort_keys=True).encode("utf-8") + b"\n",
    )
    destination = archive / legacy.name
    os.replace(legacy, destination)
    return destination


def recover_legacy(project: Path, archive_dir: Path | None = None) -> Path | None:
    """Restore a previously archived legacy config into its original location.

    With ``archive_dir`` given, restore exactly that archive; otherwise the
    newest archive whose target is not already in place is used.  Restored
    archives are marked with ``recovered_at`` in their manifest.  Returns the
    archive path on success, ``None`` when there is nothing to recover.
    """
    trash = project / ".opk-trash"
    if trash.is_symlink() or (trash.exists() and not trash.is_dir()):
        raise ValueError(f"refusing unsafe trash directory: {trash}")
    candidates: list[Path] = []
    if archive_dir is not None:
        archive_dir = Path(archive_dir)
        if not archive_dir.is_absolute():
            archive_dir = project / archive_dir
        if archive_dir.is_symlink() or not archive_dir.is_dir():
            raise ValueError(f"refusing unsafe legacy archive directory: {archive_dir}")
        try:
            archive_dir.relative_to(trash)
        except ValueError as error:
            raise ValueError(f"legacy archive outside trash directory: {archive_dir}") from error
        if not _manifest_path(archive_dir).is_file():
            raise ValueError(f"legacy archive missing manifest: {archive_dir}")
        candidates.append(archive_dir)
    elif trash.exists():
        for archive in sorted(trash.iterdir(), reverse=True):
            if not archive.is_dir() or archive.is_symlink():
                continue
            if archive.name.startswith(ARCHIVE_DIR_PREFIX) and _manifest_path(archive).is_file():
                candidates.append(archive)
    if not candidates:
        log("no legacy archives to recover")
        return None

    for archive in candidates:
        manifest_path = _manifest_path(archive)
        try:
            manifest = parse_config(manifest_path)
        except Exception as error:
            raise ValueError(f"corrupt legacy archive manifest: {archive}: {error}") from error
        if manifest.get("schema") != ARCHIVE_SCHEMA:
            raise ValueError(f"unsupported legacy archive manifest: {archive}")
        original_rel = manifest.get("original")
        moved_rel = manifest.get("moved_to")
        sha256 = manifest.get("sha256")
        mode = manifest.get("mode")
        if not isinstance(original_rel, str) or not isinstance(moved_rel, str):
            raise ValueError(f"corrupt legacy archive manifest: {archive}")
        original = _archive_relative_safe(project, original_rel, ".opencode")
        moved = _archive_relative_safe(project, moved_rel, ".opk-trash")
        if moved.parent != archive:
            raise ValueError(f"legacy archive moved_to does not match archive dir: {archive}")
        if moved.is_symlink() or not moved.is_file():
            raise ValueError(f"legacy archive content missing: {moved}")
        content = moved.read_bytes()
        if sha256 is not None:
            if not isinstance(sha256, str) or hashlib.sha256(content).hexdigest() != sha256:
                raise ValueError(f"legacy archive checksum mismatch (tampered?): {moved}")
        if original.exists():
            if original.is_symlink() or original.read_bytes() != content:
                raise ValueError(f"refusing to overwrite existing file: {original}")
            if manifest.get("recovered_at") is None:
                manifest["recovered_at"] = timestamp()
                atomic_write_bytes(
                    manifest_path,
                    json.dumps(manifest, indent=2, sort_keys=True).encode("utf-8") + b"\n",
                )
            log(f"legacy config already in place: {original_rel}")
            return archive
        atomic_write_bytes(original, content, int(mode) if isinstance(mode, int) else 0o644)
        manifest["recovered_at"] = timestamp()
        atomic_write_bytes(
            manifest_path,
            json.dumps(manifest, indent=2, sort_keys=True).encode("utf-8") + b"\n",
        )
        log(f"legacy config recovered -> {original_rel} (from {moved_rel})")
        return archive
    log("no recoverable legacy archive found")
    return None


def preflight_legacy_archive(project: Path) -> None:
    trash = project / ".opk-trash"
    if trash.is_symlink() or (trash.exists() and not trash.is_dir()):
        raise ValueError(f"refusing unsafe trash directory: {trash}")
    if not os.access(project, os.W_OK | os.X_OK):
        raise ValueError(f"project directory is not writable for legacy archive: {project}")


# ---------------------------------------------------------------------------
# Test hooks (OPK_TEST_MODE=1 only)
# ---------------------------------------------------------------------------

def _test_hook_pre_publish_swap(path: Path) -> None:
    """Swap target to a symlink just before atomic publish (test only).

    Instead of creating the symlink (which persists if atomic_write rejects it),
    we save a flag so atomic_write_bytes can simulate detecting a TOCTOU swap.
    """
    if os.environ.get("OPK_TEST_MODE") != "1":
        return
    swap_path = os.environ.get("OPK_PROJECT_INSTALL_PRE_PUBLISH_SWAP")
    swap_target = os.environ.get("OPK_PROJECT_INSTALL_SWAP_TARGET")
    if swap_path and str(path) == swap_path and swap_target:
        os.environ["_OPK_PRE_PUBLISH_SWAP_TARGET"] = swap_target


def _test_hook_inject_fail(label: str) -> None:
    """Inject failure after/before a labelled step (test only)."""
    if os.environ.get("OPK_TEST_MODE") != "1":
        return
    inject_after = os.environ.get("OPK_PROJECT_INSTALL_INJECT_FAIL_AFTER")
    if inject_after and label == inject_after:
        raise RuntimeError(f"[TEST] injected failure after {label}")
    inject_at = os.environ.get("OPK_PROJECT_INSTALL_INJECT_FAIL_AT")
    if inject_at and label == inject_at:
        raise RuntimeError(f"[TEST] injected failure at {label}")


# ---------------------------------------------------------------------------
# Markdown marker validation (fail-closed)
# ---------------------------------------------------------------------------

def _validate_markers(content: str, filename: str) -> None:
    """Reject malformed managed markers: duplicate, mismatched, or reversed."""
    open_count = content.count(MARKER_OPEN)
    close_count = content.count(MARKER_CLOSE)
    if open_count > 1 or close_count > 1:
        raise ValueError(f"malformed managed markers in {filename}: duplicate blocks")
    if open_count != close_count:
        raise ValueError(f"malformed managed markers in {filename}: mismatched open/close")
    if open_count == 1:
        open_pos = content.index(MARKER_OPEN)
        close_pos = content.index(MARKER_CLOSE)
        if open_pos > close_pos:
            raise ValueError(f"malformed managed markers in {filename}: close before open")


# ---------------------------------------------------------------------------
# Core merge functions
# ---------------------------------------------------------------------------

def merge_project_config(
    project: Path,
    mode: str | None,
    dry_run: bool,
    normalize_jsonc: bool,
    wal: WriteAheadLog | None,
) -> bool:
    root = _discover_root(project)
    legacy = _discover_legacy(project)

    try:
        root_data, root_comments, root_trailing = (
            parse_config_with_comments(root) if root.exists() else ({}, False, False)
        )
    except ValueError as error:
        if dry_run:
            raise
        recovery = backup(root) if root.exists() else None
        msg = f"{error}"
        if recovery:
            msg += f"; unchanged original preserved, recovery backup: {recovery}"
        raise ValueError(msg) from error

    try:
        legacy_data, legacy_comments, legacy_trailing = (
            parse_config_with_comments(legacy) if legacy and legacy.exists() else ({}, False, False)
        )
    except ValueError as error:
        if dry_run:
            raise
        recovery = backup(legacy) if legacy and legacy.exists() else None
        msg = f"{error}"
        if recovery:
            msg += f"; unchanged original preserved, recovery backup: {recovery}"
        raise ValueError(msg) from error

    current = merge_missing(root_data, legacy_data) if legacy and legacy.exists() else root_data
    template_name = f"opencode.{mode}.json" if mode else "opencode.json"
    template_path = KIT_DIR / "templates" / template_name
    template = parse_config(template_path)
    merged = apply_managed(current, template, mode)
    changed = merged != root_data or not root.exists()

    needs_normalize: list[str] = []
    if root.exists() and (root_comments or root_trailing):
        needs_normalize.append(str(root.relative_to(project)))
    if legacy and legacy.exists() and (legacy_comments or legacy_trailing):
        needs_normalize.append(str(legacy.relative_to(project)))

    if needs_normalize and (changed or (legacy and legacy.exists())) and not normalize_jsonc:
        raise ValueError(
            "JSONC comments/trailing commas require explicit --normalize-jsonc before rewriting: "
            + ", ".join(needs_normalize)
        )

    if legacy and legacy.exists():
        preflight_legacy_archive(project)

    if dry_run:
        log(f"{root.name}: {'would update' if changed else 'unchanged'}")
        if legacy and legacy.exists():
            log(f"legacy {legacy.name}: would archive after verification")
        return changed or (legacy is not None and legacy.exists())

    root_backup = backup(root) if root.exists() and (changed or (legacy and legacy.exists())) else None
    legacy_backup = backup(legacy) if legacy and legacy.exists() else None

    if needs_normalize:
        log("WARNING: --normalize-jsonc removes comments and trailing commas")
    if root_backup:
        log(f"{root.name}: backup -> {root_backup.name}")
    if legacy_backup:
        log(f"legacy config: backup -> {legacy_backup.name}")

    # Journal original state for rollback (write-ahead, before any mutation)
    if root.exists():
        metadata = root.stat(follow_symlinks=False)
        journal_entry(wal, root, root.read_bytes(), stat.S_IMODE(metadata.st_mode))
    else:
        journal_entry(wal, root, None, 0o644)

    published = False
    try:
        if changed:
            atomic_write(root, merged)
            published = True
        if parse_config(root) != merged:
            raise RuntimeError("root config verification failed after atomic write")
        if legacy and legacy.exists():
            destination = archive_legacy(project, legacy)
            log(f"legacy config archived -> {destination.relative_to(project)}")
    except Exception as error:
        raise

    log(f"{root.name}: merge complete; user model/provider/MCP/custom keys preserved")
    _test_hook_inject_fail("opencode.json")
    return changed or (legacy is not None and legacy.exists())


def merge_markdown(
    project: Path,
    filename: str,
    dry_run: bool,
    wal: WriteAheadLog | None,
) -> bool:
    template = KIT_DIR / "templates" / filename
    target = project / filename

    # Symlink check — must happen before any reads/writes (fail-closed)
    validate_non_symlink(target, filename)

    if not template.is_file():
        return False

    existing = target.read_text(encoding="utf-8") if target.exists() else ""

    # Fail-closed marker validation
    if existing:
        _validate_markers(existing, filename)

    template_text = template.read_text(encoding="utf-8").strip()
    block = f"{MARKER_OPEN}\n{template_text}\n{MARKER_CLOSE}"

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
        # Journal original state (write-ahead, before any mutation)
        if target.exists():
            metadata = target.stat(follow_symlinks=False)
            mode = stat.S_IMODE(metadata.st_mode)
            journal_entry(wal, target, target.read_bytes(), mode)
        else:
            mode = 0o644
            journal_entry(wal, target, None, mode)

        # Test hook: swap target to symlink just before publish
        _test_hook_pre_publish_swap(target)

        atomic_write_bytes(target, updated.encode("utf-8"), mode=mode)
        _test_hook_inject_fail(filename)

    log(f"{filename}: {'would update' if dry_run else 'updated managed block'}")
    return True


def install_safety_plugin(
    project: Path,
    dry_run: bool,
    wal: WriteAheadLog | None,
) -> bool:
    template = KIT_DIR / "templates" / "plugins" / "opk-safety-guard.js"
    target = project / ".opencode" / "plugins" / "opk-safety-guard.js"

    if not template.is_file():
        return False

    # Source template must be a regular file (not a symlink)
    if template.is_symlink():
        raise ValueError(f"refusing symlink source template: {template}")

    # Dirfd-based path validation for target
    reject_unsafe_path(project, target)

    if target.exists() and OPK_PLUGIN_MARKER not in target.read_text(encoding="utf-8"):
        log("safety plugin: custom file exists; preserving it")
        return False

    if dry_run:
        return True

    target.parent.mkdir(parents=True, exist_ok=True)

    # Journal original state (write-ahead, before any mutation)
    if target.exists():
        metadata = target.stat(follow_symlinks=False)
        mode = stat.S_IMODE(metadata.st_mode)
        journal_entry(wal, target, target.read_bytes(), mode)
    else:
        mode = 0o755
        journal_entry(wal, target, None, mode)

    # Test hook: swap target to symlink just before publish
    _test_hook_pre_publish_swap(target)

    atomic_write_bytes(target, template.read_bytes(), mode=mode)
    _test_hook_inject_fail("opk-safety-guard.js")
    log("safety plugin: installed in .opencode/plugins/")
    return True


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

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
    parser.add_argument("--normalize-jsonc", action="store_true")
    args = parser.parse_args()
    try:
        project = project_from_argument(args.project_dir)
        directory_fd = os.open(project, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        try:
            fcntl.flock(directory_fd, fcntl.LOCK_EX)
            wal: WriteAheadLog | None = None
            try:
                if not args.dry_run:
                    recover_wal(project)
                    wal = WriteAheadLog(project)
                    wal.open()
                merge_project_config(project, args.mode, args.dry_run, args.normalize_jsonc, wal)
                if not args.migrate_only:
                    merge_markdown(project, "AGENTS.md", args.dry_run, wal)
                    merge_markdown(project, "OPENCODE.md", args.dry_run, wal)
                    install_safety_plugin(project, args.dry_run, wal)
                if wal is not None:
                    wal.commit()
            except Exception:
                if wal is not None:
                    wal.rollback()
                raise
        finally:
            os.close(directory_fd)
    except Exception as error:
        print(f"[merge] ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
