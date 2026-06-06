# ─────────────────────────────────────────────────────────────────
# install-gsd-core.ps1
# opencode-power-kit v1.3.4
#
# PowerShell mirror of scripts/install-gsd-core.sh.
#
# Optional integration with the official GSD Core installer:
#
#     npx @opengsd/gsd-core@latest
#
# This script does NOT vendor or copy GSD source. It only forwards
# to the official installer. See THIRD_PARTY.md.
# ─────────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes,
    [string]$Target
)

$ErrorActionPreference = 'Stop'

$ScriptName = 'install-gsd-core.ps1'
$GsdPackage = '@opengsd/gsd-core'

# ─── Helpers ──────────────────────────────────────────────────────
function Write-Plan($cmdArgs) {
    Write-Host '=== install-gsd-core (PowerShell) ==='
    Write-Host "Mode:     $(if ($DryRun) { 'dry-run' } elseif ($Yes) { 'yes' } else { 'interactive' })"
    Write-Host "Package:  ${GsdPackage}@latest"
    Write-Host "Command:  $cmdArgs"
    if ($Target) { Write-Host "Target:   $Target" } else { Write-Host 'Target:   (no --target; installer will prompt or use cwd)' }
    Write-Host ''
}

# ─── Pre-flight: tooling ──────────────────────────────────────────
$missing = @()
foreach ($tool in @('node', 'npm', 'npx')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        $missing += $tool
    }
}
if ($missing.Count -gt 0) {
    Write-Host "ERROR: missing required tool(s) on PATH: $($missing -join ', ')" -ForegroundColor Red
    Write-Host 'Install Node.js (which bundles npm + npx) and retry.' -ForegroundColor Red
    exit 1
}

# ─── Build command ────────────────────────────────────────────────
$cmdParts = @('npx', "${GsdPackage}@latest")
if ($Target) { $cmdParts += $Target }
$cmdString = $cmdParts -join ' '

Write-Plan $cmdString

# ─── Dry run ──────────────────────────────────────────────────────
if ($DryRun) {
    Write-Host 'Dry run complete. Re-run with -Yes to actually invoke npx.'
    exit 0
}

# ─── Interactive confirmation ─────────────────────────────────────
if (-not $Yes) {
    if ([Environment]::UserInteractive -eq $false) {
        Write-Host 'ERROR: no interactive TTY; refusing to run without -Yes.' -ForegroundColor Red
        exit 1
    }
    $reply = Read-Host "Invoke '$cmdString' now? [y/N]"
    if ($reply -notin @('y', 'Y', 'yes', 'YES')) {
        Write-Host 'aborted.'
        exit 0
    }
}

# ─── Invoke ───────────────────────────────────────────────────────
Write-Host "==> $cmdString"
& npx @cmdParts
exit $LASTEXITCODE
