# ─────────────────────────────────────────────────────────────────
# verify.ps1
# opencode-power-kit v1.6.6
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
Require-File 'opencode-global/commands/doc-to-md.md'
Require-File 'opencode-global/commands/supermemory-init.md'
Require-File 'scripts/cleanup-agent-artifacts.sh'
Require-File 'scripts/opk-command-guard.sh'
Require-File 'scripts/validate-opencode-pack.py'
Require-File 'scripts/install-gsd-core.sh'
Require-File 'scripts/install-gsd-core.ps1'
Require-File 'scripts/install-markitdown.sh'
Require-File 'scripts/install-markitdown.ps1'
Require-File 'scripts/install-supermemory.sh'
Require-File 'scripts/install-supermemory.ps1'
Require-File 'scripts/install-safety-plugin.sh'
Require-File 'scripts/install-safety-plugin.ps1'
Require-File 'scripts/audit-ecc.sh'
Require-File 'scripts/install-ecc-lite.sh'
Require-File 'scripts/check-ecc-lite.sh'
Require-File 'opencode-global/agents/ecc-lite-strong.md'
Require-File 'opencode-global/commands/ecc-audit.md'
Require-File 'opencode-global/commands/quality-gate.md'
Require-File 'opencode-global/commands/research-first.md'
Require-File 'opencode-global/commands/verify-loop.md'
Require-File 'opencode-global/commands/model-route-review.md'
Require-File 'opencode-global/commands/harness-audit.md'
Require-File 'bin/opk'
Require-File 'templates/AGENTS.md'
Require-File 'templates/OPENCODE.md'
Require-File 'templates/AI_HANDOFF.md'
Require-File 'templates/opencode.safe.json'
Require-File 'templates/opencode.power.json'
Require-File 'templates/plugins/opk-safety-guard.js'
Write-Host ''

# ─── Required dirs ────────────────────────────────────────────────
Write-Host '[required directories]'
Require-Dir 'opencode-global'
Require-Dir 'opencode-global/commands'
Require-Dir 'scripts'
Require-Dir 'templates'
Require-Dir 'templates/plugins'
Require-Dir 'bin'
Write-Host ''

# ─── Auto Router presence ─────────────────────────────────────────
Write-Host '[Natural Language Auto Router]'
Require-Contains 'templates/AGENTS.md' 'Natural Language Auto Router'
Require-Contains 'templates/OPENCODE.md' 'Natural Language Auto Router'
Write-Host ''

# ─── v1.6.2: Scope Lock — docs-only/read-only scope drift fix ──
Write-Host '[v1.6.2 Scope Lock — docs-only/read-only]'
Require-Contains 'templates/AGENTS.md' 'Scope Lock — Docs-only / Read-only'
Require-Contains 'templates/OPENCODE.md' 'Scope Lock — Docs-only / Read-only'
Require-Contains 'opencode-global/agents/build-strong.md' 'Scope Gate'
Require-Contains 'profiles/node-nest-react-mysql/AGENTS.append.md' 'Scope Gate'
Require-Contains 'profiles/node-nest-react-mysql/OPENCODE.append.md' 'Scope Gate'

# opencode.json must NOT contain docs/**/*.md
$ocJson = Join-Path $KitDir 'templates/opencode.json'
if (Test-Path -LiteralPath $ocJson -PathType Leaf) {
    $jsonContent = Get-Content -LiteralPath $ocJson -Raw -ErrorAction SilentlyContinue
    if ($null -ne $jsonContent -and $jsonContent.Contains('docs/**/*.md')) {
        Fail 'templates/opencode.json still contains docs/**/*.md in instructions'
    } else {
        Ok 'templates/opencode.json does NOT contain docs/**/*.md'
    }
} else {
    Fail 'templates/opencode.json missing'
}
Write-Host ''

# ─── v1.6.3: Universal Scope Gate — all agents ────────────────────
Write-Host '[v1.6.3 Universal Scope Gate — all agents]'
$agentsWithScopeGate = @(
    'opencode-global/agents/api-strong.md'
    'opencode-global/agents/architect-strong.md'
    'opencode-global/agents/build-strong.md'
    'opencode-global/agents/db-strong.md'
    'opencode-global/agents/debug-strong.md'
    'opencode-global/agents/devops-strong.md'
    'opencode-global/agents/qa-strong.md'
    'opencode-global/agents/release-strong.md'
    'opencode-global/agents/security-strong.md'
    'opencode-global/agents/ui-ux-strong.md'
    'opencode-global/agents/gsd-executor.md'
    'opencode-global/agents/gsd-code-fixer.md'
)
foreach ($agentFile in $agentsWithScopeGate) {
    if (Test-Path -LiteralPath $agentFile -PathType Leaf) {
        Require-Contains $agentFile 'Scope Gate'
    } else {
        Fail "missing agent: $agentFile"
    }
}
Write-Host ''

# ─── v1.6.3: Scope Guard — commands ───────────────────────────────
Write-Host '[v1.6.3 Scope Guard — commands]'
$cmdsWithScopeGuard = @(
    'opencode-global/commands/agent-router.md'
    'opencode-global/commands/power-build.md'
    'opencode-global/commands/ci-fix.md'
    'opencode-global/commands/migration-safe.md'
    'opencode-global/commands/api-contract-review.md'
    'opencode-global/commands/kit-audit.md'
)
foreach ($cmdFile in $cmdsWithScopeGuard) {
    if (Test-Path -LiteralPath $cmdFile -PathType Leaf) {
        Require-Contains $cmdFile 'Scope Guard'
    } else {
        Fail "missing command: $cmdFile"
    }
}
Write-Host ''

# ─── CHANGELOG mentions v1.3.3 / v1.3.4 / v1.4.0 / v1.5.0 ──────
Write-Host '[changelog invariants]'
Require-Contains 'CHANGELOG.md' '1.3.3'
Require-Contains 'CHANGELOG.md' '1.3.4'
Require-Contains 'CHANGELOG.md' '1.4.0'
Require-Contains 'CHANGELOG.md' '1.5.0'
Require-Contains 'CHANGELOG.md' '1.6.0'
Require-Contains 'CHANGELOG.md' '1.6.2'
Require-Contains 'CHANGELOG.md' '1.6.3'
Require-Contains 'CHANGELOG.md' '1.6.4'
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

# ─── v1.6.5: One Command Update & Cleanup ──────────────────────
Write-Host '[v1.6.5 One Command Update & Cleanup]'
Require-Contains 'VERSION' '1.6.5'
Require-Contains 'README.md' 'version-1.6.5'
Require-Contains 'CHANGELOG.md' '1.6.5'
Require-Contains 'CHANGELOG.md' '1.6.6'
Require-Contains 'CHANGELOG.md' '1.6.7'
Require-Contains 'CHANGELOG.md' 'One Command Update & Cleanup'
Require-Contains 'CHANGELOG.md' 'opk up'
Require-Contains 'CHANGELOG.md' 'opk clean'
Require-Contains 'bin/opk' "'up')"
Require-Contains 'bin/opk' "'clean')"
Require-Contains 'bin/opk.ps1' "'up'"
Require-Contains 'bin/opk.ps1' "'clean'"
Require-Contains 'bin/opk' "up|update|upgrade"
Require-Contains 'bin/opk' "Trash dir"
Require-Contains 'scripts/cleanup-agent-artifacts.sh' 'GLOBAL_INSTALL_REPORT'
Require-Contains 'scripts/cleanup-agent-artifacts.sh' 'OPK_VERIFY_REPORT'
Require-Contains 'scripts/cleanup-agent-artifacts.sh' 'OPK_DOCTOR_REPORT'
Require-Contains 'scripts/cleanup-agent-artifacts.sh' 'RELEASE_NOTES_v'
Write-Host ''

# ─── v1.6.7: Supermemory Memory API ────────────────────────────
Write-Host '[v1.6.7 Supermemory Memory API]'
Require-Contains 'CHANGELOG.md' '1.6.7'
Require-Contains 'CHANGELOG.md' 'Supermemory'
Require-Contains 'scripts/install-supermemory.sh' 'supermemory'
Require-Contains 'scripts/install-supermemory.sh' 'npm install'
Require-Contains 'scripts/install-supermemory.ps1' 'supermemory'
Require-Contains 'scripts/install-supermemory.ps1' 'supermemory'
Require-Contains 'opencode-global/commands/supermemory-init.md' 'supermemory'
Require-Contains 'opencode-global/commands/supermemory-init.md' 'opk supermemory'
Require-Contains 'bin/opk' 'supermemory)'
Require-Contains 'bin/opk' 'install-supermemory.sh'
Require-Contains 'bin/opk' 'supermemory init'
Require-Contains 'bin/opk.ps1' "'supermemory'"
Require-Contains 'bin/opk.ps1' 'install-supermemory.ps1'
Require-Contains 'bin/opk.ps1' 'supermemory init'
Require-Contains 'README.md' 'Supermemory'
Require-Contains 'README.md' 'supermemory/supermemory'
Require-Contains 'README.md' 'opk supermemory'
Require-Contains 'THIRD_PARTY.md' 'Supermemory'
Write-Host ''

# ─── v1.7.0: Taste Skill ─────────────────────────────────────────
Write-Host '[v1.7.0 Taste Skill]'
Require-Contains 'CHANGELOG.md' '1.7.0'
Require-Contains 'CHANGELOG.md' 'Taste Skill'
Require-Contains 'scripts/install-taste-skill.sh' 'taste-skill'
Require-Contains 'scripts/install-taste-skill.ps1' 'taste-skill'
Require-Contains 'scripts/check-taste-skill.sh' 'taste-skill'
Require-Contains 'scripts/check-taste-skill.ps1' 'taste-skill'
Require-Contains 'opencode-global/agents/build-strong.md' 'taste-ui-strong'
Require-Contains 'opencode-global/commands/agent-router.md' 'taste-ui-strong'
Require-Contains 'bin/opk' 'taste|taste-status|taste-off|update-taste)'
Require-Contains 'bin/opk' 'taste install'
Require-Contains 'bin/opk' 'taste status'
Require-Contains 'bin/opk' 'update-taste'
Require-Contains 'bin/opk.ps1' "'taste'"
Require-Contains 'bin/opk.ps1' 'taste install'
Require-Contains 'bin/opk.ps1' 'taste status'
Require-Contains 'bin/opk.ps1' 'update-taste'
Require-Contains 'README.md' 'Taste Skill'
Require-Contains 'README.md' 'Leonxlnx/taste-skill'
Require-Contains 'README.md' 'opk taste'
Require-Contains 'THIRD_PARTY.md' 'Taste Skill'
Require-Contains 'THIRD_PARTY.md' 'taste-skill'
Write-Host ''

# ─── v1.8.0: ECC-lite (Engineering Code Commandments) ─────────────
Write-Host '[v1.8.0 ECC-lite]'
Require-Contains 'CHANGELOG.md' '1.8.0'
Require-Contains 'CHANGELOG.md' 'ECC-lite'
Require-Contains 'CHANGELOG.md' 'Engineering Code Commandments'
Require-Contains 'scripts/audit-ecc.sh' 'ECC'
Require-Contains 'scripts/install-ecc-lite.sh' 'ecc-lite'
Require-Contains 'scripts/check-ecc-lite.sh' 'ecc-lite'
Require-Contains 'opencode-global/agents/ecc-lite-strong.md' 'ECC-lite'
Require-Contains 'bin/opk' 'ec|e|ecc)'
Require-Contains 'bin/opk' 'ecc audit'
Require-Contains 'bin/opk' 'ecc lite'
Require-Contains 'bin/opk' 'ecc status'
Require-Contains 'bin/opk' 'ecc off'
Require-Contains 'bin/opk' 'update-ecc)'
Require-Contains 'bin/opk.ps1' "'ec','e','ecc'"
Require-Contains 'bin/opk.ps1' 'ecc audit'
Require-Contains 'bin/opk.ps1' 'ecc lite'
Require-Contains 'bin/opk.ps1' 'ecc status'
Require-Contains 'bin/opk.ps1' 'ecc off'
Require-Contains 'bin/opk.ps1' 'update-ecc'
Require-Contains 'README.md' 'ECC-lite'
Require-Contains 'README.md' 'ecc-lite-strong'
Require-Contains 'THIRD_PARTY.md' 'ECC'
Require-Contains 'THIRD_PARTY.md' 'affaan-m'
Write-Host ''

# ─── v1.9.0: Hermes-lite (meta-cognitive self-improvement) ─────────
Write-Host '[v1.9.0 Hermes-lite]'
Require-Contains 'CHANGELOG.md' '1.9.0'
Require-Contains 'CHANGELOG.md' 'Hermes-lite'
Require-Contains 'CHANGELOG.md' 'NousResearch'
Require-Contains 'opencode-global/agents/hermes-lite-strong.md' 'Hermes-lite'
Require-Contains 'scripts/audit-hermes.sh' 'hermes'
Require-Contains 'scripts/check-hermes-lite.sh' 'hermes-lite'
Require-Contains 'scripts/hermes-learning-capsule.sh' 'hermes'
Require-Contains 'bin/opk' 'hermes|hermes-status|hermes-off)'
Require-Contains 'bin/opk' 'hermes audit'
Require-Contains 'bin/opk' 'hermes status'
Require-Contains 'bin/opk' 'hermes capsule'
Require-Contains 'bin/opk' 'hermes off'
Require-Contains 'bin/opk.ps1' "'hermes'"
Require-Contains 'bin/opk.ps1' 'hermes audit'
Require-Contains 'bin/opk.ps1' 'hermes status'
Require-Contains 'bin/opk.ps1' 'hermes capsule'
Require-Contains 'bin/opk.ps1' 'hermes off'
Require-Contains 'README.md' 'Hermes-lite'
Require-Contains 'README.md' 'NousResearch'
Require-Contains 'THIRD_PARTY.md' 'Hermes'
Require-Contains 'THIRD_PARTY.md' 'NousResearch'
Write-Host ''

# ─── v1.9.1: RAG-lite (Retrieval-Augmented Generation reference) ──
Write-Host '[v1.9.1 RAG-lite]'
Require-Contains 'CHANGELOG.md' '1.9.1'
Require-Contains 'CHANGELOG.md' 'RAG-lite'
Require-Contains 'CHANGELOG.md' 'NirDiamant'
Require-File 'docs/RAG_LITE_INTEGRATION.md'
Require-Contains 'docs/RAG_LITE_INTEGRATION.md' 'RAG'
Require-File 'opencode-global/skills/rag-lite/SKILL.md'
Require-Contains 'opencode-global/skills/rag-lite/SKILL.md' 'RAG'
Require-File 'opencode-global/commands/rag-plan.md'
Require-File 'opencode-global/commands/rag-audit.md'
Require-File 'opencode-global/commands/rag-eval.md'
Require-Contains 'opencode-global/commands/rag-plan.md' 'RAG'
Require-Contains 'opencode-global/commands/rag-audit.md' 'RAG'
Require-Contains 'opencode-global/commands/rag-eval.md' 'RAG'
Require-Contains 'README.md' 'RAG-lite'
Require-Contains 'README.md' 'NirDiamant'
Require-Contains 'THIRD_PARTY.md' 'RAG_Techniques'
Require-Contains 'THIRD_PARTY.md' 'NirDiamant'
Require-Contains 'opencode-global/agents/build-strong.md' 'rag-'
Require-Contains 'opencode-global/commands/agent-router.md' 'rag-plan'
Write-Host ''

# ─── v1.9.3: AgentMemory-lite (Serverless Memory reference) ──
Write-Host '[v1.9.3 AgentMemory-lite]'
Require-Contains 'CHANGELOG.md' '1.9.3'
Require-Contains 'CHANGELOG.md' 'AgentMemory-lite'
Require-Contains 'CHANGELOG.md' 'rohitg00'
Require-File 'docs/AGENTMEMORY_LITE_INTEGRATION.md'
Require-Contains 'docs/AGENTMEMORY_LITE_INTEGRATION.md' 'AgentMemory-lite'
Require-Contains 'docs/AGENTMEMORY_LITE_INTEGRATION.md' 'memory'
Require-File 'opencode-global/skills/agentmemory-lite/SKILL.md'
Require-Contains 'opencode-global/skills/agentmemory-lite/SKILL.md' 'AgentMemory-lite'
Require-File 'opencode-global/commands/memory-plan.md'
Require-File 'opencode-global/commands/memory-audit.md'
Require-File 'opencode-global/commands/memory-handoff.md'
Require-Contains 'opencode-global/commands/memory-plan.md' 'memory'
Require-Contains 'opencode-global/commands/memory-audit.md' 'audit'
Require-Contains 'opencode-global/commands/memory-handoff.md' 'handoff'
Require-Contains 'README.md' 'AgentMemory-lite'
Require-Contains 'README.md' 'rohitg00'
Require-Contains 'THIRD_PARTY.md' 'agentmemory'
Require-Contains 'THIRD_PARTY.md' 'rohitg00'
Require-Contains 'opencode-global/agents/build-strong.md' 'agentmemory-lite'
Require-Contains 'opencode-global/commands/agent-router.md' 'memory-plan'
Write-Host ''

# ─── v2.0.0: OPK Orchestration Lite ──────────────────────────────
Write-Host '[v2.0.0 OPK Orchestration Lite]'
Require-Contains 'CHANGELOG.md' '2.0.0'
Require-Contains 'CHANGELOG.md' 'OPK Orchestration Lite'
Require-Contains 'CHANGELOG.md' 'oh-my-openagent'
Require-Contains 'CHANGELOG.md' 'intent-router'
Require-Contains 'CHANGELOG.md' 'power-work-lite'
Require-Contains 'CHANGELOG.md' 'continue-work'
Require-Contains 'CHANGELOG.md' 'evidence-report'
Require-Contains 'CHANGELOG.md' 'init-deep-lite'
Require-Contains 'CHANGELOG.md' 'no MCP'
Require-Contains 'CHANGELOG.md' 'no telemetry'
Require-Contains 'VERSION' '2.0.0'
Require-File 'opencode-global/commands/intent-router.md'
Require-File 'opencode-global/commands/init-deep-lite.md'
Require-File 'opencode-global/commands/power-work-lite.md'
Require-File 'opencode-global/commands/continue-work.md'
Require-File 'opencode-global/commands/evidence-report.md'
Require-Contains 'opencode-global/commands/intent-router.md' 'intent'
Require-Contains 'opencode-global/commands/power-work-lite.md' 'verify'
Require-Contains 'opencode-global/commands/continue-work.md' 'AI_HANDOFF'
Require-Contains 'opencode-global/commands/evidence-report.md' 'evidence'
Require-Contains 'opencode-global/commands/init-deep-lite.md' 'AGENTS.md'
Require-File 'docs/OPK_ORCHESTRATION_LITE.md'
Require-File 'docs/INSPIRATION_OH_MY_OPENAGENT.md'
Require-Contains 'docs/OPK_ORCHESTRATION_LITE.md' 'Orchestration Lite'
Require-Contains 'docs/INSPIRATION_OH_MY_OPENAGENT.md' 'oh-my-openagent'
Require-Contains 'README.md' 'OPK Orchestration Lite'
Require-Contains 'README.md' 'intent-router'
Require-Contains 'README.md' 'power-work-lite'
Require-Contains 'README.md' 'continue-work'
Require-Contains 'README.md' 'evidence-report'
Require-Contains 'README.md' 'init-deep-lite'
Require-Contains 'README.md' 'oh-my-openagent'
Require-Contains 'README.md' 'v2.0.0'
Require-Contains 'THIRD_PARTY.md' 'oh-my-openagent'
Require-Contains 'THIRD_PARTY.md' 'code-yeongyu'
Require-Contains 'THIRD_PARTY.md' 'Inspiration-only'
Require-Contains '.gitignore' '.opk/work/'
Require-Contains '.gitignore' '.opk/tmp/'
Require-Contains '.gitignore' '.opk/cache/'

# ─── v2.0.0: CLI Expansion & Taste verify-gated ──────────────────
Write-Host '[v2.0.0 CLI Expansion]'
Require-Contains 'bin/opk' 'upstream)'
Require-Contains 'bin/opk' 'upstream audit'
Require-Contains 'bin/opk' 'upstream doctor'
Require-Contains 'bin/opk' 'superpowers)'
Require-Contains 'bin/opk' 'superpowers status'
Require-Contains 'bin/opk' 'superpowers reset-cache'
Require-Contains 'bin/opk' 'superpowers doctor'
Require-Contains 'bin/opk' 'bmad)'
Require-Contains 'bin/opk' 'bmad status'
Require-Contains 'bin/opk' 'bmad update'
Require-Contains 'bin/opk' 'tooling)'
Require-Contains 'bin/opk' 'tooling doctor'
Require-Contains 'bin/opk' 'taste doctor'
Require-Contains 'bin/opk' 'taste install --v1'
Require-Contains 'bin/opk' 'taste install --v2'
Require-Contains 'bin/opk.ps1' "'upstream'"
Require-Contains 'bin/opk.ps1' 'upstream audit'
Require-Contains 'bin/opk.ps1' 'upstream doctor'
Require-Contains 'bin/opk.ps1' "'superpowers'"
Require-Contains 'bin/opk.ps1' 'superpowers status'
Require-Contains 'bin/opk.ps1' 'superpowers reset-cache'
Require-Contains 'bin/opk.ps1' 'superpowers doctor'
Require-Contains 'bin/opk.ps1' "'bmad'"
Require-Contains 'bin/opk.ps1' 'bmad status'
Require-Contains 'bin/opk.ps1' 'bmad update'
Require-Contains 'bin/opk.ps1' "'tooling'"
Require-Contains 'bin/opk.ps1' 'tooling doctor'
Require-Contains 'bin/opk.ps1' 'taste doctor'

Write-Host '[v2.0.0 Taste verify-gated]'
Require-Contains 'README.md' 'verify-gated'
Require-Contains 'README.md' 'opk taste install --v1'
Require-Contains 'README.md' 'opk taste doctor'
Require-Contains 'THIRD_PARTY.md' 'verify-gated'
Require-Contains 'THIRD_PARTY.md' 'user-installed'
Require-Contains 'CHANGELOG.md' 'Verify-gated'
Require-Contains 'CHANGELOG.md' 'CLI Expansion'

Write-Host '[v2.0.0 Taste auto-install removed from global scripts]'
# install-global.ps1 must NOT call install-taste-skill.ps1 -Yes
$ps1Content = Get-Content 'install-global.ps1' -Raw -ErrorAction SilentlyContinue
if ($ps1Content -and $ps1Content -match 'install-taste-skill\.ps1.*-Yes') {
    Write-Host '  FAIL: install-global.ps1 still calls install-taste-skill.ps1 -Yes' -ForegroundColor Red
    $script:Failed++
} else {
    Write-Host '  ok: install-global.ps1: no Taste auto-install call' -ForegroundColor Green
}
# install-global must have suggestion hint
Require-Contains 'install-global.sh' 'opk taste install'
Require-Contains 'install-global.ps1' 'opk taste install'
# UPSTREAM_AUDIT must not contain auto-enabled-dependency
$auditContent = Get-Content 'docs/UPSTREAM_AUDIT.md' -Raw -ErrorAction SilentlyContinue
if ($auditContent -and $auditContent -match 'auto-enabled-dependency') {
    Write-Host '  FAIL: docs/UPSTREAM_AUDIT.md still contains auto-enabled-dependency' -ForegroundColor Red
    $script:Failed++
} else {
    Write-Host '  ok: docs/UPSTREAM_AUDIT.md: no auto-enabled-dependency' -ForegroundColor Green
}
# No current-state auto-enabled wording in README/THIRD_PARTY
foreach ($f in @('README.md', 'THIRD_PARTY.md')) {
    $c = Get-Content $f -Raw -ErrorAction SilentlyContinue
    if ($c -and $c -match 'Taste Skill is automatically enabled') {
        Write-Host "  FAIL: $f contains 'Taste Skill is automatically enabled'" -ForegroundColor Red
        $script:Failed++
    } else {
        Write-Host "  ok: $f: no current-state auto-enabled wording" -ForegroundColor Green
    }
}
Write-Host ''

# ─── v2.0.0: Permission hardening & audit report consistency ─────
Write-Host '[v2.0.0 Permission & Audit Report Checks]'

# Default template must NOT have bare "permission": "allow"
$ocJson = Join-Path $KitDir 'templates/opencode.json'
if (Test-Path -LiteralPath $ocJson -PathType Leaf) {
    $jsonContent = Get-Content -LiteralPath $ocJson -Raw -ErrorAction SilentlyContinue
    if ($null -ne $jsonContent -and $jsonContent.Contains('"permission": "allow"')) {
        Fail 'templates/opencode.json still has bare "permission": "allow"'
    } else {
        Ok 'templates/opencode.json: no bare "permission": "allow"'
    }
} else {
    Fail 'templates/opencode.json missing'
}

# UPSTREAM_AUDIT.md must not have absolute local paths
$auditPath = Join-Path $KitDir 'docs/UPSTREAM_AUDIT.md'
if (Test-Path -LiteralPath $auditPath -PathType Leaf) {
    $auditContent = Get-Content -LiteralPath $auditPath -Raw -ErrorAction SilentlyContinue
    if ($null -ne $auditContent -and ($auditContent.Contains('/home/') -or $auditContent.Contains('/Users/') -or $auditContent.Contains('C:\'))) {
        Fail 'docs/UPSTREAM_AUDIT.md contains absolute local path'
    } else {
        Ok 'docs/UPSTREAM_AUDIT.md: no absolute local paths'
    }
} else {
    Fail 'docs/UPSTREAM_AUDIT.md missing'
}

# audit-upstreams.py must have --root, --check, --write
$auditScript = Join-Path $KitDir 'scripts/audit-upstreams.py'
if (Test-Path -LiteralPath $auditScript) {
    $auditHelp = & python3 $auditScript --help 2>&1
    foreach ($flag in @('--root', '--check', '--write')) {
        if ($auditHelp -match [regex]::Escape($flag)) {
            Ok "audit-upstreams.py has $flag flag"
        } else {
            Fail "audit-upstreams.py missing $flag flag"
        }
    }
}

Write-Host ''

# ─── v1.6.6: MarkItDown Document Tools ──────────────────────────
Write-Host '[v1.6.6 MarkItDown Document Tools]'
Require-Contains 'CHANGELOG.md' '1.6.6'
Require-Contains 'CHANGELOG.md' 'MarkItDown'
Require-Contains 'scripts/install-markitdown.sh' 'pipx'
Require-Contains 'scripts/install-markitdown.sh' 'markitdown'
Require-Contains 'scripts/install-markitdown.sh' '--dry-run'
Require-Contains 'scripts/install-markitdown.ps1' 'pipx'
Require-Contains 'scripts/install-markitdown.ps1' 'markitdown'
Require-Contains 'opencode-global/commands/doc-to-md.md' 'md-convert'
Require-Contains 'opencode-global/commands/doc-to-md.md' 'markitdown'
Require-Contains 'bin/opk' 'markitdown)'
Require-Contains 'bin/opk' 'install-markitdown.sh'
Require-Contains 'bin/opk' 'md-convert|doc-to-md)'
Require-Contains 'bin/opk.ps1' "'markitdown'"
Require-Contains 'bin/opk.ps1' 'install-markitdown.ps1'
Require-Contains 'bin/opk.ps1' 'md-convert'
Require-Contains 'README.md' 'MarkItDown'
Require-Contains 'README.md' 'microsoft/markitdown'
Require-Contains 'THIRD_PARTY.md' 'MarkItDown'
Write-Host ''

# ─── v1.6.4: Safety & Compatibility Polish ──────────────────────
Write-Host '[v1.6.4 Safety & Compatibility Polish]'
Require-Contains 'THIRD_PARTY.md' 'v1.6.4'
Require-Contains 'CHANGELOG.md' 'Power Mode vs Safe Mode'
Require-Contains 'CHANGELOG.md' 'Safety plugin guard'
Require-Contains 'CHANGELOG.md' 'opk mode'
Require-Contains 'templates/opencode.safe.json' '"permission":'
Require-Contains 'templates/opencode.power.json' '"permission"'
Require-Contains 'templates/plugins/opk-safety-guard.js' 'guardCheck'
Require-Contains 'bin/opk' 'mode)'
Require-Contains 'bin/opk' 'safety-plugin)'
Require-Contains 'bin/opk.ps1' "'mode'"
Require-Contains 'bin/opk.ps1' "'safety-plugin'"
Write-Host ''

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

# Parse check for install-safety-plugin.ps1
$psParseFiles = @(
    'scripts/install-safety-plugin.ps1',
    'scripts/install-gsd-core.ps1',
    'scripts/install-markitdown.ps1',
    'scripts/install-supermemory.ps1',
    'scripts/install-taste-skill.ps1',
    'scripts/check-taste-skill.ps1',
    'scripts/install-fullstack-profile.ps1',
    'bin/opk.ps1',
    'install-global.ps1',
    'bootstrap.ps1',
    'setup.ps1',
    'install.ps1',
    'update-bmad.ps1'
)
foreach ($psFile in $psParseFiles) {
    $psFullPath = Join-Path $KitDir $psFile
    if (Test-Path -LiteralPath $psFullPath) {
        try {
            $errs = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile(
                $psFullPath,
                [ref]$null,
                [ref]$errs
            )
            if ($errs -and $errs.Count -gt 0) {
                Fail "$psFile has parse errors: $($errs[0].Message)"
            } else {
                Ok "$psFile parses cleanly"
            }
        } catch {
            Fail "$psFile parse threw: $_"
        }
    } else {
        Warn "skip pwsh parser: $psFile not found"
    }
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
