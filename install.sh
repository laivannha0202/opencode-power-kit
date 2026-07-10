#!/usr/bin/env bash

# ============================================================================
# OpenCode Power Kit - Install Script
# Cài đặt Superpowers + BMAD Method vào project hiện tại
#
# Env overrides:
#   BMAD_METHOD_VERSION  Pin version BMAD (mặc định: 6.9.0)
# ============================================================================
set -euo pipefail

# --- BMAD Method version (env override, default 6.9.0) ---
: "${BMAD_METHOD_VERSION:=6.9.0}"
export BMAD_METHOD_VERSION

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
	echo -e "${BLUE}[INFO]${NC} $*"
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

# --- Paths ---
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"
REPORT_FILE="$TARGET_DIR/opencode-power-install-report.md"
BACKUP_DIR="$TARGET_DIR/.opencode-power-kit-backup-$(date +%Y%m%d%H%M%S)"
BMAD_LOG="$TARGET_DIR/.opencode-power-bmad-install.log"
BACKUP_NEEDED=false

# --- User name (env > git config > $USER > "User") ---
# Để BMAD output ghi đúng tên người dùng. Không hardcode.
OPK_USER_NAME="${OPK_USER_NAME:-$(git config user.name 2>/dev/null || true)}"
OPK_USER_NAME="${OPK_USER_NAME:-${USER:-User}}"

# --- Safety: detect bad project-dir (sync với bootstrap.sh / setup.sh / opk) ---
HOME_DIR="${HOME:-/root}"
is_bad_project_dir() {
	local p="${1:-$TARGET_DIR}"
	local p_real
	p_real="$(cd "$p" 2>/dev/null && pwd -P 2>/dev/null || echo "$p")"
	# HOME
	case "$p_real" in "$HOME_DIR" | "$HOME_DIR/" | /) return 0 ;; esac
	# Kit itself (and all normal subdirs) - with explicit allowlist for .tmp / .test scratch
	case "$p_real" in "$KIT_DIR" | "$KIT_DIR/" | "$KIT_DIR"/*)
		case "$p_real" in "$KIT_DIR"/.tmp | "$KIT_DIR"/.tmp/*) return 1 ;; esac
		case "$p_real" in "$KIT_DIR"/.test | "$KIT_DIR"/.test/*) return 1 ;; esac
		return 0
		;;
	esac
	# Temp / system roots
	case "$p_real" in /tmp | /tmp/*) return 0 ;; esac
	case "$p_real" in /var/tmp | /var/tmp/*) return 0 ;; esac
	case "$p_real" in /usr | /usr/*) return 0 ;; esac
	case "$p_real" in /etc | /etc/*) return 0 ;; esac
	return 1
}

explain_blocked_dir() {
	local p="${1:-$TARGET_DIR}"
	echo ""
	echo -e "${RED}✗ Từ chối cài vào: $p${NC}"
	echo ""
	echo "Lý do: project install KHÔNG chạy trong:"
	echo "  - \$HOME                    ($HOME_DIR)"
	echo "  - chính repo kit           ($KIT_DIR)"
	echo "  - /tmp, /var/tmp           (không phải project thật)"
	echo "  - /usr, /etc, /            (system dirs)"
	echo ""
	echo "Cách làm đúng:"
	echo ""
	echo -e "  ${GREEN}cd /path/to/your/project${NC}"
	echo -e "  ${GREEN}opk install${NC}        # cài AGENTS.md + OPENCODE.md + .opencode/"
	echo ""
}

if is_bad_project_dir; then
	explain_blocked_dir
	err "Không chạy install.sh trong $TARGET_DIR."
fi

if [ ! -d "$KIT_DIR/templates" ]; then
	err "Không tìm thấy thư mục templates/ trong $KIT_DIR"
fi

info "Target project: $TARGET_DIR"
info "Power Kit source: $KIT_DIR"
info "BMAD Method version: $BMAD_METHOD_VERSION"

# --- Merge OPK vào project (KHÔNG ghi đè cấu hình user) ---
# Dùng scripts/merge-opk-project.py: giữ nguyên model/provider/MCP/plugin
# tùy chỉnh, dùng managed marker cho AGENTS.md/OPENCODE.md, backup trước
# mọi thay đổi, và cài safety plugin mặc định (không ghi đè plugin user).
#
# FAIL-CLOSED: python3 bắt buộc cho JSONC merge an toàn.
# Set OPK_CONFIG_MERGE_SKIP=1 CHỈ trong OPK_TEST_MODE=1 (test-only).
# Production PHẢI fail-closed và giữ nguyên config user.
info "Merge OPK vào project (giữ cấu hình tùy chỉnh)..."
if [ "${OPK_CONFIG_MERGE_SKIP:-0}" = "1" ]; then
	if [ "${OPK_TEST_MODE:-0}" != "1" ]; then
		err "OPK_CONFIG_MERGE_SKIP=1 chỉ được phép trong OPK_TEST_MODE=1 (test-only).
  Production phải fail-closed — KHÔNG bypass config merge."
	fi
	warn "OPK_CONFIG_MERGE_SKIP=1 — bỏ qua config merge (OPK_TEST_MODE=1, test-only)."
else
	if ! command -v python3 >/dev/null 2>&1; then
		err "python3 không tìm thấy — cần thiết cho JSONC merge an toàn.
  Set OPK_CONFIG_MERGE_SKIP=1 để bỏ qua (không recommended)."
	fi
	if ! python3 "$KIT_DIR/scripts/merge-opk-project.py" --project-dir "$TARGET_DIR"; then
		err "merge-opk-project.py thất bại — kiểm tra lỗi ở trên.
  KHÔNG fallback copy thô để tránh ghi đè config user."
	fi
	BACKUP_NEEDED=true
	ok "AGENTS.md / OPENCODE.md / .opencode/opencode.json (merged)"
	ok "Safety plugin: .opencode/plugins/opk-safety-guard.js"
fi

# --- Merge gitignore-extra ---
if [ -f "$TARGET_DIR/.gitignore" ]; then
	MARKER="# >>> opencode-power-kit"
	if ! grep -qF "$MARKER" "$TARGET_DIR/.gitignore" 2>/dev/null; then
		{
			echo ""
			echo "$MARKER"
			cat "$KIT_DIR/templates/gitignore-extra.txt"
			echo "# <<< opencode-power-kit"
		} >>"$TARGET_DIR/.gitignore"
		ok "Đã merge gitignore-extra vào .gitignore"
	else
		warn ".gitignore đã có nội dung Power Kit, bỏ qua."
	fi
else
	cp "$KIT_DIR/templates/gitignore-extra.txt" "$TARGET_DIR/.gitignore"
	ok "Tạo mới .gitignore"
fi

# --- Copy knip.json (chưa có thì copy) ---
if [ ! -f "$TARGET_DIR/knip.json" ]; then
	cp "$KIT_DIR/templates/knip.json" "$TARGET_DIR/knip.json"
	ok "knip.json"
fi

# --- Copy lefthook.yml (chưa có thì copy) ---
if [ ! -f "$TARGET_DIR/lefthook.yml" ]; then
	cp "$KIT_DIR/templates/lefthook.yml" "$TARGET_DIR/lefthook.yml"
	ok "lefthook.yml"
fi

# --- Install BMAD Method ---
info "Cài đặt BMAD Method v${BMAD_METHOD_VERSION} (module bmm, user: $OPK_USER_NAME)..."
if command -v npx &>/dev/null; then
	# Capture full output to log, only show tail -50 to keep stdout readable.
	# shellcheck disable=SC2317  # errexit is set; this block can be invoked via && fallback
	if npx --yes "bmad-method@${BMAD_METHOD_VERSION}" install \
		--modules bmm \
		--tools opencode \
		--user-name "$OPK_USER_NAME" \
		--communication-language Vietnamese \
		--document-output-language Vietnamese \
		--directory "$TARGET_DIR" \
		-y >"$BMAD_LOG" 2>&1; then
		ok "BMAD Method v${BMAD_METHOD_VERSION} đã cài xong"
	else
		bmad_rc=$?
		echo ""
		echo -e "${RED}✗ BMAD Method cài THẤT BẠI (exit code: $bmad_rc)${NC}"
		echo ""
		echo "Full log: $BMAD_LOG"
		echo "----- tail -50 của log -----"
		tail -50 "$BMAD_LOG" 2>/dev/null || echo "(không đọc được log)"
		echo "----------------------------"
		err "Sửa lỗi trong log rồi chạy lại: bash $KIT_DIR/update-bmad.sh"
	fi
	# Always print tail -50 for visibility even on success.
	info "----- tail -50 BMAD log ($BMAD_LOG) -----"
	tail -50 "$BMAD_LOG" 2>/dev/null || true
	echo "-----------------------------------------"
else
	warn "npx không tìm thấy, bỏ qua BMAD install. Hãy cài Node.js trước."
fi

# --- Lefthook install ---
if [ -f "$TARGET_DIR/package.json" ] && [ -f "$TARGET_DIR/lefthook.yml" ]; then
	info "Cài đặt lefthook..."
	npx lefthook install || warn "lefthook install thất bại, bỏ qua."
fi

# --- Generate report ---
cat >"$REPORT_FILE" <<EOF
# OpenCode Power Kit - Install Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Project:** $TARGET_DIR
- **Power Kit:** $KIT_DIR
- **BMAD Method version:** $BMAD_METHOD_VERSION
- **User name (OPK_USER_NAME):** $OPK_USER_NAME

## Files đã cài đặt

| File | Trạng thái |
|------|-----------|
| AGENTS.md | ✅ (merged, giữ nội dung user) |
| OPENCODE.md | ✅ (merged, giữ nội dung user) |
| .opencode/opencode.json | ✅ (merged, giữ model/provider/MCP/plugin) |
| .opencode/plugins/opk-safety-guard.js | ✅ (runtime safety plugin) |
| .gitignore (merged) | ✅ |
| knip.json | $([ -f "$TARGET_DIR/knip.json" ] && echo "✅" || echo "⏭️ Đã có") |
| lefthook.yml | $([ -f "$TARGET_DIR/lefthook.yml" ] && echo "✅" || echo "⏭️ Đã có") |

## BMAD Method

- Module: bmm
- Tools: opencode
- Language: Vietnamese
- Version: $BMAD_METHOD_VERSION
- Log: $BMAD_LOG

## Backup

$([ "$BACKUP_NEEDED" = true ] && echo "- Backup tại: $BACKUP_DIR" || echo "- Không có file cần backup")

## Bước tiếp theo

1. Kiểm tra \`AGENTS.md\` và \`OPENCODE.md\` — chỉnh sửa nếu cần.
2. Chạy \`opk verify\` để kiểm tra.
3. Commit: \`git add . && git commit -m "chore: init opencode power kit"\`
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ OpenCode Power Kit đã cài thành công!  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
info "Chạy verify: opk verify"
