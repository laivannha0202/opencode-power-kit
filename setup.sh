#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - setup.sh
# Menu + non-interactive entry point. Gọi lại các script có sẵn, không
# duplicate logic. Idempotent: chạy nhiều lần không phá gì.
#
# Usage:
#   bash setup.sh                 # menu tương tác
#   bash setup.sh --global        # cài global (commands/skills/agents + opk CLI)
#   bash setup.sh --project       # cài vào project hiện tại
#   bash setup.sh --fullstack     # cài full-stack profile
#   bash setup.sh --all           # global + project + fullstack (cần cd vào project)
#   bash setup.sh --doctor        # chạy doctor (read-only)
#   bash setup.sh --dry-run       # chỉ in kế hoạch, không sửa gì
#   bash setup.sh --yes           # skip confirm
#   bash setup.sh --help
# ============================================================================
set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok() { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err() {
	echo -e "${RED}[ERROR]${NC} $*"
	exit 1
}
header() { echo -e "${CYAN}============================================${NC}"; }

# --- Resolve kit dir ---
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$KIT_DIR/opencode-global"

# --- Safety: no root, no sudo ---
if [ "$(id -u)" -eq 0 ]; then
	err "Không chạy setup.sh với sudo/root."
fi

# --- Verify required sub-scripts exist ---
require_script() {
	local s="$1"
	if [ ! -f "$s" ]; then
		err "Thiếu script con: $s — repo có thể bị thiếu file. Chạy 'git status' để kiểm tra."
	fi
	if [ ! -x "$s" ]; then
		warn "Script $s chưa +x, đang chmod +x..."
		chmod +x "$s" || true
	fi
}

for s in install-global.sh install.sh doctor.sh verify.sh \
	scripts/install-fullstack-profile.sh; do
	require_script "$KIT_DIR/$s"
done

if [ ! -d "$GLOBAL_DIR" ]; then
	err "Thiếu $GLOBAL_DIR — kit chưa đầy đủ."
fi

# --- Detect project-dir safety (refuse dangerous roots) ---
PWD_NOW="$(pwd)"
HOME_DIR="${HOME:-/root}"
# Per-project install KHÔNG được chạy trong:
#   - HOME, kit itself, root /
#   - /tmp, /var/tmp  (thường là nơi script chạy nhầm, không phải project thật)
#   - /usr, /etc      (system dirs, cấm ghi AGENTS.md / .opencode/ ở đây)
is_bad_project_dir() {
	local pwd_real
	pwd_real="$(cd "$PWD_NOW" 2>/dev/null && pwd -P 2>/dev/null || echo "$PWD_NOW")"
	# HOME
	case "$pwd_real" in "$HOME_DIR" | "$HOME_DIR/" | /) return 0 ;; esac
	# Kit itself (self-edit risk; allowlist .tmp/.test for test/CI scratch)
	case "$pwd_real" in "$KIT_DIR" | "$KIT_DIR/" | "$KIT_DIR"/*)
		case "$pwd_real" in "$KIT_DIR"/.tmp | "$KIT_DIR"/.tmp/*) return 1 ;; esac
		case "$pwd_real" in "$KIT_DIR"/.test | "$KIT_DIR"/.test/*) return 1 ;; esac
		return 0
		;;
	esac
	# System / temp roots
	case "$pwd_real" in /tmp | /tmp/*) return 0 ;; esac
	case "$pwd_real" in /var/tmp | /var/tmp/*) return 0 ;; esac
	case "$pwd_real" in /usr | /usr/*) return 0 ;; esac
	case "$pwd_real" in /etc | /etc/*) return 0 ;; esac
	return 1
}

is_safe_project_dir() {
	if is_bad_project_dir; then
		return 1
	fi
	return 0
}

explain_blocked_dir() {
	echo ""
	echo -e "${RED}✗ Từ chối cài vào: $PWD_NOW${NC}"
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
	echo -e "  ${GREEN}opk fullstack${NC}      # (tùy chọn) cài profile Node/Nest/React/MySQL"
	echo ""
	echo "Nếu chưa có project, tạo rồi cd vào:"
	echo ""
	echo -e "  ${GREEN}mkdir -p ~/projects/myapp && cd ~/projects/myapp${NC}"
	echo -e "  ${GREEN}opk install${NC}"
	echo ""
}

# --- Next-steps printer ---
print_next_steps() {
	local did_global="${1:-false}"
	echo ""
	header
	echo -e "${GREEN}  ✅ Hoàn tất!${NC}"
	header
	echo ""
	if [ "$did_global" = true ]; then
		info "Bước tiếp theo:"
		info "  1) source ~/.bashrc          # nạp OPENCODE_CONFIG_DIR + PATH"
		info "  2) opk help                  # xem lệnh opk CLI"
		info "  3) opencode                  # mở OpenCode, thử /smart-scan"
	else
		info "Bước tiếp theo:"
		info "  - opk help                   # xem lệnh opk CLI"
		info "  - bash ~/opencode-power-kit/verify.sh   # kiểm tra"
		info "  - opencode                   # mở OpenCode"
	fi
}

# --- Banner ---
banner() {
	echo ""
	header
	echo -e "  ${CYAN}OpenCode Power Kit — setup${NC}"
	echo -e "  Kit:   $KIT_DIR"
	echo -e "  PWD:   $PWD_NOW"
	echo -e "  Ver:   $(cat "$KIT_DIR/VERSION" 2>/dev/null || echo "?")"
	header
	echo ""
}

# --- Plan printer (dry-run) ---
print_plan() {
	local mode="$1"
	echo ""
	info "[DRY-RUN] Sẽ chạy:"
	case "$mode" in
	global)
		echo "  - bash $KIT_DIR/install-global.sh"
		;;
	project)
		echo "  - bash $KIT_DIR/install.sh   (yêu cầu project dir, không phải HOME/kit)"
		;;
	fullstack)
		echo "  - bash $KIT_DIR/scripts/install-fullstack-profile.sh   (yêu cầu project dir)"
		;;
	all)
		echo "  - [1/4] bash $KIT_DIR/install-global.sh"
		if is_safe_project_dir; then
			echo "  - [2/4] bash $KIT_DIR/install.sh"
			echo "  - [3/4] bash $KIT_DIR/scripts/install-fullstack-profile.sh"
			echo "  - [4/4] bash $KIT_DIR/verify.sh"
		else
			echo "  - [2/4 + 3/4 + 4/4] SKIP (pwd không phải project dir an toàn)"
		fi
		;;
	doctor)
		echo "  - bash $KIT_DIR/doctor.sh"
		;;
	esac
	echo ""
}

# --- Action runners ---
do_global() {
	info "Chạy install-global.sh..."
	bash "$KIT_DIR/install-global.sh"
	print_next_steps true
}

do_project() {
	if ! is_safe_project_dir; then
		explain_blocked_dir
		err "Không chạy install.sh trong $PWD_NOW."
	fi
	info "Chạy install.sh trong $PWD_NOW ..."
	bash "$KIT_DIR/install.sh"
	ok "Project install xong."
	print_next_steps false
}

do_fullstack() {
	if ! is_safe_project_dir; then
		explain_blocked_dir
		err "Không chạy fullstack profile trong $PWD_NOW."
	fi
	info "Chạy install-fullstack-profile.sh trong $PWD_NOW ..."
	bash "$KIT_DIR/scripts/install-fullstack-profile.sh"
	ok "Full-stack profile xong."
	print_next_steps false
}

do_all() {
	info "[1/4] install-global.sh..."
	bash "$KIT_DIR/install-global.sh"
	if is_safe_project_dir; then
		info "[2/4] install.sh trong $PWD_NOW ..."
		bash "$KIT_DIR/install.sh"
		info "[3/4] install-fullstack-profile.sh trong $PWD_NOW ..."
		bash "$KIT_DIR/scripts/install-fullstack-profile.sh"
		info "[4/4] verify.sh trong $PWD_NOW ..."
		bash "$KIT_DIR/verify.sh"
		ok "All-in-one xong."
		print_next_steps true
	else
		warn "[2/4 + 3/4 + 4/4] BỎ QUA: pwd=$PWD_NOW không phải project dir an toàn (HOME / kit / /tmp / /var/tmp / /usr / /etc)."
		warn "Sau khi 'cd' vào project, chạy: bash $KIT_DIR/setup.sh --project --fullstack"
		print_next_steps true
	fi
}

do_doctor() {
	info "Chạy doctor.sh (read-only)..."
	bash "$KIT_DIR/doctor.sh"
}

# --- Menu ---
show_menu() {
	banner
	echo "Chọn chế độ cài (nhập số, Enter = mặc định):"
	echo ""
	echo "  1) Cài global OpenCode Power Kit"
	echo "  2) Cài vào project hiện tại"
	echo "  3) Cài full-stack profile Node/Nest/React/MySQL"
	echo "  4) Cài tất cả an toàn: global + project + full-stack profile"
	echo "  5) Chạy doctor/verify (chỉ đọc, không sửa)"
	echo "  6) Chỉ xem hướng dẫn (README + flags)"
	echo "  0) Thoát"
	echo ""
}

interactive() {
	show_menu
	local choice
	read -r -p "Chọn [0-6] (mặc định 1): " choice
	choice="${choice:-1}"
	case "$choice" in
	1) do_global ;;
	2) do_project ;;
	3) do_fullstack ;;
	4) do_all ;;
	5) do_doctor ;;
	6) show_help_text ;;
	0)
		info "Thoát."
		exit 0
		;;
	*) err "Lựa chọn không hợp lệ: $choice" ;;
	esac
}

show_help_text() {
	cat <<EOF

OpenCode Power Kit v$(cat "$KIT_DIR/VERSION")

Dùng nhanh (30 giây):
  git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git ~/opencode-power-kit
  cd ~/opencode-power-kit
  bash setup.sh --global

Flags:
  --global      Cài global (commands/skills/agents + opk CLI + ~/.bashrc)
  --project     Cài vào project hiện tại
  --fullstack   Cài full-stack profile (Nest/React/MySQL)
  --all         Cài tất cả (cần cd vào project; nếu pwd = HOME/kit/tmp/var/usr/etc sẽ skip project+fullstack)
  --doctor      Chạy doctor (read-only)
  --dry-run     Chỉ in kế hoạch
  --yes         Skip confirm
  --help        In trợ giúp này

Sau khi cài global:
  source ~/.bashrc
  opk help
  opencode

EOF
}

# --- Flag parsing ---
DRY_RUN=false
ASSUME_YES=false
GLOBAL_FLAG=false
PROJECT_FLAG=false
FULLSTACK_FLAG=false
ALL_FLAG=false
DOCTOR_FLAG=false

while [ $# -gt 0 ]; do
	case "$1" in
	--global) GLOBAL_FLAG=true ;;
	--project | --install) PROJECT_FLAG=true ;;
	--fullstack) FULLSTACK_FLAG=true ;;
	--all) ALL_FLAG=true ;;
	--doctor) DOCTOR_FLAG=true ;;
	--dry-run) DRY_RUN=true ;;
	--yes | -y) ASSUME_YES=true ;;
	--help | -h)
		show_help_text
		exit 0
		;;
	*) err "Flag không hợp lệ: $1 (chạy --help)" ;;
	esac
	shift
done

# --- Dispatch ---
banner

# Default: no flag -> interactive menu
if [ "$GLOBAL_FLAG" = false ] && [ "$PROJECT_FLAG" = false ] &&
	[ "$FULLSTACK_FLAG" = false ] && [ "$ALL_FLAG" = false ] &&
	[ "$DOCTOR_FLAG" = false ]; then
	if [ "$ASSUME_YES" = true ]; then
		# --yes without action flag: default to --global
		GLOBAL_FLAG=true
	else
		interactive
		exit 0
	fi
fi

# Dry-run: print plan, do not execute
if [ "$DRY_RUN" = true ]; then
	[ "$GLOBAL_FLAG" = true ] && print_plan global
	[ "$PROJECT_FLAG" = true ] && print_plan project
	[ "$FULLSTACK_FLAG" = true ] && print_plan fullstack
	[ "$ALL_FLAG" = true ] && print_plan all
	[ "$DOCTOR_FLAG" = true ] && print_plan doctor
	exit 0
fi

# Execute in order
[ "$GLOBAL_FLAG" = true ] && do_global
[ "$PROJECT_FLAG" = true ] && do_project
[ "$FULLSTACK_FLAG" = true ] && do_fullstack
[ "$ALL_FLAG" = true ] && do_all
[ "$DOCTOR_FLAG" = true ] && do_doctor
