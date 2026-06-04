#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Integration Test
# Mục đích: chạy install.sh vào một project giả trong temp dir, sau đó chạy
# verify.sh và kiểm tra các file/thư mục kỳ vọng đã được tạo.
# Không tự gọi curl|sh, không xóa file user.
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[FAIL]${NC} $*"; FAIL=1; }

FAIL=0

# --- Resolve kit dir (this script's parent) ---
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
info "Kit dir: $KIT_DIR"

# --- Create temp project ---
TMP_DIR="$(mktemp -d -t opencode-power-kit-int-XXXXXX)"
info "Temp project: $TMP_DIR"

cleanup() {
  if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
    info "Cleanup: rm -rf $TMP_DIR"
    rm -rf "$TMP_DIR"
  fi
}
trap cleanup EXIT

# --- Seed fake project ---
cd "$TMP_DIR"
git init -q -b main .
git config user.email "ci@opencode-power-kit.local"
git config user.name "ci-bot"

cat > package.json <<'JSON'
{
  "name": "opencode-power-kit-integration",
  "version": "0.0.0",
  "private": true
}
JSON
git add package.json
git commit -q -m "chore: seed package.json"

ok "Seeded fake project at $TMP_DIR"

# --- Run install.sh (kit -> project) ---
info "Running install.sh from $KIT_DIR into $TMP_DIR ..."
if [ ! -x "$KIT_DIR/install.sh" ]; then
  err "install.sh not executable: $KIT_DIR/install.sh"
  exit 1
fi

# install.sh uses `pwd` as TARGET_DIR and computes KIT_DIR from its own
# dirname. Running it from the temp project, but invoking the kit's copy,
# means it copies the kit's templates into the project. Perfect.
set +e
bash "$KIT_DIR/install.sh" >/tmp/install.log 2>&1
install_rc=$?
set -e

if [ "$install_rc" -ne 0 ]; then
  err "install.sh exited $install_rc"
  echo "----- /tmp/install.log (tail) -----" >&2
  tail -30 /tmp/install.log >&2
else
  ok "install.sh completed (rc=0)"
fi

# --- Run verify.sh in the temp project ---
info "Running verify.sh in $TMP_DIR ..."
set +e
( cd "$TMP_DIR" && bash "$KIT_DIR/verify.sh" ) >/tmp/verify.log 2>&1
verify_rc=$?
set -e

if [ "$verify_rc" -ne 0 ]; then
  warn "verify.sh exited $verify_rc (may include optional warnings)"
  echo "----- /tmp/verify.log (tail) -----" >&2
  tail -30 /tmp/verify.log >&2
else
  ok "verify.sh completed (rc=0)"
fi

# --- Check expected files/dirs ---
echo ""
info "Checking expected artifacts in $TMP_DIR ..."

check_path() {
  local rel="$1"
  local must_be="$2"  # "file" or "dir"
  if [ "$must_be" = "dir" ]; then
    if [ -d "$TMP_DIR/$rel" ]; then
      ok "$rel/"
    else
      err "$rel/ not found"
    fi
  else
    if [ -f "$TMP_DIR/$rel" ]; then
      ok "$rel"
    else
      err "$rel not found"
    fi
  fi
}

check_path "AGENTS.md"                  "file"
check_path "OPENCODE.md"                "file"
check_path ".opencode/opencode.json"    "file"
check_path ".gitignore"                 "file"
check_path "knip.json"                  "file"
check_path "lefthook.yml"               "file"
check_path "_bmad"                      "dir"
check_path ".agents/skills"             "dir"
check_path ".opencode/commands"         "dir"

# --- Final ---
echo ""
if [ "$FAIL" -ne 0 ]; then
  err "Integration test FAILED"
  exit 1
fi
ok "Integration test PASSED"
