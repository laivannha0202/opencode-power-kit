#!/usr/bin/env bash
# ============================================================================
# release-gate.sh — Release readiness gate
# Kiểm tra tất cả điều kiện trước khi release.
# Exit 0 = PASS (ready to release), exit 1 = FAIL (fix first).
# ============================================================================
set -uo pipefail
# NOTE: khong dung -e vi script tinh exit code rieng cho tung command

# Tranh vong lap: test-runtime-behavior.sh chay release-gate.sh ben trong
export RELEASE_GATE_RUNNING=1

SELF="${BASH_SOURCE[0]}"
KIT_DIR="$(cd "$(dirname "$SELF")/.." && pwd)"
VERSION="$(cat "$KIT_DIR/VERSION" 2>/dev/null || echo "?")"
errors=0
warnings=0

pass()  { echo "  ✅ $*"; }
warn()  { echo "  ⚠️  $*"; warnings=$((warnings + 1)); }
fail()  { echo "  ❌ $*"; errors=$((errors + 1)); }
info()  { echo "  ℹ️  $*"; }
skip()  { echo "  ⏭️  $*"; }
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

# --- 4. Safety Plugin ---
section "4. Safety Plugin"
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
for s in detect-mode.py merge-opk-project.py validate-opencode-pack.py; do
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

if grep -q "json.load" "$KIT_DIR/scripts/detect-mode.py" 2>/dev/null; then
  pass "detect-mode.py uses JSON parser"
else
  warn "detect-mode.py may not use JSON parser"
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
for s in test-permission-rules.py test-safety-plugin.mjs test-opk-mode.sh test-installer-preservation.sh test-runtime-behavior.sh; do
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
        echo "  ⏭️  $label — SKIP (python3 not found)"
        RESULTS+=("SKIP|$label|skip|python3 not found")
        return
      fi
      ;;
    node)
      if ! command -v node &>/dev/null; then
        echo "  ⏭️  $label — SKIP (node not found)"
        RESULTS+=("SKIP|$label|skip|node not found")
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
  run_cmd "evals/run.sh" \
    "bash $KIT_DIR/evals/run.sh"
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

# --- Permission & Safety Tests ---
echo ""
echo "--- Permission & Safety Tests ---"
run_cmd "test-permission-rules" \
  "python3 $KIT_DIR/scripts/test-permission-rules.py"

run_cmd "test-safety-plugin" \
  "node $KIT_DIR/scripts/test-safety-plugin.mjs"

# --- Shell Tests ---
echo ""
echo "--- Shell Tests ---"
run_cmd "test-opk-mode" \
  "bash $KIT_DIR/scripts/test-opk-mode.sh"

run_cmd "test-installer-preservation" \
  "bash $KIT_DIR/scripts/test-installer-preservation.sh"

run_cmd "test-runtime-behavior" \
  "bash $KIT_DIR/scripts/test-runtime-behavior.sh"

# --- Full Verification ---
echo ""
echo "--- Full Verification ---"
run_cmd "verify.sh" \
  "bash $KIT_DIR/verify.sh"

if command -v pwsh >/dev/null 2>&1; then
  run_cmd "verify.ps1" \
    "pwsh -NoProfile -File '$KIT_DIR/verify.ps1'"
else
  echo "  ⏭️  verify.ps1 — SKIP (pwsh not found)"
  RESULTS+=("SKIP|verify.ps1|skip|pwsh not found")
fi

run_cmd "doctor.sh" \
  "bash $KIT_DIR/doctor.sh"

# doctor --deep va integration-test co the chay lau
CMD_TIMEOUT=300
run_cmd "doctor.sh --deep" \
  "bash $KIT_DIR/doctor.sh --deep"

run_cmd "integration-test" \
  "bash $KIT_DIR/scripts/integration-test.sh"
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
  echo "   Fix errors before releasing."
  exit 1
else
  echo "✅ RELEASE GATE PASSED — $warnings warning(s)"
  echo "   Ready to release v$VERSION"
  exit 0
fi
