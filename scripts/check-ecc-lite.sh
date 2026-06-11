#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# check-ecc-lite.sh
# opencode-power-kit v1.8.0
#
# Check ECC-lite installation status.
# Read-only — never modifies anything.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME}

Check ECC-lite installation status. Read-only.

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

echo "=== check-ecc-lite ==="
echo ""

# ─── Check ECC-lite agent ─────────────────────────────────────────
echo "--- Agent ---"
AGENT_FILE="${HOME}/.config/opencode/agents/ecc-lite-strong.md"
if [[ -f "${AGENT_FILE}" ]]; then
	echo "  ✅ ecc-lite-strong.md installed at: ${AGENT_FILE}"
else
	echo "  ❌ ecc-lite-strong.md not installed"
	echo "     Install: opk ecc install"
fi
echo ""

# ─── Check ECC commands ──────────────────────────────────────────
echo "--- Commands ---"
COMMANDS_FOUND=0
COMMANDS_MISSING=0
for cmd in ecc-audit quality-gate research-first verify-loop model-route-review harness-audit; do
	path="${KIT_DIR}/opencode-global/commands/${cmd}.md"
	if [[ -f "${path}" ]]; then
		echo "  ✅ /${cmd} — ${path}"
		COMMANDS_FOUND=$((COMMANDS_FOUND + 1))
	else
		echo "  ❌ /${cmd} — missing"
		COMMANDS_MISSING=$((COMMANDS_MISSING + 1))
	fi
done
echo ""

# ─── Check ECC scripts ──────────────────────────────────────────
echo "--- Scripts ---"
SCRIPTS_OK=0
SCRIPTS_MISSING=0
for script in audit-ecc.sh install-ecc-lite.sh check-ecc-lite.sh; do
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

# ─── Check full ECC (not required, but detected) ────────────────
echo "--- Full ECC (not required) ---"
if command -v ecc >/dev/null 2>&1; then
	echo "  ℹ️  Full ECC detected on PATH: $(command -v ecc)"
	echo "     ECC-lite can coexist with full ECC."
else
	echo "  ℹ️  Full ECC not installed (ECC-lite works independently)"
fi
echo ""

# ─── Summary ──────────────────────────────────────────────────────
# Determine agent status
if [[ -f "${AGENT_FILE}" ]]; then
	AGENT_STATUS="✅ installed"
else
	AGENT_STATUS="❌ not installed"
fi

echo "=== Summary ==="
echo "  Agent:   ${AGENT_STATUS}"
echo "  Commands: ${COMMANDS_FOUND}/6 present"
echo "  Scripts:  ${SCRIPTS_OK}/3 present"
echo ""
if [[ -f "${AGENT_FILE}" && ${COMMANDS_MISSING} -eq 0 && ${SCRIPTS_MISSING} -eq 0 ]]; then
	echo "✅ ECC-lite is fully installed and ready."
	exit 0
else
	echo "⚠️  ECC-lite is partially installed. Some components missing."
	exit 1
fi
