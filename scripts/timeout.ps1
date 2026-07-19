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

$process = $null
try {
    # Build start info for process tree kill
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    if ($Args.Count -gt 0) {
        $psi.Arguments = ($Args -join ' ')
    }
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $false

    $process = [System.Diagnostics.Process]::Start($psi)

    # Wait with timeout (milliseconds)
    $timeoutMs = $Seconds * 1000
    $exited = $process.WaitForExit($timeoutMs)

    if (-not $exited) {
        # Timeout — kill process tree
        try {
            $process.Kill($true)
        } catch {
            # Fallback: try taskkill /T /F
            try {
                taskkill /PID $process.Id /T /F 2>$null
            } catch {
                # Last resort
                $process.Kill()
            }
        }
        exit 124
    }

    # Command completed — return its exit code
    exit $process.ExitCode
} catch {
    Write-Error "Error running command: $_"
    exit 125
} finally {
    if ($process -ne $null) {
        $process.Dispose()
    }
}
