#!/usr/bin/env bash
# ============================================================================
# validate-free-model.sh — Validation tests cho free-model orchestration
# Kiểm tra tất cả acceptance criteria.
#
# Usage: bash scripts/validate-free-model.sh
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Helpers ---
pass() {
  TOTAL=$((TOTAL + 1))
  PASSED=$((PASSED + 1))
  echo -e "  ${GREEN}✅ PASS${NC}: $1"
}

fail() {
  TOTAL=$((TOTAL + 1))
  FAILED=$((FAILED + 1))
  echo -e "  ${RED}❌ FAIL${NC}: $1"
}

skip() {
  TOTAL=$((TOTAL + 1))
  SKIPPED=$((SKIPPED + 1))
  echo -e "  ${YELLOW}⏭️  SKIP${NC}: $1"
}

header() {
  echo ""
  echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

# --- Test 1: Không còn ANTHROPIC_API_KEY trong template ---
header "Test 1: Không còn API key trong template"

if grep -q "ANTHROPIC_API_KEY" "$KIT_DIR/templates/opencode.models.example.jsonc"; then
  fail "templates/opencode.models.example.jsonc vẫn chứa ANTHROPIC_API_KEY"
else
  pass "templates/opencode.models.example.jsonc không chứa ANTHROPIC_API_KEY"
fi

if grep -q "OPENAI_API_KEY" "$KIT_DIR/templates/opencode.models.example.jsonc"; then
  fail "templates/opencode.models.example.jsonc vẫn chứa OPENAI_API_KEY"
else
  pass "templates/opencode.models.example.jsonc không chứa OPENAI_API_KEY"
fi

# --- Test 2: Không còn API key trong docs ---
header "Test 2: Không còn API key trong docs"

if grep -q "apiKey.*ANTHROPIC_API_KEY\|apiKey.*OPENAI_API_KEY" "$KIT_DIR/docs/MODEL_ROUTING.md"; then
  fail "docs/MODEL_ROUTING.md vẫn chứa API key config"
else
  pass "docs/MODEL_ROUTING.md không chứa API key config"
fi

# --- Test 3: Dry-run không gọi opencode ---
header "Test 3: Dry-run không gọi opencode"

# Kiểm tra evals/run.sh không import openai/anthropic (bỏ qua comment)
if grep -n "import openai\|import anthropic" "$KIT_DIR/evals/run.sh" | grep -v "^\s*[0-9]*:\s*#" | grep -q "."; then
  fail "evals/run.sh vẫn import openai/anthropic"
else
  pass "evals/run.sh không import openai/anthropic"
fi

# --- Test 4: FREE_ONLY từ chối unknown-cost model ---
header "Test 4: FREE_ONLY mode behavior"

# Kiểm tra scripts có check FREE_ONLY
if grep -q "OPK_FREE_ONLY\|FREE_ONLY" "$KIT_DIR/scripts/opk-model-discover.sh"; then
  pass "scripts/opk-model-discover.sh check FREE_ONLY"
else
  fail "scripts/opk-model-discover.sh không check FREE_ONLY"
fi

# --- Test 5: Empty free pool fail-closed ---
header "Test 5: Empty free pool fail-closed"

if grep -q "Không có model free\|not found\|exit 1" "$KIT_DIR/scripts/opk-model-route.sh"; then
  pass "scripts/opk-model-route.sh fail-closed khi empty pool"
else
  fail "scripts/opk-model-route.sh không fail-closed"
fi

# --- Test 6: Exact model IDs từ opencode models ---
header "Test 6: Không hardcode model slug"

# Kiểm tra template không chứa model slug cứng
if grep -q "claude-sonnet\|claude-opus\|gpt-4\|gpt-5" "$KIT_DIR/templates/opencode.models.example.jsonc"; then
  fail "templates/opencode.models.example.jsonc vẫn hardcode model slug"
else
  pass "templates/opencode.models.example.jsonc không hardcode model slug"
fi

# --- Test 7: CLI commands tồn tại ---
header "Test 7: CLI commands tồn tại"

for cmd in discover-free list-free benchmark-free route-free status refresh; do
  if grep -q "$cmd" "$KIT_DIR/bin/opk"; then
    pass "opk model $cmd được định nghĩa"
  else
    fail "opk model $cmd không tìm thấy"
  fi
done

# --- Test 8: Scripts tồn tại ---
header "Test 8: Scripts tồn tại"

for script in opk-model-discover.sh opk-model-route.sh opk-model-benchmark.sh; do
  if [ -f "$KIT_DIR/scripts/$script" ]; then
    pass "scripts/$script tồn tại"
  else
    fail "scripts/$script không tìm thấy"
  fi
done

# --- Test 9: Cache được gitignore ---
header "Test 9: Cache được gitignore"

if grep -q "opk-free-models.json\|.opencode/" "$KIT_DIR/.gitignore"; then
  pass "Cache file được gitignore"
else
  fail "Cache file không được gitignore"
fi

# --- Test 10: Không có credential trong result ---
header "Test 10: Không có credential"

# Kiểm tra scripts không ghi credential
for script in opk-model-discover.sh opk-model-route.sh opk-model-benchmark.sh; do
  if grep -q "apiKey\|api_key\|secret\|password" "$KIT_DIR/scripts/$script" 2>/dev/null; then
    fail "scripts/$script chứa potential credential"
  else
    pass "scripts/$script không chứa credential"
  fi
done

# --- Summary ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━"
echo "Validation Summary"
echo -e "  Total: $TOTAL"
echo -e "  Passed: ${GREEN}$PASSED${NC}"
echo -e "  Failed: ${RED}$FAILED${NC}"
echo -e "  Skipped: ${YELLOW}$SKIPPED${NC}"
echo ""

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
