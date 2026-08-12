#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# opk-command-guard.sh
# opencode-power-kit v2.2.0
#
# Safety guard: warns or blocks dangerous shell commands.
# Thin wrapper around the shared rule engine (scripts/guard-rules.sh).
# Sources in ~/.bashrc or called explicitly before risky ops.
#
# Usage:
#   source scripts/opk-command-guard.sh
#   opk-guard rm -rf /some/path        # will warn/block
#   opk-guard-check "the command string"  # returns 1 if dangerous
#
# The guard NEVER bypasses on an allowlist or env var — a bypassable
# guard is no guard at all.
# ─────────────────────────────────────────────────────────────────

[[ -n "${_OPK_GUARD_WRAPPER:-}" ]] && return 0
_OPK_GUARD_WRAPPER=1

_OPK_GUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=guard-rules.sh
. "$_OPK_GUARD_DIR/guard-rules.sh"

# ─── Color ───────────────────────────────────────────────────────
if [[ -t 2 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
	RED=$(tput setaf 1)
	YELLOW=$(tput setaf 3)
	BOLD=$(tput bold)
	RESET=$(tput sgr0)
else
	RED=""
	YELLOW=""
	BOLD=""
	RESET=""
fi

# ─── Helpers ─────────────────────────────────────────────────────
_warn() { echo "${YELLOW}⚠ WARN${RESET} $*" >&2; }
_fatal() {
	echo "${RED}${BOLD}✖ BLOCKED${RESET} $*" >&2
	exit 1
}

# ─── Check if a command string is dangerous ────────────────────────
# Returns 0 if safe, 1 if dangerous. Never prints (use opk-guard for UI).
opk_guard_check() {
	local cmd="$1"
	OPK_GUARD_SILENT=1 opk_guard_scan "$cmd"
}

# ─── Guard wrapper ─────────────────────────────────────────────────
opk_guard() {
	local cmd="$*"

	if OPK_GUARD_SILENT=1 opk_guard_scan "$cmd"; then
		eval "$cmd"
	else
		echo -e "\n${RED}${BOLD}This command looks dangerous.${RESET}" >&2
		echo "Command: ${YELLOW}${cmd}${RESET}" >&2
		echo "Reason:  ${_opk_guard_violation:-unknown}" >&2
		echo "" >&2
		echo "Options:" >&2
		echo "  1) Rerun the command manually if you're sure." >&2
		echo "" >&2
		exit 1
	fi
}

# ─── If sourced, register a prompt warning for interactive shells ──
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
	opk_guard_prompt() {
		local lastcmd
		lastcmd=$(history 1 | sed 's/^ *[0-9]* *//')
		if [[ -n "$lastcmd" ]]; then
			if ! opk_guard_check "$lastcmd"; then
				_warn "Last command was dangerous: ${lastcmd}"
			fi
		fi
	}
	# PROMPT_COMMAND is additive
	PROMPT_COMMAND="opk_guard_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
