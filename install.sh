#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Install Script
# Cài đặt Superpowers + BMAD Method vào project hiện tại
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

# --- Paths ---
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$(pwd)"
REPORT_FILE="$TARGET_DIR/opencode-power-install-report.md"
BACKUP_DIR="$TARGET_DIR/.opencode-power-kit-backup-$(date +%Y%m%d%H%M%S)"

# --- Safety checks ---
if [ "$TARGET_DIR" = "$HOME" ]; then
  err "Không được chạy install.sh trong thư mục HOME (~)."
fi

if [ "$TARGET_DIR" = "$KIT_DIR" ]; then
  err "Không được chạy install.sh trong thư mục ~/opencode-power-kit."
fi

if [ ! -d "$KIT_DIR/templates" ]; then
  err "Không tìm thấy thư mục templates/ trong $KIT_DIR"
fi

info "Target project: $TARGET_DIR"
info "Power Kit source: $KIT_DIR"

# --- Backup existing files ---
BACKUP_NEEDED=false
for f in AGENTS.md OPENCODE.md .opencode/opencode.json; do
  if [ -e "$TARGET_DIR/$f" ]; then
    BACKUP_NEEDED=true
    break
  fi
done

if [ "$BACKUP_NEEDED" = true ]; then
  info "Backup files cũ vào $BACKUP_DIR ..."
  mkdir -p "$BACKUP_DIR"
  for f in AGENTS.md OPENCODE.md .opencode/opencode.json; do
    if [ -e "$TARGET_DIR/$f" ]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$f")"
      cp "$TARGET_DIR/$f" "$BACKUP_DIR/$f"
      ok "Đã backup: $f"
    fi
  done
fi

# --- Copy templates ---
info "Copy templates..."

cp "$KIT_DIR/templates/AGENTS.md" "$TARGET_DIR/AGENTS.md"
ok "AGENTS.md"

cp "$KIT_DIR/templates/OPENCODE.md" "$TARGET_DIR/OPENCODE.md"
ok "OPENCODE.md"

mkdir -p "$TARGET_DIR/.opencode"
cp "$KIT_DIR/templates/opencode.json" "$TARGET_DIR/.opencode/opencode.json"
ok ".opencode/opencode.json"

# --- Merge gitignore-extra ---
if [ -f "$TARGET_DIR/.gitignore" ]; then
  MARKER="# >>> opencode-power-kit"
  if ! grep -qF "$MARKER" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    echo "" >> "$TARGET_DIR/.gitignore"
    echo "$MARKER" >> "$TARGET_DIR/.gitignore"
    cat "$KIT_DIR/templates/gitignore-extra.txt" >> "$TARGET_DIR/.gitignore"
    echo "# <<< opencode-power-kit" >> "$TARGET_DIR/.gitignore"
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
info "Cài đặt BMAD Method (module bmm)..."
if command -v npx &>/dev/null; then
  npx bmad-method install \
    --modules bmm \
    --tools opencode \
    --user-name nha \
    --communication-language Vietnamese \
    --document-output-language Vietnamese \
    --directory "$TARGET_DIR" \
    -y 2>&1 | tail -5
  ok "BMAD Method đã cài xong"
else
  warn "npx không tìm thấy, bỏ qua BMAD install. Hãy cài Node.js trước."
fi

# --- Lefthook install ---
if [ -f "$TARGET_DIR/package.json" ] && [ -f "$TARGET_DIR/lefthook.yml" ]; then
  info "Cài đặt lefthook..."
  npx lefthook install 2>/dev/null || warn "lefthook install thất bại, bỏ qua."
fi

# --- Generate report ---
cat > "$REPORT_FILE" << EOF
# OpenCode Power Kit - Install Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Project:** $TARGET_DIR
- **Power Kit:** $KIT_DIR

## Files đã cài đặt

| File | Trạng thái |
|------|-----------|
| AGENTS.md | ✅ |
| OPENCODE.md | ✅ |
| .opencode/opencode.json | ✅ |
| .gitignore (merged) | ✅ |
| knip.json | $( [ -f "$TARGET_DIR/knip.json" ] && echo "✅" || echo "⏭️ Đã có" ) |
| lefthook.yml | $( [ -f "$TARGET_DIR/lefthook.yml" ] && echo "✅" || echo "⏭️ Đã có" ) |

## BMAD Method

- Module: bmm
- Tools: opencode
- Language: Vietnamese

## Backup

$([ "$BACKUP_NEEDED" = true ] && echo "- Backup tại: $BACKUP_DIR" || echo "- Không có file cần backup")

## Bước tiếp theo

1. Kiểm tra \`AGENTS.md\` và \`OPENCODE.md\` — chỉnh sửa nếu cần.
2. Chạy \`bash ~/opencode-power-kit/verify.sh\` để kiểm tra.
3. Commit: \`git add . && git commit -m "chore: init opencode power kit"\`
EOF

ok "Tạo report: $REPORT_FILE"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  ✅ OpenCode Power Kit đã cài thành công!  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
info "Chạy verify: bash ~/opencode-power-kit/verify.sh"
