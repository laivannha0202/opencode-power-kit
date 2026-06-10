#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# install-markitdown.sh
# opencode-power-kit v1.6.6
#
# Optional integration with Microsoft MarkItDown (Python).
#
# This script does NOT vendor or copy MarkItDown source. It only
# installs the official PyPI package via pipx (preferred) or pip
# when the user explicitly requests it.
#
# MarkItDown is a separate, third-party project (see THIRD_PARTY.md):
#   https://github.com/microsoft/markitdown
#
# SAFETY:
#   - --dry-run prints the plan and exits 0.
#   - --yes     skips the confirmation prompt.
#   - Refuses to run with sudo.
#   - Never piped through curl|sh.
#   - Never modifies .env or secrets.
#   - Prefers pipx over pip; never uses sudo pip.
#   - After install, verifies: markitdown --help
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
MODE="interactive"

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--yes]

Install Microsoft MarkItDown for document-to-Markdown conversion.

FLAGS:
  --dry-run        Print the plan. Do not install anything.
  --yes            Skip the confirmation prompt. Install immediately.
  -h, --help       Show this help.

DETAILS:
  - Requires \`python3\` on PATH.
  - Prefers \`pipx\` if available:
      pipx install "markitdown[all]"
  - Falls back to \`pip\` user install if pipx is absent:
      pip install --user "markitdown[all]"
  - NEVER uses sudo.
  - NEVER uses curl|sh.
  - After install, runs \`markitdown --help\` to verify.

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

# ─── Pre-flight: python3 ──────────────────────────────────────────
if ! command -v python3 >/dev/null 2>&1; then
	echo "ERROR: 'python3' is not on PATH. Install Python 3 first." >&2
	exit 1
fi

echo "=== install-markitdown ==="
echo "Mode:          ${MODE}"
echo "Python:        $(command -v python3) ($(python3 --version 2>&1))"

# ─── Detect pipx / pip ────────────────────────────────────────────
INSTALL_METHOD=""
INSTALL_CMD=""

if command -v pipx >/dev/null 2>&1; then
	INSTALL_METHOD="pipx"
	INSTALL_CMD=(pipx install "markitdown[all]")
	echo "Install tool:  pipx ($(pipx --version 2>&1))"
	# Determine pipx root for info
	PIPX_BIN_DIR="$(pipx environment 2>/dev/null | grep 'PIPX_BIN_DIR' | cut -d= -f2 || echo "$HOME/.local/bin")"
	echo "Pipx bin dir:  ${PIPX_BIN_DIR}"
elif command -v pip >/dev/null 2>&1; then
	INSTALL_METHOD="pip"
	INSTALL_CMD=(pip install --user "markitdown[all]")
	echo "Install tool:  pip (--user)"
	echo "Python bin:    $(python3 -c 'import site; print(site.USER_BASE)' 2>/dev/null)/bin"
else
	echo "ERROR: neither 'pipx' nor 'pip' is available." >&2
	echo "       Install pipx or pip first, then re-run this script." >&2
	echo ""
	echo "  Debian/Ubuntu:  sudo apt install python3-pip python3-pipx"
	echo "  macOS:          brew install pipx && pipx ensurepath"
	echo "  Windows:        pip install pipx"
	exit 1
fi

echo ""

# ─── Check if already installed ──────────────────────────────────
ALREADY_INSTALLED=false
if command -v markitdown >/dev/null 2>&1; then
	ALREADY_INSTALLED=true
	echo "ℹ️  'markitdown' already on PATH: $(command -v markitdown)"
	markitdown --help 2>&1 | head -3
	echo ""
fi

# ─── Plan ─────────────────────────────────────────────────────────
echo "Plan:"
echo "  Tool:  ${INSTALL_METHOD}"
echo "  Command:  ${INSTALL_CMD[*]}"
echo ""

if [[ "${MODE}" == "dry-run" ]]; then
	echo "Dry run complete. Re-run with --yes to install."
	exit 0
fi

if [[ "${ALREADY_INSTALLED}" == true ]]; then
	echo "✅ markitdown is already installed and on PATH."
	exit 0
fi

# ─── Interactive confirmation ─────────────────────────────────────
if [[ "${MODE}" == "interactive" ]]; then
	if [[ ! -t 0 ]]; then
		echo "ERROR: no TTY available; refusing to run without --yes." >&2
		exit 1
	fi
	read -r -p "Install 'markitdown[all]' via ${INSTALL_METHOD} now? [y/N] " reply
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
if command -v markitdown >/dev/null 2>&1; then
	echo "✅ markitdown installed at: $(command -v markitdown)"
	markitdown --help 2>&1 | head -5
	echo ""
	echo "🎉 MarkItDown is ready. Quick test:"
	echo "    markitdown input.pdf > output.md"
	echo "    markitdown input.docx > output.md"
	echo "    markitdown input.html > output.md"
else
	echo "⚠️  Installation may have succeeded but 'markitdown' is not on PATH." >&2
	echo "   Try adding the following to your shell configuration:" >&2
	if [[ "${INSTALL_METHOD}" == "pipx" ]]; then
		echo "       pipx ensurepath" >&2
	else
		PYTHON_USER_BIN="$(python3 -c 'import site; print(site.USER_BASE)' 2>/dev/null)/bin"
		echo "       export PATH=\"${PYTHON_USER_BIN}:\$PATH\"" >&2
	fi
	echo "   Then re-run: markitdown --help" >&2
	exit 1
fi
