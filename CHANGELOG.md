# Changelog

All notable changes to OpenCode Power Kit are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-07-10

### Runtime Hardening, Model-Agnostic & Safety Fixes

#### Added

- **`doctor.sh`** — kit health check script (basic + `--deep` extended mode).
  Checks kit integrity, templates, scripts, agents, runtime, project state.
  No side effects, fully read-only.
- **`scripts/release-gate.sh`** — release readiness gate. Validates VERSION,
  CHANGELOG, templates, safety plugin, GSD agents, scripts, personal paths,
  shell syntax, and test coverage before release.
- **`scripts/test-runtime-behavior.sh`** — orchestration script that runs all
  behavioral/integration tests in one pass.
- **`docs/MODEL_ROUTING.md`** — model-agnostic policy documentation.
- **`docs/SKILL_ROUTING.md`** — skill routing by task context, not model.
- **`docs/UPSTREAM_CAPABILITY_MAP.md`** — OPK vs OpenCode native capability map.
- **`evals/`** — eval harness with 12 workflow contracts and runner for testing
  behavioral regression (no model routing, no API keys, no overrides).
- **`scripts/test-permission-rules.py`** — behavioral test verifying permission
  deny-list ordering (wildcard first, deny last) in all templates.
- **`scripts/test-safety-plugin.mjs`** — unit tests for safety plugin helpers
  (sensitive path detection, dangerous command detection, SQL injection guard).
- **`scripts/test-opk-mode.sh`** — regression test for mode detection
  (POWER/SAFE/CUSTOM) via JSON parser.
- **`scripts/test-installer-preservation.sh`** — integration test verifying
  installer idempotency and backup preservation.
- **`verify.ps1`** — PowerShell verification with model-agnostic contract:
  no model override template, no model override in agents, build-strong
  pipeline stages, writer/read-only reviewer policy.

#### Changed

- **`scripts/merge-opk-project.py`** — fixed missing `import os` (used by
  `os.getpid()` in backup filename generation).
- **`bin/opk`** — model-agnostic policy: single `model)` branch outputs
  "OPK không quản lý model". Removed model routing/discovery/benchmark commands.
- **`templates/opencode.json`** — permission rule ordering fixed: wildcard
  `"*"` first, specific allows, deny rules last (OpenCode "last rule wins").
- **`templates/opencode.power.json`** — same rule ordering fix.
- **`templates/opencode.safe.json`** — same rule ordering fix.
- **`templates/plugins/opk-safety-guard.js`** — rewritten as CommonJS with
  `tool.execute.before` hook, `throw new Error()` for blocking (not
  `{ blocked: true }`). Single `module.exports = OPKSafetyGuard` factory.
  Sensitivity checks via string/regex, not glob.
- **`opencode-global/agents/build-strong.md`** — rewritten as 7-phase
  orchestrator pipeline: Intake → Context → Plan → Implement → Review
  → Verify → Report. Writer/read-only reviewer policy enforced.
- **`evals/run.sh`** — unknown check_type now FAIL (not SKIP). Added
  `script_exec` check_type for running actual commands. Required missing
  dependency → FAIL; optional → SKIP.
- **`evals/tasks/contracts.json`** — 12 workflow contracts: safety plugin
  test, permission rules test, model status CLI, agent model override scan,
  build-strong pipeline stages, writer/read-only reviewer.
- **GSD agents moved** — 34 GSD companion agents relocated from
  `opencode-global/agents/` to `extras/gsd-agent-reference/`. Active agents:
  16 (was 48+).
- **`scripts/install-gsd-core.sh`** — version pinned to exact `1.6.1`
  (no `@latest`).
- **`scripts/install-safety-plugin.sh`** — updated with OPK marker detection
  and backup-on-overwrite for existing plugins.
- **`install.sh`** — uses merge script for idempotent config, backup with
  timestamp for all managed files.
- **VERSION** — bumped from 2.0.0 to 2.1.0.

#### Removed

- **`templates/opencode.models.example.jsonc`** — model override template
  removed (model-agnostic policy).
- **Model routing scripts** — `scripts/opk-model-discover.sh`,
  `scripts/opk-model-route.sh`, `scripts/opk-model-benchmark.sh`,
  `scripts/validate-free-model.sh` deleted.

#### Security

- Permission deny-list in all templates now follows OpenCode's "last matching
  rule wins" semantics: wildcard allow at top, specific allows middle, deny
  rules at bottom.
- Safety plugin properly blocks at runtime (CommonJS `tool.execute.before` + throw),
  not just instruction-level.
- No personal paths (`/home/nha`) in any runtime directory.
- GSD agents no longer in active path — reference-only in extras/.
- Model-agnostic policy: no model discovery, routing, benchmarking, or
  override in any OPK file.

## [2.0.0] - 2026-06-14

### Upstream Audit & Security Hardening (2026-07-03)

### Added

- **`docs/UPSTREAM_AUDIT.md`** — comprehensive audit of all 28 upstream dependencies
  with integration types, risk levels, and required actions.
- **`docs/UPSTREAM_UPDATE_POLICY.md`** — policy for when/how to update upstream
  references, including pin updates, package migrations, and breaking changes.
- **`docs/UPSTREAM_RISKS.md`** — risk analysis for permission, auto-install,
  stale packages, license, Windows paths, version conflicts, and network deps.
- **Permission deny-list** — `templates/opencode.json`, `templates/opencode.power.json`,
  and `templates/opencode.safe.json` now include explicit deny-list for destructive
  commands: `rm -rf`, `git reset --hard`, `git clean -fd`, `git push --force`,
  `DROP TABLE`, `TRUNCATE TABLE`, `curl|sh`, `wget|sh`.
- **`scripts/audit-upstreams.py`** — new script to scan repo for upstream references
  and generate audit reports.
- **Validator updates** — `scripts/validate-opencode-pack.py` now checks for:
  - UPSTREAM_AUDIT.md, UPSTREAM_UPDATE_POLICY.md, UPSTREAM_RISKS.md existence
  - Permission deny-list in all config templates
  - Deprecated `@supermemory/ai` references outside migration section

### Changed

- **BMAD Method version pin** — default updated from `6.8.0` to `6.9.0` in
  `install.sh`, `install.ps1`, `update-bmad.sh`, `update-bmad.ps1`.
- **Supermemory package migration** — `scripts/install-supermemory.sh` and
  `scripts/install-supermemory.ps1` now use `supermemory` instead of deprecated
  `@supermemory/ai`. Old package name only appears in DEPRECATED comments.
- **OpenCode config templates** — all three templates (default, power, safe) now
  use permission object with explicit deny-list instead of bare `"permission": "allow"`.

### Security

- All config templates now deny destructive bash commands even in power mode.
- Deprecated package references removed from active code.
- Upstream dependency matrix documented with risk levels.

### CLI Expansion (v2.0.0)

- **`bin/opk`** — new subcommands:
  - `opk upstream audit` / `opk upstream audit --check` / `opk upstream doctor`
  - `opk superpowers status` / `opk superpowers reset-cache` / `opk superpowers doctor`
  - `opk bmad status` / `opk bmad update --stable/--next/--version`
  - `opk tooling doctor`
  - `opk taste install --v1/--v2` / `opk taste doctor`
- **`bin/opk.ps1`** — full parity for all new subcommands.
- **Help text** — updated with v2.0.0 sections for all new commands.

### Taste Skill — Verify-gated (v2.0.0)

- **Changed from auto-enabled to verify-gated** — Taste Skill is no longer
  auto-installed during `opk global/one/go`. User must explicitly run
  `opk taste install` to add it.
- **`install-global.sh` / `install-global.ps1`** — Taste auto-install removed.
  Scripts now print suggestion hint only.
- **New `opk taste doctor`** — checks node/npx runtime dependencies.
- **New `opk taste install --v1/--v2`** — explicit version selection.
- **Safe removal** — `opk taste off` now moves to `.opk-trash/` instead of
  deleting files directly. No `rm -rf` used.
- **README.md** — updated integration model from "Auto-enabled" to "Verify-gated".
- **THIRD_PARTY.md** — updated integration type and install behavior table.

### Migration Notes

- **BMAD 6.8.0 → 6.9.0:** If you have existing projects, run
  `BMAD_METHOD_VERSION=6.9.0 opk update-bmad` to update.
- **Supermemory:** If you installed `@supermemory/ai`, uninstall it and
  install `supermemory` instead: `npm uninstall -g @supermemory/ai && npm install -g supermemory`.

### OPK Orchestration Lite — Inspired by oh-my-openagent

### Added

- **OPK Orchestration Lite** — streamlined orchestration framework inspired by
  [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) by code-yeongyu.
  Ships only OPK-native components — no source code copied, no vendor dependency,
  no MCP, no telemetry.
- **`/intent-router`** — classifies user requests into 10 intent types
  (research, plan, implement, debug, refactor, test, security, release, docs,
  fullstack-feature) and recommends appropriate agent/workflow. Outputs in Vietnamese.
- **`/init-deep-lite`** — initializes project context by reading current project
  and creating/updating AGENTS.md, OPENCODE.md, AI_HANDOFF.md, docs/PROJECT_CONTEXT.md,
  docs/WORKFLOW.md. Never overwrites user content — uses append with markers.
- **`/power-work-lite`** — safe, Vietnamese-first long work workflow inspired by
  ultrawork. 10-step process: git status → read context → define goal → plan →
  select agent → checkpoint → build slices → verify → save evidence → report.
- **`/continue-work`** — resumes interrupted tasks from AI_HANDOFF.md and
  .opk/work/ evidence files. Reads context, runs light verification, continues safely.
- **`/evidence-report`** — generates comprehensive Vietnamese evidence report
  from git status, git diff, test results, changed files, and technical decisions.
- **`doctor --deep`** — extended read-only checks: Orchestration Lite files,
  permission mode, MCP in templates, telemetry detection, oh-my-openagent not
  vendored, optional tools detection, .opk/work/ directory.
- **`/tooling-doctor` expanded** — added detect-only for: shellcheck, shfmt, jq,
  eslint, prettier, vitest, tsc. Total 21 tools detected.
- **`.opk/work/` directory** — runtime evidence storage for power-work-lite.
- **`.gitignore` updated** — added .opk/work/, .opk/tmp/, .opk/cache/.
- **2 documentation files**:
  - `docs/OPK_ORCHESTRATION_LITE.md` — architecture, comparison, safety guarantees
  - `docs/INSPIRATION_OH_MY_OPENAGENT.md` — detailed inspiration notes
- **THIRD_PARTY.md** — oh-my-openagent entry (section 8.11, Inspiration-only),
  upstream table row, license notes, what OPK tham khảo vs KHÔNG tham khảo.
- **README.md** — OPK Orchestration Lite section, new commands table, doctor --deep,
  rationale for no MCP/telemetry, version badge updated to v2.0.0.

### Safety

- No source code copied from oh-my-openagent.
- No oh-my-openagent dependency added (npm, pip, cargo, or otherwise).
- No MCP enabled by default — OPK keeps no MCP policy.
- No telemetry added — no usage tracking, analytics, or hooks.
- All orchestration commands follow existing safety rules: no force push,
  no git reset --hard, no git clean -fd, no file deletion, no .env/secrets access.
- Every command runs git status before/after and outputs in Vietnamese.

### Changed

- VERSION bumped from 1.9.3 to 2.0.0
- `doctor.sh` — added --deep flag with extended checks
- `tooling-doctor.md` — expanded detect list (21 tools)
- `.gitignore` — added .opk/work/, .opk/tmp/, .opk/cache/
- `README.md` — version badge, new sections, updated command count
- `THIRD_PARTY.md` — version header, oh-my-openagent section

## [1.9.0] - 2026-06-11

### Hermes-lite — Meta-Cognitive Self-Improvement (Inspiration-only)

### Added

- **Hermes-lite integration** — optional, OPK-native meta-cognitive
  self-improvement framework inspired by
  [Hermes Agent](https://github.com/NousResearch/hermes-agent) by NousResearch.
  Ships only OPK-native components — no full Hermes Agent install, no gateway,
  no Telegram/Discord/Slack, no cron/scheduler/memory, no MCP, no auto-enable.
  - `opk hermes audit` — self-audit Hermes-lite components (read-only)
  - `opk hermes status` — check Hermes-lite installation status (no network)
  - `opk hermes capsule` — package learnings into capsule file
  - `opk hermes off` — remove Hermes-lite components
- **`opencode-global/agents/hermes-lite-strong.md`** — new subagent for
  meta-cognitive self-improvement workflows: learning loop, skill improvement,
  memory policy review, context/budget pressure, lightweight kanban, tool
  surface audit, remote backend review.
- **8 slash commands** for Hermes-lite:
  - `/hermes-reflect` — structured reflection on recent work
  - `/hermes-skill` — propose skill improvements from work patterns
  - `/hermes-kanban` — lightweight kanban board for agent tasks
  - `/hermes-memory` — memory policy review
  - `/hermes-budget` — context/budget pressure analysis
  - `/hermes-audit` — tool surface audit
  - `/hermes-learn` — capture learning from current work
  - `/hermes-research` — research remote backend/dependency improvement
- **3 helper scripts**:
  - `scripts/audit-hermes.sh` — read-only self-audit
  - `scripts/check-hermes-lite.sh` — read-only status check (no network)
  - `scripts/hermes-learning-capsule.sh` — package learnings into capsule
- **4 documentation files**:
  - `docs/HERMES_INTEGRATION.md` — architecture, component table, safety
    guarantees, usage guide, comparison with full Hermes Agent
  - `docs/HERMES_AUDIT.md` — audit methodology and template
  - `docs/LEARNING_LOOP.md` — learning loop documentation
  - `docs/AGENT_KANBAN.md` — lightweight kanban for agents
- **THIRD_PARTY.md** — Hermes Agent entry (section 8.5, Inspiration-only),
  upstream table row, license notes, update policy.
- **README.md** — Hermes-lite section with integration model, usage, safety
  guarantees, component table updated (agents 48→49, commands 49→57,
  scripts 15→18).

### Safety

- Hermes-lite scripts never: auto-install, vendor source, gateway, hooks, MCP,
  sudo, curl|sh, read .env/secrets.
- Hermes-lite is NOT installed during `opk global`, `opk one`, `opk go`,
  `bootstrap.sh --all`, `setup.sh --global`, `install-global.sh`, or `opk up`.
- `audit-hermes.sh` is read-only — no modifications to working tree.
- `check-hermes-lite.sh` is read-only — no network calls.
- Full Hermes Agent (scheduler, gateway, Telegram/Discord/Slack, cron, memory)
  is never installed by the kit.

### Changed

- VERSION bumped from 1.8.0 to 1.9.0
- `bin/opk` — added `hermes` namespace (audit/status/capsule/off)
- `bin/opk.ps1` — mirror Hermes subcommands for PowerShell
- `verify.sh` — added required files, executability, bash -n, Hermes-lite
  section with CHANGELOG/agent/command/CLI/README/THIRD_PARTY content checks
- `verify.ps1` — added Hermes-lite section with content checks
- `opencode-global/agents/build-strong.md` — added hermes-lite-strong to
  Agent Delegation table
- `opencode-global/commands/agent-router.md` — added Hermes-lite routing entries
- New version tag reference: `[1.9.0]`

## [1.9.1] - 2026-06-12

### RAG-lite — Retrieval-Augmented Generation Reference (Inspiration-only)

### Added

- **RAG-lite integration** — optional, OPK-native conceptual reference for
  Retrieval-Augmented Generation inspired by
  [NirDiamant/RAG_Techniques](https://github.com/NirDiamant/RAG_Techniques).
  Ships only OPK-native docs + agent skill + slash commands — no copy of
  upstream source/notebook, no auto-enable, no runtime dependency.
  - `docs/RAG_LITE_INTEGRATION.md` — conceptual reference, architecture,
    component table, evaluation checklist
  - `opencode-global/skills/rag-lite/SKILL.md` — agent skill for RAG workflow
    planning, auditing, and evaluation
  - 3 slash commands for RAG-lite:
    - `/rag-plan` — plan RAG pipeline (chunking, embedding, retrieval, generation)
    - `/rag-audit` — audit RAG pipeline health (retrieval quality, latency, coverage)
    - `/rag-eval` — evaluate RAG pipeline (faithfulness, relevance, robustness)
- **`opencode-global/agents/build-strong.md`** — added RAG planning row to
  Agent Delegation table: agent, context, when to use
- **`opencode-global/commands/agent-router.md`** — added 3 routing entries for
  rag-plan/rag-audit/rag-eval
- **THIRD_PARTY.md** — NirDiamant/RAG_Techniques entry (section 8.8,
  Reference / Learning resource), upstream table row, license notes,
  update policy.
- **README.md** — RAG-lite section with integration model, usage, files table.
  Component table updated (commands 57→60, skills 18→21, agents 49→49).
  Upstream table updated.

### Safety

- RAG-lite components are entirely docs + agent instructions — no scripts,
  no network calls, no auto-enable, no runtime code.
- RAG-lite is NOT installed during `opk global`, `opk one`, `opk go`,
  `bootstrap.sh --all`, `setup.sh --global`, `install-global.sh`, or `opk up`.
- All content is OPK-original conceptual guidance — not derived from any
  single upstream source.
- License-safe: only reference concept/workflow/checklist — no copy of
  source/notebook from NirDiamant/RAG_Techniques (which is custom
  non-commercial license).

### Changed

- VERSION bumped from 1.9.0 to 1.9.1
- `opencode-global/agents/build-strong.md` — added RAG + vector DB notes in
  layer section, RAG planning row in delegation table
- `opencode-global/commands/agent-router.md` — added rag-plan/rag-audit/rag-eval
  routing entries
- `THIRD_PARTY.md` — version banner 1.9.0→1.9.1, added NirDiamant/RAG_Techniques
  in component table + section 8.8 + update policy + license notes
- `README.md` — version badge 1.9.0→1.9.1, added upstream row for
  NirDiamant/RAG_Techniques, component counts updated, RAG-lite section added
- New version tag reference: `[1.9.1]`

## [1.9.3] - 2026-06-12

### AgentMemory-lite — Serverless Memory Reference (Inspiration-only)

### Added

- **AgentMemory-lite integration** — optional, OPK-native conceptual reference
  for serverless memory for AI agents inspired by
  [rohitg00/agentmemory](https://github.com/rohitg00/agentmemory).
  Ships only OPK-native docs + agent skill + slash commands — no copy of
  upstream source/code/hooks, no auto-enable, no runtime dependency, no
  package install.
  - `docs/AGENTMEMORY_LITE_INTEGRATION.md` — conceptual reference, memory
    strategies, safe handoff protocol, checklist, license-safe design
  - `opencode-global/skills/agentmemory-lite/SKILL.md` — agent skill for
    memory planning, audit, handoff workflows
  - 3 slash commands for AgentMemory-lite:
    - `/memory-plan` — plan memory strategy (scope classification,
      strategy selection, content planning, TTL, safety check)
    - `/memory-audit` — audit memory state (inventory, completeness,
      staleness, safety, integrity, handoff readiness)
    - `/memory-handoff` — safe memory handoff (state collection,
      AI_HANDOFF.md generation, integrity check, safety review, cleanup)
- **No auto-enable** — AgentMemory-lite never installed during `opk global`,
  `opk one`, `opk go`, `bootstrap.sh --all`, `setup.sh --global`,
  `install-global.sh`, or `opk up`.
- **License-safe** — all content is OPK-original conceptual guidance.
  No source code, plugins, or hooks from rohitg00/agentmemory are shipped.
  See `THIRD_PARTY.md` and `docs/AGENTMEMORY_LITE_INTEGRATION.md` for details.

### Changed

- VERSION bumped from 1.9.2 to 1.9.3
- `opencode-global/agents/build-strong.md` — added AgentMemory-lite row in
  delegation table
- `opencode-global/commands/agent-router.md` — added
  memory-plan/memory-audit/memory-handoff routing entries
- `THIRD_PARTY.md` — version banner 1.9.2→1.9.3, added
  rohitg00/agentmemory in component table + section 8.10 + license notes
- `README.md` — version badge 1.9.2→1.9.3, added upstream row for
  rohitg00/agentmemory, component counts updated, AgentMemory-lite section
  added
- `verify.sh` — added AgentMemory-lite section
- `verify.ps1` — added AgentMemory-lite section
- `scripts/validate-opencode-pack.py` — EXPECTED_VERSION → 1.9.3, added
  AgentMemory-lite needles
- New version tag reference: `[1.9.3]`

## [1.9.2] - 2026-06-12

### Headroom-lite — Context/Token Compression Reference (Inspiration-only)

### Added

- **Headroom-lite integration** — optional, OPK-native conceptual reference
  for context window and token compression inspired by
  [chopratejas/headroom](https://github.com/chopratejas/headroom).
  Ships only OPK-native docs + agent skill + slash commands — no copy of
  upstream source/binary, no auto-enable, no runtime dependency, no
  proxy/daemon/config.
  - `docs/HEADROOM_LITE_INTEGRATION.md` — conceptual reference, compression
    strategies, token budget management, evidence-preserving compression,
    license-safe design rationale
  - `opencode-global/skills/headroom-lite/SKILL.md` — agent skill for
    context compression workflow planning, auditing, and status monitoring
  - 3 slash commands for Headroom-lite:
    - `/headroom-plan` — plan context compression strategy (content
      classification, budget calculation, evidence preservation)
    - `/headroom-audit` — audit existing context/token usage (consumption
      breakdown, compression opportunities, evidence integrity)
    - `/headroom-status` — check Headroom-lite integration status
      (component health, routing, related tools)
- **`opencode-global/agents/build-strong.md`** — added Headroom-lite row to
  Agent Delegation table
- **`opencode-global/commands/agent-router.md`** — added 3 routing entries
  for Headroom-lite
- **THIRD_PARTY.md** — chopratejas/headroom entry (section 8.9,
  Inspiration-only / Reference), upstream table row, license notes,
  update policy.
- **README.md** — Headroom-lite section with integration model, usage,
  files table. Component table updated.

### Safety

- Headroom-lite components are entirely docs + agent instructions + commands
  — no scripts, no network calls, no auto-enable, no runtime code, no
  proxy/daemon.
- Headroom-lite is NOT installed during `opk global`, `opk one`, `opk go`,
  `bootstrap.sh --all`, `setup.sh --global`, `install-global.sh`, or
  `opk up`.
- All content is OPK-original conceptual guidance — not derived from any
  single upstream source.
- License-safe: only reference concept/workflow/checklist — no copy of
  source/binary from chopratejas/headroom (Apache-2.0).
- Combined with RAG-lite and rtk/tokscale for full context management
  stack — Headroom-lite provides workflow guidance, rtk/tokscale provide
  token measurement, RAG-lite provides retrieval quality evaluation.

### Changed

- VERSION bumped from 1.9.1 to 1.9.2
- `opencode-global/agents/build-strong.md` — added Headroom-lite row in
  delegation table
- `opencode-global/commands/agent-router.md` — added
  headroom-plan/headroom-audit/headroom-status routing entries
- `THIRD_PARTY.md` — version banner 1.9.1→1.9.2, added
  chopratejas/headroom in component table + section 8.9 + update policy +
  license notes
- `README.md` — version badge 1.9.1→1.9.2, added upstream row for
  chopratejas/headroom, component counts updated, Headroom-lite section
  added
- `verify.sh` — added Headroom-lite section with required files,
  content checks
- New version tag reference: `[1.9.2]`

## [1.8.0] - 2026-06-11

### ECC-lite — Engineering Code Commandments (Opt-in)

### Added

- **ECC-lite integration** — optional, lightweight subset of
  [ECC (Engineering Code Commandments)](https://github.com/affaan-m/ECC) by
  affaan.m. Ships only OPK-native components — no full ECC install, no hooks,
  no MCP, no memory, no auto-enable.
  - `opk ecc audit` — audit codebase against ECC principles (read-only, clone to .tmp)
  - `opk ecc lite` — install ECC-lite agent + commands
  - `opk ecc status` — check ECC-lite installation status (no network)
  - `opk ecc off` — remove ECC-lite
  - `opk update-ecc` — refresh ECC-lite installation
  - Short aliases: `opk ec` / `opk e`
- **`scripts/audit-ecc.sh`** — read-only audit: clone ECC to .tmp/, analyze
  codebase, create docs/ECC_AUDIT.md, cleanup. No global config changes,
  no full asset copy, no vendor source in repo.
- **`scripts/install-ecc-lite.sh`** — install ECC-lite agent + 6 commands
  to `~/.config/opencode/`. Dry-run + confirm. OPK-native only.
- **`scripts/check-ecc-lite.sh`** — read-only status check (no network).
- **`opencode-global/agents/ecc-lite-strong.md`** — new subagent for ECC-lite
  engineering discipline workflows (research-first, quality gate, verification
  loop, assumption checking, test-before-done, security/reliability review).
- **6 slash commands** for ECC-lite:
  - `/ecc-audit` — audit codebase against ECC principles
  - `/quality-gate` — quality gate before merge/release
  - `/research-first` — research-first approach
  - `/verify-loop` — verification loop (test-before-done)
  - `/model-route-review` — AI model routing review
  - `/harness-audit` — constraints/edge-cases/invariants audit
- **`docs/ECC_INTEGRATION.md`** — architecture, component table, safety
  guarantees, usage guide, comparison with full ECC.
- **THIRD_PARTY.md** — ECC entry (section 8, Opt-in wrapper), upstream table
  row, license notes, update policy.
- **README.md** — ECC-lite section with integration model, usage, safety
  guarantees, files table. Component table updated (agents 46→47, commands
  34→40, scripts 12→15).

### Safety

- ECC-lite scripts never: auto-install, vendor source, hooks, MCP, sudo,
  curl|sh, read .env/secrets.
- ECC-lite is NOT installed during `opk global`, `opk one`, `opk go`,
  `bootstrap.sh --all`, `setup.sh --global`, `install-global.sh`, or `opk up`.
- `audit-ecc.sh` is read-only — clones to .tmp/, never modifies working tree.
- `check-ecc-lite.sh` is read-only — no network calls.
- Installer requires explicit `--yes` or TTY confirmation.

### Changed

- VERSION bumped from 1.7.0 to 1.8.0
- `bin/opk` — added `ec|e|ecc` namespace (audit/lite/status/off) + `update-ecc`
- `bin/opk.ps1` — mirror ECC subcommands for PowerShell
- `verify.sh` — added required files, executability, bash -n, ECC-lite section
  with CHANGELOG/script/agent/command/CLI/README/THIRD_PARTY content checks
- `verify.ps1` — added ECC-lite section with content checks

## [1.7.0] - 2026-06-10

> **⚠️ Legacy behavior:** Auto-install in v1.7.0 was replaced by verify-gated
> install in v2.0.0. Global scripts no longer auto-install Taste Skill.
> Use `opk taste install` instead.

### Taste Skill — AI-Augmented UI/UX Design (Auto-Enabled — Legacy)

### Added

- **Taste Skill integration** — [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill)
  cung cấp khả năng UI/UX design AI-augmented: image-to-code, redesign, polish,
  brand kit, landing page, mobile UI optimization.
  - `opk taste install` — install via npx (dry-run + confirm)
  - `opk taste status` / `opk taste-status` — check installation status
  - `opk taste off` / `opk taste-off` — remove taste skill
  - `opk update-taste` — refresh taste skill installation
  - `OPK_SKIP_TASTE=1` — bỏ qua auto-install (environment variable)
- **`scripts/install-taste-skill.sh`** — Linux/macOS installer (npx, graceful
  degradation nếu thiếu node/npx/network)
- **`scripts/install-taste-skill.ps1`** — Windows PowerShell installer
- **`scripts/check-taste-skill.sh`** — read-only detection script (no network)
- **`scripts/check-taste-skill.ps1`** — read-only detection (PowerShell)
- **`opencode-global/agents/taste-ui-strong.md`** — new subagent for AI-augmented
  UI/UX design tasks
- **7 slash commands** cho Taste Skill:
  - `/taste-polish` — UI polish & refinement
  - `/redesign-ui` — Redesign existing UI
  - `/image-to-code` — Convert design image to code
  - `/brandkit` — Brand kit generation
  - `/mobile-ui` — Mobile UI optimization
  - `/landing-ui` — Landing page UI
  - `/ui-final-pass` — Final UI quality pass
- **Agent routing** — build-strong.md và agent-router.md: route UI design tasks
  sang taste-ui-strong
- **Auto-enabled on install** — Taste Skill được cài tự động khi chạy:
  `opk global`, `opk one`, `opk go`, `bootstrap.sh --all`, `setup.sh --global`,
  `install-global.sh`. Không fail core install nếu thiếu node/npx/network.
- **THIRD_PARTY.md** — Taste Skill entry section 7
- **README.md** — Taste Skill section với integration model, quick start,
  slash commands table, OPK_SKIP_TASTE documentation

### Safety

- Taste Skill scripts never: auto-fail on missing deps, sudo, curl|sh
- Missing node/npx/network → chỉ warn, không fail core install
- OPK_SKIP_TASTE=1 bỏ qua hoàn toàn auto-install
- Scripts prefer npx; never use sudo npm
- No .env/secrets modification
- Installer requires explicit --yes or TTY confirmation
- check scripts are read-only, no network calls

### Changed

- VERSION bumped from 1.6.7 to 1.7.0
- `bin/opk` — added taste, taste-status, taste-off, update-taste subcommands
- `bin/opk.ps1` — mirror taste subcommands for PowerShell
- `install-global.sh` — auto-install Taste Skill khi OPK_SKIP_TASTE != 1
- `install-global.ps1` — auto-install Taste Skill khi OPK_SKIP_TASTE != 1
- `opencode-global/agents/build-strong.md` — Agent Delegation table: +taste-ui-strong
- `opencode-global/commands/agent-router.md` — Routing table: +taste-ui-strong
- `verify.sh` — added required files and CLI checks for Taste Skill
- `verify.ps1` — added required files and CLI checks for Taste Skill

## [1.6.7] - 2026-06-10

### Supermemory Memory API (Opt-in)

### Added

- **Supermemory integration** — optional memory persistence across AI coding
  sessions using [Supermemory CLI](https://github.com/supermemory/supermemory)
  (npm).
  - `opk supermemory install` — install via npm global install
  - `opk supermemory status` — check if Supermemory is installed
  - `opk supermemory init` — initialize Supermemory in the current project
  - `/supermemory-init` — agent command for initialization workflow
- **`scripts/install-supermemory.sh`** — Linux/macOS installer (dry-run, --yes, npm)
- **`scripts/install-supermemory.ps1`** — Windows PowerShell installer (mirrors .sh)
- **`opencode-global/commands/supermemory-init.md`** — agent command documentation
  (guides agents to use `opk` wrapper, never self-install packages)
- **THIRD_PARTY.md** — Supermemory entry under Opt-in wrapper, section 6
- **README.md** — Supermemory section with integration model, quick start

### Safety

- Supermemory scripts never: auto-install, vendored source, sudo, curl|sh
- Supermemory is not installed during `opk up`, bootstrap, or shell startup
- bin/opk and bin/opk.ps1 require user confirmation before npm global install
- Agent command `/supermemory-init` always routes through `opk supermemory` wrapper

## [1.6.6] - 2026-06-10

### MarkItDown Document Tools (Opt-in)

### Added

- **MarkItDown integration** — optional document-to-Markdown conversion using
  [Microsoft MarkItDown](https://github.com/microsoft/markitdown) (Python).
  Supports PDF, DOCX, PPTX, XLSX, HTML, CSV, JSON, XML, ZIP.
  - `opk markitdown install` — install via pipx (preferred) or pip --user
  - `opk markitdown status` — check if MarkItDown is installed
  - `opk md-convert <input> <output> [--force]` — convert file to Markdown
  - `opk doc-to-md <input> <output> [--force]` — alias for md-convert
- **`scripts/install-markitdown.sh`** — Linux/macOS installer (dry-run, --yes, python3 + pipx/pip)
- **`scripts/install-markitdown.ps1`** — Windows PowerShell installer (mirrors .sh)
- **`opencode-global/commands/doc-to-md.md`** — agent command documentation
  (guides agents to use `opk` wrapper, never self-install packages)
- **THIRD_PARTY.md** — MarkItDown entry under Opt-in wrapper, section 5
- **README.md** — MarkItDown section with integration model, usage, format table

### Safety

- MarkItDown scripts never: auto-install, vendored source, sudo, curl|sh, read .env/secrets
- MarkItDown scripts never overwrite output without `--force`
- MarkItDown scripts refuse to convert sensitive files (.env, .secret, credential, token)
- MarkItDown is not installed during `opk up`, bootstrap, or shell startup
- bin/opk and bin/opk.ps1 reject md-convert if input file doesn't exist or is sensitive

## [1.6.5] - 2026-06-10

### One Command Update & Cleanup

### Added

- **One Command Update: `opk up`** — Update kit + project bằng một lệnh duy nhất.
  - `opk up` / `opk update` / `opk upgrade` (3 alias, cùng một lệnh)
  - Git pull `--ff-only` an toàn trong kit repo
  - Tự động chạy `install-global.sh --yes` (Linux/macOS) hoặc
    `install-global.ps1 -Yes` (Windows)
  - Nếu pwd là project an toàn (không phải root/system): chạy `opk install --yes`
    + `opk fullstack --yes` + `opk verify`
  - Nếu pwd là root/system: bỏ qua project install, hướng dẫn user `cd` vào
    project thật
  - In version sau update để xác nhận
- **Working tree protection** — `opk up` từ chối nếu working tree dirty, hiển
  thị danh sách file dirty, hướng dẫn user commit hoặc dùng `opk clean`.
  Không tự động stash/reset.
- **Cleanup subcommand: `opk clean`** — Dọn dẹp agent artifact an toàn.
  - Mặc định `--dry-run` (chỉ liệt kê, không động vào file)
  - `opk clean --apply` (trên Linux: gọi `cleanup-agent-artifacts.sh --apply`,
    trên Windows: hướng dẫn chạy trong WSL/Git Bash)
  - `opk up --clean` (update + cleanup apply trong một lệnh)
- **`cleanup-agent-artifacts.sh` patterns mở rộng** — Thêm:
  `GLOBAL_INSTALL_REPORT.md`, `OPK_VERIFY_REPORT.md`, `OPK_DOCTOR_REPORT.md`,
  `RELEASE_NOTES_v*.md`, `.bak.*` đuôi mở rộng
- **Hỗ trợ Windows PowerShell** — `bin/opk.ps1` thêm đầy đủ `up`/`update`/
  `upgrade`/`clean` subcommands, tự động dùng `install-global.ps1` và
  `cleanup-agent-artifacts.sh` (qua WSL/Git Bash) khi cần

### Safety

- `cleanup-agent-artifacts.sh`: thêm dòng TIP ở cuối script hướng dẫn tích hợp
  với `opk clean`/`opk up --clean`
- `bin/opk.ps1`: sử dụng `Test-BadProjectDir` helper (tương tự `is_bad_project_dir`
  trong bash) để tránh install vào root/system directory
- Cơ chế dry-run mặc định: `opk clean` không đụng file trừ khi có `--apply`

## [1.6.4] - 2026-06-10

### Safety & Compatibility Polish

### Added

- **Power Mode vs Safe Mode selection** — `templates/opencode.json` (Power Mode,
  `"permission": "allow"`) giữ nguyên. Thêm `templates/opencode.safe.json`
  (Safe Mode, permission object với read/grep/glob/skill=allow, còn lại=ask)
  và `templates/opencode.power.json` (Power Mode, tương đương opencode.json).
- **`opk mode` CLI subcommand** — `opk mode show` (xem mode hiện tại),
  `opk mode power` (chuyển sang Power Mode), `opk mode safe` (chuyển sang
  Safe Mode). Có backup trước khi ghi đè. Hỗ trợ bash (`bin/opk`) và
  PowerShell (`bin/opk.ps1`).
- **Safety plugin guard** — `templates/plugins/opk-safety-guard.js`: guard
  chặn đọc file nhạy cảm (`.env`, `secret`, `private key`) và command nguy
  hiểm (`rm -rf`, `git reset --hard`, force push, SQL DROP/TRUNCATE/DELETE
  không WHERE). Scripts cài đặt `scripts/install-safety-plugin.sh` +
  `scripts/install-safety-plugin.ps1`. CLI: `opk safety-plugin install`,
  `opk safety-plugin status`.
- **Verify scripts mở rộng** — `verify.sh` + `verify.ps1`: thêm checks cho
  safe/power mode templates, safety plugin guard, và `opk mode` CLI subcommand.
- **Command frontmatter chuẩn hóa** — thêm `subtask:` và `agent:` vào
  frontmatter các command files trong `opencode-global/commands/` để cải
  thiện auto-router.

### Changed

- `VERSION`: 1.6.3 → 1.6.4
- `THIRD_PARTY.md`: v1.6.1 → v1.6.4

### Safety

- Không thêm MCP mặc định
- Không vendored source từ Claude Code/Codex/OpenCode
- Không auto install package khi shell start
- Backward compatible — không phá existing workflows

## [1.6.3] - 2026-06-09

### Fixed

- **Universal Scope Gate — hardened scope drift prevention across ALL agents and commands**.
  Extends v1.6.2 Scope Lock with enforcement at every agent and command entry point:
  - **All 9 strong agents** (`api-strong`, `architect-strong`, `db-strong`, `debug-strong`,
    `devops-strong`, `qa-strong`, `release-strong`, `security-strong`, `ui-ux-strong`): added
    **Scope Gate** — agent only applies for its specific domain. If task is docs-only/read-only,
    STOP and return control to main agent.
  - **6 commands** (`agent-router`, `power-build`, `ci-fix`, `migration-safe`,
    `api-contract-review`, `kit-audit`): added **Scope Guard** — route docs-only away from
    build agents, prevent self-execution on docs-only tasks.
  - **GSD agents** (`gsd-executor`, `gsd-code-fixer`): added **Scope Gate** — prevent
    dispatch for docs-only tasks, no self-transition from docs to code.
  - `verify.sh` / `verify.ps1`: expanded checks — all agents must contain "Scope Gate",
    all commands must contain "Scope Guard".
  - `scripts/validate-opencode-pack.py`: added scope gate/guard validation for all agents
    and commands. EXPECTED_VERSION bumped to 1.6.3.

### Changed

- `VERSION`: 1.6.2 → 1.6.3

### Safety

- No new third-party source
- No new dependencies
- Backward compatible — all existing workflows unaffected

## [1.6.2] - 2026-06-09

### Fixed

- **Docs-only/read-only scope drift fix** — ngăn agent tự chuyển từ task
  docs-only/read-only sang implementation code:
  - `templates/opencode.json`: bỏ `docs/**/*.md` khỏi instructions mặc định.
    Chỉ AGENTS.md + OPENCODE.md được load tự động.
  - `templates/AGENTS.md`: thêm section **Scope Lock — Docs-only / Read-only**
    ở đầu file. Khi user ghi "chỉ kiểm tra", "read-only", "docs-only",
    "không code", "không sửa file" v.v., scope lock kích hoạt tuyệt đối:
    KHÔNG gọi build-strong/power-build/agent-router/build-slice,
    KHÔNG tạo Todo implementation, KHÔNG sửa code, KHÔNG commit/push.
  - `templates/OPENCODE.md`: thêm Scope Lock tương tự, đảm bảo quy trình
    "sửa code" chỉ áp dụng khi task là code/fix/build rõ ràng.
  - `opencode-global/agents/build-strong.md`: thêm **Scope Gate** — build-strong
    chỉ chạy cho feature/bugfix/refactor/code task rõ ràng. Nếu task là
    docs-only/read-only → STOP và trả quyền về main agent.
  - `profiles/node-nest-react-mysql/AGENTS.append.md`: thêm Scope Gate —
    fullstack workflow chỉ chạy khi user yêu cầu code/fix/build.
  - `profiles/node-nest-react-mysql/OPENCODE.append.md`: thêm Scope Gate tương tự.
  - `verify.sh` / `verify.ps1`: thêm checks bắt buộc —
    opencode.json không còn docs/**/*.md, templates có Scope Lock,
    build-strong có Scope Gate, profile append có Scope Gate.

### Changed

- `VERSION`: 1.6.1 → 1.6.2

### Safety

- Không thêm third-party source mới
- Không thêm dependency mới
- Không sửa backend/frontend/database của project khác
- Chỉ sửa markdown/JSON/VERSION trong opencode-power-kit repo
- Không commit, không push

### Backward compatibility

- **100% backward compatible.** Scope Lock là section mới added ở đầu file,
  không xóa section nào. Build-strong vẫn hoạt động cho task code rõ ràng.
  Instructions chỉ bớt `docs/**/*.md` (không load tự động) — docs vẫn đọc
  được khi user chỉ định rõ trong prompt.

## [1.6.1] - 2026-06-08

### Added

- **Detailed Credits / Upstream Projects section** in README with full table:
  - 18 upstreams/tools listed with author, role, integration mode, update path
  - Integration mode definitions: target platform, plugin reference, install-time
    dependency, config-only reference, opt-in wrapper, detect-only, recommended
    ecosystem
- **Quality Scorecard** in README — 6 tiêu chí với điểm số và giải thích trung thực:
  Dễ cài 10/10, Mạnh full-stack 10/10, Workflow agent 10/10, Safety 10/10
  (trusted-local) / 8/10 (power mode), Tài liệu 10/10, Third-party packaging 10/10
- **How to Update Upstreams** section — hướng dẫn update cho BMAD, GSD Core,
  Superpowers, detect-only tools, và kit itself
- **THIRD_PARTY.md** viết lại hoàn toàn:
  - Header version sửa từ v1.3.4 → v1.6.1
  - Chính sách rõ ràng 9 mục: không bundled source, không auto-update, opt-in, detect-only
  - Integration modes table 7 dòng
  - Full component table 18 dòng với license notes
  - BMAD mô tả đúng: install-time dependency (không còn ghi "bundled in-tree")
  - Superpowers mô tả đúng: plugin reference (không còn ghi "bundled in-tree")
  - Detect-only tools bảng chi tiết 14 tool với detection path
  - Update policy cho từng nhóm
  - License notes cho từng upstream
- Số liệu README chính xác hơn:
  - Core agents: 13 core + 33 GSD companions = 46 total
  - Scripts: 13 helper scripts + 15 root-level scripts

### Changed

- `VERSION`: 1.6.0 → 1.6.1
- `THIRD_PARTY.md`: sửa version drift, mô tả chính xác BMAD (install-time
  dependency, không bundled) và Superpowers (plugin reference, không bundled)
- `README.md` component table: scripts 12 → 13, thêm "total agent files 46",
  thêm "root-level scripts 15"
- README version badge: 1.6.0 → 1.6.1

### Safety

- Không thêm third-party source mới
- Không thêm dependency mới
- Không thêm auto-update behavior
- Không sửa .env, secrets, token
- Không sửa backend/frontend/database của project khác
- Chỉ sửa markdown/VERSION trong opencode-power-kit repo

## [1.6.0] - 2026-06-08

### Added

- **Full Auto Permission Mode v1.6.0** — nâng cấp từ safe-first granular
  allowlist lên `"permission": "allow"`:
  - `templates/opencode.json`: `permission` block → `"permission": "allow"`.
  - `templates/AGENTS.md`: section "Auto Safe Permission Mode" → "Full Auto
    Permission Mode" với 6 safety rules tự tuân thủ.
  - `templates/OPENCODE.md`: thêm section "Full Auto Permission Mode".
  - README: section "Auto Safe Permission Mode v1.5.1" → "Full Auto
    Permission Mode v1.6.0".
  - Agent có thể tự chạy tool/sửa file/tạo file/bash/test/build mà không
    hỏi lại permission — phù hợp máy/project cá nhân.
  - Safety rules enforced bằng instruction (không phải permission prompt):
    không tự `git push`, `git reset --hard`, `git clean -fd`, không xóa
    file hàng loạt, không sửa `.env`/secrets, `git status` trước task lớn,
    `git diff --stat` + báo cáo tiếng Việt sau task.

- **Vietnamese Language Lock** — rule bắt buộc cho agents/rules:
  - Templates: thêm section "Vietnamese Language Lock" vào `templates/AGENTS.md`,
    `templates/OPENCODE.md`.
  - Profile: thêm section vào `profiles/node-nest-react-mysql/AGENTS.append.md`,
    `profiles/node-nest-react-mysql/OPENCODE.append.md`.
  - Agents: thêm `Vietnamese Language Lock` instruction cho tất cả 46 agent files
    trong `opencode-global/agents/*.md`.
  - README: thêm mục "Vietnamese Language Lock" mô tả policy.
- **Tương tác ưu tiên tiếng Việt:** Agents mặc định trả lời bằng tiếng Việt. Giữ
  tiếng Anh cho code, lệnh, path, log, keyword kỹ thuật. Không tự chuyển sang
  tiếng Anh. User có thể override bằng tiếng Anh.
- **Không thêm dependency:** Tính năng chỉ dùng markdown/config — không thêm repo,
  package, hay logic installer mới.

### Backward compatibility

- **100% backward compatible.** Tất cả section mới đều additive. Không file nào bị
  xóa, đổi tên hay thay đổi behavior.
- Template install idempotent (marker-based append vẫn chạy).

## [1.5.0] - 2026-06-08

### Added

- **9 new agents** — opencode-power-kit giờ có tổng cộng 13 agents:
  - `architect-strong` — system architecture, ADR, design decisions
  - `debug-strong` — deep debug với scientific method, checkpoint
  - `qa-strong` — QA/testing, coverage analysis, regression testing
  - `security-strong` — SAST, secret scan, threat model, dependency audit
  - `db-strong` — schema design, migration safety, query optimization
  - `api-strong` — API contract, OpenAPI spec, FE/BE sync, type generation
  - `ui-ux-strong` — UI/UX review, accessibility, responsive design
  - `devops-strong` — Docker, CI/CD, deploy, infrastructure
  - `release-strong` — version bump, CHANGELOG, tag, publish
- **7 new commands** (34 commands total):
  - `/agent-router` — tự động route task sang agent chuyên môn
  - `/ci-fix` — đọc lỗi CI/test/build rồi sửa an toàn
  - `/e2e-flow` — lập và chạy E2E proof với Playwright
  - `/release-check` — kiểm tra VERSION/README/CHANGELOG/tag trước release
  - `/kit-audit` — audit chính opencode-power-kit (cấu trúc, version, agents)
  - `/power-build` — workflow tổng hợp spec→architecture→impl→QA→security→release
  - `/tooling-doctor` — detect third-party tooling (rtk, repomix, semgrep, ...)
- **`scripts/opk-command-guard.sh`** — safety guard cho shell commands: cảnh
  báo/chặn `rm -rf`, `git reset --hard`, `git clean -fd`, force push,
  `DROP TABLE`, `DELETE FROM` không WHERE. Có allowlist cho thao tác an toàn.
  Có thể source vào shell (PROMPT_COMMAND) hoặc dùng độc lập.
- **`build-strong` Agent Delegation** — agent build-strong giờ có hướng dẫn
  spawn 9 subagent chuyên môn theo context: architect cho design, debug-strong
  cho lỗi phức tạp, db-strong cho migration, api-strong cho contract, v.v.
- **Power Mode** — workflow `/power-build` tích hợp tất cả agents: spec →
  architecture → implementation → QA → security → release. Một câu lệnh duy
  nhất cho toàn bộ lifecycle.
- **README Power Mode section** — hướng dẫn dùng 13 agents + 34 commands với
  bảng agent routing và use cases.
- **`THIRD_PARTY.md` tooling policy** — thêm section "Third-Party Tooling
  Policy" liệt kê các tools detect-only và quy tắc: không vendor source,
  không auto-update, detect-only hoặc gọi official CLI.

### Backward compatibility

- **100% backward compatible.** Tất cả agent/command hiện có giữ nguyên tên,
  mode, frontmatter, permission.
- `verify.sh` / `verify.ps1` thêm checks cho v1.5.0 content.
- `validate-opencode-pack.py` version pin lên 1.5.0, thêm needles cho agents
  mới, commands mới, guard script.

## [1.4.0] - 2026-06-08

### Added

- **`build-strong` → fullstack-autopilot** — agent `build-strong` được nâng
  cấp thành fullstack-autopilot với quy trình tự động 9 bước:
  1. Git status & detect stack (backend/frontend/database/scripts).
  2. Checkpoint trước sửa lớn (≥ 3 file hoặc migration).
  3. Spec ngắn + acceptance criteria + API contract scope.
  4. Plan-work chia vertical slice (≤ 2 file, ≤ 100 dòng diff).
  5. Build từng slice — đảm bảo contract DB ↔ BE ↔ FE khớp.
  6. Verify: chạy lint/typecheck/test/build nếu có; manual proof nếu không.
  7. Cleanup file tạm qua `/cleanup-safe`.
  8. Handoff qua `/handoff-save` nếu task lớn.
  9. Báo cáo cuối: file sửa, lý do, slice count, verify result, git status.
- **12 Hard Rules an toàn** trong agent prompt: không `rm -rf`, không
  `git reset --hard`, không `git clean -fd`, không force push, không sửa
  `.env`/secrets, không DROP/TRUNCATE/DELETE không hỏi, không tự push,
  không xóa tracked files, không đọc toàn repo, mỗi slice ≤ 100 dòng diff,
  luôn `git status` trước/sau, luôn báo cáo cuối.
- **Layer-specific hướng dẫn kỹ thuật** — backend (NestJS/Express/Django/
  Rails), frontend (React/Next.js/Vue), database (Prisma/TypeORM/migration)
  với các kỹ thuật đặc thù từng layer.
- **README section "Dùng build-strong cho fullstack-auto"** — hướng dẫn
  chi tiết cách dùng agent build-strong cho fullstack task.

### Backward compatibility

- **100% backward compatible.** Agent vẫn tên `build-strong`, mode `all`,
  không thay đổi frontmatter hay permission structure.
- Tất cả commands/skills/scripts hiện có không bị ảnh hưởng.
- `verify.sh` / `verify.ps1` thêm check build-strong content để đảm bảo
  agent đã được nâng cấp.

## [1.3.4] - 2026-06-06

### Added

- **GSD Core opt-in integration** — `opk gsd` and `opk update-gsd`
  forward to the official GSD Core installer
  (`npx @opengsd/gsd-core@latest`). The kit does NOT vendor or
  copy GSD source. Supported via:
  - `scripts/install-gsd-core.sh` (Linux / macOS / Git Bash / WSL)
  - `scripts/install-gsd-core.ps1` (Windows PowerShell)
  Both check `node`/`npm`/`npx`, print the planned command,
  ask for confirmation, and forward to `npx`. Pass `--dry-run`
  to plan, `--yes` to skip the prompt.
- **`opk update-all`** — pulls kit updates via
  `git pull --ff-only` (no reset, no force push), refreshes the
  bundled `_bmad/` module pack, and optionally runs
  `update-gsd` when `--with-gsd` is passed.
- **`THIRD_PARTY.md`** — explicit list of every third-party
  integration (BMAD, Superpowers, GSD Core, rtk/tokscale) with
  the rule: the kit NEVER vendors third-party source, and
  NEVER auto-updates on shell start.
- **`.github/workflows/verify.yml`** — a focused v1.3.4 verify
  workflow that runs `verify.sh`, `verify.ps1`, the python
  validator, the integration test, plus `bash -n`,
  `shellcheck`, and `shfmt` checks. Runs alongside the
  existing comprehensive `ci.yml` (no behavior removed).
- **`scripts/validate-opencode-pack.py`** — v1.3.4 compliance
  section added: pins `EXPECTED_VERSION = "1.3.4"`, checks
  `THIRD_PARTY.md` exists and references BMAD / Superpowers /
  GSD Core, and checks `CHANGELOG.md` mentions v1.3.3 / v1.3.4
  needles. The v1.3.3 structural validation (frontmatter on
  commands/agents/skills, profiles, openapi templates) is
  preserved.

### Improved

- **`verify.sh` VERSION read is now explicit** — reads
  `${KIT_DIR}/VERSION` instead of relying on `<VERSION` from
  the script's CWD. If `VERSION` is missing, the script WARNS
  and continues with the rest of the checks instead of
  crashing (this fixes a confusing failure mode on partial
  syncs).
- **`verify.ps1`** — same explicit read-from-`$KitDir\VERSION`
  behavior, same graceful warning on missing file.
- **Auto Router presence check** — both `verify.sh` and
  `verify.ps1` now require the *Natural Language Auto Router*
  to be present in `templates/AGENTS.md` and
  `templates/OPENCODE.md`.

### Backward compatibility

- **100% backward compatible.** No v1.3.0 → v1.3.3 command,
  file, or directory was renamed or removed.
- All new subcommands are additive to `bin/opk` (`gsd`,
  `update-gsd`, `update-all`); all existing subcommands
  (`global`, `install`, `bootstrap`, `doctor`, `verify`,
  `update-bmad`, etc.) still work.
- Optional integration is **opt-in**; the kit still works
  perfectly without ever invoking `opk gsd`.
- Existing `ci.yml` workflow (10 jobs) is untouched and
  still gates every PR.


## [1.3.3] - 2026-06-06

### Added

- **`/cleanup-safe` command** (`opencode-global/commands/cleanup-safe.md`)
  — dọn file tạm/debug/repro an toàn. Default dry-run; `--apply` chỉ
  **MOVE** file vào `.opk-trash/YYYYMMDD-HHMMSS/`, không bao giờ xóa.
  Không chạm tracked file, không chạm protected dirs
  (`src/`, `app/`, `backend/`, `frontend/`, `prisma/`, `migrations/`,
  `public/`, `docs/`, `.git/`, `.opencode/`, `.agents/`, `_bmad/`).
- **`scripts/cleanup-agent-artifacts.sh`** — backing script cho
  `/cleanup-safe`. `set -euo pipefail`, `--dry-run` / `--apply`,
  refuses to run ngoài git work-tree.
- **`/handoff-save` command** (`opencode-global/commands/handoff-save.md`)
  — tạo / cập nhật `AI_HANDOFF.md` để làm project dài không đứt
  context. Dùng `templates/AI_HANDOFF.md` làm template, **không ghi
  đè** file user đã có.
- **`templates/AI_HANDOFF.md`** — short, machine-friendly template
  (goal, stack, current task, what changed, files changed, commands
  run, tests/verification, known issues, next steps).
- **`/checkpoint` command** (`opencode-global/commands/checkpoint.md`)
  — snapshot working tree ra `.opk-checkpoints/<ts>.patch` +
  `.summary.md` trước khi sửa lớn. Không commit, không reset,
  không force push. Restore bằng `git apply`.
- **Natural Language Auto Router** — đã thêm vào `templates/AGENTS.md`
  và `templates/OPENCODE.md`. Map 5 casual request (Vietnamese +
  English) sang safe workflow: bugfix, project health, feature,
  token-smart, cleanup. Slash command luôn thắng auto-router.
- **README quick-start** — 5 câu tự nhiên phổ biến ở đầu README;
  advanced slash command list chuyển xuống dưới để dễ dùng hơn.

### Improved

- `.gitignore` thêm `.opk-trash/`, `.opk-checkpoints/`, `.opk-scratch/`
  để các thư mục safety của v1.3.3 không bao giờ lọt vào commit.
- `verify.sh` thêm 8 check cho v1.3.3 (3 new commands, 1 new script,
  AI_HANDOFF template, Auto Router presence, VERSION pin).

### Backward compatibility

- **100% backward compatible.** Không command / file / folder nào
  của v1.3.0 → v1.3.2 bị xóa, đổi tên, hay thay đổi behavior.
- Mọi thay đổi đều additive. Existing `bootstrap.sh` /
  `bootstrap.ps1` / `install.sh` / `verify.sh` vẫn chạy nguyên xi
  với kit v1.3.3.

## [1.3.2] - 2026-06-06

### Added

- **`opk one` / `opk go` — all-in-one shorthand** — chạy 1 lệnh duy nhất để
  cài **global + project + fullstack + verify** trong project hiện tại.
  Bash: `opk one` = `bootstrap.sh --all --project-dir "$(pwd)" --yes`.
  PowerShell: `opk one` = `bootstrap.ps1 -All -ProjectDir $Pwd -Yes`.
  Trùng behavior với all-in-one one-liner.
- **4-step `--all` flow** — `bootstrap.sh` / `bootstrap.ps1` / `setup.sh` /
  `setup.ps1` giờ log rõ `[1/4] global` → `[2/4] project` → `[3/4] fullstack`
  → `[4/4] verify`. `verify.sh` chạy cuối để check mọi thứ đã sẵn sàng.
  Idempotent, nếu pwd nguy hiểm thì skip `[2/4] + [3/4] + [4/4]` với cảnh báo
  rõ hướng dẫn `cd` sang project.
- **All-in-one one-liner** — README trình bày 1 dòng duy nhất cho cả bash
  (Linux/macOS/WSL/Git Bash) và PowerShell (Windows) để cài all-in-one
  từ project dir: tự clone/pull kit, chạy `bootstrap --all --project-dir`,
  rồi `verify`, in `✅ OpenCode Power Kit all-in-one done. Run: opencode`.
- **Final success banner** — `bootstrap.sh` / `bootstrap.ps1` cuối cùng
  in `✅ OpenCode Power Kit all-in-one done. Run: opencode` thay vì
  banner trống — người dùng thấy ngay bước tiếp theo.
- **`opk all` chạy verify** — `bin/opk` (bash) và `bin/opk.ps1`
  (PowerShell) giờ thêm `[4/4] verify.sh` ở cuối flow `[1/3]` →
  `[1/4]`. Bad-dir guard thông báo skip cả 3 bước project+fullstack+verify.

### Changed

- **`bin/opk one` đổi semantics** — trước v1.3.2 là alias cho
  `bootstrap.sh --global --yes` (chỉ cài global). Từ v1.3.2 là alias cho
  `bootstrap.sh --all --project-dir "$(pwd)" --yes` (all-in-one).
  Muốn cài global nhanh: dùng `opk quick` hoặc `opk global`.
- **`bin/opk` help text** — bảng lệnh giờ có `opk one`, `opk go`,
  `opk update-bmad`; thêm 2 ví dụ all-in-one one-liner (bash +
  PowerShell) với one-command cd + clone + bootstrap --all + verify.
- **`README.md` "Cài 1 lệnh" → "Cài all-in-one bằng 1 lệnh (khuyến
  nghị)"** — top section giờ là all-in-one one-liner + `opk one` /
  `opk go` workflow. Section "Cài thủ công / Advanced" giữ nguyên cho
  ai muốn kiểm soát từng bước. Opk command table bổ sung `opk one`,
  `opk go`, `opk update-bmad`.
- **`bootstrap.sh` / `bootstrap.ps1` `do_all` log format** — đổi
  `[1/N]...[2/N]...[3/N]` (N là số bước thật) thành `[1/4]...[2/4]...
  [3/4]...[4/4]` cố định. Step nào skip sẽ in `[X/4 + Y/4] BỎ QUA`.
- **`setup.sh` / `setup.ps1` `do_all` log format** — đổi `[1/3]`
  thành `[1/4]`, thêm bước `[4/4] verify.sh`. Print plan cũng đổi.

### Backward compatible

- `--global`, `--project`, `--fullstack`, `--doctor`, `--dry-run`,
  `--yes` không đổi.
- `opk global`, `opk install`, `opk fullstack`, `opk all`, `opk doctor`,
  `opk verify`, `opk tools`, `opk bootstrap`, `opk quick`, `opk init`
  không đổi behavior.
- `opk one` thay đổi semantics (global → all-in-one); ai phụ thuộc
  behavior cũ dùng `opk quick` hoặc `opk global` thay thế.
- `opk update-bmad` đã có ở v1.3.1, v1.3.2 chỉ nhắc lại trong help.

## [1.3.1] - 2026-06-05

### Added

- **`BMAD_METHOD_VERSION` pin** — mặc định `6.8.0`, override qua env
  `BMAD_METHOD_VERSION=...` trước khi chạy `install.sh` / `install.ps1`
  / `update-bmad.sh`. Reproducible, lockfile-friendly.
- **Full log capture cho BMAD** — `install.sh` đổ output vào
  `.opencode-power-bmad-install.log`; `update-bmad.sh` đổ vào
  `.opencode-power-bmad-update.log`. Fail path in `tail -50` + đường
  dẫn log rõ ràng.
- **`LICENSE` (MIT)** + README badge `BMAD Method v6.8.0`.
- **README section "Cấu hình BMAD"** — bảng env + ví dụ pin version +
  vị trí log file.
- **README section "Cài thủ công / Advanced"** — chuyển nội dung
  "Dùng nhanh 30 giây" thành section riêng với bash + PowerShell
  instructions; giữ 1-liner canonical ở đầu.
- **Tree trong README** cập nhật: `bin/opk`, `bin/opk.cmd`, `bin/opk.ps1`,
  `install.sh`, `install.ps1`, `bootstrap.sh`, `bootstrap.ps1`, `setup.ps1`,
  `uninstall.ps1`, `update-bmad.sh`.

### Changed

- **`install.sh`** — thêm `BMAD_METHOD_VERSION` (default 6.8.0, env
  override), full log vào `.opencode-power-bmad-install.log`, fail
  message in `tail -50` + log path. Đồng bộ `is_bad_project_dir`
  (HOME, kit, `/`, `/tmp`, `/var/tmp`, `/usr`, `/etc`) với
  `bootstrap.sh` / `setup.sh`. Sửa `SC2129` (grouped here-doc append).
- **`install.ps1`** — thêm `$BmadVersion` (default 6.8.0, env override),
  full log capture, `$LASTEXITCODE` check + `tail -50` + fail message
  với log path. Đồng bộ `Test-BadProjectDir` (HOME, kit, `C:\`,
  `C:\Windows`, `C:\Program Files*`, `$env:TEMP`/`$env:TMP`) với
  `bootstrap.ps1`. Cải thiện error reporting.

### Round 2 - hardened identity & install paths

### Added

- **`OPK_USER_NAME` / `$OpkUserName` chain** — user-name cho BMAD
  Method install giờ lấy theo thứ tự: `OPK_USER_NAME` env →
  `git config user.name` → `${USER:-User}` (bash) /
  `${env:USERNAME}` → `'User'` (PowerShell). Không còn hardcode
  `--user-name nha` ở bất kỳ đâu trong installer. Override được.
- **`update-bmad.ps1`** — Windows parity với `update-bmad.sh`:
  `$BmadVersion` env, `$OpkUserName` chain, `Test-BadProjectDir`
  đồng bộ kit allowlist, `$LASTEXITCODE` check, full log
  `.opencode-power-bmad-update.log`, `tail -50` trên fail, hiển thị
  `.bmad` modules khi xong.
- **`opk update-bmad`** — thêm subcommand vào `bin/opk` (bash) và
  `bin/opk.ps1`. Forward flags xuống `update-bmad.{sh,ps1}`. Trùng
  pattern với `opk install` (refuse nếu pwd nguy hiểm).
- **Test/CI scratch allowlist** — `is_bad_project_dir` /
  `Test-BadProjectDir` ở `install.sh`, `install.ps1`,
  `update-bmad.sh`, `update-bmad.ps1`, `bootstrap.sh`,
  `bootstrap.ps1`, `setup.sh`, `setup.ps1`, `bin/opk`,
  `bin/opk.ps1`, `scripts/install-fullstack-profile.sh` cho phép
  `$KIT_DIR/.tmp` và `$KIT_DIR/.test` (test scratch only). Mọi
  project install thật vẫn bị từ chối đúng như cũ.
- **CI `pwsh-syntax` job** — syntax-check mọi `*.ps1` qua
  `[System.Management.Automation.Language.Parser]::ParseFile` (cài
  `pwsh` qua snap hoặc Microsoft apt repo, fail-soft nếu OS không
  hỗ trợ).
- **CI `bash-syntax` mở rộng** — `bash -n` giờ scan toàn bộ
  `*.sh` trong repo + `bin/opk` + `bootstrap.sh` + `setup.sh`
  qua `find`, không cần duy trì allowlist thủ công.
- **`.gitignore`** ở kit root + `templates/gitignore-extra.txt`
  ignore `.tmp/`, `.test/`, `.opencode-power-*.log` để scratch
  dirs và log files không bị commit nhầm.

### Changed

- **`install.sh` / `update-bmad.sh` / `install.ps1`** — bỏ
  `--user-name nha` hardcode; dùng `$OPK_USER_NAME` / `$OpkUserName`
  (xem chain ở phần Added). Info line + install report hiển thị
  user name thật đang dùng.
- **`install-global.sh`** — RC marker giờ là single block gồm
  `OPK_KIT_DIR="$KIT_REAL"` + `OPENCODE_CONFIG_DIR="$OPK_KIT_DIR/
  opencode-global"`; idempotent (không duplicate), safe REPLACE
  bằng `python3` in-place edit khi block đã tồn tại mà khác nội
  dung. `PATH_MARKER` cho `~/.local/bin` cũng idempotent. Không
  còn hardcode `$HOME/opencode-power-kit/opencode-global` ở bất
  kỳ đâu trong file.
- **`integration-test.sh`** viết lại hoàn toàn:
  - Scratch dir = `$KIT_DIR/.tmp/opk-integration-XXXXXX` (KHÔNG
    dùng `/tmp`; `install.sh` block `/tmp`).
  - `trap cleanup EXIT` để cleanup kể cả khi fail.
  - Stub `npx` ở PATH giả: log mọi invocation ra file, mock
    BMAD install để tạo `_bmad/`, `.agents/skills/`,
    `.opencode/commands/`, `.opencode/agents/` (chỉ tạo khi
    chưa có — không overwrite file install.sh đã copy từ
    template).
  - **Regression guards**:
    - Grep `--user-name nha` trong `*.sh`/`*.ps1`/`*.cmd` (trừ
      `.tmp`/`.test`/`.bak`/`.orig`) → phải rỗng.
    - Grep `$HOME/opencode-power-kit/opencode-global` trong
      `install-global.sh` → phải rỗng.
  - **NPX call assertions**: stub log phải có
    `bmad-method@<semver>`, `--modules bmm`, `--tools opencode`,
    `--user-name <fallback>` (không phải `nha`).
  - Chạy offline hoàn toàn (stub npx không gọi mạng).
- **`update-bmad.sh`** — thêm `BMAD_METHOD_VERSION` + log capture +
  fail handling. Đồng bộ safety guard.
- **CI strict** — `.github/workflows/ci.yml` bước `shellcheck` và
  `shfmt -d` bỏ `|| echo "skip..."` / `|| true`. Bất kỳ warning nào
  fail CI. Cài `shellcheck` qua `apt-get` (fail nếu không được).
- **`shfmt -w` toàn bộ `.sh`** — conform canonical style (tab indent,
  `name() {` single space, no space before `>>file`). 15 file đã format
  lại. `git diff --check` clean.
- **`README.md`** restructured: bootstrap 1-liner là canonical,
  "Cài thủ công / Advanced" là section riêng, cập nhật cây thư mục,
  document `BMAD_METHOD_VERSION=6.8.0`.
- **`VERSION`** 1.3.0 → 1.3.1.

### Fixed

- **`shellcheck` cleanup**:
  - `setup.sh` — bỏ biến `SCRIPTS_DIR` và `BAD_PROJECT_DIRS` dead
    code (SC2034).
  - `install-global.sh` — thêm `# shellcheck disable=SC2016,SC2088,SC2034`
    (literal `$HOME`/`$PATH` trong marker payloads, display tildes,
    `SAFE` flag).
  - `doctor.sh` — disable SC2088 (display tildes).
  - `scripts/install-fullstack-profile.sh` — bỏ `MARKER_END` dead.
  - `uninstall.sh` — disable SC2043 (single-element for loop intentional).
- **Bash canonical style** — `name() { ... }` (không phải `name()  { ... }`)
  trên toàn bộ script.
- **Shellcheck + shfmt** clean trên 100% `.sh` files (10 files).

### Safety (giữ nguyên + mở rộng)

- Không sudo, không `curl|sh` trong bất kỳ script nào (bash + PowerShell).
- `install.sh` / `install.ps1` / `update-bmad.sh` đồng bộ safety
  guard với `bootstrap.{sh,ps1}` và `setup.{sh,ps1}`: từ chối cài
  trong HOME, kit, root drive, system dirs, temp dirs.
- PowerShell: check `$LASTEXITCODE` của `npx`; fail rõ ràng thay vì
  silent.
- Bash: `npx ... >"$BMAD_LOG" 2>&1` — log đầy đủ vào file để debug
  nếu cần.
- License: MIT, copyright 2026.

### Compatibility

- Tương thích ngược 100% với v1.3.0. Mọi script / flag / lệnh cũ
  vẫn chạy. Thay đổi chỉ là hardening (BMAD pin + log capture +
  exit code check + safety sync + CI strict + shfmt style).

## [1.3.0] - 2026-06-04

### Added — Cross-platform (Linux / macOS / Windows PowerShell)

- **`bootstrap.sh`** (root, Linux/macOS/Git Bash/WSL): one-command installer
  với flags `--global`, `--project`, `--fullstack`, `--all`, `--project-dir`,
  `--doctor`, `--dry-run`, `--yes`, `--help`. Tự chạy `setup.sh --global --yes`,
  cập nhật `PATH` cho session hiện tại, in `opk path` + `opk version` +
  `opk doctor`. Từ chối project install trong `$HOME`, kit dir, `/`, `/tmp`,
  `/var/tmp`, `/usr`, `/etc`. Không sudo, không `curl|sh`.
- **`bootstrap.ps1`** (root, Windows PowerShell): mirror PowerShell của
  `bootstrap.sh`. Params `-Global`, `-Project`, `-Fullstack`, `-All`,
  `-ProjectDir`, `-Doctor`, `-DryRun`, `-Yes`, `-Help`. Cập nhật `$env:Path`
  cho session hiện tại, gọi `opk.cmd path`/`version`/`doctor`. Từ chối project
  install trong `$HOME`, kit dir, `C:\`, `C:\Windows`, `C:\Program Files*`,
  `$env:TEMP`/`$env:TMP`. Không admin, không sudo, không in secret.
- **`setup.ps1`** (root, Windows PowerShell): menu tiếng Việt 7 mục + 7 params
  non-interactive. Tương đương `setup.sh`. Từ chối per-project install trong
  các root nguy hiểm (HOME, kit, `C:\`, `C:\Windows`, `C:\Program Files*`,
  TEMP/TMP). Idempotent.
- **`install-global.ps1`** (root, Windows PowerShell): cài global không cần
  admin. Tạo `$HOME\.opencode-power-kit\bin`, cài shim `opk.cmd` + `opk.ps1`,
  set User env `OPK_KIT_DIR` + `OPENCODE_CONFIG_DIR`, add `$HOME\.opencode-power-kit\bin`
  vào User PATH (idempotent), cập nhật `$env:Path` cho session hiện tại. Backup
  file cũ vào `$HOME\.opencode-power-kit-backup-<ts>\`. Tạo
  `GLOBAL_INSTALL_REPORT.md` + `GLOBAL_PACK_REPORT.md` động. Không sửa
  registry system-wide, chỉ User environment.
- **`install.ps1`** (root, Windows PowerShell): mirror `install.sh`. Copy
  templates, merge `.gitignore` (idempotent), copy `knip.json`/`lefthook.yml`
  (skip nếu đã có), chạy `npx bmad-method install`, tạo report.
- **`scripts/install-fullstack-profile.ps1`**: PowerShell port của
  `install-fullstack-profile.sh`. Append AGENTS/OPENCODE qua marker
  idempotent, copy commands + skills, backup file user.
- **`bin/opk.ps1`** (Windows PowerShell CLI wrapper): mirror `bin/opk`. Hỗ trợ
  `help`, `version`, `path`, `global`, `install`/`init`, `fullstack`, `all`,
  `doctor`, `verify`, `tools`, `bootstrap`, `one`, `quick`. Dùng `OPK_KIT_DIR`
  nếu có, fallback tự detect từ vị trí script. Không duplicate logic.
- **`bin/opk.cmd`** (Windows CMD shim): gọi `opk.ps1` qua
  `powershell -ExecutionPolicy Bypass -File`. Cần `OPK_KIT_DIR` env (set bởi
  `install-global.ps1`).
- **`doctor.ps1`** (Windows PowerShell): mirror `doctor.sh`. Check git, PS
  version, `OPK_KIT_DIR`, `OPENCODE_CONFIG_DIR`, User PATH có
  `.opencode-power-kit\bin`, `opk.cmd`/`opk.ps1` tồn tại, opencode-global
  agents/commands/skills, không MCP config, secret pattern scan, 13 optional
  tools. WARN nếu thiếu optional, không fail. Tạo `OPK_DOCTOR_REPORT.md`.
- **`verify.ps1`** (Windows PowerShell): mirror `verify.sh`. Check project
  files (`AGENTS.md`, `OPENCODE.md`, `.opencode\opencode.json`,
  `.agents\skills`, `.opencode\commands`) + secret pattern scan. Tạo
  `OPK_VERIFY_REPORT.md`. Không in secret.

### Added — Bash improvements

- **`bin/opk` bash thêm 4 lệnh mới**:
  - `opk init` — alias của `opk install`.
  - `opk quick` — alias của `opk global` (cài global nhanh).
  - `opk bootstrap` — gọi `bootstrap.sh` (cài 1 lệnh cross-platform).
  - `opk one` — alias `bootstrap.sh --global --yes`.
- **Help text** `opk help` thêm 3 mục: Linux/macOS one-command, Windows
  PowerShell one-command, Project one-command.

### Changed — install-global.sh

- **zsh support** (macOS 10.15+ default shell): phát hiện `$SHELL` ends with
  `zsh` HOẶC `~/.zshrc` tồn tại → thêm markers vào cả `~/.zshrc`. Vẫn giữ
  `~/.bashrc` cho Linux/WSL/Git Bash. Không duplicate marker (idempotent).
- **Helper `add_rc_marker`**: function dùng chung, tránh duplicate logic
  giữa bash/zsh. Marker pattern giữ nguyên format cũ.
- **Secret scan** mở rộng: check cả `~/.zshrc` (không chỉ `~/.bashrc`).
- **Backup** thêm `~/.zshrc` nếu tồn tại.

### Changed — README.md

- Thêm section **"Cài 1 lệnh"** ở đầu với 3 phần: Linux/macOS one-liner,
  Windows PowerShell one-liner, Project one-command.
- Thêm badge `cross-platform`.
- Bump version badge 1.2.0 → 1.3.0.

### Safety (giữ nguyên + mở rộng)

- Không sudo, không `curl|sh` trong bất kỳ script nào (bash + PowerShell).
- Không in `token`, `password`, `secret`, `api_key`, `.env` value.
- Không sửa `~/.config/opencode/opencode.json` của user.
- Không xóa file user.
- **Windows**: không sửa registry system-wide — chỉ `User` environment
  (qua `[Environment]::SetEnvironmentVariable(..., 'User')`).
- Backup trước khi sửa config / PATH / profile / opk shim.
- Tất cả script đều **idempotent**: chạy lại không duplicate marker, PATH,
  config, shim, report.

### Compatibility

- **Tương thích ngược 100% với v1.2.0**. Mọi script / flag / lệnh cũ vẫn
  chạy. Thêm mới: PowerShell port + `bootstrap.{sh,ps1}` + 4 lệnh mới
  cho `opk` (`init`/`quick`/`bootstrap`/`one`).

## [1.2.0] - 2026-06-04

### Added

- **`setup.sh`** (root): menu tiếng Việt tương tác 7 mục + 7 cờ
  non-interactive (`--global`, `--project`, `--fullstack`, `--all`,
  `--doctor`, `--dry-run`, `--yes`, `--help`). Từ chối chạy per-project
  install trong HOME hoặc trong chính kit. Báo lỗi rõ khi thiếu script
  con. Idempotent: chạy nhiều lần không phá.
- **`bin/opk`** (CLI wrapper): thin wrapper gọi lại các script sẵn có —
  `help`, `version`, `path`, `global`, `install`, `fullstack`, `all`,
  `doctor`, `verify`, `tools`. Tự phát hiện đường dẫn kit qua
  `BASH_SOURCE` hoặc `OPK_KIT_DIR`. Không duplicate logic.
- **`install-global.sh` cải tiến**:
  - Tự cài `opk` vào `~/.local/bin/opk` (backup file cũ nếu tồn tại
    vào `$HOME/.opencode-power-kit-backup-<ts>/local-bin/opk`).
  - Đảm bảo `~/.local/bin` trong `PATH`, cảnh báo nếu chưa có trong
    shell hiện tại.
  - Verify `opk path` chạy được sau khi cài.
  - Tạo `GLOBAL_PACK_REPORT.md` động: liệt kê đúng agents/commands/
    skills đang có trong `opencode-global/`, kèm vị trí `opk` CLI và
    trạng thái PATH.
  - Backup thêm `~/.local/bin/opk` vào cùng thư mục backup.

### Changed

- `README.md`: thêm section "Dùng nhanh trong 30 giây" ở đầu, bảng
  lệnh `opk`, mục "Có gì mới trong v1.2.0", cập nhật sơ đồ thư mục.
- `VERSION`: bump 1.1.1 → 1.2.0.

### Safety (giữ nguyên policy)

- Không sudo, không `curl|sh` trong bất kỳ script nào.
- Không in `token`, `password`, `secret`, `api_key`, `.env` value.
- Không sửa `~/.config/opencode/opencode.json` của user.
- Không xóa file project. Backup trước khi sửa `~/.bashrc`,
  `~/.config/opencode/opencode.json`, `~/.local/bin/opk`.
- Tất cả script `setup.sh`, `bin/opk`, `install-global.sh` đều
  idempotent — chạy lại không tạo duplicate marker / không ghi đè
  file user nếu chưa backup.

### Compatibility

- Tương thích ngược 100% với v1.1.1. Mọi script / flag / lệnh cũ
  (`install.sh`, `install-global.sh`, `verify.sh`, `doctor.sh`,
  `uninstall.sh`, `update-bmad.sh`, `scripts/install-*.sh`) đều chạy
  bình thường. `setup.sh` và `opk` chỉ là lớp tiện ích bên ngoài.

## [1.1.1] - 2026-06-04

### Fixed

- `.github/workflows/ci.yml`: bước `Validate YAML in templates/` chứa
  `python3 -c` với line continuation `\` làm vỡ YAML block scalar. Rewrite
  thành bash multi-line dùng `set +e` + retry sau `pip install pyyaml`. CI
  giờ parse được `ci.yml` + chạy được job `yaml-templates`.
- `scripts/integration-test.sh`, `doctor.sh`, `uninstall.sh`: expand 3 cụm
  one-liner function (`info/ok/warn/err`) thành multi-line cho style chuẩn.
- Markdown headings + code fences: scan toàn repo, không có heading level
  bị skip, không có code fence mất cân.
- Secret scan: clean (loại trừ `CHANGELOG.md`, `README.md`, `doctor.sh`,
  `docs/*`; command `secret-scan.md` đã viết lại pattern ví dụ để không
  match regex nữa).

### Notes

- Không thêm file mới, không đổi logic.
- `v1.1.0` tag giữ nguyên — commit v1.1.0 vẫn tồn tại ở `4114471` cho ai
  tham chiếu; release "sạch" ở main là `v1.1.1`.

## [1.1.0] - 2026-06-04

### Added

- **Full-stack profile** (`profiles/node-nest-react-mysql/`) cho stack
  NestJS + React/Vite + MySQL:
  - 5 commands: `fullstack-scan`, `api-e2e-flow`, `env-doctor`,
    `docker-dev-doctor`, `seed-data-safe`.
  - 5 skills: `nestjs-backend`, `react-vite-frontend`, `mysql-schema-safe`,
    `auth-rbac-review`, `fullstack-test-strategy`.
  - `AGENTS.append.md` + `OPENCODE.append.md` với rule layer + workflow.
- **Profile installer** (`scripts/install-fullstack-profile.sh`): copy commands
  + skills, append AGENTS/OPENCODE với marker idempotent, backup file user.
  Từ chối chạy trong HOME hoặc trong `~/opencode-power-kit`.
- **Global full-stack commands** (9 mới):
  `fullstack-scan`, `openapi-check`, `secret-scan`, `sast-check`,
  `e2e-plan`, `test-matrix`, `js-quality-check`, `env-doctor`,
  `docker-dev-doctor`.
- **Global full-stack skills** (8 mới):
  `openapi-contract`, `secure-fullstack`, `dependency-maintenance`,
  `fullstack-test-strategy`, `js-ts-quality`, `env-config-safe`,
  `docker-compose-safe`, `nest-react-mysql`.
- **Templates** (4 mới):
  `biome.json.example`, `renovate.json.example`,
  `openapi/openapi.yaml.example`, `openapi/spectral.yaml.example`.
- **Optional install scripts** (3 mới):
  `install-security-tools.sh`, `install-api-tools.sh`,
  `install-js-quality-tools.sh`. Detect tool, in hướng dẫn, tạo report.
  Không sudo, không curl|sh, không tự cài.

### Changed

- **Pack validator** (`scripts/validate-opencode-pack.py`): thêm validate
  `profiles/*/commands/*.md` frontmatter + `profiles/*/skills/*/SKILL.md`
  heading + `templates/openapi/*.example` tồn tại.
- **Integration test** (`scripts/integration-test.sh`): thêm test
  `install-fullstack-profile.sh` trong temp project, verify marker + artifacts.
- **CI** (`.github/workflows/ci.yml`):
  - `bash -n` thêm 4 script mới.
  - `no-mcp` scan cả `profiles/`.
  - `line-count-guard` thêm min lines cho 17 file mới.
  - Validate JSON `biome.json.example`, `renovate.json.example`.
  - Validate YAML `spectral.yaml.example`.

### Safety (giữ nguyên policy)

- Không thêm MCP config vào `opencode-global/` hay `profiles/`.
- Không chứa `sk-`, `ghp_`, `AKIA`, `PRIVATE KEY`, `api_key=`, `password=`
  pattern trong source.
- Không sudo, không curl|sh trong install scripts.
- Không tự cài dependency nặng (gitleaks, semgrep, biome, ...).
- Backup trước khi append/sửa file user.

## [1.0.0] - 2026-06-04

First production-grade release. Bumped from 9.4/10 → 10/10.

### Added

- **Global pack** (`opencode-global/`): 4 agents, 15 commands, 12 skills
  - Lifecycle commands: `spec-lite`, `plan-work`, `build-slice`, `test-proof`, `ship-check`
  - Review commands: `security-review`, `api-contract-review`, `migration-safe`, `review-diff`
  - Token commands: `rtk-gain`, `token-pack`
  - Utility commands: `smart-scan`, `bugfix-safe`, `repo-map`, `db-readonly`
- **Per-project install** (`install.sh`): seeds `AGENTS.md`, `OPENCODE.md`,
  `.opencode/opencode.json`, `.gitignore` (merged), `knip.json`, `lefthook.yml`
- **Global install** (`install-global.sh`): sets `OPENCODE_CONFIG_DIR` in
  `~/.bashrc` and adds `~/.local/bin` to `PATH`. Backs up existing files
  before touching them
- **BMAD integration**: `install.sh` and `update-bmad.sh` install BMAD Method
  via `npx bmad-method install --modules bmm --tools opencode`
- **Superpowers**: enabled through `.opencode/opencode.json` template
- **Token tools** (`scripts/install-token-tools.sh`): detects `rtk` and
  `tokscale`; never auto-runs `curl|sh`, never uses `sudo`
- **Verify** (`verify.sh`): checks global config, pack structure, MCP
  absence, secret-pattern absence, project files
- **Pack validator** (`scripts/validate-opencode-pack.py`): checks
  `commands/*.md` frontmatter + `description`, `agents/*.md` frontmatter +
  `description` + `mode`, `skills/*/SKILL.md` heading + body
- **Integration test** (`scripts/integration-test.sh`): builds a temp
  project, runs `install.sh` + `verify.sh`, asserts expected files exist
- **Doctor** (`doctor.sh`): read-only diagnostic for `OPENCODE_CONFIG_DIR`,
  pack structure, scripts, MCP, secrets
- **Uninstall** (`uninstall.sh`): restores from backup if present;
  requires confirmation (or `--yes`)
- **CI** (`.github/workflows/ci.yml`): 12 jobs — `bash -n`, `shellcheck`
  (best effort), `shfmt -d` (best effort), JSON templates, YAML templates,
  `git diff --check`, no-MCP guard, no-secrets scan, line-count guard,
  pack validation, integration test
- **Safety**:
  - No MCP config in `opencode-global/` (verified by CI)
  - No `sk-`, `ghp_`, `AKIA`, `PRIVATE KEY`, `api_key=`, `password=`
    patterns in source (verified by CI)
  - No `curl|sh`, no `sudo` in install scripts
  - Backup before overwrite (`.opencode-power-kit-backup-<timestamp>`)
- **Release metadata**: `VERSION` (1.0.0), `CHANGELOG.md` (this file)
- **Badges** in `README.md`: CI status, version, no-MCP policy,
  safe/no-secrets policy

[1.9.2]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.9.2
[1.9.1]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.9.1
[1.9.0]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.9.0
[1.8.0]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.8.0
[1.6.7]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.7
[1.6.6]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.6
[1.6.5]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.5
[1.6.4]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.4
[1.6.3]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.3
[1.6.2]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.2
[1.6.1]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.1
[1.6.0]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.6.0
[1.5.0]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.5.0
[1.4.0]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.4.0
[1.0.0]: https://github.com/laivannha0202/opencode-power-kit/releases/tag/v1.0.0
