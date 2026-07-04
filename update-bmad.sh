#!/usr/bin/env bash

# ============================================================================
# OpenCode Power Kit - Update BMAD
# Cài đặt lại / cập nhật BMAD Method cho project hiện tại
#
# Env overrides:
#   BMAD_METHOD_VERSION  Pin version BMAD (mặc định: 6.9.0)
# ============================================================================
set -euo pipefail

# --- BMAD Method version (env override, default 6.9.0) ---
: "${BMAD_METHOD_VERSION:=6.9.0}"
export BMAD_METHOD_VERSION

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
	echo -e "${BLUE:-}[INFO]${NC} $*"
}
ok() {
	echo -e "${GREEN}[OK]${NC} $*"
}
warn() {
	echo -e "${YELLOW}[WARN]${NC} $*"
}
err() {
	echo -e "${RED}[ERROR]${NC} $*"
	exit 1
}

TARGET_DIR="$(pwd)"
BMAD_LOG="$TARGET_DIR/.opencode-power-bmad-update.log"

# --- User name (env > git config > $USER > "User") ---
OPK_USER_NAME="${OPK_USER_NAME:-$(git config user.name 2>/dev/null || true)}"
OPK_USER_NAME="${OPK_USER_NAME:-${USER:-User}}"

# --- Safety: detect bad project-dir (sync với bootstrap.sh / setup.sh / opk) ---
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME:-/root}"
is_bad_project_dir() {
	local p="${1:-$TARGET_DIR}"
	local p_real
	p_real="$(cd "$p" 2>/dev/null && pwd -P 2>/dev/null || echo "$p")"
	case "$p_real" in "$HOME_DIR" | "$HOME_DIR/" | /) return 0 ;; esac
	case "$p_real" in "$KIT_DIR" | "$KIT_DIR/" | "$KIT_DIR"/*)
		case "$p_real" in "$KIT_DIR"/.tmp | "$KIT_DIR"/.tmp/*) return 1 ;; esac
		case "$p_real" in "$KIT_DIR"/.test | "$KIT_DIR"/.test/*) return 1 ;; esac
		return 0
		;;
	esac
	case "$p_real" in /tmp | /tmp/*) return 0 ;; esac
	case "$p_real" in /var/tmp | /var/tmp/*) return 0 ;; esac
	case "$p_real" in /usr | /usr/*) return 0 ;; esac
	case "$p_real" in /etc | /etc/*) return 0 ;; esac
	return 1
}

if is_bad_project_dir; then
	echo ""
	echo -e "${RED}✗ Từ chối chạy update-bmad.sh trong: $TARGET_DIR${NC}"
	echo "  (HOME / kit / / /tmp / /var/tmp / /usr / /etc đều bị từ chối.)"
	err "Hãy 'cd' vào project thật rồi chạy lại."
fi

if [ ! -f "$TARGET_DIR/.opencode/opencode.json" ]; then
	err "Không tìm thấy .opencode/opencode.json. Hãy chạy install.sh trước."
fi

info "Cập nhật BMAD Method v${BMAD_METHOD_VERSION} cho: $TARGET_DIR"
info "Cập nhật BMAD Method v${BMAD_METHOD_VERSION} (user: $OPK_USER_NAME)"
info "Log đầy đủ: $BMAD_LOG"

# Run BMAD install: full log goes to file, only tail -50 to stdout.
# shellcheck disable=SC2317
if npx --yes "bmad-method@${BMAD_METHOD_VERSION}" install \
	--modules bmm \
	--tools opencode \
	--user-name "$OPK_USER_NAME" \
	--communication-language Vietnamese \
	--document-output-language Vietnamese \
	--directory "$TARGET_DIR" \
	-y >"$BMAD_LOG" 2>&1; then
	ok "BMAD Method v${BMAD_METHOD_VERSION} đã cập nhật!"
else
	rc=$?
	echo ""
	echo -e "${RED}✗ BMAD Method cập nhật THẤT BẠI (exit code: $rc)${NC}"
	echo ""
	echo "Full log: $BMAD_LOG"
	echo "----- tail -50 của log -----"
	tail -50 "$BMAD_LOG" 2>/dev/null || echo "(không đọc được log)"
	echo "----------------------------"
	err "Sửa lỗi rồi chạy lại: bash $KIT_DIR/update-bmad.sh"
fi

echo ""
info "----- tail -50 BMAD log ($BMAD_LOG) -----"
tail -50 "$BMAD_LOG" 2>/dev/null || true
echo "-----------------------------------------"

echo ""
info "Các module hiện có:"
if [ -d "$TARGET_DIR/.bmad" ]; then
	ls "$TARGET_DIR/.bmad/" 2>/dev/null || warn "Thư mục .bmad trống"
else
	warn "Không tìm thấy .bmad/"
fi
