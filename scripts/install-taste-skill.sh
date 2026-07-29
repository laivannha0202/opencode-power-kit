#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/upstream-versions.sh"
[[ "$(id -u)" -ne 0 ]] || { echo 'ERROR: do not run with sudo/root' >&2; exit 1; }
MODE=interactive
REFRESH=0
while (($#)); do
  case "$1" in
    --dry-run) MODE=dry-run ;;
    --yes|-y) MODE=yes ;;
    --refresh|--upgrade) REFRESH=1 ;;
    -h|--help) echo 'Usage: install-taste-skill.sh [--dry-run] [--yes] [--refresh]'; exit 0 ;;
    *) echo "ERROR: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done
command -v npx >/dev/null || { echo 'ERROR: npx not found' >&2; exit 1; }
TARGET="$HOME/.config/opencode/skills/taste-skill"
CMD=(npx skills add "$OPK_TASTE_SOURCE")
printf 'Taste plan:'; printf ' %q' "${CMD[@]}"; printf '\n'
if [[ "$MODE" == dry-run ]]; then
  [[ -d "$TARGET" && $REFRESH -eq 1 ]] && echo "DRY-RUN: move $TARGET to safe trash before reinstall"
  exit 0
fi
if [[ -d "$TARGET" && $REFRESH -eq 0 ]]; then echo 'Taste already installed; use --refresh'; exit 0; fi
if [[ "$MODE" == interactive ]]; then
  [[ -t 0 ]] || { echo 'ERROR: pass --yes' >&2; exit 1; }
  read -r -p 'Install/update Taste? [y/N] ' a
  [[ "$a" =~ ^([yY]|yes|YES)$ ]] || exit 0
fi
if [[ -d "$TARGET" ]]; then
  trash="$KIT_DIR/.opk-trash/taste-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$trash"
  mv "$TARGET" "$trash/"
fi
"${CMD[@]}"
[[ -f "$TARGET/SKILL.md" ]] || { echo 'ERROR: Taste skill verification failed' >&2; exit 1; }
