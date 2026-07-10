#!/usr/bin/env bash
# ============================================================================
# run.sh — Eval harness runner
# Chạy tất cả eval tasks, gọi model thật hoặc dry-run nếu không có client.
# Usage: bash evals/run.sh [task-file.json]
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
EVAL_DIR="$(cd "$(dirname "$SELF")" && pwd)"
TASKS_DIR="$EVAL_DIR/tasks"
RESULTS_DIR="$EVAL_DIR/results"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Detect model client ---
MODEL_CLIENT="none"
MODEL_REASON=""

detect_model_client() {
  if python3 -c "import openai" 2>/dev/null; then
    MODEL_CLIENT="openai"
    MODEL_REASON="openai library found"
    return 0
  fi

  if python3 -c "import anthropic" 2>/dev/null; then
    MODEL_CLIENT="anthropic"
    MODEL_REASON="anthropic library found"
    return 0
  fi

  MODEL_CLIENT="none"
  MODEL_REASON="no model client library found (install openai or anthropic)"
  return 1
}

# --- Real model call ---
call_model_real() {
  local prompt="$1"
  local max_tokens="${2:-500}"

  python3 -c "
import json, time, sys

model = '$MODEL_CLIENT'
prompt = sys.stdin.read()
max_tokens = $max_tokens

start = time.time()

try:
    if model == 'openai':
        import openai
        client = openai.OpenAI()
        resp = client.chat.completions.create(
            model='gpt-4o-mini',
            messages=[{'role': 'user', 'content': prompt}],
            max_tokens=max_tokens,
            temperature=0.0
        )
        content = resp.choices[0].message.content or ''
        latency = time.time() - start
        result = {
            'success': True,
            'model': 'gpt-4o-mini',
            'content': content,
            'latency_ms': round(latency * 1000),
            'tokens_used': getattr(resp.usage, 'total_tokens', 0) if resp.usage else 0
        }
    elif model == 'anthropic':
        import anthropic
        client = anthropic.Anthropic()
        resp = client.messages.create(
            model='claude-3-haiku-20240307',
            max_tokens=max_tokens,
            messages=[{'role': 'user', 'content': prompt}]
        )
        content = resp.content[0].text if resp.content else ''
        latency = time.time() - start
        result = {
            'success': True,
            'model': 'claude-3-haiku-20240307',
            'content': content,
            'latency_ms': round(latency * 1000),
            'tokens_used': (resp.usage.input_tokens + resp.usage.output_tokens) if resp.usage else 0
        }
    else:
        result = {'success': False, 'error': f'unknown client: {model}'}

except Exception as e:
    latency = time.time() - start
    result = {'success': False, 'error': str(e), 'latency_ms': round(latency * 1000)}

print(json.dumps(result))
" <<< "$prompt" 2>/dev/null
}

# --- Generate dry-run JSON ---
generate_dry_run_json() {
  local task_file="$1"
  local task_id="$2"
  local reason="$3"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  python3 << PYEOF
import json, sys

task_file = "$task_file"
task_id = "$task_id"
reason = "$reason"
timestamp = "$timestamp"

with open(task_file) as f:
    tasks = json.load(f)

task = next((t for t in tasks if t["id"] == task_id), None)
if not task:
    sys.exit(1)

result = {
    "task_id": task_id,
    "task_name": task["name"],
    "model_available": False,
    "skip": True,
    "reason": reason,
    "timestamp": timestamp,
    "input": task["input"],
    "expected_contains": task.get("expected_contains", []),
    "expected_not_contains": task.get("expected_not_contains", []),
    "output": None,
    "checks": {},
    "latency_ms": 0
}
print(json.dumps(result, indent=2))
PYEOF
}

# --- Generate real eval JSON ---
generate_real_json() {
  local task_file="$1"
  local task_id="$2"
  local output="$3"
  local latency_ms="$4"
  local reason="$5"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  python3 << PYEOF
import json, sys

task_file = "$task_file"
task_id = "$task_id"
output = sys.stdin.read()
latency_ms = $latency_ms
reason = "$reason"
timestamp = "$timestamp"

with open(task_file) as f:
    tasks = json.load(f)

task = next((t for t in tasks if t["id"] == task_id), None)
if not task:
    sys.exit(1)

expected = task.get("expected_contains", [])
not_expected = task.get("expected_not_contains", [])
output_lower = output.lower()

checks = {}
for term in expected:
    checks[f"contains:{term}"] = term.lower() in output_lower
for term in not_expected:
    checks[f"not_contains:{term}"] = term.lower() not in output_lower

all_pass = all(checks.values()) if checks else True

result = {
    "task_id": task_id,
    "task_name": task["name"],
    "model_available": True,
    "skip": False,
    "reason": reason,
    "timestamp": timestamp,
    "input": task["input"],
    "expected_contains": expected,
    "expected_not_contains": not_expected,
    "output": output[:2000],
    "checks": checks,
    "all_pass": all_pass,
    "latency_ms": latency_ms
}
print(json.dumps(result, indent=2))
PYEOF
}

# --- Run eval for a task file ---
run_eval() {
  local task_file="$1"
  local task_name
  task_name="$(basename "$task_file" .json)"

  echo ""
  echo "━━━ $task_name ━━━"

  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "  ${YELLOW}⏭️  python3 not found, skipping${NC}"
    SKIPPED=$((SKIPPED + 1))
    return
  fi

  # Validate structure first
  local struct_results
  struct_results=$(EVAL_TASK_FILE="$task_file" python3 -c '
import json, os

task_file = os.environ["EVAL_TASK_FILE"]
with open(task_file) as f:
    tasks = json.load(f)

for task in tasks:
    tid = task["id"]
    name = task["name"]
    inp = task["input"]
    expected = task.get("expected_contains", [])
    not_expected = task.get("expected_not_contains", [])

    errors = []
    if not tid: errors.append("missing id")
    if not name: errors.append("missing name")
    if not inp: errors.append("missing input")
    if not isinstance(expected, list): errors.append("expected_contains must be list")
    if not isinstance(not_expected, list): errors.append("expected_not_contains must be list")

    status = "PASS" if not errors else "FAIL"
    err_str = ";".join(errors) if errors else ""
    print(f"{tid}|{status}|{err_str}")
' 2>/dev/null)

  # Process results line by line (no subshell)
  while IFS='|' read -r tid status errors; do
    [ -z "$tid" ] && continue
    TOTAL=$((TOTAL + 1))

    echo "  [$tid]"

    if [ "$status" = "FAIL" ]; then
      echo -e "    ${RED}❌ STRUCT ERRORS: $errors${NC}"
      FAILED=$((FAILED + 1))

      mkdir -p "$RESULTS_DIR"
      generate_dry_run_json "$task_file" "$tid" "struct validation failed: $errors" > "$RESULTS_DIR/${tid}.json"

    elif [ "$DRY_RUN" = true ]; then
      echo -e "    ${CYAN}[SKIP] Model client not available — dry-run mode${NC}"
      SKIPPED=$((SKIPPED + 1))

      mkdir -p "$RESULTS_DIR"
      generate_dry_run_json "$task_file" "$tid" "$MODEL_REASON" > "$RESULTS_DIR/${tid}.json"

    else
      # Get task input and max_tokens
      local input_prompt max_tokens
      input_prompt=$(python3 -c "
import json
with open('$task_file') as f:
    tasks = json.load(f)
t = next((x for x in tasks if x['id'] == '$tid'), None)
print(t['input'] if t else '')
" 2>/dev/null)

      max_tokens=$(python3 -c "
import json
with open('$task_file') as f:
    tasks = json.load(f)
t = next((x for x in tasks if x['id'] == '$tid'), None)
print(t.get('max_tokens', 500) if t else 500)
" 2>/dev/null)

      echo -e "    ${YELLOW}⏳ Calling $MODEL_CLIENT (max_tokens=$max_tokens)...${NC}"
      local model_result
      model_result=$(call_model_real "$input_prompt" "$max_tokens")

      local success
      success=$(echo "$model_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('success', False))" 2>/dev/null)

      if [ "$success" = "True" ]; then
        local content latency_ms
        content=$(echo "$model_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('content', ''))" 2>/dev/null)
        latency_ms=$(echo "$model_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('latency_ms', 0))" 2>/dev/null)

        echo -e "    ${GREEN}✅ Model responded (${latency_ms}ms)${NC}"

        mkdir -p "$RESULTS_DIR"
        echo "$content" | generate_real_json "$task_file" "$tid" "" "$latency_ms" "$MODEL_REASON" > "$RESULTS_DIR/${tid}.json"

        local all_pass
        all_pass=$(python3 -c "
import json
with open('$RESULTS_DIR/${tid}.json') as f:
    r = json.load(f)
print(r.get('all_pass', False))
" 2>/dev/null)

        if [ "$all_pass" = "True" ]; then
          echo -e "    ${GREEN}✅ All checks passed${NC}"
          PASSED=$((PASSED + 1))
        else
          echo -e "    ${RED}❌ Some checks failed — see $RESULTS_DIR/${tid}.json${NC}"
          FAILED=$((FAILED + 1))
        fi
      else
        local error_msg
        error_msg=$(echo "$model_result" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error', 'unknown'))" 2>/dev/null)
        echo -e "    ${RED}❌ Model call failed: $error_msg${NC}"
        FAILED=$((FAILED + 1))

        mkdir -p "$RESULTS_DIR"
        generate_dry_run_json "$task_file" "$tid" "model call failed: $error_msg" > "$RESULTS_DIR/${tid}.json"
      fi
    fi
  done <<< "$struct_results"
}

# --- Main ---
echo "=== OpenCode Power Kit Eval Harness ==="
echo ""

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      echo -e "${CYAN}Flag: --dry-run forced (structural check only)${NC}"
      DRY_RUN=true
      ;;
  esac
done

# Detect model client
echo "Detecting model client..."
if detect_model_client; then
  echo -e "  ${GREEN}✅ $MODEL_REASON${NC}"
  DRY_RUN=false
else
  echo -e "  ${YELLOW}[SKIP] $MODEL_REASON — dry-run mode${NC}"
  DRY_RUN=true
fi
echo ""

if [ $# -gt 0 ]; then
  for f in "$@"; do
    # Skip flags (already parsed above)
    case "$f" in
      --*) continue ;;
    esac
    if [ -f "$f" ]; then
      run_eval "$f"
    else
      echo -e "${YELLOW}⚠️  File not found: $f${NC}"
    fi
  done
else
  if [ ! -d "$TASKS_DIR" ]; then
    echo -e "${RED}❌ Tasks directory not found: $TASKS_DIR${NC}"
    exit 1
  fi

  task_count=$(find "$TASKS_DIR" -name "*.json" -maxdepth 1 2>/dev/null | wc -l)
  if [ "$task_count" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No task files found in $TASKS_DIR${NC}"
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
echo "Eval harness complete."
if [ "$DRY_RUN" = true ]; then
  echo -e "  ${CYAN}Mode: DRY-RUN (no model client)${NC}"
else
  echo -e "  ${GREEN}Mode: REAL (model client active)${NC}"
fi
echo -e "  Results: $RESULTS_DIR/"
echo ""
echo "Summary: total=$TOTAL passed=$PASSED failed=$FAILED skipped=$SKIPPED"
if [ "$FAILED" -gt 0 ]; then
  exit 1
elif [ "$TOTAL" -eq 0 ] && [ "$DRY_RUN" = true ]; then
  # Dry-run with no tasks executed — exit 0 (no failures)
  exit 0
else
  exit 0
fi
