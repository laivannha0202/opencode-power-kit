#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-timeout.sh — Deterministic backend coverage for timeout.sh
# opencode-power-kit v2.1.0
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT_TOOL="$SCRIPT_DIR/timeout.sh"
BASH_BIN="$(command -v bash)"

pass_count=0
fail_count=0
skip_count=0
case_count=0
_MARKER_FILE=""

green='✅'
red='❌'
yellow='⏭️ '

pass() { echo "  $green $*"; pass_count=$((pass_count + 1)); }
fail() { echo "  $red $*"; fail_count=$((fail_count + 1)); }
skip() { echo "  $yellow $*"; skip_count=$((skip_count + 1)); }
info() { echo "  ℹ️  $*"; }
case_start() { case_count=$((case_count + 1)); }

cleanup() {
  [ -n "$_MARKER_FILE" ] && rm -f "$_MARKER_FILE" 2>/dev/null || true
}
trap cleanup EXIT

gnu_timeout_cmd() {
  local candidate version_output
  for candidate in timeout gtimeout; do
    if command -v "$candidate" >/dev/null 2>&1; then
      version_output=$("$candidate" --version 2>&1) || continue
      if [[ "$version_output" == *"GNU coreutils"* ]]; then
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done
  return 1
}

backend_available() {
  case "$1" in
    gnu) gnu_timeout_cmd >/dev/null ;;
    python) command -v python3 >/dev/null 2>&1 ;;
    bash) command -v setsid >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

run_backend() {
  local backend="$1" seconds="$2"
  shift 2
  RUN_OUTPUT=$(env OPK_TIMEOUT_BACKEND="$backend" "$TIMEOUT_TOOL" "$seconds" "$@" 2>&1) && RUN_RC=0 || RUN_RC=$?
}

assert_backend_status() {
  local backend="$1" label="$2" expected="$3" seconds="$4"
  shift 4
  run_backend "$backend" "$seconds" "$@"
  if [ "$RUN_RC" -eq "$expected" ]; then
    pass "$backend: $label (exit $RUN_RC)"
  else
    fail "$backend: $label expected $expected, got $RUN_RC${RUN_OUTPUT:+ — $RUN_OUTPUT}"
  fi
}

poll_process_state() {
  local pid="$1" attempt state
  for attempt in 1 2 3 4; do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo gone
      return
    fi
    state=$(ps -o state= -p "$pid" 2>/dev/null | tr -d ' ')
    case "$state" in
      Z|Z+) echo zombie; return ;;
    esac
    sleep 0.25
  done
  echo "alive:${state:-unknown}"
}

test_grandchild() {
  local backend="$1" grand_pid final_state
  _MARKER_FILE=$(mktemp "${TMPDIR:-/tmp}/.opk-timeout-test-XXXXXX")
  rm -f "$_MARKER_FILE"

  run_backend "$backend" 2 sh -c "
    sh -c 'echo \$\$ > \"$_MARKER_FILE\"; sleep 600' &
    sleep 0.3
    wait
  "
  if [ "$RUN_RC" -ne 124 ]; then
    fail "$backend: grandchild timeout expected 124, got $RUN_RC"
    return
  fi
  pass "$backend: grandchild timeout (exit 124)"

  grand_pid=""
  [ -f "$_MARKER_FILE" ] && grand_pid=$(tr -d '[:space:]' < "$_MARKER_FILE")
  if ! [[ "$grand_pid" =~ ^[1-9][0-9]*$ ]]; then
    fail "$backend: grandchild PID missing or invalid ('$grand_pid')"
    return
  fi
  pass "$backend: grandchild PID captured ($grand_pid)"

  final_state=$(poll_process_state "$grand_pid")
  case "$final_state" in
    gone|zombie) pass "$backend: grandchild stopped ($final_state)" ;;
    *)
      fail "$backend: grandchild still running ($final_state)"
      kill -9 "$grand_pid" 2>/dev/null || true
      ;;
  esac
  rm -f "$_MARKER_FILE"
  _MARKER_FILE=""
}

test_backend() {
  local backend="$1" code direct_rc
  case_start
  echo ""
  echo "=== Backend: $backend ==="

  if ! backend_available "$backend"; then
    skip "$backend backend unavailable — backend suite SKIP"
    return
  fi

  assert_backend_status "$backend" "normal exit" 0 5 sh -c 'exit 0'
  assert_backend_status "$backend" "exit 42" 42 5 sh -c 'exit 42'

  for code in 1 2 10 31 32 42 125 126 127; do
    assert_backend_status "$backend" "low exit $code" "$code" 5 sh -c "exit $code"
  done

  assert_backend_status "$backend" "timeout" 124 1 sleep 10
  assert_backend_status "$backend" "timeout 0" 126 0 sleep 10

  direct_rc=$( { sh -c 'kill -USR1 $$' >/dev/null 2>&1; printf '%s' "$?"; } 2>/dev/null)
  assert_backend_status "$backend" "SIGUSR1 matches direct shell" "$direct_rc" 5 sh -c 'kill -USR1 $$'

  test_grandchild "$backend"

  assert_backend_status "$backend" "nested wrapper preserves exit 42" 42 5 \
    env OPK_TIMEOUT_BACKEND="$backend" "$TIMEOUT_TOOL" 2 sh -c 'exit 42'
  assert_backend_status "$backend" "nested wrapper returns inner timeout" 124 5 \
    env OPK_TIMEOUT_BACKEND="$backend" "$TIMEOUT_TOOL" 1 sleep 10
}

test_selector_contract() {
  local output rc
  case_start
  echo ""
  echo "=== Backend selector contract ==="

  output=$(env OPK_TIMEOUT_BACKEND=invalid "$TIMEOUT_TOOL" 5 sh -c 'exit 0' 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 126 ] && pass "invalid backend returns 126" || fail "invalid backend expected 126, got $rc"

  output=$(env PATH=/nonexistent OPK_TIMEOUT_BACKEND=gnu "$BASH_BIN" "$TIMEOUT_TOOL" 5 true 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 125 ] && pass "unavailable GNU backend returns 125" || fail "unavailable GNU backend expected 125, got $rc"

  output=$(env PATH=/nonexistent OPK_TIMEOUT_BACKEND=python "$BASH_BIN" "$TIMEOUT_TOOL" 5 true 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 125 ] && pass "unavailable Python backend returns 125" || fail "unavailable Python backend expected 125, got $rc"

  output=$(env OPK_TIMEOUT_BACKEND=bash OPK_TIMEOUT_DISABLE_SETSID=1 "$TIMEOUT_TOOL" 5 true 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 125 ] && pass "unavailable Bash backend returns 125" || fail "unavailable Bash backend expected 125, got $rc"

  output=$(env OPK_TIMEOUT_BACKEND=auto "$TIMEOUT_TOOL" 5 sh -c 'exit 42' 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 42 ] && pass "auto backend preserves command exit" || fail "auto backend expected 42, got $rc"

  output=$(env OPK_TIMEOUT_BACKEND=auto "$TIMEOUT_TOOL" 1 sleep 10 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 124 ] && pass "auto backend returns 124 on timeout" || fail "auto backend timeout expected 124, got $rc"

  output=$(env PATH=/nonexistent OPK_TIMEOUT_BACKEND=auto "$BASH_BIN" "$TIMEOUT_TOOL" 5 true 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 125 ] && pass "auto without any backend returns 125" || fail "auto without backend expected 125, got $rc"

  output=$(env OPK_TIMEOUT_BACKEND=auto OPK_TIMEOUT_FORCE_FALLBACK=1 "$TIMEOUT_TOOL" 5 sh -c 'exit 42' 2>&1) && rc=0 || rc=$?
  [ "$rc" -eq 42 ] && pass "OPK_TIMEOUT_FORCE_FALLBACK remains compatible" || fail "forced auto fallback expected 42, got $rc"
}

main() {
  echo "timeout.sh test suite"
  echo "====================="
  info "Timeout tool: $TIMEOUT_TOOL"
  info "GNU timeout: $(gnu_timeout_cmd 2>/dev/null || echo 'not found')"
  info "python3: $(command -v python3 2>/dev/null || echo 'not found')"
  info "setsid: $(command -v setsid 2>/dev/null || echo 'not found')"

  case "${1:-all}" in
    --grandchild)
      local backend
      for backend in gnu python bash; do
        case_start
        echo ""
        echo "=== Grandchild backend: $backend ==="
        if backend_available "$backend"; then
          test_grandchild "$backend"
        else
          skip "$backend backend unavailable — grandchild test SKIP"
        fi
      done
      ;;
    --case)
      case "${2:-}" in
        selector|backend-selector) test_selector_contract ;;
        gnu|python|bash) test_backend "$2" ;;
        *) echo "Unknown case: ${2:-}" >&2; exit 1 ;;
      esac
      ;;
    all)
      local backend
      test_selector_contract
      for backend in gnu python bash; do
        test_backend "$backend"
      done
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac

  echo ""
  echo "====================="
  printf "Cases: %d | Assertions: %d | ✅ PASS: %d | ❌ FAIL: %d | ⏭️  SKIP: %d\n" \
    "$case_count" "$((pass_count + fail_count + skip_count))" "$pass_count" "$fail_count" "$skip_count"

  if [ "$fail_count" -gt 0 ]; then
    echo "❌ TIMEOUT TESTS FAILED"
    exit 1
  fi
  echo "✅ ALL AVAILABLE TIMEOUT BACKEND TESTS PASSED"
}

main "$@"
