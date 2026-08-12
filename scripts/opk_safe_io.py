#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────
# opk_safe_io.py
# opencode-power-kit
#
# TOCTOU-safe filesystem primitives for the opk installer stack.
# Every path operation is performed relative to a containment root
# using dir_fd + O_NOFOLLOW + O_CREAT|O_EXCL + os.replace + fsync,
# so a symlink swap between "check" and "use" cannot redirect writes.
#
# Safety properties:
#   - rel paths must be relative, contain no ".." and no empty parts
#   - no path component may be a symlink (checked with follow_symlinks=False)
#   - the final target of a write must not be a symlink
#   - overwriting a regular file with nlink > 1 (hardlink alias) is refused
#   - temp files are created O_EXCL with unpredictable names in the
#     same directory as the target, then atomically replaced and fsynced
#   - reads open with O_NOFOLLOW and verify the file is a regular file
#
# CLI (machine readable, JSON on stdout):
#   opk_safe_io.py check   --root R --rel P
#   opk_safe_io.py verify  --root R --rel P
#   opk_safe_io.py hash    --root R --rel P
#   opk_safe_io.py read    --root R --rel P
#   opk_safe_io.py write   --root R --rel P [--stdin|--text T] [--mode M]
#                          [--preserve-mode] [--require-absent]
#                          [--create-parents] [--no-clobber]
#   opk_safe_io.py mkdir   --root R --rel P
#   opk_safe_io.py backup  --root R --rel P --backup-root BR --backup-rel Q
#   opk_safe_io.py restore --root R --rel P --backup-root BR --backup-rel Q
#   opk_safe_io.py remove  --root R --rel P
#   opk_safe_io.py rmdir   --root R --rel P
#
# Exit codes: 0 ok | 1 error | 2 unsafe path | 3 target missing
# ─────────────────────────────────────────────────────────────────

import errno
import hashlib
import json
import os
import secrets
import sys

EXIT_OK = 0
EXIT_ERR = 1
EXIT_UNSAFE = 2
EXIT_MISSING = 3

MAX_FILE_BYTES = 64 * 1024 * 1024


class OpkSafeIOError(Exception):
    """Generic failure."""


class UnsafePathError(OpkSafeIOError):
    """Path escapes root, contains '..', or traverses a symlink."""


class PathMissingError(OpkSafeIOError):
    """Path does not exist."""


def canonical_root(root):
    root = os.path.realpath(os.path.abspath(root))
    if not os.path.isdir(root):
        raise OpkSafeIOError("root is not a directory: %s" % root)
    return root


def split_rel(rel):
    if not isinstance(rel, str) or not rel:
        raise UnsafePathError("empty rel path")
    if rel.startswith("/"):
        raise UnsafePathError("absolute rel path: %s" % rel)
    parts = rel.split("/")
    if any(p in ("", ".", "..") for p in parts):
        raise UnsafePathError("unsafe rel path component: %s" % rel)
    if "\x00" in rel:
        raise UnsafePathError("nul byte in rel path")
    return parts


def open_root(root):
    fd = os.open(root, os.O_RDONLY | os.O_DIRECTORY)
    return fd


def open_dir_no_follow(parent_fd, part):
    """Open a subdirectory without following a symlink. Returns fd."""
    try:
        return os.open(
            part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent_fd
        )
    except OSError as exc:
        if exc.errno == errno.ELOOP:
            raise UnsafePathError("symlink in path component: %s" % part) from exc
        if exc.errno in (errno.ENOENT, errno.ENOTDIR):
            raise PathMissingError("missing path component: %s" % part) from exc
        raise OpkSafeIOError("cannot open %s: %s" % (part, exc)) from exc


def open_parent(root_fd, rel_parts, create_parents=False):
    """Return (parent_fd, final_name). No component is followed as symlink."""
    opened = []
    parent_fd = root_fd
    try:
        for part in rel_parts[:-1]:
            try:
                parent_fd = os.open(
                    part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent_fd
                )
            except OSError as exc:
                if create_parents and exc.errno == errno.ENOENT:
                    os.mkdir(part, 0o755, dir_fd=parent_fd)
                    parent_fd = os.open(
                        part,
                        os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                        dir_fd=parent_fd,
                    )
                elif exc.errno in (errno.ELOOP, errno.ENOTDIR):
                    raise UnsafePathError(
                        "path component not traversable: %s" % part
                    ) from exc
                elif exc.errno == errno.ENOENT:
                    raise PathMissingError("missing path component: %s" % part) from exc
                else:
                    raise OpkSafeIOError("cannot open %s: %s" % (part, exc)) from exc
            opened.append(parent_fd)
    except Exception:
        for fd in reversed(opened):
            close_fd(fd)
        raise
    return parent_fd, rel_parts[-1]


def lstat_final(parent_fd, name):
    try:
        return os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except OSError as exc:
        if exc.errno == errno.ENOENT:
            raise PathMissingError("target missing: %s" % name) from exc
        raise OpkSafeIOError("cannot stat %s: %s" % (name, exc)) from exc


def close_fd(fd):
    if fd is None:
        return
    try:
        os.close(fd)
    except OSError:
        pass


def _read_all(fd):
    out = []
    total = 0
    while True:
        chunk = os.read(fd, 65536)
        if not chunk:
            break
        total += len(chunk)
        if total > MAX_FILE_BYTES:
            raise OpkSafeIOError("file exceeds max size")
        out.append(chunk)
    return b"".join(out)


def safe_read(root, rel):
    """Read a regular file under root, refusing symlinks at any level."""
    root = canonical_root(root)
    root_fd = open_root(root)
    parent_fd = None
    try:
        parent_fd, name = open_parent(root_fd, split_rel(rel))
        st = lstat_final(parent_fd, name)
        if stat_is_symlink(st):
            raise UnsafePathError("target is a symlink: %s" % rel)
        if not stat_is_reg(st):
            raise UnsafePathError("target is not a regular file: %s" % rel)
        fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent_fd)
        try:
            return _read_all(fd)
        finally:
            close_fd(fd)
    finally:
        close_fd(parent_fd)
        close_fd(root_fd)


def stat_is_symlink(st):
    return st is not None and os.path.stat.S_ISLNK(st.st_mode)


def stat_is_reg(st):
    return st is not None and os.path.stat.S_ISREG(st.st_mode)


def stat_is_dir(st):
    return st is not None and os.path.stat.S_ISDIR(st.st_mode)


def check(root, rel):
    """Return JSON-able dict describing the target."""
    root = canonical_root(root)
    root_fd = open_root(root)
    parent_fd = None
    result = {"exists": False, "is_symlink": False, "is_dir": False,
              "is_reg": False, "mode": None, "nlink": None, "size": None,
              "type": "missing"}
    try:
        parts = split_rel(rel)
        try:
            parent_fd, name = open_parent(root_fd, parts)
            st = lstat_final(parent_fd, name)
        except PathMissingError:
            return result
        result["exists"] = True
        result["is_symlink"] = stat_is_symlink(st)
        result["is_dir"] = stat_is_dir(st)
        result["is_reg"] = stat_is_reg(st)
        result["mode"] = st.st_mode & 0o7777
        result["nlink"] = st.st_nlink
        result["size"] = st.st_size
        if stat_is_symlink(st):
            result["type"] = "symlink"
        elif stat_is_dir(st):
            result["type"] = "dir"
        elif stat_is_reg(st):
            result["type"] = "file"
        else:
            result["type"] = "other"
        return result
    finally:
        close_fd(parent_fd)
        close_fd(root_fd)


def _fsync_dir(parent_fd):
    dfd = os.open(".", os.O_RDONLY | os.O_DIRECTORY, dir_fd=parent_fd)
    try:
        os.fsync(dfd)
    finally:
        close_fd(dfd)


def write(root, rel, data, mode=None, preserve_mode=False, require_absent=False,
          create_parents=False, no_clobber=False):
    """Atomically create or replace a regular file under root.

    Refuses to write through symlinks and refuses to overwrite a file
    with nlink > 1 (hardlink alias).
    """
    if isinstance(data, str):
        data = data.encode("utf-8")
    root = canonical_root(root)
    root_fd = open_root(root)
    parent_fd = None
    tmp_name = None
    try:
        parts = split_rel(rel)
        parent_fd, name = open_parent(root_fd, parts, create_parents=create_parents)
        old_mode = None
        try:
            st = lstat_final(parent_fd, name)
            if stat_is_symlink(st):
                raise UnsafePathError("refusing to write through symlink: %s" % rel)
            if not stat_is_reg(st):
                raise UnsafePathError("refusing to clobber non-regular target: %s" % rel)
            if st.st_nlink > 1:
                raise UnsafePathError("refusing to overwrite hardlink alias: %s" % rel)
            old_mode = st.st_mode & 0o7777
        except PathMissingError:
            pass
        if require_absent:
            try:
                lstat_final(parent_fd, name)
                raise OpkSafeIOError("target already exists: %s" % rel)
            except PathMissingError:
                pass
        if no_clobber:
            try:
                lstat_final(parent_fd, name)
                raise OpkSafeIOError("target already exists (no-clobber): %s" % rel)
            except PathMissingError:
                pass
        tmp_name = ".opk-tmp-%s" % secrets.token_hex(8)
        fd = os.open(
            tmp_name,
            os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=parent_fd,
        )
        try:
            view = memoryview(data)
            written = 0
            while written < len(view):
                written += os.write(fd, view[written:])
            os.fsync(fd)
        finally:
            close_fd(fd)
        new_mode = mode if mode is not None else (old_mode if preserve_mode and old_mode else 0o644)
        os.chmod(tmp_name, new_mode, dir_fd=parent_fd, follow_symlinks=False)
        os.replace(tmp_name, name, src_dir_fd=parent_fd, dst_dir_fd=parent_fd)
        tmp_name = None
        _fsync_dir(parent_fd)
        return {"root": root, "rel": rel, "mode": new_mode,
                "existed_before": old_mode is not None}
    finally:
        if tmp_name is not None and parent_fd is not None:
            try:
                os.unlink(tmp_name, dir_fd=parent_fd)
            except OSError:
                pass
        close_fd(parent_fd)
        close_fd(root_fd)


def mkdir(root, rel, create_parents=False):
    root = canonical_root(root)
    root_fd = open_root(root)
    parent_fd = None
    try:
        parts = split_rel(rel)
        parent_fd, name = open_parent(root_fd, parts, create_parents=create_parents)
        try:
            st = lstat_final(parent_fd, name)
            if stat_is_dir(st):
                return {"root": root, "rel": rel, "created": False}
            raise OpkSafeIOError("target exists and is not a directory: %s" % rel)
        except PathMissingError:
            pass
        try:
            os.mkdir(name, 0o755, dir_fd=parent_fd)
        except FileExistsError:
            return {"root": root, "rel": rel, "created": False}
        return {"root": root, "rel": rel, "created": True}
    finally:
        close_fd(parent_fd)
        close_fd(root_fd)


def remove(root, rel):
    root = canonical_root(root)
    root_fd = open_root(root)
    parent_fd = None
    try:
        parts = split_rel(rel)
        parent_fd, name = open_parent(root_fd, parts)
        st = lstat_final(parent_fd, name)
        if stat_is_symlink(st):
            raise UnsafePathError("refusing to remove symlink: %s" % rel)
        if not stat_is_reg(st):
            raise UnsafePathError("refusing to remove non-regular target: %s" % rel)
        os.unlink(name, dir_fd=parent_fd)
        _fsync_dir(parent_fd)
        return {"root": root, "rel": rel, "removed": True}
    finally:
        close_fd(parent_fd)
        close_fd(root_fd)


def rmdir(root, rel):
    root = canonical_root(root)
    root_fd = open_root(root)
    parent_fd = None
    try:
        parts = split_rel(rel)
        parent_fd, name = open_parent(root_fd, parts)
        st = lstat_final(parent_fd, name)
        if stat_is_symlink(st):
            raise UnsafePathError("refusing to rmdir symlink: %s" % rel)
        if not stat_is_dir(st):
            raise UnsafePathError("target is not a directory: %s" % rel)
        os.rmdir(name, dir_fd=parent_fd)
        return {"root": root, "rel": rel, "removed": True}
    finally:
        close_fd(parent_fd)
        close_fd(root_fd)


def backup(root, rel, backup_root, backup_rel):
    data = safe_read(root, rel)
    return write(backup_root, backup_rel, data, preserve_mode=True)


def restore(root, rel, backup_root, backup_rel):
    data = safe_read(backup_root, backup_rel)
    return write(root, rel, data, preserve_mode=True)


def sha256_bytes(data):
    if isinstance(data, str):
        data = data.encode("utf-8")
    return hashlib.sha256(data).hexdigest()


# ─── CLI ─────────────────────────────────────────────────────────

def _need(args, flag):
    if flag not in args:
        raise OpkSafeIOError("missing required flag: %s" % flag)
    return args[flag]


def _out(obj):
    print(json.dumps(obj, sort_keys=True))
    return EXIT_OK


def _exit(code, obj):
    print(json.dumps(obj, sort_keys=True))
    return code


def main(argv):
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

    if not cmd:
        raise OpkSafeIOError("missing command")

    if cmd == "check":
        return _out(check(_need(args, "root"), _need(args, "rel")))
    if cmd == "verify":
        result = check(_need(args, "root"), _need(args, "rel"))
        if result["is_symlink"]:
            return _exit(EXIT_UNSAFE, {"safe": False, "reason": "symlink", "info": result})
        if not result["exists"]:
            return _exit(EXIT_MISSING, {"safe": False, "reason": "missing", "info": result})
        if not result["is_reg"]:
            return _exit(EXIT_UNSAFE, {"safe": False, "reason": "not-regular", "info": result})
        return _out({"safe": True, "reason": "ok", "info": result})
    if cmd == "hash":
        try:
            data = safe_read(_need(args, "root"), _need(args, "rel"))
        except PathMissingError:
            return _out({"sha256": "MISSING"})
        return _out({"sha256": sha256_bytes(data)})
    if cmd == "read":
        sys.stdout.buffer.write(safe_read(_need(args, "root"), _need(args, "rel")))
        return EXIT_OK
    if cmd == "write":
        if args.get("stdin"):
            data = sys.stdin.buffer.read()
        elif "text" in args:
            data = args["text"]
        else:
            raise OpkSafeIOError("write requires --stdin or --text")
        mode = None
        if "mode" in args:
            mode = int(args["mode"], 8)
        return _out(write(
            _need(args, "root"), _need(args, "rel"), data,
            mode=mode,
            preserve_mode=bool(args.get("preserve-mode")),
            require_absent=bool(args.get("require-absent")),
            create_parents=bool(args.get("create-parents")),
            no_clobber=bool(args.get("no-clobber")),
        ))
    if cmd == "mkdir":
        return _out(mkdir(_need(args, "root"), _need(args, "rel"),
                          create_parents=bool(args.get("create-parents"))))
    if cmd == "backup":
        return _out(backup(_need(args, "root"), _need(args, "rel"),
                           _need(args, "backup-root"), _need(args, "backup-rel")))
    if cmd == "restore":
        return _out(restore(_need(args, "root"), _need(args, "rel"),
                            _need(args, "backup-root"), _need(args, "backup-rel")))
    if cmd == "remove":
        return _out(remove(_need(args, "root"), _need(args, "rel")))
    if cmd == "rmdir":
        return _out(rmdir(_need(args, "root"), _need(args, "rel")))
    raise OpkSafeIOError("unknown command: %s" % cmd)


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except UnsafePathError as exc:
        print(json.dumps({"error": "unsafe-path", "message": str(exc)}))
        sys.exit(EXIT_UNSAFE)
    except PathMissingError as exc:
        print(json.dumps({"error": "missing", "message": str(exc)}))
        sys.exit(EXIT_MISSING)
    except OpkSafeIOError as exc:
        print(json.dumps({"error": "error", "message": str(exc)}))
        sys.exit(EXIT_ERR)
    except BrokenPipeError:
        sys.exit(EXIT_ERR)
