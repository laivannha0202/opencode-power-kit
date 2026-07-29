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
    -h|--help) echo 'Usage: install-markitdown.sh [--dry-run] [--yes] [--upgrade]'; exit 0 ;;
    *) echo "ERROR: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done
VERSION="${MARKITDOWN_VERSION:-$OPK_MARKITDOWN_VERSION}"
SPEC="markitdown[all]==$VERSION"
command -v python3 >/dev/null || { echo 'ERROR: python3 not found' >&2; exit 1; }
if command -v pipx >/dev/null; then
  CMD=(pipx install)
  ((UPGRADE)) && CMD+=(--force)
  CMD+=("$SPEC")
else
  CMD=(python3 -m pip install --user)
  ((UPGRADE)) && CMD+=(--upgrade)
  CMD+=("$SPEC")
fi
printf 'MarkItDown plan:'; printf ' %q' "${CMD[@]}"; printf '\n'
[[ "$MODE" == dry-run ]] && exit 0
if command -v markitdown >/dev/null && (( ! UPGRADE )); then echo 'MarkItDown already installed; use --upgrade'; exit 0; fi
if [[ "$MODE" == interactive ]]; then
  [[ -t 0 ]] || { echo 'ERROR: pass --yes' >&2; exit 1; }
  read -r -p 'Install/update MarkItDown? [y/N] ' a
  [[ "$a" =~ ^([yY]|yes|YES)$ ]] || exit 0
fi
"${CMD[@]}"
command -v markitdown >/dev/null || { echo 'ERROR: markitdown not on PATH after install' >&2; exit 1; }
