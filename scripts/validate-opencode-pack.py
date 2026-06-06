#!/usr/bin/env python3
# ============================================================================
# OpenCode Power Kit - Pack validator
# opencode-power-kit v1.3.4
#
# Kiểm tra cấu trúc:
#   - opencode-global/commands/*.md phải có frontmatter + description
#   - opencode-global/agents/*.md phải có frontmatter + description + mode
#   - opencode-global/skills/*/SKILL.md phải có heading và nội dung
#   - profiles/*/commands/*.md phải có frontmatter + description
#   - profiles/*/skills/*/SKILL.md phải có heading và nội dung
#   - templates/openapi/*.example phải tồn tại (nếu openapi dir tồn tại)
#
# v1.3.4 bổ sung:
#   - VERSION pin = "1.3.4"
#   - THIRD_PARTY.md tồn tại và reference BMAD / Superpowers / GSD Core
#   - CHANGELOG.md chứa các needle v1.3.3 / v1.3.4 / cleanup-safe /
#     handoff-save / checkpoint / Auto Router / GSD Core
#   - Natural Language Auto Router có mặt trong templates/AGENTS.md và
#     templates/OPENCODE.md
#
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

# ─── v1.3.4 compliance constants ────────────────────────────────────
EXPECTED_VERSION = "1.3.4"

AUTO_ROUTER_NEEDLES: tuple[tuple[str, str], ...] = (
    ("templates/AGENTS.md", "Natural Language Auto Router"),
    ("templates/OPENCODE.md", "Natural Language Auto Router"),
)

CHANGELOG_NEEDLES: tuple[str, ...] = (
    "1.3.3",
    "1.3.4",
    "cleanup-safe",
    "handoff-save",
    "checkpoint",
    "Natural Language Auto Router",
    "Backward compatible",
    "GSD Core",
)

THIRD_PARTY_NEEDLES: tuple[tuple[str, str], ...] = (
    ("THIRD_PARTY.md", "BMAD"),
    ("THIRD_PARTY.md", "Superpowers"),
    ("THIRD_PARTY.md", "GSD Core"),
)

V134_HINT_FILES: tuple[str, ...] = (
    "THIRD_PARTY.md",
    "scripts/install-gsd-core.sh",
    "scripts/install-gsd-core.ps1",
    ".github/workflows/verify.yml",
)


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


# ─── v1.3.4 compliance section ──────────────────────────────────────
def validate_v134() -> list[str]:
    """v1.3.4 release invariants. Returns list of error messages."""
    errors: list[str] = []

    # VERSION file pin
    print("[v1.3.4 VERSION]")
    version_path = KIT_ROOT / "VERSION"
    if version_path.is_file():
        current = version_path.read_text(encoding="utf-8").strip()
        if current == EXPECTED_VERSION:
            ok(f"VERSION == {EXPECTED_VERSION}")
        else:
            errors.append(
                f"VERSION is '{current}', expected '{EXPECTED_VERSION}'"
            )
    else:
        errors.append(f"VERSION file missing at {version_path}")

    # Optional v1.3.4 hint files (warn-only, do not fail on missing)
    print("[v1.3.4 hint files (optional, warn-only)]")
    for rel in V134_HINT_FILES:
        p = KIT_ROOT / rel
        if p.is_file():
            ok(f"present: {rel}")
        else:
            print(f"  warn: missing optional v1.3.4 file: {rel}")

    # Natural Language Auto Router presence
    print("[v1.3.4 Natural Language Auto Router]")
    for rel, needle in AUTO_ROUTER_NEEDLES:
        p = KIT_ROOT / rel
        if p.is_file() and needle in p.read_text(encoding="utf-8"):
            ok(f"{rel} contains: {needle}")
        else:
            errors.append(f"{rel} missing needle: {needle}")

    # CHANGELOG needles
    print("[v1.3.4 CHANGELOG invariants]")
    cl = KIT_ROOT / "CHANGELOG.md"
    if cl.is_file():
        text = cl.read_text(encoding="utf-8")
        text_lower = text.lower()
        for needle in CHANGELOG_NEEDLES:
            if needle.lower() in text_lower:
                ok(f"CHANGELOG.md contains: {needle}")
            else:
                errors.append(f"CHANGELOG.md missing needle: {needle}")
    else:
        errors.append("CHANGELOG.md missing")

    # THIRD_PARTY.md needles
    print("[v1.3.4 THIRD_PARTY.md invariants]")
    tp = KIT_ROOT / "THIRD_PARTY.md"
    if tp.is_file():
        text = tp.read_text(encoding="utf-8")
        text_lower = text.lower()
        for rel, needle in THIRD_PARTY_NEEDLES:
            if needle.lower() in text_lower:
                ok(f"{rel} contains: {needle}")
            else:
                errors.append(f"{rel} missing needle: {needle}")
    else:
        errors.append("THIRD_PARTY.md missing")

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

    # v1.3.4 release compliance (VERSION, THIRD_PARTY, Auto Router, CHANGELOG needles)
    errors += validate_v134()

    if errors:
        print("\nPack validation FAILED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("\nPack validation: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
