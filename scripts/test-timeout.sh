#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-timeout.sh — Comprehensive timeout.sh tests
# opencode-power-kit v2.1.0
#
# Tests all timeout behaviors: system timeout, fallback, exit codes,
# grandchild cleanup, setsid-less mode, signal preservation, timeout 0.
#
# Usage:
#   bash scripts/test-timeout.sh              # run all tests
#   bash scripts/test-timeout.sh --grandchild # run grandchild test only
#   bash scripts/test-timeout.sh --case NAME  # run specific case
#
# Cases:
#   A. default-timeout      — system timeout returns 124
#   B. forced-timeout       — forced fallback returns 124
#   C. exit-code            — normal exit code preserved
#   D. forced-exit-code     — forced fallback preserves exit code
#   E. grandchild           — timeout kills grandchild processes
#   F. no-setsid-grandchild — fallback without setsid kills grandchild
#   G. signal-preservation  — command signal status preserved
#   H. timeout-zero         — timeout 0 returns 126
#   I. low-exit-codes       — exit codes 1,2,10,31,32,42,125,126,127 preserved
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT_SH="$SCRIPT_DIR/timeout.sh"
TIMEOUT_TOOL="${TIMEOUT_SH}"

errors=0
pass_count=0
fail_count=0
skip_count=0
case_count=0

pass() { echo "  ✅ $*"; pass_count=$((pass_count + 1)); }
fail() { echo "  ❌ $*"; fail_count=$((fail_count + 1)); errors=$((errors + 1)); }
skip() { echo "  ⏭️  $*"; skip_count=$((skip_count + 1)); }
info() { echo "  ℹ️  $*"; }
case_start() { case_count=$((case_count + 1)); }

cleanup_marker() {
  [ -n "${_MARKER:-}" ] && rm -f "$_MARKER" 2>/dev/null
  [ -n "${_MARKER_FILE:-}" ] && rm -f "$_MARKER_FILE" 2>/dev/null
}

# Ensure no leftover processes from test
cleanup_pids() {
  local pid
  for pid in "${_TEST_PIDS[@]:-}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  _TEST_PIDS=()
}

trap cleanup_marker EXIT
trap 'cleanup_pids; cleanup_marker' EXIT

declare -a _TEST_PIDS=()

# ── Helper: check if PID is a valid integer ──
is_valid_pid() {
  [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -gt 0 ] 2>/dev/null
}

# ── Helper: poll zombie → wait briefly for process to disappear ──
# Returns final state description: "gone", "zombie", or "alive:<state>"
poll_process_state() {
  local pid="$1"
  local max_wait="${2:-2}"
  local elapsed=0
  while [ "$elapsed" -lt "$max_wait" ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "gone"
      return
    fi
    local state
    state=$(ps -o state= -p "$pid" 2>/dev/null | tr -d ' ')
    if [ "$state" = "Z" ] || [ "$state" = "Z+" ]; then
      sleep 0.5
      elapsed=$((elapsed + 1))
      # Check again after brief wait
      if ! kill -0 "$pid" 2>/dev/null; then
        echo "gone"
        return
      fi
      state=$(ps -o state= -p "$pid" 2>/dev/null | tr -d ' ')
      if [ "$state" = "Z" ] || [ "$state" = "Z+" ]; then
        echo "zombie"
        return
      fi
    else
      echo "alive:$state"
      return
    fi
  done
  # Final check
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "gone"
  else
    local state
    state=$(ps -o state= -p "$pid" 2>/dev/null | tr -d ' ')
    echo "alive:$state"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE A: Default timeout (system) returns 124
# ─────────────────────────────────────────────────────────────────
case_default_timeout() {
  case_start
  echo ""
  echo "=== Case A: Default timeout returns 124 ==="
  local output rc
  output=$("$TIMEOUT_TOOL" 1 sleep 10 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 124 ]; then
    pass "Default timeout: exit 124"
  else
    fail "Default timeout: expected 124, got $rc"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE B: Forced fallback timeout returns 124
# ─────────────────────────────────────────────────────────────────
case_forced_timeout() {
  case_start
  echo ""
  echo "=== Case B: Forced fallback timeout returns 124 ==="
  local output rc
  output=$(env OPK_TIMEOUT_FORCE_FALLBACK=1 "$TIMEOUT_TOOL" 1 sleep 10 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 124 ]; then
    pass "Forced fallback timeout: exit 124"
  else
    fail "Forced fallback timeout: expected 124, got $rc"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE C: Exit code preserved
# ─────────────────────────────────────────────────────────────────
case_exit_code() {
  case_start
  echo ""
  echo "=== Case C: Exit code preserved ==="
  local output rc
  output=$("$TIMEOUT_TOOL" 5 sh -c 'exit 42' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 42 ]; then
    pass "Exit code preserved: exit 42"
  else
    fail "Exit code preserved: expected 42, got $rc"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE D: Forced fallback exit code preserved
# ─────────────────────────────────────────────────────────────────
case_forced_exit_code() {
  case_start
  echo ""
  echo "=== Case D: Forced fallback exit code preserved ==="
  local output rc
  output=$(env OPK_TIMEOUT_FORCE_FALLBACK=1 "$TIMEOUT_TOOL" 5 sh -c 'exit 42' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 42 ]; then
    pass "Forced fallback exit code: exit 42"
  else
    fail "Forced fallback exit code: expected 42, got $rc"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE E: Grandchild cleanup — timeout kills grandchild processes
# ─────────────────────────────────────────────────────────────────
case_grandchild() {
  case_start
  echo ""
  echo "=== Case E: Grandchild cleanup ==="

  _MARKER_FILE="$(mktemp /tmp/.opk-timeout-test-XXXXXX)"
  rm -f "$_MARKER_FILE"

  # Create a command that spawns a grandchild
  # The grandchild writes its PID to the marker file
  # The parent then waits (blocking until timeout)
  local output rc
  output=$("$TIMEOUT_TOOL" 2 sh -c "
    # Create grandchild that sleeps and writes PID
    sh -c 'echo \$\$ > \"$_MARKER_FILE\" && sleep 600' &
    # Wait for grandchild to start
    sleep 0.3
    # Parent blocks until timeout
    wait
  " 2>&1) && rc=0 || rc=$?

  if [ "$rc" -ne 124 ]; then
    fail "Grandchild test: expected timeout exit 124, got $rc"
    rm -f "$_MARKER_FILE"
    return
  fi
  pass "Grandchild test: exit 124"

  # Read grandchild PID from marker — REQUIRED
  local grand_pid=""
  if [ -f "$_MARKER_FILE" ]; then
    grand_pid="$(cat "$_MARKER_FILE" 2>/dev/null | tr -d '[:space:]')"
  fi

  if [ -z "$grand_pid" ]; then
    fail "Grandchild test: marker file empty or missing — PID not captured"
    rm -f "$_MARKER_FILE"
    return
  fi

  if ! is_valid_pid "$grand_pid"; then
    fail "Grandchild test: marker PID '$grand_pid' is not a valid integer"
    rm -f "$_MARKER_FILE"
    return
  fi
  pass "Grandchild test: marker PID valid ($grand_pid)"
  rm -f "$_MARKER_FILE"

  # Poll for process state with grace period
  local final_state
  final_state=$(poll_process_state "$grand_pid" 2)

  case "$final_state" in
    gone)
      pass "Grandchild test: process $grand_pid terminated (not running)"
      ;;
    zombie)
      pass "Grandchild test: process $grand_pid terminated zombie, not running"
      ;;
    alive:*)
      local state="${final_state#alive:}"
      fail "Grandchild test: process $grand_pid still alive (state=$state)"
      kill -9 "$grand_pid" 2>/dev/null || true
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────
# CASE F: No-setsid grandchild cleanup (Python fallback)
# ─────────────────────────────────────────────────────────────────
case_no_setsid_grandchild() {
  case_start
  echo ""
  echo "=== Case F: No-setsid grandchild cleanup ==="

  # Check if Python is available for fallback
  if ! command -v python3 &>/dev/null; then
    skip "No-setsid grandchild: python3 not available"
    return
  fi

  _MARKER_FILE="$(mktemp /tmp/.opk-timeout-test-XXXXXX)"
  rm -f "$_MARKER_FILE"

  local output rc
  output=$(env OPK_TIMEOUT_FORCE_FALLBACK=1 OPK_TIMEOUT_DISABLE_SETSID=1 "$TIMEOUT_TOOL" 2 sh -c "
    sh -c 'echo \$\$ > \"$_MARKER_FILE\" && sleep 600' &
    sleep 0.3
    wait
  " 2>&1) && rc=0 || rc=$?

  if [ "$rc" -ne 124 ]; then
    fail "No-setsid grandchild: expected timeout exit 124, got $rc"
    rm -f "$_MARKER_FILE"
    return
  fi
  pass "No-setsid grandchild: exit 124"

  # Read grandchild PID from marker — REQUIRED
  local grand_pid=""
  if [ -f "$_MARKER_FILE" ]; then
    grand_pid="$(cat "$_MARKER_FILE" 2>/dev/null | tr -d '[:space:]')"
  fi

  if [ -z "$grand_pid" ]; then
    fail "No-setsid grandchild: marker file empty or missing — PID not captured"
    rm -f "$_MARKER_FILE"
    return
  fi

  if ! is_valid_pid "$grand_pid"; then
    fail "No-setsid grandchild: marker PID '$grand_pid' is not a valid integer"
    rm -f "$_MARKER_FILE"
    return
  fi
  pass "No-setsid grandchild: marker PID valid ($grand_pid)"
  rm -f "$_MARKER_FILE"

  # Poll for process state with grace period
  local final_state
  final_state=$(poll_process_state "$grand_pid" 2)

  case "$final_state" in
    gone)
      pass "No-setsid grandchild: process $grand_pid terminated (not running)"
      ;;
    zombie)
      pass "No-setsid grandchild: process $grand_pid terminated zombie, not running"
      ;;
    alive:*)
      local state="${final_state#alive:}"
      fail "No-setsid grandchild: process $grand_pid still alive (state=$state)"
      kill -9 "$grand_pid" 2>/dev/null || true
      ;;
  esac
}

# ─────────────────────────────────────────────────────────────────
# CASE G: Signal preservation — exact parity with direct status
# ─────────────────────────────────────────────────────────────────
case_signal_preservation() {
  case_start
  echo ""
  echo "=== Case G: Signal preservation ==="

  # --- G.1: exit 0 preserved ---
  local output rc
  output=$("$TIMEOUT_TOOL" 5 sh -c 'exit 0' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "Signal: exit 0 preserved"
  else
    fail "Signal: expected 0, got $rc"
  fi

  # --- G.2: exit 42 preserved ---
  output=$("$TIMEOUT_TOOL" 5 sh -c 'exit 42' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 42 ]; then
    pass "Signal: exit 42 preserved"
  else
    fail "Signal: expected 42, got $rc"
  fi

  # --- G.3: SIGUSR1 signal parity ---
  # Get direct shell signal status (ground truth for this system)
  local direct_rc
  sh -c 'kill -USR1 $$' 2>/dev/null; direct_rc=$?
  info "Direct SIGUSR1 status on this system: $direct_rc"

  # A. System timeout
  output=$("$TIMEOUT_TOOL" 5 sh -c 'kill -USR1 $$' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq "$direct_rc" ]; then
    pass "Signal: system timeout SIGUSR1 = $rc (matches direct $direct_rc)"
  else
    fail "Signal: system timeout SIGUSR1 = $rc, expected $direct_rc"
  fi

  # B. Forced Bash fallback (if setsid available)
  if command -v setsid &>/dev/null; then
    output=$(env OPK_TIMEOUT_FORCE_FALLBACK=1 "$TIMEOUT_TOOL" 5 sh -c 'kill -USR1 $$' 2>&1) && rc=0 || rc=$?
    if [ "$rc" -eq "$direct_rc" ]; then
      pass "Signal: Bash fallback SIGUSR1 = $rc (matches direct $direct_rc)"
    else
      fail "Signal: Bash fallback SIGUSR1 = $rc, expected $direct_rc"
    fi
  else
    skip "Signal: Bash fallback SIGUSR1 (setsid not available)"
  fi

  # C. Forced Python/no-setsid fallback
  if command -v python3 &>/dev/null; then
    output=$(env OPK_TIMEOUT_FORCE_FALLBACK=1 OPK_TIMEOUT_DISABLE_SETSID=1 \
      "$TIMEOUT_TOOL" 5 sh -c 'kill -USR1 $$' 2>&1) && rc=0 || rc=$?
    if [ "$rc" -eq "$direct_rc" ]; then
      pass "Signal: Python fallback SIGUSR1 = $rc (matches direct $direct_rc)"
    else
      fail "Signal: Python fallback SIGUSR1 = $rc, expected $direct_rc"
    fi
  else
    skip "Signal: Python fallback SIGUSR1 (python3 not available)"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE H: Timeout 0 must return 126
# ─────────────────────────────────────────────────────────────────
case_timeout_zero() {
  case_start
  echo ""
  echo "=== Case H: Timeout 0 returns 126 ==="
  local output rc

  # System path
  output=$("$TIMEOUT_TOOL" 0 sleep 10 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 126 ]; then
    pass "Timeout 0: system path returns 126"
  else
    fail "Timeout 0: system path expected 126, got $rc"
  fi

  # Forced fallback
  output=$(env OPK_TIMEOUT_FORCE_FALLBACK=1 "$TIMEOUT_TOOL" 0 sleep 10 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 126 ]; then
    pass "Timeout 0: fallback path returns 126"
  else
    fail "Timeout 0: fallback path expected 126, got $rc"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE I: Low exit codes — preserve 1,2,10,31,32,42,125,126,127
# ─────────────────────────────────────────────────────────────────
case_low_exit_codes() {
  case_start
  echo ""
  echo "=== Case I: Low exit codes preserved ==="

  local _low_codes=(1 2 10 31 32 42 125 126 127)
  local _code _direct _system _bash_fb _python_fb

  for _code in "${_low_codes[@]}"; do
    # Ground truth
    sh -c "exit $_code" 2>/dev/null; _direct=$?

    # A. System / default path
    "$TIMEOUT_TOOL" 5 sh -c "exit $_code" 2>/dev/null; _system=$?

    # B. Forced Bash fallback (if setsid available)
    _bash_fb="skip"
    if command -v setsid &>/dev/null; then
      env OPK_TIMEOUT_FORCE_FALLBACK=1 "$TIMEOUT_TOOL" 5 sh -c "exit $_code" 2>/dev/null; _bash_fb=$?
    fi

    # C. Forced Python fallback
    _python_fb="skip"
    if command -v python3 &>/dev/null; then
      env OPK_TIMEOUT_FORCE_FALLBACK=1 OPK_TIMEOUT_DISABLE_SETSID=1 \
        "$TIMEOUT_TOOL" 5 sh -c "exit $_code" 2>/dev/null; _python_fb=$?
    fi

    # Check system path matches direct
    if [ "$_system" -eq "$_direct" ]; then
      pass "exit $_code: system=$_system == direct=$_direct"
    else
      fail "exit $_code: system=$_system != direct=$_direct"
    fi

    # Check Bash fallback matches direct
    if [ "$_bash_fb" != "skip" ]; then
      if [ "$_bash_fb" -eq "$_direct" ]; then
        pass "exit $_code: bash_fb=$_bash_fb == direct=$_direct"
      else
        fail "exit $_code: bash_fb=$_bash_fb != direct=$_direct"
      fi
    fi

    # Check Python fallback matches direct
    if [ "$_python_fb" != "skip" ]; then
      if [ "$_python_fb" -eq "$_direct" ]; then
        pass "exit $_code: python_fb=$_python_fb == direct=$_direct"
      else
        fail "exit $_code: python_fb=$_python_fb != direct=$_direct"
      fi
    fi
  done
}

# ─────────────────────────────────────────────────────────────────
# Main: parse arguments and run cases
# ─────────────────────────────────────────────────────────────────
main() {
  echo "timeout.sh test suite"
  echo "====================="
  echo ""
  info "Timeout tool: $TIMEOUT_TOOL"
  info "System timeout: $(command -v timeout 2>/dev/null || echo 'not found')"
  info "setsid: $(command -v setsid 2>/dev/null || echo 'not found')"
  info "python3: $(command -v python3 2>/dev/null || echo 'not found')"

  local case_filter="${1:-all}"

  case "$case_filter" in
    --grandchild)
      case_grandchild
      ;;
    --case)
      local case_name="${2:-}"
      case "$case_name" in
        default-timeout)      case_default_timeout ;;
        forced-timeout)       case_forced_timeout ;;
        exit-code)            case_exit_code ;;
        forced-exit-code)     case_forced_exit_code ;;
        grandchild)           case_grandchild ;;
        no-setsid-grandchild) case_no_setsid_grandchild ;;
        signal-preservation)  case_signal_preservation ;;
        timeout-zero)         case_timeout_zero ;;
        low-exit-codes)       case_low_exit_codes ;;
        *)
          echo "Unknown case: $case_name" >&2
          echo "Available: default-timeout, forced-timeout, exit-code, forced-exit-code, grandchild, no-setsid-grandchild, signal-preservation, timeout-zero, low-exit-codes" >&2
          exit 1
          ;;
      esac
      ;;
    *)
      case_default_timeout
      case_forced_timeout
      case_exit_code
      case_forced_exit_code
      case_grandchild
      case_no_setsid_grandchild
      case_signal_preservation
      case_timeout_zero
      case_low_exit_codes
      ;;
  esac

  echo ""
  echo "====================="
  printf "Cases: %d | Assertions: %d | ✅ PASS: %d | ❌ FAIL: %d | ⏭️  SKIP: %d\n" \
    "$case_count" "$((pass_count + fail_count + skip_count))" "$pass_count" "$fail_count" "$skip_count"

  if [ "$errors" -gt 0 ]; then
    echo "❌ TIMEOUT TESTS FAILED"
    exit 1
  else
    echo "✅ ALL TIMEOUT TESTS PASSED"
    exit 0
  fi
}

main "$@"
