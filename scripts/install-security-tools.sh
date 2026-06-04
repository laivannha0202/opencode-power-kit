#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Security Tools Check (optional)
# Detect gitleaks / trufflehog / semgrep. In hướng dẫn cài nếu thiếu.
# KHÔNG sudo, KHÔNG tự cài, KHÔNG curl|sh.
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
REPORT_FILE="$KIT_DIR/SECURITY_TOOLS_REPORT.md"

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - Security Tools"
echo "  (gitleaks, trufflehog, semgrep)"
echo "=========================================="
echo ""

GITLEAKS_OK=false
TRUFFLEHOG_OK=false
SEMGREP_OK=false
GITLEAKS_PATH=""
TRUFFLEHOG_PATH=""
SEMGREP_PATH=""

if command -v gitleaks &>/dev/null; then
  GITLEAKS_PATH="$(command -v gitleaks)"
  GITLEAKS_OK=true
  ok "gitleaks:    tìm thấy tại $GITLEAKS_PATH"
else
  warn "gitleaks:   CHƯA CÓ"
fi

if command -v trufflehog &>/dev/null; then
  TRUFFLEHOG_PATH="$(command -v trufflehog)"
  TRUFFLEHOG_OK=true
  ok "trufflehog: tìm thấy tại $TRUFFLEHOG_PATH"
else
  warn "trufflehog: CHƯA CÓ"
fi

if command -v semgrep &>/dev/null; then
  SEMGREP_PATH="$(command -v semgrep)"
  SEMGREP_OK=true
  ok "semgrep:    tìm thấy tại $SEMGREP_PATH"
else
  warn "semgrep:    CHƯA CÓ"
fi

echo ""
info "=== Hướng dẫn cài thủ công (KHÔNG tự động chạy) ==="
echo ""

if [ "$GITLEAKS_OK" = false ]; then
  info "gitleaks (secret scan):"
  echo "    brew install gitleaks"
  echo "    # hoặc: https://github.com/gitleaks/gitleaks/releases"
  echo ""
fi

if [ "$TRUFFLEHOG_OK" = false ]; then
  info "trufflehog (secret scan, có verify):"
  echo "    brew install trufflehog"
  echo "    # hoặc: go install github.com/trufflehog/trufflehog/v3/...@latest"
  echo ""
fi

if [ "$SEMGREP_OK" = false ]; then
  info "semgrep (SAST):"
  echo "    pip install semgrep"
  echo "    # hoặc: brew install semgrep"
  echo "    # docs: https://semgrep.dev/docs/getting-started"
  echo ""
fi

# --- Generate report ---
cat > "$REPORT_FILE" << EOF
# Security Tools Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Power Kit:** $KIT_DIR

## Trạng thái

| Tool | Có sẵn | Đường dẫn | Mục đích |
|------|--------|----------|---------|
| gitleaks | $([ "$GITLEAKS_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${GITLEAKS_PATH:-N/A} | Quét secret pattern trong git history + working tree |
| trufflehog | $([ "$TRUFFLEHOG_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${TRUFFLEHOG_PATH:-N/A} | Quét secret, có verify bằng API provider |
| semgrep | $([ "$SEMGREP_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${SEMGREP_PATH:-N/A} | SAST cho nhiều ngôn ngữ |

## Cài thủ công (nếu muốn)

### gitleaks

\`\`\`bash
brew install gitleaks
# hoặc tải binary từ GitHub release:
# https://github.com/gitleaks/gitleaks/releases
\`\`\`

### trufflehog

\`\`\`bash
brew install trufflehog
# hoặc
go install github.com/trufflehog/trufflehog/v3/...@latest
\`\`\`

### semgrep

\`\`\`bash
pip install semgrep
# hoặc
brew install semgrep
\`\`\`

## Cách dùng

### gitleaks

\`\`\`bash
gitleaks detect --source . --no-banner -v
gitleaks protect --source . --no-banner      # scan staged changes
\`\`\`

### trufflehog

\`\`\`bash
trufflehog filesystem --directory=. --no-verification
trufflehog git file://. --since-commit HEAD~10
\`\`\`

### semgrep

\`\`\`bash
semgrep --config=auto .                              # auto detect stack
semgrep --config=p/typescript --config=p/jwt .       # specific rules
\`\`\`

## Power Kit không tự cài

- Không sudo.
- Không \`curl ... | sh\` tự động.
- Không bắt buộc — project chạy tốt không cần các tool này.
- Script chỉ kiểm tra và in hướng dẫn.

## Trong OpenCode

- \`/secret-scan\` — chạy gitleaks/trufflehog/grep.
- \`/sast-check\` — chạy semgrep.

## Bước tiếp theo

1. Nếu muốn cài: đọc repo chính thức trước, tự cài thủ công.
2. Nếu đã cài: dùng command \`/secret-scan\` hoặc \`/sast-check\` trong OpenCode.
3. Chạy lại script này bất kỳ lúc nào để kiểm tra lại.
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}=========================================="
echo -e "  ✅ Kiểm tra security tools xong"
echo -e "==========================================${NC}"
echo ""
info "Report: $REPORT_FILE"
