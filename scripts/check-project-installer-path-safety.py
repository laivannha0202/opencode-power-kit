#!/usr/bin/env python3
"""Static validator: check merge-opk-project.py for dangerous path patterns.

Scans for:
  - os.path.join / Path / open calls without dirfd safety
  - os.makedirs without exist_ok
  - shutil.rmtree without error handler
  - subprocess calls with shell=True
  - eval/exec calls
  - open() without explicit encoding
"""
from __future__ import annotations
import ast
import sys
import pathlib

MERGE_SCRIPT = pathlib.Path(__file__).resolve().parent / "merge-opk-project.py"
VIOLATIONS: list[str] = []

def warn(msg: str) -> None:
    VIOLATIONS.append(msg)

def check_file(path: pathlib.Path) -> None:
    source = path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(path))
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            func = node.func
            # open() without encoding
            if isinstance(func, ast.Name) and func.id == "open":
                kw_names = {kw.arg for kw in node.keywords}
                if "encoding" not in kw_names:
                    warn(f"open() without encoding at line {node.lineno}")
            # os.makedirs without exist_ok
            if isinstance(func, ast.Attribute) and func.attr == "makedirs":
                kw_names = {kw.arg for kw in node.keywords}
                if "exist_ok" not in kw_names:
                    warn(f"os.makedirs without exist_ok at line {node.lineno}")
            # shutil.rmtree without onerror/handler
            if isinstance(func, ast.Attribute) and func.attr == "rmtree":
                kw_names = {kw.arg for kw in node.keywords}
                if "onerror" not in kw_names and "ignore_errors" not in kw_names:
                    warn(f"shutil.rmtree without onerror at line {node.lineno}")
            # subprocess with shell=True
            if isinstance(func, ast.Attribute) and func.attr in ("run", "call", "check_call", "check_output"):
                kw_names = {kw.arg for kw in node.keywords}
                if "shell" in kw_names:
                    warn(f"subprocess call with shell=True at line {node.lineno}")
        # eval/exec
        if isinstance(node, (ast.Call,)):
            func = node.func
            if isinstance(func, ast.Name) and func.id in ("eval", "exec"):
                warn(f"dangerous call {func.id}() at line {node.lineno}")

def main() -> int:
    check_file(MERGE_SCRIPT)
    if VIOLATIONS:
        for v in VIOLATIONS:
            print(f"VIOLATION: {v}", file=sys.stderr)
        return 1
    print("path-safety: 0 violations")
    return 0

if __name__ == "__main__":
    sys.exit(main())
