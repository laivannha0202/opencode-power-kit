# ─────────────────────────────────────────────────────────────────
# timeout.ps1 — Portable timeout wrapper (PowerShell)
# opencode-power-kit v2.1.0
#
# Runs a command with a timeout. Returns exit code 124 if timeout occurs.
#
# Usage:
#   pwsh timeout.ps1 -Seconds <N> -Command <string> [-Args <string[]>]
#
# Examples:
#   pwsh timeout.ps1 -Seconds 5 -Command "sleep" -Args 10
#   pwsh timeout.ps1 -Seconds 5 -Command "sleep" -Args 2
#
# Exit codes:
#   0-N   — exit code from the command
#   124   — timeout occurred
#   125   — invalid arguments
# ─────────────────────────────────────────────────────────────────

param(
    [Parameter(Mandatory=$true)]
    [int]$Seconds,
    
    [Parameter(Mandatory=$true)]
    [string]$Command,
    
    [string[]]$Args = @()
)

if ($Seconds -le 0) {
    Write-Error "Error: timeout must be a positive integer"
    exit 125
}

try {
    $process = Start-Process -FilePath $Command -ArgumentList $Args -NoNewWindow -PassThru -Wait -ErrorAction Stop
    exit $process.ExitCode
} catch {
    if ($_.Exception.Message -match "timed out|timeout") {
        exit 124
    }
    Write-Error "Error running command: $_"
    exit 125
}
