#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-timeout.sh — Deterministic backend coverage for timeout.sh
# opencode-power-kit v2.1.0
# ─────────────────────────────────────────────────────────────────
# shellcheck disable=SC2015,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMEOUT_TOOL="$SCRIPT_DIR/timeout.sh"
BASH_BIN="$(command -v bash)"

pass_count=0
fail_count=0
skip_count=0
case_count=0
_MARKER_FILE=""
_TEMP_FILES=""
_TEMP_DIRS=""

green='✅'
red='❌'
yellow='⏭️ '

pass() { echo "  $green $*"; pass_count=$((pass_count + 1)); }
fail() { echo "  $red $*"; fail_count=$((fail_count + 1)); }
skip() { echo "  $yellow $*"; skip_count=$((skip_count + 1)); }
info() { echo "  ℹ️  $*"; }
case_start() { case_count=$((case_count + 1)); }

cleanup() {
  local file dir
  [ -n "$_MARKER_FILE" ] && rm -f "$_MARKER_FILE" 2>/dev/null || true
  for file in $_TEMP_FILES; do
    rm -f "$file" 2>/dev/null || true
  done
  for dir in $_TEMP_DIRS; do
    rmdir "$dir" 2>/dev/null || true
  done
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
  local backend="$1" grand_pid final_state process_args
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
      process_args=$(ps -o args= -p "$grand_pid" 2>/dev/null || true)
      case "$process_args" in
        *"$_MARKER_FILE"*) kill -9 "$grand_pid" 2>/dev/null || true ;;
        *) fail "$backend: refused cleanup because PID $grand_pid no longer matches the test marker" ;;
      esac
      ;;
  esac
  rm -f "$_MARKER_FILE"
  _MARKER_FILE=""
}

read_lifecycle_pid_record() {
  local pid_file="$1"
  watchdog_pid=""
  timer_pid=""
  watchdog_identity=""
  timer_identity=""
  if [ -s "$pid_file" ]; then
    {
      read -r watchdog_pid timer_pid
      IFS= read -r watchdog_identity || true
      IFS= read -r timer_identity || true
    } <"$pid_file"
  fi
}

assert_pid_gone() {
  local label="$1" pid="$2" expected_identity="$3" current_identity
  if ! [[ "$pid" =~ ^[1-9][0-9]*$ ]]; then
    fail "$label PID missing or invalid ('$pid')"
    return
  fi
  if kill -0 "$pid" 2>/dev/null; then
    current_identity=$(ps -o lstart= -p "$pid" 2>/dev/null || true)
    if [ -n "$expected_identity" ] && [ "$current_identity" = "$expected_identity" ]; then
      fail "$label process still running (PID $pid)"
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    else
      fail "$label PID $pid was reused; refusing to kill a process outside this test"
    fi
  else
    pass "$label process reaped (PID $pid)"
  fi
}

test_bash_lifecycle() {
  local pid_file output_file output rc start elapsed watchdog_pid timer_pid iteration
  local watchdog_identity timer_identity

  case_start
  echo ""
  echo "=== Bash lifecycle and latency ==="

  if ! backend_available bash; then
    skip "bash backend unavailable — lifecycle suite SKIP"
    return
  fi

  pid_file=$(mktemp "${TMPDIR:-/tmp}/.opk-timeout-pids-XXXXXX")
  output_file=$(mktemp "${TMPDIR:-/tmp}/.opk-timeout-output-XXXXXX")
  _TEMP_FILES="$_TEMP_FILES $pid_file $output_file"
  rm -f "$pid_file"

  start=$SECONDS
  env OPK_TIMEOUT_BACKEND=bash OPK_TIMEOUT_TEST_PID_FILE="$pid_file" \
    "$TIMEOUT_TOOL" 47 sh -c 'printf direct' >"$output_file"
  rc=$?
  elapsed=$((SECONDS - start))
  output=$(<"$output_file")
  [ "$rc" -eq 0 ] && pass "bash: direct early completion exits 0" || fail "bash: direct early completion expected 0, got $rc"
  [ "$output" = direct ] && pass "bash: direct stdout preserved" || fail "bash: direct stdout expected direct, got '$output'"
  [ "$elapsed" -lt 2 ] && pass "bash: direct completion is early (${elapsed}s)" || fail "bash: direct completion waited ${elapsed}s"

  read_lifecycle_pid_record "$pid_file"
  assert_pid_gone "bash: watchdog" "$watchdog_pid" "$watchdog_identity"
  assert_pid_gone "bash: timer" "$timer_pid" "$timer_identity"

  start=$SECONDS
  output=$(env OPK_TIMEOUT_BACKEND=bash "$TIMEOUT_TOOL" 5 sh -c 'printf hello')
  rc=$?
  elapsed=$((SECONDS - start))
  [ "$rc" -eq 0 ] && pass "bash: captured stdout exits 0" || fail "bash: captured stdout expected 0, got $rc"
  [ "$output" = hello ] && pass "bash: captured stdout preserved" || fail "bash: captured stdout expected hello, got '$output'"
  [ "$elapsed" -lt 2 ] && pass "bash: captured completion is early (${elapsed}s)" || fail "bash: captured completion held pipe for ${elapsed}s"

  start=$SECONDS
  output=$(env OPK_TIMEOUT_BACKEND=bash "$TIMEOUT_TOOL" 5 sh -c 'printf problem >&2' 2>&1)
  rc=$?
  elapsed=$((SECONDS - start))
  [ "$rc" -eq 0 ] && pass "bash: captured stderr exits 0" || fail "bash: captured stderr expected 0, got $rc"
  [ "$output" = problem ] && pass "bash: captured stderr preserved" || fail "bash: captured stderr expected problem, got '$output'"
  [ "$elapsed" -lt 2 ] && pass "bash: captured stderr completes early (${elapsed}s)" || fail "bash: captured stderr held pipe for ${elapsed}s"

  rm -f "$pid_file"
  env OPK_TIMEOUT_BACKEND=bash OPK_TIMEOUT_TEST_PID_FILE="$pid_file" \
    "$TIMEOUT_TOOL" 1 sleep 10
  rc=$?
  [ "$rc" -eq 124 ] && pass "bash: lifecycle timeout returns 124" || fail "bash: lifecycle timeout expected 124, got $rc"
  read_lifecycle_pid_record "$pid_file"
  assert_pid_gone "bash: timed-out watchdog" "$watchdog_pid" "$watchdog_identity"
  assert_pid_gone "bash: timed-out timer" "$timer_pid" "$timer_identity"

  for iteration in 1 2 3 4 5; do
    rm -f "$pid_file"
    env OPK_TIMEOUT_BACKEND=bash OPK_TIMEOUT_TEST_PID_FILE="$pid_file" \
      "$TIMEOUT_TOOL" 47 sh -c 'exit 0'
    rc=$?
    if [ "$rc" -ne 0 ]; then
      fail "bash: rapid iteration $iteration expected 0, got $rc"
      continue
    fi
    read_lifecycle_pid_record "$pid_file"
    assert_pid_gone "bash: iteration $iteration watchdog" "$watchdog_pid" "$watchdog_identity"
    assert_pid_gone "bash: iteration $iteration timer" "$timer_pid" "$timer_identity"
  done
}

test_backend_exec_errors() {
  local backend="$1" missing noexec bad_interpreter bad_name bad_dir module_dir module_output module_rc
  missing="opk-command-that-does-not-exist-$$-$backend"

  run_backend "$backend" 5 "$missing"
  [ "$RUN_RC" -eq 127 ] && pass "$backend: missing command returns 127" || fail "$backend: missing command expected 127, got $RUN_RC${RUN_OUTPUT:+ — $RUN_OUTPUT}"
  case "$RUN_OUTPUT" in
    *Traceback*) fail "$backend: missing command leaked Python traceback" ;;
    *) pass "$backend: missing command has no traceback" ;;
  esac

  noexec=$(mktemp "${TMPDIR:-/tmp}/.opk-timeout-noexec-XXXXXX")
  _TEMP_FILES="$_TEMP_FILES $noexec"
  chmod 600 "$noexec"
  run_backend "$backend" 5 "$noexec"
  [ "$RUN_RC" -eq 126 ] && pass "$backend: non-executable command returns 126" || fail "$backend: non-executable command expected 126, got $RUN_RC${RUN_OUTPUT:+ — $RUN_OUTPUT}"
  case "$RUN_OUTPUT" in
    *Traceback*) fail "$backend: non-executable command leaked Python traceback" ;;
    *) pass "$backend: non-executable command has no traceback" ;;
  esac
  rm -f "$noexec"

  if [ "$backend" = python ]; then
    bad_interpreter=$(mktemp "${TMPDIR:-/tmp}/.opk-timeout-bad-interpreter-XXXXXX")
    _TEMP_FILES="$_TEMP_FILES $bad_interpreter"
    printf '#!/opk/missing/interpreter\nexit 0\n' >"$bad_interpreter"
    chmod 700 "$bad_interpreter"
    bad_name=${bad_interpreter##*/}
    bad_dir=${bad_interpreter%/*}
    PATH="$bad_dir:$PATH" run_backend "$backend" 5 "$bad_name"
    [ "$RUN_RC" -eq 126 ] && pass "python: PATH command with missing interpreter returns 126" || fail "python: PATH command with missing interpreter expected 126, got $RUN_RC${RUN_OUTPUT:+ — $RUN_OUTPUT}"
    case "$RUN_OUTPUT" in
      *Traceback*) fail "python: missing interpreter leaked Python traceback" ;;
      *) pass "python: missing interpreter has no traceback" ;;
    esac
    rm -f "$bad_interpreter"

    module_dir=$(mktemp -d "${TMPDIR:-/tmp}/.opk-timeout-python-path-XXXXXX")
    _TEMP_DIRS="$_TEMP_DIRS $module_dir"
    _TEMP_FILES="$_TEMP_FILES $module_dir/shutil.py"
    printf 'raise RuntimeError("untrusted cwd import")\n' >"$module_dir/shutil.py"
    module_output=$(cd "$module_dir" && env PYTHONDONTWRITEBYTECODE=1 OPK_TIMEOUT_BACKEND=python \
      "$TIMEOUT_TOOL" 5 sh -c 'exit 0' 2>&1) && module_rc=0 || module_rc=$?
    [ "$module_rc" -eq 0 ] && pass "python: backend ignores modules from command cwd" || fail "python: cwd module isolation expected 0, got $module_rc${module_output:+ — $module_output}"
    case "$module_output" in
      *Traceback*) fail "python: cwd module injection leaked traceback" ;;
      *) pass "python: cwd module injection has no traceback" ;;
    esac
    rm -f "$module_dir/shutil.py"
    rmdir "$module_dir"
  fi
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

  test_backend_exec_errors "$backend"
  [ "$backend" = bash ] && test_bash_lifecycle
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
        lifecycle|bash-lifecycle) test_bash_lifecycle ;;
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
