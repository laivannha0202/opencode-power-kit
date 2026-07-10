#!/usr/bin/env bash
# ============================================================================
# run.sh — Eval harness runner
# Chạy tất cả eval tasks và report kết quả.
# Usage: bash evals/run.sh [task-file.json]
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
EVAL_DIR="$(cd "$(dirname "$SELF")" && pwd)"
TASKS_DIR="$EVAL_DIR/tasks"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

run_eval() {
  local task_file="$1"
  local task_name
  task_name="$(basename "$task_file" .json)"

  echo ""
  echo "━━━ $task_name ━━━"

  if ! command -v python3 >/dev/null 2>&1; then
    echo "  ⏭️  python3 not found, skipping"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  # Parse and run each task
  python3 -c "
import json, sys

with open('$task_file') as f:
    tasks = json.load(f)

for task in tasks:
    tid = task['id']
    name = task['name']
    desc = task.get('description', '')
    inp = task['input']
    expected = task.get('expected_contains', [])
    not_expected = task.get('expected_not_contains', [])

    print(f'  [{tid}] {name}')
    print(f'    {desc}')

    # For now, we just validate the task structure
    # In a real setup, this would send to an LLM and check output
    errors = []

    if not tid:
        errors.append('missing id')
    if not name:
        errors.append('missing name')
    if not inp:
        errors.append('missing input')
    if not isinstance(expected, list):
        errors.append('expected_contains must be list')
    if not isinstance(not_expected, list):
        errors.append('expected_not_contains must be list')

    if errors:
        print(f'    ❌ STRUCT ERRORS: {\", \".join(errors)}')
        print(f'    RESULT=FAIL')
    else:
        print(f'    ✅ Structure valid (expected: {len(expected)} contains, {len(not_expected)} not-contains)')
        print(f'    RESULT=PASS')
" 2>/dev/null
}

# --- Main ---
echo "=== OpenCode Power Kit Eval Harness ==="
echo ""

if [ $# -gt 0 ]; then
  # Run specific task file
  for f in "$@"; do
    if [ -f "$f" ]; then
      run_eval "$f"
    else
      echo "⚠️  File not found: $f"
    fi
  done
else
  # Run all task files
  if [ ! -d "$TASKS_DIR" ]; then
    echo "❌ Tasks directory not found: $TASKS_DIR"
    exit 1
  fi

  task_count=$(find "$TASKS_DIR" -name "*.json" -maxdepth 1 2>/dev/null | wc -l)
  if [ "$task_count" -eq 0 ]; then
    echo "⚠️  No task files found in $TASKS_DIR"
    exit 0
  fi

  echo "Found $task_count task file(s)"
  for f in "$TASKS_DIR"/*.json; do
    [ -f "$f" ] || continue
    run_eval "$f"
  done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "Eval harness: structure validation complete."
echo "To run with real LLM evaluation, integrate with your model provider."
exit 0
