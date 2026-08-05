#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# opk_tx.sh — Bash wrapper cho transaction layer opk_tx.py
# opencode-power-kit
#
# Exit codes (nhất quán với opk_safe_io.sh):
#   0 ok | 1 error | 2 unsafe path | 3 missing
#
# Cách dùng:
#   opk_tx.sh begin  --root R [--reason X]                     -> tx_id
#   opk_tx.sh stage  --txid T --root R --kind K --rel F [options]
#   opk_tx.sh commit --txid T --root R
#   opk_tx.sh rollback --txid T --root R [--force]
#   opk_tx.sh status --root R [--txid T]
#   opk_tx.sh recover --root R [--latest|--all|--txid T] [--yes]
#   opk_tx.sh help
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
TX_PY="$SCRIPT_DIR/opk_tx.py"

USAGE="opk_tx.sh — transaction layer (wrapper quanh opk_tx.py)

Usage:
  opk_tx.sh begin  --root R [--reason X]
  opk_tx.sh stage  --txid T --root R --kind K --rel F [--text S] [--file P]
                   [--marker M] [--mode O] [--require-absent]
  opk_tx.sh commit --txid T --root R
  opk_tx.sh rollback --txid T --root R [--force]
  opk_tx.sh status --root R [--txid T]
  opk_tx.sh recover --root R [--latest | --all | --txid T] [--yes]

Exit codes: 0 ok | 1 error | 2 unsafe path | 3 missing"

if [ "$#" -eq 0 ]; then
	echo "$USAGE" >&2
	exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "help" ] || [ "$1" = "-h" ]; then
	echo "$USAGE"
	exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
	echo "opk_tx.sh: python3 is required" >&2
	exit 1
fi

python3 "$TX_PY" "$@"
rc=$?

case $rc in
0) exit 0 ;;
2) echo "opk_tx.sh: unsafe path (exit 2)" >&2 ;;
3) echo "opk_tx.sh: missing path (exit 3)" >&2 ;;
*) exit $rc ;;
esac
exit $rc
