#!/usr/bin/env bash
# ============================================================================
# install-safety-plugin.sh
#
# Cài safety plugin guard (opk-safety-guard.js) vào project hiện tại.
# Plugin được copy từ templates/plugins/ vào .opencode/plugins/
#
# Usage:
#   bash scripts/install-safety-plugin.sh
#   bash scripts/install-safety-plugin.sh --yes    (skip confirm)
#   opk safety-plugin install                      (qua CLI wrapper)
#
# Safety:
#   - Không sudo, không curl|sh
#   - Chỉ copy file template, không xóa file user
#   - Backup nếu file đã tồn tại
# ============================================================================
set -euo pipefail

# --- Resolve kit dir ---
SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Config ---
TEMPLATE_FILE="$KIT_DIR/templates/plugins/opk-safety-guard.js"
TARGET_DIR=".opencode/plugins"
TARGET_FILE=".opencode/plugins/opk-safety-guard.js"
SKIP_CONFIRM=0

for a in "$@"; do
	case "$a" in
	--yes | -Y | -y) SKIP_CONFIRM=1 ;;
	esac
done

# --- Check template exists ---
if [ ! -f "$TEMPLATE_FILE" ]; then
	echo "install-safety-plugin: LỖI — không tìm thấy template: $TEMPLATE_FILE" >&2
	exit 1
fi

# --- Check project dir ---
# shellcheck disable=SC2034
PWD_REAL="$(pwd -P 2>/dev/null || pwd)"
if [ ! -f ".opencode/opencode.json" ] && [ ! -f "AGENTS.md" ] && [ ! -f "OPENCODE.md" ]; then
	echo "install-safety-plugin: CẢNH BÁO — $(pwd) có vẻ không phải project OpenCode." >&2
	echo "  (Không tìm thấy .opencode/opencode.json, AGENTS.md, hay OPENCODE.md)" >&2
	if [ "$SKIP_CONFIRM" -eq 0 ]; then
		read -r -p "  Tiếp tục cài safety plugin? [y/N] " reply
		case "$reply" in
		[yY] | [yY][eE][sS]) ;;
		*)
			echo "install-safety-plugin: Đã hủy."
			exit 0
			;;
		esac
	fi
fi

# --- Confirm ---
echo "install-safety-plugin: Sẽ cài safety plugin guard vào:"
echo "  Template: $TEMPLATE_FILE"
echo "  Target:   $(pwd)/$TARGET_FILE"
echo ""
echo "  Guard chặn:"
echo "    - Đọc file nhạy cảm (.env, secret, private key)"
echo "    - rm -rf, git reset --hard, git clean -fd, force push"
echo "    - SQL DROP TABLE, TRUNCATE, DELETE FROM không WHERE"
echo ""

if [ "$SKIP_CONFIRM" -eq 0 ]; then
	read -r -p "Tiếp tục? [y/N] " reply
	case "$reply" in
	[yY] | [yY][eE][sS]) ;;
	*)
		echo "install-safety-plugin: Đã hủy."
		exit 0
		;;
	esac
fi

# --- Create target dir ---
mkdir -p "$TARGET_DIR"

# --- Backup / skip logic ---
# Chỉ ghi đè nếu file hiện tại LÀ OPK plugin (có marker). Nếu là plugin
# tùy chỉnh của user (không có marker), KHÔNG ghi đè.
OPK_MARKER="@opk-plugin opk-safety-guard"
if [ -f "$TARGET_FILE" ]; then
	if grep -qF "$OPK_MARKER" "$TARGET_FILE" 2>/dev/null; then
		BACKUP_FILE="${TARGET_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
		cp "$TARGET_FILE" "$BACKUP_FILE"
		echo "install-safety-plugin: Backup OPK plugin cũ -> $BACKUP_FILE"
	else
		echo "install-safety-plugin: ⚠️  File đã tồn tại nhưng KHÔNG phải OPK plugin."
		echo "   Bỏ qua để không ghi đè plugin tùy chỉnh của bạn."
		echo "   Nếu muốn cài OPK plugin, hãy xóa/đổi tên file rồi chạy lại."
		exit 0
	fi
fi

# --- Install ---
cp "$TEMPLATE_FILE" "$TARGET_FILE"
echo "install-safety-plugin: ✅ Đã cài safety plugin guard (runtime OpenCode plugin)."
echo "   File: $(pwd)/$TARGET_FILE"
echo ""
echo "   Đây là RUNTIME plugin — OpenCode sẽ gọi hook tool.execute.before"
echo "   để chặn đọc file nhạy cảm và command nguy hiểm."
echo "   (KHÁC với scripts/opk-command-guard.sh — đó là manual CLI shell guard,"
echo "   không intercept OpenCode tool call.)"
echo ""
echo "   Để kiểm tra: opk safety-plugin status"
