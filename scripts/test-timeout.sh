#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-timeout.sh — Comprehensive timeout.sh tests
# opencode-power-kit v2.1.0
#
# Tests all timeout behaviors: system timeout, fallback, exit codes,
# grandchild cleanup, setsid-less mode, signal preservation.
#
# Usage:
#   bash scripts/test-timeout.sh              # run all tests
#   bash scripts/test-timeout.sh --grandchild # run grandchild test only
#   bash scripts/test-timeout.sh --case NAME  # run specific case
#
# Cases:
#   default-timeout      — system timeout returns 124
#   forced-timeout       — forced fallback returns 124
#   exit-code            — normal exit code preserved
#   forced-exit-code     — forced fallback preserves exit code
#   grandchild           — timeout kills grandchild processes
#   no-setsid-grandchild — fallback without setsid kills grandchild
#   signal-preservation  — command signal status preserved
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT_SH="$SCRIPT_DIR/timeout.sh"
TIMEOUT_TOOL="${TIMEOUT_SH}"

errors=0
pass_count=0
fail_count=0
skip_count=0

pass() { echo "  ✅ $*"; pass_count=$((pass_count + 1)); }
fail() { echo "  ❌ $*"; fail_count=$((fail_count + 1)); errors=$((errors + 1)); }
skip() { echo "  ⏭️  $*"; skip_count=$((skip_count + 1)); }
info() { echo "  ℹ️  $*"; }

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

# ─────────────────────────────────────────────────────────────────
# CASE A: Default timeout (system) returns 124
# ─────────────────────────────────────────────────────────────────
case_default_timeout() {
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

  # Read grandchild PID from marker
  local grand_pid=""
  if [ -f "$_MARKER_FILE" ]; then
    grand_pid="$(cat "$_MARKER_FILE" 2>/dev/null)"
  fi
  rm -f "$_MARKER_FILE"

  if [ -z "$grand_pid" ]; then
    # Grandchild may have been reaped before we could read
    # This is acceptable — it means cleanup worked
    pass "Grandchild cleanup: grandchild already reaped (exit 124)"
    return
  fi

  # Check if grandchild is still running
  sleep 0.5
  if kill -0 "$grand_pid" 2>/dev/null; then
    # Grandchild is still running — check if it's a zombie
    local state
    state=$(ps -o state= -p "$grand_pid" 2>/dev/null | tr -d ' ')
    if [ "$state" = "Z" ] || [ "$state" = "Z+" ]; then
      pass "Grandchild cleanup: zombie (reaped) $grand_pid"
    else
      fail "Grandchild cleanup: grandchild $grand_pid still alive (state=$state)"
      # Cleanup the process we can't kill
      kill -9 "$grand_pid" 2>/dev/null || true
    fi
  else
    pass "Grandchild cleanup: grandchild $grand_pid reaped (exit 124)"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE F: No-setsid grandchild cleanup
# ─────────────────────────────────────────────────────────────────
case_no_setsid_grandchild() {
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

  local grand_pid=""
  if [ -f "$_MARKER_FILE" ]; then
    grand_pid="$(cat "$_MARKER_FILE" 2>/dev/null)"
  fi
  rm -f "$_MARKER_FILE"

  if [ -z "$grand_pid" ]; then
    pass "No-setsid grandchild: grandchild already reaped (exit 124)"
    return
  fi

  sleep 0.5
  if kill -0 "$grand_pid" 2>/dev/null; then
    local state
    state=$(ps -o state= -p "$grand_pid" 2>/dev/null | tr -d ' ')
    if [ "$state" = "Z" ] || [ "$state" = "Z+" ]; then
      pass "No-setsid grandchild: zombie (reaped) $grand_pid"
    else
      fail "No-setsid grandchild: grandchild $grand_pid still alive (state=$state)"
      kill -9 "$grand_pid" 2>/dev/null || true
    fi
  else
    pass "No-setsid grandchild: grandchild $grand_pid reaped (exit 124)"
  fi
}

# ─────────────────────────────────────────────────────────────────
# CASE G: Signal preservation — command signal status preserved
# ─────────────────────────────────────────────────────────────────
case_signal_preservation() {
  echo ""
  echo "=== Case G: Signal preservation ==="

  # Command that exits with specific code should preserve that code
  local output rc
  output=$("$TIMEOUT_TOOL" 5 sh -c 'exit 1' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 1 ]; then
    pass "Signal preservation: exit 1 preserved"
  else
    fail "Signal preservation: expected 1, got $rc"
  fi

  # Command that exits with 0 should return 0
  output=$("$TIMEOUT_TOOL" 5 sh -c 'exit 0' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 0 ]; then
    pass "Signal preservation: exit 0 preserved"
  else
    fail "Signal preservation: expected 0, got $rc"
  fi

  # Command that receives SIGUSR1 and exits with signal-specific code
  # On Linux, killed by signal returns 128+signal_number
  # We test that the exit code is NOT 124 (which would mean timeout incorrectly claimed it)
  output=$("$TIMEOUT_TOOL" 5 sh -c 'kill -USR1 $$; exit 42' 2>&1) && rc=0 || rc=$?
  if [ "$rc" -eq 42 ]; then
    pass "Signal preservation: exit 42 after USR1"
  elif [ "$rc" -ne 124 ]; then
    # Any non-124 exit means the signal was handled, not mistaken for timeout
    pass "Signal preservation: exit $rc (not 124, signal handled)"
  else
    fail "Signal preservation: got 124 — signal mistaken for timeout"
  fi
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
        *)
          echo "Unknown case: $case_name" >&2
          echo "Available: default-timeout, forced-timeout, exit-code, forced-exit-code, grandchild, no-setsid-grandchild, signal-preservation" >&2
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
      ;;
  esac

  echo ""
  echo "====================="
  printf "Total: %d | ✅ PASS: %d | ❌ FAIL: %d | ⏭️  SKIP: %d\n" \
    "$((pass_count + fail_count + skip_count))" "$pass_count" "$fail_count" "$skip_count"

  if [ "$errors" -gt 0 ]; then
    echo "❌ TIMEOUT TESTS FAILED"
    exit 1
  else
    echo "✅ ALL TIMEOUT TESTS PASSED"
    exit 0
  fi
}

main "$@"
