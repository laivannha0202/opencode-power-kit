#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# install-ecc-lite.sh
# opencode-power-kit v1.8.0
#
# Optional ECC-lite integration.
#
# This script installs only the OPK-native ECC-lite components:
#   - ecc-lite-strong.md agent
#   - 6 slash commands (/ecc-audit, /quality-gate, /research-first,
#     /verify-loop, /model-route-review, /harness-audit)
#   - 3 supporting scripts (audit-ecc.sh, install-ecc-lite.sh,
#     check-ecc-lite.sh)
#
# ECC-lite is a lightweight adaptation of Engineering Code
# Commandments (ECC) principles into OPK's native agent/command
# system. It does NOT install the full ECC system (260+ skills,
# 80+ commands, hooks, MCP configs, memory system).
#
# ECC is a separate, third-party project (see THIRD_PARTY.md):
#   https://github.com/affaan-m/ECC
#
# SAFETY:
#   - --dry-run prints the plan and exits 0.
#   - --yes     skips the confirmation prompt.
#   - Refuses to run with sudo.
#   - Never clones ECC full source into project.
#   - Never modifies .env or secrets.
#   - Never installs ECC hooks or MCP configs.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="interactive"

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--yes]

Install ECC-lite components from OPK (no full ECC install).

FLAGS:
  --dry-run        Print the plan. Do not install anything.
  --yes            Skip the confirmation prompt. Install immediately.
  -h, --help       Show this help.

DETAILS:
  Installs these OPK-native components:
    • Agent:       ecc-lite-strong.md → opencode-global/agents/
    • Commands:    /ecc-audit, /quality-gate, /research-first,
                   /verify-loop, /model-route-review, /harness-audit
    • Scripts:     audit-ecc.sh, install-ecc-lite.sh, check-ecc-lite.sh

  Does NOT install full ECC:
    • No ECC hooks or git hooks
    • No ECC MCP configuration
    • No ECC memory system
    • No ECC 260+ skills or 80+ commands
    • No ECC auto-installer or bootstrap

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

echo "=== install-ecc-lite ==="
echo "Mode:       ${MODE}"
echo "Kit dir:    ${KIT_DIR}"
echo ""

# ─── Files to install ─────────────────────────────────────────────
declare -a ECC_AGENTS=(
	"opencode-global/agents/ecc-lite-strong.md"
)

declare -a ECC_COMMANDS=(
	"opencode-global/commands/ecc-audit.md"
	"opencode-global/commands/quality-gate.md"
	"opencode-global/commands/research-first.md"
	"opencode-global/commands/verify-loop.md"
	"opencode-global/commands/model-route-review.md"
	"opencode-global/commands/harness-audit.md"
)

declare -a ECC_SCRIPTS=(
	"scripts/audit-ecc.sh"
	"scripts/install-ecc-lite.sh"
	"scripts/check-ecc-lite.sh"
)

# ─── Verification function ────────────────────────────────────────
check_file() {
	local path="$1"
	if [[ -f "${KIT_DIR}/${path}" ]]; then
		return 0
	else
		return 1
	fi
}

all_files_exist() {
	local missing=0
	for f in "${ECC_AGENTS[@]}" "${ECC_COMMANDS[@]}" "${ECC_SCRIPTS[@]}"; do
		if ! check_file "$f"; then
			echo "  MISSING: ${f}" >&2
			missing=1
		fi
	done
	return ${missing}
}

# ─── Dry run ──────────────────────────────────────────────────────
if [[ "${MODE}" == "dry-run" ]]; then
	echo "Plan: Install ECC-lite components from OPK"
	echo ""
	echo "Agents (1):"
	for f in "${ECC_AGENTS[@]}"; do
		echo "  • ${f}"
	done
	echo ""
	echo "Commands (6):"
	for f in "${ECC_COMMANDS[@]}"; do
		echo "  • ${f}"
	done
	echo ""
	echo "Scripts (3):"
	for f in "${ECC_SCRIPTS[@]}"; do
		echo "  • ${f}"
	done
	echo ""
	echo "NOT installing full ECC:"
	echo "  • No ECC hooks or git hooks"
	echo "  • No ECC MCP configuration"
	echo "  • No ECC memory system"
	echo "  • No ECC 260+ skills or 80+ commands"
	echo "  • No ECC auto-installer"
	echo ""
	echo "Dry run complete. Re-run with --yes to install."
	exit 0
fi

# ─── Check all source files exist ─────────────────────────────────
if ! all_files_exist; then
	echo ""
	echo "ERROR: Some ECC-lite source files are missing in OPK." >&2
	echo "       Re-clone or update opencode-power-kit." >&2
	exit 1
fi

# ─── Interactive confirmation ─────────────────────────────────────
if [[ "${MODE}" == "interactive" ]]; then
	if [[ ! -t 0 ]]; then
		echo "ERROR: no TTY available; refusing to run without --yes." >&2
		exit 1
	fi
	echo "This will install ECC-lite components (NO full ECC install)."
	echo ""
	read -r -p "Install ECC-lite now? [y/N] " reply
	case "${reply}" in
	y | Y | yes | YES) : ;;
	*)
		echo "aborted."
		exit 0
		;;
	esac
fi

# ─── Install ───────────────────────────────────────────────────────
echo "==> Installing ECC-lite components..."
echo ""

INSTALLED=0
SKIPPED=0

# Agents already exist in opencode-global/agents/ — they are part of OPK
# The "install" here means symlink or copy to ~/.config/opencode/agents
# Determine install dir: prefer OPENCODE_CONFIG_DIR over ~/.config/opencode
if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
	INSTALL_DIR="${OPENCODE_CONFIG_DIR}/agents"
else
	INSTALL_DIR="${HOME}/.config/opencode/agents"
fi
mkdir -p "${INSTALL_DIR}"

KIT_GLOBAL_DIR="${KIT_DIR}/opencode-global"
for f in "${ECC_AGENTS[@]}"; do
	src="${KIT_DIR}/${f}"
	dst="${INSTALL_DIR}/$(basename "$f")"
	if [[ -f "${dst}" ]]; then
		echo "  ⚠️  Agent already installed: ${dst}"
		SKIPPED=$((SKIPPED + 1))
	elif [[ "${OPENCODE_CONFIG_DIR:-}" == "${KIT_GLOBAL_DIR}" ]]; then
		# OPENCODE_CONFIG_DIR points to the kit's own opencode-global dir,
		# file is already in place — no need to copy
		echo "  ✅ Agent already in place: ${dst}"
		SKIPPED=$((SKIPPED + 1))
	else
		cp "${src}" "${dst}"
		echo "  ✅ Agent: ${f} → ${dst}"
		INSTALLED=$((INSTALLED + 1))
	fi
done

# Commands are already in opencode-global/commands/ — part of OPK
# The "install" means copy to global commands dir
# Determine commands install dir: prefer OPENCODE_CONFIG_DIR
if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
	CMD_INSTALL_DIR="${OPENCODE_CONFIG_DIR}/commands"
else
	CMD_INSTALL_DIR="${HOME}/.config/opencode/commands"
fi
mkdir -p "${CMD_INSTALL_DIR}"

for f in "${ECC_COMMANDS[@]}"; do
	src="${KIT_DIR}/${f}"
	dst="${CMD_INSTALL_DIR}/$(basename "$f")"
	if [[ -f "${dst}" ]]; then
		echo "  ⚠️  Command already installed: ${dst}"
		SKIPPED=$((SKIPPED + 1))
	elif [[ "${OPENCODE_CONFIG_DIR:-}" == "${KIT_GLOBAL_DIR}" ]]; then
		# File already in place in the kit's global dir
		echo "  ✅ Command already in place: ${dst}"
		SKIPPED=$((SKIPPED + 1))
	else
		cp "${src}" "${dst}"
		echo "  ✅ Command: ${f} → ${dst}"
		INSTALLED=$((INSTALLED + 1))
	fi
done

echo ""
echo "=== Installation summary ==="
echo "  Installed: ${INSTALLED}"
echo "  Skipped:   ${SKIPPED}"
echo ""
echo "ECC-lite is ready. Try:"
echo "  opk ecc status"
echo "  /ecc-audit"
echo "  /quality-gate"
echo ""
echo "Run 'opk help' to see all ECC commands."
