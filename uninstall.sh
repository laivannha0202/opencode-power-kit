#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Uninstall
# Gỡ cấu hình project do Power Kit tạo (chỉ khi có backup gần nhất).
# KHÔNG xóa code user, KHÔNG xóa file đã có sẵn trước khi cài kit.
# Mặc định hỏi xác nhận; --yes để skip.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
	echo -e "${BLUE}[INFO]${NC} $*"
}
ok() {
	echo -e "${GREEN}[OK]${NC}   $*"
}
warn() {
	echo -e "${YELLOW}[WARN]${NC} $*"
}
err() {
	echo -e "${RED}[FAIL]${NC} $*"
	exit 1
}

AUTO_YES=false
for arg in "$@"; do
	case "$arg" in
	--yes | -y) AUTO_YES=true ;;
	--help | -h)
		cat <<USAGE
Usage: bash uninstall.sh [--yes]

Chỉ gỡ cấu hình project do Power Kit tạo. Nếu có backup
.opencode-power-kit-backup-* thì sẽ restore. Nếu không có backup,
chỉ xóa các file marker rõ ràng của kit.
USAGE
		exit 0
		;;
	*) err "Unknown arg: $arg (dùng --yes hoặc --help)" ;;
	esac
done

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"

info "Target: $TARGET_DIR"
info "Kit:    $KIT_DIR"

# --- Find latest backup dir ---
BACKUP_DIR=""
for d in "$TARGET_DIR"/.opencode-power-kit-backup-*; do
	if [ -d "$d" ]; then
		BACKUP_DIR="$d"
	fi
done

# --- Confirm ---
echo ""
if [ "$AUTO_YES" != true ]; then
	echo "Sẽ gỡ các cấu hình Power Kit trong: $TARGET_DIR"
	if [ -n "$BACKUP_DIR" ]; then
		echo "  - Tìm thấy backup: $BACKUP_DIR  (sẽ restore file cũ nếu có)"
	else
		echo "  - Không có backup - chỉ xóa file rõ ràng do kit tạo"
	fi
	echo "  - KHÔNG xóa code user, KHÔNG xóa file có sẵn trước khi cài"
	echo ""
	read -r -p "Tiếp tục? [y/N] " REPLY
	case "$REPLY" in
	[yY] | [yY][eE][sS]) ;;
	*)
		info "Hủy."
		exit 0
		;;
	esac
fi

# --- Restore from backup if present ---
if [ -n "$BACKUP_DIR" ]; then
	info "Restore từ backup: $BACKUP_DIR"
	for f in AGENTS.md OPENCODE.md .opencode/opencode.json; do
		if [ -e "$BACKUP_DIR/$f" ]; then
			mkdir -p "$TARGET_DIR/$(dirname "$f")"
			cp -f "$BACKUP_DIR/$f" "$TARGET_DIR/$f"
			ok "restored: $f"
		fi
	done
	rm -rf "$BACKUP_DIR"
	ok "removed backup dir: $BACKUP_DIR"
else
	warn "Không có backup để restore. Bỏ qua restore."
fi

# --- Remove kit-created files (only if they look like kit output) ---
# 1) Strip the opencode-power-kit block from .gitignore (if present).
if [ -f "$TARGET_DIR/.gitignore" ] && grep -qF "# >>> opencode-power-kit" "$TARGET_DIR/.gitignore" 2>/dev/null; then
	info "Strip opencode-power-kit block khỏi .gitignore"
	python3 - "$TARGET_DIR/.gitignore" <<'PY'
import re, sys
p = sys.argv[1]
text = open(p).read()
new = re.sub(
    r"\n?# >>> opencode-power-kit.*?# <<< opencode-power-kit\n?",
    "\n",
    text,
    flags=re.DOTALL,
)
open(p, "w").write(new)
PY
	ok "stripped .gitignore block"
fi

# 2) Remove the install report (kit output, safe to drop).
# shellcheck disable=SC2043  # single-element for loop intentional (extensible)
for f in opencode-power-install-report.md; do
	if [ -f "$TARGET_DIR/$f" ]; then
		rm -f "$TARGET_DIR/$f"
		ok "removed: $f"
	fi
done

echo ""
ok "Uninstall hoàn tất. Code của bạn KHÔNG bị xóa."
info "Nếu muốn xóa thêm .opencode/ hoặc _bmad/, hãy tự xóa thủ công sau khi review."
