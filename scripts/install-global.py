#!/usr/bin/env python3
"""Install OPK assets into OpenCode's default global config directory."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

MANIFEST_NAME = ".opk-managed-assets.json"
SHIM_MARKER = "# @opk-managed-shim"
GLOBAL_MARKER = "opencode-power-kit-global"
PATH_MARKER = "opencode-power-kit-path"
ASSET_DIRS = ("agents", "commands", "skills", "plugins")


def strip_jsonc(text: str) -> str:
    result: list[str] = []
    index = 0
    in_string = in_line = in_block = False
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
            index += 2
        elif char == "/" and following == "*":
            in_block = True
            index += 2
        else:
            result.append(char)
            index += 1
    if in_string or in_block:
        raise ValueError("unterminated JSONC string or comment")
    return "".join(result)


def parse_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(strip_jsonc(path.read_text(encoding="utf-8")))
    except Exception as error:
        raise ValueError(f"cannot parse {path}: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"JSON root must be an object: {path}")
    return value


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
    def __init__(self, kit: Path, home: Path, mode: str | None, dry_run: bool) -> None:
        self.kit = kit
        self.home = home
        self.mode = mode
        self.dry_run = dry_run
        self.config_dir = home / ".config" / "opencode"
        self.backup_dir = home / f".opencode-power-kit-backup-{self.stamp()}"
        self.backup_created = False

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
        descriptor = -1
        temporary = ""
        try:
            descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.tmp.", dir=path.parent)
            os.fchmod(descriptor, mode)
            with os.fdopen(descriptor, "wb") as handle:
                descriptor = -1
                handle.write(content)
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

    def atomic_text(self, path: Path, content: str, mode: int = 0o644) -> None:
        self.atomic_bytes(path, content.encode("utf-8"), mode)

    def merge_config(self) -> None:
        target = self.config_dir / "opencode.json"
        self.validate_target(target)
        if target.exists() and not target.is_file():
            raise ValueError(f"global config is not a regular file: {target}")
        current = parse_json(target) if target.exists() else {}
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
        self.backup(target)
        self.atomic_text(target, serialized)

    def load_manifest(self) -> dict[str, str]:
        path = self.config_dir / MANIFEST_NAME
        if not path.exists():
            return {}
        data = parse_json(path)
        assets = data.get("assets", {})
        if not isinstance(assets, dict) or not all(isinstance(k, str) and isinstance(v, str) for k, v in assets.items()):
            raise ValueError(f"invalid managed asset manifest: {path}")
        return assets

    def install_assets(self) -> None:
        previous = self.load_manifest()
        managed = dict(previous)
        source_root = self.kit / "opencode-global"
        for directory in ASSET_DIRS:
            source_dir = source_root / directory
            if not source_dir.is_dir():
                continue
            for source in sorted(path for path in source_dir.rglob("*") if path.is_file()):
                if source.is_symlink() or source.resolve(strict=True) != source:
                    raise ValueError(f"refusing symlinked OPK asset: {source}")
                relative = source.relative_to(source_root).as_posix()
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

        manifest = self.config_dir / MANIFEST_NAME
        content = json.dumps({"version": 1, "assets": dict(sorted(managed.items()))}, indent=2) + "\n"
        if manifest.exists() and manifest.read_text(encoding="utf-8") == content:
            return
        self.backup(manifest)
        self.atomic_text(manifest, content)

    @staticmethod
    def marker_block(name: str, content: str) -> str:
        return f"# >>> {name}\n{content}\n# <<< {name}"

    def update_marker(self, path: Path, name: str, content: str) -> None:
        self.validate_target(path)
        existing = path.read_text(encoding="utf-8") if path.exists() else ""
        start = f"# >>> {name}"
        end = f"# <<< {name}"
        block = self.marker_block(name, content)
        if (start in existing) != (end in existing):
            raise ValueError(f"malformed managed marker in {path}: {name}")
        if start in existing:
            before, remainder = existing.split(start, 1)
            _, after = remainder.split(end, 1)
            updated = before + block + after
        else:
            separator = "" if not existing else ("" if existing.endswith("\n\n") else "\n")
            updated = existing + separator + block + "\n"
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
        self.merge_config()
        self.install_assets()
        self.update_shell_files()
        self.install_shim()
        print(f"Global config: {self.config_dir / 'opencode.json'}")
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
    args = parser.parse_args()
    try:
        kit = Path(args.kit_dir).absolute()
        home = Path(os.environ["HOME"]).absolute()
        if kit.is_symlink() or kit.resolve(strict=True) != kit:
            raise ValueError(f"kit path contains a symlink: {kit}")
        Installer(kit, home, args.mode, args.dry_run).run()
    except Exception as error:
        print(f"install-global: ERROR: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
