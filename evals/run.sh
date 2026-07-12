#!/usr/bin/env bash
# ============================================================================
# run.sh — Workflow Regression Test Runner
# Verify behavioral contracts: no model routing, no API keys, no overrides.
# Usage: bash evals/run.sh [--dry-run]
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
EVAL_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$EVAL_DIR/.." && pwd)"
TASKS_DIR="$EVAL_DIR/tasks"
RESULTS_DIR="$EVAL_DIR/results"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Check functions ---

check_grep_absent() {
  local target="$1"
  shift
  local patterns=("$@")
  local full_path="$KIT_DIR/$target"

  if [ ! -f "$full_path" ] && [ ! -d "$full_path" ]; then
    echo "SKIP|$target not found"
    return 2
  fi

  for pat in "${patterns[@]}"; do
    if [ -d "$full_path" ]; then
      if grep -rql "$pat" "$full_path" 2>/dev/null; then
        echo "FAIL|$target contains forbidden pattern: $pat"
        return 1
      fi
    else
      if grep -ql "$pat" "$full_path" 2>/dev/null; then
        echo "FAIL|$target contains forbidden pattern: $pat"
        return 1
      fi
    fi
  done
  echo "PASS|$target clean"
  return 0
}

check_grep_present() {
  local target="$1"
  shift
  local patterns=("$@")
  local full_path="$KIT_DIR/$target"

  if [ ! -f "$full_path" ]; then
    echo "FAIL|$target not found"
    return 1
  fi

  for pat in "${patterns[@]}"; do
    if ! grep -ql "$pat" "$full_path" 2>/dev/null; then
      echo "FAIL|$target missing required pattern: $pat"
      return 1
    fi
  done
  echo "PASS|$target has all required patterns"
  return 0
}

check_file_absent() {
  local targets=("$@")
  for t in "${targets[@]}"; do
    if [ -e "$KIT_DIR/$t" ]; then
      echo "FAIL|$t should not exist"
      return 1
    fi
  done
  echo "PASS|files correctly absent"
  return 0
}

check_file_present() {
  local targets=("$@")
  for t in "${targets[@]}"; do
    if [ ! -e "$KIT_DIR/$t" ]; then
      echo "FAIL|$t should exist"
      return 1
    fi
  done
  echo "PASS|files correctly present"
  return 0
}

# --- Run a single task ---
run_task() {
  local task_file="$1"
  local task_id="$2"

  local result
  result=$(python3 -c "
import json, sys
with open('$task_file') as f:
    tasks = json.load(f)
task = next((t for t in tasks if t['id'] == '$task_id'), None)
if not task:
    print('ERROR|task not found')
    sys.exit(0)
print(json.dumps(task))
" 2>/dev/null)

  if echo "$result" | grep -q "^ERROR|"; then
    echo -e "  ${RED}❌ $task_id: task not found in JSON${NC}"
    FAILED=$((FAILED + 1))
    return
  fi

  local check_type target
  check_type=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['check_type'])" 2>/dev/null)
  target=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('target',''))" 2>/dev/null)

  local patterns
  patterns=$(echo "$result" | python3 -c "
import json,sys
t = json.load(sys.stdin)
p = t.get('patterns', [])
for x in p: print(x)
" 2>/dev/null)

  local targets
  targets=$(echo "$result" | python3 -c "
import json,sys
t = json.load(sys.stdin)
tg = t.get('targets', [])
for x in tg: print(x)
" 2>/dev/null)

  local check_output
  local check_result=0
  case "$check_type" in
    grep_absent)
      local pat_arr=()
      while IFS= read -r p; do [ -n "$p" ] && pat_arr+=("$p"); done <<< "$patterns"
      check_output=$(check_grep_absent "$target" "${pat_arr[@]}") || check_result=$?
      ;;
    grep_present)
      local pat_arr=()
      while IFS= read -r p; do [ -n "$p" ] && pat_arr+=("$p"); done <<< "$patterns"
      check_output=$(check_grep_present "$target" "${pat_arr[@]}") || check_result=$?
      ;;
    file_absent)
      local tgt_arr=()
      while IFS= read -r t; do [ -n "$t" ] && tgt_arr+=("$t"); done <<< "$targets"
      check_output=$(check_file_absent "${tgt_arr[@]}") || check_result=$?
      ;;
    file_present)
      local tgt_arr=()
      while IFS= read -r t; do [ -n "$t" ] && tgt_arr+=("$t"); done <<< "$targets"
      check_output=$(check_file_present "${tgt_arr[@]}") || check_result=$?
      ;;
    script_exec)
      local cmd_str
      cmd_str=$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('command',''))" 2>/dev/null)
      if [ -z "$cmd_str" ]; then
        check_output="FAIL|$task_id: script_exec missing command"
        check_result=1
      else
        local interp="${cmd_str%% *}"
        case "$interp" in
          python3)
            if ! command -v python3 >/dev/null 2>&1; then
              check_output="FAIL|$task_id: python3 not found (required dependency)"
              check_result=1
            else
              local output rc=0
              output=$(cd "$KIT_DIR" && timeout 60 bash -c "$cmd_str" 2>&1) && rc=0 || rc=$?
              if [ "$rc" -eq 0 ]; then
                check_output="PASS|$task_id: $cmd_str exited 0"
                check_result=0
              else
                check_output="FAIL|$task_id: $cmd_str exited $rc"
                check_result=1
              fi
            fi
            ;;
          node)
            if ! command -v node >/dev/null 2>&1; then
              check_output="FAIL|$task_id: node not found (required dependency)"
              check_result=1
            else
              local output rc=0
              output=$(cd "$KIT_DIR" && timeout 60 bash -c "$cmd_str" 2>&1) && rc=0 || rc=$?
              if [ "$rc" -eq 0 ]; then
                check_output="PASS|$task_id: $cmd_str exited 0"
                check_result=0
              else
                check_output="FAIL|$task_id: $cmd_str exited $rc"
                check_result=1
              fi
            fi
            ;;
          bin/opk|./bin/opk)
            local output rc=0
            output=$(cd "$KIT_DIR" && timeout 60 bash -c "$cmd_str" 2>&1) && rc=0 || rc=$?
            if [ "$rc" -eq 0 ]; then
              check_output="PASS|$task_id: $cmd_str exited 0"
              check_result=0
            else
              check_output="FAIL|$task_id: $cmd_str exited $rc"
              check_result=1
            fi
            ;;
          *)
            local output rc=0
            output=$(cd "$KIT_DIR" && timeout 60 bash -c "$cmd_str" 2>&1) && rc=0 || rc=$?
            if [ "$rc" -eq 0 ]; then
              check_output="PASS|$task_id: $cmd_str exited 0"
              check_result=0
            else
              check_output="FAIL|$task_id: $cmd_str exited $rc"
              check_result=1
            fi
            ;;
        esac
      fi
      ;;
    *)
      echo -e "  ${RED}❌ $task_id: unknown check_type '$check_type' — FAIL${NC}"
      FAILED=$((FAILED + 1))
      TOTAL=$((TOTAL + 1))
      return
      ;;
  esac

  TOTAL=$((TOTAL + 1))
  local label
  label=$(echo "$check_output" | head -1 | cut -d'|' -f2)

  if [ "$check_result" -eq 0 ]; then
    echo -e "  ${GREEN}✅ $task_id: $label${NC}"
    PASSED=$((PASSED + 1))
  else
    echo -e "  ${RED}❌ $task_id: $label${NC}"
    FAILED=$((FAILED + 1))
  fi
}

# --- Main ---
echo "=== OPK Workflow Regression Tests ==="
echo ""

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      echo -e "${CYAN}Flag: --dry-run (structural check only)${NC}"
      ;;
  esac
done

if [ ! -d "$TASKS_DIR" ]; then
  echo -e "${RED}❌ Tasks directory not found: $TASKS_DIR${NC}"
  exit 1
fi

task_count=$(find "$TASKS_DIR" -name "*.json" -maxdepth 1 2>/dev/null | wc -l)
if [ "$task_count" -eq 0 ]; then
  echo -e "${YELLOW}⚠️  No task files found${NC}"
  exit 0
fi

echo "Found $task_count task file(s)"
for f in "$TASKS_DIR"/*.json; do
  [ -f "$f" ] || continue
  fname="$(basename "$f" .json)"
  echo ""
  echo "━━━ $fname ━━━"

  # Get all task IDs from this file
  task_ids=$(python3 -c "
import json
with open('$f') as fh:
    tasks = json.load(fh)
for t in tasks:
    print(t['id'])
" 2>/dev/null)

  while IFS= read -r tid; do
    [ -z "$tid" ] && continue
    run_task "$f" "$tid"
  done <<< "$task_ids"
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "Workflow regression tests complete."
echo -e "  Summary: total=$TOTAL passed=$PASSED failed=$FAILED skipped=$SKIPPED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
