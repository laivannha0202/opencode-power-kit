#!/usr/bin/env python3
"""Install OPK assets into OpenCode's default global config directory."""

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

MANIFEST_NAME = ".opk-managed-assets.json"
SHIM_MARKER = "# @opk-managed-shim"
GLOBAL_MARKER = "opencode-power-kit-global"
PATH_MARKER = "opencode-power-kit-path"
ASSET_DIRS = ("agents", "commands", "skills", "plugins")


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON key: {key}")
        result[key] = value
    return result


def _strip_comments(text: str) -> tuple[str, bool]:
    """Strip // and /* */ comments. Returns (result, has_comments)."""
    result: list[str] = []
    index = 0
    in_string = in_line = in_block = False
    has_comments = False
    while index < len(text):
        char = text[index]
        following = text[index + 1] if index + 1 < len(text) else ""
        if in_string:
            result.append(char)
            if char == "\\" and following:
                result.append(following)
                index += 2
                continue
            if char == '"':
                in_string = False
            index += 1
        elif in_line:
            if char == "\n":
                in_line = False
                result.append(char)
            index += 1
        elif in_block:
            if char == "*" and following == "/":
                in_block = False
                index += 2
            else:
                index += 1
        elif char == '"':
            in_string = True
            result.append(char)
            index += 1
        elif char == "/" and following == "/":
            in_line = True
            has_comments = True
            index += 2
        elif char == "/" and following == "*":
            in_block = True
            has_comments = True
            index += 2
        else:
            result.append(char)
            index += 1
    if in_string or in_block:
        raise ValueError("unterminated JSONC string or comment")
    return "".join(result), has_comments


def _strip_trailing_commas(text: str) -> tuple[str, bool]:
    """Strip trailing commas before ``}`` or ``]`` in comment-free JSON."""
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
    return "".join(result), had_trailing


def scan_jsonc(text: str) -> tuple[str, bool, bool]:
    """Strip comments and trailing commas. Returns (stripped, has_comments, had_trailing)."""
    no_comments, has_comments = _strip_comments(text)
    clean, had_trailing = _strip_trailing_commas(no_comments)
    return clean, has_comments, had_trailing


def strip_jsonc(text: str) -> str:
    return scan_jsonc(text)[0]


def parse_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(strip_jsonc(path.read_text(encoding="utf-8")), object_pairs_hook=reject_duplicate_keys)
    except Exception as error:
        raise ValueError(f"cannot parse {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


def parse_json_with_comments(path: Path) -> tuple[dict[str, Any], bool, bool]:
    """Parse JSONC config. Returns (data, has_comments, had_trailing_commas)."""
    try:
        stripped, has_comments, had_trailing = scan_jsonc(path.read_text(encoding="utf-8"))
        value = json.loads(stripped, object_pairs_hook=reject_duplicate_keys)
    except Exception as error:
        raise ValueError(f"cannot parse {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value, has_comments, had_trailing


def dedupe(values: Any) -> list[Any]:
    if not isinstance(values, list):
        return []
    result: list[Any] = []
    for value in values:
        if value not in result:
            result.append(value)
    return result


def union(first: Any, second: Any) -> list[Any]:
    return dedupe([*dedupe(first), *dedupe(second)])


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(65536), b""):
            digest.update(chunk)
    return digest.hexdigest()


class Installer:
    def __init__(self, kit: Path, home: Path, mode: str | None, dry_run: bool, normalize_jsonc: bool) -> None:
        self.kit = kit
        self.home = home
        self.mode = mode
        self.dry_run = dry_run
        self.normalize_jsonc = normalize_jsonc
        self.config_dir = home / ".config" / "opencode"
        self.backup_dir = home / f".opencode-power-kit-backup-{self.stamp()}"
        self.backup_created = False
        self.originals: dict[Path, tuple[bytes | None, int]] = {}
        self.rolling_back = False

    @staticmethod
    def stamp() -> str:
        return time.strftime("%Y%m%d%H%M%S") + f"-{time.time_ns() % 1_000_000_000:09d}-{os.getpid()}"

    def validate_target(self, path: Path) -> None:
        if path == self.home:
            if self.home.is_symlink() or not self.home.is_dir():
                raise ValueError(f"HOME must be a real directory: {self.home}")
            return
        relative = path.relative_to(self.home)
        current = self.home
        if self.home.is_symlink() or not self.home.is_dir():
            raise ValueError(f"HOME must be a real directory: {self.home}")
        for part in relative.parts:
            current = current / part
            if current.is_symlink():
                raise ValueError(f"refusing symlink target: {current}")
        existing_parent = path.parent
        while not existing_parent.exists() and existing_parent != self.home:
            existing_parent = existing_parent.parent
        resolved = existing_parent.resolve(strict=True)
        if resolved != self.home and self.home not in resolved.parents:
            raise ValueError(f"target escapes HOME: {path}")

    def ensure_dir(self, path: Path) -> None:
        self.validate_target(path)
        if self.dry_run:
            return
        path.mkdir(parents=True, exist_ok=True)
        self.validate_target(path)
        if not path.is_dir():
            raise ValueError(f"target is not a directory: {path}")

    def backup(self, path: Path) -> None:
        if not path.exists():
            return
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"refusing to back up non-regular file: {path}")
        relative = path.relative_to(self.home)
        destination = self.backup_dir / relative
        if self.dry_run:
            return
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.exists() or destination.is_symlink():
            raise ValueError(f"backup collision: {destination}")
        shutil.copy2(path, destination, follow_symlinks=False)
        self.backup_created = True

    def atomic_bytes(self, path: Path, content: bytes, mode: int = 0o644) -> None:
        self.validate_target(path)
        self.ensure_dir(path.parent)
        if path.exists() and (path.is_symlink() or not path.is_file()):
            raise ValueError(f"refusing non-regular target: {path}")
        if self.dry_run:
            return
        if not self.rolling_back and path not in self.originals:
            if path.exists():
                metadata = path.stat(follow_symlinks=False)
                if not stat.S_ISREG(metadata.st_mode):
                    raise ValueError(f"refusing non-regular target before journal: {path}")
                self.originals[path] = (path.read_bytes(), stat.S_IMODE(metadata.st_mode))
            else:
                self.originals[path] = (None, mode)
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

    def rollback(self) -> None:
        failures: list[str] = []
        self.rolling_back = True
        try:
            for path, (content, mode) in reversed(self.originals.items()):
                try:
                    if content is None:
                        directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
                        try:
                            os.unlink(path.name, dir_fd=directory_fd)
                            os.fsync(directory_fd)
                        except FileNotFoundError:
                            pass
                        finally:
                            os.close(directory_fd)
                    else:
                        self.atomic_bytes(path, content, mode)
                        if path.read_bytes() != content:
                            raise RuntimeError("byte verification failed")
                except Exception as error:
                    failures.append(f"{path}: {error}")
        finally:
            self.rolling_back = False
        if failures:
            raise RuntimeError("installer rollback failed: " + "; ".join(failures))

    def atomic_text(self, path: Path, content: str, mode: int = 0o644) -> None:
        self.atomic_bytes(path, content.encode("utf-8"), mode)

    def acquire_lock(self) -> int:
        lock_path = self.config_dir / ".opk-install.lock"
        self.validate_target(lock_path)
        flags = os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC
        descriptor = os.open(lock_path, flags, 0o600)
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            os.close(descriptor)
            raise ValueError(f"installer lock is not a regular file: {lock_path}")
        os.fchmod(descriptor, 0o600)
        deadline = time.monotonic() + 30
        while True:
            try:
                fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
                return descriptor
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    os.close(descriptor)
                    raise TimeoutError(f"timed out waiting for installer lock: {lock_path}")
                time.sleep(0.05)

    def _discover_global_config(self) -> Path | None:
        """Discover active global config file. Raises on conflict."""
        json_path = self.config_dir / "opencode.json"
        jsonc_path = self.config_dir / "opencode.jsonc"
        if json_path.is_symlink():
            raise ValueError(f"refusing symlink global config: {json_path}")
        if jsonc_path.is_symlink():
            raise ValueError(f"refusing symlink global config: {jsonc_path}")
        json_exists = json_path.exists()
        jsonc_exists = jsonc_path.exists()
        if json_exists and jsonc_exists:
            raise ValueError(
                f"conflict: both {json_path.name} and {jsonc_path.name} exist in {self.config_dir}"
            )
        return json_path if json_exists else (jsonc_path if jsonc_exists else None)

    def merge_config(self) -> None:
        active = self._discover_global_config()
        target = active if active else self.config_dir / "opencode.json"
        self.validate_target(target)
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ValueError(f"global config is not a regular file: {target}")
        current, has_comments, has_trailing = parse_json_with_comments(target) if target.exists() else ({}, False, False)
        profile_name = self.mode or "safe"
        profile = parse_json(self.kit / "templates" / f"opencode.{profile_name}.json")
        merged = dict(current)
        merged.setdefault("$schema", "https://opencode.ai/config.json")
        merged["plugin"] = union(merged.get("plugin"), profile.get("plugin"))

        compaction = merged.get("compaction") if isinstance(merged.get("compaction"), dict) else {}
        wanted_compaction = profile.get("compaction", {})
        compaction["auto"] = wanted_compaction.get("auto", True)
        compaction["prune"] = wanted_compaction.get("prune", True)
        if "reserved" not in compaction:
            compaction["reserved"] = wanted_compaction.get("reserved", 10000)
        merged["compaction"] = compaction

        watcher = merged.get("watcher") if isinstance(merged.get("watcher"), dict) else {}
        watcher["ignore"] = union(watcher.get("ignore"), profile.get("watcher", {}).get("ignore"))
        merged["watcher"] = watcher
        if self.mode is not None or "permission" not in merged:
            merged["permission"] = profile["permission"]

        serialized = json.dumps(merged, indent=2, ensure_ascii=False) + "\n"
        if target.exists() and target.read_text(encoding="utf-8") == serialized:
            return
        if (has_comments or has_trailing) and not self.normalize_jsonc:
            raise ValueError(
                f"JSONC comments/trailing commas require explicit --normalize-jsonc before rewriting: {target}"
            )
        if has_comments or has_trailing:
            print("WARN: --normalize-jsonc removes comments and trailing commas")
        self.backup(target)
        self.atomic_text(target, serialized)
        if not self.dry_run and parse_json(target) != merged:
            raise RuntimeError(f"global config verification failed after atomic write: {target}")

    def load_manifest(self) -> dict[str, str]:
        path = self.config_dir / MANIFEST_NAME
        self.validate_target(path)
        if not path.exists():
            return {}
        if path.is_symlink() or not path.is_file():
            raise ValueError(f"invalid managed asset manifest target: {path}")
        data = parse_json(path)
        assets = data.get("assets", {})
        if not isinstance(assets, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in assets.items()):
            raise ValueError(f"invalid managed asset manifest: {path}")
        return assets

    def install_assets(self) -> None:
        previous = self.load_manifest()
        managed = dict(previous)
        source_root = self.kit / "opencode-global"
        seen: set[str] = set()
        for directory in ASSET_DIRS:
            source_dir = source_root / directory
            if not source_dir.is_dir():
                continue
            if source_dir.is_symlink() or source_dir.resolve(strict=True).parent != source_root.resolve(strict=True):
                raise ValueError(f"refusing unsafe OPK asset directory: {source_dir}")
            for source in sorted(path for path in source_dir.rglob("*") if path.is_file()):
                if source.is_symlink() or source.resolve(strict=True) != source:
                    raise ValueError(f"refusing symlinked OPK asset: {source}")
                relative = source.relative_to(source_root).as_posix()
                seen.add(relative)
                destination = self.config_dir / relative
                self.validate_target(destination)
                source_hash = sha256(source)
                if destination.exists():
                    if destination.is_symlink() or not destination.is_file():
                        raise ValueError(f"refusing non-regular asset target: {destination}")
                    current_hash = sha256(destination)
                    if relative not in previous:
                        print(f"WARN: preserving custom asset collision: {destination}")
                        continue
                    if current_hash != previous[relative]:
                        print(f"WARN: preserving modified managed asset: {destination}")
                        continue
                    if current_hash == source_hash:
                        managed[relative] = source_hash
                        continue
                    self.backup(destination)
                self.atomic_bytes(destination, source.read_bytes(), source.stat().st_mode & 0o777)
                managed[relative] = source_hash

        for relative in sorted(set(previous) - seen):
            print(f"WARN: source asset removed; preserving installed file and dropping manifest entry: {relative}")
            managed.pop(relative, None)

        manifest = self.config_dir / MANIFEST_NAME
        content = json.dumps({"version": 1, "assets": dict(sorted(managed.items()))}, indent=2) + "\n"
        if manifest.exists() and manifest.read_text(encoding="utf-8") == content:
            return
        self.backup(manifest)
        self.atomic_text(manifest, content)

    @staticmethod
    def marker_block(name: str, content: str, newline: str = "\n") -> str:
        return f"# >>> {name}{newline}{content}{newline}# <<< {name}"

    def update_marker(self, path: Path, name: str, content: str) -> None:
        self.validate_target(path)
        existing = path.read_text(encoding="utf-8") if path.exists() else ""
        start = f"# >>> {name}"
        end = f"# <<< {name}"
        newline = "\r\n" if "\r\n" in existing else "\n"
        block = self.marker_block(name, content, newline)
        if existing.count(start) != existing.count(end) or existing.count(start) > 1:
            raise ValueError(f"malformed managed marker in {path}: {name}")
        if start in existing:
            before, remainder = existing.split(start, 1)
            _, after = remainder.split(end, 1)
            updated = before + block + after
        else:
            separator = "" if not existing else ("" if existing.endswith(newline + newline) else newline)
            updated = existing + separator + block + newline
        if updated == existing:
            return
        self.backup(path)
        self.atomic_text(path, updated)

    def update_shell_files(self) -> None:
        shell_files = [self.home / ".bashrc"]
        zshrc = self.home / ".zshrc"
        if zshrc.exists() or os.environ.get("SHELL", "").endswith("/zsh"):
            shell_files.append(zshrc)
        kit_export = f'export OPK_KIT_DIR="{self.kit}"'
        path_export = 'export PATH="$HOME/.local/bin:$PATH"'
        for path in shell_files:
            if path.exists() and (path.is_symlink() or not path.is_file()):
                raise ValueError(f"refusing unsafe shell rc: {path}")
            existing = path.read_text(encoding="utf-8") if path.exists() else ""
            outside = existing
            start = f"# >>> {GLOBAL_MARKER}"
            end = f"# <<< {GLOBAL_MARKER}"
            if start in outside and end in outside:
                before, rest = outside.split(start, 1)
                _, after = rest.split(end, 1)
                outside = before + after
            if "OPENCODE_CONFIG_DIR=" in outside:
                print(f"WARN: custom OPENCODE_CONFIG_DIR outside OPK marker remains in {path}")
            self.update_marker(path, GLOBAL_MARKER, kit_export)
            self.update_marker(path, PATH_MARKER, path_export)

    def install_shim(self) -> None:
        path = self.home / ".local" / "bin" / "opk"
        content = (
            "#!/usr/bin/env bash\n"
            f"{SHIM_MARKER}\n"
            f'export OPK_KIT_DIR="{self.kit}"\n'
            'exec "$OPK_KIT_DIR/bin/opk" "$@"\n'
        )
        if path.exists():
            if path.is_symlink() or not path.is_file():
                raise ValueError(f"refusing unsafe opk shim target: {path}")
            existing = path.read_text(encoding="utf-8")
            if SHIM_MARKER not in existing:
                print(f"WARN: preserving custom executable: {path}")
                return
            if existing == content:
                return
            self.backup(path)
        self.atomic_text(path, content, 0o755)

    def run(self) -> None:
        self.ensure_dir(self.config_dir)
        if self.dry_run:
            self.merge_config()
            self.install_assets()
            self.update_shell_files()
            self.install_shim()
        else:
            lock_descriptor = self.acquire_lock()
            try:
                try:
                    self.merge_config()
                    self.install_assets()
                    self.update_shell_files()
                    self.install_shim()
                except Exception as error:
                    try:
                        self.rollback()
                    except Exception as rollback_error:
                        raise RuntimeError(f"install failed: {error}; {rollback_error}") from error
                    raise RuntimeError(f"install failed; published files restored: {error}") from error
            finally:
                os.close(lock_descriptor)
        self.originals.clear()
        active = self._discover_global_config()
        config_path = active if active else self.config_dir / "opencode.json"
        print(f"Global config: {config_path}")
        print(f"Managed assets: {self.config_dir / MANIFEST_NAME}")
        print("Optional UI skill: opk taste install")
        if self.backup_created:
            print(f"Backup: {self.backup_dir}")
        if os.environ.get("OPENCODE_CONFIG_DIR"):
            print("WARN: current shell still has OPENCODE_CONFIG_DIR set; open a new shell or unset it")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kit-dir", required=True)
    parser.add_argument("--mode", choices=("power", "safe"))
    parser.add_argument("--yes", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--normalize-jsonc", action="store_true")
    args = parser.parse_args()
    try:
        kit = Path(args.kit_dir).absolute()
        home = Path(os.environ["HOME"]).absolute()
        if kit.is_symlink() or kit.resolve(strict=True) != kit:
            raise ValueError(f"kit path contains a symlink: {kit}")
        Installer(kit, home, args.mode, args.dry_run, args.normalize_jsonc).run()
    except Exception as error:
        print(f"install-global: ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
