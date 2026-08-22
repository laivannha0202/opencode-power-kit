#!/usr/bin/env python3
"""Read-only diagnostics for effective OpenCode permissions."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))

# Single-source engine: classification semantics, deny contracts, and the
# permission rule helpers live in opk_mode.py; this CLI only adds I/O and
# reporting around them.
from opk_mode import (  # noqa: E402
    DESTRUCTIVE_RULES,
    OPTIONAL_ALLOW_KEYS,
    SECRET_RULES,
    action,
    classify,
    count_action,
    resolve_config_path,
)


def project_from_argument(raw: str) -> tuple[Path, int]:
    lexical = Path(raw).absolute()
    if lexical.is_symlink() or not lexical.exists() or not lexical.is_dir():
        raise ValueError(f"invalid project directory: {lexical}")
    resolved = lexical.resolve(strict=True)
    if resolved != lexical:
        raise ValueError(f"project path contains a symlink: {lexical}")
    descriptor = os.open(resolved, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    opened = os.fstat(descriptor)
    current = os.stat(resolved, follow_symlinks=False)
    if (opened.st_dev, opened.st_ino) != (current.st_dev, current.st_ino):
        os.close(descriptor)
        raise ValueError(f"project directory changed while resolving: {resolved}")
    return resolved, descriptor


def verify_project_identity(project: Path, descriptor: int) -> None:
    opened = os.fstat(descriptor)
    current = os.stat(project, follow_symlinks=False)
    if (opened.st_dev, opened.st_ino) != (current.st_dev, current.st_ino):
        raise ValueError(f"project directory changed after resolution: {project}")


def git_root(project: Path) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(project), "rev-parse", "--show-toplevel"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return result.stdout.strip() or None if result.returncode == 0 else None


def resolve_config(project: Path, descriptor: int) -> tuple[dict[str, Any] | None, str | None]:
    binary = shutil.which("opencode")
    if not binary:
        return None, "opencode is not installed"
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as output:
        try:
            verify_project_identity(project, descriptor)
            result = subprocess.run(
                [binary, "debug", "config", "--pure"],
                cwd=project,
                text=True,
                stdout=output,
                stderr=subprocess.PIPE,
                check=False,
                timeout=30,
            )
            verify_project_identity(project, descriptor)
        except subprocess.TimeoutExpired:
            return None, "opencode debug config timed out after 30 seconds"
        except (OSError, ValueError) as error:
            return None, str(error)
        output.seek(0)
        resolved_text = output.read()
    if result.returncode != 0:
        message = result.stderr.strip().splitlines()
        return None, message[-1] if message else f"opencode debug config exited {result.returncode}"
    try:
        value = json.loads(resolved_text)
    except json.JSONDecodeError as error:
        return None, f"resolved config is not JSON: {error}"
    if not isinstance(value, dict):
        return None, "resolved config root is not an object"
    return value, None


def auto_supported() -> bool:
    binary = shutil.which("opencode")
    if not binary:
        return False
    result = subprocess.run(
        [binary, "--help"], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False, timeout=10
    )
    return "--auto" in result.stdout


def opencode_version() -> str:
    binary = shutil.which("opencode")
    if not binary:
        return "not installed"
    result = subprocess.run([binary, "--version"], text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False)
    return result.stdout.strip() or "unknown"


def global_config_diagnostics() -> tuple[Path | None, bool, str | None]:
    """Report the standard global config without confusing custom env sources.

    OpenCode's standard global config lives under ~/.config/opencode and may
    use JSON or JSONC. OPENCODE_CONFIG and OPENCODE_CONFIG_DIR are separate
    custom sources and are reported independently by ``report``.
    """
    directory = Path.home() / ".config" / "opencode"
    default = directory / "opencode.json"
    try:
        active = resolve_config_path(directory, required=False)
    except ValueError as error:
        return None, False, str(error)
    if active is None:
        return default, False, None
    return active, True, None


def report(project: Path, descriptor: int, as_json: bool, require_power: bool) -> int:
    root_json = project / "opencode.json"
    root_jsonc = project / "opencode.jsonc"
    legacy = project / ".opencode" / "opencode.json"
    if root_json.is_symlink() or root_jsonc.is_symlink() or legacy.is_symlink():
        config, error = None, "config target is a symlink"
    elif root_json.exists() and root_jsonc.exists():
        config, error = None, "conflict: both opencode.json and opencode.jsonc exist"
    else:
        config, error = resolve_config(project, descriptor)
    active_root = root_json if root_json.exists() and not root_jsonc.exists() else (root_jsonc if root_jsonc.exists() else root_json)
    permission = config.get("permission", {}) if config else {}
    mode, details, validation_error = classify(config, error)
    error = error or validation_error
    conflicts = details.get("agent_override_conflicts", [])
    effective = details.get("effective", {})
    for key in OPTIONAL_ALLOW_KEYS:
        if isinstance(permission, dict) and key not in permission:
            effective[key] = "not_present"

    global_config, global_config_exists, global_config_error = global_config_diagnostics()
    custom_config = os.environ.get("OPENCODE_CONFIG", "") or None
    custom_config_dir = os.environ.get("OPENCODE_CONFIG_DIR", "") or None

    data = {
        "opencode_version": opencode_version(),
        "project_root": str(project),
        "git_root": git_root(project),
        "global_config": str(global_config) if global_config is not None else None,
        "global_config_exists": global_config_exists,
        "global_config_error": global_config_error,
        "custom_config": custom_config,
        "custom_config_dir": custom_config_dir,
        "project_config": str(active_root),
        "project_config_exists": active_root.is_file() and not active_root.is_symlink(),
        "legacy_config": str(legacy),
        "legacy_config_exists": legacy.exists(),
        "effective_permission": permission,
        "effective": effective,
        "agent_override_conflicts": conflicts,
        "agent_override_conflict_count": len(conflicts),
        "ask_count": details.get("global_ask_count", 0) + details.get("agent_ask_count", 0),
        "global_ask_count": details.get("global_ask_count", 0),
        "agent_ask_count": details.get("agent_ask_count", 0),
        "deny_count": count_action(permission, "deny"),
        "missing_secret_denies": details.get("missing_secret_denies", list(SECRET_RULES)),
        "missing_destructive_denies": details.get("missing_destructive_denies", list(DESTRUCTIVE_RULES)),
        "mode": mode,
        "auto_supported": auto_supported(),
        "environment": {
            "OPENCODE_CONFIG": os.environ.get("OPENCODE_CONFIG", "") or "unset",
            "OPENCODE_CONFIG_DIR": os.environ.get("OPENCODE_CONFIG_DIR", "") or "unset",
            "OPENCODE_CONFIG_CONTENT": "set" if os.environ.get("OPENCODE_CONFIG_CONTENT") else "unset",
        },
        "error": error,
    }
    if require_power:
        if mode == "POWER":
            return 0
        print(f"opk-permissions: Power contract failed for {project}: mode={mode}", file=sys.stderr)
        if error:
            print(f"opk-permissions: {error}", file=sys.stderr)
        return 1
    if as_json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return int(data["mode"] == "BROKEN")

    print(f"OpenCode version: {data['opencode_version']}")
    print(f"Project root: {project}")
    if data["global_config_error"]:
        print(f"Global config: conflict/unsafe ({data['global_config_error']})")
    else:
        print(
            f"Global config: {data['global_config']} "
            f"({'present' if data['global_config_exists'] else 'missing'})"
        )
    if data["custom_config"]:
        print(f"Custom config (OPENCODE_CONFIG): {data['custom_config']}")
    if data["custom_config_dir"]:
        print(f"Custom config dir (OPENCODE_CONFIG_DIR): {data['custom_config_dir']}")
    print(f"Project config: {active_root} ({'present' if data['project_config_exists'] else 'missing'})")
    print(f"Legacy config: {legacy} ({'present' if data['legacy_config_exists'] else 'absent'})")
    for key, value in data["effective"].items():
        print(f"Effective {key}: {value}")
    print(f"Agent override conflicts: {len(conflicts)}" + (f" ({', '.join(conflicts)})" if conflicts else ""))
    print(f"Ask rules: {data['ask_count']}")
    print(f"Deny rules: {data['deny_count']}")
    print(f"Mode: {data['mode']}")
    print(f"--auto support: {'yes' if data['auto_supported'] else 'no'}")
    for key, value in data["environment"].items():
        print(f"{key}: {value}")
    if custom_config_dir:
        print(
            "WARNING: OPENCODE_CONFIG_DIR adds a custom OpenCode config/assets "
            "directory that can override managed OPK assets."
        )
        print(
            "Remediation: unset OPENCODE_CONFIG_DIR if this override is not intentional."
        )
    if global_config_error:
        print(
            "WARNING: standard global config location is ambiguous/unsafe; "
            "keep exactly one regular opencode.json or opencode.jsonc."
        )
    if legacy.exists():
        print("Remediation: opk mode migrate")
    if data["mode"] != "POWER":
        print("Remediation: opk mode power")
    if error:
        print(f"Resolved config error: {error}")
    return int(data["mode"] == "BROKEN")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--project-dir", default=os.getcwd())
    parser.add_argument("--require-power", action="store_true")
    args = parser.parse_args()
    try:
        project, descriptor = project_from_argument(args.project_dir)
    except (OSError, ValueError) as error:
        print(f"opk-permissions: {error}", file=sys.stderr)
        return 1
    try:
        return report(project, descriptor, args.json, args.require_power)
    finally:
        os.close(descriptor)


if __name__ == "__main__":
    sys.exit(main())
