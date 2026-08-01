#!/usr/bin/env bash
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$KIT_DIR/scripts/check-agent-permission-contracts.py"
SOURCE_BEFORE="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
TMP="$(mktemp -d)"
trap 'rm -r -- "$TMP"' EXIT

PASS=0
FAIL=0

check_rejected() {
  local name="$1" content="$2" expected="$3" root output
  root="$TMP/$name"
  mkdir -p "$root/opencode-global/agents" "$root/scripts"
  printf '{"ask_exceptions": {}}\n' >"$root/scripts/agent-permission-exceptions.json"
  printf '%s\n' '---' 'description: fixture' "$content" '---' >"$root/opencode-global/agents/build-strong.md"
  if output="$(python3 "$CHECKER" --root "$root" 2>&1)"; then
    printf '  [FAIL] %s was accepted\n' "$name" >&2
    FAIL=$((FAIL + 1))
  elif [[ "$output" == *"$expected"* ]]; then
    printf '  [ok]   %s\n' "$name"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s returned unexpected error: %s\n' "$name" "$output" >&2
    FAIL=$((FAIL + 1))
  fi
}

check_rejected double-quoted $'permission:\n  edit: "ask"' 'power-compatible agent contains ask'
check_rejected single-quoted $'permission:\n  edit: '\''ask'\''' 'power-compatible agent contains ask'
check_rejected unquoted $'permission:\n  edit: ask' 'power-compatible agent contains ask'
check_rejected inline $'permission: { edit: ask }' 'inline permission objects are not supported'
check_rejected bash-unquoted $'permission:\n  bash:\n    "*": ask' 'power-compatible agent contains ask'
check_rejected bash-quoted $'permission:\n  bash:\n    '\''*'\'': '\''ask'\''' 'power-compatible agent contains ask'
check_rejected trailing-comment $'permission:\n  edit: ask # approval' 'power-compatible agent contains ask'
check_rejected nested-inline $'permission:\n  bash: {"*": ask}' 'inline permission objects are not supported'

READ_ONLY_ROOT="$TMP/read-only"
mkdir -p "$READ_ONLY_ROOT/opencode-global/agents" "$READ_ONLY_ROOT/scripts"
printf '{"ask_exceptions": {}}\n' >"$READ_ONLY_ROOT/scripts/agent-permission-exceptions.json"
cat >"$READ_ONLY_ROOT/opencode-global/agents/review-lite.md" <<'EOF'
---
description: fixture
permission:
  edit: deny
  bash:
    "*": allow
    "git diff*": allow
---
EOF
if output="$(python3 "$CHECKER" --root "$READ_ONLY_ROOT" 2>&1)"; then
  printf '  [FAIL] read-only wildcard allow was accepted\n' >&2
  FAIL=$((FAIL + 1))
elif [[ "$output" == *'read-only agent bash wildcard must be deny'* ]]; then
  printf '  [ok]   read-only wildcard allow rejected\n'
  PASS=$((PASS + 1))
else
  printf '  [FAIL] read-only wildcard returned unexpected error: %s\n' "$output" >&2
  FAIL=$((FAIL + 1))
fi

printf '\nAgent permission tests: %d passed, %d failed\n' "$PASS" "$FAIL"
SOURCE_AFTER="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
if [[ "$SOURCE_BEFORE" != "$SOURCE_AFTER" ]]; then
  printf '  [FAIL] agent permission tests changed source tree\n' >&2
  FAIL=$((FAIL + 1))
fi
((FAIL == 0))
