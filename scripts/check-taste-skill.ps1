# ─────────────────────────────────────────────────────────────────
# check-taste-skill.ps1
# opencode-power-kit v1.7.0
#
# PowerShell mirror of scripts/check-taste-skill.sh.
#
# Read-only check: detect Taste Skill installation.
# No network calls, no modifications, no prompts.
#
# Exit codes:
#   0 = installed
#   1 = not installed (or partial)
# ─────────────────────────────────────────────────────────────────

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$tasteDir = Join-Path $HOME '.config/opencode/skills/taste-skill'

if (Test-Path (Join-Path $tasteDir 'SKILL.md')) {
    Write-Host "✅ Taste Skill installed at: $tasteDir" -ForegroundColor Green
    exit 0
}

# Check for command on PATH
$cmd = Get-Command taste-skill -ErrorAction SilentlyContinue
if ($cmd) {
    Write-Host "✅ taste-skill command found on PATH: $($cmd.Source)" -ForegroundColor Green
    exit 0
}

Write-Host '❌ Taste Skill not installed.' -ForegroundColor Red
Write-Host "   Expected: $tasteDir" -ForegroundColor Red
Write-Host '   Install:  opk taste install' -ForegroundColor Red
exit 1
