#!/usr/bin/env bash
# ============================================================================
# opk-model-discover.sh — Free-model discovery and caching
# Tự phát hiện model free từ opencode CLI, lưu cache an toàn.
#
# Usage:
#   bash scripts/opk-model-discover.sh                # discover + cache
#   bash scripts/opk-model-discover.sh --list-only    # hiển thị cache
#   bash scripts/opk-model-discover.sh --status       # trạng thái
#   bash scripts/opk-model-discover.sh --refresh      # refresh cache
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Cache location — không commit, add vào .gitignore
CACHE_DIR="${KIT_DIR}/.opencode"
CACHE_FILE="${CACHE_DIR}/opk-free-models.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helpers ---
err()   { echo "opk model: $*" >&2; exit 1; }
warn()  { echo -e "${YELLOW}opk model: $*${NC}" >&2; }
info()  { echo -e "${GREEN}opk model: $*${NC}"; }
header() { echo -e "${CYAN}━━━ $* ━━━${NC}"; }

# --- FREE_ONLY mode check ---
FREE_ONLY="${OPK_FREE_ONLY:-0}"

check_free_only() {
  if [ "$FREE_ONLY" = "1" ]; then
    info "FREE_ONLY mode: chỉ dùng model free"
  fi
}

# --- Detect opencode CLI ---
detect_opencode() {
  if ! command -v opencode >/dev/null 2>&1; then
    err "opencode CLI không tìm thấy. Hãy cài opencode trước."
  fi
}

# --- Discover free models ---
discover_models() {
  header "Phát hiện model free"

  detect_opencode
  check_free_only

  # Refresh và lấy danh sách model
  local models_output
  models_output=$(opencode models --refresh --verbose 2>&1) || {
    err "Không thể chạy opencode models. Lỗi: $models_output"
  }

  # Parse free models — tìm các model có free/zero price
  local free_models
  free_models=$(echo "$models_output" | python3 -c "
import json, sys, re
from datetime import datetime

output = sys.stdin.read()
models = []

# Parse output từ opencode models
# Tìm các dòng có free/zero/$0.00
for line in output.split('\n'):
    line = line.strip()
    if not line:
        continue

    # Parse format: provider/model-id [free] [available/unavailable]
    match = re.match(r'^(\S+)\s+(.*)', line)
    if match:
        model_id = match.group(1)
        rest = match.group(2).lower()

        # Kiểm tra free
        is_free = any(keyword in rest for keyword in ['free', 'zero', '\$0.00', '0.00'])

        # Kiểm tra availability
        is_available = 'unavailable' not in rest

        if is_free:
            models.append({
                'id': model_id,
                'free': True,
                'availability': 'available' if is_available else 'unavailable',
                'evidence': 'free label from CLI'
            })

result = {
    'generated_at': datetime.utcnow().isoformat() + 'Z',
    'source': 'opencode models --refresh --verbose',
    'free_only': $( [ "$FREE_ONLY" = "1" ] && echo "true" || echo "false" ),
    'models': models,
    'total_free': len(models),
    'available_free': len([m for m in models if m['availability'] == 'available'])
}

print(json.dumps(result, indent=2))
" 2>/dev/null) || {
    err "Không thể parse danh sách model"
  }

  # Lưu cache
  mkdir -p "$CACHE_DIR"
  echo "$free_models" > "$CACHE_FILE"

  # Hiển thị kết quả
  local total available
  total=$(echo "$free_models" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total_free', 0))" 2>/dev/null)
  available=$(echo "$free_models" | python3 -c "import json,sys; print(json.load(sys.stdin).get('available_free', 0))" 2>/dev/null)

  info "Tìm thấy $total model free ($available available)"
  info "Cache lưu tại: $CACHE_FILE"

  # Hiển thị danh sách
  echo ""
  echo "$free_models" | python3 -c "
import json, sys

data = json.load(sys.stdin)
models = data.get('models', [])

if not models:
    print('  Không tìm thấy model free nào')
else:
    print(f'  {\"MODEL ID\":<40} {\"STATUS\":<15} {\"EVIDENCE\"}')
    print(f'  {\"─\"*40} {\"─\"*15} {\"─\"*30}')
    for m in models:
        status = '✅ Available' if m['availability'] == 'available' else '❌ Unavailable'
        print(f'  {m[\"id\"]:<40} {status:<15} {m[\"evidence\"]}')
" 2>/dev/null
}

# --- List cached models ---
list_cached_models() {
  header "Danh sách free model (cached)"

  if [ ! -f "$CACHE_FILE" ]; then
    warn "Chưa có cache. Chạy: opk model discover-free"
    return 1
  fi

  cat "$CACHE_FILE" | python3 -c "
import json, sys

data = json.load(sys.stdin)
models = data.get('models', [])
generated = data.get('generated_at', 'unknown')

print(f'  Generated: {generated}')
print(f'  Total free: {data.get(\"total_free\", 0)}')
print(f'  Available free: {data.get(\"available_free\", 0)}')
print()

if not models:
    print('  Không có model free nào trong cache')
else:
    print(f'  {\"MODEL ID\":<40} {\"STATUS\":<15} {\"EVIDENCE\"}')
    print(f'  {\"─\"*40} {\"─\"*15} {\"─\"*30}')
    for m in models:
        status = '✅' if m['availability'] == 'available' else '❌'
        print(f'  {m[\"id\"]:<40} {status:<15} {m[\"evidence\"]}')
" 2>/dev/null
}

# --- Show status ---
show_status() {
  header "Free-Model Orchestration Status"

  echo -e "  ${CYAN}Environment:${NC}"
  echo "    OPK_FREE_ONLY=${FREE_ONLY:-0}"

  if [ -f "$CACHE_FILE" ]; then
    echo -e "  ${CYAN}Cache:${NC} $CACHE_FILE"
    cat "$CACHE_FILE" | python3 -c "
import json, sys
data = json.load(sys.stdin)
print(f'    Generated: {data.get(\"generated_at\", \"unknown\")}')
print(f'    Total free: {data.get(\"total_free\", 0)}')
print(f'    Available free: {data.get(\"available_free\", 0)}')
" 2>/dev/null
  else
    echo -e "  ${CYAN}Cache:${NC} Chưa có (chạy opk model discover-free)"
  fi

  echo ""
  echo -e "  ${CYAN}OpenCode CLI:${NC}"
  if command -v opencode >/dev/null 2>&1; then
    echo "    Status: ✅ Installed"
  else
    echo "    Status: ❌ Not found"
  fi

  echo ""
  echo -e "  ${CYAN}Commands:${NC}"
  echo "    opk model discover-free   Phát hiện model free"
  echo "    opk model list-free       Xem danh sách cached"
  echo "    opk model refresh         Refresh cache"
  echo "    opk model status          Xem trạng thái này"
}

# --- Refresh cache ---
refresh_cache() {
  header "Refresh cache model free"
  discover_models
}

# --- Main ---
case "${1:-}" in
  --list-only)
    list_cached_models
    ;;
  --status)
    show_status
    ;;
  --refresh)
    refresh_cache
    ;;
  *)
    discover_models
    ;;
esac
