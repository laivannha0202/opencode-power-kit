#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# install-taste-skill.sh
# opencode-power-kit v1.7.0
#
# Optional integration with Leonxlnx/taste-skill.
#
# This script does NOT vendor or copy Taste Skill source. It only
# installs the official npm package via npx when the user explicitly
# requests it.
#
# Taste Skill is a separate, third-party project (see THIRD_PARTY.md):
#   https://github.com/Leonxlnx/taste-skill
#
# SAFETY:
#   - --dry-run prints the plan and exits 0.
#   - --yes     skips the confirmation prompt.
#   - Refuses to run with sudo.
#   - Never piped through curl|sh.
#   - Never modifies .env or secrets.
#   - Prefers npx; never uses sudo npm.
#   - After install, verifies taste-skill file exists.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
MODE="interactive"
TASTE_PACKAGE="Leonxlnx/taste-skill"
OPK_SKIP_TASTE="${OPK_SKIP_TASTE:-}"

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--yes]

Install Taste Skill for AI-augmented UI/UX design (npm).

FLAGS:
  --dry-run        Print the plan. Do not install anything.
  --yes            Skip the confirmation prompt. Install immediately.
  -h, --help       Show this help.

DETAILS:
  - Requires \`node\`, \`npm\`, and \`npx\` on PATH.
  - Installs via: npx skills add ${TASTE_PACKAGE}
  - NEVER uses sudo.
  - NEVER uses curl|sh.
  - NOT required for core opencode-power-kit functionality.
  - Set OPK_SKIP_TASTE=1 to skip installation entirely.

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

# ─── Check for skip env var ───────────────────────────────────────
if [[ "${OPK_SKIP_TASTE}" == "1" ]]; then
	echo "=== install-taste-skill ==="
	echo "OPK_SKIP_TASTE=1 — bỏ qua cài đặt Taste Skill."
	exit 0
fi

# ─── Pre-flight: node + npm + npx (graceful: only warn, don't fail) ───
HAVE_NODE=false
HAVE_NPX=false
if command -v node >/dev/null 2>&1; then
	HAVE_NODE=true
fi
if command -v npx >/dev/null 2>&1; then
	HAVE_NPX=true
fi

if ! $HAVE_NODE || ! $HAVE_NPX; then
	echo "=== install-taste-skill ===" >&2
	echo "⚠️  node/npx không tìm thấy. Taste Skill yêu cầu Node.js." >&2
	echo "   Bỏ qua cài đặt. Install Node.js từ https://nodejs.org" >&2
	echo "   rồi chạy lại: npx skills add ${TASTE_PACKAGE}" >&2
	exit 0
fi

echo "=== install-taste-skill ==="
echo "Mode:          ${MODE}"
echo "Node:          $(command -v node) ($(node --version 2>&1))"
echo "npx:           $(command -v npx)"
echo "Package:       ${TASTE_PACKAGE}"
echo ""

# ─── Detect if already installed ──────────────────────────────────
ALREADY_INSTALLED=false
TASTE_FILE=""
# Taste Skill typically installs as a skill file — check common locations
if [[ -d "${HOME}/.config/opencode/skills/taste-skill" ]] ||
	[[ -f "${HOME}/.config/opencode/skills/taste-skill/SKILL.md" ]]; then
	ALREADY_INSTALLED=true
	TASTE_FILE="${HOME}/.config/opencode/skills/taste-skill/SKILL.md"
	echo "ℹ️  Taste Skill đã được cài đặt tại: ${TASTE_FILE}"
elif command -v taste-skill >/dev/null 2>&1; then
	ALREADY_INSTALLED=true
	TASTE_FILE="$(command -v taste-skill)"
	echo "ℹ️  'taste-skill' đã có trên PATH: ${TASTE_FILE}"
fi

# ─── Plan ─────────────────────────────────────────────────────────
INSTALL_CMD=(npx skills add "${TASTE_PACKAGE}")

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
	echo "✅ Taste Skill đã được cài đặt."
	exit 0
fi

# ─── Interactive confirmation ─────────────────────────────────────
if [[ "${MODE}" == "interactive" ]]; then
	if [[ ! -t 0 ]]; then
		echo "ERROR: no TTY available; refusing to run without --yes." >&2
		exit 1
	fi
	read -r -p "Install '${TASTE_PACKAGE}' via npx now? [y/N] " reply
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
# npx skills add may fail on network — we catch and warn (not fail)
if ! "${INSTALL_CMD[@]}"; then
	echo "⚠️  Taste Skill installation failed (network or npx issue)." >&2
	echo "   Bạn có thể thử lại sau: npx skills add ${TASTE_PACKAGE}" >&2
	exit 0
fi
echo ""

# ─── Verify ───────────────────────────────────────────────────────
if [[ -d "${HOME}/.config/opencode/skills/taste-skill" ]] ||
	[[ -f "${HOME}/.config/opencode/skills/taste-skill/SKILL.md" ]]; then
	echo "✅ Taste Skill installed at: ${HOME}/.config/opencode/skills/taste-skill/"
	echo ""
	echo "🎉 Taste Skill is ready. Các lệnh khả dụng:"
	echo "    /taste-polish     — UI polish & refinement"
	echo "    /redesign-ui      — Redesign existing UI"
	echo "    /image-to-code    — Convert design image to code"
	echo "    /brandkit         — Brand kit generation"
	echo "    /mobile-ui        — Mobile UI optimization"
	echo "    /landing-ui       — Landing page UI"
	echo "    /ui-final-pass    — Final UI quality pass"
	echo ""
	echo "Chạy: opk taste-status  — kiểm tra trạng thái"
else
	echo "⚠️  Taste Skill installed nhưng không tìm thấy skill file." >&2
	echo "   Kiểm tra lại: ls ~/.config/opencode/skills/taste-skill/" >&2
	exit 0
fi
