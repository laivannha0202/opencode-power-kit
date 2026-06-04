#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Global Install Script
# Cài đặt cấu hình global cho toàn bộ OpenCode
# ============================================================================
set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# --- Safety checks ---
if [ "$(id -u)" -eq 0 ]; then
  err "Không chạy với sudo."
fi

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$KIT_DIR/opencode-global"
REPORT_FILE="$KIT_DIR/GLOBAL_INSTALL_REPORT.md"
BACKUP_DIR="$HOME/.opencode-power-kit-backup-$(date +%Y%m%d%H%M%S)"
OPENCODE_CONFIG_DIR="$HOME/.config/opencode"

info "Power Kit source: $KIT_DIR"
info "Global config dir target: $OPENCODE_CONFIG_DIR"

# --- Verify opencode-global exists ---
if [ ! -d "$GLOBAL_DIR" ]; then
  err "Không tìm thấy $GLOBAL_DIR — thư mục opencode-global không tồn tại."
fi

if [ ! -d "$GLOBAL_DIR/agents" ] || [ ! -d "$GLOBAL_DIR/commands" ] || [ ! -d "$GLOBAL_DIR/skills" ]; then
  err "Thiếu thư mục con trong opencode-global/ (agents, commands, skills)."
fi

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

if [ -f "$OPENCODE_CONFIG_DIR/opencode.json" ]; then
  mkdir -p "$BACKUP_DIR/config-opencode"
  cp "$OPENCODE_CONFIG_DIR/opencode.json" "$BACKUP_DIR/config-opencode/opencode.json"
  ok "Đã backup ~/.config/opencode/opencode.json"
  BACKED_UP=true
fi

# --- Create ~/.config/opencode if needed ---
if [ ! -d "$OPENCODE_CONFIG_DIR" ]; then
  mkdir -p "$OPENCODE_CONFIG_DIR"
  ok "Tạo mới $OPENCODE_CONFIG_DIR"
else
  info "$OPENCODE_CONFIG_DIR đã tồn tại."
fi

# --- Add OPENCODE_CONFIG_DIR to ~/.bashrc ---
MARKER="# >>> opencode-power-kit-global"
if [ -f "$HOME/.bashrc" ] && grep -qF "$MARKER" "$HOME/.bashrc" 2>/dev/null; then
  warn "~/.bashrc đã có OPENCODE_CONFIG_DIR. Bỏ qua."
else
  {
    echo ""
    echo "$MARKER"
    echo 'export OPENCODE_CONFIG_DIR="$HOME/opencode-power-kit/opencode-global"'
    echo "# <<< opencode-power-kit-global"
  } >> "$HOME/.bashrc"
  ok "Đã thêm OPENCODE_CONFIG_DIR vào ~/.bashrc"
fi

# --- Ensure ~/.local/bin in PATH ---
PATH_MARKER="# >>> opencode-power-kit-path"
if [ -f "$HOME/.bashrc" ] && grep -qF "$PATH_MARKER" "$HOME/.bashrc" 2>/dev/null; then
  warn "~/.bashrc đã có PATH update. Bỏ qua."
else
  {
    echo ""
    echo "$PATH_MARKER"
    echo 'export PATH="$HOME/.local/bin:$PATH"'
    echo "# <<< opencode-power-kit-path"
  } >> "$HOME/.bashrc"
  ok "Đã thêm ~/.local/bin vào PATH"
fi

# --- Safety: no secrets ---
SAFE=true
if [ -f "$HOME/.bashrc" ]; then
  if grep -qiE "(token|password|secret|api_key|OPENAI_API_KEY|ANTHROPIC_API_KEY)" "$HOME/.bashrc" 2>/dev/null; then
    warn "~/.bashrc có chứa chuỗi giống secret. Kiểm tra thủ công."
    SAFE=false
  fi
fi

# --- No MCP modify ---
info "Không sửa đổi cấu hình MCP hiện có."

# --- Generate report ---
cat > "$REPORT_FILE" << EOF
# OpenCode Power Kit - Global Install Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Power Kit:** $KIT_DIR
- **Global config dir:** $OPENCODE_CONFIG_DIR

## Files đã cài đặt

| Mục | Trạng thái |
|-----|-----------|
| OPENCODE_CONFIG_DIR in ~/.bashrc | ✅ |
| ~/.local/bin in PATH | ✅ |
| opencode-global/ structure | ✅ |

## Backup

$([ "$BACKED_UP" = true ] && echo "- Backup tại: $BACKUP_DIR" || echo "- Không có file cần backup")

## Agents

| Agent | Mô tả |
|-------|--------|
| plan-lite.md | Lập kế hoạch nhanh, không sửa file |
| review-lite.md | Review diff tiết kiệm token |
| debug-lite.md | Điều tra bug evidence-first |
| build-strong.md | Triển khai code mạnh |

## Commands

| Command | Mô tả |
|---------|--------|
| /smart-scan | Quét nhanh project |
| /bugfix-safe | Sửa bug an toàn |
| /review-diff | Review git diff |
| /repo-map | Tạo bản đồ project |
| /token-pack | Tạo gói context Repomix |
| /db-readonly | Kiểm tra DB read-only |

## Skills

| Skill | Mô tả |
|-------|--------|
| token-smart-code | Tiết kiệm token khi code |
| serena-first | Dùng Serena semantic search |
| safe-edit | Quy tắc sửa code an toàn |
| repo-map | Tạo repo map ngắn |
| js-ts-project | Hướng dẫn JS/TS projects |

## Bước tiếp theo

1. \`source ~/.bashrc\`
2. \`opencode\`
3. Thử: \`/smart-scan\`, \`/repo-map\`, \`/bugfix-safe\`, \`/review-diff\`
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ Global Install hoàn tất!               ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
info "Bước tiếp theo:"
info "  source ~/.bashrc"
info "  opencode"
info "  /smart-scan  hoặc  @plan-lite"
