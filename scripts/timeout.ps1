# ─────────────────────────────────────────────────────────────────
# timeout.ps1 — Portable timeout wrapper (PowerShell)
# opencode-power-kit v2.1.0
#
# Runs a command with a timeout. Returns exit code 124 if timeout occurs.
#
# Usage:
#   pwsh -NoProfile -File timeout.ps1 -Seconds <N> -Command <string> [-Args <string[]>]
#
# Examples:
#   pwsh -NoProfile -File timeout.ps1 -Seconds 5 -Command "sleep" -Args 10
#   pwsh -NoProfile -File timeout.ps1 -Seconds 5 -Command "sleep" -Args 2
#
# Exit codes:
#   0-N   — exit code from the command
#   124   — timeout occurred
#   126   — invalid arguments
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
    exit 126
}

$process = $null
try {
    # Build ProcessStartInfo with ArgumentList — no shell quoting
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Command
    $psi.UseShellExecute = $false
    if ($null -eq $psi.ArgumentList) {
        throw "ProcessStartInfo.ArgumentList is unavailable; PowerShell timeout requires a runtime with argv support"
    }

    foreach ($arg in $Args) {
        [void]$psi.ArgumentList.Add($arg)
    }

    $process = [System.Diagnostics.Process]::Start($psi)

    # Wait with timeout using WaitForExit(milliseconds)
    $timeoutMs = $Seconds * 1000
    $exited = $process.WaitForExit($timeoutMs)

    if (-not $exited) {
        # Timeout — kill the entire process tree
        try {
            $process.Kill($true)
        } catch {
            # Fallback: try killing without tree
            try { $process.Kill() } catch {}
        }
        # Reap the process
        try { $process.WaitForExit() } catch {}
        exit 124
    }

    # Command completed — return its actual exit code
    exit $process.ExitCode
} catch {
    Write-Error "Error running command: $_"
    exit 126
} finally {
    if ($process -ne $null) {
        $process.Dispose()
    }
}
