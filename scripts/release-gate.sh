#!/usr/bin/env bash
# ============================================================================
# release-gate.sh — Release readiness gate
# Kiểm tra tất cả điều kiện trước khi release.
# Linux-only local release gate.
# ============================================================================
set -uo pipefail
# NOTE: khong dung -e vi script tinh exit code rieng cho tung command

# Tranh vong lap: test-runtime-behavior.sh chay release-gate.sh ben trong
export RELEASE_GATE_RUNNING=1

SELF="${BASH_SOURCE[0]}"
KIT_DIR="$(cd "$(dirname "$SELF")/.." && pwd)"
source "$KIT_DIR/scripts/require-linux.sh"
opk_require_linux
VERSION="$(cat "$KIT_DIR/VERSION" 2>/dev/null || echo "?")"
errors=0
warnings=0
if [ "$#" -gt 0 ]; then
  echo "Usage: $(basename "$0")" >&2
  exit 126
fi

pass()  { echo "  ✅ $*"; }
warn()  { echo "  ⚠️  $*"; warnings=$((warnings + 1)); }
fail()  { echo "  ❌ $*"; errors=$((errors + 1)); }
info()  { echo "  ℹ️  $*"; }
section() { echo ""; echo "=== $* ==="; }

echo "Release Gate — checking readiness for v$VERSION"
echo "Kit: $KIT_DIR"

# ============================================================================
# PHAN 1: Infrastructure checks
# ============================================================================

# --- 1. VERSION file ---
section "1. VERSION"
if [ -f "$KIT_DIR/VERSION" ]; then
  ver="$(cat "$KIT_DIR/VERSION")"
  if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    pass "VERSION = $ver (valid semver)"
  else
    fail "VERSION = '$ver' (not semver)"
  fi
else
  fail "VERSION file missing"
fi

# --- 1b. Linux-only distribution contract ---
section "1b. Linux-only Distribution"
WINDOWS_ARTIFACTS="$(find "$KIT_DIR" -type f \( -name '*.ps1' -o -name '*.cmd' -o -name '*.bat' \) \
  -not -path "$KIT_DIR/.git/*" -not -path "$KIT_DIR/.tmp/*" -not -path "$KIT_DIR/.test/*" 2>/dev/null || true)"
if [ -n "$WINDOWS_ARTIFACTS" ]; then
  fail "Windows runtime artifacts are still tracked:"
  printf '%s\n' "$WINDOWS_ARTIFACTS" | sed 's/^/     /'
else
  pass "No tracked .ps1/.cmd/.bat runtime artifacts"
fi

EXTRA_WORKFLOWS="$(find "$KIT_DIR/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) ! -name 'ci.yml' 2>/dev/null || true)"
if [ -n "$EXTRA_WORKFLOWS" ]; then
  fail "Unexpected GitHub Actions workflows found: $(echo "$EXTRA_WORKFLOWS" | tr '\n' ' ')"
else
  pass "only ci.yml present in .github/workflows"
fi

# --- 2. CHANGELOG ---
section "2. CHANGELOG"
if [ -f "$KIT_DIR/CHANGELOG.md" ]; then
  if grep -q "## \[$VERSION\]" "$KIT_DIR/CHANGELOG.md"; then
    pass "CHANGELOG has section [$VERSION]"
  else
    fail "CHANGELOG missing section [$VERSION]"
  fi
  dupes=$(grep -c "^## \[" "$KIT_DIR/CHANGELOG.md" 2>/dev/null || echo "0")
  info "Total version headings: $dupes"
else
  fail "CHANGELOG.md missing"
fi

# --- 3. Templates ---
section "3. Config Templates"
for tpl in opencode.json opencode.power.json opencode.safe.json; do
  if [ -f "$KIT_DIR/templates/$tpl" ]; then
    pass "templates/$tpl exists"
    if grep -q '"rm -rf' "$KIT_DIR/templates/$tpl" 2>/dev/null; then
      pass "templates/$tpl has deny-list"
    else
      fail "templates/$tpl missing deny-list"
    fi
  else
    fail "templates/$tpl missing"
  fi
done

for tpl in opencode.json opencode.power.json opencode.safe.json; do
  f="$KIT_DIR/templates/$tpl"
  if [ -f "$f" ]; then
    wc_line=$(grep -n '^\s*"\*":' "$f" | head -1 | cut -d: -f1 || echo "9999")
    deny_line=$(grep -n '"rm -rf' "$f" | head -1 | cut -d: -f1 || echo "0")
    if [ "$wc_line" -lt "$deny_line" ] 2>/dev/null; then
      pass "templates/$tpl: wildcard before deny (correct order)"
    else
      fail "templates/$tpl: deny rules before wildcard (wrong order)"
    fi
  fi
done

# --- 4. Safety & Token Plugins ---
section "4. Safety & Token Plugins"
SP="$KIT_DIR/templates/plugins/opk-safety-guard.js"
if [ -f "$SP" ]; then
  pass "Safety plugin exists"
  if grep -q "tool.execute.before" "$SP"; then
    pass "Uses tool.execute.before hook (CommonJS)"
  else
    fail "Missing tool.execute.before hook"
  fi
  if grep -q "throw new Error" "$SP"; then
    pass "Uses throw new Error() for blocking"
  else
    fail "Missing throw new Error() pattern"
  fi
else
  fail "Safety plugin missing"
fi
TP="$KIT_DIR/templates/plugins/opk-token-guard.js"
if [ -f "$TP" ]; then
  pass "Token-guard plugin exists"
  if grep -q "tool.execute.before" "$TP"; then
    pass "Uses tool.execute.before hook (CommonJS)"
  else
    fail "Missing tool.execute.before hook"
  fi
  if grep -q "throw new Error" "$TP"; then
    pass "Uses throw new Error() for blocking"
  else
    fail "Missing throw new Error() pattern"
  fi
  if grep -q "@opk-plugin opk-token-guard" "$TP"; then
    pass "Has @opk-plugin opk-token-guard marker"
  else
    fail "Missing @opk-plugin marker"
  fi
else
  fail "Token-guard plugin missing"
fi

# --- 5. GSD Agents ---
section "5. GSD Agents"
GSD_ACTIVE=$(find "$KIT_DIR/opencode-global/agents" -maxdepth 1 -name "gsd-*.md" 2>/dev/null | wc -l)
if [ "$GSD_ACTIVE" -gt 0 ]; then
  fail "$GSD_ACTIVE GSD agents still in opencode-global/agents/"
else
  pass "No GSD agents in active dir"
fi
GSD_REF=$(find "$KIT_DIR/extras/gsd-agent-reference" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
if [ "$GSD_REF" -gt 0 ]; then
  pass "GSD reference agents in extras/ ($GSD_REF files)"
else
  warn "No GSD reference agents in extras/"
fi

# --- 6. Scripts ---
section "6. Scripts"
for s in detect-mode.py merge-opk-project.py install-global.py install-fullstack-profile.py opk-permissions.py \
         opk_safe_io.py opk_tx.py opk_install_session.py check-runtime-plugins.mjs \
         validate-opencode-pack.py check-cli-file-references.py \
         check-opencode-config-paths.py check-agent-permission-contracts.py test-ci-opencode-pin.py \
         test-cli-contracts.sh test-global-installer.sh \
         test-opencode-resolved-config.sh audit-hermes.sh; do
  if [ -f "$KIT_DIR/scripts/$s" ]; then
    pass "scripts/$s exists"
  else
    fail "scripts/$s missing"
  fi
done

if grep -q "^import os" "$KIT_DIR/scripts/merge-opk-project.py" 2>/dev/null; then
  pass "merge-opk-project.py has import os"
else
  fail "merge-opk-project.py missing import os"
fi

if grep -q "from opk_mode import .*load_config" "$KIT_DIR/scripts/detect-mode.py" 2>/dev/null && \
   grep -q "data = load_config(path)" "$KIT_DIR/scripts/detect-mode.py" 2>/dev/null; then
  pass "detect-mode.py uses shared JSON/JSONC parser"
else
  warn "detect-mode.py shared parser delegation not detected"
fi

# --- 7. No personal paths ---
section "7. Personal Path Check"
PERSONAL=0
if grep -rl '/home/nha' "$KIT_DIR/opencode-global/" "$KIT_DIR/extras/" >/dev/null 2>&1; then
  PERSONAL=$(grep -rl '/home/nha' "$KIT_DIR/opencode-global/" "$KIT_DIR/extras/" 2>/dev/null | wc -l)
fi
if [ "$PERSONAL" -gt 0 ]; then
  fail "$PERSONAL files contain /home/nha path"
else
  pass "No personal paths in runtime dirs"
fi

# --- 8. Shell syntax ---
section "8. Shell Syntax"
SHELL_ERRS=0
# Individual syntax checks for critical scripts
for s in "$KIT_DIR"/install.sh "$KIT_DIR"/doctor.sh "$KIT_DIR"/verify.sh \
         "$KIT_DIR"/scripts/release-gate.sh "$KIT_DIR"/scripts/integration-test.sh \
         "$KIT_DIR"/bin/opk "$KIT_DIR"/scripts/*.sh; do
  [ -f "$s" ] || continue
  if ! bash -n "$s" 2>/dev/null; then
    fail "bash -n failed: $(basename "$s")"
    SHELL_ERRS=$((SHELL_ERRS + 1))
  fi
done
if [ "$SHELL_ERRS" -eq 0 ]; then
  pass "All shell scripts pass bash -n"
fi

# --- 9. Tests exist ---
section "9. Test Coverage"
for s in test-permission-rules.py test-safety-plugin.mjs test-token-guard.mjs \
         test-opk-mode.sh test-installer-preservation.sh test-fullstack-installer.sh test-global-installer.sh \
         test-opencode-resolved-config.sh test-timeout.sh test-runtime-behavior.sh \
         test-wal-recovery.sh test-legacy-recovery.sh test-safe-io.sh \
         test-tx.sh test-install-tx.sh test-install-session.sh test-bmad-log-lifecycle.sh test-doctor-runtime.sh test-hardening-contract.py \
         test-command-guard.sh test-guard-no-env-bypass.sh test-guard-interactive.py \
         test-phase2-upstream-contract.py test-release-metadata.py test-ci-opencode-pin.py \
         check-bmad-runtime-prereqs.sh; do
  if [ -f "$KIT_DIR/scripts/$s" ]; then
    pass "scripts/$s exists"
  else
    warn "scripts/$s missing"
  fi
done

# --- 10. Evals ---
section "10. Eval Harness"
if [ -d "$KIT_DIR/evals" ]; then
  pass "evals/ directory exists"
else
  warn "evals/ directory not found"
fi
# --- run_cmd helper (defined early for use in Phase 10+) ---
declare -a RESULTS=()
CMD_TIMEOUT=120  # 2 phut moi command

run_cmd() {
  local label="$1"
  shift
  local cmd_str="$*"

  # Kiem tra file ton tai (neu la script file)
  local first_arg="${1}"
  if [[ "$first_arg" == *.py || "$first_arg" == *.mjs || "$first_arg" == *.sh ]] && [[ ! "$first_arg" =~ ^python3|^node|^bash|^git ]]; then
    if [ ! -f "$first_arg" ] && [ ! -f "$KIT_DIR/$first_arg" ]; then
      echo "  ⏭️  $label — SKIP (file not found: $first_arg)"
      RESULTS+=("SKIP|$label|skip|file not found")
      return
    fi
  fi

  # Kiem tra interpreter ton tai
  local interp="${cmd_str%% *}"
  case "$interp" in
    python3)
      if ! command -v python3 &>/dev/null; then
        echo "  ❌ $label — FAIL (required dependency python3 not found)"
        RESULTS+=("FAIL|$label|missing|python3 not found")
        errors=$((errors + 1))
        return
      fi
      ;;
    node)
      if ! command -v node &>/dev/null; then
        echo "  ❌ $label — FAIL (required dependency node not found)"
        RESULTS+=("FAIL|$label|missing|node not found")
        errors=$((errors + 1))
        return
      fi
      ;;
  esac

  # Chay command voi timeout qua portable timeout helper, bat exit code
  local output
  local rc
  output=$(bash "$KIT_DIR/scripts/timeout.sh" "$CMD_TIMEOUT" bash -c "$cmd_str" 2>&1) && rc=0 || rc=$?

  if [ "$rc" -eq 0 ]; then
    echo "  ✅ $label — PASS (exit $rc)"
    RESULTS+=("PASS|$label|$rc|")
  elif [ "$rc" -eq 124 ]; then
    echo "  ⏰ $label — TIMEOUT (>${CMD_TIMEOUT}s)"
    RESULTS+=("FAIL|$label|timeout|")
    errors=$((errors + 1))
  else
    echo "  ❌ $label — FAIL (exit $rc)"
    # In output neu co loi (gioi han 20 dong dau)
    if [ -n "$output" ]; then
      echo "$output" | head -20 | sed 's/^/     /'
      local line_count
      line_count=$(echo "$output" | wc -l)
      if [ "$line_count" -gt 20 ]; then
        echo "     ... ($((line_count - 20)) more lines)"
      fi
    fi
    RESULTS+=("FAIL|$label|$rc|")
    errors=$((errors + 1))
  fi
}

# Run eval harness (workflow regression tests, no model calls)
if [ -f "$KIT_DIR/evals/run.sh" ]; then
  PREV_CMD_TIMEOUT=$CMD_TIMEOUT
  CMD_TIMEOUT=300  # evals can be slow due to script_exec checks
  run_cmd "evals/run.sh" \
    "bash $KIT_DIR/evals/run.sh"
  CMD_TIMEOUT=$PREV_CMD_TIMEOUT
fi

# ============================================================================
# PHAN 2: Chay thuc te cac lenh test/validation
# ============================================================================
section "11. Command Execution (actual runs)"

# --- Python validators ---
echo ""
echo "--- Python Validators ---"
run_cmd "validate-formatting" \
  "python3 $KIT_DIR/scripts/validate-formatting.py"

run_cmd "audit-upstreams" \
  "python3 $KIT_DIR/scripts/audit-upstreams.py --check"

run_cmd "validate-opencode-pack" \
  "python3 $KIT_DIR/scripts/validate-opencode-pack.py"

run_cmd "check-cli-file-references" \
  "python3 $KIT_DIR/scripts/check-cli-file-references.py"

run_cmd "check-opencode-config-paths" \
  "python3 $KIT_DIR/scripts/check-opencode-config-paths.py"

run_cmd "check-agent-permission-contracts" \
  "python3 $KIT_DIR/scripts/check-agent-permission-contracts.py"

# --- Permission & Safety Tests ---
echo ""
echo "--- Permission & Safety Tests ---"
run_cmd "test-permission-rules" \
  "python3 $KIT_DIR/scripts/test-permission-rules.py"

run_cmd "test-safety-plugin" \
  "node $KIT_DIR/scripts/test-safety-plugin.mjs"

run_cmd "test-token-guard" \
  "node $KIT_DIR/scripts/test-token-guard.mjs"

run_cmd "test-doctor-runtime" \
  "bash $KIT_DIR/scripts/test-doctor-runtime.sh"

run_cmd "test-hardening-contract" \
  "python3 $KIT_DIR/scripts/test-hardening-contract.py"

run_cmd "test-phase2-upstream-contract" \
  "python3 $KIT_DIR/scripts/test-phase2-upstream-contract.py"

run_cmd "test-release-metadata" \
  "python3 $KIT_DIR/scripts/test-release-metadata.py"

run_cmd "test-ci-opencode-pin" \
  "python3 $KIT_DIR/scripts/test-ci-opencode-pin.py"

# --- Shell Tests ---
echo ""
echo "--- Shell Tests ---"
run_cmd "test-command-guard" \
  "bash $KIT_DIR/scripts/test-command-guard.sh"

run_cmd "test-guard-no-env-bypass" \
  "bash $KIT_DIR/scripts/test-guard-no-env-bypass.sh"

run_cmd "test-guard-interactive" \
  "python3 $KIT_DIR/scripts/test-guard-interactive.py"

run_cmd "test-opk-mode" \
  "bash $KIT_DIR/scripts/test-opk-mode.sh"

run_cmd "test-opk-permissions" \
  "bash $KIT_DIR/scripts/test-opk-permissions.sh"

run_cmd "test-agent-permission-contracts" \
  "bash $KIT_DIR/scripts/test-agent-permission-contracts.sh"

run_cmd "test-cli-contracts" \
  "bash $KIT_DIR/scripts/test-cli-contracts.sh"

run_cmd "audit-hermes --check" \
  "bash $KIT_DIR/scripts/audit-hermes.sh --check"

run_cmd "test-installer-preservation" \
  "bash $KIT_DIR/scripts/test-installer-preservation.sh"

run_cmd "test-fullstack-installer" \
  "bash $KIT_DIR/scripts/test-fullstack-installer.sh"

run_cmd "test-global-installer" \
  "bash $KIT_DIR/scripts/test-global-installer.sh"

run_cmd "test-opencode-resolved-config" \
  "bash $KIT_DIR/scripts/test-opencode-resolved-config.sh"

run_cmd "test-timeout" \
  "bash $KIT_DIR/scripts/test-timeout.sh"

run_cmd "test-runtime-behavior" \
  "bash $KIT_DIR/scripts/test-runtime-behavior.sh"

run_cmd "test-wal-recovery" \
  "bash $KIT_DIR/scripts/test-wal-recovery.sh"

run_cmd "test-legacy-recovery" \
  "bash $KIT_DIR/scripts/test-legacy-recovery.sh"

# --- Safe-I/O & Transaction Tests ---
echo ""
echo "--- Safe-I/O & Transaction Tests ---"
run_cmd "detect-mode templates" \
  "test \"\$(python3 $KIT_DIR/scripts/detect-mode.py $KIT_DIR/templates/opencode.power.json)\" = POWER && test \"\$(python3 $KIT_DIR/scripts/detect-mode.py $KIT_DIR/templates/opencode.safe.json)\" = SAFE"

run_cmd "test-safe-io" \
  "bash $KIT_DIR/scripts/test-safe-io.sh"

run_cmd "test-tx" \
  "bash $KIT_DIR/scripts/test-tx.sh"

run_cmd "test-install-tx" \
  "bash $KIT_DIR/scripts/test-install-tx.sh"

run_cmd "test-install-session" \
  "bash $KIT_DIR/scripts/test-install-session.sh"

run_cmd "test-bmad-log-lifecycle" \
  "bash $KIT_DIR/scripts/test-bmad-log-lifecycle.sh"

# --- Path Safety & JSONC Tests ---
echo ""
echo "--- Path Safety & JSONC Tests ---"
run_cmd "test-project-installer-path-safety" \
  "bash $KIT_DIR/scripts/test-project-installer-path-safety.sh"

run_cmd "test-opencode-jsonc-compatibility" \
  "bash $KIT_DIR/scripts/test-opencode-jsonc-compatibility.sh"

run_cmd "check-project-installer-path-safety" \
  "python3 $KIT_DIR/scripts/check-project-installer-path-safety.py"

# --- Full Verification ---
echo ""
echo "--- Full Verification ---"
run_cmd "verify.sh" \
  "bash $KIT_DIR/verify.sh"

run_cmd "doctor.sh" \
  "bash $KIT_DIR/doctor.sh"

# doctor --deep va integration-test co the chay lau
CMD_TIMEOUT=300
run_cmd "doctor.sh --deep" \
  "bash $KIT_DIR/doctor.sh --deep"

OPK_TEST_MODE_WAS_SET="${OPK_TEST_MODE+x}"
OPK_TEST_MODE_PREVIOUS="${OPK_TEST_MODE:-}"
export OPK_TEST_MODE=1
run_cmd "integration-test" \
  "bash $KIT_DIR/scripts/integration-test.sh"
if [ "$OPK_TEST_MODE_WAS_SET" = "x" ]; then
  export OPK_TEST_MODE="$OPK_TEST_MODE_PREVIOUS"
else
  unset OPK_TEST_MODE
fi
CMD_TIMEOUT=120

# --- Git Checks ---
echo ""
echo "--- Git Checks ---"
# Check for whitespace errors in all changes from base branch
# Resolve merge-base with strict fallback chain (no silent degradation):
#   1. OPK_BASE_REF (explicit, fail if invalid)
#   2. origin/main (fail if exists but merge-base fails)
#   3. local main (only when origin/main truly absent)
#   4. FAIL — no fallback to HEAD~1, HEAD, or HEAD HEAD
MERGE_BASE=""
if [ -n "${OPK_BASE_REF:-}" ]; then
  if ! git -C "$KIT_DIR" rev-parse --verify "$OPK_BASE_REF" >/dev/null 2>&1; then
    fail "OPK_BASE_REF=$OPK_BASE_REF is not a valid ref"
    MERGE_BASE="SKIP"
  else
    MERGE_BASE=$(git -C "$KIT_DIR" merge-base "$OPK_BASE_REF" HEAD 2>/dev/null) || true
    if [ -z "$MERGE_BASE" ]; then
      fail "Cannot compute merge-base with OPK_BASE_REF=$OPK_BASE_REF (ref valid but no common ancestor with HEAD)"
      MERGE_BASE="SKIP"
    fi
  fi
elif git -C "$KIT_DIR" rev-parse --verify origin/main >/dev/null 2>&1; then
  MERGE_BASE=$(git -C "$KIT_DIR" merge-base origin/main HEAD 2>/dev/null) || true
  if [ -z "$MERGE_BASE" ]; then
    fail "origin/main exists but cannot compute merge-base with HEAD (try: git fetch origin)"
    MERGE_BASE="SKIP"
  fi
elif git -C "$KIT_DIR" rev-parse --verify main >/dev/null 2>&1; then
  MERGE_BASE=$(git -C "$KIT_DIR" merge-base main HEAD 2>/dev/null) || true
  if [ -z "$MERGE_BASE" ]; then
    fail "local main exists but cannot compute merge-base with HEAD"
    MERGE_BASE="SKIP"
  fi
else
  fail "No main branch found (neither origin/main nor local main). Skipping git diff --check."
  MERGE_BASE="SKIP"
fi
if [ "$MERGE_BASE" != "SKIP" ]; then
  run_cmd "git-diff-check (from base)" \
    "git -C '$KIT_DIR' diff --check '$MERGE_BASE' HEAD"
fi

# ============================================================================
# PHAN 3: Summary
# ============================================================================
echo ""
echo "============================================================================"
echo "  RELEASE GATE SUMMARY — v$VERSION"
echo "============================================================================"
echo ""

# In bang ket qua
printf "  %-35s %-8s %s\n" "COMMAND" "STATUS" "EXIT"
printf "  %-35s %-8s %s\n" "-----------------------------------" "--------" "----"

pass_count=0
fail_count=0
skip_count=0

for entry in "${RESULTS[@]}"; do
  IFS='|' read -r status name rc _rest <<< "$entry"
  case "$status" in
    PASS)
      printf "  %-35s %-8s %s\n" "$name" "✅ PASS" "$rc"
      pass_count=$((pass_count + 1))
      ;;
    FAIL)
      printf "  %-35s %-8s %s\n" "$name" "❌ FAIL" "$rc"
      fail_count=$((fail_count + 1))
      ;;
    SKIP)
      printf "  %-35s %-8s %s\n" "$name" "⏭️  SKIP" "-"
      skip_count=$((skip_count + 1))
      ;;
  esac
done

echo ""
printf "  Total: %d | ✅ PASS: %d | ❌ FAIL: %d | ⏭️  SKIP: %d | ⚠️  WARN: %d\n" \
  "${#RESULTS[@]}" "$pass_count" "$fail_count" "$skip_count" "$warnings"

echo ""
echo "============================="
if [ "$errors" -gt 0 ]; then
  echo "❌ RELEASE GATE FAILED — $errors error(s), $warnings warning(s)"
  echo "   NOT RELEASE READY — fix required failures."
  exit 1
else
  echo "✅ RELEASE GATE PASSED — $warnings warning(s)"
  echo "   Ready to release v$VERSION for Linux"
  exit 0
fi
