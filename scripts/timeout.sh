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
#   0-N   — exit code from the command
#   124   — timeout occurred
#   125   — timeout utility not available
#   126   — invalid arguments
#
# Environment:
#   OPK_TIMEOUT_FORCE_FALLBACK=1   — force bash/Python fallback even if timeout available
#   OPK_TIMEOUT_DISABLE_SETSID=1   — disable setsid (use Python fallback for process groups)
# ─────────────────────────────────────────────────────────────────

# Do NOT use set -e here — we need to capture exit codes safely.

if [ $# -lt 2 ]; then
  echo "Usage: $(basename "$0") <seconds> <command> [args...]" >&2
  exit 126
fi

TIMEOUT_SEC="$1"
shift

if ! [[ "$TIMEOUT_SEC" =~ ^[0-9]+$ ]]; then
  echo "Error: timeout must be a positive integer" >&2
  exit 126
fi

# ── Helper: check if a command exists ──
_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# ── Portable Python fallback ──
# Uses Python subprocess with start_new_session=True to create a new session,
# and os.killpg to kill the entire process tree. Works on macOS without setsid.
_fallback_python() {
  if ! _has_cmd python3; then
    echo "Error: python3 not available for fallback timeout" >&2
    exit 125
  fi

  python3 -c "
import subprocess, os, sys, signal, time

timeout_sec = int(sys.argv[1])
cmd = sys.argv[2:]

if not cmd:
    print('Error: no command specified', file=sys.stderr)
    sys.exit(126)

try:
    # Create new session so we can kill the entire process group
    proc = subprocess.Popen(
        cmd,
        start_new_session=True,
        stdin=subprocess.DEVNULL
    )
except FileNotFoundError as e:
    print(f'Error: command not found: {e}', file=sys.stderr)
    sys.exit(125)

timed_out = False
try:
    proc.wait(timeout=timeout_sec)
except subprocess.TimeoutExpired:
    timed_out = True
    # Kill the entire process group (children and grandchildren)
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        # Process already dead or not permitted
        try:
            proc.kill()
        except (ProcessLookupError, PermissionError):
            pass
    # Reap the zombie
    try:
        proc.wait(timeout=2)
    except subprocess.TimeoutExpired:
        pass

if timed_out:
    sys.exit(124)
else:
    sys.exit(proc.returncode)
" "$TIMEOUT_SEC" "$@"
}

# ── Portable bash fallback (when setsid available) ──
_fallback_bash() {
  local cmd_pid="" watchdog_pid="" exit_code=0
  local _timeout_flag
  _timeout_flag="$(mktemp "${TMPDIR:-/tmp}/.opk-timeout-XXXXXX" 2>/dev/null)" || {
    echo "Error: cannot create temp file for timeout flag" >&2
    exit 125
  }
  # Remove the file — mktemp only creates a unique name.
  # The watchdog will re-create it if a timeout actually occurs.
  rm -f "$_timeout_flag"

  # Cleanup on exit: kill child + watchdog, remove flag, reap zombies
  cleanup() {
    rm -f "$_timeout_flag" 2>/dev/null
    # Kill watchdog first (prevent it from firing after cleanup)
    if [ -n "$watchdog_pid" ] && kill -0 "$watchdog_pid" 2>/dev/null; then
      kill -9 "$watchdog_pid" 2>/dev/null || true
    fi
    wait "$watchdog_pid" 2>/dev/null || true
    # Kill command and its process group if still running
    if [ -n "$cmd_pid" ] && kill -0 "$cmd_pid" 2>/dev/null; then
      # Kill entire process group (covers grandchildren)
      kill -9 -- -"$cmd_pid" 2>/dev/null || true
      # Fallback: kill the process itself
      kill -9 "$cmd_pid" 2>/dev/null || true
    fi
    wait "$cmd_pid" 2>/dev/null || true
  }
  trap cleanup EXIT

  # Run the command in background (suppress bash job control messages)
  set +m
  # Use setsid to create a new session/process group when available.
  # This ensures kill -9 -- -cmd_pid reliably kills all descendants.
  if _has_cmd setsid && [ "${OPK_TIMEOUT_DISABLE_SETSID:-0}" != "1" ]; then
    setsid "$@" </dev/null &
  else
    "$@" </dev/null &
  fi
  cmd_pid=$!

  # Start watchdog timer — writes flag file and kills process tree on timeout
  (
    sleep "$TIMEOUT_SEC"
    # If cmd still running after timeout, signal and kill the process tree
    if kill -0 "$cmd_pid" 2>/dev/null; then
      touch "$_timeout_flag"
      # Kill entire process group (grandchildren included)
      kill -9 -- -"$cmd_pid" 2>/dev/null || true
      # Fallback: kill the process itself in case group kill didn't work
      kill -9 "$cmd_pid" 2>/dev/null || true
    fi
  ) &
  watchdog_pid=$!

  # Wait for the command — capture exit code safely
  # No set -e / set +e toggling needed: script does not use set -e globally
  wait "$cmd_pid" 2>/dev/null
  exit_code=$?

  # Stop the watchdog (it may have already exited)
  kill "$watchdog_pid" 2>/dev/null || true
  wait "$watchdog_pid" 2>/dev/null || true
  watchdog_pid=""

  # If the watchdog flagged a timeout, return 124
  # This avoids blindly mapping signal exit codes (137/143/9/15) to 124,
  # which would incorrectly mask commands that receive real signals.
  if [ -f "$_timeout_flag" ]; then
    rm -f "$_timeout_flag"
    exit 124
  fi

  # Command completed (or was killed by something else) — return its real exit code
  exit "$exit_code"
}

# ── Main logic ──

# If OPK_TIMEOUT_FORCE_FALLBACK=1, skip system timeout
if [ "${OPK_TIMEOUT_FORCE_FALLBACK:-0}" != "1" ]; then
  # Try GNU/BSD timeout first
  # Use --kill-after=1s to ensure process tree cleanup on timeout.
  # Do NOT use --signal=KILL — it may cause exit code 137 instead of 124
  # on some systems (GNU coreutils). Default signal is SIGTERM which is correct.
  if _has_cmd timeout; then
    timeout --kill-after=1s "$TIMEOUT_SEC" "$@"
    exit $?
  fi

  # Try BSD timeout (macOS via coreutils — gtimeout)
  if _has_cmd gtimeout; then
    gtimeout --kill-after=1s "$TIMEOUT_SEC" "$@"
    exit $?
  fi
fi

# Fallback: Python or bash-native process + watchdog
# Python fallback is preferred when setsid is unavailable (macOS)
# because it properly manages process groups via start_new_session.
if [ "${OPK_TIMEOUT_DISABLE_SETSID:-0}" = "1" ] || ! _has_cmd setsid; then
  _fallback_python "$@"
else
  _fallback_bash "$@"
fi
