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


def project_root() -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return Path(result.stdout.strip()).resolve() if result.returncode == 0 else Path.cwd().resolve()


def resolve_config(project: Path) -> tuple[dict[str, Any] | None, str | None]:
    binary = shutil.which("opencode")
    if not binary:
        return None, "opencode is not installed"
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8") as output:
        result = subprocess.run(
            [binary, "debug", "config", "--pure"],
            cwd=project,
            text=True,
            stdout=output,
            stderr=subprocess.PIPE,
            check=False,
            timeout=30,
        )
        output.seek(0)
        resolved_text = output.read()
    if result.returncode != 0:
        message = result.stderr.strip().splitlines()
        return None, message[-1] if message else f"opencode debug config exited {result.returncode}"
    try:
        value = json.loads(resolved_text)
    except json.JSONDecodeError as error:
        return None, f"resolved config is not JSON: {error}"
    return value, None


def action(permission: Any, key: str) -> str:
    if isinstance(permission, str):
        return permission
    if not isinstance(permission, dict):
        return "allow"
    value = permission.get(key, permission.get("*", "allow"))
    if isinstance(value, str):
        return value
    if isinstance(value, dict):
        return str(value.get("*", "allow"))
    return "allow"


def count_action(value: Any, wanted: str) -> int:
    if isinstance(value, dict):
        return sum(count_action(child, wanted) for child in value.values())
    if isinstance(value, list):
        return sum(count_action(child, wanted) for child in value)
    return int(value == wanted)


def agent_conflicts(config: dict[str, Any]) -> list[str]:
    conflicts: list[str] = []
    for name, agent in config.get("agent", {}).items():
        if isinstance(agent, dict) and count_action(agent.get("permission", {}), "ask"):
            conflicts.append(name)
    return sorted(conflicts)


def mode_of(config: dict[str, Any] | None, error: str | None) -> str:
    if error or config is None:
        return "BROKEN"
    permission = config.get("permission", {})
    edit = action(permission, "edit")
    bash = action(permission, "bash")
    task = action(permission, "task")
    if edit == bash == task == "allow" and not agent_conflicts(config):
        return "POWER"
    if edit == "ask" and bash == "ask":
        return "SAFE"
    return "CUSTOM"


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


def report(as_json: bool) -> int:
    project = project_root()
    root = project / "opencode.json"
    legacy = project / ".opencode" / "opencode.json"
    config, error = resolve_config(project)
    permission = config.get("permission", {}) if config else {}
    conflicts = agent_conflicts(config) if config else []
    data = {
        "opencode_version": opencode_version(),
        "project_root": str(project),
        "global_config": str(Path.home() / ".config" / "opencode" / "opencode.json"),
        "project_config": str(root),
        "project_config_exists": root.is_file() and not root.is_symlink(),
        "legacy_config": str(legacy),
        "legacy_config_exists": legacy.exists(),
        "effective_permission": permission,
        "effective": {
            key: action(permission, key)
            for key in ("read", "edit", "bash", "task", "skill", "external_directory", "doom_loop")
        },
        "agent_override_conflicts": conflicts,
        "agent_override_conflict_count": len(conflicts),
        "ask_count": count_action(permission, "ask") + sum(
            count_action(agent.get("permission", {}), "ask")
            for agent in (config or {}).get("agent", {}).values()
            if isinstance(agent, dict)
        ),
        "deny_count": count_action(permission, "deny"),
        "mode": mode_of(config, error),
        "auto_supported": auto_supported(),
        "environment": {
            "OPENCODE_CONFIG": os.environ.get("OPENCODE_CONFIG", "") or "unset",
            "OPENCODE_CONFIG_DIR": os.environ.get("OPENCODE_CONFIG_DIR", "") or "unset",
            "OPENCODE_CONFIG_CONTENT": "set" if os.environ.get("OPENCODE_CONFIG_CONTENT") else "unset",
        },
        "error": error,
    }
    if as_json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return int(data["mode"] == "BROKEN")

    print(f"OpenCode version: {data['opencode_version']}")
    print(f"Project root: {project}")
    print(f"Global config: {data['global_config']}")
    print(f"Project config: {root} ({'present' if data['project_config_exists'] else 'missing'})")
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
    config_dir = os.environ.get("OPENCODE_CONFIG_DIR", "")
    if config_dir:
        print("WARNING: current shell overrides the default global asset directory.")
        print("Remediation: unset OPENCODE_CONFIG_DIR; open a new shell after running opk global.")
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
    args = parser.parse_args()
    return report(args.json)


if __name__ == "__main__":
    sys.exit(main())
