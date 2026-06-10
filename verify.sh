#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# verify.sh
# opencode-power-kit v1.6.6
#
# Sanity-check the power-kit. Runs on every CI run and is also safe
# to run locally: it does not modify anything, it only inspects.
#
# The version it expects to find is read from $KIT_DIR/VERSION.
# If VERSION is missing, the script Warns and still tries to validate
# the rest of the pack — it never aborts on a missing VERSION file.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="${SCRIPT_DIR}"
cd "${KIT_DIR}"

VERSION_FILE="${KIT_DIR}/VERSION"
EXPECTED_VERSION=""
PASS=0
FAIL=0
WARN=0

# ─── Helpers ──────────────────────────────────────────────────────
ok() {
	echo "  ok   $*"
	PASS=$((PASS + 1))
}

fail() {
	echo "  FAIL $*"
	FAIL=$((FAIL + 1))
}

warn() {
	echo "  warn $*"
	WARN=$((WARN + 1))
}

require_file() {
	local path="$1"
	if [[ -f "${path}" ]]; then
		ok "file exists: ${path}"
	else
		fail "missing file: ${path}"
	fi
}

require_dir() {
	local path="$1"
	if [[ -d "${path}" ]]; then
		ok "dir exists:  ${path}"
	else
		fail "missing dir:  ${path}"
	fi
}

require_contains() {
	local path="$1"
	local needle="$2"
	if [[ -f "${path}" ]] && grep -Fiq -- "${needle}" "${path}"; then
		ok "${path} contains: ${needle}"
	else
		fail "${path} missing:  ${needle}"
	fi
}

require_executable() {
	local path="$1"
	if [[ -x "${path}" ]]; then
		ok "executable:    ${path}"
	else
		fail "not executable: ${path}"
	fi
}

# ─── Header ───────────────────────────────────────────────────────
echo "=== opencode-power-kit verify ==="
echo "Repo root: ${KIT_DIR}"
echo

# ─── VERSION ──────────────────────────────────────────────────────
# Read EXPECTED_VERSION from $KIT_DIR/VERSION explicitly.
# If the file is missing, we warn (do not crash) and leave
# EXPECTED_VERSION empty so subsequent checks degrade gracefully.
echo "[VERSION]"
if [[ -f "${VERSION_FILE}" ]]; then
	EXPECTED_VERSION="$(tr -d '[:space:]' <"${VERSION_FILE}")"
	if [[ -n "${EXPECTED_VERSION}" ]]; then
		ok "VERSION file read from ${VERSION_FILE}: ${EXPECTED_VERSION}"
	else
		warn "VERSION file is empty at ${VERSION_FILE}"
	fi
else
	warn "VERSION file missing at ${VERSION_FILE} (continuing without version check)"
fi
echo

# ─── Required files ───────────────────────────────────────────────
echo "[required files]"
require_file "VERSION"
require_file "CHANGELOG.md"
require_file "README.md"
require_file "THIRD_PARTY.md"
require_file "verify.sh"
require_file "verify.ps1"
require_file "opencode-global/agents/build-strong.md"
require_file "opencode-global/agents/architect-strong.md"
require_file "opencode-global/agents/debug-strong.md"
require_file "opencode-global/agents/qa-strong.md"
require_file "opencode-global/agents/security-strong.md"
require_file "opencode-global/agents/db-strong.md"
require_file "opencode-global/agents/api-strong.md"
require_file "opencode-global/agents/ui-ux-strong.md"
require_file "opencode-global/agents/devops-strong.md"
require_file "opencode-global/agents/release-strong.md"
require_file "opencode-global/commands/cleanup-safe.md"
require_file "opencode-global/commands/handoff-save.md"
require_file "opencode-global/commands/checkpoint.md"
require_file "opencode-global/commands/agent-router.md"
require_file "opencode-global/commands/ci-fix.md"
require_file "opencode-global/commands/e2e-flow.md"
require_file "opencode-global/commands/release-check.md"
require_file "opencode-global/commands/kit-audit.md"
require_file "opencode-global/commands/power-build.md"
require_file "opencode-global/commands/tooling-doctor.md"
require_file "scripts/cleanup-agent-artifacts.sh"
require_file "scripts/opk-command-guard.sh"
require_file "scripts/validate-opencode-pack.py"
require_file "scripts/install-gsd-core.sh"
require_file "scripts/install-gsd-core.ps1"
require_file "scripts/install-markitdown.sh"
require_file "scripts/install-markitdown.ps1"
require_file "scripts/install-supermemory.sh"
require_file "scripts/install-supermemory.ps1"
require_file "scripts/install-safety-plugin.sh"
require_file "scripts/install-safety-plugin.ps1"
require_file "bin/opk"
require_file "templates/AGENTS.md"
require_file "templates/OPENCODE.md"
require_file "templates/AI_HANDOFF.md"
require_file "templates/opencode.safe.json"
require_file "templates/opencode.power.json"
require_file "templates/plugins/opk-safety-guard.js"
echo

# ─── Required dirs ────────────────────────────────────────────────
echo "[required directories]"
require_dir "opencode-global"
require_dir "opencode-global/commands"
require_dir "scripts"
require_dir "templates"
require_dir "templates/plugins"
require_dir "bin"
echo

# ─── Executables ──────────────────────────────────────────────────
echo "[executable bits]"
require_executable "verify.sh"
require_executable "scripts/cleanup-agent-artifacts.sh"
require_executable "scripts/validate-opencode-pack.py"
require_executable "scripts/install-gsd-core.sh"
require_executable "scripts/install-markitdown.sh"
require_executable "scripts/install-supermemory.sh"
require_executable "bin/opk"
echo

# ─── Auto Router presence ─────────────────────────────────────────
echo "[Natural Language Auto Router]"
require_contains "templates/AGENTS.md" "Natural Language Auto Router"
require_contains "templates/OPENCODE.md" "Natural Language Auto Router"
echo

# ─── CHANGELOG mentions v1.3.3 / v1.3.4 / v1.4.0 / v1.5.0 / v1.6.0 ──────
echo "[changelog invariants]"
require_contains "CHANGELOG.md" "1.3.3"
require_contains "CHANGELOG.md" "1.3.4"
require_contains "CHANGELOG.md" "1.4.0"
require_contains "CHANGELOG.md" "1.5.0"
require_contains "CHANGELOG.md" "1.6.0"
require_contains "CHANGELOG.md" "1.6.2"
require_contains "CHANGELOG.md" "1.6.3"
require_contains "CHANGELOG.md" "1.6.4"
require_contains "CHANGELOG.md" "Full Auto Permission Mode"
require_contains "CHANGELOG.md" "Vietnamese Language Lock"
require_contains "CHANGELOG.md" "build-strong"
require_contains "CHANGELOG.md" "fullstack-autopilot"
require_contains "CHANGELOG.md" "cleanup-safe"
require_contains "CHANGELOG.md" "handoff-save"
require_contains "CHANGELOG.md" "checkpoint"
require_contains "CHANGELOG.md" "Natural Language Auto Router"
require_contains "CHANGELOG.md" "Backward compatible"
require_contains "CHANGELOG.md" "GSD Core"
require_contains "CHANGELOG.md" "Power Mode"
require_contains "CHANGELOG.md" "architect-strong"
require_contains "CHANGELOG.md" "opk-command-guard"
require_contains "CHANGELOG.md" "Safety & Compatibility Polish"
require_contains "THIRD_PARTY.md" "BMAD"
require_contains "THIRD_PARTY.md" "GSD Core"

# ─── v1.6.0: Full Auto Permission Mode ──────────────────────────
echo "[v1.6.0 Full Auto Permission Mode]"
require_contains "templates/opencode.json" '"permission": "allow"'
require_contains "templates/AGENTS.md" "Full Auto Permission Mode"
require_contains "templates/OPENCODE.md" "Full Auto Permission Mode"
echo

# ─── v1.6.0: Vietnamese Language Lock ───────────────────────────
echo "[v1.6.0 Vietnamese Language Lock]"
require_contains "templates/AGENTS.md" "Vietnamese Language Lock"
require_contains "templates/OPENCODE.md" "Vietnamese Language Lock"
echo

# ─── v1.6.2: Scope Lock — docs-only/read-only scope drift fix ──
echo "[v1.6.2 Scope Lock — docs-only/read-only]"
require_contains "templates/AGENTS.md" "Scope Lock — Docs-only / Read-only"
require_contains "templates/OPENCODE.md" "Scope Lock — Docs-only / Read-only"
require_contains "opencode-global/agents/build-strong.md" "Scope Gate"
require_contains "profiles/node-nest-react-mysql/AGENTS.append.md" "Scope Gate"
require_contains "profiles/node-nest-react-mysql/OPENCODE.append.md" "Scope Gate"

# opencode.json must NOT contain docs/**/*.md
if [[ -f "templates/opencode.json" ]]; then
	if grep -q 'docs/\*\*/\*\.md' "templates/opencode.json"; then
		fail "templates/opencode.json still contains docs/**/*.md in instructions"
	else
		ok "templates/opencode.json does NOT contain docs/**/*.md"
	fi
else
	fail "templates/opencode.json missing"
fi
echo

# ─── v1.6.3: Universal Scope Gate — all strong agents ─────────────
echo "[v1.6.3 Universal Scope Gate — all agents]"
AGENTS_WITH_SCOPE_GATE=(
	"opencode-global/agents/api-strong.md"
	"opencode-global/agents/architect-strong.md"
	"opencode-global/agents/build-strong.md"
	"opencode-global/agents/db-strong.md"
	"opencode-global/agents/debug-strong.md"
	"opencode-global/agents/devops-strong.md"
	"opencode-global/agents/qa-strong.md"
	"opencode-global/agents/release-strong.md"
	"opencode-global/agents/security-strong.md"
	"opencode-global/agents/ui-ux-strong.md"
	"opencode-global/agents/gsd-executor.md"
	"opencode-global/agents/gsd-code-fixer.md"
)
for agent_file in "${AGENTS_WITH_SCOPE_GATE[@]}"; do
	if [[ -f "${agent_file}" ]]; then
		require_contains "${agent_file}" "Scope Gate"
	else
		fail "missing agent: ${agent_file}"
	fi
done
echo

# ─── v1.6.3: Scope Guard — commands ──────────────────────────────
echo "[v1.6.3 Scope Guard — commands]"
COMMANDS_WITH_SCOPE_GUARD=(
	"opencode-global/commands/agent-router.md"
	"opencode-global/commands/power-build.md"
	"opencode-global/commands/ci-fix.md"
	"opencode-global/commands/migration-safe.md"
	"opencode-global/commands/api-contract-review.md"
	"opencode-global/commands/kit-audit.md"
)
for cmd_file in "${COMMANDS_WITH_SCOPE_GUARD[@]}"; do
	if [[ -f "${cmd_file}" ]]; then
		require_contains "${cmd_file}" "Scope Guard"
	else
		fail "missing command: ${cmd_file}"
	fi
done
echo

# ─── v1.6.5: One Command Update & Cleanup ──────────────────────
echo "[v1.6.5 One Command Update & Cleanup]"
require_contains "CHANGELOG.md" "1.6.5"
require_contains "CHANGELOG.md" "1.6.6"
require_contains "CHANGELOG.md" "1.6.7"
require_contains "CHANGELOG.md" "One Command Update & Cleanup"
require_contains "CHANGELOG.md" "opk up"
require_contains "CHANGELOG.md" "opk clean"
# Use bash -n + grep -E (regex mode) since require_contains uses -F (fixed string)
if grep -Eq '^\s*up\|update\|upgrade\)' "bin/opk"; then
	ok "bin/opk has up/update/upgrade case"
else
	fail "bin/opk missing up/update/upgrade case"
fi
if grep -Eq '^\s*clean\)' "bin/opk"; then
	ok "bin/opk has clean case"
else
	fail "bin/opk missing clean case"
fi
require_contains "bin/opk.ps1" "'up'"
require_contains "bin/opk.ps1" "'clean'"
require_contains "bin/opk" "up|update|upgrade"
require_contains "scripts/cleanup-agent-artifacts.sh" "Trash dir"
require_contains "scripts/cleanup-agent-artifacts.sh" "GLOBAL_INSTALL_REPORT"
require_contains "scripts/cleanup-agent-artifacts.sh" "OPK_VERIFY_REPORT"
require_contains "scripts/cleanup-agent-artifacts.sh" "OPK_DOCTOR_REPORT"
require_contains "scripts/cleanup-agent-artifacts.sh" "RELEASE_NOTES_v"
echo

# ─── v1.6.7: Supermemory Memory API ───────────────────────────
echo "[v1.6.7 Supermemory Memory API]"
require_contains "CHANGELOG.md" "1.6.7"
require_contains "CHANGELOG.md" "Supermemory"
require_file "scripts/install-supermemory.sh"
require_file "scripts/install-supermemory.ps1"
require_file "opencode-global/commands/supermemory-init.md"
require_executable "scripts/install-supermemory.sh"
# Script content checks
require_contains "scripts/install-supermemory.sh" "@supermemory/ai"
require_contains "scripts/install-supermemory.sh" "--dry-run"
require_contains "scripts/install-supermemory.sh" "npm install"
require_contains "scripts/install-supermemory.ps1" "@supermemory/ai"
require_contains "scripts/install-supermemory.ps1" "supermemory"
require_contains "opencode-global/commands/supermemory-init.md" "supermemory"
require_contains "opencode-global/commands/supermemory-init.md" "opk supermemory"
# bin/opk commands
require_contains "bin/opk" "supermemory)"
require_contains "bin/opk" "install-supermemory.sh"
require_contains "bin/opk" "supermemory init"
# bin/opk.ps1 commands
require_contains "bin/opk.ps1" "'supermemory'"
require_contains "bin/opk.ps1" "install-supermemory.ps1"
require_contains "bin/opk.ps1" "supermemory init"
# README
require_contains "README.md" "Supermemory"
require_contains "README.md" "supermemory/supermemory"
require_contains "README.md" "opk supermemory"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "Supermemory"
require_contains "THIRD_PARTY.md" "supermemory/supermemory"
echo

# ─── v1.6.6: MarkItDown Document Tools ──────────────────────────
echo "[v1.6.6 MarkItDown Document Tools]"
require_contains "CHANGELOG.md" "1.6.6"
require_contains "CHANGELOG.md" "MarkItDown"
require_file "scripts/install-markitdown.sh"
require_file "scripts/install-markitdown.ps1"
require_file "opencode-global/commands/doc-to-md.md"
require_executable "scripts/install-markitdown.sh"
# Script content checks
require_contains "scripts/install-markitdown.sh" "pipx"
require_contains "scripts/install-markitdown.sh" "markitdown"
require_contains "scripts/install-markitdown.sh" "--dry-run"
require_contains "scripts/install-markitdown.ps1" "pipx"
require_contains "scripts/install-markitdown.ps1" "markitdown"
require_contains "opencode-global/commands/doc-to-md.md" "md-convert"
require_contains "opencode-global/commands/doc-to-md.md" "markitdown"
# bin/opk commands
require_contains "bin/opk" "markitdown)"
require_contains "bin/opk" "md-convert|doc-to-md)"
require_contains "bin/opk" "install-markitdown.sh"
require_contains "bin/opk" "command -v markitdown"
# bin/opk.ps1 commands
require_contains "bin/opk.ps1" "'markitdown'"
require_contains "bin/opk.ps1" "md-convert"
require_contains "bin/opk.ps1" "install-markitdown.ps1"
# README
require_contains "README.md" "MarkItDown"
require_contains "README.md" "microsoft/markitdown"
require_contains "README.md" "md-convert"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "MarkItDown"
require_contains "THIRD_PARTY.md" "microsoft/markitdown"
echo

# ─── v1.6.4: Safety & Compatibility Polish ──────────────────────
echo "[v1.6.4 Safety & Compatibility Polish]"
require_contains "CHANGELOG.md" "Power Mode vs Safe Mode"
require_contains "CHANGELOG.md" "Safety plugin guard"
require_contains "CHANGELOG.md" "opk mode"
require_contains "templates/opencode.safe.json" '"permission":'
require_contains "templates/opencode.power.json" '"permission": "allow"'
require_contains "templates/plugins/opk-safety-guard.js" "guardCheck"
require_contains "bin/opk" "mode)"
require_contains "bin/opk" "safety-plugin)"
require_contains "bin/opk.ps1" "'mode'"
require_contains "bin/opk.ps1" "'safety-plugin'"
echo

# ─── v1.6.0: docs/releases ──────────────────────────────────────
echo "[v1.6.0 release notes]"
require_file "docs/releases/v1.6.0.md"
echo

# ─── build-strong.md content ─────────────────────────────────────
echo "[build-strong agent content]"
require_contains "opencode-global/agents/build-strong.md" "Fullstack-Autopilot"
require_contains "opencode-global/agents/build-strong.md" "Hard Rules"
require_contains "opencode-global/agents/build-strong.md" "vertical slice"
require_contains "opencode-global/agents/build-strong.md" "cleanup-safe"
require_contains "opencode-global/agents/build-strong.md" "Agent Delegation"
echo

# ─── Script sanity (shellcheck optional, syntax required) ─────────
echo "[script sanity]"
SCRIPTS_TO_CHECK=(
	"scripts/cleanup-agent-artifacts.sh"
	"scripts/opk-command-guard.sh"
	"scripts/install-gsd-core.sh"
	"scripts/install-safety-plugin.sh"
	"verify.sh"
)
if [[ -x "bin/opk" ]]; then
	SCRIPTS_TO_CHECK+=("bin/opk")
fi
for s in "${SCRIPTS_TO_CHECK[@]}"; do
	if [[ -f "${s}" ]]; then
		if bash -n "${s}"; then
			ok "bash -n ${s}"
		else
			fail "bash -n failed for ${s}"
		fi
	else
		warn "skip bash -n: ${s} not found"
	fi
done

# shellcheck disable=SC2317
if command -v shellcheck >/dev/null 2>&1; then
	SHELLCHECK_FILES=(
		"scripts/cleanup-agent-artifacts.sh"
		"scripts/opk-command-guard.sh"
		"scripts/install-gsd-core.sh"
		"verify.sh"
	)
	if [[ -x "bin/opk" ]]; then
		SHELLCHECK_FILES+=("bin/opk")
	fi
	if shellcheck "${SHELLCHECK_FILES[@]}"; then
		ok "shellcheck clean"
	else
		fail "shellcheck found issues (see above)"
	fi
else
	echo "  skip shellcheck (not installed)"
fi
echo

# ─── PowerShell parser (optional) ────────────────────────────────
echo "[powershell parser]"
if command -v pwsh >/dev/null 2>&1; then
	PS_FILES=(
		"verify.ps1"
		"scripts/install-gsd-core.ps1"
	)
	for ps in "${PS_FILES[@]}"; do
		if [[ -f "${ps}" ]]; then
			if pwsh -NoProfile -Command "
				\$errs = \$null
				[System.Management.Automation.Language.Parser]::ParseFile('${ps}', [ref]\$null, [ref]\$errs) | Out-Null
				if (\$errs) { exit 1 } else { exit 0 }
			" >/dev/null 2>&1; then
				ok "pwsh parser ${ps}"
			else
				fail "pwsh parser failed for ${ps}"
			fi
		else
			warn "skip pwsh parser: ${ps} not found"
		fi
	done
else
	echo "  skip pwsh parser (pwsh not installed)"
fi
echo

# ─── Python validator (run if present) ────────────────────────────
echo "[python validator]"
if [[ -f "scripts/validate-opencode-pack.py" ]]; then
	if command -v python3 >/dev/null 2>&1; then
		if python3 "scripts/validate-opencode-pack.py"; then
			ok "python3 validate-opencode-pack.py"
		else
			fail "python3 validate-opencode-pack.py failed"
		fi
	else
		echo "  skip python validator (python3 not installed)"
	fi
else
	fail "scripts/validate-opencode-pack.py missing"
fi
echo

# ─── Summary ──────────────────────────────────────────────────────
echo "=== summary ==="
echo "passed: ${PASS}"
echo "failed: ${FAIL}"
echo "warned: ${WARN}"

if [[ ${FAIL} -gt 0 ]]; then
	echo "RESULT: FAIL"
	exit 1
fi
echo "RESULT: PASS"
exit 0
