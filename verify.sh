#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Verify Script
# Kiểm tra project và global config đã được cài đặt đúng chưa
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
  local desc="$1" path="$2"
  if [ -e "$path" ]; then
    echo -e "  ${GREEN}✅${NC} $desc"
    ((PASS++))
  else
    echo -e "  ${RED}❌${NC} $desc — KHÔNG TÌM THẤY: $path"
    ((FAIL++))
  fi
}

check_warn() {
  local desc="$1" path="$2"
  if [ -e "$path" ]; then
    echo -e "  ${GREEN}✅${NC} $desc"
    ((PASS++))
  else
    echo -e "  ${YELLOW}⚠️${NC} $desc — không bắt buộc: $path"
    ((WARN++))
  fi
}

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - Verify"
echo "  Project: $(pwd)"
echo "=========================================="
echo ""

# --- Global config checks ---
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$KIT_DIR/opencode-global"

echo "🌍 Global config (opencode-global/):"
check "OPENCODE_CONFIG_DIR env in ~/.bashrc" "$HOME/.bashrc"
if grep -qF 'OPENCODE_CONFIG_DIR' "$HOME/.bashrc" 2>/dev/null; then
  echo -e "  ${GREEN}✅${NC} OPENCODE_CONFIG_DIR đã set trong ~/.bashrc"
  ((PASS++))
else
  echo -e "  ${RED}❌${NC} OPENCODE_CONFIG_DIR chưa set trong ~/.bashrc"
  ((FAIL++))
fi

echo ""
echo "📁 Global agents:"
check "plan-lite.md" "$GLOBAL_DIR/agents/plan-lite.md"
check "review-lite.md" "$GLOBAL_DIR/agents/review-lite.md"
check "debug-lite.md" "$GLOBAL_DIR/agents/debug-lite.md"
check "build-strong.md" "$GLOBAL_DIR/agents/build-strong.md"

echo ""
echo "📁 Global commands:"
check "smart-scan.md" "$GLOBAL_DIR/commands/smart-scan.md"
check "bugfix-safe.md" "$GLOBAL_DIR/commands/bugfix-safe.md"
check "review-diff.md" "$GLOBAL_DIR/commands/review-diff.md"
check "repo-map.md" "$GLOBAL_DIR/commands/repo-map.md"
check "token-pack.md" "$GLOBAL_DIR/commands/token-pack.md"
check "db-readonly.md" "$GLOBAL_DIR/commands/db-readonly.md"

echo ""
echo "📁 Global skills:"
check "token-smart-code/SKILL.md" "$GLOBAL_DIR/skills/token-smart-code/SKILL.md"
check "serena-first/SKILL.md" "$GLOBAL_DIR/skills/serena-first/SKILL.md"
check "safe-edit/SKILL.md" "$GLOBAL_DIR/skills/safe-edit/SKILL.md"
check "repo-map/SKILL.md" "$GLOBAL_DIR/skills/repo-map/SKILL.md"
check "js-ts-project/SKILL.md" "$GLOBAL_DIR/skills/js-ts-project/SKILL.md"

echo ""
echo "🔧 External tools:"
for tool in repomix rg fd ast-grep serena; do
  if command -v "$tool" &>/dev/null; then
    echo -e "  ${GREEN}✅${NC} $tool"
    ((PASS++))
  else
    echo -e "  ${YELLOW}⚠️${NC} $tool — không tìm thấy (không bắt buộc)"
    ((WARN++))
  fi
done

# --- Per-project checks ---
echo ""
echo "=========================================="
echo "  Per-project: $(pwd)"
echo "=========================================="
echo ""

echo "📁 Files bắt buộc:"
check "AGENTS.md" "AGENTS.md"
check "OPENCODE.md" "OPENCODE.md"
check ".opencode/opencode.json" ".opencode/opencode.json"

echo ""
echo "📁 Files tùy chọn:"
check_warn "knip.json" "knip.json"
check_warn "lefthook.yml" "lefthook.yml"

echo ""
echo "📁 Gitignore:"
if [ -f ".gitignore" ]; then
  if grep -qF "# >>> opencode-power-kit" .gitignore 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} .gitignore có nội dung Power Kit"
    ((PASS++))
  else
    echo -e "  ${YELLOW}⚠️${NC} .gitignore chưa có nội dung Power Kit"
    ((WARN++))
  fi
else
  echo -e "  ${RED}❌${NC} .gitignore không tồn tại"
  ((FAIL++))
fi

echo ""
echo "📦 opencode.json content:"
if [ -f ".opencode/opencode.json" ]; then
  if grep -q "superpowers" .opencode/opencode.json 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} Có superpowers plugin"
    ((PASS++))
  else
    echo -e "  ${RED}❌${NC} Thiếu superpowers plugin"
    ((FAIL++))
  fi
  if grep -q "AGENTS.md" .opencode/opencode.json 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} Có AGENTS.md instruction"
    ((PASS++))
  else
    echo -e "  ${RED}❌${NC} Thiếu AGENTS.md instruction"
    ((FAIL++))
  fi
fi

echo ""
echo "🔐 Safety check:"
SAFE=true

for f in .env .env.local .env.production; do
  if [ -f "$f" ]; then
    echo -e "  ${RED}❌${NC} CẢNH BÁO: $f tồn tại — đừng commit!"
    SAFE=false
  fi
done

if [ -f ".opencode/opencode.json" ]; then
  if grep -qiE "(token|password|secret|api_key)" .opencode/opencode.json 2>/dev/null; then
    echo -e "  ${RED}❌${NC} opencode.json có chứa token/password — KIỂM TRA LẠI!"
    SAFE=false
  fi
fi

if [ "$SAFE" = true ]; then
  echo -e "  ${GREEN}✅${NC} Không phát hiện secrets"
  ((PASS++))
fi

echo ""
echo "=========================================="
echo "  Kết quả: ${GREEN}$PASS pass${NC} | ${RED}$FAIL fail${NC} | ${YELLOW}$WARN warn${NC}"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo -e "${RED}❌ Có $FAIL lỗi. Hãy chạy lại install hoặc kiểm tra thủ công.${NC}"
  exit 1
else
  echo ""
  echo -e "${GREEN}✅ Project đã sẵn sàng với OpenCode Power Kit!${NC}"
fi
