#!/usr/bin/env python3
# ============================================================================
# OpenCode Power Kit - Pack validator
# Kiểm tra cấu trúc:
#   - opencode-global/commands/*.md phải có frontmatter + description
#   - opencode-global/agents/*.md phải có frontmatter + description + mode
#   - opencode-global/skills/*/SKILL.md phải có heading và nội dung
#   - profiles/*/commands/*.md phải có frontmatter + description
#   - profiles/*/skills/*/SKILL.md phải có heading và nội dung
#   - templates/openapi/*.example phải tồn tại (nếu openapi dir tồn tại)
# Exit code 0 nếu pass, 1 nếu fail.
# ============================================================================
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

KIT_ROOT = Path(__file__).resolve().parent.parent
GLOBAL_DIR = KIT_ROOT / "opencode-global"
PROFILES_DIR = KIT_ROOT / "profiles"
TEMPLATES_DIR = KIT_ROOT / "templates"


def die(msg: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"[FAIL] {msg}", file=sys.stderr)
    sys.exit(1)


def ok(msg: str) -> None:
    print(f"  ok: {msg}")


def parse_frontmatter(text: str) -> dict | None:
    """Return frontmatter as dict, or None if missing/malformed."""
    if not text.startswith("---"):
        return None
    # Find the closing fence.
    end = text.find("\n---", 3)
    if end < 0:
        return None
    block = text[3:end].strip()
    out: dict[str, str] = {}
    for line in block.splitlines():
        line = line.rstrip()
        if not line or ":" not in line:
            continue
        key, _, value = line.partition(":")
        out[key.strip()] = value.strip()
    return out


def validate_commands(commands_dir: Path) -> list[str]:
    errors: list[str] = []
    if not commands_dir.is_dir():
        errors.append(f"missing dir: {commands_dir}")
        return errors
    files = sorted(commands_dir.glob("*.md"))
    if not files:
        errors.append(f"no commands in {commands_dir}")
    for f in files:
        try:
            text = f.read_text(encoding="utf-8")
        except OSError as e:
            errors.append(f"{f.name}: read error {e}")
            continue
        fm = parse_frontmatter(text)
        if fm is None:
            errors.append(f"commands/{f.name}: missing or malformed frontmatter")
            continue
        if "description" not in fm or not fm["description"]:
            errors.append(f"commands/{f.name}: missing 'description' in frontmatter")
        else:
            ok(f"commands/{f.name}: description ok")
    return errors


def validate_agents(agents_dir: Path) -> list[str]:
    errors: list[str] = []
    if not agents_dir.is_dir():
        errors.append(f"missing dir: {agents_dir}")
        return errors
    files = sorted(agents_dir.glob("*.md"))
    if not files:
        errors.append(f"no agents in {agents_dir}")
    for f in files:
        try:
            text = f.read_text(encoding="utf-8")
        except OSError as e:
            errors.append(f"{f.name}: read error {e}")
            continue
        fm = parse_frontmatter(text)
        if fm is None:
            errors.append(f"agents/{f.name}: missing or malformed frontmatter")
            continue
        missing = [k for k in ("description", "mode") if k not in fm or not fm[k]]
        if missing:
            errors.append(f"agents/{f.name}: missing frontmatter keys: {', '.join(missing)}")
        else:
            ok(f"agents/{f.name}: description+mode ok")
    return errors


def validate_skills(skills_dir: Path) -> list[str]:
    errors: list[str] = []
    if not skills_dir.is_dir():
        errors.append(f"missing dir: {skills_dir}")
        return errors
    skill_dirs = sorted([d for d in skills_dir.iterdir() if d.is_dir()])
    if not skill_dirs:
        errors.append(f"no skills in {skills_dir}")
    for d in skill_dirs:
        skill_file = d / "SKILL.md"
        if not skill_file.is_file():
            errors.append(f"skills/{d.name}/SKILL.md: missing")
            continue
        try:
            text = skill_file.read_text(encoding="utf-8")
        except OSError as e:
            errors.append(f"skills/{d.name}/SKILL.md: read error {e}")
            continue
        # Must have at least one markdown heading.
        if not re.search(r"^#\s+\S+", text, re.MULTILINE):
            errors.append(f"skills/{d.name}/SKILL.md: no top-level heading")
            continue
        # Body must contain more than the heading.
        non_empty = [ln for ln in text.splitlines() if ln.strip()]
        if len(non_empty) < 3:
            errors.append(f"skills/{d.name}/SKILL.md: body too short")
            continue
        ok(f"skills/{d.name}/SKILL.md: heading + body ok")
    return errors


def validate_profile(profile_dir: Path) -> list[str]:
    """Validate a single profile: commands/, skills/, README.md optional."""
    errors: list[str] = []
    name = profile_dir.name
    print(f"[profile: {name}]")

    # commands
    cmds_dir = profile_dir / "commands"
    if cmds_dir.is_dir():
        errors += validate_commands(cmds_dir)
    else:
        ok(f"profile/{name}/commands/ not present (optional)")

    # skills
    skills_dir = profile_dir / "skills"
    if skills_dir.is_dir():
        errors += validate_skills(skills_dir)
    else:
        ok(f"profile/{name}/skills/ not present (optional)")

    return errors


def validate_openapi_templates() -> list[str]:
    errors: list[str] = []
    openapi_dir = TEMPLATES_DIR / "openapi"
    if not openapi_dir.is_dir():
        ok("templates/openapi/ not present (optional)")
        return errors
    examples = sorted(openapi_dir.glob("*.example"))
    if not examples:
        errors.append(f"templates/openapi/ exists but no *.example files")
        return errors
    for f in examples:
        if f.is_file() and f.stat().st_size > 0:
            ok(f"templates/openapi/{f.name} present and non-empty")
        else:
            errors.append(f"templates/openapi/{f.name} empty or not a file")
    return errors


def main() -> int:
    if not GLOBAL_DIR.is_dir():
        die(f"opencode-global not found at {GLOBAL_DIR}")
    print(f"Validating opencode pack in: {KIT_ROOT}")
    errors: list[str] = []
    print("[opencode-global/commands]")
    errors += validate_commands(GLOBAL_DIR / "commands")
    print("[opencode-global/agents]")
    errors += validate_agents(GLOBAL_DIR / "agents")
    print("[opencode-global/skills]")
    errors += validate_skills(GLOBAL_DIR / "skills")

    if PROFILES_DIR.is_dir():
        profile_dirs = sorted([d for d in PROFILES_DIR.iterdir() if d.is_dir()])
        for p in profile_dirs:
            errors += validate_profile(p)
    else:
        ok("profiles/ not present (optional)")

    print("[templates/openapi]")
    errors += validate_openapi_templates()

    if errors:
        print("\nPack validation FAILED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("\nPack validation: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
