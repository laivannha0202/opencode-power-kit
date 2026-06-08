# ─────────────────────────────────────────────────────────────────
# verify.ps1
# opencode-power-kit v1.5.0
#
# PowerShell mirror of verify.sh. Read-only sanity check.
#
# Reads the expected version from $KitDir\VERSION. If VERSION is
# missing, the script WARNS (does not crash) and continues with the
# other checks.
# ─────────────────────────────────────────────────────────────────

[CmdletBinding()]
param(
    [switch]$NoPython,
    [switch]$NoPwsh
)

$ErrorActionPreference = 'Stop'

# ─── Resolve kit root ──────────────────────────────────────────────
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$KitDir = $ScriptDir
Set-Location -LiteralPath $KitDir

$VersionFile = Join-Path $KitDir 'VERSION'
$ExpectedVersion = ''

$Pass = 0
$Fail = 0
$Warn = 0

# ─── Helpers ──────────────────────────────────────────────────────
function Ok($msg) {
    Write-Host "  ok   $msg"
    $script:Pass++
}
function Fail($msg) {
    Write-Host "  FAIL $msg"
    $script:Fail++
}
function Warn($msg) {
    Write-Host "  warn $msg"
    $script:Warn++
}

function Require-File($path) {
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Ok "file exists: $path"
    } else {
        Fail "missing file: $path"
    }
}
function Require-Dir($path) {
    if (Test-Path -LiteralPath $path -PathType Container) {
        Ok "dir exists:  $path"
    } else {
        Fail "missing dir:  $path"
    }
}
function Require-Contains($path, $needle) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Fail "$path missing:  $needle"
        return
    }
    $content = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
    if ($null -ne $content -and $content.ToLower().Contains($needle.ToLower())) {
        Ok "$path contains: $needle"
    } else {
        Fail "$path missing:  $needle"
    }
}

# ─── Header ───────────────────────────────────────────────────────
Write-Host '=== opencode-power-kit verify (PowerShell) ==='
Write-Host "Repo root: $KitDir"
Write-Host ''

# ─── VERSION ──────────────────────────────────────────────────────
# Read $KitDir\VERSION explicitly. If missing, warn — do not crash.
Write-Host '[VERSION]'
if (Test-Path -LiteralPath $VersionFile -PathType Leaf) {
    $raw = Get-Content -LiteralPath $VersionFile -Raw -ErrorAction SilentlyContinue
    if ($null -ne $raw) {
        $ExpectedVersion = ($raw -replace '\s', '').Trim()
    }
    if ([string]::IsNullOrEmpty($ExpectedVersion)) {
        Warn "VERSION file is empty at $VersionFile"
    } else {
        Ok "VERSION file read from $VersionFile : $ExpectedVersion"
    }
} else {
    Warn "VERSION file missing at $VersionFile (continuing without version check)"
}
Write-Host ''

# ─── Required files ───────────────────────────────────────────────
Write-Host '[required files]'
Require-File 'VERSION'
Require-File 'CHANGELOG.md'
Require-File 'README.md'
Require-File 'THIRD_PARTY.md'
Require-File 'verify.sh'
Require-File 'verify.ps1'
Require-File 'opencode-global/agents/build-strong.md'
Require-File 'opencode-global/agents/architect-strong.md'
Require-File 'opencode-global/agents/debug-strong.md'
Require-File 'opencode-global/agents/qa-strong.md'
Require-File 'opencode-global/agents/security-strong.md'
Require-File 'opencode-global/agents/db-strong.md'
Require-File 'opencode-global/agents/api-strong.md'
Require-File 'opencode-global/agents/ui-ux-strong.md'
Require-File 'opencode-global/agents/devops-strong.md'
Require-File 'opencode-global/agents/release-strong.md'
Require-File 'opencode-global/commands/cleanup-safe.md'
Require-File 'opencode-global/commands/handoff-save.md'
Require-File 'opencode-global/commands/checkpoint.md'
Require-File 'opencode-global/commands/agent-router.md'
Require-File 'opencode-global/commands/ci-fix.md'
Require-File 'opencode-global/commands/e2e-flow.md'
Require-File 'opencode-global/commands/release-check.md'
Require-File 'opencode-global/commands/kit-audit.md'
Require-File 'opencode-global/commands/power-build.md'
Require-File 'opencode-global/commands/tooling-doctor.md'
Require-File 'scripts/cleanup-agent-artifacts.sh'
Require-File 'scripts/opk-command-guard.sh'
Require-File 'scripts/validate-opencode-pack.py'
Require-File 'scripts/install-gsd-core.sh'
Require-File 'scripts/install-gsd-core.ps1'
Require-File 'bin/opk'
Require-File 'templates/AGENTS.md'
Require-File 'templates/OPENCODE.md'
Require-File 'templates/AI_HANDOFF.md'
Write-Host ''

# ─── Required dirs ────────────────────────────────────────────────
Write-Host '[required directories]'
Require-Dir 'opencode-global'
Require-Dir 'opencode-global/commands'
Require-Dir 'scripts'
Require-Dir 'templates'
Require-Dir 'bin'
Write-Host ''

# ─── Auto Router presence ─────────────────────────────────────────
Write-Host '[Natural Language Auto Router]'
Require-Contains 'templates/AGENTS.md' 'Natural Language Auto Router'
Require-Contains 'templates/OPENCODE.md' 'Natural Language Auto Router'
Write-Host ''

# ─── CHANGELOG mentions v1.3.3 / v1.3.4 / v1.4.0 / v1.5.0 ──────
Write-Host '[changelog invariants]'
Require-Contains 'CHANGELOG.md' '1.3.3'
Require-Contains 'CHANGELOG.md' '1.3.4'
Require-Contains 'CHANGELOG.md' '1.4.0'
Require-Contains 'CHANGELOG.md' '1.5.0'
Require-Contains 'CHANGELOG.md' 'build-strong'
Require-Contains 'CHANGELOG.md' 'fullstack-autopilot'
Require-Contains 'CHANGELOG.md' 'cleanup-safe'
Require-Contains 'CHANGELOG.md' 'handoff-save'
Require-Contains 'CHANGELOG.md' 'checkpoint'
Require-Contains 'CHANGELOG.md' 'Natural Language Auto Router'
Require-Contains 'CHANGELOG.md' 'Backward compatible'
Require-Contains 'CHANGELOG.md' 'GSD Core'
Require-Contains 'CHANGELOG.md' 'Power Mode'
Require-Contains 'CHANGELOG.md' 'architect-strong'
Require-Contains 'CHANGELOG.md' 'opk-command-guard'
Require-Contains 'THIRD_PARTY.md' 'BMAD'
Require-Contains 'THIRD_PARTY.md' 'GSD Core'

# ─── build-strong.md content ─────────────────────────────────────
Write-Host '[build-strong agent content]'
Require-Contains 'opencode-global/agents/build-strong.md' 'Fullstack-Autopilot'
Require-Contains 'opencode-global/agents/build-strong.md' 'Hard Rules'
Require-Contains 'opencode-global/agents/build-strong.md' 'vertical slice'
Require-Contains 'opencode-global/agents/build-strong.md' 'cleanup-safe'
Require-Contains 'opencode-global/agents/build-strong.md' 'Agent Delegation'
Write-Host ''

# ─── PowerShell parser self-check ─────────────────────────────────
Write-Host '[powershell parser self-check]'
try {
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile(
        (Join-Path $KitDir 'verify.ps1'),
        [ref]$null,
        [ref]$errs
    )
    if ($errs -and $errs.Count -gt 0) {
        Fail "verify.ps1 has parse errors: $($errs[0].Message)"
    } else {
        Ok 'verify.ps1 parses cleanly'
    }
} catch {
    Fail "verify.ps1 parse threw: $_"
}

$installPs1 = Join-Path $KitDir 'scripts/install-gsd-core.ps1'
if (Test-Path -LiteralPath $installPs1) {
    try {
        $errs = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $installPs1,
            [ref]$null,
            [ref]$errs
        )
        if ($errs -and $errs.Count -gt 0) {
            Fail "scripts/install-gsd-core.ps1 has parse errors: $($errs[0].Message)"
        } else {
            Ok 'scripts/install-gsd-core.ps1 parses cleanly'
        }
    } catch {
        Fail "scripts/install-gsd-core.ps1 parse threw: $_"
    }
} else {
    Warn 'skip pwsh parser: scripts/install-gsd-core.ps1 not found'
}
Write-Host ''

# ─── Python validator (run if present) ────────────────────────────
Write-Host '[python validator]'
$pyScript = Join-Path $KitDir 'scripts/validate-opencode-pack.py'
if (Test-Path -LiteralPath $pyScript) {
    if ($NoPython) {
        Write-Host '  skip python validator (-NoPython)'
    } elseif (Get-Command python3 -ErrorAction SilentlyContinue) {
        $proc = Start-Process -FilePath 'python3' -ArgumentList @($pyScript) `
            -NoNewWindow -Wait -PassThru
        if ($proc.ExitCode -eq 0) {
            Ok 'python3 validate-opencode-pack.py'
        } else {
            Fail "python3 validate-opencode-pack.py exit=$($proc.ExitCode)"
        }
    } else {
        Write-Host '  skip python validator (python3 not installed)'
    }
} else {
    Fail 'scripts/validate-opencode-pack.py missing'
}
Write-Host ''

# ─── Summary ──────────────────────────────────────────────────────
Write-Host '=== summary ==='
Write-Host "passed: $Pass"
Write-Host "failed: $Fail"
Write-Host "warned: $Warn"

if ($Fail -gt 0) {
    Write-Host 'RESULT: FAIL'
    exit 1
}
Write-Host 'RESULT: PASS'
exit 0
