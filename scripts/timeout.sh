#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# timeout.sh — Portable timeout wrapper
# opencode-power-kit v2.1.0
#
# Runs a command with a timeout. Returns exit code 124 if timeout occurs.
#
# Usage:
#   timeout.sh <seconds> <command> [args...]
#
# Examples:
#   timeout.sh 5 sleep 10      # times out after 5s, exit 124
#   timeout.sh 5 sleep 2       # completes, exit 0
#   timeout.sh 10 git status   # git status with 10s timeout
#
# Exit codes:
#   124   — timeout occurred
#   125   — timeout backend unavailable or internal wrapper failure
#   126   — invalid arguments or command found but cannot execute
#   127   — command not found
#   other — exit code from the command
#
# Environment:
#   OPK_TIMEOUT_BACKEND=auto|gnu|python|bash — select timeout backend (default: auto)
#   OPK_TIMEOUT_FORCE_FALLBACK=1   — in auto mode, skip GNU and use a fallback
#   OPK_TIMEOUT_DISABLE_SETSID=1   — disable Bash fallback (Python remains available)
# ─────────────────────────────────────────────────────────────────

# Do NOT use set -e here — we need to capture exit codes safely.

if [ $# -lt 2 ]; then
  echo "Usage: $(basename "$0") <seconds> <command> [args...]" >&2
  exit 126
fi

TIMEOUT_SEC="$1"
shift

if ! [[ "$TIMEOUT_SEC" =~ ^[0-9]+$ ]] || [ "$TIMEOUT_SEC" -lt 1 ]; then
  echo "Error: timeout must be a positive integer (>= 1)" >&2
  exit 126
fi

# ── Helper: check if a command exists ──
_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ── Detect GNU Coreutils timeout ──
# Only GNU coreutils `timeout` has correct exit-code semantics:
#   124 on timeout, command exit code on normal exit, 128+signal on signal death.
# uutils / BusyBox return raw signal numbers (e.g. 10 for SIGUSR1) instead of 128+signal,
# so we MUST NOT use them — fall back to Python which handles this correctly.
_gnu_timeout_cmd() {
  local _cand
  for _cand in timeout gtimeout; do
    if _has_cmd "$_cand"; then
      if "$_cand" --version 2>&1 | grep -qi 'GNU coreutils'; then
        echo "$_cand"
        return 0
      fi
    fi
  done
  return 1
}

# ── Portable Python fallback ──
# Uses Python subprocess with start_new_session=True to create a new session,
# and os.killpg to kill the entire process tree on Linux.
_fallback_python() {
  if ! _has_cmd python3; then
    echo "Error: python3 not available for fallback timeout" >&2
    exit 125
  fi

  python3 -I -c "
import os, shutil, signal, subprocess, sys

timeout_sec = int(sys.argv[1])
cmd = sys.argv[2:]

if not cmd:
    print('Error: no command specified', file=sys.stderr)
    sys.exit(126)

try:
    # Create new session so we can kill the entire process group.
    proc = subprocess.Popen(
        cmd,
        start_new_session=True,
        stdin=subprocess.DEVNULL
    )
except FileNotFoundError as error:
    # An existing script can also raise ENOENT when its shebang interpreter is
    # missing. Match shell semantics: that command was found but cannot run.
    command_exists = shutil.which(cmd[0]) is not None
    if os.path.sep in cmd[0]:
        command_exists = os.path.exists(cmd[0])
    if command_exists:
        print(f'Error: command cannot execute: {error}', file=sys.stderr)
        sys.exit(126)
    print(f'Error: command not found: {cmd[0]}', file=sys.stderr)
    sys.exit(127)
except PermissionError as error:
    print(f'Error: command cannot execute: {error}', file=sys.stderr)
    sys.exit(126)
except OSError as error:
    print(f'Error: command cannot execute: {error}', file=sys.stderr)
    sys.exit(126)

def terminate_and_reap(process):
    try:
        os.killpg(os.getpgid(process.pid), signal.SIGKILL)
    except Exception:
        try:
            process.kill()
        except Exception:
            pass
    try:
        process.wait(timeout=2)
    except Exception:
        pass

try:
    proc.wait(timeout=timeout_sec)
except subprocess.TimeoutExpired:
    terminate_and_reap(proc)
    sys.exit(124)
except Exception as error:
    terminate_and_reap(proc)
    print(f'Error: Python timeout backend failure: {error}', file=sys.stderr)
    sys.exit(125)

try:
    # When killed by signal, proc.returncode is negative (e.g., -10 for SIGUSR1).
    # Convert to 128 + abs(returncode) to match shell convention.
    rc = proc.returncode
    if rc < 0:
        sys.exit(128 + (-rc))
    sys.exit(rc)
except Exception as error:
    terminate_and_reap(proc)
    print(f'Error: Python timeout backend failure: {error}', file=sys.stderr)
    sys.exit(125)
" "$TIMEOUT_SEC" "$@"
}

# ── Portable bash fallback (when setsid available) ──
_fallback_bash() {
  local cmd_pid="" watchdog_pid="" timer_pid="" exit_code=0
  local _timeout_flag _watchdog_state _attempt _watchdog_identity _timer_identity
  _timeout_flag="$(mktemp "${TMPDIR:-/tmp}/.opk-timeout-XXXXXX" 2>/dev/null)" || {
    echo "Error: cannot create temp file for timeout flag" >&2
    exit 125
  }
  _watchdog_state="$(mktemp "${TMPDIR:-/tmp}/.opk-watchdog-XXXXXX" 2>/dev/null)" || {
    rm -f "$_timeout_flag"
    echo "Error: cannot create temp file for watchdog state" >&2
    exit 125
  }
  # mktemp reserves unique names. Empty files mean no timeout/PID is recorded yet.
  : >"$_timeout_flag"
  : >"$_watchdog_state"

  _stop_watchdog() {
    # The watchdog owns the timer. TERM interrupts its wait; its trap then kills
    # and reaps the timer before exiting. This avoids leaving an orphan sleep.
    if [ -n "$watchdog_pid" ] && kill -0 "$watchdog_pid" 2>/dev/null; then
      kill "$watchdog_pid" 2>/dev/null || true
    fi
    [ -n "$watchdog_pid" ] && wait "$watchdog_pid" 2>/dev/null || true
    watchdog_pid=""
    timer_pid=""
  }

  cleanup() {
    _stop_watchdog
    if [ -n "$cmd_pid" ] && kill -0 "$cmd_pid" 2>/dev/null; then
      kill -9 -- -"$cmd_pid" 2>/dev/null || true
      kill -9 "$cmd_pid" 2>/dev/null || true
    fi
    [ -n "$cmd_pid" ] && wait "$cmd_pid" 2>/dev/null || true
    rm -f "$_timeout_flag" "$_watchdog_state" 2>/dev/null
  }
  trap cleanup EXIT

  set +m
  # Explicit Bash fallback is gated on setsid by the selector below, so the
  # command always has a private process group that can be killed safely.
  setsid "$@" </dev/null &
  cmd_pid=$!

  # The watchdog and its timer never inherit command-substitution pipes.
  # The watchdog is the timer's parent, so it is also the only process that
  # reaps that timer. The parent wrapper separately tracks both exact PIDs.
  (
    _watchdog_timer=""
    _watchdog_cleanup() {
      if [ -n "$_watchdog_timer" ] && kill -0 "$_watchdog_timer" 2>/dev/null; then
        kill "$_watchdog_timer" 2>/dev/null || true
      fi
      [ -n "$_watchdog_timer" ] && wait "$_watchdog_timer" 2>/dev/null || true
      exit 0
    }
    trap _watchdog_cleanup HUP INT TERM

    sleep "$TIMEOUT_SEC" &
    _watchdog_timer=$!
    printf '%s\n' "$_watchdog_timer" >"$_watchdog_state"

    wait "$_watchdog_timer" 2>/dev/null
    _timer_status=$?
    _watchdog_timer=""
    trap - HUP INT TERM
    [ "$_timer_status" -eq 0 ] || exit 0

    if kill -0 "$cmd_pid" 2>/dev/null; then
      printf 'timeout\n' >"$_timeout_flag"
      kill -9 -- -"$cmd_pid" 2>/dev/null || true
      kill -9 "$cmd_pid" 2>/dev/null || true
    fi
  ) </dev/null >/dev/null 2>&1 &
  watchdog_pid=$!

  # Handshake until the watchdog publishes its timer PID. Avoid wait -n so this
  # remains compatible with Bash versions commonly available on Linux.
  _attempt=0
  while [ ! -s "$_watchdog_state" ] && kill -0 "$watchdog_pid" 2>/dev/null; do
    _attempt=$((_attempt + 1))
    if [ "$_attempt" -ge 200 ]; then
      echo "Error: Bash timeout watchdog failed to start" >&2
      exit 125
    fi
    sleep 0.01
  done
  read -r timer_pid <"$_watchdog_state" || timer_pid=""
  if ! [[ "$timer_pid" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Bash timeout watchdog did not publish a timer PID" >&2
    exit 125
  fi

  if [ -n "${OPK_TIMEOUT_TEST_PID_FILE:-}" ]; then
    _watchdog_identity=$(ps -o lstart= -p "$watchdog_pid" 2>/dev/null || true)
    _timer_identity=$(ps -o lstart= -p "$timer_pid" 2>/dev/null || true)
    {
      printf '%s %s\n' "$watchdog_pid" "$timer_pid"
      printf '%s\n' "$_watchdog_identity"
      printf '%s\n' "$_timer_identity"
    } >"$OPK_TIMEOUT_TEST_PID_FILE" || {
      echo "Error: cannot write Bash timeout test PID file" >&2
      exit 125
    }
  fi

  wait "$cmd_pid" 2>/dev/null
  exit_code=$?
  cmd_pid=""

  _stop_watchdog

  if [ -s "$_timeout_flag" ]; then
    rm -f "$_timeout_flag" "$_watchdog_state"
    exit 124
  fi

  rm -f "$_timeout_flag" "$_watchdog_state"
  exit "$exit_code"
}

# ── Main logic ──

_timeout_backend="${OPK_TIMEOUT_BACKEND:-auto}"
case "$_timeout_backend" in
  auto|gnu|python|bash) ;;
  *)
    echo "Error: invalid OPK_TIMEOUT_BACKEND '$_timeout_backend' (expected auto, gnu, python, or bash)" >&2
    exit 126
    ;;
esac

case "$_timeout_backend" in
  gnu)
    _gnu_cmd=""
    if _gnu_cmd=$(_gnu_timeout_cmd); then
      "$_gnu_cmd" --kill-after=1s "$TIMEOUT_SEC" "$@"
      exit $?
    fi
    echo "Error: GNU Coreutils timeout backend is not available" >&2
    exit 125
    ;;
  python)
    _fallback_python "$@"
    ;;
  bash)
    if _has_cmd setsid && [ "${OPK_TIMEOUT_DISABLE_SETSID:-0}" != "1" ]; then
      _fallback_bash "$@"
    fi
    echo "Error: Bash timeout backend requires setsid" >&2
    exit 125
    ;;
  auto)
    # OPK_TIMEOUT_FORCE_FALLBACK remains backward compatible by skipping only
    # the GNU backend. Explicit OPK_TIMEOUT_BACKEND values always select the
    # requested backend.
    if [ "${OPK_TIMEOUT_FORCE_FALLBACK:-0}" != "1" ]; then
      _gnu_cmd=""
      if _gnu_cmd=$(_gnu_timeout_cmd); then
        "$_gnu_cmd" --kill-after=1s "$TIMEOUT_SEC" "$@"
        exit $?
      fi
    fi

    if _has_cmd python3; then
      _fallback_python "$@"
    elif _has_cmd setsid && [ "${OPK_TIMEOUT_DISABLE_SETSID:-0}" != "1" ]; then
      _fallback_bash "$@"
    else
      echo "Error: no timeout backend available (need GNU timeout, python3, or setsid)" >&2
      exit 125
    fi
    ;;
esac
