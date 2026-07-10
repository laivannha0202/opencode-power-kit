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
require_file "scripts/audit-ecc.sh"
require_file "scripts/install-ecc-lite.sh"
require_file "scripts/check-ecc-lite.sh"
require_file "opencode-global/agents/ecc-lite-strong.md"
require_file "opencode-global/commands/ecc-audit.md"
require_file "opencode-global/commands/quality-gate.md"
require_file "opencode-global/commands/research-first.md"
require_file "opencode-global/commands/verify-loop.md"
require_file "opencode-global/commands/model-route-review.md"
require_file "opencode-global/commands/harness-audit.md"
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
require_executable "scripts/audit-ecc.sh"
require_executable "scripts/install-ecc-lite.sh"
require_executable "scripts/check-ecc-lite.sh"
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
require_contains "templates/opencode.json" '"permission"'
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
	# v2.1.0: GSD agents moved to extras/gsd-agent-reference/
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
require_contains "scripts/install-supermemory.sh" "supermemory"
require_contains "scripts/install-supermemory.sh" "--dry-run"
require_contains "scripts/install-supermemory.sh" "npm install"
require_contains "scripts/install-supermemory.ps1" "supermemory"
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

# ─── v1.7.0: Taste Skill ─────────────────────────────────────────
echo "[v1.7.0 Taste Skill]"
# CHANGELOG
require_contains "CHANGELOG.md" "1.7.0"
require_contains "CHANGELOG.md" "Taste Skill"
# Script files
require_file "scripts/install-taste-skill.sh"
require_file "scripts/install-taste-skill.ps1"
require_file "scripts/check-taste-skill.sh"
require_file "scripts/check-taste-skill.ps1"
require_executable "scripts/install-taste-skill.sh"
require_executable "scripts/check-taste-skill.sh"
# Agent / command files
require_file "opencode-global/agents/taste-ui-strong.md"
# Script content checks
require_contains "scripts/install-taste-skill.sh" "taste-skill"
require_contains "scripts/install-taste-skill.sh" "npx"
require_contains "scripts/install-taste-skill.ps1" "taste-skill"
require_contains "scripts/install-taste-skill.ps1" "npx"
require_contains "scripts/check-taste-skill.sh" "taste-skill"
require_contains "scripts/check-taste-skill.ps1" "taste-skill"
# bin/opk commands
require_contains "bin/opk" "taste|taste-status|taste-off|update-taste)"
require_contains "bin/opk" "taste install"
require_contains "bin/opk" "taste status"
require_contains "bin/opk" "taste off"
require_contains "bin/opk" "update-taste"
# bin/opk.ps1 commands
require_contains "bin/opk.ps1" "'taste'"
require_contains "bin/opk.ps1" "taste install"
require_contains "bin/opk.ps1" "taste status"
require_contains "bin/opk.ps1" "taste off"
require_contains "bin/opk.ps1" "update-taste"
# Agent routing
require_contains "opencode-global/agents/build-strong.md" "taste-ui-strong"
require_contains "opencode-global/commands/agent-router.md" "taste-ui-strong"
# README
require_contains "README.md" "Taste Skill"
require_contains "README.md" "Leonxlnx/taste-skill"
require_contains "README.md" "opk taste"
require_contains "README.md" "taste-ui-strong"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "Taste Skill"
require_contains "THIRD_PARTY.md" "Leonxlnx"
echo

# ─── v1.8.0: ECC-lite (Engineering Code Commandments) ─────────────
echo "[v1.8.0 ECC-lite]"
# CHANGELOG
require_contains "CHANGELOG.md" "1.8.0"
require_contains "CHANGELOG.md" "ECC-lite"
require_contains "CHANGELOG.md" "Engineering Code Commandments"
# Script files
require_file "scripts/audit-ecc.sh"
require_file "scripts/install-ecc-lite.sh"
require_file "scripts/check-ecc-lite.sh"
require_executable "scripts/audit-ecc.sh"
require_executable "scripts/install-ecc-lite.sh"
require_executable "scripts/check-ecc-lite.sh"
# Agent / command files
require_file "opencode-global/agents/ecc-lite-strong.md"
require_file "opencode-global/commands/ecc-audit.md"
require_file "opencode-global/commands/quality-gate.md"
require_file "opencode-global/commands/research-first.md"
require_file "opencode-global/commands/verify-loop.md"
require_file "opencode-global/commands/model-route-review.md"
require_file "opencode-global/commands/harness-audit.md"
# Script content checks
require_contains "scripts/audit-ecc.sh" "ECC"
require_contains "scripts/install-ecc-lite.sh" "ecc-lite"
require_contains "scripts/install-ecc-lite.sh" "OPENCODE_CONFIG_DIR"
require_contains "scripts/check-ecc-lite.sh" "ecc-lite"
require_contains "scripts/check-ecc-lite.sh" "OPENCODE_CONFIG_DIR"
require_contains "opencode-global/agents/ecc-lite-strong.md" "ECC-lite"
# bin/opk commands
require_contains "bin/opk" "ec|e|ecc)"
require_contains "bin/opk" "ecc audit"
require_contains "bin/opk" "ecc lite"
require_contains "bin/opk" "ecc status"
require_contains "bin/opk" "ecc off"
require_contains "bin/opk" "OPENCODE_CONFIG_DIR"
require_contains "bin/opk" "update-ecc)"
# bin/opk.ps1 commands
require_contains "bin/opk.ps1" "'ec','e','ecc'"
require_contains "bin/opk.ps1" "ecc audit"
require_contains "bin/opk.ps1" "ecc lite"
require_contains "bin/opk.ps1" "ecc status"
require_contains "bin/opk.ps1" "ecc off"
require_contains "bin/opk.ps1" "update-ecc"
# README
require_contains "README.md" "ECC-lite"
require_contains "README.md" "ecc-lite-strong"
# ECC_INTEGRATION doc
require_file "docs/ECC_INTEGRATION.md"
require_contains "docs/ECC_INTEGRATION.md" "ECC-lite"
require_contains "docs/ECC_INTEGRATION.md" "What is ECC?"
require_contains "docs/ECC_INTEGRATION.md" "Why not full ECC?"
require_contains "docs/ECC_INTEGRATION.md" "Safety Guarantees"
# Command frontmatter checks — subtask: true, no subtask: admin
for ecc_cmd in ecc-audit quality-gate research-first verify-loop model-route-review harness-audit; do
	require_contains "opencode-global/commands/${ecc_cmd}.md" "subtask: true"
	if rg "subtask: admin" "opencode-global/commands/${ecc_cmd}.md" >/dev/null 2>&1; then
		fail "opencode-global/commands/${ecc_cmd}.md must NOT contain subtask: admin"
	fi
done
# Agent frontmatter checks
require_contains "opencode-global/agents/ecc-lite-strong.md" "mode: all"
if rg "subtask: admin" "opencode-global/agents/ecc-lite-strong.md" >/dev/null 2>&1; then
	fail "opencode-global/agents/ecc-lite-strong.md must NOT contain subtask: admin"
fi
# Script --help flags
require_contains "scripts/audit-ecc.sh" "--help"
require_contains "scripts/install-ecc-lite.sh" "--help"
require_contains "scripts/check-ecc-lite.sh" "--help"
# No auto-enable in bootstrap / install-global
if rg -q "ecc" "scripts/bootstrap.sh" 2>/dev/null; then
	fail "bootstrap.sh must NOT auto-enable ECC"
fi
if rg -q "ecc" "scripts/install-global.sh" 2>/dev/null; then
	fail "install-global.sh must NOT auto-enable ECC"
fi
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "ECC"
require_contains "THIRD_PARTY.md" "affaan-m"
echo

# ─── v1.9.0: Hermes-lite (meta-cognitive self-improvement) ─────────
echo "[v1.9.0 Hermes-lite]"
# CHANGELOG
require_contains "CHANGELOG.md" "1.9.0"
require_contains "CHANGELOG.md" "Hermes-lite"
require_contains "CHANGELOG.md" "NousResearch"
# Agent file
require_file "opencode-global/agents/hermes-lite-strong.md"
require_contains "opencode-global/agents/hermes-lite-strong.md" "Hermes-lite"
require_contains "opencode-global/agents/hermes-lite-strong.md" "mode: all"
# Script files
require_file "scripts/audit-hermes.sh"
require_file "scripts/check-hermes-lite.sh"
require_file "scripts/hermes-learning-capsule.sh"
require_executable "scripts/audit-hermes.sh"
require_executable "scripts/check-hermes-lite.sh"
require_executable "scripts/hermes-learning-capsule.sh"
# Script content checks
require_contains "scripts/audit-hermes.sh" "hermes"
require_contains "scripts/check-hermes-lite.sh" "hermes-lite"
require_contains "scripts/hermes-learning-capsule.sh" "hermes"
# Commands (8)
for hermes_cmd in hermes-reflect hermes-skill hermes-kanban hermes-memory hermes-budget hermes-audit hermes-learn hermes-research; do
	require_file "opencode-global/commands/${hermes_cmd}.md"
done
# bin/opk commands
require_contains "bin/opk" "hermes|hermes-status|hermes-off)"
require_contains "bin/opk" "hermes audit"
require_contains "bin/opk" "hermes status"
require_contains "bin/opk" "hermes capsule"
require_contains "bin/opk" "hermes off"
# bin/opk.ps1 commands
require_contains "bin/opk.ps1" "'hermes'"
require_contains "bin/opk.ps1" "hermes audit"
require_contains "bin/opk.ps1" "hermes status"
require_contains "bin/opk.ps1" "hermes capsule"
require_contains "bin/opk.ps1" "hermes off"
# Docs
require_file "docs/HERMES_INTEGRATION.md"
require_file "docs/HERMES_AUDIT.md"
require_file "docs/LEARNING_LOOP.md"
require_file "docs/AGENT_KANBAN.md"
require_contains "docs/HERMES_INTEGRATION.md" "Hermes-lite"
require_contains "docs/LEARNING_LOOP.md" "Learning Loop"
require_contains "docs/AGENT_KANBAN.md" "Kanban"
# README
require_contains "README.md" "Hermes-lite"
require_contains "README.md" "NousResearch"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "Hermes"
require_contains "THIRD_PARTY.md" "NousResearch"
# No auto-enable in bootstrap / install-global / setup
if rg -q "hermes" "bootstrap.sh" 2>/dev/null; then
	fail "bootstrap.sh must NOT auto-enable Hermes-lite"
fi
if rg -q "hermes" "install-global.sh" 2>/dev/null; then
	fail "install-global.sh must NOT auto-enable Hermes-lite"
fi
if rg -q "hermes" "setup.sh" 2>/dev/null; then
	fail "setup.sh must NOT auto-enable Hermes-lite"
fi
# No subtask: admin on agent
if rg "subtask: admin" "opencode-global/agents/hermes-lite-strong.md" >/dev/null 2>&1; then
	fail "opencode-global/agents/hermes-lite-strong.md must NOT contain subtask: admin"
fi
# Build-strong and agent-router integration
require_contains "opencode-global/agents/build-strong.md" "hermes-lite-strong"
require_contains "opencode-global/commands/agent-router.md" "hermes-lite-strong"
echo

# ─── v1.9.1: RAG-lite (Retrieval-Augmented Generation reference) ──
echo "[v1.9.1 RAG-lite]"
# CHANGELOG
require_contains "CHANGELOG.md" "1.9.1"
require_contains "CHANGELOG.md" "RAG-lite"
require_contains "CHANGELOG.md" "NirDiamant"
# Doc
require_file "docs/RAG_LITE_INTEGRATION.md"
require_contains "docs/RAG_LITE_INTEGRATION.md" "RAG"
# Skill
require_file "opencode-global/skills/rag-lite/SKILL.md"
require_contains "opencode-global/skills/rag-lite/SKILL.md" "RAG"
require_contains "opencode-global/skills/rag-lite/SKILL.md" "rag-"
# Commands (3)
for rag_cmd in rag-plan rag-audit rag-eval; do
	require_file "opencode-global/commands/${rag_cmd}.md"
done
require_contains "opencode-global/commands/rag-plan.md" "RAG"
require_contains "opencode-global/commands/rag-audit.md" "RAG"
require_contains "opencode-global/commands/rag-eval.md" "RAG"
# README
require_contains "README.md" "RAG-lite"
require_contains "README.md" "NirDiamant"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "RAG_Techniques"
require_contains "THIRD_PARTY.md" "NirDiamant"
# No auto-enable in bootstrap / install-global / setup
if rg -q "rag-lite" "bootstrap.sh" 2>/dev/null; then
	fail "bootstrap.sh must NOT auto-enable RAG-lite"
fi
if rg -q "rag-lite" "install-global.sh" 2>/dev/null; then
	fail "install-global.sh must NOT auto-enable RAG-lite"
fi
if rg -q "rag-lite" "setup.sh" 2>/dev/null; then
	fail "setup.sh must NOT auto-enable RAG-lite"
fi
# Build-strong and agent-router integration
require_contains "opencode-global/agents/build-strong.md" "rag-"
require_contains "opencode-global/commands/agent-router.md" "rag-plan"
echo

# ─── v1.9.3: AgentMemory-lite (Serverless Memory reference) ──
echo "[v1.9.3 AgentMemory-lite]"
# CHANGELOG
require_contains "CHANGELOG.md" "1.9.3"
require_contains "CHANGELOG.md" "AgentMemory-lite"
require_contains "CHANGELOG.md" "rohitg00"
# Doc
require_file "docs/AGENTMEMORY_LITE_INTEGRATION.md"
require_contains "docs/AGENTMEMORY_LITE_INTEGRATION.md" "AgentMemory-lite"
require_contains "docs/AGENTMEMORY_LITE_INTEGRATION.md" "memory"
# Skill
require_file "opencode-global/skills/agentmemory-lite/SKILL.md"
require_contains "opencode-global/skills/agentmemory-lite/SKILL.md" "AgentMemory-lite"
require_contains "opencode-global/skills/agentmemory-lite/SKILL.md" "memory-"
# Commands (3)
for am_cmd in memory-plan memory-audit memory-handoff; do
	require_file "opencode-global/commands/${am_cmd}.md"
done
require_contains "opencode-global/commands/memory-plan.md" "memory"
require_contains "opencode-global/commands/memory-audit.md" "audit"
require_contains "opencode-global/commands/memory-handoff.md" "handoff"
# README
require_contains "README.md" "AgentMemory-lite"
require_contains "README.md" "rohitg00"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "agentmemory"
require_contains "THIRD_PARTY.md" "rohitg00"
# No auto-enable in bootstrap / install-global / setup
if rg -q "agentmemory-lite" "bootstrap.sh" 2>/dev/null; then
	fail "bootstrap.sh must NOT auto-enable AgentMemory-lite"
fi
if rg -q "agentmemory-lite" "install-global.sh" 2>/dev/null; then
	fail "install-global.sh must NOT auto-enable AgentMemory-lite"
fi
if rg -q "agentmemory-lite" "setup.sh" 2>/dev/null; then
	fail "setup.sh must NOT auto-enable AgentMemory-lite"
fi
# Build-strong and agent-router integration
require_contains "opencode-global/agents/build-strong.md" "agentmemory-lite"
require_contains "opencode-global/commands/agent-router.md" "memory-plan"
echo

# ─── v1.9.2: Headroom-lite (Context/Token Compression reference) ──
echo "[v1.9.2 Headroom-lite]"
# CHANGELOG
require_contains "CHANGELOG.md" "1.9.2"
require_contains "CHANGELOG.md" "Headroom-lite"
require_contains "CHANGELOG.md" "chopratejas"
# Doc
require_file "docs/HEADROOM_LITE_INTEGRATION.md"
require_contains "docs/HEADROOM_LITE_INTEGRATION.md" "Headroom-lite"
require_contains "docs/HEADROOM_LITE_INTEGRATION.md" "compression"
# Skill
require_file "opencode-global/skills/headroom-lite/SKILL.md"
require_contains "opencode-global/skills/headroom-lite/SKILL.md" "Headroom-lite"
require_contains "opencode-global/skills/headroom-lite/SKILL.md" "headroom-"
# Commands (3)
for headroom_cmd in headroom-plan headroom-audit headroom-status; do
	require_file "opencode-global/commands/${headroom_cmd}.md"
done
require_contains "opencode-global/commands/headroom-plan.md" "compression"
require_contains "opencode-global/commands/headroom-audit.md" "audit"
require_contains "opencode-global/commands/headroom-status.md" "status"
# README
require_contains "README.md" "Headroom-lite"
require_contains "README.md" "chopratejas"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "chopratejas"
require_contains "THIRD_PARTY.md" "headroom"
# No auto-enable in bootstrap / install-global / setup
if rg -q "headroom-lite" "bootstrap.sh" 2>/dev/null; then
	fail "bootstrap.sh must NOT auto-enable Headroom-lite"
fi
if rg -q "headroom-lite" "install-global.sh" 2>/dev/null; then
	fail "install-global.sh must NOT auto-enable Headroom-lite"
fi
if rg -q "headroom-lite" "setup.sh" 2>/dev/null; then
	fail "setup.sh must NOT auto-enable Headroom-lite"
fi
# Build-strong and agent-router integration
require_contains "opencode-global/agents/build-strong.md" "headroom-lite"
require_contains "opencode-global/commands/agent-router.md" "headroom-plan"
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
require_contains "templates/opencode.power.json" '"permission"'
require_contains "templates/plugins/opk-safety-guard.js" "tool.execute.before"
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

# ─── v2.0.0: OPK Orchestration Lite ──────────────────────────────
echo "[v2.0.0 OPK Orchestration Lite]"
# CHANGELOG
require_contains "CHANGELOG.md" "2.0.0"
require_contains "CHANGELOG.md" "OPK Orchestration Lite"
require_contains "CHANGELOG.md" "oh-my-openagent"
require_contains "CHANGELOG.md" "intent-router"
require_contains "CHANGELOG.md" "power-work-lite"
require_contains "CHANGELOG.md" "continue-work"
require_contains "CHANGELOG.md" "evidence-report"
require_contains "CHANGELOG.md" "init-deep-lite"
require_contains "CHANGELOG.md" "no MCP"
require_contains "CHANGELOG.md" "no telemetry"
# VERSION
require_contains "VERSION" "2.1.0"
# New commands (5)
require_file "opencode-global/commands/intent-router.md"
require_file "opencode-global/commands/init-deep-lite.md"
require_file "opencode-global/commands/power-work-lite.md"
require_file "opencode-global/commands/continue-work.md"
require_file "opencode-global/commands/evidence-report.md"
# Command content checks
require_contains "opencode-global/commands/intent-router.md" "intent"
require_contains "opencode-global/commands/intent-router.md" "agent"
require_contains "opencode-global/commands/power-work-lite.md" "power-work-lite"
require_contains "opencode-global/commands/power-work-lite.md" "verify"
require_contains "opencode-global/commands/continue-work.md" "AI_HANDOFF"
require_contains "opencode-global/commands/evidence-report.md" "evidence"
require_contains "opencode-global/commands/init-deep-lite.md" "AGENTS.md"
# Documentation (2)
require_file "docs/OPK_ORCHESTRATION_LITE.md"
require_file "docs/INSPIRATION_OH_MY_OPENAGENT.md"
require_contains "docs/OPK_ORCHESTRATION_LITE.md" "Orchestration Lite"
require_contains "docs/INSPIRATION_OH_MY_OPENAGENT.md" "oh-my-openagent"
# README
require_contains "README.md" "OPK Orchestration Lite"
require_contains "README.md" "intent-router"
require_contains "README.md" "power-work-lite"
require_contains "README.md" "continue-work"
require_contains "README.md" "evidence-report"
require_contains "README.md" "init-deep-lite"
require_contains "README.md" "oh-my-openagent"
require_contains "README.md" "v2.0.0"
# THIRD_PARTY
require_contains "THIRD_PARTY.md" "oh-my-openagent"
require_contains "THIRD_PARTY.md" "code-yeongyu"
require_contains "THIRD_PARTY.md" "Inspiration-only"
# .gitignore
require_contains ".gitignore" ".opk/work/"
require_contains ".gitignore" ".opk/tmp/"
require_contains ".gitignore" ".opk/cache/"
# No MCP auto-enabled
if grep -rE '"mcp"\s*:' "templates/" 2>/dev/null; then
	fail "MCP config detected in templates/ (should not be auto-enabled)"
else
	ok "no MCP auto-enabled in templates/"
fi
# No telemetry
if grep -rEi 'posthog|mixpanel|amplitude|segment\.io|heap\.io' "opencode-global/" --include='*.md' --include='*.json' --include='*.js' --exclude-dir='node_modules' 2>/dev/null; then
	fail "telemetry patterns detected in opencode-global/"
else
	ok "no telemetry in opencode-global/"
fi
# oh-my-openagent not vendored
if [ -d "node_modules/oh-my-openagent" ] || [ -d "vendor/oh-my-openagent" ]; then
	fail "oh-my-openagent appears vendored"
else
	ok "oh-my-openagent not vendored"
fi

# ─── v2.0.0: CLI Expansion & Taste verify-gated ──────────────────
echo "[v2.0.0 CLI Expansion]"
# bin/opk subcommands
require_contains "bin/opk" "upstream)"
require_contains "bin/opk" "upstream audit"
require_contains "bin/opk" "upstream doctor"
require_contains "bin/opk" "superpowers)"
require_contains "bin/opk" "superpowers status"
require_contains "bin/opk" "superpowers reset-cache"
require_contains "bin/opk" "superpowers doctor"
require_contains "bin/opk" "bmad)"
require_contains "bin/opk" "bmad status"
require_contains "bin/opk" "bmad update"
require_contains "bin/opk" "tooling)"
require_contains "bin/opk" "tooling doctor"
require_contains "bin/opk" "taste doctor"
require_contains "bin/opk" "taste install --v1"
require_contains "bin/opk" "taste install --v2"
# bin/opk.ps1 parity
require_contains "bin/opk.ps1" "'upstream'"
require_contains "bin/opk.ps1" "upstream audit"
require_contains "bin/opk.ps1" "upstream doctor"
require_contains "bin/opk.ps1" "'superpowers'"
require_contains "bin/opk.ps1" "superpowers status"
require_contains "bin/opk.ps1" "superpowers reset-cache"
require_contains "bin/opk.ps1" "superpowers doctor"
require_contains "bin/opk.ps1" "'bmad'"
require_contains "bin/opk.ps1" "bmad status"
require_contains "bin/opk.ps1" "bmad update"
require_contains "bin/opk.ps1" "'tooling'"
require_contains "bin/opk.ps1" "tooling doctor"
require_contains "bin/opk.ps1" "taste doctor"

echo "[v2.0.0 Taste verify-gated]"
require_contains "README.md" "verify-gated"
require_contains "README.md" "opk taste install --v1"
require_contains "README.md" "opk taste doctor"
require_contains "THIRD_PARTY.md" "verify-gated"
require_contains "THIRD_PARTY.md" "user-installed"
require_contains "CHANGELOG.md" "Verify-gated"
require_contains "CHANGELOG.md" "CLI Expansion"

# Taste safe removal (no rm -rf)
if grep -A5 "taste-off)" "bin/opk" | grep -v "^[[:space:]]*#" | grep -q "rm -rf"; then
	fail "bin/opk taste-off uses rm -rf (should use mv to .opk-trash/)"
else
	ok "bin/opk taste-off uses safe removal"
fi

echo "[v2.0.0 Taste auto-install removed from global scripts]"
# install-global.sh must NOT call install-taste-skill.sh --yes
if grep -q "install-taste-skill.sh.*--yes" "install-global.sh"; then
	fail "install-global.sh still calls install-taste-skill.sh --yes (auto-install must be removed)"
else
	ok "install-global.sh: no Taste auto-install call"
fi
# install-global.ps1 must NOT call install-taste-skill.ps1 -Yes
if grep -q "install-taste-skill.ps1.*-Yes" "install-global.ps1"; then
	fail "install-global.ps1 still calls install-taste-skill.ps1 -Yes (auto-install must be removed)"
else
	ok "install-global.ps1: no Taste auto-install call"
fi
# install-global must have suggestion hint
require_contains "install-global.sh" "opk taste install"
require_contains "install-global.ps1" "opk taste install"
# UPSTREAM_AUDIT must not contain auto-enabled-dependency
if grep -q "auto-enabled-dependency" "docs/UPSTREAM_AUDIT.md"; then
	fail "docs/UPSTREAM_AUDIT.md still contains 'auto-enabled-dependency'"
else
	ok "docs/UPSTREAM_AUDIT.md: no 'auto-enabled-dependency'"
fi
# No current-state auto-enabled wording in README/THIRD_PARTY
if grep -q "Taste Skill is automatically enabled" "README.md" "THIRD_PARTY.md" 2>/dev/null; then
	fail "README.md or THIRD_PARTY.md contains 'Taste Skill is automatically enabled'"
else
	ok "No current-state 'Taste Skill is automatically enabled' wording"
fi

echo

# ─── v2.0.0: Permission hardening & audit report consistency ──────
echo "[v2.0.0 Permission & Audit Report Checks]"

# Default template must NOT have bare "permission": "allow"
if grep -q '"permission": "allow"' "templates/opencode.json"; then
	fail 'templates/opencode.json still has bare "permission": "allow"'
else
	ok 'templates/opencode.json: no bare "permission": "allow"'
fi

# UPSTREAM_AUDIT.md must not have absolute local paths
if grep -q '/home/' "docs/UPSTREAM_AUDIT.md" 2>/dev/null || grep -q '/Users/' "docs/UPSTREAM_AUDIT.md" 2>/dev/null || grep -q "C:\\" "docs/UPSTREAM_AUDIT.md" 2>/dev/null; then
	fail "docs/UPSTREAM_AUDIT.md contains absolute local path"
else
	ok "docs/UPSTREAM_AUDIT.md: no absolute local paths"
fi

# audit-upstreams.py must have --root, --check, --write
if python3 scripts/audit-upstreams.py --help 2>&1 | grep -q '\-\-root'; then
	ok "audit-upstreams.py has --root flag"
else
	fail "audit-upstreams.py missing --root flag"
fi
if python3 scripts/audit-upstreams.py --help 2>&1 | grep -q '\-\-check'; then
	ok "audit-upstreams.py has --check flag"
else
	fail "audit-upstreams.py missing --check flag"
fi
if python3 scripts/audit-upstreams.py --help 2>&1 | grep -q '\-\-write'; then
	ok "audit-upstreams.py has --write flag"
else
	fail "audit-upstreams.py missing --write flag"
fi

# audit-upstreams.py --check must NOT fail just because refs exist
# (it should only fail for report consistency issues)
if python3 scripts/audit-upstreams.py --check 2>&1 | grep -q "PASS"; then
	ok "audit-upstreams.py --check passes (does not fail on upstream refs)"
else
	fail "audit-upstreams.py --check should pass when report is consistent"
fi

echo

# ─── Script sanity (shellcheck optional, syntax required) ─────────
echo "[script sanity]"
SCRIPTS_TO_CHECK=(
	"scripts/cleanup-agent-artifacts.sh"
	"scripts/opk-command-guard.sh"
	"scripts/install-gsd-core.sh"
	"scripts/install-safety-plugin.sh"
	"scripts/audit-ecc.sh"
	"scripts/install-ecc-lite.sh"
	"scripts/check-ecc-lite.sh"
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
		"bin/opk.ps1"
		"install-global.ps1"
		"bootstrap.ps1"
		"setup.ps1"
		"install.ps1"
		"update-bmad.ps1"
		"scripts/install-gsd-core.ps1"
		"scripts/install-markitdown.ps1"
		"scripts/install-supermemory.ps1"
		"scripts/install-taste-skill.ps1"
		"scripts/check-taste-skill.ps1"
		"scripts/install-safety-plugin.ps1"
		"scripts/install-fullstack-profile.ps1"
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

# ─── Formatting guard (run if present) ────────────────────────────
echo "[formatting guard]"
if [[ -f "scripts/validate-formatting.py" ]]; then
	if command -v python3 >/dev/null 2>&1; then
		if python3 "scripts/validate-formatting.py"; then
			ok "python3 validate-formatting.py"
		else
			fail "python3 validate-formatting.py failed"
		fi
	else
		echo "  skip formatting guard (python3 not installed)"
	fi
else
	warn "scripts/validate-formatting.py missing"
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
