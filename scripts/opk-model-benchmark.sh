#!/usr/bin/env bash
# ============================================================================
# opk-model-benchmark.sh — Free-model benchmark
# Benchmark các free model bằng cách chạy cùng một bộ task.
#
# Usage:
#   bash scripts/opk-model-benchmark.sh                 # benchmark all
#   bash scripts/opk-model-benchmark.sh --dry-run       # dry-run
#   bash scripts/opk-model-benchmark.sh --model <id>    # benchmark 1 model
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHE_DIR="${KIT_DIR}/.opencode"
CACHE_FILE="${CACHE_DIR}/opk-free-models.json"
RESULTS_DIR="${KIT_DIR}/evals/results"
SAFE_EVAL_PROJECT="${KIT_DIR}/.tmp/eval-project"

DRY_RUN=false
TARGET_MODEL=""
MAX_RUNS=3

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helpers ---
err()   { echo "opk model benchmark: $*" >&2; exit 1; }
info()  { echo -e "${GREEN}opk model benchmark: $*${NC}"; }
warn()  { echo -e "${YELLOW}opk model benchmark: $*${NC}"; }
header() { echo -e "${CYAN}━━━ $* ━━━${NC}"; }

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --model|-m)
      TARGET_MODEL="$2"
      shift 2
      ;;
    --max-runs)
      MAX_RUNS="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: opk model benchmark-free [--dry-run] [--model <id>] [--max-runs <n>]"
      echo ""
      echo "Benchmark free models bằng cách chạy cùng một bộ task."
      echo ""
      echo "Flags:"
      echo "  --dry-run       Không gọi model, chỉ kiểm tra task/schema"
      echo "  --model <id>    Benchmark 1 model cụ thể"
      echo "  --max-runs <n>  Số lần chạy mỗi model (default: 3)"
      exit 0
      ;;
    *)
      err "flag không hợp lệ: $1"
      ;;
  esac
done

# --- Check dependencies ---
if ! command -v opencode >/dev/null 2>&1; then
  err "opencode CLI không tìm thấy"
fi

if [ ! -f "$CACHE_FILE" ]; then
  err "Chưa có cache model free. Chạy: opk model discover-free"
fi

# --- Display models to benchmark ---
header "Models sẽ được benchmark"

python3 << PYEOF
import json

cache_file = "$CACHE_FILE"
target = "$TARGET_MODEL"

with open(cache_file) as f:
    cache = json.load(f)

models = cache.get("models", [])
available = [m for m in models if m.get("availability") == "available"]

if target:
    available = [m for m in available if m["id"] == target]
    if not available:
        print(f"Model '{target}' không tìm thấy hoặc không available")
        exit(1)

if not available:
    print("Không có model free available để benchmark")
    exit(1)

print(f"{'MODEL ID':<40} {'STATUS':<15}")
print(f"{'─'*40} {'─'*15}")
for m in available:
    print(f"{m['id']:<40} {'✅ Available':<15}")
print()
print(f"Total: {len(available)} model(s)")
print(f"Max runs per model: $MAX_RUNS")
print(f"Dry-run: $DRY_RUN")
PYEOF

echo ""

# --- Dry-run check ---
if [ "$DRY_RUN" = true ]; then
  info "DRY-RUN mode: Không gọi model, chỉ kiểm tra"
  echo ""
  echo "Task schemas:"
  if [ -d "${KIT_DIR}/evals/tasks" ]; then
    for f in "${KIT_DIR}/evals/tasks"/*.json; do
      [ -f "$f" ] || continue
      local task_name
      task_name=$(basename "$f" .json)
      echo "  - $task_name"
    done
  else
    echo "  Không tìm thấy task files"
  fi
  echo ""
  info "DRY_RUN — Không tiêu thụ quota"
  exit 0
fi

# --- Create safe eval project ---
mkdir -p "$SAFE_EVAL_PROJECT"
cd "$SAFE_EVAL_PROJECT"

if [ ! -f "package.json" ]; then
  cat > package.json << 'EOF'
{
  "name": "opk-eval-project",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "test": "echo 'All tests passed'",
    "build": "echo 'Build successful'",
    "lint": "echo 'Lint passed'",
    "typecheck": "echo 'Typecheck passed'"
  }
}
EOF
fi

# --- Run benchmark ---
header "Benchmarking"

RESULTS_FILE="${RESULTS_DIR}/benchmark-$(date +%Y%m%d-%H%M%S).json"
mkdir -p "$RESULTS_DIR"

# Đọc models
models_to_bench=$(python3 -c "
import json
with open('$CACHE_FILE') as f:
    cache = json.load(f)
models = [m for m in cache.get('models', []) if m.get('availability') == 'available']
if '$TARGET_MODEL':
    models = [m for m in models if m['id'] == '$TARGET_MODEL']
for m in models:
    print(m['id'])
" 2>/dev/null)

total=0
passed=0
failed=0

while IFS= read -r model_id; do
  [ -z "$model_id" ] && continue

  echo ""
  echo -e "${CYAN}Testing: $model_id${NC}"

  model_passed=0
  model_failed=0

  for run in $(seq 1 "$MAX_RUNS"); do
    total=$((total + 1))
    echo -n "  Run $run/$MAX_RUNS: "

    # Gọi opencode run
    start_time=$(date +%s%N)
    output=$(opencode run \
      --model "$model_id" \
      --format json \
      --dir "$SAFE_EVAL_PROJECT" \
      "Write a simple function that returns 42" 2>&1) || {
      end_time=$(date +%s%N)
      latency_ms=$(( (end_time - start_time) / 1000000 ))
      echo -e "${RED}FAIL (${latency_ms}ms)${NC}"
      model_failed=$((model_failed + 1))
      failed=$((failed + 1))
      continue
    }
    end_time=$(date +%s%N)
    latency_ms=$(( (end_time - start_time) / 1000000 ))

    # Kiểm tra output có hợp lệ không
    if echo "$output" | grep -qi "function\|def \|return 42"; then
      echo -e "${GREEN}PASS (${latency_ms}ms)${NC}"
      model_passed=$((model_passed + 1))
      passed=$((passed + 1))
    else
      echo -e "${RED}FAIL (${latency_ms}ms)${NC}"
      model_failed=$((model_failed + 1))
      failed=$((failed + 1))
    fi
  done

  echo -e "  Result: ${GREEN}$model_passed passed${NC}, ${RED}$model_failed failed${NC}"

done <<< "$models_to_bench"

# --- Summary ---
echo ""
header "Benchmark Summary"
echo "  Total runs: $total"
echo -e "  Passed: ${GREEN}$passed${NC}"
echo -e "  Failed: ${RED}$failed${NC}"
echo ""

if [ "$failed" -gt 0 ]; then
  exit 1
fi
