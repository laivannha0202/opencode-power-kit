#!/usr/bin/env bash
set -euo pipefail
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$KIT_DIR/scripts/require-linux.sh"
opk_require_linux
source "$KIT_DIR/scripts/upstream-versions.sh"
[[ "$(id -u)" -ne 0 ]] || { echo 'ERROR: do not run with sudo/root' >&2; exit 1; }
MODE=interactive
while (($#)); do
  case "$1" in
    --dry-run) MODE=dry-run ;;
    --yes|-y) MODE=yes ;;
    -h|--help) echo 'Usage: update-bmad.sh [--dry-run] [--yes]'; exit 0 ;;
    *) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done
VERSION="${BMAD_METHOD_VERSION:-$OPK_BMAD_VERSION}"
TARGET="$(pwd -P)"
[[ -f "$TARGET/.opencode/opencode.json" ]] || { echo 'ERROR: run opk install first' >&2; exit 1; }
CMD=(npx --yes "bmad-method@$VERSION" install --modules bmm --tools opencode --user-name "${OPK_USER_NAME:-${USER:-User}}" --communication-language Vietnamese --document-output-language Vietnamese --directory "$TARGET" -y)
printf 'BMAD plan:'; printf ' %q' "${CMD[@]}"; printf '\n'
[[ "$MODE" == dry-run ]] && exit 0
command -v npx >/dev/null || { echo 'ERROR: npx not found' >&2; exit 1; }
if [[ "$MODE" == interactive ]]; then
  [[ -t 0 ]] || { echo 'ERROR: pass --yes' >&2; exit 1; }
  read -r -p 'Update BMAD? [y/N] ' a
  [[ "$a" =~ ^([yY]|yes|YES)$ ]] || exit 0
fi
LOG="$TARGET/.opencode-power-bmad-update.log"
"${CMD[@]}" >"$LOG" 2>&1 || { rc=$?; tail -50 "$LOG" >&2 || true; exit "$rc"; }
echo "BMAD $VERSION updated"
