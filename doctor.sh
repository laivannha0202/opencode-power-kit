#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Doctor
# Chẩn đoán nhanh cấu hình global + project: kiểm tra OPENCODE_CONFIG_DIR,
# commands/agents/skills structure, scripts, không MCP, không secrets.
# Chỉ đọc - không sửa file.
# ============================================================================
# shellcheck disable=SC2088
#   SC2088: '~/.bashrc' in user-facing messages (intentional display string)
set -euo pipefail

# --- Parse flags ---
DEEP_MODE=0
for arg in "$@"; do
  case "$arg" in
    --deep) DEEP_MODE=1 ;;
  esac
done

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
if [ "$DEEP_MODE" -eq 1 ]; then
  echo "  OpenCode Power Kit - Doctor --deep"
else
  echo "  OpenCode Power Kit - Doctor"
fi
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

# --- Deep mode checks ---
if [ "$DEEP_MODE" -eq 1 ]; then
  echo ""
  echo "--- Doctor --deep ---"

  # --- OPK Orchestration Lite files ---
  echo ""
  info "OPK Orchestration Lite check"
  for f in \
    opencode-global/commands/intent-router.md \
    opencode-global/commands/init-deep-lite.md \
    opencode-global/commands/power-work-lite.md \
    opencode-global/commands/continue-work.md \
    opencode-global/commands/evidence-report.md \
    docs/OPK_ORCHESTRATION_LITE.md \
    docs/INSPIRATION_OH_MY_OPENAGENT.md; do
    if [ -f "$KIT_DIR/$f" ]; then
      ok "$f"
    else
      err "missing: $f"
    fi
  done

  # --- Permission mode check ---
  echo ""
  info "Permission mode check"
  if [ -f "$GLOBAL_DIR/../templates/opencode.json" ]; then
    if grep -q '"permission": "allow"' "$GLOBAL_DIR/../templates/opencode.json" 2>/dev/null; then
      ok "Power Mode (permission: allow) detected"
    elif grep -q '"permission"' "$GLOBAL_DIR/../templates/opencode.json" 2>/dev/null; then
      ok "Permission mode configured (not Power Mode)"
    else
      warn "No explicit permission mode in templates/opencode.json"
      WARN=$((WARN + 1))
    fi
  else
    warn "templates/opencode.json not found"
    WARN=$((WARN + 1))
  fi

  # --- MCP check in templates ---
  echo ""
  info "Safety: no MCP auto-enabled in templates"
  if grep -rE '"mcp"\s*:' "$KIT_DIR/templates" >/dev/null 2>&1; then
    err "MCP config detected in templates/"
  else
    ok "no MCP config in templates/"
  fi

  # --- Telemetry check ---
  echo ""
  info "Safety: no telemetry in kit"
  if grep -rEi 'posthog|mixpanel|amplitude|segment\.io|heap\.io' \
    "$GLOBAL_DIR" --include='*.md' --include='*.json' --include='*.js' --exclude-dir='node_modules' >/dev/null 2>&1; then
    err "telemetry patterns detected in opencode-global/"
  else
    ok "no telemetry patterns in opencode-global/"
  fi

  # --- oh-my-openagent not vendored ---
  echo ""
  info "Safety: oh-my-openagent not vendored"
  if [ -d "$KIT_DIR/node_modules/oh-my-openagent" ] || \
     [ -d "$KIT_DIR/vendor/oh-my-openagent" ] || \
     grep -r "oh-my-openagent" "$GLOBAL_DIR" >/dev/null 2>&1; then
    err "oh-my-openagent appears to be vendored/referenced in kit source"
  else
    ok "oh-my-openagent not vendored"
  fi

  # --- Optional tools detection ---
  echo ""
  info "Optional tools detection"
  OPTIONAL_TOOLS=(
    "rg:Fast grep:ripgrep"
    "fd:Fast find:fd-find"
    "sg:Structural search:ast-grep"
    "ast-grep:Structural search:ast-grep"
    "jq:JSON processor:jq"
    "shellcheck:Bash linter:shellcheck"
    "shfmt:Bash formatter:shfmt"
    "node:Node.js:nodejs"
    "npm:npm:npm"
    "git:Git:git"
    "docker:Docker:docker"
    "python3:Python 3:python3"
  )
  for tool_entry in "${OPTIONAL_TOOLS[@]}"; do
    IFS=':' read -r tool_name purpose install_hint <<< "$tool_entry"
    if command -v "$tool_name" >/dev/null 2>&1; then
      ver=$("$tool_name" --version 2>/dev/null | head -1 || echo "?")
      ok "$tool_name ($ver) — $purpose"
    else
      warn "$tool_name not found — install: $install_hint"
      WARN=$((WARN + 1))
    fi
  done

  # --- .opk/work/ directory ---
  echo ""
  info "Runtime directory check"
  if [ -d ".opk/work" ]; then
    work_count=$(find ".opk/work" -maxdepth 1 -type f 2>/dev/null | wc -l)
    ok ".opk/work/ exists ($work_count files)"
  else
    warn ".opk/work/ not found (will be created on first /power-work-lite)"
    WARN=$((WARN + 1))
  fi
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
