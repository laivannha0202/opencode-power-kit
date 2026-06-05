#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - API Tools Check (optional)
# Detect spectral, oasdiff, openapi-generator. In hướng dẫn cài nếu thiếu.
# KHÔNG sudo, KHÔNG tự cài, KHÔNG curl|sh.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() {
	echo -e "${RED}[ERROR]${NC} $*"
	exit 1
}

if [ "$(id -u)" -eq 0 ]; then
	err "Không chạy với sudo/root."
fi

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_FILE="$KIT_DIR/API_TOOLS_REPORT.md"

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - API Tools"
echo "  (spectral, oasdiff, openapi-generator)"
echo "=========================================="
echo ""

SPECTRAL_OK=false
OASDIFF_OK=false
OPENAPI_GEN_OK=false
SPECTRAL_PATH=""
OASDIFF_PATH=""
OPENAPI_GEN_PATH=""

if command -v spectral &>/dev/null; then
	SPECTRAL_PATH="$(command -v spectral)"
	SPECTRAL_OK=true
	ok "spectral:           tìm thấy tại $SPECTRAL_PATH"
else
	warn "spectral:           CHƯA CÓ"
fi

if command -v oasdiff &>/dev/null; then
	OASDIFF_PATH="$(command -v oasdiff)"
	OASDIFF_OK=true
	ok "oasdiff:            tìm thấy tại $OASDIFF_PATH"
else
	warn "oasdiff:            CHƯA CÓ"
fi

if command -v openapi-generator-cli &>/dev/null; then
	OPENAPI_GEN_PATH="$(command -v openapi-generator-cli)"
	OPENAPI_GEN_OK=true
	ok "openapi-generator:  tìm thấy tại $OPENAPI_GEN_PATH"
elif command -v openapi-generator &>/dev/null; then
	OPENAPI_GEN_PATH="$(command -v openapi-generator)"
	OPENAPI_GEN_OK=true
	ok "openapi-generator:  tìm thấy tại $OPENAPI_GEN_PATH"
else
	warn "openapi-generator:  CHƯA CÓ"
fi

echo ""
info "=== Hướng dẫn cài thủ công (KHÔNG tự động chạy) ==="
echo ""

if [ "$SPECTRAL_OK" = false ]; then
	info "spectral (OpenAPI lint):"
	echo "    npm i -g @stoplight/spectral-cli"
	echo "    # docs: https://stoplight.io/open-source/spectral"
	echo ""
fi

if [ "$OASDIFF_OK" = false ]; then
	info "oasdiff (so sánh OpenAPI version, phát hiện breaking change):"
	echo "    brew install oasdiff"
	echo "    # hoặc: go install github.com/oasdiff/oasdiff/cmd/oasdiff@latest"
	echo "    # docs: https://github.com/oasdiff/oasdiff"
	echo ""
fi

if [ "$OPENAPI_GEN_OK" = false ]; then
	info "openapi-generator (generate client từ OpenAPI):"
	echo "    npm i -g @openapitools/openapi-generator-cli"
	echo "    # hoặc: brew install openapi-generator"
	echo "    # docs: https://openapi-generator.tech"
	echo ""
fi

# --- Generate report ---
cat >"$REPORT_FILE" <<EOF
# API Tools Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Power Kit:** $KIT_DIR

## Trạng thái

| Tool | Có sẵn | Đường dẫn | Mục đích |
|------|--------|----------|---------|
| spectral | $([ "$SPECTRAL_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${SPECTRAL_PATH:-N/A} | Lint OpenAPI spec |
| oasdiff | $([ "$OASDIFF_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${OASDIFF_PATH:-N/A} | Diff OpenAPI, phát hiện breaking change |
| openapi-generator | $([ "$OPENAPI_GEN_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${OPENAPI_GEN_PATH:-N/A} | Generate client (TS, Java, Go, ...) |

## Cài thủ công (nếu muốn)

### spectral

\`\`\`bash
npm i -g @stoplight/spectral-cli
spectral lint openapi.yaml --ruleset templates/openapi/spectral.yaml.example
\`\`\`

### oasdiff

\`\`\`bash
brew install oasdiff
# hoặc
go install github.com/oasdiff/oasdiff/cmd/oasdiff@latest
oasdiff diff openapi-v1.yaml openapi-v2.yaml
\`\`\`

### openapi-generator

\`\`\`bash
npm i -g @openapitools/openapi-generator-cli
openapi-generator-cli generate -i openapi.yaml -g typescript-axios -o ./clients/ts
\`\`\`

## Power Kit không tự cài

- Không sudo.
- Không \`curl ... | sh\` tự động.
- Không bắt buộc.

## Trong OpenCode

- \`/openapi-check\` — chạy spectral + oasdiff nếu có.
- \`/api-contract-review\` — review contract thủ công.

## Bước tiếp theo

1. Nếu muốn cài: đọc repo chính thức trước, tự cài thủ công.
2. Nếu đã cài: dùng command \`/openapi-check\` trong OpenCode.
3. Chạy lại script này bất kỳ lúc nào để kiểm tra lại.
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}=========================================="
echo -e "  ✅ Kiểm tra API tools xong"
echo -e "==========================================${NC}"
echo ""
info "Report: $REPORT_FILE"
