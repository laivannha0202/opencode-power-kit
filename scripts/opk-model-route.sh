#!/usr/bin/env bash
# ============================================================================
# opk-model-route.sh — Free-model routing
# Tạo config routing từ danh sách free model đã discover.
#
# Usage:
#   bash scripts/opk-model-route.sh                  # tạo config
#   bash scripts/opk-model-route.sh --output <file>  # ghi ra file cụ thể
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

CACHE_DIR="${KIT_DIR}/.opencode"
CACHE_FILE="${CACHE_DIR}/opk-free-models.json"
OUTPUT_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helpers ---
err()   { echo "opk model route: $*" >&2; exit 1; }
info()  { echo -e "${GREEN}opk model route: $*${NC}"; }
header() { echo -e "${CYAN}━━━ $* ━━━${NC}"; }

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --output|-o)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: opk model route-free [--output <file>]"
      echo ""
      echo "Tạo opencode config với free-model routing."
      echo "Output: opencode.json hoặc file chỉ định."
      exit 0
      ;;
    *)
      err "flag không hợp lệ: $1"
      ;;
  esac
done

# --- Check cache ---
if [ ! -f "$CACHE_FILE" ]; then
  err "Chưa có cache model free. Chạy: opk model discover-free"
fi

# --- Parse free models và tạo routing ---
header "Tạo free-model routing config"

python3 << 'PYEOF'
import json, sys, os

cache_file = os.environ.get("CACHE_FILE", "")
output_file = os.environ.get("OUTPUT_FILE", "")

with open(cache_file) as f:
    cache = json.load(f)

models = cache.get("models", [])
available = [m for m in models if m.get("availability") == "available"]

if not available:
    print("Không có model free available. Chạy: opk model discover-free", file=sys.stderr)
    sys.exit(1)

# Phân loại model theo capability (dựa trên tên)
best_model = available[0]["id"]
second_model = available[1]["id"] if len(available) > 1 else available[0]["id"]
third_model = available[2]["id"] if len(available) > 2 else available[0]["id"]

# Tạo config
config = {
    "$schema": "https://opencode.ai/config.json",
    "model": best_model,
    "agent": {
        "build": {
            "mode": "primary",
            "model": best_model
        },
        "explore": {
            "mode": "subagent",
            "model": second_model
        },
        "build-strong": {
            "mode": "primary",
            "model": best_model
        },
        "debug-strong": {
            "mode": "all",
            "model": third_model
        }
    }
}

# Output
if output_file:
    with open(output_file, "w") as f:
        json.dump(config, f, indent=2)
    print(f"Config saved to: {output_file}")
else:
    print(json.dumps(config, indent=2))

# Hiển thị routing table
print()
print("Free-Model Routing:")
print(f"  {'ROLE':<20} {'MODEL':<40}")
print(f"  {'─'*20} {'─'*40}")
print(f"  {'default':<20} {best_model:<40}")
print(f"  {'build':<20} {best_model:<40}")
print(f"  {'explore':<20} {second_model:<40}")
print(f"  {'build-strong':<20} {best_model:<40}")
print(f"  {'debug-strong':<20} {third_model:<40}")
PYEOF

info "Routing config đã được tạo"
