#!/usr/bin/env node
// ============================================================================
// opk-token-guard.js  —  OpenCode Power Kit token-leak guard plugin
// @opk-plugin opk-token-guard
//
// Real OpenCode plugin: exports an async plugin factory that returns a
// `tool.execute.before` hook. The hook inspects the tool name (`input.tool`)
// and the tool arguments (`output.args`) and THROWS on a violation so that
// OpenCode aborts the tool call.
//
// Guards (bash/exec/execute/shell/run only, plus token-store file access):
//   - environment dumps: `printenv`, bare `env`, bare `set`
//   - expanding secret env vars via echo/printf: `echo $OPENAI_API_KEY`
//   - exporting a secret with a literal value: `export FOO=sk-...`
//   - inline credentials: sk-..., Bearer <token>, ghp_..., AKIA..., AIza...
//   - reading/writing token stores: .ssh/, .aws/credentials, .netrc,
//     .kube/config, auth.json
//
// Helper functions (isTokenStorePath / findTokenLeak) are private (not
// exported) and tested via the plugin hook in test-token-guard.mjs.
//
// @version 2.1.0
// ============================================================================

// --- Token store path detection ----------------------------------------------
const TOKEN_STORE_PATH_PATTERNS = [
  /(^|[\\/])\.ssh[\\/]/, // ~/.ssh/id_rsa, known_hosts, config ...
  /(^|[\\/])\.aws[\\/]credentials$/,
  /(^|[\\/])\.netrc$/,
  /(^|[\\/])\.kube[\\/]config$/,
  /(^|[\\/])\.config[\\/]opencode[\\/]auth\.json$/i,
  /(^|[\\/])\.local[\\/]share[\\/]opencode[\\/]auth\.json$/i,
  /(^|[\\/])\.config[\\/]claude[\\/]credentials\.json$/i,
];

function isTokenStorePath(path) {
  const p = String(path || "").replace(/\\/g, "/");
  if (!p) return false;
  const parts = p.split("/");
  if (parts.includes("..")) return false;
  return TOKEN_STORE_PATH_PATTERNS.some((re) => re.test(p));
}

// --- Secret env var names ----------------------------------------------------
const SECRET_ENV_SUFFIX = /_(?:API_KEY|TOKEN|SECRET|PASSWORD|ACCESS_KEY|CREDENTIALS?)$/i;
const KNOWN_SECRET_ENV = new Set([
  "OPENAI_API_KEY",
  "ANTHROPIC_API_KEY",
  "GEMINI_API_KEY",
  "GOOGLE_API_KEY",
  "DEEPSEEK_API_KEY",
  "GROQ_API_KEY",
  "MISTRAL_API_KEY",
  "HF_TOKEN",
  "HUGGINGFACE_TOKEN",
  "GITHUB_TOKEN",
  "GITLAB_TOKEN",
  "AWS_SECRET_ACCESS_KEY",
  "AZURE_OPENAI_API_KEY",
  "COHERE_API_KEY",
  "XAI_API_KEY",
  "PERPLEXITY_API_KEY",
  "TOGETHER_API_KEY",
]);

function isSecretEnvName(name) {
  return KNOWN_SECRET_ENV.has(name) || SECRET_ENV_SUFFIX.test(name);
}

// --- Inline secret patterns ---------------------------------------------------
const INLINE_SECRET_PATTERNS = [
  /sk-[A-Za-z0-9]{16,}/, // OpenAI-style keys
  /AIza[0-9A-Za-z_-]{25,}/, // Google API keys
  /AKIA[0-9A-Z]{16}/, // AWS access key id
  /ghp_[A-Za-z0-9]{30,}/, // GitHub personal access token
  /gho_[A-Za-z0-9]{30,}/,
  /xox[baprs]-[A-Za-z0-9-]{10,}/, // Slack tokens
  /Bearer\s+[A-Za-z0-9._~+/=-]{20,}/i, // bearer token
  /Basic\s+[A-Za-z0-9+/=]{20,}/i, // basic auth payload
];

function hasInlineSecret(text) {
  return INLINE_SECRET_PATTERNS.some((re) => re.test(text));
}

// --- Env expansion extraction -------------------------------------------------
// Captures $NAME / ${NAME} occurrences, returning the set of names.
function extractEnvExpansions(text) {
  const names = new Set();
  const re = /\$\{?([A-Z][A-Z0-9_]*)\}?/g;
  let m;
  while ((m = re.exec(text)) !== null) {
    names.add(m[1]);
  }
  return names;
}

// --- Core guard ---------------------------------------------------------------
// Throws Error nếu (tool, args) vi phạm. Ngược lại không làm gì.
function guardTokenCall(tool, args) {
  const name = String(tool || "").toLowerCase();
  const a = args || {};

  if (name === "read" || name === "write" || name === "edit") {
    const p = a.path || a.filePath || a.file_path;
    if (p && isTokenStorePath(p)) {
      throw new Error(
        `opk-token-guard: BLOCKED — ${name} trên token store: ${p}`,
      );
    }
    return;
  }

  if (
    name === "bash" ||
    name === "exec" ||
    name === "execute" ||
    name === "shell" ||
    name === "run"
  ) {
    const cmd = a.command || a.cmd || a.input || a.script || "";
    const leak = findTokenLeak(cmd);
    if (leak) {
      throw new Error(`opk-token-guard: BLOCKED — ${leak}: ${cmd}`);
    }
    return;
  }
}

// Returns a reason string if the shell command leaks tokens, else null.
function findTokenLeak(cmd) {
  const text = String(cmd || "").trim();
  if (!text) return null;

  // Bare environment dumps: printenv / env / set (whole command)
  if (/^(?:printenv|env|set)\s*(?:[;&|]|$)/.test(text)) {
    return "lệnh dump toàn bộ environment (lộ secret)";
  }

  // cat/type/head/tail/less/nl of token stores (flags like -3 are skipped)
  const fileRead = text.match(
    /(?:^|[;&|]\s*)(?:cat|type|head|tail|less|more|nl)\s+(.*?)(?:[;&|]|$)/,
  );
  if (fileRead) {
    const tokens = fileRead[1]
      .trim()
      .split(/\s+/)
      .filter((t) => t && !t.startsWith("-"));
    if (tokens.some((t) => isTokenStorePath(t))) {
      return "đọc token store";
    }
  }

  // echo/printf expanding secret env vars
  if (/(?:^|[;&|]\s*)(?:echo|printf)\b/.test(text)) {
    const expansions = extractEnvExpansions(text);
    for (const envName of expansions) {
      if (isSecretEnvName(envName)) {
        return `echo in biến bí mật: ${envName}`;
      }
    }
  }

  // Exporting a secret env var with a literal value
  const exportMatch = text.match(
    /(?:^|[;&|]\s*)export\s+([A-Z][A-Z0-9_]*)\s*=\s*(\S+)/,
  );
  if (exportMatch && isSecretEnvName(exportMatch[1]) && hasInlineSecret(exportMatch[2])) {
    return `export secret bằng literal: ${exportMatch[1]}`;
  }

  // Inline credentials anywhere in the command
  if (hasInlineSecret(text)) {
    return "lệnh chứa credential dạng chữ";
  }

  return null;
}

/**
 * OpenCode plugin factory. Returns an object with a `tool.execute.before` hook.
 * The hook reads the tool name from `input.tool` and arguments from
 * `output.args`, then delegates to guardTokenCall.
 */
const OPKTokenGuard = async (ctx) => {
  return {
    "tool.execute.before": async (input, output) => {
      const tool = (input && input.tool) || (output && output.tool);
      const args =
        (output && output.args) ||
        (input && input.args) ||
        {};
      guardTokenCall(tool, args);
      return output;
    },
  };
};

module.exports = OPKTokenGuard;
