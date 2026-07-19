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

  # Cleanup on exit: kill child + watchdog, wait to reap zombies
  cleanup() {
    # Kill command and its process group (covers grandchild processes)
    if [ -n "$cmd_pid" ] && kill -0 "$cmd_pid" 2>/dev/null; then
      kill -TERM -- -"$cmd_pid" 2>/dev/null || kill -TERM "$cmd_pid" 2>/dev/null || true
      sleep 0.2
      kill -9 -- -"$cmd_pid" 2>/dev/null || kill -9 "$cmd_pid" 2>/dev/null || true
    fi
    # Kill watchdog
    if [ -n "$watchdog_pid" ] && kill -0 "$watchdog_pid" 2>/dev/null; then
      kill -9 "$watchdog_pid" 2>/dev/null || true
    fi
    # Reap zombies
    wait "$cmd_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
  }
  trap cleanup EXIT

  # Run the command in background (suppress bash job control messages)
  set +m
  "$@" </dev/null &
  cmd_pid=$!

  # Start watchdog timer
  (
    sleep "$TIMEOUT_SEC"
    # If cmd still running after timeout, kill the process group
    if kill -0 "$cmd_pid" 2>/dev/null; then
      kill -9 -- -"$cmd_pid" 2>/dev/null || kill -9 "$cmd_pid" 2>/dev/null || true
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

  # If killed by signal, treat as timeout
  # 137 = 128+9 (SIGKILL), 143 = 128+15 (SIGTERM), 9 = SIGKILL, 15 = SIGTERM
  if [ "$exit_code" -eq 137 ] || [ "$exit_code" -eq 9 ] || \
     [ "$exit_code" -eq 143 ] || [ "$exit_code" -eq 15 ]; then
    exit 124
  fi

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
