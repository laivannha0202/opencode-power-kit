#!/usr/bin/env python3
"""Transactional installer for the node-nest-react-mysql full-stack profile.

All project mutations go through opk_tx/opk_safe_io.  The installer refuses
symlink/hardlink targets, preserves existing user text around managed blocks,
and rolls back the whole profile install when a later operation fails.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import time
from pathlib import Path

import opk_safe_io as io
import opk_tx


KIT_DIR = Path(__file__).resolve().parent.parent
PROFILE_REL = "profiles/node-nest-react-mysql"
PROFILE_DIR = KIT_DIR / PROFILE_REL
LEGACY_BEGIN = "<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->"
LEGACY_END = "<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-end -->"
REPORT_REL = "FULLSTACK_PROFILE_REPORT.md"


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    raise RuntimeError(message)


def info(message: str) -> None:
    print(f"[INFO] {message}")


def ok(message: str) -> None:
    print(f"[OK] {message}")


def warn(message: str) -> None:
    print(f"[WARN] {message}", file=sys.stderr)


def validate_runtime(project_arg: str | None) -> str:
    if not sys.platform.startswith("linux"):
        fail("fullstack profile installer chỉ hỗ trợ Linux")

    if hasattr(os, "geteuid") and os.geteuid() == 0 and os.environ.get("OPK_TEST_MODE") != "1":
        fail("Không chạy với sudo/root.")

    raw = Path(project_arg).expanduser() if project_arg else Path.cwd()
    if not raw.exists() or not raw.is_dir():
        fail(f"project directory không tồn tại: {raw}")

    project = io.canonical_root(str(raw))
    home = os.path.realpath(os.path.expanduser("~"))
    kit = os.path.realpath(str(KIT_DIR))

    if project in ("/", home):
        fail(f"Không chạy fullstack installer trong HOME/root: {project}")

    if project == kit or project.startswith(kit + os.sep):
        allowed = (
            project == os.path.join(kit, ".tmp")
            or project.startswith(os.path.join(kit, ".tmp") + os.sep)
            or project == os.path.join(kit, ".test")
            or project.startswith(os.path.join(kit, ".test") + os.sep)
        )
        if not allowed:
            fail(f"Không chạy fullstack installer trong chính OPK kit: {project}")

    if PROFILE_DIR.is_symlink() or not PROFILE_DIR.is_dir():
        fail(f"profile source missing/unsafe: {PROFILE_DIR}")

    return project


def validate_source_tree(path: Path) -> None:
    root_real = KIT_DIR.resolve(strict=True)
    for candidate in [path, *path.rglob("*")]:
        if candidate.is_symlink():
            fail(f"refusing symlinked profile source: {candidate}")
        resolved = candidate.resolve(strict=True)
        if resolved != root_real and root_real not in resolved.parents:
            fail(f"profile source escapes kit: {candidate}")
        if candidate.is_file() and not candidate.stat().st_mode:
            fail(f"invalid source file: {candidate}")


def tx_stage(root: str, txid: str, lease: str, kind: str, rel: str, **kwargs):
    return opk_tx.stage(
        root,
        txid,
        kind,
        rel,
        lease=lease,
        **kwargs,
    )


def ensure_dir(root: str, txid: str, lease: str, rel: str) -> None:
    state = io.check(root, rel)
    if state["exists"]:
        if state["is_symlink"] or not state["is_dir"]:
            fail(f"unsafe/non-directory destination: {rel}")
        return
    tx_stage(root, txid, lease, "MKDIR", rel)


def read_optional(root: str, rel: str) -> str | None:
    state = io.check(root, rel)
    if not state["exists"]:
        return None
    if state["is_symlink"] or not state["is_reg"]:
        fail(f"unsafe/non-regular target: {rel}")
    return io.safe_read(root, rel).decode("utf-8")


def merge_managed_append(existing: str | None, source: str, rel: str) -> str:
    if source.count(LEGACY_BEGIN) != 1 or source.count(LEGACY_END) != 1:
        fail(f"profile source markers malformed: {rel}")

    if existing is None:
        return source if source.endswith("\n") else source + "\n"

    begin_count = existing.count(LEGACY_BEGIN)
    end_count = existing.count(LEGACY_END)
    if begin_count != end_count or begin_count > 1:
        fail(f"managed marker malformed in target: {rel}")

    if begin_count == 1:
        start = existing.index(LEGACY_BEGIN)
        end = existing.index(LEGACY_END, start) + len(LEGACY_END)
        merged = existing[:start] + source.rstrip("\n") + existing[end:]
        return merged if merged.endswith("\n") else merged + "\n"

    prefix = existing.rstrip("\n")
    if prefix:
        return prefix + "\n\n" + source.rstrip("\n") + "\n"
    return source if source.endswith("\n") else source + "\n"


def install_append(
    root: str,
    txid: str,
    lease: str,
    source_rel: str,
    target_rel: str,
) -> str:
    source = io.safe_read(str(KIT_DIR), source_rel).decode("utf-8")
    existing = read_optional(root, target_rel)
    merged = merge_managed_append(existing, source, target_rel)
    if existing == merged:
        ok(f"{target_rel}: managed block already current")
        return "unchanged"
    tx_stage(root, txid, lease, "REPLACE", target_rel, text=merged)
    ok(f"{target_rel}: managed block installed/updated")
    return "updated" if existing is not None else "created"


def install_commands(root: str, txid: str, lease: str) -> int:
    source_dir = PROFILE_DIR / "commands"
    if not source_dir.is_dir():
        warn(f"commands source missing: {source_dir}")
        return 0

    ensure_dir(root, txid, lease, ".opencode")
    ensure_dir(root, txid, lease, ".opencode/commands")
    ensure_dir(root, txid, lease, ".opencode/commands/fullstack")

    count = 0
    for source in sorted(source_dir.glob("*.md")):
        if source.is_symlink() or not source.is_file():
            fail(f"unsafe command source: {source}")
        source_rel = source.relative_to(KIT_DIR).as_posix()
        target_rel = f".opencode/commands/fullstack/{source.name}"
        tx_stage(
            root,
            txid,
            lease,
            "REPLACE",
            target_rel,
            src_root=str(KIT_DIR),
            src_rel=source_rel,
        )
        ok(f"command: {target_rel}")
        count += 1
    return count


def install_one_skill(
    root: str,
    txid: str,
    lease: str,
    source_dir: Path,
) -> bool:
    name = source_dir.name
    target_root = f".agents/skills/{name}"
    state = io.check(root, target_root)

    if state["exists"]:
        if state["is_symlink"] or not state["is_dir"]:
            fail(f"unsafe skill destination: {target_root}")
        warn(f"skill {name} đã tồn tại — preserve/skip")
        return False

    ensure_dir(root, txid, lease, target_root)

    entries = sorted(
        source_dir.rglob("*"),
        key=lambda p: (len(p.relative_to(source_dir).parts), p.as_posix()),
    )
    for source in entries:
        if source.is_symlink():
            fail(f"refusing symlinked skill source: {source}")
        relative_inside = source.relative_to(source_dir)
        target_rel = f"{target_root}/{relative_inside.as_posix()}"

        if source.is_dir():
            ensure_dir(root, txid, lease, target_rel)
            continue

        if not source.is_file():
            fail(f"unsupported skill source entry: {source}")

        source_rel = source.relative_to(KIT_DIR).as_posix()
        tx_stage(
            root,
            txid,
            lease,
            "CREATE",
            target_rel,
            require_absent=True,
            src_root=str(KIT_DIR),
            src_rel=source_rel,
        )

    ok(f"skill: {target_root}")
    return True


def install_skills(root: str, txid: str, lease: str) -> int:
    source_root = PROFILE_DIR / "skills"
    if not source_root.is_dir():
        warn(f"skills source missing: {source_root}")
        return 0

    ensure_dir(root, txid, lease, ".agents")
    ensure_dir(root, txid, lease, ".agents/skills")

    count = 0
    for source_dir in sorted(p for p in source_root.iterdir() if p.is_dir()):
        if source_dir.is_symlink():
            fail(f"refusing symlinked skill source: {source_dir}")
        if install_one_skill(root, txid, lease, source_dir):
            count += 1
    return count


def report_text(
    root: str,
    txid: str,
    agents_action: str,
    opencode_action: str,
    command_count: int,
    skill_count: int,
) -> str:
    return f"""# Full-Stack Profile Install Report

- **Thời gian:** {time.strftime("%Y-%m-%d %H:%M:%S")}
- **Project:** {root}
- **Kit:** {KIT_DIR}
- **Profile:** {PROFILE_DIR}
- **Transaction:** {txid}

## Managed instructions

| File | Action |
|------|--------|
| AGENTS.md | {agents_action} |
| OPENCODE.md | {opencode_action} |

## Runtime assets

- Commands installed/updated: {command_count}
- New skills installed: {skill_count}
- Existing skill directories are preserved and skipped.

## Safety

- Project writes use `opk_tx.py` + `opk_safe_io.py`.
- Symlink and hardlink mutation targets are refused.
- A failure before commit rolls back previously applied operations.
- No direct `cp`, `cp -r`, `cat >>`, or shell redirection is used for project writes.

## Recovery metadata

Transaction journal:
`.opk-state/transactions/{txid}/`

## Bước tiếp theo

1. Đọc phần managed trong `AGENTS.md` / `OPENCODE.md`.
2. Chạy `/fullstack-scan`.
3. Chạy `/env-doctor` và `/docker-dev-doctor` nếu project dùng Docker.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-dir")
    parser.add_argument("--yes", action="store_true")
    args = parser.parse_args()

    txid: str | None = None
    lease = f"fullstack-{os.getpid()}-{time.time_ns()}"

    try:
        root = validate_runtime(args.project_dir)
        validate_source_tree(PROFILE_DIR)

        if not os.path.isfile(os.path.join(root, "package.json")) and not os.path.isdir(
            os.path.join(root, ".git")
        ):
            warn("Project không có package.json hoặc .git.")
            if not args.yes:
                reply = input("Tiếp tục? [y/N] ").strip().lower()
                if reply not in ("y", "yes"):
                    print("Đã hủy.")
                    return 0

        info(f"Project: {root}")
        info(f"Profile: {PROFILE_DIR}")

        txid = opk_tx.begin(
            root,
            "install-fullstack-profile: transactional profile install",
            lease=lease,
        )
        info(f"Transaction: {txid}")

        agents_action = install_append(
            root,
            txid,
            lease,
            f"{PROFILE_REL}/AGENTS.append.md",
            "AGENTS.md",
        )
        opencode_action = install_append(
            root,
            txid,
            lease,
            f"{PROFILE_REL}/OPENCODE.append.md",
            "OPENCODE.md",
        )

        command_count = install_commands(root, txid, lease)
        skill_count = install_skills(root, txid, lease)

        report = report_text(
            root,
            txid,
            agents_action,
            opencode_action,
            command_count,
            skill_count,
        )
        tx_stage(root, txid, lease, "REPLACE", REPORT_REL, text=report)

        opk_tx.commit(root, txid, lease=lease)
        ok("Full-stack profile transaction committed")
        info(f"Report: {os.path.join(root, REPORT_REL)}")
        return 0

    except Exception as error:
        if txid is not None:
            try:
                opk_tx.rollback(
                    io.canonical_root(args.project_dir or os.getcwd()),
                    txid,
                    lease=lease,
                )
            except Exception as rollback_error:
                print(
                    f"[ERROR] install failed: {error}; rollback also failed: {rollback_error}",
                    file=sys.stderr,
                )
                return 1
        print(f"[ERROR] {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
