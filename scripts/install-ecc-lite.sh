#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
[[ "$(id -u)" -ne 0 ]] || { echo 'ERROR: do not run with sudo/root' >&2; exit 1; }
MODE=interactive
REFRESH=0
while (($#)); do
  case "$1" in
    --dry-run) MODE=dry-run ;;
    --yes|-y) MODE=yes ;;
    --refresh|--upgrade) REFRESH=1 ;;
    -h|--help) echo 'Usage: install-ecc-lite.sh [--dry-run] [--yes] [--refresh]'; exit 0 ;;
    *) echo "ERROR: unknown flag $1" >&2; exit 2 ;;
  esac
  shift
done
BASE="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
AGENTS=(ecc-lite-strong.md)
COMMANDS=(ecc-audit.md quality-gate.md research-first.md verify-loop.md backend-route-review.md harness-audit.md)
echo "ECC-lite plan: refresh=$REFRESH target=$BASE"
for f in "${AGENTS[@]}"; do echo "  agent: $f"; done
for f in "${COMMANDS[@]}"; do echo "  command: $f"; done
[[ "$MODE" == dry-run ]] && exit 0
if [[ "$MODE" == interactive ]]; then
  [[ -t 0 ]] || { echo 'ERROR: pass --yes' >&2; exit 1; }
  read -r -p 'Install/update ECC-lite? [y/N] ' a
  [[ "$a" =~ ^([yY]|yes|YES)$ ]] || exit 0
fi
mkdir -p "$BASE/agents" "$BASE/commands"
for f in "${AGENTS[@]}"; do
  src="$KIT_DIR/opencode-global/agents/$f"; dst="$BASE/agents/$f"
  [[ -f "$src" ]] || { echo "ERROR: missing $src" >&2; exit 1; }
  [[ "$src" == "$dst" ]] || { [[ ! -e "$dst" || $REFRESH -eq 1 ]] && cp -f "$src" "$dst" || true; }
done
for f in "${COMMANDS[@]}"; do
  src="$KIT_DIR/opencode-global/commands/$f"; dst="$BASE/commands/$f"
  [[ -f "$src" ]] || { echo "ERROR: missing $src" >&2; exit 1; }
  [[ "$src" == "$dst" ]] || { [[ ! -e "$dst" || $REFRESH -eq 1 ]] && cp -f "$src" "$dst" || true; }
done
echo 'ECC-lite ready'
