#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# check-hermes-lite.sh
# opencode-power-kit v1.9.0
#
# Check Hermes-lite installation status.
# Read-only — never modifies anything.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME}

Check Hermes-lite installation status. Read-only.

FLAGS:
  -h, --help       Show this help.
EOF
}

# ─── Argument parsing ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
	case "$1" in
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

echo "=== check-hermes-lite ==="
echo ""

# ─── Check Hermes-lite agent ─────────────────────────────────────
echo "--- Agent ---"
AGENT_FILE=""
# Priority 1: OPENCODE_CONFIG_DIR (if set and file exists)
if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
	candidate="${OPENCODE_CONFIG_DIR}/agents/hermes-lite-strong.md"
	if [[ -f "${candidate}" ]]; then
		AGENT_FILE="${candidate}"
	fi
fi
# Priority 2: fallback to ~/.config/opencode
if [[ -z "${AGENT_FILE}" ]]; then
	candidate="${HOME}/.config/opencode/agents/hermes-lite-strong.md"
	if [[ -f "${candidate}" ]]; then
		AGENT_FILE="${candidate}"
	fi
fi
# Priority 3: fallback to kit bundled
if [[ -z "${AGENT_FILE}" ]]; then
	candidate="${KIT_DIR}/opencode-global/agents/hermes-lite-strong.md"
	if [[ -f "${candidate}" ]]; then
		AGENT_FILE="${candidate}"
	fi
fi

if [[ -n "${AGENT_FILE}" ]]; then
	echo "  ✅ hermes-lite-strong.md installed at: ${AGENT_FILE}"
else
	echo "  ❌ hermes-lite-strong.md not installed"
	echo "     Install: opk hermes lite"
fi
echo ""

# ─── Check Hermes commands ───────────────────────────────────────
echo "--- Commands ---"
COMMANDS_FOUND=0
COMMANDS_MISSING=0
for cmd in hermes-reflect hermes-skill hermes-kanban hermes-memory hermes-budget hermes-audit hermes-learn hermes-research; do
	path=""
	# Priority: OPENCODE_CONFIG_DIR/commands
	if [[ -n "${OPENCODE_CONFIG_DIR:-}" ]]; then
		candidate="${OPENCODE_CONFIG_DIR}/commands/${cmd}.md"
		if [[ -f "${candidate}" ]]; then
			path="${candidate}"
		fi
	fi
	# Fallback: KIT_DIR bundled
	if [[ -z "${path}" ]]; then
		candidate="${KIT_DIR}/opencode-global/commands/${cmd}.md"
		if [[ -f "${candidate}" ]]; then
			path="${candidate}"
		fi
	fi
	# Fallback: ~/.config/opencode
	if [[ -z "${path}" ]]; then
		candidate="${HOME}/.config/opencode/commands/${cmd}.md"
		if [[ -f "${candidate}" ]]; then
			path="${candidate}"
		fi
	fi

	if [[ -n "${path}" ]]; then
		echo "  ✅ /${cmd} — ${path}"
		COMMANDS_FOUND=$((COMMANDS_FOUND + 1))
	else
		echo "  ❌ /${cmd} — missing"
		COMMANDS_MISSING=$((COMMANDS_MISSING + 1))
	fi
done
echo ""

# ─── Check Hermes scripts ────────────────────────────────────────
echo "--- Scripts ---"
SCRIPTS_OK=0
SCRIPTS_MISSING=0
for script in audit-hermes.sh check-hermes-lite.sh hermes-learning-capsule.sh; do
	path="${KIT_DIR}/scripts/${script}"
	if [[ -f "${path}" ]]; then
		echo "  ✅ ${script} — ${path}"
		SCRIPTS_OK=$((SCRIPTS_OK + 1))
	else
		echo "  ❌ ${script} — missing"
		SCRIPTS_MISSING=$((SCRIPTS_MISSING + 1))
	fi
done
echo ""

# ─── Check Hermes docs ───────────────────────────────────────────
echo "--- Docs ---"
DOCS_OK=0
DOCS_MISSING=0
for doc in HERMES_INTEGRATION.md HERMES_AUDIT.md LEARNING_LOOP.md AGENT_KANBAN.md; do
	path="${KIT_DIR}/docs/${doc}"
	if [[ -f "${path}" ]]; then
		echo "  ✅ ${doc} — ${path}"
		DOCS_OK=$((DOCS_OK + 1))
	else
		echo "  ❌ ${doc} — missing"
		DOCS_MISSING=$((DOCS_MISSING + 1))
	fi
done
echo ""

# ─── Check CLI integration ───────────────────────────────────────
echo "--- CLI Integration ---"
CLI_OPK=false
CLI_PS1=false
if grep -q 'hermes' "${KIT_DIR}/bin/opk" 2>/dev/null; then
	echo "  ✅ bin/opk — hermes subcommand found"
	CLI_OPK=true
else
	echo "  ❌ bin/opk — hermes subcommand NOT found"
fi
if grep -q 'hermes' "${KIT_DIR}/bin/opk.ps1" 2>/dev/null; then
	echo "  ✅ bin/opk.ps1 — hermes subcommand found"
	CLI_PS1=true
else
	echo "  ❌ bin/opk.ps1 — hermes subcommand NOT found"
fi
echo ""

# ─── Summary ──────────────────────────────────────────────────────
AGENT_STATUS="❌ not installed"
if [[ -f "${AGENT_FILE}" ]]; then
	AGENT_STATUS="✅ installed"
fi

echo "=== Summary ==="
echo "  Agent:   ${AGENT_STATUS}"
echo "  Commands: ${COMMANDS_FOUND}/8 present"
echo "  Scripts:  ${SCRIPTS_OK}/3 present"
echo "  Docs:     ${DOCS_OK}/4 present"
echo "  CLI:      opk=${CLI_OPK}, ps1=${CLI_PS1}"
echo ""

ALL_OK=true
if [[ ! -f "${AGENT_FILE}" ]]; then ALL_OK=false; fi
if [[ ${COMMANDS_MISSING} -ne 0 ]]; then ALL_OK=false; fi
if [[ ${SCRIPTS_MISSING} -ne 0 ]]; then ALL_OK=false; fi
if [[ ${DOCS_MISSING} -ne 0 ]]; then ALL_OK=false; fi
if [[ "${CLI_OPK}" != true ]]; then ALL_OK=false; fi

if [[ "${ALL_OK}" == true ]]; then
	echo "✅ Hermes-lite is fully installed and ready."
	exit 0
else
	echo "⚠️  Hermes-lite is partially installed. Some components missing."
	echo "   Run 'opk hermes lite' to install missing components."
	exit 1
fi
