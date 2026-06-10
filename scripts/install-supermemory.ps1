# ─────────────────────────────────────────────────────────────────
# install-supermemory.ps1
# opencode-power-kit v1.6.7
#
# PowerShell mirror of scripts/install-supermemory.sh.
#
# Optional integration with Supermemory CLI (npm).
# Installs the official npm package via npm global install when
# the user explicitly requests it.
#
# See THIRD_PARTY.md for details.
# ─────────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

$ScriptName = 'install-supermemory.ps1'
$SupermemoryPackage = '@supermemory/ai'

# ─── Helpers ──────────────────────────────────────────────────────
function Write-Plan($cmdLine) {
    Write-Host '=== install-supermemory (PowerShell) ==='
    Write-Host "Mode:          $(if ($DryRun) { 'dry-run' } elseif ($Yes) { 'yes' } else { 'interactive' })"
    Write-Host "Package:       $SupermemoryPackage"
    Write-Host "Command:       $cmdLine"
    Write-Host ''
}

# ─── Pre-flight: node + npm ──────────────────────────────────────
$node = Get-Command node -ErrorAction SilentlyContinue
$npm  = Get-Command npm -ErrorAction SilentlyContinue

if (-not $node) {
    Write-Host 'ERROR: node is not on PATH. Install Node.js first.' -ForegroundColor Red
    exit 1
}
if (-not $npm) {
    Write-Host 'ERROR: npm is not on PATH. Install npm first.' -ForegroundColor Red
    exit 1
}

$nodeVersion = & $node.Source --version 2>&1
$npmVersion  = & $npm.Source --version 2>&1

Write-Host "=== install-supermemory ==="
Write-Host "Mode:          $(if ($DryRun) { 'dry-run' } elseif ($Yes) { 'yes' } else { 'interactive' })"
Write-Host "Node:          $($node.Source) ($nodeVersion)"
Write-Host "npm:           $($npm.Source) ($npmVersion)"
Write-Host ''

# ─── Check if already installed ──────────────────────────────────
$alreadyInstalled = (Get-Command supermemory -ErrorAction SilentlyContinue) -ne $null
if ($alreadyInstalled) {
    $smPath = (Get-Command supermemory).Source
    Write-Host "ℹ️  'supermemory' already on PATH: $smPath" -ForegroundColor Cyan
    Write-Host ''
}

# ─── Plan ─────────────────────────────────────────────────────────
$installCmd = @($npm.Source, 'install', '-g', $SupermemoryPackage)
$cmdLine = $installCmd -join ' '

Write-Host "Plan:"
Write-Host "  Command:  $cmdLine"
Write-Host "  Sudo:     NO"
Write-Host "  curl|sh:  NO"
Write-Host ''

# ─── Dry run ──────────────────────────────────────────────────────
if ($DryRun) {
    Write-Plan $cmdLine
    Write-Host 'Dry run complete. Re-run with -Yes to install.'
    exit 0
}

if ($alreadyInstalled) {
    Write-Host '✅ supermemory is already installed and on PATH.' -ForegroundColor Green
    exit 0
}

# ─── Interactive confirmation ─────────────────────────────────────
if (-not $Yes) {
    $reply = Read-Host "Install '$SupermemoryPackage' via npm now? [y/N]"
    if ($reply -notin @('y','Y','yes','YES')) {
        Write-Host 'aborted.'
        exit 0
    }
}

# ─── Install ──────────────────────────────────────────────────────
Write-Host "==> $cmdLine"
& $installCmd[0] $installCmd[1..($installCmd.Length-1)]
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Installation failed (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit 1
}
Write-Host ''

# ─── Verify ───────────────────────────────────────────────────────
$smCheck = Get-Command supermemory -ErrorAction SilentlyContinue
if ($smCheck) {
    Write-Host "✅ supermemory installed at: $($smCheck.Source)" -ForegroundColor Green
    & $smCheck.Source --help 2>&1 | Select-Object -First 5
    Write-Host ''
    Write-Host '🎉 Supermemory is ready. Quick start:' -ForegroundColor Green
    Write-Host '    supermemory init          # Initialize in your project'
    Write-Host '    supermemory status        # Check memory status'
    Write-Host ''
    Write-Host 'Agent command: /supermemory-init'
} else {
    Write-Host "⚠️  Installation may have succeeded but 'supermemory' is not on PATH." -ForegroundColor Yellow
    $npmRoot = & $npm.Source root -g 2>&1
    Write-Host "   Check npm global bin directory: $npmRoot"
    Write-Host "   Try adding to your PATH, then re-run: supermemory --help"
    exit 1
}
