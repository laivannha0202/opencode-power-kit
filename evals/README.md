# Eval Harness — Workflow Regression Suite

Workflow regression tests for OpenCode Power Kit. Verifies behavioral
contracts for Linux packaging, safety, permissions, orchestration, timeout
behavior, documentation counts, and upstream pins.

The suite validates repository behavior and does not call an AI provider.

## Structure

```
evals/
├── README.md          # This file
├── tasks/
│   └── contracts.json # 22 behavioral workflow contracts
├── results/           # Test output (auto-generated)
└── run.sh             # Test runner
```

## Usage

```bash
# Run all contracts
bash evals/run.sh

# Dry run (structural check only)
bash evals/run.sh --dry-run
```

## Contract Format

Each contract in `contracts.json` is a JSON object:

```json
{
  "id": "contract-001",
  "name": "Windows runtime artifacts removed",
  "description": "Linux-only distribution must not ship Windows entrypoints",
  "check_type": "file_absent",
  "targets": ["bin/opk.cmd", "bin/opk.ps1"],
  "expected": "all_absent"
}
```

## Check Types

| Check Type | Description | Required Tool |
|-----------|-------------|---------------|
| `grep_absent` | Patterns must NOT appear in target file/directory | `grep` |
| `grep_present` | Patterns must appear in target file | `grep` |
| `file_absent` | Target files must NOT exist | filesystem |
| `file_present` | Target files must exist | filesystem |
| `script_exec` | Run command, exit 0 = PASS | `python3`, `node`, `bash` |

**Unknown check_type → FAIL.** Runner does not silently skip unknown types.

**Missing required dependency → FAIL.** (e.g., `python3` not found for `script_exec`).
Optional dependency → SKIP.

## Contracts

| ID | Check Type | What It Verifies |
|----|-----------|-----------------|
| contract-001 | file_absent | Windows runtime artifacts removed |
| contract-002 | grep_present | Linux-only support documented |
| contract-003 | grep_absent | .gitignore allows .opencode/ |
| contract-004 | grep_present | Linux platform guard exists |
| contract-005 | script_exec | Safety plugin test (node) |
| contract-006 | script_exec | Permission ordering test (python3) |
| contract-007 | file_present | CI workflow ci.yml exists |
| contract-007b | file_absent | No extra GitHub Actions workflows |
| contract-011 | grep_present | Writer/read-only reviewer policy |
| contract-012 | grep_present | build-strong pipeline stages |
| contract-013 | script_exec | Timeout helper exists and runs |
| contract-014 | script_exec | Timeout forced fallback returns 124 |
| contract-015 | script_exec | Timeout forced fallback preserves exit code |
| contract-016a | file_present | backend-route-review exists |
| contract-018 | grep_present | README agent count accurate |
| contract-019 | grep_present | README command count accurate |
| contract-020 | grep_absent | No unsupported quality scorecard |
| contract-021 | grep_present | UPSTREAM_CAPABILITY_MAP correct URLs and pins |
| contract-022 | script_exec | Default timeout path returns 124 |
| contract-023 | script_exec | Timeout kills grandchild processes |
| contract-024 | script_exec | Default timeout path preserves exit code |
| contract-025 | script_exec | install-gsd-core.sh status runs without error |
| contract-026 | grep_present | THIRD_PARTY.md has correct upstream pins |

## Notes

- **Repository regression only.** Tests verify file contents and CLI behavior.
- **Linux-only.** Windows entrypoints and GitHub workflow gates must stay absent.
- **No provider calls.** The suite runs locally and does not contact an AI model.
- **Extensible.** Add new contracts to `contracts.json` following the format.
- Runner auto-discovers all `*.json` in `evals/tasks/`.
