# Headroom-lite — Context/Token Compression Workflow (Reference)

> **Version:** opencode-power-kit v1.9.2
>
> **Integration mode:** Reference / Workflow guidance — OPK-native docs, skill,
> and slash commands. **No runtime code, no dependency, no package install,
> no MCP, no proxy/daemon.** All content is conceptual guidance, workflow
> templates, and agent instructions — safe to use under MIT license.

---

## Overview

Headroom-lite is an **OPK-native reference module** for context window and
token compression patterns. It helps agents manage context budgets, compress
verbose outputs, optimize token usage, and make intelligent decisions about
when and how to compress.

Headroom-lite draws inspiration from
[chopratejas/headroom](https://github.com/chopratejas/headroom) — a Linux
daemon for context/token compression — but is a **reference workflow only**.
No code, binaries, or daemon configurations from upstream are shipped.

Headroom-lite provides:

- **Documentation** — conceptual overview, compression strategies, when to
  compress vs when to keep verbatim, token budget management.
- **Agent skill** — `headroom-lite` skill that teaches agents how to plan,
  audit, and monitor context compression.
- **Slash commands** — `/headroom-plan`, `/headroom-audit`, `/headroom-status`
  for structured workflows.

### What Headroom-lite is NOT

- ❌ **Not a compression runtime** — no daemon, no proxy, no interceptor.
- ❌ **Not a code library** — no Python/TypeScript/Rust code is shipped.
- ❌ **Not a copy of upstream** — no source, binary, or significant content
  from [chopratejas/headroom](https://github.com/chopratejas/headroom).
- ❌ **Not a token counter** — use `rtk` or `tokscale` for actual token
  measurement.
- ❌ **Not auto-installed** — never enabled by `opk global`, bootstrap, or
  setup.

### What Headroom-lite IS

- ✅ **Conceptual reference** — context window economics, compression
  strategies, token budget patterns, evidence-preserving compression.
- ✅ **Workflow templates** — how to plan a compression strategy, audit
  existing context usage, and monitor token consumption.
- ✅ **Agent guidance** — when to compress (logs, long output, RAG chunks,
  tool output), when NOT to compress (code, error messages, secrets,
  structured data needing exact parsing), how to balance compression vs
  information loss.
- ✅ **Complementary to RAG-lite** — use together: RAG-lite for retrieval
  quality, Headroom-lite for context compression within token budgets.
- ✅ **Complementary to rtk** — use `rtk` for actual token counting/saving,
  Headroom-lite for workflow guidance on *what* to compress and *when*.

---

## Context Compression Concept Reference

### Why Context Compression Matters

Every LLM interaction has a **context window budget**:

- More tokens = higher cost, higher latency, more chance of hitting limits.
- Long contexts dilute attention — models perform worse on very long inputs.
- Tool output, retrieval results, and logs are the biggest token consumers.
- Compression is a **quality lever**: remove noise, amplify signal.

### The Compression Spectrum

| Approach | Token savings | Info loss | Use case |
|----------|:------------:|:---------:|----------|
| **Truncation** (cut tail) | High | High | Last resort when over limit |
| **Summarization** (rephrase) | Medium-High | Medium | Logs, verbose output, chat history |
| **Structured truncation** (keep head+tail) | Medium | Low | Long tool output, JSON arrays |
| **De-duplication** (remove repeats) | Low-Medium | None | Repeated error messages, logs |
| **Filtering** (remove irrelevant) | Medium | Low | RAG chunks below relevance threshold |
| **Keyword extraction** | High | High | Quick skimming |
| **No compression** | 0% | None | Code, errors, structured data |

### When to Compress

| Content type | Compress? | Strategy |
|-------------|:---------:|----------|
| Tool stdout/stderr (long) | ✅ Yes | Summarize or structured truncation |
| RAG retrieved chunks | ✅ Yes | Filter low-relevance, summarize verbose |
| Chat history (long) | ✅ Yes | Summarize older turns |
| Log output | ✅ Yes | Deduplicate, then summarize |
| Error messages | ❌ No | Keep verbatim — details matter |
| Stack traces | ❌ No | Keep verbatim — line numbers matter |
| Code diffs | ❌ No | Keep verbatim — correctness depends on exact code |
| Structured data (JSON, YAML) | ⚠️ Partial | Keep schema, truncate large arrays |
| Secrets / credentials | ❌ NEVER | Never log, never compress, never expose |
| User instructions | ❌ No | Keep verbatim — intent matters |
| API contracts | ❌ No | Keep verbatim — correctness depends on exact spec |

### Token Budget Management

When planning a session with limited context:

```
Total context window:     N tokens
  - System prompt:        S tokens  (fixed)
  - User message:         U tokens  (fixed)
  - Conversation history: H tokens  (compressible)
  - Tool outputs:         T tokens  (compressible)
  - Retrieved context:    R tokens  (compressible)
  ----------------------------
  - Available for reply:  N - (S+U) - compress(H+T+R)
```

**Rules of thumb:**

1. Reserve ≥25% of context window for the model's response.
2. Compress tool output first — it's usually the biggest variable.
3. Compress conversation history second — older turns matter less.
4. Never compress system prompt, user instruction, or error context.
5. If still over budget: truncate oldest history, then reduce top-k on
   retrieval.

### Evidence-Preserving Compression

When compression is necessary, **preserve evidence**:

- Key numbers, dates, names, and IDs should survive compression.
- Error codes and exit statuses should survive compression.
- The compress operation should declare **what was compressed** and
  **what was removed**.
- Example declaration: *"Summarized 40 lines of build output (preserved
  exit code 1, last 5 lines verbatim)"*

---

## License-Safe Design

### Why this matters

[chopratejas/headroom](https://github.com/chopratejas/headroom) is licensed
under **Apache-2.0**, which permits commercial use, modification, and
distribution with attribution. However, Headroom-lite is designed as a
**reference workflow only** to keep opencode-power-kit lightweight, MIT-only,
and free of runtime dependencies.

### Headroom-lite rule

1. **No source code** from any upstream repository is shipped in OPK.
2. **No binaries or daemon configurations** are shipped.
3. **No significant text** is copied from upstream documentation.
   Short quotes (≤1 paragraph) for attribution are acceptable.
4. **All conceptual content** is OPK-original — written from general
   context window / token compression knowledge, not derived from any
   single upstream.
5. **Credit is given** in `THIRD_PARTY.md` for:
   - chopratejas/headroom (reference / inspiration)
   - Any other compression projects referenced in this module
6. **Links to upstream** are provided for users who want the full
   implementation details.

### Third-party references

| Project | Link | Purpose |
|---------|------|---------|
| chopratejas/headroom | https://github.com/chopratejas/headroom | Context/token compression Linux daemon (reference) |
| rtk | https://github.com/rtk-ai/rtk | Token-saving shell wrapper (complementary tool) |
| tokscale | https://github.com/tokscale/tokscale | Token cost visualization (complementary tool) |

---

## Workflow: Plan → Audit → Status

Headroom-lite provides three structured workflows for agents:

### 1. Plan (`/headroom-plan`)

When a task involves managing context budget or compressing output,
`/headroom-plan` guides the agent through:

1. **Problem analysis** — Is context compression needed? What's the budget?
   What's consuming tokens?
2. **Content classification** — What content types are present? Which are
   compressible? Which must stay verbatim?
3. **Strategy selection** — Which compression approach fits each content
   type? Summarize, filter, de-duplicate, structured truncation?
4. **Evidence preservation plan** — What information must survive
   compression? Key numbers, errors, IDs?
5. **Budget calculation** — Target token reduction, expected savings,
   fallback if compression isn't enough.
6. **Implementation** — Apply compression with declared operations,
   verify evidence preserved.

### 2. Audit (`/headroom-audit`)

When reviewing an existing session's context usage, `/headroom-audit` checks:

1. **Token consumption** — How many tokens used? What consumed the most?
2. **Compression opportunities** — Are there compressible content types
   being kept verbatim?
3. **Evidence integrity** — After compression, are key details preserved?
4. **Budget compliance** — Is the session within its target budget?
5. **Compression declaration** — Was compression declared? What was
   removed?
6. **Tool output review** — Are tool outputs unnecessarily verbose?

### 3. Status (`/headroom-status`)

When checking Headroom-lite readiness, `/headroom-status` reports:

1. **Component check** — Are integration doc, skill, and commands present?
2. **Integration status** — Are references in build-strong.md and
   agent-router.md up to date?
3. **Related tools** — Are `rtk` / `tokscale` available on PATH for token
   measurement?
4. **RAG-lite synergy** — Is RAG-lite available for combined context
   compression + retrieval quality workflow?

---

## Agent Integration

### When to activate headroom-lite skill

The `headroom-lite` skill should be activated when:

- A task involves managing long context or token budgets
- Tool outputs are very long and need compression
- RAG retrieval returns more chunks than fit in context
- Session history is long and needs summarization
- Any task mentioning "context compression", "token budget",
  "context window", "output truncation", "compression strategy"

### How agents use headroom-lite

1. Agent detects context-compression-related work → loads `headroom-lite` skill
2. Uses `/headroom-plan`, `/headroom-audit`, `/headroom-status` commands
   for structured workflows
3. Applies checklists from this document to ensure quality
4. Never installs compression packages directly — uses OPK-native patterns
5. Never copies code from upstream — follows OPK-safe patterns
6. Combines with `rag-lite` when both retrieval and compression are needed
7. Combines with `rtk` / `tokscale` for actual token measurement

### Safety rules for agents

- **No auto-install** — Never install compression daemons, proxies, or
  packages without explicit user request.
- **No credential handling** — Never read or store API keys or tokens.
- **No production changes** — Headroom-lite workflows are planning/audit
  tools only. Production changes require user approval.
- **No upstream code copy** — Never copy code from chopratejas/headroom or
  other upstreams into the project.
- **Always credit** — When referencing upstream projects, add credit to
  `THIRD_PARTY.md` following OPK conventions.
- **Declare compression** — Always declare what was compressed and what
  was removed. Never silently drop content.
- **Preserve evidence** — Always ensure key numbers, dates, names, IDs,
  and error codes survive compression.

### Combining with RAG-lite

When both retrieval and compression are needed:

1. Use `/rag-plan` to design the retrieval pipeline.
2. Use `/headroom-plan` to fit retrieved chunks within the context budget.
3. Use `/rag-audit` + `/headroom-audit` together to verify both retrieval
   quality and compression integrity.
4. The combined workflow: retrieve → filter low-relevance chunks →
   compress verbose chunks → assemble context → generate.

---

## Compression Checklist

Before applying compression, verify:

- [ ] **Content classified** — Each content type identified as compressible
      or verbatim-required.
- [ ] **Strategy matches content** — Summarization for logs, filtering for
      RAG chunks, structured truncation for arrays.
- [ ] **Evidence preserved** — Key numbers, error codes, names, IDs survive.
- [ ] **Compression declared** — What was compressed, what was removed, and
      why.
- [ ] **Fallback available** — If compression isn't enough, what's the
      truncation strategy?
- [ ] **Combined with RAG-lite** — If retrieval is involved, verify
      retrieval quality before compressing results.
- [ ] **Token measurement** — Use `rtk` or `tokscale` to verify actual
      savings.

---

## Compression Anti-Patterns

- ❌ Compressing error messages and stack traces
- ❌ Compressing code diffs and code blocks
- ❌ Silently dropping content without declaring what was removed
- ❌ Over-compressing: losing critical evidence for minor token savings
- ❌ Using compression as a substitute for proper retrieval quality
  (compress bad RAG results = garbage in, compressed garbage out)
- ❌ Applying the same strategy to all content types
- ❌ Forgetting to check token budget before compression
- ❌ Not verifying compression output quality

---

## Comparison: Strategies at a Glance

| Approach | When to use | When to avoid |
|----------|-------------|---------------|
| **Summarization** | Logs, verbose tool stdout, long chat history | Code, errors, structured data, API responses |
| **Filtering** | RAG chunks below threshold, irrelevant output | When every detail might be relevant |
| **Structured truncation** | Long JSON arrays, repeated patterns | Single items, critical data |
| **De-duplication** | Repeated error messages, log spam | Unique items that look similar |
| **Verbatim** | Code, errors, user intent, contracts | Verbose output that isn't actionable |

---

## Files

| File | Role |
|------|------|
| `docs/HEADROOM_LITE_INTEGRATION.md` | This document — conceptual reference, compression strategies, checklist |
| `opencode-global/skills/headroom-lite/SKILL.md` | Agent skill — teaches agents context compression workflow and best practices |
| `opencode-global/commands/headroom-plan.md` | `/headroom-plan` — plan a context compression strategy |
| `opencode-global/commands/headroom-audit.md` | `/headroom-audit` — audit existing context/token usage |
| `opencode-global/commands/headroom-status.md` | `/headroom-status` — check Headroom-lite integration status |

---

## Upstream References

- **chopratejas/headroom** — https://github.com/chopratejas/headroom
  Context/token compression Linux daemon. Apache-2.0 licensed.
  OPK references concepts only — no code or binary is copied.
- **rtk** — https://github.com/rtk-ai/rtk
  Token-saving shell wrapper (detect-only in OPK).
- **tokscale** — https://github.com/tokscale/tokscale
  Token cost visualization (detect-only in OPK).

---

## Related Modules

| Module | Integration | Purpose |
|--------|:-----------:|---------|
| **RAG-lite** | Reference | Retrieval quality, chunking, embedding evaluation |
| **rtk** | Detect-only | Token counting and saving |
| **tokscale** | Detect-only | Token cost visualization |
| **Hermes-lite** | Inspiration-only | Meta-cognitive self-improvement, context budget review |

---

*This file is part of opencode-power-kit and is MIT licensed. It references
upstream projects for conceptual guidance only. No upstream source code,
binaries, daemon configurations, or significant text are included.
See `THIRD_PARTY.md` for full attribution.*
