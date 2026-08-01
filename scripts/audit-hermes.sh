#!/usr/bin/env bash
# Hermes-lite audit: read-only by default; report writes require --write.
set -uo pipefail

SCRIPT_NAME="$(basename "$0")"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT_OUTPUT="$KIT_DIR/docs/HERMES_AUDIT.md"
MODE=check

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [--dry-run|--check|--write|--help]

  --dry-run  Print the audit plan only; make no changes.
  --check    Run noninteractive read-only checks (default).
  --write    Run checks and update docs/HERMES_AUDIT.md.
  --help     Show this help.
EOF
}

if (($# == 1)) && [[ "$1" == -h || "$1" == --help ]]; then
  usage
  exit 0
fi

MODE_FLAGS=0
while (($#)); do
  case "$1" in
    --dry-run|--check|--write)
      MODE_FLAGS=$((MODE_FLAGS + 1))
      if ((MODE_FLAGS > 1)); then
        echo "ERROR: choose exactly one of --dry-run, --check, or --write" >&2
        exit 2
      fi
      case "$1" in
        --dry-run) MODE=dry-run ;;
        --check) MODE=check ;;
        --write) MODE="write" ;;
      esac
      ;;
    -h|--help)
      echo "ERROR: --help cannot be combined with other options" >&2
      exit 2
      ;;
    *) echo "ERROR: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$MODE" == dry-run ]]; then
  cat <<EOF
Hermes audit plan:
  1. Check the Hermes agent and exact bundled command manifest frontmatter.
  2. Check required Hermes scripts and docs.
  3. Check CLI/verify.sh integration and Bash syntax.
  4. Run shellcheck when available; otherwise report SKIP.
  5. Do not write files.
Dry run complete.
EOF
  exit 0
fi

TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=()

pass() { echo "  PASS $1"; PASSED_CHECKS=$((PASSED_CHECKS + 1)); }
fail() { echo "  FAIL $1"; FAILED_CHECKS=$((FAILED_CHECKS + 1)); WARNINGS+=("$1"); }
check_file() {
  local path="$1" label="$2"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if [[ -f "$path" ]]; then pass "$label"; else fail "$label (missing: ${path#"$KIT_DIR"/})"; fi
}
check_frontmatter() {
  local path="$1" label="$2" delimiters=0
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  [[ -f "$path" ]] && delimiters="$(grep -c '^---$' "$path")"
  if [[ -f "$path" && "$(head -n1 "$path")" == '---' ]] && head -n10 "$path" | grep -q '^description:' && ((delimiters >= 2)); then
    pass "$label frontmatter"
  else
    fail "$label frontmatter"
  fi
}
check_bash_syntax() {
  local path="$1" label="$2"
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if [[ -f "$path" ]] && bash -n "$path"; then pass "$label bash -n"; else fail "$label bash -n"; fi
}

echo "=== audit-hermes ==="
echo "Mode: $MODE"

echo "--- Agent ---"
check_file "$KIT_DIR/opencode-global/agents/hermes-lite-strong.md" "hermes-lite-strong.md"
check_frontmatter "$KIT_DIR/opencode-global/agents/hermes-lite-strong.md" "hermes-lite-strong.md"

echo "--- Bundled commands ---"
HERMES_COMMANDS=(
  hermes-audit.md
  hermes-budget.md
  hermes-kanban.md
  hermes-learn.md
  hermes-memory.md
  hermes-reflect.md
  hermes-research.md
  hermes-skill.md
)
for command_file in "${HERMES_COMMANDS[@]}"; do
  path="$KIT_DIR/opencode-global/commands/$command_file"
  check_file "$path" "commands/$command_file"
  check_frontmatter "$path" "commands/$command_file"
done
ACTUAL_COMMANDS=()
for path in "$KIT_DIR"/opencode-global/commands/hermes-*.md; do
  [[ -f "$path" ]] && ACTUAL_COMMANDS+=("${path##*/}")
done
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ "${ACTUAL_COMMANDS[*]}" == "${HERMES_COMMANDS[*]}" ]]; then
  pass "exact bundled Hermes command manifest (${#HERMES_COMMANDS[@]})"
else
  fail "exact bundled Hermes command manifest"
fi

echo "--- Required scripts ---"
for script in check-hermes-lite.sh hermes-learning-capsule.sh; do
  check_file "$KIT_DIR/scripts/$script" "$script"
done

echo "--- Required docs ---"
for doc in HERMES_INTEGRATION.md HERMES_AUDIT.md LEARNING_LOOP.md AGENT_KANBAN.md; do
  check_file "$KIT_DIR/docs/$doc" "docs/$doc"
done

echo "--- CLI integration ---"
TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
if [[ -f "$KIT_DIR/bin/opk" ]] && grep -q 'hermes|hermes-status' "$KIT_DIR/bin/opk"; then
  pass "bin/opk Hermes dispatcher"
else
  fail "bin/opk Hermes dispatcher"
fi

if [[ -f "$KIT_DIR/verify.sh" ]]; then
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if grep -q 'hermes' "$KIT_DIR/verify.sh"; then pass "verify.sh Hermes integration"; else fail "verify.sh Hermes integration"; fi
else
  echo "  SKIP verify.sh integration (not present)"
fi

echo "--- Bash syntax ---"
for script in audit-hermes.sh check-hermes-lite.sh hermes-learning-capsule.sh; do
  check_bash_syntax "$KIT_DIR/scripts/$script" "$script"
done

echo "--- shellcheck ---"
if command -v shellcheck >/dev/null 2>&1; then
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  if shellcheck "$KIT_DIR/scripts/audit-hermes.sh" "$KIT_DIR/scripts/check-hermes-lite.sh" "$KIT_DIR/scripts/hermes-learning-capsule.sh"; then
    pass "shellcheck"
  else
    fail "shellcheck"
  fi
else
  echo "  SKIP shellcheck (not installed)"
fi

PASS_RATE=0
((TOTAL_CHECKS == 0)) || PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

if [[ "$MODE" == write ]]; then
  mkdir -p "$KIT_DIR/docs"
  {
    echo '# Hermes-lite Audit Report'
    echo
    echo "> Generated by \`audit-hermes.sh --write\` on $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    echo '| Attribute | Value |'
    echo '|---|---:|'
    echo "| Total checks | $TOTAL_CHECKS |"
    echo "| Passed | $PASSED_CHECKS |"
    echo "| Failed | $FAILED_CHECKS |"
    echo "| Pass rate | $PASS_RATE% |"
    echo
    echo '## Findings'
    if ((${#WARNINGS[@]} == 0)); then echo '- None.'; else for warning in "${WARNINGS[@]}"; do echo "- $warning"; done; fi
  } >"$AUDIT_OUTPUT"
  echo "WROTE $AUDIT_OUTPUT"
fi

echo "=== Summary ==="
echo "  Checks: $PASSED_CHECKS/$TOTAL_CHECKS passed"
echo "  Failed: $FAILED_CHECKS"
echo "  Mode: $MODE"
((FAILED_CHECKS == 0))
