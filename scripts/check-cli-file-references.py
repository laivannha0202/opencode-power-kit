#!/usr/bin/env python3
"""Validate file references rooted at KIT_DIR in the Bash CLI."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_ROOT = Path(__file__).resolve().parent.parent
REFERENCE_RE = re.compile(
    r"\$(?:\{KIT_DIR\}|KIT_DIR)/"
    r"(?P<path>[A-Za-z0-9_./+@-]*[A-Za-z0-9_+@.-])"
    r"(?=$|[\s\"'`;|)&<>])"
)
GUARD_RE = re.compile(
    r"(?:\[\[|\[|\btest)\s+-f\s+['\"]?"
    r"(?P<reference>\$(?:\{KIT_DIR\}|KIT_DIR)/"
    r"[A-Za-z0-9_./+@-]*[A-Za-z0-9_+@.-])['\"]?"
)
FILE_OPERAND_COMMAND_RE = re.compile(
    r"(?:^|[;&|({)])\s*(?:(?:if|then|elif|while|until|do|!)\s+)*"
    r"(?:command\s+)?"
    r"(?:source|cat|bash|python[23]?|node|need|run_script|exec|grep|cmp|diff|jq)\b"
)
SOURCE_DEST_COMMAND_RE = re.compile(
    r"(?:^|[;&|({)])\s*(?:(?:if|then|elif|while|until|do|!)\s+)*"
    r"(?:command\s+)?(?:cp|install|mv|ln)\b"
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate literal KIT_DIR file references in bin/opk."
    )
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--cli", type=Path)
    return parser.parse_args()


def is_in_shell_comment(line: str, position: int) -> bool:
    quote: str | None = None
    escaped = False
    for index, character in enumerate(line[:position]):
        if escaped:
            escaped = False
            continue
        if character == "\\" and quote != "'":
            escaped = True
            continue
        if quote:
            if character == quote:
                quote = None
            continue
        if character in ("'", '"'):
            quote = character
            continue
        if character == "#" and (
            index == 0 or line[index - 1].isspace() or line[index - 1] in ";&|()"
        ):
            return True
    return False


def normalize_reference(root: Path, relative: str) -> tuple[Path, str] | None:
    target = (root / relative).resolve(strict=False)
    try:
        normalized = target.relative_to(root)
    except ValueError:
        return None
    return target, normalized.as_posix()


def guard_occurrences(root: Path, line: str) -> list[tuple[int, int, str]]:
    condition = line.split(";", 1)[0]
    if "||" in condition or re.search(r"(?:^|\s)-o(?:\s|$)", condition):
        return []

    guards: list[tuple[int, int, str]] = []
    for match in GUARD_RE.finditer(line):
        before = line[: match.start()].rstrip()
        if before.endswith("!"):
            continue
        reference = match.group("reference")
        reference_match = REFERENCE_RE.fullmatch(reference)
        if not reference_match:
            continue
        normalized = normalize_reference(root, reference_match.group("path"))
        if normalized:
            guards.append((match.start(), match.end(), normalized[1]))
    return guards


def has_following_operand(line: str, match: re.Match[str]) -> bool:
    suffix = line[match.end() :].lstrip("\"' \t")
    return bool(suffix and suffix[0] not in ";|)&<>#")


def reference_role(
    root: Path,
    line: str,
    match: re.Match[str],
    target: Path,
) -> str | None:
    prefix = line[: match.start()]
    command_segment = re.split(r"[;&|]", prefix)[-1]
    if SOURCE_DEST_COMMAND_RE.search(command_segment):
        if has_following_operand(line, match):
            return None if target.is_dir() else "source"
        return "destination"
    if target.is_dir():
        return None
    if FILE_OPERAND_COMMAND_RE.search(command_segment):
        return "source"
    guards = guard_occurrences(root, line)
    if any(start <= match.start() < end for start, end, _ in guards):
        return "source"
    return None


def occurrence_is_guarded(
    line: str,
    match: re.Match[str],
    normalized_path: str,
    active_guards: set[str],
    guards: list[tuple[int, int, str]],
) -> bool:
    if normalized_path in active_guards:
        return True
    for start, end, guarded_path in guards:
        if start <= match.start() < end:
            return True
        if guarded_path != normalized_path or end > match.start():
            continue
        between = line[end : match.start()]
        if "&&" in between and ";" not in between:
            return True
        if re.search(r";\s*then\b", between) and not re.search(
            r"\b(?:elif|else|fi)\b", between
        ):
            return True
    return False


def check_references(root: Path, cli: Path) -> tuple[list[tuple[int, str]], int]:
    source = cli.read_text(encoding="utf-8")
    issues: list[tuple[int, str]] = []
    checked = 0
    guard_stack: list[set[str]] = []
    pending_guards: set[str] | None = None

    for line_number, line in enumerate(source.splitlines(), start=1):
        stripped = line.strip()
        starts_branch = re.match(r"^(?:elif\b|else\b|fi\b)", stripped)
        if starts_branch and guard_stack:
            guard_stack.pop()

        if re.match(r"^then\b", stripped) and pending_guards is not None:
            guard_stack.append(pending_guards)
            pending_guards = None

        active_guards = set().union(*guard_stack) if guard_stack else set()
        guards = guard_occurrences(root, line)
        for match in REFERENCE_RE.finditer(line):
            if is_in_shell_comment(line, match.start()):
                continue
            relative = match.group("path")
            unresolved_target = root / relative
            role = reference_role(root, line, match, unresolved_target)
            if role is None:
                continue
            normalized = normalize_reference(root, relative)
            checked += 1
            if normalized is None:
                issues.append((line_number, f"path escapes root: {relative}"))
                continue
            target, normalized_path = normalized
            if role == "destination" or target.is_file():
                continue
            if occurrence_is_guarded(
                line, match, normalized_path, active_guards, guards
            ):
                continue
            issues.append((line_number, f"missing: {normalized_path}"))

        starts_if = bool(re.match(r"^if\b", stripped))
        starts_elif = bool(re.match(r"^elif\b", stripped))
        starts_else = bool(re.match(r"^else\b", stripped))
        has_then = bool(re.search(r"(?:;|^)\s*then\b", line))
        has_fi = bool(re.search(r"(?:;|^)\s*fi\b", line))

        if starts_if or starts_elif:
            if has_then:
                if not has_fi:
                    guard_stack.append({path for _, _, path in guards})
            else:
                pending_guards = {path for _, _, path in guards}
        elif starts_else:
            if has_then and not has_fi:
                guard_stack.append(set())
            elif not has_then:
                guard_stack.append(set())

        closes_later = has_fi and not re.match(r"^fi\b", stripped)
        belongs_to_same_line_if = starts_if and has_then
        if closes_later and not belongs_to_same_line_if and guard_stack:
            guard_stack.pop()

    return issues, checked


def main() -> int:
    args = parse_args()
    root = args.root.resolve()
    cli = args.cli.resolve() if args.cli else root / "bin" / "opk"
    if not cli.is_file():
        print(f"check-cli-file-references: missing CLI: {cli}", file=sys.stderr)
        return 1

    issues, checked = check_references(root, cli)
    for line_number, issue in issues:
        print(
            f"check-cli-file-references: {issue} (line {line_number})",
            file=sys.stderr,
        )
    if issues:
        return 1

    print(f"check-cli-file-references: PASS ({checked} references)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
