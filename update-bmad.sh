#!/usr/bin/env bash

# ============================================================================
# OpenCode Power Kit - Update BMAD
# Cài đặt lại / cập nhật BMAD Method cho project hiện tại
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${BLUE:-}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

TARGET_DIR="$(pwd)"

if [ ! -f "$TARGET_DIR/.opencode/opencode.json" ]; then
  err "Không tìm thấy .opencode/opencode.json. Hãy chạy install.sh trước."
fi

info "Cập nhật BMAD Method cho: $TARGET_DIR"

npx bmad-method install \
  --modules bmm \
  --tools opencode \
  --user-name nha \
  --communication-language Vietnamese \
  --document-output-language Vietnamese \
  --directory "$TARGET_DIR" \
  -y 2>&1 | tail -10

ok "BMAD Method đã cập nhật!"

echo ""
info "Các module hiện có:"
if [ -d "$TARGET_DIR/.bmad" ]; then
  ls "$TARGET_DIR/.bmad/" 2>/dev/null || warn "Thư mục .bmad trống"
else
  warn "Không tìm thấy .bmad/"
fi
