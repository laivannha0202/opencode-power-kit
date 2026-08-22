#!/usr/bin/env node
// @opk-plugin opk-token-guard
// Runtime defense against secret/token leakage.

const TOKEN_STORE_PATH_PATTERNS = [
  /(^|[\\/])\.ssh[\\/]/,
  /(^|[\\/])\.aws[\\/]credentials$/,
  /(^|[\\/])\.netrc$/,
  /(^|[\\/])\.kube[\\/]config$/,
  /(^|[\\/])\.config[\\/]opencode[\\/]auth\.json$/i,
  /(^|[\\/])\.local[\\/]share[\\/]opencode[\\/]auth\.json$/i,
  /(^|[\\/])\.config[\\/]claude[\\/]credentials\.json$/i,
];

const PROJECT_SECRET_PATH_PATTERNS = [
  /(^|[\\/])\.env$/i,
  /(^|[\\/])\.env\.[^\\/]+$/i,
  /(^|[\\/])\.envrc$/i,
  /(^|[\\/])secrets?(?:[\\/]|$)/i,
  /(^|[\\/])secret[^\\/]*$/i,
  /private[._-]?key/i,
  /id_rsa$/i,
  /id_ed25519$/i,
  /id_ecdsa$/i,
  /\.pem$/i,
  /\.key$/i,
  /credentials?/i,
];

function normalizePath(path) {
  let p = String(path || "").replace(/\\/g, "/").trim();
  if (!p) return "";

  const absolute = p.startsWith("/");
  const parts = [];

  for (const part of p.split("/")) {
    if (!part || part === ".") continue;

    if (part === "..") {
      if (parts.length > 0 && parts[parts.length - 1] !== "..") {
        parts.pop();
      } else if (!absolute) {
        // Preserve unresolved leading traversal. It must remain visible to
        // sensitive-path matching instead of turning the path into "safe".
        parts.push("..");
      }
      continue;
    }

    parts.push(part);
  }

  const normalized = parts.join("/");
  return absolute ? `/${normalized}` : normalized;
}

function isTokenStorePath(path) {
  const p = normalizePath(path);
  if (!p) return false;
  return TOKEN_STORE_PATH_PATTERNS.some((re) => re.test(p));
}

function isProtectedSecretPath(path) {
  const p = normalizePath(path);
  if (!p) return false;
  if (isTokenStorePath(p)) return true;

  // .env.example is a conventional non-secret template. Keep the exception
  // exact to the basename: .env.example.local and every other .env* remain
  // protected.
  if (/(^|[\\/])\.env\.example$/i.test(p)) return false;

  return PROJECT_SECRET_PATH_PATTERNS.some((re) => re.test(p));
}

const PROTECTED_LITERAL_PATTERNS = [
  ["proc environment", /\/proc\/(?:self|[0-9]+|\$[A-Za-z_][A-Za-z0-9_]*)\/environ\b/i],
  ["envrc", /(^|[\/\s"'`=:(])\.envrc(?=$|[\/\s"'`;|)&])/i],
  ["secret path", /(^|[\/\s"'`=:(])secrets?(?=$|[\/\s"'`;|)&])/i],
  ["private key", /private[._-]?key|id_rsa|id_ed25519|id_ecdsa/i],
  ["pem/key file", /[A-Za-z0-9_.\/-]+\.(?:pem|key)(?=$|[\s"'`;|)&])/i],
  ["credentials", /credentials?(?:\.json)?(?=$|[\/\s"'`;|)&])/i],
  ["netrc", /(^|[\/\s"'`=:(])\.netrc(?=$|[\s"'`;|)&])/i],
  ["ssh store", /(^|[\/\s"'`=:(])\.ssh\//i],
  ["aws credentials", /\.aws\/credentials/i],
  ["kube config", /\.kube\/config/i],
  ["opencode auth", /(?:\.config|\.local\/share)\/opencode\/auth\.json/i],
  ["claude credentials", /\.config\/claude\/credentials\.json/i],
];

function findProtectedEnvLiteral(text) {
  // Scan every env-looking literal independently. This is important for
  // commands such as `cat .env .env.example`: the safe example token must
  // never mask the real secret token.
  const re = /(^|[\/\s"'`=:(])(\.env(?:\.[A-Za-z0-9_.-]+)?)(?=$|[\/\s"'`;|)&])/gi;
  let match;
  while ((match = re.exec(String(text || ""))) !== null) {
    if (isProtectedSecretPath(match[2])) return "env file";
  }
  return null;
}

function findProtectedPathLiteral(text) {
  const normalized = String(text || "").replace(/\\\\/g, "/");
  const envLiteral = findProtectedEnvLiteral(normalized);
  if (envLiteral) return envLiteral;
  for (const [label, re] of PROTECTED_LITERAL_PATTERNS) {
    if (re.test(normalized)) return label;
  }
  return null;
}

const SECRET_ENV_SUFFIX = /_(?:API_KEY|TOKEN|SECRET|PASSWORD|ACCESS_KEY|CREDENTIALS?)$/i;
const KNOWN_SECRET_ENV = new Set([
  "OPENAI_API_KEY", "ANTHROPIC_API_KEY", "GEMINI_API_KEY", "GOOGLE_API_KEY",
  "DEEPSEEK_API_KEY", "GROQ_API_KEY", "MISTRAL_API_KEY", "HF_TOKEN",
  "HUGGINGFACE_TOKEN", "GITHUB_TOKEN", "GITLAB_TOKEN", "AWS_SECRET_ACCESS_KEY",
  "AZURE_OPENAI_API_KEY", "COHERE_API_KEY", "XAI_API_KEY", "PERPLEXITY_API_KEY",
  "TOGETHER_API_KEY",
]);

const INLINE_SECRET_PATTERNS = [
  /sk-[A-Za-z0-9]{16,}/,
  /AIza[0-9A-Za-z_-]{25,}/,
  /AKIA[0-9A-Z]{16}/,
  /ghp_[A-Za-z0-9]{30,}/,
  /gho_[A-Za-z0-9]{30,}/,
  /xox[baprs]-[A-Za-z0-9-]{10,}/,
  /Bearer\s+[A-Za-z0-9._~+/=-]{20,}/i,
  /Basic\s+[A-Za-z0-9+/=]{20,}/i,
];

function isSecretEnvName(name) {
  return KNOWN_SECRET_ENV.has(name) || SECRET_ENV_SUFFIX.test(name);
}
function hasInlineSecret(text) {
  return INLINE_SECRET_PATTERNS.some((re) => re.test(text));
}
function extractEnvExpansions(text) {
  const names = new Set();
  const re = /\$\{?([A-Z][A-Z0-9_]*)\}?/g;
  let m;
  while ((m = re.exec(text)) !== null) names.add(m[1]);
  return names;
}

function findTokenLeak(cmd) {
  const text = String(cmd || "").trim();
  if (!text) return null;
  const protectedLiteral = findProtectedPathLiteral(text);
  if (protectedLiteral) return `lệnh shell tham chiếu ${protectedLiteral}`;
  if (/^(?:printenv|env|set)\s*(?:[;&|]|$)/.test(text)) {
    return "lệnh dump toàn bộ environment (lộ secret)";
  }
  if (/(?:^|[;&|]\s*)(?:echo|printf)\b/.test(text)) {
    for (const name of extractEnvExpansions(text)) {
      if (isSecretEnvName(name)) return `echo in biến bí mật: ${name}`;
    }
  }
  const exp = text.match(/(?:^|[;&|]\s*)export\s+([A-Z][A-Z0-9_]*)\s*=\s*(\S+)/);
  if (exp && isSecretEnvName(exp[1]) && hasInlineSecret(exp[2])) {
    return `export secret bằng literal: ${exp[1]}`;
  }
  if (hasInlineSecret(text)) return "lệnh chứa credential dạng chữ";
  return null;
}

function extractPatchPaths(patchText) {
  const paths = [];
  const re = /\*\*\*\s+(?:Add|Update|Delete)\s+File:\s*(.+?)\s*$|\*\*\*\s+Move\s+File:\s*(.+?)\s*$|\*\*\*\s+Move\s+to:\s*(.+?)\s*$/gm;
  let m;
  const text = String(patchText || "");
  while ((m = re.exec(text)) !== null) {
    const value = (m[1] || m[2] || m[3] || "").trim();
    if (!value) continue;
    const arrow = value.match(/^(.*?)\s*->\s*(.*)$/);
    if (arrow) paths.push(arrow[1].trim(), arrow[2].trim());
    else paths.push(value);
  }
  return paths;
}

function guardTokenCall(tool, args) {
  const name = String(tool || "").toLowerCase();
  const a = args || {};
  if (name === "read" || name === "write" || name === "edit") {
    const p = a.path || a.filePath || a.file_path;
    if (p && isProtectedSecretPath(p)) {
      throw new Error(`opk-token-guard: BLOCKED — ${name} trên secret/token path: ${p}`);
    }
    return;
  }
  if (name === "apply_patch") {
    const patch = a.patchText || a.patch || a.text || "";
    const bad = extractPatchPaths(patch).find((p) => isProtectedSecretPath(p));
    if (bad) throw new Error(`opk-token-guard: BLOCKED — apply_patch chạm secret/token path: ${bad}`);
    return;
  }
  if (["bash", "exec", "execute", "shell", "run"].includes(name)) {
    const cmd = a.command || a.cmd || a.input || a.script || "";
    const leak = findTokenLeak(cmd);
    if (leak) throw new Error(`opk-token-guard: BLOCKED — ${leak}: ${cmd}`);
  }
}

function sanitizeAgentShellEnv(input, output) {
  // AI shell calls carry sessionID/callID; manual PTY calls carry cwd only.
  // Sanitize agent subprocesses without mutating the OpenCode parent process.
  const agentScoped = Boolean(input && (input.callID || input.sessionID));
  if (!agentScoped) return;

  const env = output && output.env;
  if (!env || typeof env !== "object") return;

  // OpenCode merges shell.env output on top of process.env.
  // Empty-string overrides remove secret values from the child process.
  const names = new Set([
    ...Object.keys(process.env),
    ...Object.keys(env),
  ]);

  for (const name of names) {
    const value = Object.prototype.hasOwnProperty.call(env, name)
      ? env[name]
      : process.env[name];

    if (
      isSecretEnvName(name) ||
      (value && hasInlineSecret(String(value)))
    ) {
      env[name] = "";
    }
  }
}

const OPKTokenGuard = async () => ({
  "tool.execute.before": async (input, output) => {
    const tool = (input && input.tool) || (output && output.tool);
    const args = (output && output.args) || (input && input.args) || {};
    guardTokenCall(tool, args);
    return output;
  },
  "shell.env": async (input, output) => {
    sanitizeAgentShellEnv(input, output);
    return output;
  },
});

module.exports = OPKTokenGuard;
