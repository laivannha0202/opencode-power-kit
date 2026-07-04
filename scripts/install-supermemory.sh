#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# install-supermemory.sh
# opencode-power-kit v1.6.7
#
# Optional integration with Supermemory CLI (npm).
#
# This script does NOT vendor or copy Supermemory source. It only
# installs the official npm package via npm global install when
# the user explicitly requests it.
#
# Supermemory is a separate, third-party project (see THIRD_PARTY.md):
#   https://github.com/supermemory/supermemory
#
# SAFETY:
#   - --dry-run prints the plan and exits 0.
#   - --yes     skips the confirmation prompt.
#   - Refuses to run with sudo.
#   - Never piped through curl|sh.
#   - Never modifies .env or secrets.
#   - Prefers npm global install; never uses sudo npm.
#   - After install, verifies: supermemory --help
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
MODE="interactive"
# DEPRECATED: @supermemory/ai is no longer maintained.
# Use 'supermemory' or '@supermemory/tools' instead.
# See: https://github.com/supermemory/supermemory
SUPERMEMORY_PACKAGE="supermemory"

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--yes]

Install Supermemory CLI for memory persistence across AI coding sessions.

FLAGS:
  --dry-run        Print the plan. Do not install anything.
  --yes            Skip the confirmation prompt. Install immediately.
  -h, --help       Show this help.

DETAILS:
  - Requires \`node\` and \`npm\` on PATH.
  - Installs via \`npm install -g ${SUPERMEMORY_PACKAGE}\`.
  - NEVER uses sudo.
  - NEVER uses curl|sh.
  - After install, runs \`supermemory --help\` to verify.

EXAMPLES:
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --yes
EOF
}

# ─── Argument parsing ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		MODE="dry-run"
		shift
		;;
	--yes)
		MODE="yes"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "ERROR: unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

# ─── Pre-flight: node + npm ───────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
	echo "ERROR: 'node' is not on PATH. Install Node.js first." >&2
	exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
	echo "ERROR: 'npm' is not on PATH. Install npm first." >&2
	exit 1
fi

echo "=== install-supermemory ==="
echo "Mode:          ${MODE}"
echo "Node:          $(command -v node) ($(node --version 2>&1))"
echo "npm:           $(command -v npm) ($(npm --version 2>&1))"
echo "Package:       ${SUPERMEMORY_PACKAGE}"

# ─── Check if already installed ──────────────────────────────────
ALREADY_INSTALLED=false
if command -v supermemory >/dev/null 2>&1; then
	ALREADY_INSTALLED=true
	echo "ℹ️  'supermemory' already on PATH: $(command -v supermemory)"
	supermemory --help 2>&1 | head -3
	echo ""
fi

# ─── Plan ─────────────────────────────────────────────────────────
INSTALL_CMD=(npm install -g "${SUPERMEMORY_PACKAGE}")

echo ""
echo "Plan:"
echo "  Command:  ${INSTALL_CMD[*]}"
echo "  Sudo:     NO"
echo "  curl|sh:  NO"
echo ""

if [[ "${MODE}" == "dry-run" ]]; then
	echo "Dry run complete. Re-run with --yes to install."
	exit 0
fi

if [[ "${ALREADY_INSTALLED}" == true ]]; then
	echo "✅ supermemory is already installed and on PATH."
	exit 0
fi

# ─── Interactive confirmation ─────────────────────────────────────
if [[ "${MODE}" == "interactive" ]]; then
	if [[ ! -t 0 ]]; then
		echo "ERROR: no TTY available; refusing to run without --yes." >&2
		exit 1
	fi
	read -r -p "Install '${SUPERMEMORY_PACKAGE}' via npm now? [y/N] " reply
	case "${reply}" in
	y | Y | yes | YES) : ;;
	*)
		echo "aborted."
		exit 0
		;;
	esac
fi

# ─── Install ──────────────────────────────────────────────────────
echo "==> ${INSTALL_CMD[*]}"
"${INSTALL_CMD[@]}"
echo ""

# ─── Verify ───────────────────────────────────────────────────────
if command -v supermemory >/dev/null 2>&1; then
	echo "✅ supermemory installed at: $(command -v supermemory)"
	supermemory --help 2>&1 | head -5
	echo ""
	echo "🎉 Supermemory is ready. Quick start:"
	echo "    supermemory init          # Initialize in your project"
	echo "    supermemory status        # Check memory status"
	echo ""
	echo "Agent command: /supermemory-init"
else
	echo "⚠️  Installation may have succeeded but 'supermemory' is not on PATH." >&2
	NPM_GLOBAL="$(npm root -g 2>/dev/null)/../bin"
	echo "   Check: ${NPM_GLOBAL}" >&2
	echo "   Try adding to your shell config:" >&2
	echo "       export PATH=\"${NPM_GLOBAL}:\$PATH\"" >&2
	echo "   Then re-run: supermemory --help" >&2
	exit 1
fi
