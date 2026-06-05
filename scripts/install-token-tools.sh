#!/usr/bin/env bash

# ============================================================================
# OpenCode Power Kit - Install Token Optimization Tools
# Kiểm tra và hướng dẫn cài rtk (Rust Token Killer) + tokscale
# KHÔNG sudo, KHÔNG tự chạy curl|sh, KHÔNG bắt buộc cài.
# ============================================================================
set -euo pipefail

# --- Colors ---
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

# --- Safety ---
if [ "$(id -u)" -eq 0 ]; then
	err "Không chạy với sudo."
fi

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPORT_FILE="$KIT_DIR/TOKEN_TOOLS_REPORT.md"

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - Token Tools Check"
echo "  (rtk, tokscale - không bắt buộc)"
echo "=========================================="
echo ""

# --- Detect ---
RTK_OK=false
TOKSCALE_OK=false
RTK_PATH=""
TOKSCALE_PATH=""

if command -v rtk &>/dev/null; then
	RTK_PATH="$(command -v rtk)"
	RTK_OK=true
	ok "rtk: tìm thấy tại $RTK_PATH"
else
	warn "rtk: CHƯA CÓ"
fi

if command -v tokscale &>/dev/null; then
	TOKSCALE_PATH="$(command -v tokscale)"
	TOKSCALE_OK=true
	ok "tokscale: tìm thấy tại $TOKSCALE_PATH"
else
	warn "tokscale: CHƯA CÓ"
fi

# --- Optional: ask before installing ---
ASK_INSTALL=false
if [ "$RTK_OK" = false ] || [ "$TOKSCALE_OK" = false ]; then
	if [ -t 0 ]; then
		# Interactive shell - ask
		echo ""
		read -r -p "Bạn có muốn xem hướng dẫn cài ngay bây giờ? [y/N] " REPLY
		case "$REPLY" in
		[yY] | [yY][eE][sS]) ASK_INSTALL=true ;;
		*) warn "Bỏ qua. Xem TOKEN_TOOLS_REPORT.md để biết chi tiết." ;;
		esac
	fi
fi

# --- Print install hints (never auto-run curl|sh) ---
print_hints() {
	echo ""
	info "=== Hướng dẫn cài thủ công (KHÔNG tự động chạy) ==="
	echo ""
	if [ "$RTK_OK" = false ]; then
		info "rtk (Rust Token Killer - giảm 40-60% output token):"
		echo "    cargo install rtk"
		echo "    # hoặc xem: https://github.com/rtk-ai/rtk"
		echo ""
	fi
	if [ "$TOKSCALE_OK" = false ]; then
		info "tokscale (theo dõi token usage):"
		echo "    cargo install tokscale"
		echo "    # hoặc: npm i -g tokscale  (nếu có npm package)"
		echo ""
	fi
	echo "  Power Kit KHÔNG tự chạy 'curl ... | sh'."
	echo "  Hãy đọc script trước khi chạy."
}

if [ "$ASK_INSTALL" = true ]; then
	print_hints
fi

# --- Generate report ---
cat >"$REPORT_FILE" <<EOF
# Token Tools Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Power Kit:** $KIT_DIR

## Trạng thái

| Tool | Có sẵn | Đường dẫn |
|------|--------|----------|
| rtk | $([ "$RTK_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${RTK_PATH:-N/A} |
| tokscale | $([ "$TOKSCALE_OK" = true ] && echo "✅ Có" || echo "❌ Chưa") | ${TOKSCALE_PATH:-N/A} |

## Tại sao nên dùng

- **rtk** (Rust Token Killer): proxy/runner giảm 40-60% token output cho cargo, git, ls, cat, rg, fd, kubectl, docker, ...
- **tokscale**: vẽ bar chart token usage theo model/project, giúp phát hiện request tốn token.

## Cài thủ công (nếu muốn)

### rtk
\`\`\`bash
# Cần Rust/cargo
cargo install rtk
# Repo: https://github.com/rtk-ai/rtk
\`\`\`

### tokscale
\`\`\`bash
# Cần Rust/cargo hoặc npm
cargo install tokscale
# Repo: https://github.com/hasansezertasan/tokscale
\`\`\`

## Cú pháp dùng

Sau khi cài, dùng thay cho lệnh thường:

\`\`\`bash
# Thay vì:
ls -la
git status
cargo test

# Dùng:
rtk ls
rtk git status
rtk cargo test
\`\`\`

Hoặc alias trong ~/.bashrc:
\`\`\`bash
alias ls='rtk ls'
alias cat='rtk cat'
alias rg='rtk rg'
\`\`\`

## Power Kit không tự cài

- Không \`sudo\`.
- Không \`curl ... | sh\` tự động.
- Không bắt buộc — project chạy tốt không cần rtk/tokscale.
- Script này chỉ kiểm tra và in hướng dẫn.

## Bước tiếp theo

1. Nếu muốn cài: đọc repo chính thức trước, tự cài thủ công.
2. Nếu đã cài: dùng command \`/rtk-gain\` trong OpenCode để chạy \`rtk gain\`.
3. Chạy lại script này bất kỳ lúc nào để kiểm tra lại.
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}=========================================="
echo -e "  ✅ Kiểm tra hoàn tất (không cài gì cả)"
echo -e "==========================================${NC}"
echo ""
info "Report: $REPORT_FILE"
if [ "$RTK_OK" = false ] || [ "$TOKSCALE_OK" = false ]; then
	info "Đọc report để biết cách cài thủ công."
fi
