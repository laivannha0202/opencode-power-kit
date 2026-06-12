#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# check-taste-skill.sh
# opencode-power-kit v1.7.0
#
# Read-only check: detect Taste Skill installation.
# No network calls, no modifications, no prompts.
#
# Exit codes:
#   0 = installed
#   1 = not installed (or partial)
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# Check 1: skill directory exists
if [[ -d "${HOME}/.config/opencode/skills/taste-skill" ]] &&
	[[ -f "${HOME}/.config/opencode/skills/taste-skill/SKILL.md" ]]; then
	echo "✅ Taste Skill installed at: ${HOME}/.config/opencode/skills/taste-skill/"
	exit 0
fi

# Check 2: taste-skill command on PATH (less common but valid)
if command -v taste-skill >/dev/null 2>&1; then
	echo "✅ taste-skill command found on PATH: $(command -v taste-skill)"
	exit 0
fi

# Not installed
echo "❌ Taste Skill not installed."
echo "   Expected: ${HOME}/.config/opencode/skills/taste-skill/"
echo "   Install:  opk taste install"
exit 1
