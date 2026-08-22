#!/usr/bin/env bash
# OpenCode Power Kit - transactional full-stack profile installer.
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/require-linux.sh
source "$KIT_DIR/scripts/require-linux.sh"
opk_require_linux

if ! command -v python3 >/dev/null 2>&1; then
  echo "install-fullstack-profile: python3 is required" >&2
  exit 1
fi

exec python3 "$KIT_DIR/scripts/install-fullstack-profile.py" "$@"
