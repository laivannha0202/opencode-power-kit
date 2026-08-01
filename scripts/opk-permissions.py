#!/usr/bin/env python3
"""Read-only diagnostics for effective OpenCode permissions."""

from __future__ import annotations

import argparse
import fnmatch
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

VALID_ACTIONS = {"allow", "ask", "deny"}
POWER_ALLOW_KEYS = ("read", "edit", "bash", "task", "skill", "glob", "grep", "list", "lsp")
OPTIONAL_ALLOW_KEYS = ("webfetch", "websearch")
SECRET_RULES = {
    "*.env": "app.env",
    "*.env.*": "app.env.local",
    "*secret*": "project-secret.txt",
    "*private-key*": "project-private-key.txt",
    "*.pem": "certificate.pem",
    "*.key": "private.key",
}
DESTRUCTIVE_RULES = {
    "rm -rf*": "rm -rf build",
    "rm -fr*": "rm -fr build",
    "sudo rm -rf*": "sudo rm -rf build",
    "sudo rm -fr*": "sudo rm -fr build",
    "git reset --hard*": "git reset --hard HEAD",
    "git clean -f*": "git clean -fd",
    "git push --force*": "git push --force origin main",
    "git push -f*": "git push -f origin main",
    "*DROP TABLE*": "mysql -e DROP TABLE users",
    "*DROP DATABASE*": "mysql -e DROP DATABASE app",
    "*TRUNCATE*": "psql -c TRUNCATE users",
    "*DELETE FROM*": "psql -c DELETE FROM users",
    "curl *| *sh*": "curl https://example.invalid/install | sh",
    "curl *| *bash*": "curl https://example.invalid/install | bash",
    "wget *| *sh*": "wget https://example.invalid/install | sh",
    "wget *| *bash*": "wget https://example.invalid/install | bash",
}


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


def validate_action(value: Any, label: str) -> str:
    if not isinstance(value, str) or value not in VALID_ACTIONS:
        raise ValueError(f"invalid permission action for {label}")
    return value


def validate_rule_map(value: Any, label: str) -> dict[str, str]:
    if not isinstance(value, dict):
        raise ValueError(f"invalid permission rule map for {label}")
    result: dict[str, str] = {}
    for pattern, effect in value.items():
        if not isinstance(pattern, str):
            raise ValueError(f"invalid permission pattern for {label}")
        result[pattern] = validate_action(effect, f"{label}.{pattern}")
    return result


def action(permission: Any, key: str) -> str:
    if isinstance(permission, str):
        return validate_action(permission, "permission")
    if not isinstance(permission, dict):
        raise ValueError("resolved permission must be a string or object")
    fallback = permission.get("*", "ask")
    validate_action(fallback, "permission.*")
    value = permission.get(key, fallback)
    if isinstance(value, str):
        return validate_action(value, key)
    if isinstance(value, dict):
        rules = validate_rule_map(value, key)
        return rules.get("*", "ask")
    raise ValueError(f"invalid permission value for {key}")


def count_action(value: Any, wanted: str) -> int:
    if isinstance(value, dict):
        return sum(count_action(child, wanted) for child in value.values())
    if isinstance(value, list):
        return sum(count_action(child, wanted) for child in value)
    return int(value == wanted)


def agent_conflicts(config: dict[str, Any]) -> list[str]:
    conflicts: list[str] = []
    agents = config.get("agent", {})
    if not isinstance(agents, dict):
        raise ValueError("resolved agent config must be an object")
    for name, agent in agents.items():
        if not isinstance(name, str) or not isinstance(agent, dict):
            raise ValueError("resolved agent entry is invalid")
        agent_permission = agent.get("permission", {})
        if not isinstance(agent_permission, (str, dict)):
            raise ValueError(f"invalid permission for agent {name}")
        if count_action(agent_permission, "ask"):
            conflicts.append(name)
    return sorted(conflicts)


def wildcard_match(value: str, pattern: str) -> bool:
    return fnmatch.fnmatchcase(value.replace("\\", "/"), pattern.replace("\\", "/"))


def evaluate_rules(rules: dict[str, str], resource: str) -> str:
    effect = "ask"
    for pattern, candidate in rules.items():
        if wildcard_match(resource, pattern):
            effect = candidate
    return effect


def representative(pattern: str) -> str:
    return pattern.replace("*", "x").replace("?", "x")


def deny_contract(permission: Any, key: str, required: dict[str, str]) -> tuple[bool, list[str]]:
    if not isinstance(permission, dict) or not isinstance(permission.get(key), dict):
        return False, list(required)
    rules = validate_rule_map(permission[key], key)
    missing = [
        pattern
        for pattern, sample in required.items()
        if rules.get(pattern) != "deny" or evaluate_rules(rules, sample) != "deny"
    ]
    positions = {pattern: index for index, pattern in enumerate(rules)}
    present_positions = [positions[pattern] for pattern in required if pattern in positions]
    if present_positions:
        first_deny = min(present_positions)
        missing.extend(
            f"late non-deny rule: {pattern}"
            for index, (pattern, effect) in enumerate(rules.items())
            if index > first_deny
            and effect != "deny"
            and any(wildcard_match(representative(pattern), required_pattern) for required_pattern in required)
        )
    return not missing, missing


def classify(config: dict[str, Any] | None, error: str | None) -> tuple[str, dict[str, Any], str | None]:
    if error or config is None:
        return "BROKEN", {}, error
    try:
        permission = config.get("permission", {})
        if not isinstance(permission, (str, dict)):
            raise ValueError("resolved permission must be a string or object")
        effective = {key: action(permission, key) for key in (*POWER_ALLOW_KEYS, *OPTIONAL_ALLOW_KEYS, "external_directory", "doom_loop")}
        conflicts = agent_conflicts(config)
        agent_asks = sum(
            count_action(agent.get("permission", {}), "ask")
            for agent in config.get("agent", {}).values()
            if isinstance(agent, dict)
        )
        global_asks = count_action(permission, "ask")
        secret_ok, missing_secret = deny_contract(permission, "read", SECRET_RULES)
        destructive_ok, missing_destructive = deny_contract(permission, "bash", DESTRUCTIVE_RULES)
        optional_ok = all(key not in permission or effective[key] == "allow" for key in OPTIONAL_ALLOW_KEYS) if isinstance(permission, dict) else False
        power = (
            all(effective[key] == "allow" for key in POWER_ALLOW_KEYS)
            and optional_ok
            and effective["external_directory"] == "deny"
            and effective["doom_loop"] == "deny"
            and global_asks == 0
            and not conflicts
            and secret_ok
            and destructive_ok
        )
        safe = (
            effective["edit"] == "ask"
            and effective["bash"] == "ask"
            and effective["external_directory"] == "deny"
            and effective["doom_loop"] == "deny"
            and secret_ok
            and destructive_ok
        )
        details = {
            "effective": effective,
            "agent_override_conflicts": conflicts,
            "agent_ask_count": agent_asks,
            "global_ask_count": global_asks,
            "missing_secret_denies": missing_secret,
            "missing_destructive_denies": missing_destructive,
        }
        return "POWER" if power else "SAFE" if safe else "CUSTOM", details, None
    except ValueError as validation_error:
        return "BROKEN", {}, str(validation_error)


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
    data = {
        "opencode_version": opencode_version(),
        "project_root": str(project),
        "git_root": git_root(project),
        "global_config": str(Path.home() / ".config" / "opencode" / "opencode.json"),
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
    print(f"Global config: {data['global_config']}")
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
