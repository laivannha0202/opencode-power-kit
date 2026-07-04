#!/usr/bin/env bash

# ============================================================================
# OpenCode Power Kit - Global Install Script
# Cài đặt cấu hình global cho toàn bộ OpenCode + opk CLI.
# Idempotent: chạy lại không duplicate.
# ============================================================================
# shellcheck disable=SC2016,SC2088,SC2034
#   SC2016: literal $HOME/$PATH in single-quoted marker payloads (intentional)
#   SC2088: '~/.bashrc' / '~/.zshrc' in user-facing messages (intentional)
#   SC2034: SAFE is a flag set but not read (kept for clarity / future hooks)
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

# --- Safety checks ---
if [ "$(id -u)" -eq 0 ]; then
	err "Không chạy với sudo."
fi

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$KIT_DIR/opencode-global"
REPORT_FILE="$KIT_DIR/GLOBAL_INSTALL_REPORT.md"
PACK_REPORT_FILE="$KIT_DIR/GLOBAL_PACK_REPORT.md"
BACKUP_DIR="$HOME/.opencode-power-kit-backup-$(date +%Y%m%d%H%M%S)"
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
LOCAL_BIN="$HOME/.local/bin"
OPK_SRC="$KIT_DIR/bin/opk"
OPK_DST="$LOCAL_BIN/opk"

info "Power Kit source: $KIT_DIR"
info "Global config dir target: $OPENCODE_CONFIG_DIR"

# --- Verify opencode-global exists ---
if [ ! -d "$GLOBAL_DIR" ]; then
	err "Không tìm thấy $GLOBAL_DIR — thư mục opencode-global không tồn tại."
fi

if [ ! -d "$GLOBAL_DIR/agents" ] || [ ! -d "$GLOBAL_DIR/commands" ] || [ ! -d "$GLOBAL_DIR/skills" ]; then
	err "Thiếu thư mục con trong opencode-global/ (agents, commands, skills)."
fi

# --- Verify opk source exists ---
if [ ! -f "$OPK_SRC" ]; then
	err "Thiếu $OPK_SRC — chạy 'git status' để kiểm tra repo."
fi
chmod +x "$OPK_SRC" 2>/dev/null || true

# Resolve KIT_DIR thật (canonical) để nhét vào shim, tránh symlink / ../
KIT_REAL="$(cd "$KIT_DIR" >/dev/null 2>&1 && pwd -P)"

# --- Backup ---
info "Backup files cũ vào $BACKUP_DIR ..."
mkdir -p "$BACKUP_DIR"

BACKED_UP=false
if [ -f "$HOME/.bashrc" ]; then
	mkdir -p "$BACKUP_DIR/home"
	cp "$HOME/.bashrc" "$BACKUP_DIR/home/.bashrc"
	ok "Đã backup ~/.bashrc"
	BACKED_UP=true
fi

# macOS defaults to zsh since Catalina (10.15) — also backup ~/.zshrc nếu có
if [ -f "$HOME/.zshrc" ]; then
	mkdir -p "$BACKUP_DIR/home"
	cp "$HOME/.zshrc" "$BACKUP_DIR/home/.zshrc"
	ok "Đã backup ~/.zshrc"
	BACKED_UP=true
fi

if [ -f "$OPENCODE_CONFIG_DIR/opencode.json" ]; then
	mkdir -p "$BACKUP_DIR/config-opencode"
	cp "$OPENCODE_CONFIG_DIR/opencode.json" "$BACKUP_DIR/config-opencode/opencode.json"
	ok "Đã backup ~/.config/opencode/opencode.json"
	BACKED_UP=true
fi

if [ -f "$OPK_DST" ]; then
	mkdir -p "$BACKUP_DIR/local-bin"
	cp "$OPK_DST" "$BACKUP_DIR/local-bin/opk"
	ok "Đã backup ~/.local/bin/opk"
	BACKED_UP=true
fi

# --- Create ~/.config/opencode if needed ---
if [ ! -d "$OPENCODE_CONFIG_DIR" ]; then
	mkdir -p "$OPENCODE_CONFIG_DIR"
	ok "Tạo mới $OPENCODE_CONFIG_DIR"
else
	info "$OPENCODE_CONFIG_DIR đã tồn tại."
fi

# --- Detect shell: bash vs zsh ---
# macOS (10.15+) default = zsh. Nếu $SHELL trỏ tới zsh HOẶC ~/.zshrc đã tồn tại
# → coi như môi trường zsh và cập nhật cả ~/.zshrc. Vẫn giữ ~/.bashrc cho
# Linux/WSL/Git Bash. Không bao giờ xóa marker cũ.
USE_ZSH=false
if [ -n "${SHELL:-}" ] && [[ "$SHELL" == */zsh ]]; then
	USE_ZSH=true
fi
if [ -f "$HOME/.zshrc" ]; then
	USE_ZSH=true
fi

# --- Helper: append marker block to a rc file (idempotent + safe update) ---
# Nếu marker đã tồn tại với content cũ, REPLACE block (không duplicate).
# Nếu chưa có, APPEND block mới.
add_rc_marker() {
	local rcfile="$1"
	local marker="$2"
	local content="$3"
	local end_marker="# <<< ${marker#\# >>> }"
	if [ ! -f "$rcfile" ]; then
		# Tạo mới nếu chưa có (ví dụ: user mới cài zsh chưa có ~/.zshrc)
		: >"$rcfile"
	fi
	if grep -qF "$marker" "$rcfile" 2>/dev/null; then
		# Marker đã có: kiểm tra content có đúng không
		# Tách block từ marker đến end_marker (nếu có), so sánh với content mới
		local current_block
		current_block="$(awk -v m="$marker" -v e="$end_marker" '
			$0 == m { in_block = 1; print; next }
			in_block && $0 == e { print; in_block = 0; exit }
			in_block { print }
		' "$rcfile")"
		local new_block
		new_block="$(printf '%s\n%s\n%s\n' "$marker" "$content" "$end_marker")"
		if [ "$current_block" = "$new_block" ]; then
			ok "$rcfile marker '$marker' đã đúng — không sửa."
		else
			# Replace cũ bằng mới (dùng python để in-place edit an toàn)
			python3 - "$rcfile" "$marker" "$end_marker" "$new_block" <<'PYEOF'
import sys, pathlib
path, marker, end_marker, new_block = sys.argv[1:5]
p = pathlib.Path(path)
text = p.read_text()
lines = text.splitlines(keepends=True)
out = []
in_block = False
replaced = False
for line in lines:
    stripped = line.rstrip("\n")
    if not in_block and stripped == marker:
        out.append(new_block if new_block.endswith("\n") else new_block + "\n")
        in_block = True
        replaced = True
        continue
    if in_block and stripped == end_marker:
        in_block = False
        continue
    if not in_block:
        out.append(line)
if not replaced:
    # Marker không tìm thấy ở line-level (hiếm); append ở cuối
    if out and not out[-1].endswith("\n"):
        out[-1] += "\n"
    out.append(new_block if new_block.endswith("\n") else new_block + "\n")
p.write_text("".join(out))
PYEOF
			ok "$rcfile marker '$marker' đã update (nội dung cũ → mới)."
		fi
		return 0
	fi
	{
		echo ""
		echo "$marker"
		echo "$content"
		echo "$end_marker"
	} >>"$rcfile"
	ok "Đã thêm marker vào $rcfile"
}

# --- Add OPENCODE_CONFIG_DIR + PATH markers ---
# Dùng OPK_KIT_DIR (do KIT_REAL resolve) thay vì hardcode $HOME/opencode-power-kit/...
# → idempotent và an toàn nếu user clone kit vào path khác.
MARKER="# >>> opencode-power-kit-global"
PATH_MARKER="# >>> opencode-power-kit-path"

# Mỗi marker = 1 block. Ghép các export liên quan vào cùng 1 block
# để add_rc_marker replace đúng nội dung (không phải 2 block cùng marker).
GLOBAL_BLOCK="export OPK_KIT_DIR=\"$KIT_REAL\"
export OPENCODE_CONFIG_DIR=\"\$OPK_KIT_DIR/opencode-global\""
PATH_BLOCK='export PATH="$HOME/.local/bin:$PATH"'

# Luôn cập nhật ~/.bashrc (Linux/WSL/Git Bash)
add_rc_marker "$HOME/.bashrc" "$MARKER" "$GLOBAL_BLOCK"
add_rc_marker "$HOME/.bashrc" "$PATH_MARKER" "$PATH_BLOCK"

# Nếu là môi trường zsh, cập nhật thêm ~/.zshrc
if [ "$USE_ZSH" = true ]; then
	add_rc_marker "$HOME/.zshrc" "$MARKER" "$GLOBAL_BLOCK"
	add_rc_marker "$HOME/.zshrc" "$PATH_MARKER" "$PATH_BLOCK"
	ok "Đã cập nhật cả ~/.zshrc (môi trường zsh: $SHELL)"
fi

# --- Install opk CLI to ~/.local/bin/opk (SHIM, không copy trực tiếp) ---
# Lý do: nếu copy trực tiếp bin/opk sang ~/.local/bin thì ~/.local/bin/opk
# sẽ mất OPK_KIT_DIR (vì nó ở ngoài kit). Dùng shim để ~/.local/bin/opk
# luôn exec lại đúng $KIT_DIR/bin/opk — dù user có mv/rename kit thì chỉ
# cần sửa 1 dòng OPK_KIT_DIR trong shim, không cần reinstall.
info "Cài opk CLI (shim)..."
mkdir -p "$LOCAL_BIN"
if [ -f "$OPK_DST" ]; then
	info "~/.local/bin/opk đã tồn tại, đã backup ở $BACKUP_DIR/local-bin/opk"
fi
{
	echo "#!/usr/bin/env bash"
	echo "# Auto-generated by install-global.sh — DO NOT EDIT BY HAND."
	echo "# Nếu cần đổi kit dir: sửa dòng OPK_KIT_DIR bên dưới rồi chmod +x lại."
	echo "# Re-generate bằng: bash $KIT_REAL/install-global.sh"
	echo "export OPK_KIT_DIR=\"$KIT_REAL\""
	echo 'exec "$OPK_KIT_DIR/bin/opk" "$@"'
} >"$OPK_DST"
chmod +x "$OPK_DST"
ok "Đã cài opk shim: $OPK_DST → $KIT_REAL/bin/opk"

# Verify opk can find kit
if [ -x "$OPK_DST" ]; then
	if "$OPK_DST" path >/dev/null 2>&1; then
		ok "opk path OK: $("$OPK_DST" path)"
	else
		warn "opk shim installed nhưng 'opk path' không hoạt động. Kiểm tra thủ công."
	fi
fi

# Check PATH contains ~/.local/bin (for current shell + future shells)
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
	warn "$LOCAL_BIN chưa có trong PATH của shell hiện tại. Chạy:"
	warn "  source ~/.bashrc"
	warn "  hoặc thêm thủ công: export PATH=\"\$HOME/.local/bin:\$PATH\""
else
	ok "$LOCAL_BIN đã có trong PATH"
fi

# --- Safety: no secrets ---
SAFE=true
if [ -f "$HOME/.bashrc" ]; then
	if grep -qiE "(token|password|secret|api_key|OPENAI_API_KEY|ANTHROPIC_API_KEY)" "$HOME/.bashrc" 2>/dev/null; then
		warn "~/.bashrc có chứa chuỗi giống secret. Kiểm tra thủ công."
		SAFE=false
	fi
fi
if [ -f "$HOME/.zshrc" ]; then
	if grep -qiE "(token|password|secret|api_key|OPENAI_API_KEY|ANTHROPIC_API_KEY)" "$HOME/.zshrc" 2>/dev/null; then
		warn "~/.zshrc có chứa chuỗi giống secret. Kiểm tra thủ công."
		SAFE=false
	fi
fi

# --- No MCP modify ---
info "Không sửa đổi cấu hình MCP hiện có."

# --- Count items in pack ---
COUNT_AGENTS=$(find "$GLOBAL_DIR/agents" -maxdepth 2 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
COUNT_COMMANDS=$(find "$GLOBAL_DIR/commands" -maxdepth 2 -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
COUNT_SKILLS=$(find "$GLOBAL_DIR/skills" -maxdepth 2 -type d -mindepth 1 2>/dev/null | wc -l | tr -d ' ')

# --- Generate GLOBAL_INSTALL_REPORT.md (basic) ---
cat >"$REPORT_FILE" <<EOF
# OpenCode Power Kit - Global Install Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Power Kit:** $KIT_DIR
- **Global config dir:** $OPENCODE_CONFIG_DIR

## Files đã cài đặt

| Mục | Trạng thái |
|-----|-----------|
| OPENCODE_CONFIG_DIR in ~/.bashrc | ✅ |
| ~/.local/bin in PATH | ✅ |
| opencode-global/ structure | ✅ ($COUNT_AGENTS agents, $COUNT_COMMANDS commands, $COUNT_SKILLS skills) |
| opk CLI | ✅ $OPK_DST |

## Backup

$([ "$BACKED_UP" = true ] && echo "- Backup tại: $BACKUP_DIR" || echo "- Không có file cần backup")

## Bước tiếp theo

1. \`source ~/.bashrc\`
2. \`opk help\`
3. \`opencode\`
4. Thử: \`/smart-scan\`, \`/repo-map\`, \`/bugfix-safe\`, \`/review-diff\`
EOF

ok "Tạo report: $REPORT_FILE"

# --- Generate GLOBAL_PACK_REPORT.md (dynamic inventory) ---
{
	echo "# OpenCode Power Kit - Global Pack Report"
	echo ""
	echo "- **Thời gian cập nhật:** $(date '+%Y-%m-%d %H:%M:%S')"
	echo "- **Repo:** $KIT_DIR"
	echo "- **Ver:** $(cat "$KIT_DIR/VERSION" 2>/dev/null || echo '?')"
	echo ""
	echo "## Tổng quan"
	echo ""
	echo "| Mục | Số lượng | Vị trí |"
	echo "|-----|----------|---------|"
	echo "| Agents   | $COUNT_AGENTS | \`opencode-global/agents/\` |"
	echo "| Commands | $COUNT_COMMANDS | \`opencode-global/commands/\` |"
	echo "| Skills   | $COUNT_SKILLS | \`opencode-global/skills/\` |"
	echo "| opk CLI  | ✅        | \`$OPK_DST\` |"
	echo ""
	echo "## Agents installed"
	echo ""
	if [ "$COUNT_AGENTS" -gt 0 ]; then
		echo "| Agent | File |"
		echo "|-------|------|"
		find "$GLOBAL_DIR/agents" -maxdepth 2 -type f -name '*.md' 2>/dev/null |
			sort |
			while read -r f; do
				base="$(basename "$f")"
				echo "| \`$base\` | \`opencode-global/agents/$base\` |"
			done
	else
		echo "_Chưa có agent nào._"
	fi
	echo ""
	echo "## Commands installed"
	echo ""
	if [ "$COUNT_COMMANDS" -gt 0 ]; then
		echo "| Command | File |"
		echo "|---------|------|"
		find "$GLOBAL_DIR/commands" -maxdepth 2 -type f -name '*.md' 2>/dev/null |
			sort |
			while read -r f; do
				base="$(basename "$f")"
				stem="${base%.md}"
				echo "| \`/$stem\` | \`opencode-global/commands/$base\` |"
			done
	else
		echo "_Chưa có command nào._"
	fi
	echo ""
	echo "## Skills installed"
	echo ""
	if [ "$COUNT_SKILLS" -gt 0 ]; then
		echo "| Skill | Vị trí |"
		echo "|-------|--------|"
		find "$GLOBAL_DIR/skills" -maxdepth 2 -type d -mindepth 1 2>/dev/null |
			sort |
			while read -r d; do
				name="$(basename "$d")"
				echo "| \`$name\` | \`opencode-global/skills/$name/\` |"
			done
	else
		echo "_Chưa có skill nào._"
	fi
	echo ""
	echo "## opk CLI"
	echo ""
	echo "- **Path:** \`$OPK_DST\`"
	if [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
		echo "- **PATH:** ✅ \`$LOCAL_BIN\` đã có trong PATH"
	else
		echo "- **PATH:** ⚠️  \`$LOCAL_BIN\` chưa có trong PATH hiện tại. Chạy: \`source ~/.bashrc\`"
	fi
	echo ""
	echo "Lệnh khả dụng: \`opk help\`, \`opk version\`, \`opk path\`, \`opk global\`, \`opk install\`, \`opk fullstack\`, \`opk all\`, \`opk doctor\`, \`opk verify\`, \`opk tools\`."
	echo ""
	echo "## Bước tiếp theo"
	echo ""
	echo '1. `source ~/.bashrc`'
	echo '2. `opk help`'
	echo '3. `opencode`'
	echo '4. Thử: `/smart-scan`, `/repo-map`, `/bugfix-safe`, `/review-diff`'
	echo ""
	echo "## An toàn"
	echo ""
	echo "- Không token / password / secrets trong repo."
	echo "- Backup trước khi sửa \`~/.bashrc\` và \`~/.local/bin/opk\`."
	echo "- Không sudo, không \`curl|sh\`."
	echo "- Không sửa MCP config hiện có."
	echo "- Không xóa file user."
} >"$PACK_REPORT_FILE"

ok "Tạo report: $PACK_REPORT_FILE"

# --- Taste Skill: suggest (verify-gated, not auto-installed since v2.0.0) ---
echo ""
info "Taste Skill (UI/UX design) is optional and NOT auto-installed."
info "To install:  opk taste install"
info "To check:    opk taste doctor"

# --- Final summary ---
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ Global Install hoàn tất!               ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
info "Đã cài:"
info "  • opencode-global/: $COUNT_AGENTS agents, $COUNT_COMMANDS commands, $COUNT_SKILLS skills"
info "  • opk CLI (shim):   $OPK_DST → $KIT_REAL/bin/opk"
info "  • Reports:          $REPORT_FILE"
info "                        $PACK_REPORT_FILE"
echo ""
info "Bước tiếp theo:"
info "  1) source ~/.bashrc"
info "  2) opk help"
info "  3) opencode"
info "  4) Thử /taste-polish  hoặc  /smart-scan"
