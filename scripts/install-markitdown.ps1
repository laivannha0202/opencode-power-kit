# ─────────────────────────────────────────────────────────────────
# install-markitdown.ps1
# opencode-power-kit v1.6.6
#
# PowerShell mirror of scripts/install-markitdown.sh.
#
# Optional integration with Microsoft MarkItDown (Python).
# Installs the official PyPI package via pipx (preferred) or pip
# when the user explicitly requests it.
#
# See THIRD_PARTY.md for details.
# ─────────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes
)

$ErrorActionPreference = 'Stop'

$ScriptName = 'install-markitdown.ps1'

# ─── Helpers ──────────────────────────────────────────────────────
function Write-Plan($method, $cmdLine) {
    Write-Host '=== install-markitdown (PowerShell) ==='
    Write-Host "Mode:          $(if ($DryRun) { 'dry-run' } elseif ($Yes) { 'yes' } else { 'interactive' })"
    Write-Host "Install tool:  $method"
    Write-Host "Command:       $cmdLine"
    Write-Host ''
}

# ─── Pre-flight: python3 ──────────────────────────────────────────
$python = Get-Command python -ErrorAction SilentlyContinue
$python3 = Get-Command python3 -ErrorAction SilentlyContinue
$pythonPath = if ($python3) { $python3.Source } elseif ($python) { $python.Source } else { $null }

if (-not $pythonPath) {
    Write-Host 'ERROR: Python is not on PATH. Install Python 3 first.' -ForegroundColor Red
    exit 1
}

$pyVersion = & $pythonPath --version 2>&1
Write-Host "=== install-markitdown ==="
Write-Host "Mode:          $(if ($DryRun) { 'dry-run' } elseif ($Yes) { 'yes' } else { 'interactive' })"
Write-Host "Python:        $pythonPath ($pyVersion)"

# ─── Detect pipx / pip ────────────────────────────────────────────
$installMethod = $null
$installCmd = @()

$pipx = Get-Command pipx -ErrorAction SilentlyContinue
$pip = Get-Command pip -ErrorAction SilentlyContinue

if ($pipx) {
    $installMethod = 'pipx'
    $installCmd = @('pipx', 'install', 'markitdown[all]')
    $pipxVersion = & $pipx.Source --version 2>&1
    Write-Host "Install tool:  pipx ($pipxVersion)"
} elseif ($pip) {
    $installMethod = 'pip'
    $installCmd = @($pip.Source, 'install', '--user', 'markitdown[all]')
    Write-Host 'Install tool:  pip (--user)'
} else {
    Write-Host "ERROR: neither 'pipx' nor 'pip' is available." -ForegroundColor Red
    Write-Host "       Install pipx or pip first, then re-run this script." -ForegroundColor Red
    Write-Host ''
    Write-Host '  Install pip:   python -m pip install --upgrade pip'
    Write-Host '  Install pipx:  pip install pipx  (or: python -m pip install --user pipx)'
    exit 1
}

Write-Host ''

# ─── Check if already installed ──────────────────────────────────
$alreadyInstalled = (Get-Command markitdown -ErrorAction SilentlyContinue) -ne $null
if ($alreadyInstalled) {
    $mdPath = (Get-Command markitdown).Source
    Write-Host "ℹ️  'markitdown' already on PATH: $mdPath" -ForegroundColor Cyan
    Write-Host ''
}

# ─── Dry run ──────────────────────────────────────────────────────
if ($DryRun) {
    Write-Plan $installMethod ($installCmd -join ' ')
    Write-Host 'Dry run complete. Re-run with -Yes to install.'
    exit 0
}

if ($alreadyInstalled) {
    Write-Host '✅ markitdown is already installed and on PATH.' -ForegroundColor Green
    exit 0
}

# ─── Plan ─────────────────────────────────────────────────────────
$cmdLine = $installCmd -join ' '
Write-Host "Plan:"
Write-Host "  Tool:     $installMethod"
Write-Host "  Command:  $cmdLine"
Write-Host ''

# ─── Interactive confirmation ─────────────────────────────────────
if (-not $Yes) {
    $reply = Read-Host "Install 'markitdown[all]' via $installMethod now? [y/N]"
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
$mdCheck = Get-Command markitdown -ErrorAction SilentlyContinue
if ($mdCheck) {
    Write-Host "✅ markitdown installed at: $($mdCheck.Source)" -ForegroundColor Green
    & $mdCheck.Source --help 2>&1 | Select-Object -First 5
    Write-Host ''
    Write-Host '🎉 MarkItDown is ready. Quick test:' -ForegroundColor Green
    Write-Host '    markitdown input.pdf > output.md'
    Write-Host '    markitdown input.docx > output.md'
    Write-Host '    markitdown input.html > output.md'
} else {
    Write-Host "⚠️  Installation may have succeeded but 'markitdown' is not on PATH." -ForegroundColor Yellow
    if ($installMethod -eq 'pipx') {
        Write-Host "   Try running: pipx ensurepath"
    } else {
        $userBase = & $pythonPath -c 'import site; print(site.USER_BASE)' 2>&1
        Write-Host "   Try adding to your PATH: $userBase\bin"
    }
    Write-Host "   Then re-run: markitdown --help"
    exit 1
}
