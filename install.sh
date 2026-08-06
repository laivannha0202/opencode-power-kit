#!/usr/bin/env bash

# ============================================================================
# OpenCode Power Kit - Install Script
# Cài đặt Superpowers + BMAD Method vào project hiện tại
#
# Env overrides:
#   BMAD_METHOD_VERSION  Pin version BMAD (mặc định: $OPK_BMAD_VERSION từ upstream-versions.sh)
# ============================================================================
set -euo pipefail

# --- BMAD Method version (env override, default từ upstream-versions.sh) ---
# Single source of truth: update-bmad.sh dùng OPK_BMAD_VERSION — install
# phải trùng, không hardcode riêng (trước đây 6.9.0 vs 6.10.0).
source "$(cd "$(dirname "$0")" && pwd)/scripts/upstream-versions.sh"
: "${BMAD_METHOD_VERSION:=$OPK_BMAD_VERSION}"
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
source "$KIT_DIR/scripts/require-linux.sh"
opk_require_linux
TARGET_DIR="$(pwd)"
REPORT_FILE="$TARGET_DIR/opencode-power-install-report.md"
BACKUP_DIR="$TARGET_DIR/.opencode-power-kit-backup-$(date +%Y%m%d%H%M%S)"
BMAD_LOG="$TARGET_DIR/.opencode-power-bmad-install.log"
BACKUP_NEEDED=false
MERGE_ARGS=()
for arg in "$@"; do
	[[ "$arg" != --normalize-jsonc ]] || MERGE_ARGS+=(--normalize-jsonc)
done

# --- Per-run lease: mọi tx của install run này đều gắn nonce này. ---
# Kết hợp với global install lock (.opk-state/.install.lock) bên dưới:
# hai installer không thể chạy đồng thời, và nếu có tx dở dang từ run
# khác (crash), lease của run này sẽ không đụng vào nó.
LEASE="install-$$-$(date +%s)"

# --- Global install lock (fail-closed) ---
# hold-lock mở + validate + flock .install.lock trong MỘT fd (O_NOFOLLOW):
# không có TOCTOU giữa check và lock. Process giữ lock được kill ở EXIT trap.
INSTALL_LOCK_OUT="$(mktemp "${TMPDIR:-/tmp}/opk-lock.XXXXXX")"
python3 "$KIT_DIR/scripts/opk_tx.py" hold-lock --root "$TARGET_DIR" >"$INSTALL_LOCK_OUT" 2>&1 &
INSTALL_LOCK_PID=$!
LOCK_ACQUIRED=0
for _ in $(seq 1 100); do
	if grep -q '"ok": true' "$INSTALL_LOCK_OUT" 2>/dev/null; then
		LOCK_ACQUIRED=1
		break
	fi
	if ! kill -0 "$INSTALL_LOCK_PID" 2>/dev/null; then
		break
	fi
	sleep 0.05
done
if [ "$LOCK_ACQUIRED" != "1" ]; then
	err "Không lấy được install lock (.opk-state/.install.lock):
  $(cat "$INSTALL_LOCK_OUT" 2>/dev/null || echo 'không có thông báo từ hold-lock')"
fi
rm -f "$INSTALL_LOCK_OUT"
trap 'kill "$INSTALL_LOCK_PID" 2>/dev/null || true' EXIT
info "Install lock đang được giữ: .opk-state/.install.lock (lease: $LEASE)"

# --- Transaction layer ---
# Mọi file install.sh ghi vào project đi qua opk_tx.sh (journal + backup +
# rollback). Fail-closed: lỗi tx -> dừng install, hướng dẫn recover.
TX_SH="$KIT_DIR/scripts/opk_tx.sh"

opk_tx() {
	# begin prints tx_id on stdout (needed); các lệnh khác chỉ cần rc, ẩn JSON.
	if [ "$1" = "begin" ]; then
		"$TX_SH" "$@" --lease "$LEASE" || err "opk_tx.sh $* thất bại.
  Khôi phục: $TX_SH recover --root \"$TARGET_DIR\" --all --yes"
	else
		"$TX_SH" "$@" --lease "$LEASE" >/dev/null || err "opk_tx.sh $* thất bại.
  Khôi phục: $TX_SH recover --root \"$TARGET_DIR\" --all --yes"
	fi
}

tx_id_of() {
	python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])'
}

# Khôi phục giao dịch dở dang từ lần install bị gián đoạn (Ctrl-C / crash).
# Chỉ chạm vào .opk-state/ và các file do chính tx trước ghi.
# Chạy SAU khi đã giữ global lock: không có installer nào khác đang chạy
# nên không sợ recover đụng vào tx đang hoạt động.
recover_pending_tx() {
	local pending
	pending="$("$TX_SH" status --root "$TARGET_DIR" 2>/dev/null | python3 -c '
import json, sys
try:
    txs = json.load(sys.stdin)
except Exception:
    txs = []
print(sum(1 for t in txs if t.get("status") in ("prepared", "applying", "failed")))
' 2>/dev/null || echo 0)"
	pending="${pending:-0}"
	if [ "$pending" -gt 0 ] 2>/dev/null; then
		warn "Có $pending giao dịch dở dang từ lần install trước — đang khôi phục..."
		"$TX_SH" recover --root "$TARGET_DIR" --all --yes
	fi
}

# --- Failure injection (test-only, fail-closed ngoài test) ---
# OPK_TEST_MODE=1 + OPK_TEST_INJECT_FAIL=<phase> dừng install đúng sau
# phase đó, cho phép test e2e kiểm tra rollback + giải phóng lock.
# Production: biến này bị từ chối (giống OPK_CONFIG_MERGE_SKIP).
inject_fail() {
	local phase="$1"
	if [ "${OPK_TEST_INJECT_FAIL:-}" != "$phase" ]; then
		return 0
	fi
	if [ "${OPK_TEST_MODE:-0}" != "1" ]; then
		err "OPK_TEST_INJECT_FAIL=$phase chỉ được phép trong OPK_TEST_MODE=1 (test-only)."
	fi
	warn "OPK_TEST_INJECT_FAIL=$phase — dừng install (test-only)."
	err "Injected failure tại phase: $phase (OPK_TEST_INJECT_FAIL)"
}

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
	# Explicit test escape hatch: OPK_ALLOW_DIR must equal the real target path.
	# Only honored in test mode; production installs are never affected.
	if [ "$OPK_TEST_MODE" = "1" ] && [ -n "$OPK_ALLOW_DIR" ]; then
		local a_real
		a_real="$(cd "$OPK_ALLOW_DIR" 2>/dev/null && pwd -P 2>/dev/null || echo "$OPK_ALLOW_DIR")"
		if [ "$a_real" = "$p_real" ]; then return 1; fi
	fi
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

recover_pending_tx

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
MERGE_JSON=""
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
	if ! MERGE_JSON="$(python3 "$KIT_DIR/scripts/merge-opk-project.py" \
		--project-dir "$TARGET_DIR" --json "${MERGE_ARGS[@]}")"; then
		err "merge-opk-project.py thất bại — kiểm tra lỗi ở trên.
  KHÔNG fallback copy thô để tránh ghi đè config user."
	fi
	BACKUP_NEEDED=true
	ok "AGENTS.md / OPENCODE.md / opencode.json (merged)"
	ok "Safety plugin: .opencode/plugins/opk-safety-guard.js"
fi
inject_fail after-merge

# --- Merge gitignore-extra + knip.json + lefthook.yml trong MỘT giao dịch ---
# Atomic: nếu bất kỳ op nào thất bại (hoặc install bị gián đoạn), toàn bộ
# file được khôi phục về trạng thái trước khi chạy.
TX_ID="$(opk_tx begin --root "$TARGET_DIR" --reason "install.sh: gitignore/knip/lefthook" | tx_id_of)"

# .gitignore: MERGE_MARKER idempotent — file mới được tạo, file có sẵn được
# thêm/được thay block managed marker (không ghi đè nội dung user khác).
opk_tx stage --txid "$TX_ID" --root "$TARGET_DIR" --kind MERGE_MARKER \
	--rel .gitignore --marker gitignore-extra \
	--text "$(cat "$KIT_DIR/templates/gitignore-extra.txt")"
ok "Đã merge gitignore-extra vào .gitignore"

# knip.json / lefthook.yml: chỉ tạo khi chưa tồn tại (require-absent, fail-closed).
if [ ! -f "$TARGET_DIR/knip.json" ]; then
	opk_tx stage --txid "$TX_ID" --root "$TARGET_DIR" --kind CREATE \
		--rel knip.json --file "$KIT_DIR/templates/knip.json" --require-absent
	ok "knip.json"
else
	warn "knip.json đã có, bỏ qua."
fi
if [ ! -f "$TARGET_DIR/lefthook.yml" ]; then
	opk_tx stage --txid "$TX_ID" --root "$TARGET_DIR" --kind CREATE \
		--rel lefthook.yml --file "$KIT_DIR/templates/lefthook.yml" --require-absent
	ok "lefthook.yml"
else
	warn "lefthook.yml đã có, bỏ qua."
fi

opk_tx commit --txid "$TX_ID" --root "$TARGET_DIR"
inject_fail after-gitignore-tx

# --- Install BMAD Method ---
info "Cài đặt BMAD Method v${BMAD_METHOD_VERSION} (module bmm, user: $OPK_USER_NAME)..."
BMAD_RC=0
if command -v npx &>/dev/null; then
	# Capture full output to a TEMP log (never shell-redirect into a
	# project path: a pre-seeded symlink at $BMAD_LOG would make the
	# redirect write through it). Publish to $BMAD_LOG via the safe
	# write layer (refuses symlink/hardlink targets) after npx exits.
	# shellcheck disable=SC2317  # errexit is set; this block can be invoked via && fallback
	BMAD_TMP_LOG="$(mktemp "${TMPDIR:-/tmp}/opk-bmad.XXXXXX")"
	if npx --yes "bmad-method@${BMAD_METHOD_VERSION}" install \
		--modules bmm \
		--tools opencode \
		--user-name "$OPK_USER_NAME" \
		--communication-language Vietnamese \
		--document-output-language Vietnamese \
		--directory "$TARGET_DIR" \
		-y >"$BMAD_TMP_LOG" 2>&1; then
		BMAD_RC=0
		ok "BMAD Method v${BMAD_METHOD_VERSION} đã cài xong"
	else
		BMAD_RC=$?
	fi
	# Publish log an toàn (fail-closed: không publish qua symlink).
	if ! python3 "$KIT_DIR/scripts/opk_safe_io.py" write \
		--root "$TARGET_DIR" \
		--rel .opencode-power-bmad-install.log \
		--stdin <"$BMAD_TMP_LOG" >/dev/null 2>&1; then
		rm -f "$BMAD_TMP_LOG"
		err "Không publish được BMAD log qua safe write (đích không an toàn?):
  $BMAD_LOG
  Log tạm: $BMAD_TMP_LOG"
	fi
	rm -f "$BMAD_TMP_LOG"
	if [ "$BMAD_RC" -ne 0 ]; then
		echo ""
		echo -e "${RED}✗ BMAD Method cài THẤT BẠI (exit code: $BMAD_RC)${NC}"
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
inject_fail after-bmad

# --- Lefthook install ---
if [ -f "$TARGET_DIR/package.json" ] && [ -f "$TARGET_DIR/lefthook.yml" ]; then
	info "Cài đặt lefthook..."
	npx lefthook install || warn "lefthook install thất bại, bỏ qua."
fi

inject_fail before-report

# --- Generate report (qua transaction layer: REPLACE có backup/rollback) ---
# Nội dung report lấy từ dữ liệu THẬT: merge --json (status từng file),
# tx gitignore/knip/lefthook, BMAD exit code, lease id.
TX_R="$(opk_tx begin --root "$TARGET_DIR" --reason "install.sh: report" | tx_id_of)"
REPORT_TMP="$(mktemp "${TMPDIR:-/tmp}/opk-report.XXXXXX")"
cat >"$REPORT_TMP" <<EOF
# OpenCode Power Kit - Install Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Project:** $TARGET_DIR
- **Power Kit:** $KIT_DIR
- **BMAD Method version:** $BMAD_METHOD_VERSION
- **User name (OPK_USER_NAME):** $OPK_USER_NAME
- **Lease (install run):** $LEASE
- **Install lock:** .opk-state/.install.lock

## Files đã cài đặt

$(python3 - "$MERGE_JSON" <<'PY'
import json, sys
data = json.loads(sys.argv[1]) if sys.argv[1] else {"files": []}
ICONS = {
    "created": "✅ (mới)",
    "modified": "✅ (merged, giữ nội dung user)",
    "updated": "✅ (merged, giữ nội dung user)",
    "installed": "✅ (runtime safety plugin)",
    "preserved": "⏭️ Đã có, giữ nguyên",
    "archived": "🗄️ Legacy được archive",
}
for f in data.get("files", []):
    status = f.get("status", "?")
    icon = ICONS.get(status, f"❓ {status}")
    print(f"| {f['file']} | {icon} |")
PY
)

| .gitignore (merged) | ✅ |
| knip.json | $([ -f "$TARGET_DIR/knip.json" ] && echo "✅" || echo "⏭️ Đã có") |
| lefthook.yml | $([ -f "$TARGET_DIR/lefthook.yml" ] && echo "✅" || echo "⏭️ Đã có") |
| opencode-power-install-report.md | ✅ (report này) |

## Giao dịch (transaction)

- Gitignore/knip/lefthook tx: \`$TX_ID\`
- BMAD install exit code: $BMAD_RC
- Report tx: \`$TX_R\`

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

opk_tx stage --txid "$TX_R" --root "$TARGET_DIR" --kind REPLACE \
	--rel opencode-power-install-report.md --file "$REPORT_TMP"
rm -f "$REPORT_TMP"
opk_tx commit --txid "$TX_R" --root "$TARGET_DIR"
inject_fail after-report

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ OpenCode Power Kit đã cài thành công!  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
info "Chạy verify: opk verify"
