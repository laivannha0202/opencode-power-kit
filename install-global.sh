#!/usr/bin/env bash
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
# shellcheck source=scripts/require-linux.sh
source "$KIT_DIR/scripts/require-linux.sh"
opk_require_linux

command -v python3 >/dev/null 2>&1 || {
  echo 'install-global: python3 is required for safe config merging' >&2
  exit 1
}

exec python3 "$KIT_DIR/scripts/install-global.py" --kit-dir "$KIT_DIR" "$@"
