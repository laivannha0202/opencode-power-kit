#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Doctor
# Chẩn đoán nhanh cấu hình global + project: kiểm tra OPENCODE_CONFIG_DIR,
# commands/agents/skills structure, scripts, không MCP, không secrets.
# Chỉ đọc - không sửa file.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}
ok() {
  echo -e "${GREEN}[OK]${NC}   $*"
}
warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}
err() {
  echo -e "${RED}[FAIL]${NC} $*"
  FAIL=1
}

FAIL=0
WARN=0

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$KIT_DIR/opencode-global"

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - Doctor"
echo "  Kit: $KIT_DIR"
echo "  PWD: $(pwd)"
echo "=========================================="
echo ""

# --- OPENCODE_CONFIG_DIR ---
info "OPENCODE_CONFIG_DIR check"
if [ -n "${OPENCODE_CONFIG_DIR:-}" ]; then
  ok "OPENCODE_CONFIG_DIR is set: $OPENCODE_CONFIG_DIR"
  if [ -d "$OPENCODE_CONFIG_DIR" ]; then
    ok "dir exists: $OPENCODE_CONFIG_DIR"
  else
    warn "dir missing: $OPENCODE_CONFIG_DIR"
    WARN=$((WARN + 1))
  fi
else
  warn "OPENCODE_CONFIG_DIR is not set (chạy install-global.sh)"
  WARN=$((WARN + 1))
fi

if [ -f "$HOME/.bashrc" ] && grep -qF 'OPENCODE_CONFIG_DIR' "$HOME/.bashrc" 2>/dev/null; then
  ok "~/.bashrc có export OPENCODE_CONFIG_DIR"
else
  warn "~/.bashrc thiếu export OPENCODE_CONFIG_DIR"
  WARN=$((WARN + 1))
fi

# --- Pack structure ---
echo ""
info "Pack structure check"
for sub in commands agents skills; do
  if [ -d "$GLOBAL_DIR/$sub" ]; then
    n=$(find "$GLOBAL_DIR/$sub" -maxdepth 2 -type f | wc -l)
    ok "opencode-global/$sub/ ($n entries)"
  else
    err "opencode-global/$sub/ missing"
  fi
done

# --- Scripts ---
echo ""
info "Scripts check"
for s in install.sh verify.sh install-global.sh update-bmad.sh \
         doctor.sh uninstall.sh \
         scripts/install-token-tools.sh scripts/integration-test.sh \
         scripts/validate-opencode-pack.py; do
  if [ -f "$KIT_DIR/$s" ]; then
    ok "$s"
  else
    warn "$s missing"
    WARN=$((WARN + 1))
  fi
done

# --- No MCP ---
echo ""
info "Safety: no MCP config in opencode-global/"
if grep -rE '"mcp"\s*:' "$GLOBAL_DIR" >/dev/null 2>&1; then
  err "MCP config detected in opencode-global/"
else
  ok "no MCP config in opencode-global/"
fi

# --- No secrets (kit repo) ---
echo ""
info "Safety: no secret patterns in kit source"
# api_key=/password= require literal '=' and >=8 alphanumeric
# (plus _ and -) value chars. Real secret tokens are typically
# alphanumeric. We exclude this file (and the .github/ tree, which
# also embeds the same regex source) to avoid self-match.
hits=$(grep -rEn \
  'sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|BEGIN .* PRIVATE KEY|api_key=[A-Za-z0-9_\-]{8,}|password=[A-Za-z0-9_\-]{8,}' \
  "$KIT_DIR" \
  --include='*.sh' \
  --include='*.md' \
  --include='*.json' \
  --include='*.yml' \
  --include='*.yaml' \
  --include='*.py' \
  --exclude-dir='.git' \
  --exclude-dir='.github' \
  --exclude='CHANGELOG.md' \
  --exclude='README.md' \
  --exclude='doctor.sh' \
  --exclude='docs/*' 2>/dev/null || true)
if [ -n "$hits" ]; then
  err "possible secrets found in kit:"
  echo "$hits" >&2
else
  ok "no secret patterns matched"
fi

# --- .env files in project ---
echo ""
info "Safety: no .env files in current project"
env_found=0
for f in .env .env.local .env.production; do
  if [ -f "$f" ]; then
    warn ".env-like file present: $f (do not commit)"
    env_found=1
  fi
done
if [ "$env_found" -eq 0 ]; then
  ok "no .env-like files in $(pwd)"
fi

# --- Pack validation (frontmatter) ---
echo ""
info "Pack validation (frontmatter)"
if command -v python3 >/dev/null 2>&1 && [ -f "$KIT_DIR/scripts/validate-opencode-pack.py" ]; then
  if python3 "$KIT_DIR/scripts/validate-opencode-pack.py" >/dev/null 2>&1; then
    ok "pack frontmatter ok"
  else
    err "pack frontmatter has issues (run validate-opencode-pack.py)"
  fi
else
  warn "python3 hoặc validate-opencode-pack.py không có - bỏ qua"
fi

# --- Summary ---
echo ""
echo "=========================================="
if [ "$FAIL" -ne 0 ]; then
  err "Doctor: CÓ LỖI — xem ở trên"
  exit 1
fi
if [ "$WARN" -gt 0 ]; then
  warn "Doctor: $WARN cảnh báo, không có lỗi nghiêm trọng"
else
  ok "Doctor: sạch, không có cảnh báo"
fi
echo "=========================================="
