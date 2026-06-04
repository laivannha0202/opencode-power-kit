#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - bootstrap.sh
# One-command installer for Linux / macOS / Git Bash / WSL.
# Không sudo, không curl|sh, không in secret. Idempotent.
#
# Usage:
#   bash bootstrap.sh --global
#   bash bootstrap.sh --all
#   bash bootstrap.sh --project --project-dir /path/to/proj
#   bash bootstrap.sh --fullstack
#   bash bootstrap.sh --doctor
#   bash bootstrap.sh --dry-run --global
#   bash bootstrap.sh --yes --all
#   bash bootstrap.sh --help
# ============================================================================
set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
header(){ echo -e "${CYAN}============================================${NC}"; }

# --- Resolve kit dir (nơi chứa bootstrap.sh) ---
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$KIT_DIR/opencode-global"

if [ ! -f "$KIT_DIR/setup.sh" ] || [ ! -f "$KIT_DIR/install-global.sh" ]; then
  err "Không tìm thấy setup.sh / install-global.sh tại $KIT_DIR. Repo kit có thể bị thiếu file."
fi

if [ ! -d "$GLOBAL_DIR" ]; then
  err "Thiếu $GLOBAL_DIR — kit chưa đầy đủ."
fi

# --- Safety: no root ---
if [ "$(id -u)" -eq 0 ]; then
  err "Không chạy bootstrap.sh với sudo/root. Chạy với user thường."
fi

PWD_NOW="$(pwd)"
HOME_DIR="${HOME:-/root}"

# --- Bad project-dir detection ---
is_bad_project_dir() {
  local p="$1"
  local p_real
  p_real="$(cd "$p" 2>/dev/null && pwd -P 2>/dev/null || echo "$p")"
  # HOME
  case "$p_real" in "$HOME_DIR"|"$HOME_DIR/") return 0 ;; esac
  # Kit itself
  case "$p_real" in "$KIT_DIR"|"$KIT_DIR/"|"$KIT_DIR"/*) return 0 ;; esac
  # Root + system + temp
  case "$p_real" in /) return 0 ;; esac
  case "$p_real" in /tmp|/tmp/*) return 0 ;; esac
  case "$p_real" in /var/tmp|/var/tmp/*) return 0 ;; esac
  case "$p_real" in /usr|/usr/*) return 0 ;; esac
  case "$p_real" in /etc|/etc/*) return 0 ;; esac
  return 1
}

explain_blocked_dir() {
  local p="$1"
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
  echo -e "  ${GREEN}opk fullstack${NC}      # (tùy chọn) cài profile Node/Nest/React/MySQL"
  echo ""
}

# --- Banner ---
banner() {
  echo ""
  header
  echo -e "  ${CYAN}OpenCode Power Kit — bootstrap${NC}"
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
    global)    echo "  - bash $KIT_DIR/setup.sh --global --yes" ;;
    project)   echo "  - bash $KIT_DIR/setup.sh --project --yes   (cwd: $PWD_NOW)" ;;
    fullstack) echo "  - bash $KIT_DIR/setup.sh --fullstack --yes (cwd: $PWD_NOW)" ;;
    all)
      echo "  - bash $KIT_DIR/setup.sh --global --yes"
      if is_bad_project_dir "$PWD_NOW"; then
        echo "  - SKIP project + fullstack (cwd không phải project dir an toàn)"
      else
        echo "  - bash $KIT_DIR/setup.sh --project --fullstack --yes"
      fi
      ;;
    doctor)    echo "  - bash $KIT_DIR/setup.sh --doctor" ;;
  esac
  echo ""
}

# --- Runners ---
do_global() {
  info "Cài global..."
  bash "$KIT_DIR/setup.sh" --global --yes
  # Cập nhật PATH cho shell hiện tại
  export PATH="$HOME/.local/bin:$PATH"
  ok "Global install xong."
  if command -v opk >/dev/null 2>&1; then
    info "opk path: $(opk path 2>/dev/null || echo '?')"
    info "opk version: $(opk version 2>/dev/null || echo '?')"
    opk doctor >/dev/null 2>&1 || true
  else
    warn "opk chưa có trong PATH. Chạy: source ~/.bashrc  (hoặc mở shell mới)"
  fi
}

do_project() {
  local target="${PROJECT_DIR:-$PWD_NOW}"
  if is_bad_project_dir "$target"; then
    explain_blocked_dir "$target"
    err "Không chạy project install trong $target."
  fi
  info "Cài project vào: $target"
  ( cd "$target" && bash "$KIT_DIR/setup.sh" --project --yes )
  ok "Project install xong tại $target."
}

do_fullstack() {
  local target="${PROJECT_DIR:-$PWD_NOW}"
  if is_bad_project_dir "$target"; then
    explain_blocked_dir "$target"
    err "Không chạy fullstack trong $target."
  fi
  info "Cài fullstack profile vào: $target"
  ( cd "$target" && bash "$KIT_DIR/setup.sh" --fullstack --yes )
  ok "Fullstack profile xong tại $target."
}

do_all() {
  info "[1/N] Cài global..."
  bash "$KIT_DIR/setup.sh" --global --yes
  export PATH="$HOME/.local/bin:$PATH"
  local target="${PROJECT_DIR:-$PWD_NOW}"
  if is_bad_project_dir "$target"; then
    warn "[2/N + 3/N] BỎ QUA project + fullstack: $target không phải project dir an toàn."
    warn "         (HOME / kit / / /tmp / /var/tmp / /usr / /etc đều bị từ chối.)"
    echo ""
    info "Sau khi 'cd' vào project thật, chạy:"
    echo -e "  ${GREEN}opk install${NC}"
    echo -e "  ${GREEN}opk fullstack${NC}"
    return 0
  fi
  info "[2/N] Cài project vào: $target"
  ( cd "$target" && bash "$KIT_DIR/setup.sh" --project --yes )
  info "[3/N] Cài fullstack profile vào: $target"
  ( cd "$target" && bash "$KIT_DIR/setup.sh" --fullstack --yes )
  ok "All-in-one xong tại $target."
}

do_doctor() {
  info "Chạy doctor..."
  bash "$KIT_DIR/setup.sh" --doctor
}

# --- Help text ---
show_help() {
  cat <<EOF

OpenCode Power Kit — bootstrap v$(cat "$KIT_DIR/VERSION")

Dùng nhanh (1 lệnh cài global):
  bash $KIT_DIR/bootstrap.sh --global

Flags:
  --global              Cài global (commands/skills/agents + opk CLI)
  --project             Cài vào project hiện tại (pwd)
  --fullstack           Cài full-stack profile
  --all                 Cài global + project + fullstack (auto-detect project)
  --project-dir <path>  Override thư mục project (dùng với --project/--fullstack/--all)
  --doctor              Chạy doctor (read-only)
  --dry-run             Chỉ in kế hoạch
  --yes                 Skip confirm
  --help                In trợ giúp này

Sau khi cài global:
  source ~/.bashrc      # hoặc mở shell mới
  opk help
  opencode

Project install TỪ CHỐI chạy trong:
  \$HOME, kit dir, /, /tmp, /var/tmp, /usr, /etc

EOF
}

# --- Flag parsing ---
GLOBAL_FLAG=false
PROJECT_FLAG=false
FULLSTACK_FLAG=false
ALL_FLAG=false
DOCTOR_FLAG=false
DRY_RUN=false
ASSUME_YES=false
PROJECT_DIR=""

while [ $# -gt 0 ]; do
  case "$1" in
    --global)      GLOBAL_FLAG=true ;;
    --project|--install) PROJECT_FLAG=true ;;
    --fullstack)   FULLSTACK_FLAG=true ;;
    --all)         ALL_FLAG=true ;;
    --doctor)      DOCTOR_FLAG=true ;;
    --project-dir) PROJECT_DIR="${2:-}"; [ -z "$PROJECT_DIR" ] && err "--project-dir cần tham số"; shift ;;
    --dry-run)     DRY_RUN=true ;;
    --yes|-y)      ASSUME_YES=true ;;
    --help|-h)     show_help; exit 0 ;;
    *) err "Flag không hợp lệ: $1 (chạy --help)" ;;
  esac
  shift
done

banner

# No flag: default to --global
if [ "$GLOBAL_FLAG" = false ] && [ "$PROJECT_FLAG" = false ] && \
   [ "$FULLSTACK_FLAG" = false ] && [ "$ALL_FLAG" = false ] && \
   [ "$DOCTOR_FLAG" = false ]; then
  if [ "$ASSUME_YES" = true ]; then
    GLOBAL_FLAG=true
  else
    show_help
    info "Không có flag nào — mặc định sẽ chạy --global. Thêm --yes để skip confirm."
    GLOBAL_FLAG=true
    ASSUME_YES=true
  fi
fi

# Validate PROJECT_DIR if set
if [ -n "$PROJECT_DIR" ]; then
  if [ ! -d "$PROJECT_DIR" ]; then
    err "--project-dir không tồn tại: $PROJECT_DIR"
  fi
  PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd -P)"
fi

# Dry-run mode
if [ "$DRY_RUN" = true ]; then
  [ "$GLOBAL_FLAG" = true ]    && print_plan global
  [ "$PROJECT_FLAG" = true ]   && print_plan project
  [ "$FULLSTACK_FLAG" = true ] && print_plan fullstack
  [ "$ALL_FLAG" = true ]       && print_plan all
  [ "$DOCTOR_FLAG" = true ]    && print_plan doctor
  exit 0
fi

# --- Confirm nếu cần ---
confirm_default_yes() {
  local prompt="$1"
  if [ "$ASSUME_YES" = true ]; then
    return 0
  fi
  read -r -p "$prompt [Y/n] " ans
  case "${ans:-Y}" in
    Y|y|yes|YES|"") return 0 ;;
    *) info "Đã hủy."; exit 0 ;;
  esac
}

# --- Dispatch ---
[ "$GLOBAL_FLAG" = true ]    && { confirm_default_yes "Cài global?"; do_global; }
[ "$PROJECT_FLAG" = true ]   && { confirm_default_yes "Cài project tại ${PROJECT_DIR:-$PWD_NOW}?"; do_project; }
[ "$FULLSTACK_FLAG" = true ] && { confirm_default_yes "Cài fullstack tại ${PROJECT_DIR:-$PWD_NOW}?"; do_fullstack; }
[ "$ALL_FLAG" = true ]       && { confirm_default_yes "Cài tất cả?"; do_all; }
[ "$DOCTOR_FLAG" = true ]    && do_doctor

echo ""
header
echo -e "  ${GREEN}✅ bootstrap hoàn tất${NC}"
header
echo ""
info "Bước tiếp theo:"
if command -v opk >/dev/null 2>&1; then
  info "  1) opk help"
  info "  2) opk path"
  info "  3) opencode"
else
  info "  1) source ~/.bashrc   # nạp PATH + OPENCODE_CONFIG_DIR"
  info "  2) opk help"
  info "  3) opencode"
fi
echo ""
