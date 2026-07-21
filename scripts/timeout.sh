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
#   OPK_TIMEOUT_FORCE_FALLBACK=1  — force bash fallback even if timeout/gtimeout available
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

# ── Portable bash fallback ──
_fallback() {
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
  if _has_cmd setsid; then
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
  # Try GNU timeout first (Linux)
  if _has_cmd timeout; then
    timeout --signal=KILL "$TIMEOUT_SEC" "$@"
    exit $?
  fi

  # Try BSD timeout (macOS via coreutils)
  if _has_cmd gtimeout; then
    gtimeout --signal=KILL "$TIMEOUT_SEC" "$@"
    exit $?
  fi
fi

# Fallback: bash-native process + watchdog
_fallback "$@"
