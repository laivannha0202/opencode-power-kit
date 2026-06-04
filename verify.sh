#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Verify Script
# Kiểm tra project đã được cài đặt đúng chưa
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

# Check no secrets
for f in .env .env.local .env.production; do
  if [ -f "$f" ]; then
    echo -e "  ${RED}❌${NC} CẢNH BÁO: $f tồn tại — đừng commit!"
    SAFE=false
  fi
done

# Check no tokens in opencode.json
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
