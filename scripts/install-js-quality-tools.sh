#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - JS/TS Quality Tools Check (optional)
# Detect eslint, prettier, biome, knip, vitest, tsc.
# In hướng dẫn cài nếu thiếu. KHÔNG sudo, KHÔNG tự cài, KHÔNG curl|sh.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

if [ "$(id -u)" -eq 0 ]; then
  err "Không chạy với sudo/root."
fi

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_FILE="$KIT_DIR/JS_QUALITY_TOOLS_REPORT.md"

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - JS/TS Quality Tools"
echo "  (eslint, prettier, biome, knip, vitest, tsc)"
echo "=========================================="
echo ""

ESLINT_OK=false
PRETTIER_OK=false
BIOME_OK=false
KNIP_OK=false
VITEST_OK=false
TSC_OK=false
ESLINT_PATH=""
PRETTIER_PATH=""
BIOME_PATH=""
KNIP_PATH=""
VITEST_PATH=""
TSC_PATH=""

check() {
  local name="$1"
  local var_ok="$2"
  local var_path="$3"
  local cmd="$4"
  if command -v "$cmd" &>/dev/null; then
    eval "$var_ok=true"
    eval "$var_path=\"$(command -v "$cmd")\""
    ok "$name: tìm thấy tại $(command -v "$cmd")"
  else
    eval "$var_ok=false"
    warn "$name: CHƯA CÓ"
  fi
}

check "eslint"     ESLINT_OK    ESLINT_PATH    "eslint"
check "prettier"   PRETTIER_OK  PRETTIER_PATH  "prettier"
check "biome"      BIOME_OK     BIOME_PATH     "biome"
check "knip"       KNIP_OK      KNIP_PATH      "knip"
check "vitest"     VITEST_OK    VITEST_PATH    "vitest"
check "tsc"        TSC_OK       TSC_PATH       "tsc"

echo ""
info "=== Hướng dẫn cài thủ công (KHÔNG tự động chạy) ==="
echo ""

[ "$ESLINT_OK" = false ] && {
  info "eslint (lint):"
  echo "    npm i -D eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin"
  echo ""
}

[ "$PRETTIER_OK" = false ] && {
  info "prettier (format):"
  echo "    npm i -D prettier"
  echo ""
}

[ "$BIOME_OK" = false ] && {
  info "biome (lint + format, nhanh hơn ESLint+Prettier):"
  echo "    npm i -D @biomejs/biome"
  echo "    # hoặc: cargo install biome"
  echo ""
}

[ "$KNIP_OK" = false ] && {
  info "knip (dead code detection):"
  echo "    npm i -D knip"
  echo ""
}

[ "$VITEST_OK" = false ] && {
  info "vitest (test runner):"
  echo "    npm i -D vitest @vitest/ui"
  echo ""
}

[ "$TSC_OK" = false ] && {
  info "tsc (typecheck):"
  echo "    npm i -D typescript"
  echo "    # hoặc global: npm i -g typescript"
  echo ""
}

# --- Generate report ---
cat > "$REPORT_FILE" << EOF
# JS/TS Quality Tools Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Power Kit:** $KIT_DIR

## Trạng thái

| Tool | Có sẵn | Đường dẫn | Mục đích |
|------|--------|----------|---------|
| eslint | $([ "$ESLINT_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${ESLINT_PATH:-N/A} | Lint TS/JS |
| prettier | $([ "$PRETTIER_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${PRETTIER_PATH:-N/A} | Format code |
| biome | $([ "$BIOME_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${BIOME_PATH:-N/A} | Lint + format, nhanh hơn |
| knip | $([ "$KNIP_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${KNIP_PATH:-N/A} | Phát hiện unused file / export / dep |
| vitest | $([ "$VITEST_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${VITEST_PATH:-N/A} | Test runner |
| tsc | $([ "$TSC_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${TSC_PATH:-N/A} | Typecheck |

## Cài trong project (recommended)

\`\`\`bash
# Lint + format combo (chọn 1)
npm i -D @biomejs/biome                                    # biome (nhanh)
# hoặc
npm i -D eslint prettier eslint-config-prettier            # eslint + prettier

# Dead code
npm i -D knip
cp ~/opencode-power-kit/templates/knip.json ./knip.json

# Test
npm i -D vitest @vitest/ui
# (nếu dùng Vitest) bỏ Jest

# Typecheck
npm i -D typescript
\`\`\`

## Cài global (ít khuyến khích)

\`\`\`bash
npm i -g typescript
npm i -g @biomejs/biome
\`\`\`

## Cú pháp dùng

\`\`\`bash
npx eslint .                           # lint
npx prettier --write .                 # format
npx @biomejs/biome check --write .     # biome lint+format
npx tsc --noEmit                       # typecheck
npx vitest run                         # test
npx knip                               # dead code
\`\`\`

## Power Kit không tự cài

- Không sudo.
- Không \`curl ... | sh\` tự động.
- Không bắt buộc.

## Trong OpenCode

- \`/js-quality-check\` — detect công cụ + đề xuất lệnh.

## Bước tiếp theo

1. Nếu muốn cài: chạy trong project, dùng devDependency (không global).
2. Copy template config từ \`templates/knip.json\`, \`templates/biome.json.example\`, \`templates/lefthook.yml\`.
3. Nếu đã cài: dùng command \`/js-quality-check\` trong OpenCode.
4. Chạy lại script này bất kỳ lúc nào để kiểm tra lại.
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}=========================================="
echo -e "  ✅ Kiểm tra JS/TS quality tools xong"
echo -e "==========================================${NC}"
echo ""
info "Report: $REPORT_FILE"
