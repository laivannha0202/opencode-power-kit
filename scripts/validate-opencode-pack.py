#!/usr/bin/env python3
# ============================================================================
# OpenCode Power Kit - Pack validator
# opencode-power-kit v1.6.0
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
# v1.4.0 bổ sung:
#   - VERSION pin = "1.4.0"
#   - CHANGELOG.md chứa thêm needle build-strong / Fullstack-Autopilot
#   - opencode-global/agents/build-strong.md chứa Fullstack-Autopilot /
#     Hard Rules / vertical slice / cleanup-safe
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

# ─── version compliance constants ───────────────────────────────────
EXPECTED_VERSION = "1.6.0"

AUTO_ROUTER_NEEDLES: tuple[tuple[str, str], ...] = (
    ("templates/AGENTS.md", "Natural Language Auto Router"),
    ("templates/OPENCODE.md", "Natural Language Auto Router"),
)

CHANGELOG_NEEDLES: tuple[str, ...] = (
    "1.3.3",
    "1.3.4",
    "1.4.0",
    "1.5.0",
    "1.6.0",
    "cleanup-safe",
    "handoff-save",
    "checkpoint",
    "Natural Language Auto Router",
    "Backward compatible",
    "GSD Core",
    "build-strong",
    "Fullstack-Autopilot",
    "Power Mode",
    "architect-strong",
    "opk-command-guard",
    "Full Auto Permission Mode",
    "Vietnamese Language Lock",
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


# ─── version compliance section ─────────────────────────────────────
def validate_version() -> list[str]:
    """Release invariants for current EXPECTED_VERSION. Returns list of error messages."""
    errors: list[str] = []

    # VERSION file pin
    print(f"[VERSION == {EXPECTED_VERSION}]")
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

    # Optional hint files (warn-only, do not fail on missing)
    print("[hint files (optional, warn-only)]")
    for rel in V134_HINT_FILES:
        p = KIT_ROOT / rel
        if p.is_file():
            ok(f"present: {rel}")
        else:
            print(f"  warn: missing optional file: {rel}")

    # Natural Language Auto Router presence
    print("[Natural Language Auto Router]")
    for rel, needle in AUTO_ROUTER_NEEDLES:
        p = KIT_ROOT / rel
        if p.is_file() and needle in p.read_text(encoding="utf-8"):
            ok(f"{rel} contains: {needle}")
        else:
            errors.append(f"{rel} missing needle: {needle}")

    # CHANGELOG needles
    print("[CHANGELOG invariants]")
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
    print("[THIRD_PARTY.md invariants]")
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

    # v1.6.0: Full Auto Permission Mode check
    print("[Full Auto Permission Mode]")
    opencode_json = KIT_ROOT / "templates" / "opencode.json"
    if opencode_json.is_file():
        json_text = opencode_json.read_text(encoding="utf-8")
        if '"permission": "allow"' in json_text:
            ok("templates/opencode.json has permission: allow")
        else:
            errors.append("templates/opencode.json missing 'permission': 'allow'")
    else:
        errors.append("templates/opencode.json missing")

    # v1.6.0: Vietnamese Language Lock
    print("[Vietnamese Language Lock]")
    for rel, needle in (
        ("templates/AGENTS.md", "Vietnamese Language Lock"),
        ("templates/AGENTS.md", "Full Auto Permission Mode"),
        ("templates/OPENCODE.md", "Vietnamese Language Lock"),
        ("templates/OPENCODE.md", "Full Auto Permission Mode"),
    ):
        p = KIT_ROOT / rel
        if p.is_file() and needle in p.read_text(encoding="utf-8"):
            ok(f"{rel} contains: {needle}")
        else:
            errors.append(f"{rel} missing needle: {needle}")

    # v1.6.0: docs/release notes
    print("[v1.6.0 release notes]")
    release_path = KIT_ROOT / "docs" / "releases" / "v1.6.0.md"
    if release_path.is_file():
        ok("docs/releases/v1.6.0.md exists")
    else:
        errors.append("docs/releases/v1.6.0.md missing")

    # build-strong.md content needles (v1.4.0 + v1.5.0)
    print("[build-strong agent content]")
    bs_path = GLOBAL_DIR / "agents" / "build-strong.md"
    if bs_path.is_file():
        bs_text = bs_path.read_text(encoding="utf-8")
        for needle in ("Fullstack-Autopilot", "Hard Rules", "Agent Delegation"):
            if needle in bs_text:
                ok(f"build-strong.md contains: {needle}")
            else:
                errors.append(f"build-strong.md missing needle: {needle}")
    else:
        errors.append("opencode-global/agents/build-strong.md missing")

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

    # THIRD_PARTY.md tooling policy section (v1.5.0)
    print("[THIRD_PARTY.md tooling policy]")
    tp = KIT_ROOT / "THIRD_PARTY.md"
    if tp.is_file():
        tp_text = tp.read_text(encoding="utf-8")
        for needle in ("Tooling Policy", "detect-only", "ast-grep"):
            if needle in tp_text:
                ok(f"THIRD_PARTY.md contains: {needle}")
            else:
                errors.append(f"THIRD_PARTY.md missing needle: {needle}")
    else:
        errors.append("THIRD_PARTY.md missing")

    # opk-command-guard.sh exists (v1.5.0)
    print("[opk-command-guard.sh]")
    guard_path = KIT_ROOT / "scripts" / "opk-command-guard.sh"
    if guard_path.is_file():
        ok("scripts/opk-command-guard.sh exists")
    else:
        errors.append("scripts/opk-command-guard.sh missing")

    # New agents check (v1.5.0)
    print("[v1.5.0 new agents]")
    agent_names = [
        "architect-strong", "debug-strong", "qa-strong",
        "security-strong", "db-strong", "api-strong",
        "ui-ux-strong", "devops-strong", "release-strong",
    ]
    agents_dir = GLOBAL_DIR / "agents"
    for name in agent_names:
        agent_file = agents_dir / f"{name}.md"
        if agent_file.is_file():
            ok(f"agents/{name}.md exists")
        else:
            errors.append(f"agents/{name}.md missing")

    # version compliance (VERSION, THIRD_PARTY, Auto Router, CHANGELOG needles, build-strong content)
    errors += validate_version()

    if errors:
        print("\nPack validation FAILED:", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1
    print("\nPack validation: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
