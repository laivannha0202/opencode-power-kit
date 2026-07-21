# Eval Harness — Workflow Regression Suite

Workflow regression tests for OpenCode Power Kit. Verifies behavioral
contracts: no model routing, no API keys, no overrides, no model selection.

**This is NOT a model quality benchmark.** It does not call models,
score model output, or compare providers.

## Structure

```
evals/
├── README.md          # This file
├── tasks/
│   └── contracts.json # 27 behavioral workflow contracts
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
  "name": "No model routing in bin/opk",
  "description": "bin/opk must not contain model discovery, routing, or benchmark",
  "check_type": "grep_absent",
  "target": "bin/opk",
  "patterns": ["discover-free", "benchmark-free"],
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
| contract-001 | grep_absent | No model routing/discovery/benchmark in bin/opk |
| contract-002 | grep_absent | No API keys in templates |
| contract-003 | grep_absent | .gitignore allows .opencode/ |
| contract-004 | file_absent | Deleted model routing scripts |
| contract-005 | script_exec | Safety plugin test (node) |
| contract-006 | script_exec | Permission ordering test (python3) |
| contract-007 | file_absent | No model override template |
| contract-008 | grep_present | Model-agnostic policy documented |
| contract-009 | script_exec | Model status via opk CLI |
| contract-010 | grep_absent | No model override in agent files |
| contract-011 | grep_present | Writer/read-only reviewer policy |
| contract-012 | grep_present | build-strong pipeline stages |
| contract-013 | script_exec | Timeout helper exists and runs |
| contract-014 | script_exec | Timeout forced fallback returns 124 |
| contract-015 | script_exec | Timeout forced fallback preserves exit code |
| contract-016a | file_present | backend-route-review exists |
| contract-016b | file_absent | model-route-review deleted |
| contract-017 | grep_absent | No model routing commands in backend-route-review |
| contract-018 | grep_present | README agent count accurate |
| contract-019 | grep_present | README command count accurate |
| contract-020 | grep_absent | No Quality Scorecard in README |
| contract-021 | grep_present | UPSTREAM_CAPABILITY_MAP correct URLs and pins |
| contract-022 | script_exec | Default timeout path returns 124 |
| contract-023 | script_exec | Timeout kills grandchild processes |
| contract-024 | script_exec | Default timeout path preserves exit code |
| contract-025 | script_exec | install-gsd-core.sh status runs without error |
| contract-026 | grep_present | THIRD_PARTY.md has correct upstream pins |

## Notes

- **Workflow regression only.** Tests verify file contents and CLI behavior.
- **No model calls.** Contracts do not invoke models or score output.
- **No benchmark.** No model comparison or quality ranking.
- **Extensible.** Add new contracts to `contracts.json` following the format.
- Runner auto-discovers all `*.json` in `evals/tasks/`.
