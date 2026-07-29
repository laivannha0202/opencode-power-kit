#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/upstream-versions.sh"
[[ "$(id -u)" -ne 0 ]] || { echo 'ERROR: do not run with sudo/root' >&2; exit 1; }
MODE=interactive
UPGRADE=0
while (($#)); do
  case "$1" in
    --dry-run) MODE=dry-run ;;
    --yes|-y) MODE=yes ;;
    --upgrade|--refresh) UPGRADE=1 ;;
    -h|--help) echo 'Usage: install-supermemory.sh [--dry-run] [--yes] [--upgrade]'; exit 0 ;;
    *) echo "ERROR: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done
command -v npm >/dev/null || { echo 'ERROR: npm not found' >&2; exit 1; }
PKG="${SUPERMEMORY_PACKAGE:-$OPK_SUPERMEMORY_PACKAGE}"
CMD=(npm install -g "$PKG@latest")
printf 'Supermemory plan:'; printf ' %q' "${CMD[@]}"; printf '\n'
[[ "$MODE" == dry-run ]] && exit 0
if command -v supermemory >/dev/null && (( ! UPGRADE )); then echo 'Supermemory already installed; use --upgrade'; exit 0; fi
if [[ "$MODE" == interactive ]]; then
  [[ -t 0 ]] || { echo 'ERROR: pass --yes' >&2; exit 1; }
  read -r -p 'Install/update Supermemory? [y/N] ' a
  [[ "$a" =~ ^([yY]|yes|YES)$ ]] || exit 0
fi
"${CMD[@]}"
command -v supermemory >/dev/null || { echo 'ERROR: supermemory not on PATH after install' >&2; exit 1; }
