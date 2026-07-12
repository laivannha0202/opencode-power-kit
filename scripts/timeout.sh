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
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

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

# Try GNU timeout first (Linux)
if command -v timeout >/dev/null 2>&1; then
  timeout --signal=KILL "$TIMEOUT_SEC" "$@"
  exit $?
fi

# Try BSD timeout (macOS)
if command -v gtimeout >/dev/null 2>&1; then
  gtimeout --signal=KILL "$TIMEOUT_SEC" "$@"
  exit $?
fi

# Fallback: background process + kill
PID=$$
CHILD_PID=""

cleanup() {
  if [ -n "$CHILD_PID" ] && kill -0 "$CHILD_PID" 2>/dev/null; then
    kill -9 "$CHILD_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT

"$@" &
CHILD_PID=$!

(
  sleep "$TIMEOUT_SEC"
  if kill -0 "$CHILD_PID" 2>/dev/null; then
    kill -9 "$CHILD_PID" 2>/dev/null || true
  fi
) &
WATCHDOG_PID=$!

wait "$CHILD_PID" 2>/dev/null
EXIT_CODE=$?

kill "$WATCHDOG_PID" 2>/dev/null || true
wait "$WATCHDOG_PID" 2>/dev/null || true

if [ "$EXIT_CODE" -eq 137 ] || [ "$EXIT_CODE" -eq 9 ]; then
  exit 124
fi

exit "$EXIT_CODE"
