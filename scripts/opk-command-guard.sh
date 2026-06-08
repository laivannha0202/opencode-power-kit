#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# opk-command-guard.sh
# opencode-power-kit v1.5.0
#
# Safety guard: warns or blocks dangerous shell commands.
# Sources in ~/.bashrc or called explicitly before risky ops.
#
# Usage:
#   source scripts/opk-command-guard.sh
#   opk-guard rm -rf /some/path    # will warn/block
#   opk-guard-check "the command string"  # returns 1 if dangerous
#
# The guard NEVER blocks commands that match an allowlist pattern
# (e.g. rm -rf in .opk-trash/ or node_modules/ is safe).
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Config ──────────────────────────────────────────────────────
OPK_GUARD_SKIP="${OPK_GUARD_SKIP:-}"  # set to "1" to bypass all guards

# Allowlist patterns (these are considered safe)
ALLOWLIST_PATTERNS=(
  "rm -rf \./\.opk-trash/"
  "rm -rf \./node_modules/"
  "rm -rf \./\.tmp/"
  "rm -rf \./\.test/"
  "rm -rf \./dist/"
  "rm -rf \./build/"
  "rm -rf \./\.next/"
  "git clean -fd.*--dry-run"
  "git clean -fd.*-n"
  "git diff"
)

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
_fatal() { echo "${RED}${BOLD}✖ BLOCKED${RESET} $*" >&2; exit 1; }

# ─── Check if a command string is dangerous ────────────────────────
opk_guard_check() {
  local cmd="$1"

  # If bypass is set, allow everything
  if [[ "${OPK_GUARD_SKIP}" == "1" ]]; then
    return 0
  fi

  # Check allowlist first
  for pattern in "${ALLOWLIST_PATTERNS[@]}"; do
    if [[ "$cmd" =~ $pattern ]]; then
      return 0
    fi
  done

  # ─── Danger patterns ──────────────────────────────────────────
  local dangerous=0

  # rm -rf (except allowlist)
  if echo "$cmd" | grep -qE '\brm\s+-rf\b'; then
    _warn "rm -rf detected: ${cmd}"
    dangerous=1
  fi

  # git reset --hard
  if echo "$cmd" | grep -qE '\bgit\s+reset\s+--hard\b'; then
    _warn "git reset --hard detected: ${cmd}"
    dangerous=1
  fi

  # git clean -fd (non-dry-run)
  if echo "$cmd" | grep -qE '\bgit\s+clean\s+-fd\b'; then
    _warn "git clean -fd detected: ${cmd}"
    dangerous=1
  fi

  # git push --force
  if echo "$cmd" | grep -qE '\bgit\s+push\s+.*--force\b'; then
    _warn "git push --force detected: ${cmd}"
    dangerous=1
  fi

  # DROP TABLE
  if echo "$cmd" | grep -qiE '\bDROP\s+TABLE\b'; then
    _warn "DROP TABLE detected: ${cmd}"
    dangerous=1
  fi

  # TRUNCATE
  if echo "$cmd" | grep -qiE '\bTRUNCATE\b'; then
    _warn "TRUNCATE detected: ${cmd}"
    dangerous=1
  fi

  # DELETE FROM without WHERE
  if echo "$cmd" | grep -qiE '\bDELETE\s+FROM\b' && ! echo "$cmd" | grep -qiE '\bWHERE\b'; then
    _warn "DELETE FROM without WHERE detected: ${cmd}"
    dangerous=1
  fi

  if [[ $dangerous -eq 1 ]]; then
    return 1
  fi

  return 0
}

# ─── Guard wrapper ─────────────────────────────────────────────────
opk_guard() {
  local cmd="$*"

  if opk_guard_check "$cmd"; then
    eval "$cmd"
  else
    echo -e "\n${RED}${BOLD}This command looks dangerous.${RESET}" >&2
    echo "Command: ${YELLOW}${cmd}${RESET}" >&2
    echo "" >&2
    echo "Options:" >&2
    echo "  1) Skip this guard:   export OPK_GUARD_SKIP=1" >&2
    echo "  2) Rerun the command manually if you're sure." >&2
    echo "" >&2
    exit 1
  fi
}

# ─── If sourced, register as DEBUG trap for interactive shell ─────
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  # Sourced — register a prompt command warning
  opk_guard_prompt() {
    local lastcmd
    lastcmd=$(history 1 | sed 's/^ *[0-9]* *//')
    if [[ -n "$lastcmd" ]]; then
      if ! opk_guard_check "$lastcmd" >/dev/null 2>&1; then
        _warn "Last command was dangerous: ${lastcmd}"
        echo "  Run 'export OPK_GUARD_SKIP=1' to bypass, then re-run." >&2
      fi
    fi
  }
  # PROMPT_COMMAND is additive
  PROMPT_COMMAND="opk_guard_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
fi
