#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/upstream-versions.sh"
[[ "$(id -u)" -ne 0 ]] || { echo 'ERROR: do not run with sudo/root' >&2; exit 1; }
VERSION="${GSD_CORE_VERSION:-$OPK_GSD_VERSION}"
MODE=interactive
TARGET=""
if [[ "${1:-}" == status ]]; then
  echo "Pinned version: $VERSION"
  command -v gsd-core >/dev/null 2>&1 && echo INSTALLED || echo NOT_INSTALLED
  exit 0
fi
while (($#)); do
  case "$1" in
    --dry-run) MODE=dry-run ;;
    --yes|-y) MODE=yes ;;
    --target) shift; TARGET="${1:?missing target}" ;;
    -h|--help) echo 'Usage: install-gsd-core.sh [status] [--dry-run] [--yes] [--target DIR]'; exit 0 ;;
    *) echo "ERROR: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done
CMD=(npx "@opengsd/gsd-core@$VERSION")
[[ -n "$TARGET" ]] && CMD+=("$TARGET")
printf 'GSD plan:'; printf ' %q' "${CMD[@]}"; printf '\n'
[[ "$MODE" == dry-run ]] && exit 0
command -v npx >/dev/null || { echo 'ERROR: npx not found' >&2; exit 1; }
if [[ "$MODE" == interactive ]]; then
  [[ -t 0 ]] || { echo 'ERROR: pass --yes' >&2; exit 1; }
  read -r -p 'Update GSD? [y/N] ' a
  [[ "$a" =~ ^([yY]|yes|YES)$ ]] || exit 0
fi
exec "${CMD[@]}"
