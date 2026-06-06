#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Install Full-Stack Profile
# Cài profile node-nest-react-mysql vào project hiện tại.
# - KHÔNG sudo, KHÔNG curl|sh, KHÔNG cài dependency nặng.
# - KHÔNG chạy trong HOME hay trong ~/opencode-power-kit.
# - Backup file user trước khi append.
# - Append AGENTS.append.md + OPENCODE.append.md qua marker (idempotent).
# - Copy commands/skills từ profile sang project.
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

# --- Safety: not root ---
if [ "$(id -u)" -eq 0 ]; then
	err "Không chạy với sudo/root."
fi

# --- Resolve kit dir (this script lives in $KIT_DIR/scripts/) ---
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE_DIR="$KIT_DIR/profiles/node-nest-react-mysql"

if [ ! -d "$PROFILE_DIR" ]; then
	err "Không tìm thấy profile tại $PROFILE_DIR"
fi

# --- Resolve project dir (pwd) ---
PROJECT_DIR="$(pwd)"

# --- Safety: refuse to run in HOME or in kit itself ---
HOME_DIR="${HOME:-/root}"
case "$PROJECT_DIR" in
"$HOME_DIR" | "$HOME_DIR/" | /)
	err "Không chạy script trong HOME ($HOME_DIR). Vào project rồi chạy lại."
	;;
"$KIT_DIR" | "$KIT_DIR/" | "$KIT_DIR"/*)
	case "$PROJECT_DIR" in
	"$KIT_DIR"/.tmp | "$KIT_DIR"/.tmp/*)
		# explicit allowlist: test/CI scratch
		;;
	*)
		err "Không chạy script trong chính opencode-power-kit ($KIT_DIR). Vào project khác rồi chạy lại."
		;;
	esac
	;;
esac

# --- Check project has package.json or git ---
if [ ! -f "$PROJECT_DIR/package.json" ] && [ ! -d "$PROJECT_DIR/.git" ]; then
	warn "Project hiện tại không có package.json hoặc .git. Có thể không phải project Node."
	read -r -p "Tiếp tục? [y/N] " REPLY
	case "$REPLY" in
	[yY] | [yY][eE][sS]) ;;
	*) err "Đã hủy." ;;
	esac
fi

REPORT_FILE="$PROJECT_DIR/FULLSTACK_PROFILE_REPORT.md"

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - Full-Stack Profile"
echo "  (NestJS + React/Vite + MySQL)"
echo "=========================================="
echo ""
info "Project: $PROJECT_DIR"
info "Kit:     $KIT_DIR"
info "Profile: $PROFILE_DIR"
echo ""

# --- Backup helper ---
BACKUP_DIR="$PROJECT_DIR/.opencode-power-kit-backup-$(date '+%Y%m%d-%H%M%S')"
backup_if_exists() {
	local rel="$1"
	local src="$PROJECT_DIR/$rel"
	if [ -f "$src" ]; then
		mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
		cp -p "$src" "$BACKUP_DIR/$rel"
		ok "backup: $rel -> $BACKUP_DIR/$rel"
	fi
}

info "Backup target: $BACKUP_DIR"
backup_if_exists "AGENTS.md"
backup_if_exists "OPENCODE.md"

# --- Append AGENTS.append.md via marker ---
MARKER_BEGIN='<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->'

append_marker_block() {
	local kit_rel="$1"
	local project_rel="$2"
	local label="$3"
	local src="$KIT_DIR/$kit_rel"
	local dst="$PROJECT_DIR/$project_rel"

	if [ ! -f "$src" ]; then
		warn "Không tìm thấy source $src — skip $label."
		return 0
	fi

	if [ ! -f "$dst" ]; then
		cp "$src" "$dst"
		ok "tạo mới: $project_rel (từ $kit_rel)"
		return 0
	fi

	# Idempotent: if marker exists, skip
	if grep -qF "$MARKER_BEGIN" "$dst" 2>/dev/null; then
		ok "$project_rel đã có marker. Skip append."
		return 0
	fi

	# Append with leading newline
	printf '\n\n' >>"$dst"
	cat "$src" >>"$dst"
	ok "append: $project_rel (+ $label)"
}

info "Append AGENTS rules..."
append_marker_block "profiles/node-nest-react-mysql/AGENTS.append.md" "AGENTS.md" "fullstack rules"

info "Append OPENCODE workflow..."
append_marker_block "profiles/node-nest-react-mysql/OPENCODE.append.md" "OPENCODE.md" "fullstack workflow"

# --- Copy commands ---
PROFILE_CMDS_SRC="$PROFILE_DIR/commands"
PROFILE_CMDS_DST="$PROJECT_DIR/.opencode/commands/fullstack"
mkdir -p "$PROFILE_CMDS_DST"

if [ -d "$PROFILE_CMDS_SRC" ]; then
	cmd_count=0
	for f in "$PROFILE_CMDS_SRC"/*.md; do
		[ -e "$f" ] || continue
		base="$(basename "$f")"
		cp "$f" "$PROFILE_CMDS_DST/$base"
		ok "command: .opencode/commands/fullstack/$base"
		cmd_count=$((cmd_count + 1))
	done
	info "Copied $cmd_count profile commands."
else
	warn "Không tìm thấy $PROFILE_CMDS_SRC — skip commands."
fi

# --- Copy skills ---
PROFILE_SKILLS_SRC="$PROFILE_DIR/skills"
PROFILE_SKILLS_DST="$PROJECT_DIR/.agents/skills"
mkdir -p "$PROFILE_SKILLS_DST"

if [ -d "$PROFILE_SKILLS_SRC" ]; then
	skill_count=0
	for d in "$PROFILE_SKILLS_SRC"/*; do
		[ -d "$d" ] || continue
		name="$(basename "$d")"
		if [ -d "$PROFILE_SKILLS_DST/$name" ]; then
			warn "skill $name đã tồn tại — skip (không overwrite)."
			continue
		fi
		cp -r "$d" "$PROFILE_SKILLS_DST/$name"
		ok "skill: .agents/skills/$name"
		skill_count=$((skill_count + 1))
	done
	info "Copied $skill_count profile skills."
else
	warn "Không tìm thấy $PROFILE_SKILLS_SRC — skip skills."
fi

# --- Generate report ---
cat >"$REPORT_FILE" <<EOF
# Full-Stack Profile Install Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Project:** $PROJECT_DIR
- **Kit:** $KIT_DIR
- **Profile:** $PROFILE_DIR

## Files appended

| File | Action | Notes |
|------|--------|-------|
| AGENTS.md | appended | marker idempotent |
| OPENCODE.md | appended | marker idempotent |

## Commands copied

| Source | Dest |
|--------|------|
| profiles/node-nest-react-mysql/commands/*.md | .opencode/commands/fullstack/ |

## Skills copied

| Source | Dest |
|--------|------|
| profiles/node-nest-react-mysql/skills/*/ | .agents/skills/ |

## Backup

- **Location:** $BACKUP_DIR
- AGENTS.md + OPENCODE.md đã backup trước khi append (nếu tồn tại).

## An toàn

- KHÔNG sudo.
- KHÔNG curl|sh.
- KHÔNG tự cài dependency nặng.
- KHÔNG ghi đè file user (chỉ append với marker, hoặc skip nếu conflict).
- KHÔNG chạy trong HOME hoặc trong $KIT_DIR.

## Bước tiếp theo

1. Đọc phần append trong AGENTS.md / OPENCODE.md.
2. Chạy \`/fullstack-scan\` trong OpenCode để xem project trông thế nào.
3. Chạy \`/env-doctor\` và \`/docker-dev-doctor\` nếu có docker-compose.
4. Nếu không thích, restore từ $BACKUP_DIR.
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}=========================================="
echo -e "  ✅ Cài full-stack profile xong"
echo -e "==========================================${NC}"
echo ""
info "Report: $REPORT_FILE"
if [ -d "$BACKUP_DIR" ]; then
	info "Backup: $BACKUP_DIR"
fi
