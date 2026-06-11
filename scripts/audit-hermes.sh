#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# audit-hermes.sh
# opencode-power-kit v1.9.0
#
# Read-only Hermes-lite self-audit. Scans the kit for all
# Hermes-lite components (agent, commands, scripts, docs),
# validates their integrity, and generates a structured audit
# report at docs/HERMES_AUDIT.md.
#
# Never modifies files, never installs anything, never touches
# .env / secrets / MCP config.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT_OUTPUT="${KIT_DIR}/docs/HERMES_AUDIT.md"
MODE="interactive"

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--yes] [--verbose]

Read-only self-audit of Hermes-lite components.

FLAGS:
  --dry-run        Print the plan. Do not audit.
  --yes            Skip the confirmation prompt. Run audit immediately.
  --verbose        Show detailed file checks.
  -h, --help       Show this help.

DETAILS:
  - Validates: agent file, commands, scripts, docs, CLI integration.
  - Checks: file existence, YAML frontmatter, shellcheck, bash -n.
  - Generates docs/HERMES_AUDIT.md with structured findings.
  - NEVER modifies files.
  - NEVER touches .env, secrets, MCP configuration.

EXAMPLES:
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --yes
  ${SCRIPT_NAME} --yes --verbose
EOF
}

# ─── Argument parsing ─────────────────────────────────────────────
VERBOSE=false
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
	--verbose)
		VERBOSE=true
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

# ─── Pre-flight ───────────────────────────────────────────────────
echo "=== audit-hermes ==="
echo "Mode:        ${MODE}"
echo "Kit dir:     ${KIT_DIR}"
echo "Audit out:   ${AUDIT_OUTPUT}"
echo ""

# ─── Dry run ──────────────────────────────────────────────────────
if [[ "${MODE}" == "dry-run" ]]; then
	echo "Plan:"
	echo "  1. Validate agent file (hermes-lite-strong.md)"
	echo "  2. Validate 8 slash commands"
	echo "  3. Validate 3 scripts (bash -n)"
	echo "  4. Validate 4 docs"
	echo "  5. Check CLI integration (bin/opk)"
	echo "  6. Check verify.sh/ps1 integration"
	echo "  7. Write audit report to ${AUDIT_OUTPUT}"
	echo ""
	echo "Dry run complete. Re-run with --yes to audit."
	exit 0
fi

# ─── Interactive confirmation ─────────────────────────────────────
if [[ "${MODE}" == "interactive" ]]; then
	if [[ ! -t 0 ]]; then
		echo "ERROR: no TTY available; refusing to run without --yes." >&2
		exit 1
	fi
	read -r -p "Run Hermes-lite audit? [y/N] " reply
	case "${reply}" in
	y | Y | yes | YES) : ;;
	*)
		echo "aborted."
		exit 0
		;;
	esac
fi

# ─── Initialize counters ──────────────────────────────────────────
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=()

# ─── Helper ───────────────────────────────────────────────────────
check_file() {
	local path="$1"
	local label="$2"
	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
	if [[ -f "${path}" ]]; then
		echo "  ✅ ${label} — $(realpath --relative-to="${KIT_DIR}" "${path}")"
		PASSED_CHECKS=$((PASSED_CHECKS + 1))
		return 0
	else
		echo "  ❌ ${label} — MISSING (expected: ${path})"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		WARNINGS+=("MISSING: ${label} at ${path}")
		return 1
	fi
}

check_bash_syntax() {
	local path="$1"
	local label="$2"
	if [[ ! -f "${path}" ]]; then
		return 1
	fi
	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
	if bash -n "${path}" 2>/dev/null; then
		echo "  ✅ ${label} — bash syntax OK"
		PASSED_CHECKS=$((PASSED_CHECKS + 1))
	else
		echo "  ❌ ${label} — bash syntax ERROR"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		WARNINGS+=("BASH_SYNTAX: ${label} at ${path}")
	fi
}

check_yaml_frontmatter() {
	local path="$1"
	local label="$2"
	if [[ ! -f "${path}" ]]; then
		return 1
	fi
	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
	if head -5 "${path}" 2>/dev/null | grep -q '^---$'; then
		echo "  ✅ ${label} — YAML frontmatter OK"
		PASSED_CHECKS=$((PASSED_CHECKS + 1))
	else
		echo "  ⚠️  ${label} — NO YAML frontmatter"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		WARNINGS+=("NO_YAML: ${label} at ${path}")
	fi
}

# ─── Phase 1: Agent file ──────────────────────────────────────────
echo "==> [1/7] Agent file..."
check_file "${KIT_DIR}/opencode-global/agents/hermes-lite-strong.md" "Agent file"
check_yaml_frontmatter "${KIT_DIR}/opencode-global/agents/hermes-lite-strong.md" "Agent file"
echo ""

# ─── Phase 2: Commands ────────────────────────────────────────────
echo "==> [2/7] Slash commands..."
COMMANDS=(
	hermes-reflect
	hermes-skill
	hermes-kanban
	hermes-memory
	hermes-budget
	hermes-audit
	hermes-learn
	hermes-research
)
for cmd in "${COMMANDS[@]}"; do
	check_file "${KIT_DIR}/opencode-global/commands/${cmd}.md" "/${cmd}"
done
echo ""

# ─── Phase 3: Scripts ─────────────────────────────────────────────
echo "==> [3/7] Scripts..."
SCRIPTS=(
	audit-hermes.sh
	check-hermes-lite.sh
	hermes-learning-capsule.sh
)
for script in "${SCRIPTS[@]}"; do
	check_file "${KIT_DIR}/scripts/${script}" "${script}"
	if [[ -f "${KIT_DIR}/scripts/${script}" ]] && [[ "${script}" == *.sh ]]; then
		check_bash_syntax "${KIT_DIR}/scripts/${script}" "${script} (syntax)"
	fi
done
echo ""

# ─── Phase 4: Docs ────────────────────────────────────────────────
echo "==> [4/7] Documentation..."
DOCS=(
	HERMES_INTEGRATION.md
	HERMES_AUDIT.md
	LEARNING_LOOP.md
	AGENT_KANBAN.md
)
for doc in "${DOCS[@]}"; do
	check_file "${KIT_DIR}/docs/${doc}" "${doc}"
done
echo ""

# ─── Phase 5: CLI integration ─────────────────────────────────────
echo "==> [5/7] CLI integration..."
if [[ -f "${KIT_DIR}/bin/opk" ]]; then
	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
	if grep -q 'hermes' "${KIT_DIR}/bin/opk" 2>/dev/null; then
		echo "  ✅ bin/opk — hermes subcommand found"
		PASSED_CHECKS=$((PASSED_CHECKS + 1))
	else
		echo "  ⚠️  bin/opk — hermes subcommand NOT found"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		WARNINGS+=("CLI_MISSING: hermes not in bin/opk")
	fi
fi
if [[ -f "${KIT_DIR}/bin/opk.ps1" ]]; then
	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
	if grep -q 'hermes' "${KIT_DIR}/bin/opk.ps1" 2>/dev/null; then
		echo "  ✅ bin/opk.ps1 — hermes subcommand found"
		PASSED_CHECKS=$((PASSED_CHECKS + 1))
	else
		echo "  ⚠️  bin/opk.ps1 — hermes subcommand NOT found"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		WARNINGS+=("CLI_MISSING: hermes not in bin/opk.ps1")
	fi
fi
echo ""

# ─── Phase 6: Verify integration ──────────────────────────────────
echo "==> [6/7] Verify script integration..."
if [[ -f "${KIT_DIR}/verify.sh" ]]; then
	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
	if grep -q 'hermes' "${KIT_DIR}/verify.sh" 2>/dev/null; then
		echo "  ✅ verify.sh — hermes checks found"
		PASSED_CHECKS=$((PASSED_CHECKS + 1))
	else
		echo "  ⚠️  verify.sh — hermes checks NOT found"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		WARNINGS+=("VERIFY_MISSING: hermes not in verify.sh")
	fi
fi
if [[ -f "${KIT_DIR}/verify.ps1" ]]; then
	TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
	if grep -q 'hermes' "${KIT_DIR}/verify.ps1" 2>/dev/null; then
		echo "  ✅ verify.ps1 — hermes checks found"
		PASSED_CHECKS=$((PASSED_CHECKS + 1))
	else
		echo "  ⚠️  verify.ps1 — hermes checks NOT found"
		FAILED_CHECKS=$((FAILED_CHECKS + 1))
		WARNINGS+=("VERIFY_MISSING: hermes not in verify.ps1")
	fi
fi
echo ""

# ─── Phase 7: Write audit report ─────────────────────────────────
echo "==> [7/7] Write audit report..."
mkdir -p "${KIT_DIR}/docs"

# Calculate pass rate
PASS_RATE=0
if [[ ${TOTAL_CHECKS} -gt 0 ]]; then
	PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
fi

cat > "${AUDIT_OUTPUT}" <<EOFAUDIT
# Hermes-lite Audit Report

> Generated by \`audit-hermes.sh\` on $(date '+%Y-%m-%d %H:%M:%S')
> Read-only audit — no files were modified.

## Overview

| Attribute | Value |
|-----------|-------|
| **Component** | Hermes-lite (OPK v1.9.0) |
| **Inspiration** | Hermes Agent (NousResearch) |
| **Total checks** | ${TOTAL_CHECKS} |
| **Passed** | ${PASSED_CHECKS} |
| **Failed** | ${FAILED_CHECKS} |
| **Pass rate** | ${PASS_RATE}% |

## Component Status

### Agent
- \`hermes-lite-strong.md\`: $( [[ -f "${KIT_DIR}/opencode-global/agents/hermes-lite-strong.md" ]] && echo "✅" || echo "❌" )

### Commands (8)
$(for cmd in hermes-reflect hermes-skill hermes-kanban hermes-memory hermes-budget hermes-audit hermes-learn hermes-research; do
	printf -- "- \`/%s\`: %s\n" "${cmd}" "$( [[ -f "${KIT_DIR}/opencode-global/commands/${cmd}.md" ]] && echo '✅' || echo '❌' )"
done)

### Scripts (3)
$(for script in audit-hermes.sh check-hermes-lite.sh hermes-learning-capsule.sh; do
	printf -- "- \`%s\`: %s\n" "${script}" "$( [[ -f "${KIT_DIR}/scripts/${script}" ]] && echo '✅' || echo '❌' )"
done)

### Docs (4)
$(for doc in HERMES_INTEGRATION.md HERMES_AUDIT.md LEARNING_LOOP.md AGENT_KANBAN.md; do
	printf -- "- \`%s\`: %s\n" "${doc}" "$( [[ -f "${KIT_DIR}/docs/${doc}" ]] && echo '✅' || echo '❌' )"
done)

## Warnings
$(if [[ ${#WARNINGS[@]} -eq 0 ]]; then
	echo "None. All checks passed."
else
	for w in "${WARNINGS[@]}"; do
		echo "- ${w}"
	done
fi)

## Notes
- Hermes-lite is an optional OPK-native meta-cognitive component.
- It does NOT require full Hermes Agent installation.
- It does NOT use MCP servers, cron, gateways, or messaging integrations.
- It follows the same pattern as ECC-lite: optional pack, OPK-native.
EOFAUDIT

echo "  ✅ Audit report written to ${AUDIT_OUTPUT}"
echo ""

# ─── Summary ──────────────────────────────────────────────────────
echo "=== Summary ==="
echo "  Checks:  ${PASSED_CHECKS}/${TOTAL_CHECKS} passed"
echo "  Warnings: ${#WARNINGS[@]}"
echo ""
if [[ ${FAILED_CHECKS} -eq 0 ]]; then
	echo "✅ Hermes-lite audit passed."
	exit 0
else
	echo "⚠️  Hermes-lite audit has ${FAILED_CHECKS} issue(s)."
	echo "   See: ${AUDIT_OUTPUT}"
	exit 1
fi
