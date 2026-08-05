#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────
# opk_tx.py
# opencode-power-kit
#
# Transaction/journal layer on top of opk_safe_io. Every install-like
# operation is recorded in a manifest + append journal under
# <root>/.opk-state/transactions/<txid>/, with pre-content backups,
# so a failure (or SIGINT/SIGTERM) can roll the project back to its
# previous state. Incomplete transactions are detected and rolled
# back on the next run.
#
# Ops: CREATE | REPLACE | MERGE_MARKER | MKDIR | COPY_TREE |
#      REMOVE_MANAGED | ARCHIVE
#
# Failure injection (test only): OPK_TEST_MODE=1 + OPK_TEST_FAIL_AFTER=<op>
# makes the transaction fail right after the named op completes,
# exercising the rollback path. In production (OPK_TEST_MODE != 1)
# the injection env is refused.
#
# CLI:
#   opk_tx.py begin --root R --reason X
#   opk_tx.py stage  --txid T --root R --kind KIND [--rel P] [--text T]
#                    [--file F] [--marker M] [--src-root SR --src-rel SRREL]
#                    [--mode M] [--require-absent]
#   opk_tx.py commit --txid T --root R
#   opk_tx.py rollback --txid T --root R
#   opk_tx.py status --root R [--json]
#   opk_tx.py recover --root R --latest|--all [--yes]
#
# Exit codes: 0 ok | 1 error | 2 unsafe path | 3 missing
# ─────────────────────────────────────────────────────────────────

import errno
import fcntl
import json
import os
import re
import sys
import time
import uuid

import opk_safe_io as io

STATE_REL = ".opk-state"
TX_DIR_REL = STATE_REL + "/transactions"
LOCK_REL = STATE_REL + "/.tx-lock"
MANIFEST = "manifest.json"
JOURNAL = "journal.log"
BACKUPS = "backups"

TX_VERSION = 1

KINDS = ("CREATE", "REPLACE", "MERGE_MARKER", "MKDIR", "COPY_TREE",
         "REMOVE_MANAGED", "ARCHIVE")


class TxError(Exception):
    pass


class TxUnsafe(TxError):
    pass


def _fail_after():
    mode = os.environ.get("OPK_TEST_MODE")
    marker = os.environ.get("OPK_TEST_FAIL_AFTER")
    if not marker:
        return None
    if mode != "1":
        raise TxError(
            "OPK_TEST_FAIL_AFTER is test-only; refusing to run in production "
            "(set OPK_TEST_MODE=1 to enable failure injection)"
        )
    if marker not in KINDS:
        raise TxError("unknown OPK_TEST_FAIL_AFTER kind: %s" % marker)
    return marker


def _inject(kind):
    if kind == _fail_after():
        raise TxError("injected failure after op kind %s (OPK_TEST_FAIL_AFTER)" % kind)


def _sanitize(rel):
    return re.sub(r"[^A-Za-z0-9._-]", "_", rel)


class Lock:
    def __init__(self, root):
        self.root = root
        self.fd = None

    def __enter__(self):
        lock_dir = os.path.join(self.root, STATE_REL)
        os.makedirs(lock_dir, exist_ok=True)
        self.fd = os.open(os.path.join(lock_dir, ".tx-lock"),
                          os.O_RDWR | os.O_CREAT, 0o600)
        try:
            fcntl.flock(self.fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            raise TxError("another opk transaction is in progress") from exc
        return self

    def __exit__(self, *exc):
        if self.fd is not None:
            try:
                fcntl.flock(self.fd, fcntl.LOCK_UN)
            except OSError:
                pass
            try:
                os.close(self.fd)
            except OSError:
                pass
        return False


def tx_dir(root, tx_id):
    return os.path.join(root, STATE_REL, "transactions", tx_id)


def manifest_path(root, tx_id):
    return os.path.join(tx_dir(root, tx_id), MANIFEST)


def _write_json_abs(path, obj):
    tmp = "%s.tmp-%s" % (path, uuid.uuid4().hex[:12])
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(obj, fh, sort_keys=True, indent=2)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)
    dfd = os.open(os.path.dirname(path), os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(dfd)
    finally:
        os.close(dfd)


def _read_json_abs(path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def _journal_append(root, tx_id, entry):
    path = os.path.join(tx_dir(root, tx_id), JOURNAL)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, sort_keys=True) + "\n")
        fh.flush()
        os.fsync(fh.fileno())


def _load_manifest(root, tx_id):
    path = manifest_path(root, tx_id)
    if not os.path.exists(path):
        raise TxError("transaction %s does not exist under %s" % (tx_id, root))
    return _read_json_abs(path)


def _save_manifest(root, tx_id, manifest):
    _write_json_abs(manifest_path(root, tx_id), manifest)


def _rel_of_manifest(root, tx_id):
    manifest = _load_manifest(root, tx_id)
    root_canon = io.canonical_root(root)
    if manifest.get("project_root") != root_canon:
        raise TxError("manifest project_root mismatch: %s" % manifest.get("project_root"))
    return manifest


def begin(root, reason):
    _fail_after()
    root = io.canonical_root(root)
    with Lock(root):
        tx_id = "%s-%s" % (time.strftime("%Y%m%d-%H%M%S"), uuid.uuid4().hex[:8])
        manifest = {
            "version": TX_VERSION,
            "tx_id": tx_id,
            "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "reason": reason,
            "project_root": root,
            "status": "prepared",
            "ops": [],
        }
        rel = os.path.join(TX_DIR_REL, tx_id)
        io.mkdir(root, rel, create_parents=True)
        io.mkdir(root, os.path.join(rel, BACKUPS), create_parents=True)
        _save_manifest(root, tx_id, manifest)
        return tx_id


def _backup_rel(root, tx_id, seq, rel):
    return os.path.join(TX_DIR_REL, tx_id, BACKUPS,
                        "%04d-%s" % (seq, _sanitize(rel)))


def _pre_backup(root, tx_id, seq, rel, manifest):
    """Backup pre-content if the target exists and is a regular file."""
    info = io.check(root, rel)
    if not info["exists"]:
        return None
    if info["is_symlink"]:
        raise TxUnsafe("refusing to stage over symlink: %s" % rel)
    if not info["is_reg"]:
        raise TxUnsafe("refusing to stage over non-regular target: %s" % rel)
    if info["nlink"] and info["nlink"] > 1:
        raise TxUnsafe("refusing to stage over hardlink alias: %s" % rel)
    backup_rel = _backup_rel(root, tx_id, seq, rel)
    io.backup(root, rel, root, backup_rel)
    pre_hash = io.sha256_bytes(io.safe_read(root, rel))
    return {"backup_rel": backup_rel, "pre_hash": pre_hash, "pre_mode": info["mode"]}


def stage(root, tx_id, kind, rel, text=None, file_src=None, marker=None,
          mode=None, require_absent=False, src_root=None, src_rel=None):
    if kind not in KINDS:
        raise TxError("unknown op kind: %s" % kind)
    try:
        with Lock(root):
            return _stage_locked(root, tx_id, kind, rel, text, file_src, marker,
                                 mode, require_absent, src_root, src_rel)
    except (TxError, io.UnsafePathError, io.PathMissingError,
            io.OpkSafeIOError):
        _best_effort_rollback(root, tx_id)
        raise


def _best_effort_rollback(root, tx_id):
    """Reverse any applied ops of a failed transaction. If the lock or the
    transaction state prevents a clean rollback, leave status=failed so a
    later `recover` finishes the job."""
    try:
        rollback(root, tx_id)
    except Exception:
        pass


def _stage_locked(root, tx_id, kind, rel, text=None, file_src=None,
                  marker=None, mode=None, require_absent=False,
                  src_root=None, src_rel=None):
    manifest = _rel_of_manifest(root, tx_id)
    if manifest["status"] in ("committed", "rolled_back", "failed"):
        raise TxError("transaction already %s" % manifest["status"])
    manifest["status"] = "applying"
    _save_manifest(root, tx_id, manifest)

    seq = len(manifest["ops"]) + 1
    op = {"seq": seq, "op": kind, "rel": rel}
    try:
        if kind in ("CREATE", "REPLACE", "COPY_TREE"):
            pre = _pre_backup(root, tx_id, seq, rel, manifest)
            if pre is not None:
                op.update(pre)
            data = text if text is not None else None
            if file_src is not None:
                with open(file_src, "rb") as fh:
                    data = fh.read()
            if data is None and src_root is not None and src_rel is not None:
                data = io.safe_read(src_root, src_rel)
            if data is None:
                raise TxError("stage %s requires --text, --file or --src" % kind)
            if require_absent and pre is not None:
                raise TxError("target already exists: %s" % rel)
            result = io.write(root, rel, data, mode=mode,
                              preserve_mode=True,
                              require_absent=require_absent)
            op["post_hash"] = io.sha256_bytes(data)
            op["pre_exists"] = pre is not None
        elif kind == "MERGE_MARKER":
            if marker is None:
                raise TxError("MERGE_MARKER requires --marker")
            pre = _pre_backup(root, tx_id, seq, rel, manifest)
            if pre is not None:
                op.update(pre)
            merged = _merge_marker(root, rel, marker, text or b"")
            result = io.write(root, rel, merged, preserve_mode=True)
            op["post_hash"] = io.sha256_bytes(merged)
            op["pre_exists"] = pre is not None
            op["marker"] = marker
        elif kind == "MKDIR":
            result = io.mkdir(root, rel, create_parents=True)
            op["pre_exists"] = not result["created"]
        elif kind == "REMOVE_MANAGED":
            info = io.check(root, rel)
            if not info["exists"]:
                op["pre_exists"] = False
                op["note"] = "already-absent"
            else:
                pre = _pre_backup(root, tx_id, seq, rel, manifest)
                if pre is not None:
                    op.update(pre)
                result = io.remove(root, rel)
                op["pre_exists"] = True
        elif kind == "ARCHIVE":
            info = io.check(root, rel)
            if not info["exists"]:
                op["pre_exists"] = False
                op["note"] = "already-absent"
            else:
                pre = _pre_backup(root, tx_id, seq, rel, manifest)
                if pre is not None:
                    op.update(pre)
                result = io.remove(root, rel)
                op["pre_exists"] = True
        else:
            raise TxError("unhandled kind %s" % kind)
    except (io.UnsafePathError, io.PathMissingError, io.OpkSafeIOError) as exc:
        manifest["status"] = "failed"
        manifest["error"] = str(exc)
        _save_manifest(root, tx_id, manifest)
        raise
    except Exception as exc:
        manifest["status"] = "failed"
        manifest["error"] = "%s: %s" % (type(exc).__name__, exc)
        _save_manifest(root, tx_id, manifest)
        raise

    manifest["ops"].append(op)
    _save_manifest(root, tx_id, manifest)
    _journal_append(root, tx_id, {
        "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "seq": seq, "op": kind, "rel": rel,
        "pre_hash": op.get("pre_hash"), "post_hash": op.get("post_hash"),
        "status": "applied",
    })
    _inject(kind)
    return op


def _merge_marker(root, rel, marker, content):
    begin_mark = "<!-- OPK-MARKER: %s-begin -->" % marker
    end_mark = "<!-- OPK-MARKER: %s-end -->" % marker
    if isinstance(content, bytes):
        content = content.decode("utf-8")
    block = "\n%s\n%s\n%s\n" % (begin_mark, content.rstrip("\n"), end_mark)
    try:
        existing = io.safe_read(root, rel).decode("utf-8")
    except io.PathMissingError:
        return block.lstrip("\n")
    pattern = re.compile(
        r"(?ms)^\s*%s.*?%s\s*" % (re.escape(begin_mark), re.escape(end_mark)))
    new, n = pattern.subn(block, existing, count=1)
    if n:
        return new
    return existing.rstrip("\n") + "\n" + block


def commit(root, tx_id):
    with Lock(root):
        manifest = _rel_of_manifest(root, tx_id)
        if manifest["status"] == "committed":
            return {"tx_id": tx_id, "status": "committed", "ops": len(manifest["ops"])}
        if manifest["status"] in ("rolled_back", "failed"):
            raise TxError("cannot commit transaction in state %s" % manifest["status"])
        manifest["status"] = "committed"
        manifest["committed_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        _save_manifest(root, tx_id, manifest)
        _journal_append(root, tx_id, {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "op": "COMMIT", "status": "committed",
        })
        return {"tx_id": tx_id, "status": "committed", "ops": len(manifest["ops"])}


def rollback(root, tx_id, force=False):
    """Reverse every op. Idempotent: rolled_back is a no-op."""
    with Lock(root):
        manifest = _load_manifest(root, tx_id)
        if manifest["status"] == "rolled_back":
            return {"tx_id": tx_id, "status": "rolled_back", "ops": 0}
        if manifest["status"] == "committed" and not force:
            raise TxError("cannot roll back a committed transaction")
        reversed_ops = list(reversed(manifest.get("ops", [])))
        for op in reversed_ops:
            _rollback_op(root, tx_id, op)
        manifest["status"] = "rolled_back"
        manifest["rolled_back_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        _save_manifest(root, tx_id, manifest)
        _journal_append(root, tx_id, {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "op": "ROLLBACK", "status": "rolled_back",
        })
        return {"tx_id": tx_id, "status": "rolled_back", "ops": len(reversed_ops)}


def _rollback_op(root, tx_id, op):
    rel = op["rel"]
    kind = op["op"]
    backup_rel = op.get("backup_rel")
    had_pre = op.get("pre_exists")
    if kind in ("CREATE", "REPLACE", "COPY_TREE", "MERGE_MARKER"):
        if backup_rel and had_pre:
            io.restore(root, rel, root, backup_rel)
        else:
            try:
                info = io.check(root, rel)
                if info["exists"]:
                    io.remove(root, rel)
            except io.PathMissingError:
                pass
    elif kind == "MKDIR":
        try:
            info = io.check(root, rel)
            if info["is_dir"]:
                io.rmdir(root, rel)
        except (io.PathMissingError, io.OpkSafeIOError):
            pass
    elif kind in ("REMOVE_MANAGED", "ARCHIVE"):
        if backup_rel and had_pre:
            io.restore(root, rel, root, backup_rel)
    elif kind == "COPY_TREE":
        pass
    else:
        raise TxError("cannot roll back unknown op kind %s" % kind)


def list_txs(root):
    root = io.canonical_root(root)
    base = os.path.join(root, TX_DIR_REL)
    if not os.path.isdir(base):
        return []
    out = []
    for name in sorted(os.listdir(base)):
        path = os.path.join(base, name)
        if not os.path.isdir(path):
            continue
        mp = os.path.join(path, MANIFEST)
        if not os.path.isfile(mp):
            continue
        try:
            out.append(_read_json_abs(mp))
        except (OSError, ValueError):
            out.append({"tx_id": name, "status": "corrupt",
                        "project_root": root, "reason": "unreadable manifest"})
    return out


def status(root, tx_id=None):
    txs = list_txs(root)
    if tx_id is not None:
        for t in txs:
            if t["tx_id"] == tx_id:
                return t
        raise TxError("transaction %s not found" % tx_id)
    return txs


def recover(root, which="latest", txid=None, yes=False):
    """Roll back incomplete transactions. which: latest | all; or pass
    --txid to recover one specific transaction."""
    root = io.canonical_root(root)
    txs = list_txs(root)
    pending = [t for t in txs
               if t.get("status") in ("prepared", "applying", "failed")]
    if not pending:
        return {"recovered": [], "pending": 0}
    pending.sort(key=lambda t: (t.get("created_at", ""), t.get("tx_id", "")))
    if txid is not None:
        all_ids = [t["tx_id"] for t in txs]
        if txid not in all_ids:
            raise TxError("transaction %s not found" % txid)
        if txid not in [t["tx_id"] for t in pending]:
            return {"recovered": [], "pending": 0,
                    "note": "transaction %s is not pending" % txid}
        pending = [next(t for t in pending if t["tx_id"] == txid)]
    elif which == "latest":
        pending = [pending[-1]]
    if not yes:
        names = ", ".join(t["tx_id"] for t in pending)
        raise TxError("recovery would roll back: %s (pass --yes)" % names)
    out = []
    for t in pending:
        res = rollback(root, t["tx_id"], force=False)
        res["tx_id"] = t["tx_id"]
        out.append(res)
    return {"recovered": out, "pending": len(pending)}


# ─── CLI ─────────────────────────────────────────────────────────

def _parse_args(argv):
    args = {}
    cmd = None
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg.startswith("--") and "=" in arg:
            key, val = arg[2:].split("=", 1)
            args[key] = val
        elif arg.startswith("--"):
            key = arg[2:]
            if i + 1 < len(argv) and not argv[i + 1].startswith("--"):
                args[key] = argv[i + 1]
                i += 1
            else:
                args[key] = True
        else:
            cmd = arg
        i += 1
    return cmd, args


def _need(args, flag):
    if flag not in args:
        raise TxError("missing required flag: %s" % flag)
    return args[flag]


def main(argv):
    cmd, args = _parse_args(argv)
    if cmd == "begin":
        return print(json.dumps({"tx_id": begin(_need(args, "root"),
                                                args.get("reason", ""))}))
    if cmd == "stage":
        op = stage(_need(args, "root"), _need(args, "txid"), _need(args, "kind"),
                   rel=args.get("rel", ""),
                   text=args.get("text"),
                   file_src=args.get("file"),
                   marker=args.get("marker"),
                   mode=int(args["mode"], 8) if "mode" in args else None,
                   require_absent=bool(args.get("require-absent")),
                   src_root=args.get("src-root"), src_rel=args.get("src-rel"))
        return print(json.dumps(op, sort_keys=True))
    if cmd == "commit":
        return print(json.dumps(commit(_need(args, "root"), _need(args, "txid"))))
    if cmd == "rollback":
        return print(json.dumps(rollback(_need(args, "root"), _need(args, "txid"),
                                         force=bool(args.get("force")))))
    if cmd == "status":
        return print(json.dumps(status(_need(args, "root"), args.get("txid")),
                                sort_keys=True))
    if cmd == "recover":
        return print(json.dumps(recover(_need(args, "root"),
                                        args.get("which", "latest"),
                                        txid=args.get("txid"),
                                        yes=bool(args.get("yes")))))
    raise TxError("unknown command: %s" % cmd)


if __name__ == "__main__":
    try:
        main(sys.argv[1:])
        sys.exit(0)
    except TxUnsafe as exc:
        print(json.dumps({"error": "unsafe-path", "message": str(exc)}))
        sys.exit(2)
    except io.PathMissingError as exc:
        print(json.dumps({"error": "missing", "message": str(exc)}))
        sys.exit(3)
    except TxError as exc:
        print(json.dumps({"error": "error", "message": str(exc)}))
        sys.exit(1)
    except BrokenPipeError:
        sys.exit(1)
