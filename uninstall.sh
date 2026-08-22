#!/usr/bin/env bash
# OpenCode Power Kit - fail-closed project uninstall.
set -euo pipefail

AUTO_YES=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y) AUTO_YES=true ;;
    --help|-h)
      cat <<'USAGE'
Usage: bash uninstall.sh [--yes]

Restores the latest finalized OPK install session using:
  .opk-state/installs/<session>/manifest.json
  .opk-wal/archive-*/...
  .opk-state/transactions/<txid>/...

If a recorded managed file changed after install, uninstall refuses before
restoring anything. BMAD/application artifacts outside the recorded OPK
session are left for manual review.
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] Unknown arg: $arg (use --yes or --help)" >&2
      exit 1
      ;;
  esac
done

KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$KIT_DIR/scripts/require-linux.sh"
opk_require_linux
TARGET_DIR="$(pwd)"

ARGS=(uninstall --root "$TARGET_DIR")
if [ "$AUTO_YES" = true ]; then
  ARGS+=(--yes)
fi

python3 "$KIT_DIR/scripts/opk_install_session.py" "${ARGS[@]}"
echo ""
echo "[OK] OPK install session uninstalled."
echo "[INFO] User edits outside recorded OPK-managed paths were untouched."
