#!/usr/bin/env python3
"""Install-session lifecycle for OpenCode Power Kit project installs.

A completed install session ties together:
- the merger's committed WAL archive (pre-install originals),
- opk_tx transaction ids used by install.sh,
- the exact final state after the whole install completes.

Uninstall is fail-closed: every managed path must still match the recorded
final state before any restore begins. This prevents clobbering user edits made
after installation.
"""

from __future__ import annotations

import argparse
import fcntl
import hashlib
import json
import os
import re
import sys
import time
import uuid
from pathlib import Path
from typing import Any

import opk_safe_io as io
import opk_tx as tx

SCHEMA = "opk-install-session/v1"
INSTALLS_REL = ".opk-state/installs"
SESSION_RE = re.compile(r"^[0-9]{8}-[0-9]{6}-[a-f0-9]{12}$")


class SessionError(Exception):
    pass


def _canonical(root: str) -> str:
    return io.canonical_root(root)


def _safe_rel(value: str, *, allow_state: bool = False) -> str:
    if not isinstance(value, str) or not value:
        raise SessionError("empty session path")
    path = value.replace("\\", "/")
    if path.startswith("/"):
        raise SessionError("absolute session path refused: %s" % value)
    parts = path.split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise SessionError("unsafe session path refused: %s" % value)
    normalized = "/".join(parts)
    if not allow_state and (
        normalized == ".opk-state"
        or normalized.startswith(".opk-state/")
    ):
        raise SessionError(
            "managed install target may not be under .opk-state: %s"
            % value
        )
    return normalized


def _session_rel(session_id: str) -> str:
    if not SESSION_RE.fullmatch(session_id):
        raise SessionError("invalid session id: %s" % session_id)
    return "%s/%s/manifest.json" % (INSTALLS_REL, session_id)


def _json_read(root: str, rel: str) -> dict[str, Any]:
    try:
        raw = io.safe_read(root, rel)
        data = json.loads(raw.decode("utf-8"))
    except (io.OpkSafeIOError, UnicodeDecodeError, ValueError) as exc:
        raise SessionError("cannot read %s: %s" % (rel, exc)) from exc
    if not isinstance(data, dict):
        raise SessionError("JSON object required: %s" % rel)
    return data


def _json_write(root: str, rel: str, data: dict[str, Any]) -> None:
    raw = (
        json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2)
        + "\n"
    ).encode("utf-8")
    io.write(root, rel, raw, preserve_mode=True, create_parents=True)


def _load_session(root: str, session_id: str) -> dict[str, Any]:
    data = _json_read(root, _session_rel(session_id))
    if data.get("schema") != SCHEMA:
        raise SessionError("unsupported install session schema")
    if data.get("session_id") != session_id:
        raise SessionError("session id mismatch")
    if data.get("project_root") != root:
        raise SessionError("session project_root mismatch")
    return data


def _list_session_ids(root: str) -> list[str]:
    root_fd = state_fd = installs_fd = None
    try:
        try:
            root_fd, state_fd = tx._open_state_dir(root, create=False)
        except io.PathMissingError:
            return []
        installs_fd = tx._open_state_child_dir(
            state_fd, "installs", missing_ok=True
        )
        if installs_fd is None:
            return []
        names = os.listdir(installs_fd)
    finally:
        io.close_fd(installs_fd)
        io.close_fd(state_fd)
        io.close_fd(root_fd)

    return sorted(name for name in names if SESSION_RE.fullmatch(name))


def _latest_session(
    root: str,
    *,
    status: str | None = "installed",
) -> tuple[str, dict[str, Any]] | None:
    candidates: list[tuple[str, dict[str, Any]]] = []
    for session_id in _list_session_ids(root):
        try:
            manifest = _load_session(root, session_id)
        except SessionError:
            continue
        if status is not None and manifest.get("status") != status:
            continue
        candidates.append((session_id, manifest))
    return candidates[-1] if candidates else None


def _parse_merge_json(raw: str) -> tuple[list[dict[str, Any]], str | None]:
    if not raw.strip():
        return [], None
    try:
        data = json.loads(raw)
    except ValueError as exc:
        raise SessionError("invalid merger JSON: %s" % exc) from exc
    if not isinstance(data, dict):
        raise SessionError("merger JSON must be an object")
    if data.get("error"):
        raise SessionError("merger reported error: %s" % data["error"])
    files = data.get("files", [])
    if not isinstance(files, list) or any(
        not isinstance(item, dict) for item in files
    ):
        raise SessionError("merger files must be a list of objects")
    wal_archive = data.get("wal_archive")
    if wal_archive is not None:
        wal_archive = _safe_rel(str(wal_archive))
        if not wal_archive.startswith(".opk-wal/archive-"):
            raise SessionError(
                "unexpected merger WAL archive: %s" % wal_archive
            )
    return files, wal_archive


def _tx_manifest(root: str, tx_id: str) -> dict[str, Any]:
    if not isinstance(tx_id, str) or not tx_id:
        raise SessionError("empty transaction id")
    try:
        data = tx.status(root, tx_id)
    except Exception as exc:
        raise SessionError(
            "cannot read transaction %s: %s" % (tx_id, exc)
        ) from exc
    if not isinstance(data, dict) or data.get("tx_id") != tx_id:
        raise SessionError("invalid transaction manifest: %s" % tx_id)
    if data.get("project_root") != root:
        raise SessionError("transaction project_root mismatch: %s" % tx_id)
    return data


def _read_wal_records(
    root: str, wal_archive: str | None
) -> list[dict[str, Any]]:
    if wal_archive is None:
        return []
    wal_archive = _safe_rel(wal_archive)
    journal_rel = wal_archive + "/journal.wal"
    try:
        text = io.safe_read(root, journal_rel).decode("utf-8")
    except (io.OpkSafeIOError, UnicodeDecodeError) as exc:
        raise SessionError(
            "cannot read merger WAL journal: %s" % exc
        ) from exc

    records: list[dict[str, Any]] = []
    for line_no, line in enumerate(text.splitlines(), 1):
        if not line.strip():
            continue
        try:
            record = json.loads(line)
        except ValueError as exc:
            raise SessionError(
                "corrupt WAL record %s:%d" % (journal_rel, line_no)
            ) from exc
        if not isinstance(record, dict):
            raise SessionError(
                "corrupt WAL record %s:%d" % (journal_rel, line_no)
            )
        path = record.get("path")
        if not isinstance(path, str) or not path:
            raise SessionError("WAL record has invalid path")
        if path != ".commit":
            _safe_rel(path)
        records.append(record)

    if not any(record.get("path") == ".commit" for record in records):
        raise SessionError("merger WAL archive is not committed")
    return records


def _snapshot(root: str, rel: str) -> dict[str, Any]:
    rel = _safe_rel(rel)
    try:
        info = io.check(root, rel)
    except io.OpkSafeIOError as exc:
        raise SessionError(
            "cannot inspect managed path %s: %s" % (rel, exc)
        ) from exc

    if not info["exists"]:
        return {"type": "missing"}
    if info["is_symlink"]:
        raise SessionError("refusing symlinked managed path: %s" % rel)
    if info["is_reg"]:
        if info.get("nlink") and int(info["nlink"]) > 1:
            raise SessionError(
                "refusing hardlinked managed path: %s" % rel
            )
        data = io.safe_read(root, rel)
        return {
            "type": "file",
            "sha256": hashlib.sha256(data).hexdigest(),
            "size": len(data),
        }
    if info["is_dir"]:
        return {"type": "dir"}
    raise SessionError("unsupported managed path type: %s" % rel)


def _derive_targets(
    root: str,
    session: dict[str, Any],
) -> list[str]:
    targets: set[str] = set()

    wal_archive = session.get("merge_wal_archive")
    records = _read_wal_records(root, wal_archive)
    for record in records:
        if record.get("post") or record.get("path") == ".commit":
            continue
        targets.add(_safe_rel(str(record["path"])))

    merge_files = session.get("merge_files", [])
    if not isinstance(merge_files, list):
        raise SessionError("merge_files is corrupt")
    for item in merge_files:
        if not isinstance(item, dict):
            raise SessionError("merge_files entry is corrupt")
        backup = item.get("backup")
        if backup:
            targets.add(_safe_rel(str(backup)))
        if item.get("status") == "archived":
            original = item.get("file")
            moved = item.get("archive")
            if original:
                targets.add(_safe_rel(str(original)))
            if moved:
                targets.add(_safe_rel(str(moved)))

    tx_ids = session.get("tx_ids", [])
    if not isinstance(tx_ids, list):
        raise SessionError("tx_ids is corrupt")
    for tx_id in tx_ids:
        manifest = _tx_manifest(root, str(tx_id))
        ops = manifest.get("ops", [])
        if not isinstance(ops, list):
            raise SessionError("transaction ops are corrupt: %s" % tx_id)
        for op in ops:
            if not isinstance(op, dict):
                raise SessionError("transaction op is corrupt: %s" % tx_id)
            rel = op.get("rel")
            if rel:
                targets.add(_safe_rel(str(rel)))

    return sorted(targets)


def _preflight_restore_material(
    root: str,
    session: dict[str, Any],
) -> None:
    wal_archive = session.get("merge_wal_archive")
    for record in _read_wal_records(root, wal_archive):
        if record.get("post") or record.get("path") == ".commit":
            continue
        backup = record.get("backup")
        mode = record.get("mode")
        if backup is None and mode is None:
            continue
        if not isinstance(backup, str) or not isinstance(mode, int):
            raise SessionError("corrupt WAL restore record")
        backup_rel = _safe_rel(str(wal_archive) + "/" + backup)
        io.safe_read(root, backup_rel)

    for tx_id in session.get("tx_ids", []):
        manifest = _tx_manifest(root, str(tx_id))
        if manifest.get("status") != "committed":
            raise SessionError(
                "transaction %s is not committed (status=%s)"
                % (tx_id, manifest.get("status"))
            )
        for op in manifest.get("ops", []):
            backup_rel = op.get("backup_rel")
            if not backup_rel:
                continue
            data = io.safe_read(root, str(backup_rel))
            wanted = op.get("pre_hash")
            if wanted and hashlib.sha256(data).hexdigest() != wanted:
                raise SessionError(
                    "transaction backup checksum mismatch: %s"
                    % backup_rel
                )

    for item in session.get("merge_files", []):
        if item.get("status") != "archived":
            continue
        moved_rel = _safe_rel(str(item.get("archive", "")))
        archive_dir = str(Path(moved_rel).parent).replace("\\", "/")
        manifest_rel = _safe_rel(archive_dir + "/manifest.json")
        archive_manifest = _json_read(root, manifest_rel)
        original = _safe_rel(str(archive_manifest.get("original", "")))
        moved = _safe_rel(str(archive_manifest.get("moved_to", "")))
        if original != _safe_rel(str(item.get("file", ""))):
            raise SessionError("legacy archive original path mismatch")
        if moved != moved_rel:
            raise SessionError("legacy archive moved path mismatch")
        content = io.safe_read(root, moved_rel)
        wanted = archive_manifest.get("sha256")
        if (
            isinstance(wanted, str)
            and hashlib.sha256(content).hexdigest() != wanted
        ):
            raise SessionError("legacy archive checksum mismatch")


def _compare_final_state(root: str, session: dict[str, Any]) -> None:
    final_state = session.get("final_state")
    if not isinstance(final_state, dict) or not final_state:
        raise SessionError("install session has no finalized state")

    conflicts: list[str] = []
    for rel, wanted in sorted(final_state.items()):
        if not isinstance(wanted, dict):
            raise SessionError("corrupt final_state entry: %s" % rel)
        got = _snapshot(root, rel)
        if got != wanted:
            conflicts.append(
                "%s (installed=%s, current=%s)"
                % (
                    rel,
                    json.dumps(wanted, sort_keys=True),
                    json.dumps(got, sort_keys=True),
                )
            )
    if conflicts:
        raise SessionError(
            "refusing uninstall because managed files changed after install:\n  - "
            + "\n  - ".join(conflicts)
        )


def _restore_wal(root: str, session: dict[str, Any]) -> None:
    wal_archive = session.get("merge_wal_archive")
    if wal_archive is None:
        return
    records = _read_wal_records(root, str(wal_archive))

    for record in reversed(records):
        if record.get("post") or record.get("path") == ".commit":
            continue
        rel = _safe_rel(str(record["path"]))
        backup = record.get("backup")
        mode = record.get("mode")

        if backup is None and mode is None:
            info = io.check(root, rel)
            if not info["exists"]:
                continue
            if info["is_symlink"] or not info["is_reg"]:
                raise SessionError(
                    "refusing to remove unsafe WAL-created path: %s" % rel
                )
            io.remove(root, rel)
            continue

        if not isinstance(backup, str) or not isinstance(mode, int):
            raise SessionError("corrupt WAL restore record for %s" % rel)
        backup_rel = _safe_rel(str(wal_archive) + "/" + backup)
        content = io.safe_read(root, backup_rel)
        io.write(
            root,
            rel,
            content,
            mode=mode,
            preserve_mode=False,
            create_parents=True,
        )


def _restore_legacy_archives(
    root: str,
    session: dict[str, Any],
) -> list[str]:
    restored: list[str] = []
    for item in session.get("merge_files", []):
        if item.get("status") != "archived":
            continue

        moved_rel = _safe_rel(str(item.get("archive", "")))
        archive_dir = str(Path(moved_rel).parent).replace("\\", "/")
        manifest_rel = _safe_rel(archive_dir + "/manifest.json")
        archive_manifest = _json_read(root, manifest_rel)

        original_rel = _safe_rel(
            str(archive_manifest.get("original", ""))
        )
        expected_original = _safe_rel(str(item.get("file", "")))
        if original_rel != expected_original:
            raise SessionError("legacy archive original mismatch")

        moved_to = _safe_rel(str(archive_manifest.get("moved_to", "")))
        if moved_to != moved_rel:
            raise SessionError("legacy archive moved_to mismatch")

        content = io.safe_read(root, moved_rel)
        wanted = archive_manifest.get("sha256")
        if (
            isinstance(wanted, str)
            and hashlib.sha256(content).hexdigest() != wanted
        ):
            raise SessionError("legacy archive checksum mismatch")

        info = io.check(root, original_rel)
        if info["exists"]:
            raise SessionError(
                "legacy original unexpectedly exists during restore: %s"
                % original_rel
            )

        mode = archive_manifest.get("mode")
        io.write(
            root,
            original_rel,
            content,
            mode=int(mode) if isinstance(mode, int) else 0o644,
            create_parents=True,
        )
        restored.append(original_rel)

        io.remove(root, moved_rel)
        io.remove(root, manifest_rel)
        try:
            io.rmdir(root, archive_dir)
        except io.OpkSafeIOError:
            pass
    return restored


def _cleanup_merge_backups(
    root: str,
    session: dict[str, Any],
) -> list[str]:
    removed: list[str] = []
    for item in session.get("merge_files", []):
        backup = item.get("backup")
        if not backup:
            continue
        rel = _safe_rel(str(backup))
        info = io.check(root, rel)
        if not info["exists"]:
            continue
        if info["is_symlink"] or not info["is_reg"]:
            raise SessionError("unsafe recovery backup path: %s" % rel)
        io.remove(root, rel)
        removed.append(rel)
    return removed


def _cleanup_wal_archive(root: str, session: dict[str, Any]) -> None:
    wal_archive = session.get("merge_wal_archive")
    if wal_archive is None:
        return
    wal_archive = _safe_rel(str(wal_archive))
    records = _read_wal_records(root, wal_archive)

    names = {"journal.wal"}
    for record in records:
        backup = record.get("backup")
        if isinstance(backup, str):
            names.add(backup)

    for name in sorted(names):
        rel = _safe_rel(wal_archive + "/" + name)
        info = io.check(root, rel)
        if not info["exists"]:
            continue
        if info["is_symlink"] or not info["is_reg"]:
            raise SessionError("unsafe WAL archive entry: %s" % rel)
        io.remove(root, rel)

    try:
        io.rmdir(root, wal_archive)
    except io.OpkSafeIOError:
        pass


def create_session(
    root: str,
    merge_json: str,
    tx_ids: list[str],
    lease: str | None,
) -> dict[str, Any]:
    root = _canonical(root)
    merge_files, wal_archive = _parse_merge_json(merge_json)

    if wal_archive is not None:
        _read_wal_records(root, wal_archive)

    for tx_id in tx_ids:
        manifest = _tx_manifest(root, tx_id)
        if manifest.get("status") not in (
            "prepared",
            "applying",
            "committed",
        ):
            raise SessionError(
                "transaction %s has invalid create-time status %s"
                % (tx_id, manifest.get("status"))
            )

    session_id = (
        time.strftime("%Y%m%d-%H%M%S")
        + "-"
        + uuid.uuid4().hex[:12]
    )
    session_dir = "%s/%s" % (INSTALLS_REL, session_id)
    io.mkdir(root, session_dir, create_parents=True)

    manifest: dict[str, Any] = {
        "schema": SCHEMA,
        "session_id": session_id,
        "created_at": time.strftime(
            "%Y-%m-%dT%H:%M:%SZ", time.gmtime()
        ),
        "project_root": root,
        "status": "installing",
        "lease": lease,
        "merge_wal_archive": wal_archive,
        "merge_files": merge_files,
        "tx_ids": list(tx_ids),
        "final_state": {},
    }
    _json_write(root, _session_rel(session_id), manifest)
    return {
        "session_id": session_id,
        "manifest": _session_rel(session_id),
        "status": "installing",
        "merge_wal_archive": wal_archive,
    }


def finalize_session(root: str, session_id: str) -> dict[str, Any]:
    root = _canonical(root)
    manifest = _load_session(root, session_id)
    if manifest.get("status") == "installed":
        return {
            "session_id": session_id,
            "manifest": _session_rel(session_id),
            "status": "installed",
        }
    if manifest.get("status") != "installing":
        raise SessionError(
            "cannot finalize session in status %s"
            % manifest.get("status")
        )

    for tx_id in manifest.get("tx_ids", []):
        tx_manifest = _tx_manifest(root, str(tx_id))
        if tx_manifest.get("status") != "committed":
            raise SessionError(
                "cannot finalize: transaction %s status=%s"
                % (tx_id, tx_manifest.get("status"))
            )

    _preflight_restore_material(root, manifest)
    targets = _derive_targets(root, manifest)
    manifest["final_state"] = {
        rel: _snapshot(root, rel) for rel in targets
    }
    manifest["status"] = "installed"
    manifest["finalized_at"] = time.strftime(
        "%Y-%m-%dT%H:%M:%SZ", time.gmtime()
    )
    _json_write(root, _session_rel(session_id), manifest)
    return {
        "session_id": session_id,
        "manifest": _session_rel(session_id),
        "status": "installed",
        "managed_paths": len(targets),
    }


def acquire_install_lock(root: str) -> int:
    """Acquire the project-wide OPK install/uninstall lock."""
    root = _canonical(root)
    lock_fd = tx._open_state_lock(root, ".install.lock")
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError as exc:
        io.close_fd(lock_fd)
        raise SessionError(
            "another installer/uninstaller is holding the install lock"
        ) from exc
    return lock_fd


def release_install_lock(lock_fd: int | None) -> None:
    if lock_fd is None:
        return
    try:
        fcntl.flock(lock_fd, fcntl.LOCK_UN)
    except OSError:
        pass
    io.close_fd(lock_fd)


def prepare_extension(root: str) -> str | None:
    """Return the latest installed session after proving it is still clean.

    A standalone full-stack install is allowed when no OPK install session
    exists.  When a session does exist, callers must extend that same session
    so one uninstall can reverse the complete OPK lifecycle.
    """
    root = _canonical(root)
    latest = _latest_session(root, status="installed")
    if latest is None:
        return None
    session_id, manifest = latest
    _compare_final_state(root, manifest)
    _preflight_restore_material(root, manifest)
    return session_id


def _extension_pre_snapshot(
    root: str,
    tx_id: str,
    op: dict[str, Any],
) -> dict[str, Any]:
    pre_exists = op.get("pre_exists")
    if pre_exists is False:
        return {"type": "missing"}
    if pre_exists is not True:
        raise SessionError(
            "extension transaction op has invalid pre_exists: %s"
            % op.get("rel")
        )

    if op.get("op") == "MKDIR":
        return {"type": "dir"}

    backup_raw = op.get("backup_rel")
    pre_hash = op.get("pre_hash")
    if not isinstance(backup_raw, str) or not isinstance(pre_hash, str):
        raise SessionError(
            "extension transaction missing file pre-state: %s"
            % op.get("rel")
        )
    backup_rel = _safe_rel(backup_raw, allow_state=True)
    prefix = ".opk-state/transactions/%s/backups/" % tx_id
    if not backup_rel.startswith(prefix):
        raise SessionError(
            "extension transaction backup path is outside its tx: %s"
            % backup_rel
        )
    data = io.safe_read(root, backup_rel)
    digest = hashlib.sha256(data).hexdigest()
    if digest != pre_hash:
        raise SessionError(
            "extension transaction pre-state checksum mismatch: %s"
            % op.get("rel")
        )
    return {
        "type": "file",
        "sha256": digest,
        "size": len(data),
    }


def _verify_transaction_post_state(
    root: str,
    tx_manifest: dict[str, Any],
) -> None:
    ops = tx_manifest.get("ops", [])
    if not isinstance(ops, list):
        raise SessionError("extension transaction ops are corrupt")

    last_by_rel: dict[str, dict[str, Any]] = {}
    for op in ops:
        if not isinstance(op, dict):
            raise SessionError("extension transaction op is corrupt")
        rel_raw = op.get("rel")
        if rel_raw:
            rel = _safe_rel(str(rel_raw))
            last_by_rel[rel] = op

    conflicts: list[str] = []
    for rel, op in sorted(last_by_rel.items()):
        got = _snapshot(root, rel)
        post_hash = op.get("post_hash")
        kind = op.get("op")

        if isinstance(post_hash, str):
            good = (
                got.get("type") == "file"
                and got.get("sha256") == post_hash
            )
        elif kind == "MKDIR":
            good = got.get("type") == "dir"
        elif kind in ("REMOVE_MANAGED", "ARCHIVE"):
            good = got.get("type") == "missing"
        else:
            raise SessionError(
                "extension transaction has unverifiable post-state: %s"
                % rel
            )

        if not good:
            conflicts.append(
                "%s (tx-post=%s, current=%s)"
                % (
                    rel,
                    json.dumps(
                        {
                            "op": kind,
                            "post_hash": post_hash,
                        },
                        sort_keys=True,
                    ),
                    json.dumps(got, sort_keys=True),
                )
            )

    if conflicts:
        raise SessionError(
            "transaction outputs changed after staging:\n  - "
            + "\n  - ".join(conflicts)
        )


def verify_transaction_post_state(root: str, tx_id: str) -> None:
    root = _canonical(root)
    manifest = _tx_manifest(root, tx_id)
    if manifest.get("status") != "committed":
        raise SessionError(
            "transaction %s is not committed (status=%s)"
            % (tx_id, manifest.get("status"))
        )
    _verify_transaction_post_state(root, manifest)


def extend_session(
    root: str,
    session_id: str,
    tx_id: str,
) -> dict[str, Any]:
    """Attach one committed OPK transaction to an installed session.

    The transaction's recorded pre-state must equal the session's previous
    finalized state for every overlapping path.  Untouched session paths must
    still be byte-identical.  The transaction's current outputs must also
    match its recorded post-state before the session manifest is updated.
    """
    root = _canonical(root)
    manifest = _load_session(root, session_id)
    if manifest.get("status") != "installed":
        raise SessionError(
            "cannot extend session %s in status %s"
            % (session_id, manifest.get("status"))
        )

    tx_ids = manifest.get("tx_ids", [])
    if not isinstance(tx_ids, list):
        raise SessionError("session tx_ids is corrupt")
    tx_ids = [str(value) for value in tx_ids]

    if tx_id in tx_ids:
        _compare_final_state(root, manifest)
        return {
            "session_id": session_id,
            "status": "installed",
            "extended": False,
            "tx_id": tx_id,
        }

    tx_manifest = _tx_manifest(root, tx_id)
    if tx_manifest.get("status") != "committed":
        raise SessionError(
            "cannot extend with transaction %s status=%s"
            % (tx_id, tx_manifest.get("status"))
        )

    final_state = manifest.get("final_state")
    if not isinstance(final_state, dict) or not final_state:
        raise SessionError("install session has no finalized state")

    ops = tx_manifest.get("ops", [])
    if not isinstance(ops, list):
        raise SessionError("extension transaction ops are corrupt")

    first_by_rel: dict[str, dict[str, Any]] = {}
    for op in ops:
        if not isinstance(op, dict):
            raise SessionError("extension transaction op is corrupt")
        rel_raw = op.get("rel")
        if rel_raw:
            rel = _safe_rel(str(rel_raw))
            first_by_rel.setdefault(rel, op)

    conflicts: list[str] = []
    for rel, wanted in sorted(final_state.items()):
        if not isinstance(wanted, dict):
            raise SessionError("corrupt final_state entry: %s" % rel)
        if rel in first_by_rel:
            got = _extension_pre_snapshot(
                root,
                tx_id,
                first_by_rel[rel],
            )
        else:
            got = _snapshot(root, rel)
        if got != wanted:
            conflicts.append(
                "%s (session=%s, tx-pre/current=%s)"
                % (
                    rel,
                    json.dumps(wanted, sort_keys=True),
                    json.dumps(got, sort_keys=True),
                )
            )

    if conflicts:
        raise SessionError(
            "refusing session extension because project changed after "
            "the base install:\n  - "
            + "\n  - ".join(conflicts)
        )

    _verify_transaction_post_state(root, tx_manifest)

    updated = dict(manifest)
    updated["tx_ids"] = [*tx_ids, tx_id]
    extensions = updated.get("extensions", [])
    if not isinstance(extensions, list):
        raise SessionError("session extensions metadata is corrupt")
    updated["extensions"] = [
        *extensions,
        {
            "tx_id": tx_id,
            "reason": tx_manifest.get("reason", ""),
            "extended_at": time.strftime(
                "%Y-%m-%dT%H:%M:%SZ",
                time.gmtime(),
            ),
        },
    ]

    _preflight_restore_material(root, updated)
    targets = _derive_targets(root, updated)
    updated["final_state"] = {
        rel: _snapshot(root, rel) for rel in targets
    }
    updated["extended_at"] = time.strftime(
        "%Y-%m-%dT%H:%M:%SZ",
        time.gmtime(),
    )
    _json_write(root, _session_rel(session_id), updated)

    return {
        "session_id": session_id,
        "status": "installed",
        "extended": True,
        "tx_id": tx_id,
        "managed_paths": len(targets),
    }


def show_session(
    root: str,
    session_id: str | None = None,
) -> dict[str, Any]:
    root = _canonical(root)
    if session_id:
        return _load_session(root, session_id)
    latest = _latest_session(root, status="installed")
    if latest is None:
        raise SessionError("no installed OPK session found")
    return latest[1]


def uninstall_session(
    root: str,
    session_id: str | None,
    yes: bool,
) -> dict[str, Any]:
    root = _canonical(root)

    lock_fd = tx._open_state_lock(root, ".install.lock")
    try:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            raise SessionError(
                "another installer/uninstaller is holding the install lock"
            ) from exc

        if session_id:
            manifest = _load_session(root, session_id)
            chosen = session_id
            if manifest.get("status") != "installed":
                raise SessionError(
                    "session %s is not installed (status=%s)"
                    % (chosen, manifest.get("status"))
                )
        else:
            latest = _latest_session(root, status="installed")
            if latest is None:
                raise SessionError(
                    "no installed OPK session manifest found; "
                    "automatic uninstall is refused"
                )
            chosen, manifest = latest

        if not yes:
            print(
                "Sẽ gỡ OPK install session %s trong:\n  %s"
                % (chosen, root)
            )
            print(
                "Mọi managed file phải còn đúng trạng thái lúc install kết thúc."
            )
            answer = input("Tiếp tục? [y/N] ").strip().lower()
            if answer not in ("y", "yes"):
                return {
                    "session_id": chosen,
                    "status": "cancelled",
                }

        _compare_final_state(root, manifest)
        _preflight_restore_material(root, manifest)

        tx_ids = [str(value) for value in manifest.get("tx_ids", [])]
        for tx_id in reversed(tx_ids):
            tx_manifest = _tx_manifest(root, tx_id)
            tx_lease = tx_manifest.get("lease")
            if tx_lease is not None and not isinstance(tx_lease, str):
                raise SessionError(
                    "transaction %s has invalid lease metadata" % tx_id
                )
            tx.rollback(
                root,
                tx_id,
                force=True,
                lease=tx_lease,
            )

        _restore_wal(root, manifest)
        restored_legacy = _restore_legacy_archives(root, manifest)
        removed_backups = _cleanup_merge_backups(root, manifest)
        _cleanup_wal_archive(root, manifest)

        manifest["status"] = "uninstalled"
        manifest["uninstalled_at"] = time.strftime(
            "%Y-%m-%dT%H:%M:%SZ", time.gmtime()
        )
        _json_write(root, _session_rel(chosen), manifest)

        return {
            "session_id": chosen,
            "status": "uninstalled",
            "transactions_rolled_back": len(tx_ids),
            "legacy_restored": restored_legacy,
            "recovery_backups_removed": removed_backups,
        }
    finally:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_UN)
        except OSError:
            pass
        io.close_fd(lock_fd)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    create = sub.add_parser("create")
    create.add_argument("--root", required=True)
    create.add_argument("--merge-json", default="")
    create.add_argument("--txid", action="append", default=[])
    create.add_argument("--lease")

    finalize = sub.add_parser("finalize")
    finalize.add_argument("--root", required=True)
    finalize.add_argument("--session", required=True)

    show = sub.add_parser("show")
    show.add_argument("--root", required=True)
    show.add_argument("--session")

    uninstall = sub.add_parser("uninstall")
    uninstall.add_argument("--root", required=True)
    uninstall.add_argument("--session")
    uninstall.add_argument("--yes", action="store_true")

    return parser


def main(argv: list[str]) -> int:
    args = _parser().parse_args(argv)
    if args.command == "create":
        result = create_session(
            args.root, args.merge_json, args.txid, args.lease
        )
    elif args.command == "finalize":
        result = finalize_session(args.root, args.session)
    elif args.command == "show":
        result = show_session(args.root, args.session)
    elif args.command == "uninstall":
        result = uninstall_session(
            args.root, args.session, args.yes
        )
    else:
        raise SessionError("unknown command")
    print(json.dumps(result, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except io.UnsafePathError as exc:
        print(
            json.dumps(
                {"error": "unsafe-path", "message": str(exc)},
                ensure_ascii=False,
            ),
            file=sys.stderr,
        )
        raise SystemExit(2)
    except (SessionError, tx.TxError, io.OpkSafeIOError) as exc:
        print(
            json.dumps(
                {"error": "error", "message": str(exc)},
                ensure_ascii=False,
            ),
            file=sys.stderr,
        )
        raise SystemExit(1)
