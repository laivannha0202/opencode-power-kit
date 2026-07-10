#!/usr/bin/env bash
# ============================================================================
# test-runtime-behavior.sh — Chạy tất cả behavioral tests
# Runs all behavioral/integration tests and reports results.
# Exit 0 = all pass, exit 1 = any fail.
# ============================================================================
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

run_test() {
  local name="$1"
  local cmd="$2"
  TOTAL=$((TOTAL + 1))
  printf "  [%d] %-50s " "$TOTAL" "$name"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "✅"
    PASSED=$((PASSED + 1))
  else
    echo "❌"
    FAILED=$((FAILED + 1))
  fi
}

skip_test() {
  local name="$1"
  local reason="$2"
  TOTAL=$((TOTAL + 1))
  printf "  [%d] %-50s " "$TOTAL" "$name"
  echo "⏭️  ($reason)"
  SKIPPED=$((SKIPPED + 1))
}

section() {
  echo ""
  echo "━━━ $1 ━━━"
}

echo "=== Runtime Behavior Tests ==="
echo "Kit: $KIT_DIR"
echo ""

# --- 1. Permission rule ordering ---
section "1. Permission Rule Ordering"
for tpl in opencode.json opencode.power.json opencode.safe.json; do
  f="$KIT_DIR/templates/$tpl"
  if [ -f "$f" ]; then
    run_test "$tpl: wildcard before deny" \
      "python3 $SCRIPT_DIR/test-permission-rules.py '$f' 2>/dev/null"
  else
    skip_test "$tpl: wildcard before deny" "file not found"
  fi
done

# --- 2. Safety Plugin ---
section "2. Safety Plugin"
SP="$KIT_DIR/templates/plugins/opk-safety-guard.js"
if [ -f "$SP" ]; then
  if command -v node >/dev/null 2>&1; then
    run_test "Safety plugin: unit tests" \
      "node --experimental-vm-modules $SCRIPT_DIR/test-safety-plugin.mjs 2>/dev/null || node $SCRIPT_DIR/test-safety-plugin.mjs 2>/dev/null"
  else
    skip_test "Safety plugin: unit tests" "node not found"
  fi
else
  skip_test "Safety plugin: unit tests" "plugin not found"
fi

# --- 3. Mode Detection ---
section "3. Mode Detection"
if [ -f "$SCRIPT_DIR/detect-mode.py" ] && command -v python3 >/dev/null 2>&1; then
  run_test "Mode detection: Power template" \
    "test \"$(python3 "$SCRIPT_DIR/detect-mode.py" "$KIT_DIR/templates/opencode.power.json" 2>/dev/null)\" = POWER"
  run_test "Mode detection: Safe template" \
    "test \"$(python3 "$SCRIPT_DIR/detect-mode.py" "$KIT_DIR/templates/opencode.safe.json" 2>/dev/null)\" = SAFE"
  run_test "Mode detection: test-opk-mode.sh" \
    "bash $SCRIPT_DIR/test-opk-mode.sh 2>/dev/null"
else
  skip_test "Mode detection tests" "detect-mode.py or python3 not found"
fi

# --- 4. Merge Script ---
section "4. Merge Script"
if [ -f "$SCRIPT_DIR/merge-opk-project.py" ]; then
  run_test "Merge script: import os present" \
    "grep -q '^import os' $SCRIPT_DIR/merge-opk-project.py"
  run_test "Merge script: syntax valid" \
    "python3 -c 'import py_compile; py_compile.compile(\"$SCRIPT_DIR/merge-opk-project.py\", doraise=True)' 2>/dev/null"
else
  skip_test "Merge script tests" "merge-opk-project.py not found"
fi

# --- 5. Installer Preservation ---
section "5. Installer Preservation"
if [ -f "$SCRIPT_DIR/test-installer-preservation.sh" ]; then
  run_test "Installer preservation test" \
    "bash $SCRIPT_DIR/test-installer-preservation.sh 2>/dev/null"
else
  skip_test "Installer preservation test" "test script not found"
fi

# --- 6. Doctor Script ---
section "6. Doctor Script"
if [ -f "$KIT_DIR/doctor.sh" ]; then
  run_test "Doctor: basic check passes" \
    "bash $KIT_DIR/doctor.sh 2>/dev/null"
  run_test "Doctor: bash -n syntax" \
    "bash -n $KIT_DIR/doctor.sh 2>/dev/null"
else
  skip_test "Doctor: basic check" "doctor.sh not found"
fi

# --- 7. Release Gate ---
section "7. Release Gate"
if [ -f "$SCRIPT_DIR/release-gate.sh" ]; then
  run_test "Release gate: passes" \
    "bash $SCRIPT_DIR/release-gate.sh 2>/dev/null"
else
  skip_test "Release gate" "release-gate.sh not found"
fi

# --- 8. No Personal Paths ---
section "8. Safety Checks"
run_test "No /home/nha in opencode-global/" \
  "test \"$(grep -rl '/home/nha' '$KIT_DIR/opencode-global/' 2>/dev/null | wc -l)\" -eq 0"
run_test "No /home/nha in extras/" \
  "test \"$(grep -rl '/home/nha' '$KIT_DIR/extras/' 2>/dev/null | wc -l)\" -eq 0"

# --- 9. GSD Agents ---
section "9. GSD Agent Relocation"
run_test "No gsd-*.md in opencode-global/agents/" \
  "test \"$(find '$KIT_DIR/opencode-global/agents' -maxdepth 1 -name 'gsd-*.md' 2>/dev/null | wc -l)\" -eq 0"
GSD_REF=$(find "$KIT_DIR/extras/gsd-agent-reference" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
run_test "GSD reference agents in extras/ (>=30)" \
  "test \"$GSD_REF\" -ge 30"

# --- Summary ---
echo ""
echo "============================="
echo "  Total:  $TOTAL"
echo "  Passed: $PASSED ✅"
echo "  Failed: $FAILED ❌"
echo "  Skipped: $SKIPPED ⏭️"
echo ""

if [ "$FAILED" -gt 0 ]; then
  echo "❌ TESTS FAILED"
  exit 1
else
  echo "✅ ALL TESTS PASSED"
  exit 0
fi
