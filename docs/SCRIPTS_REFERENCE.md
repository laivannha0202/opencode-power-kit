# Scripts Reference

| Script | Purpose |
|--------|---------|
| `bootstrap.sh` | Linux/macOS bootstrap — installs agents, commands, skills globally |
| `bootstrap.ps1` | Windows PowerShell bootstrap equivalent |
| `verify.sh` | Linux/macOS verification of kit installation |
| `verify.ps1` | Windows PowerShell verification equivalent |
| `setup.sh` | Linux/macOS full setup script |
| `setup.ps1` | Windows PowerShell full setup script |
| `install-global.sh` | Install global components (agents/commands/skills) |
| `install-project.sh` | Install project components |
| `install-fullstack-profile.sh` | Install full-stack profile (Node/Nest/React/MySQL) |
| `opk-command-guard.sh` | Safety guard: warns/blocks dangerous shell commands |
| `cleanup-agent-artifacts.sh` | Safely clean up agent artifacts |
| `doctor.sh` | Read-only diagnostic check |

All scripts are idempotent — safe to run multiple times.
