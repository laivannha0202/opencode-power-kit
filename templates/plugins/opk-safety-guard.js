#!/usr/bin/env node
// ============================================================================
// opk-safety-guard.js  —  OpenCode Power Kit safety plugin
// @opk-plugin opk-safety-guard
//
// Real OpenCode plugin: exports an async plugin factory that returns a
// `tool.execute.before` hook. The hook inspects the tool name (`input.tool`)
// and the tool arguments (`output.args`) and THROWS on a violation so that
// OpenCode aborts the tool call. Returning `{ blocked: true }` is NOT enough —
// OpenCode does not understand that object, so we throw.
//
// Tools guarded:
//   read, write, edit        -> sensitive file paths
//   apply_patch              -> patch that touches sensitive file paths
//   bash (execute, shell)    -> destructive shell commands
//
// Helper functions (isSensitivePath / findDangerousCommand / extractPatchPaths)
// are private (not exported) and tested via the plugin hook in test-safety-plugin.mjs.
//
// @version 2.2.0
// ============================================================================

// --- Sensitive path detection ------------------------------------------------
// Ordered: exact .env, .env.<suffix> (except .example), private keys, etc.
// Allowlist: *.example only. No broad directory allowlists.
const SENSITIVE_PATH_PATTERNS = [
  /\.env$/, // exact .env
  /\.env\.(?!example)[A-Za-z0-9_-]+$/, // .env.local / .env.production ... but not .env.example
  /\.envrc$/,
  /(^|[\\/])secrets?$/, // secret / secrets directory
  /(^|[\\/])secret\b/i,
  /private[\._-]?key/i,
  /id_rsa$/,
  /id_ed25519$/,
  /id_ecdsa$/,
  /\.pem$/,
  /\.key$/,
  /credential/i,
];

const SENSITIVE_PATH_ALLOWLIST = [
  /\.example$/, // *.example sample files (.env.example, opencode.example.jsonc)
];

/**
 * Chuẩn hóa slash Windows/Linux và loại bỏ dư thừa.
 */
function normalizePath(p) {
  if (!p) return "";
  return String(p).replace(/\\/g, "/").trim();
}

/**
 * Trả về true nếu filePath là file nhạy cảm (secret / private key / .env thật).
 * .env.example và file template mẫu KHÔNG bị block.
 */
function isSensitivePath(filePath) {
  const p = normalizePath(filePath);
  if (!p) return false;

  // Allowlist: sample / template files.
  if (SENSITIVE_PATH_ALLOWLIST.some((re) => re.test(p))) {
    return false;
  }

  // Block absolute or traversal paths pointing to a sensitive file name
  // regardless of directory (e.g. /etc/secrets, ../.env).
  return SENSITIVE_PATH_PATTERNS.some((re) => re.test(p));
}

// --- Dangerous command detection --------------------------------------------
// Token-aware scanner.  Do NOT delete quoted substrings: quotes can contain
// executable options (`rm "-rf"`, `git reset "--hard"`) and shell payloads.
// Instead, lex each simple command, normalize wrappers/executable paths, and
// inspect only commands that can perform the destructive action.

const SQL_RE = /\b(DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+TABLE|TRUNCATE\s+)\b/i;
const SQL_DELETE_RE = /\bDELETE\s+FROM\b(?![\s\S]*\bWHERE\b)/i;
const REDIRECT_TARGET_RE = /(?:\s*(?:2?>>?|&>|&>>|1>>?|3>>?)\s*)([^\s&|;>]+)/g;
const TEE_TARGET_RE = /(?:\s*tee\s+)([^\s&|;>]+)/g;

function splitShellSegments(command) {
  const text = String(command || "");
  const segments = [];
  let current = "";
  let quote = "";
  let escaped = false;

  const flush = () => {
    const value = current.trim();
    if (value) segments.push(value);
    current = "";
  };

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];

    if (escaped) {
      current += ch;
      escaped = false;
      continue;
    }

    if (quote) {
      current += ch;
      if (ch === "\\" && quote === '"') {
        escaped = true;
      } else if (ch === quote) {
        quote = "";
      }
      continue;
    }

    if (ch === "'" || ch === '"') {
      quote = ch;
      current += ch;
      continue;
    }

    if (ch === "\n" || ch === ";" || ch === "|" || ch === "&") {
      flush();
      // Treat && / || as one separator.
      if ((ch === "|" || ch === "&") && text[i + 1] === ch) i += 1;
      continue;
    }

    current += ch;
  }

  flush();
  return segments;
}

function shellTokens(segment) {
  const text = String(segment || "");
  const tokens = [];
  let token = "";
  let quote = "";
  let escaped = false;
  let active = false;

  const flush = () => {
    if (active) tokens.push(token);
    token = "";
    active = false;
  };

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];

    if (escaped) {
      token += ch;
      active = true;
      escaped = false;
      continue;
    }

    if (quote) {
      if (ch === "\\" && quote === '"') {
        escaped = true;
      } else if (ch === quote) {
        quote = "";
      } else {
        token += ch;
        active = true;
      }
      continue;
    }

    if (ch === "'" || ch === '"') {
      quote = ch;
      active = true;
      continue;
    }

    if (/\s/.test(ch)) {
      flush();
      continue;
    }

    if (ch === "\\") {
      escaped = true;
      active = true;
      continue;
    }

    token += ch;
    active = true;
  }

  if (escaped) token += "\\";
  flush();
  return tokens;
}

function executableName(token) {
  const clean = String(token || "").replace(/\\/g, "/");
  return clean.slice(clean.lastIndexOf("/") + 1);
}

function isAssignment(token) {
  return /^[A-Za-z_][A-Za-z0-9_]*=/.test(String(token || ""));
}

function shortFlagHas(token, letter) {
  return /^-[^-]+$/.test(token) && token.slice(1).includes(letter);
}

function unwrapCommand(tokens) {
  let i = 0;

  while (i < tokens.length && isAssignment(tokens[i])) i += 1;

  let guard = 0;
  while (i < tokens.length && guard < 8) {
    guard += 1;
    const exe = executableName(tokens[i]);

    if (exe === "sudo") {
      i += 1;
      while (i < tokens.length && tokens[i].startsWith("-")) {
        const opt = tokens[i];
        if (["-u", "-g", "-h", "-p", "-C", "-R", "-T"].includes(opt)) i += 2;
        else i += 1;
      }
      continue;
    }

    if (exe === "command") {
      i += 1;
      if (tokens[i] === "-v" || tokens[i] === "-V") {
        return { exe: "command-query", args: [], index: i };
      }
      while (tokens[i] === "-p") i += 1;
      continue;
    }

    if (exe === "env") {
      i += 1;
      while (i < tokens.length) {
        const tok = tokens[i];
        if (isAssignment(tok)) {
          i += 1;
          continue;
        }
        if (tok === "-i" || tok === "--ignore-environment" || tok === "-0" || tok === "--null") {
          i += 1;
          continue;
        }
        if (tok === "-u" || tok === "--unset" || tok === "-C" || tok === "--chdir") {
          i += 2;
          continue;
        }
        if (tok.startsWith("--unset=") || tok.startsWith("--chdir=")) {
          i += 1;
          continue;
        }
        break;
      }
      continue;
    }

    return { exe, args: tokens.slice(i + 1), index: i };
  }

  return { exe: "", args: [], index: i };
}

function rmDanger(args) {
  let recursive = false;
  let force = false;

  for (const arg of args) {
    if (arg === "--") break;
    if (arg === "--recursive") recursive = true;
    else if (arg === "--force") force = true;
    else if (shortFlagHas(arg, "r") || shortFlagHas(arg, "R")) recursive = true;

    if (shortFlagHas(arg, "f") || shortFlagHas(arg, "F")) force = true;
  }

  return recursive && force;
}

function normalizeGitArgs(args) {
  let i = 0;
  while (i < args.length) {
    const arg = args[i];
    if (arg === "-C" || arg === "-c" || arg === "--git-dir" || arg === "--work-tree" || arg === "--namespace") {
      i += 2;
      continue;
    }
    if (
      arg.startsWith("--git-dir=") ||
      arg.startsWith("--work-tree=") ||
      arg.startsWith("--namespace=")
    ) {
      i += 1;
      continue;
    }
    break;
  }
  return args.slice(i);
}

function gitDanger(args) {
  const normalized = normalizeGitArgs(args);
  const sub = normalized[0] || "";
  const rest = normalized.slice(1);

  if (sub === "reset" && rest.includes("--hard")) {
    return "git reset --hard: mất thay đổi chưa commit";
  }

  if (sub === "clean") {
    const forced = rest.some(
      (arg) => arg === "--force" || shortFlagHas(arg, "f") || shortFlagHas(arg, "F"),
    );
    if (forced) return "git clean -f: xóa untracked files";
  }

  if (sub === "push") {
    const forced = rest.some(
      (arg) =>
        arg === "--force" ||
        arg.startsWith("--force-with-lease") ||
        shortFlagHas(arg, "f"),
    );
    if (forced) return "git push --force/-f: ghi đè lịch sử remote";
  }

  return null;
}

function shellPayload(args) {
  for (let i = 0; i < args.length; i += 1) {
    const arg = args[i];
    if (/^-[A-Za-z]*c[A-Za-z]*$/.test(arg)) {
      return args[i + 1] || "";
    }
  }
  return "";
}

function scanCoreCommand(tokens, depth = 0) {
  if (!tokens.length || depth > 6) return null;

  const { exe, args } = unwrapCommand(tokens);
  if (!exe || exe === "command-query") return null;

  if (exe === "rm" && rmDanger(args)) {
    return "rm recursive+force: xóa dữ liệu không thể phục hồi";
  }

  if (exe === "git") {
    return gitDanger(args);
  }

  if (exe === "bash" || exe === "sh" || exe === "zsh") {
    const payload = shellPayload(args);
    if (payload) return scanCommandText(payload, depth + 1);
    return null;
  }

  if (exe === "eval") {
    return scanCommandText(args.join(" "), depth + 1);
  }

  if (exe === "ssh") {
    let i = 0;
    while (i < args.length && args[i].startsWith("-")) {
      const opt = args[i];
      if (["-b", "-c", "-D", "-E", "-e", "-F", "-I", "-i", "-J", "-L", "-l", "-m", "-O", "-o", "-p", "-Q", "-R", "-S", "-W", "-w"].includes(opt)) i += 2;
      else i += 1;
    }
    if (i < args.length) i += 1; // host
    if (i < args.length) return scanCommandText(args.slice(i).join(" "), depth + 1);
  }

  return null;
}

function scanCommandText(command, depth = 0) {
  if (depth > 6) return null;
  for (const segment of splitShellSegments(command)) {
    const danger = scanCoreCommand(shellTokens(segment), depth);
    if (danger) return danger;
  }
  return null;
}

function isShellInvocation(segment) {
  const { exe, args } = unwrapCommand(shellTokens(segment));
  if (!["bash", "sh", "zsh"].includes(exe)) return false;
  // A pipe into `bash script.sh` is still execution of pipeline input only
  // when no script/command operand is supplied.  Shell options are allowed.
  return !args.some((arg) => !arg.startsWith("-"));
}

function hasPipeToShell(command) {
  const text = String(command || "");
  let quote = "";
  let escaped = false;
  let current = "";

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i];

    if (escaped) {
      current += ch;
      escaped = false;
      continue;
    }
    if (quote) {
      current += ch;
      if (ch === "\\" && quote === '"') escaped = true;
      else if (ch === quote) quote = "";
      continue;
    }
    if (ch === "'" || ch === '"') {
      quote = ch;
      current += ch;
      continue;
    }

    if (ch === "|" && text[i + 1] !== "|") {
      const right = text.slice(i + 1);
      const next = splitShellSegments(right)[0] || "";
      if (isShellInvocation(next)) return true;
    }
    current += ch;
  }
  return false;
}

/**
 * Return a violation description, or null when the shell command is allowed.
 */
function findDangerousCommand(command) {
  if (!command) return null;
  const raw = String(command);

  const coreDanger = scanCommandText(raw);
  if (coreDanger) return coreDanger;

  if (hasPipeToShell(raw)) {
    return "pipe-to-shell: curl/wget/... | sh|bash|zsh — rủi ro thực thi mã từ xa";
  }

  // SQL is intentionally gated on a real SQL client to avoid blocking
  // documentation searches that merely contain SQL text.
  const sqlClient = splitShellSegments(raw).some((segment) => {
    const { exe } = unwrapCommand(shellTokens(segment));
    return ["mysql", "psql", "sqlite", "sqlite3", "sqlcmd"].includes(exe);
  });
  if (sqlClient && (SQL_RE.test(raw) || SQL_DELETE_RE.test(raw))) {
    return "SQL DROP/TRUNCATE/DELETE không WHERE: mất dữ liệu bảng";
  }

  // Redirect / tee into a sensitive file.
  if (/[>]|tee/.test(raw)) {
    const targets = [];
    for (const m of raw.matchAll(REDIRECT_TARGET_RE)) {
      if (m[1]) targets.push(m[1]);
    }
    for (const m of raw.matchAll(TEE_TARGET_RE)) {
      if (m[1]) targets.push(m[1]);
    }
    for (let target of targets) {
      target = target.replace(/["'`]/g, "");
      if (target === "&1" || target === "/dev/null") continue;
      if (isSensitivePath(target)) {
        return `redirect/tee vào file nhạy cảm: ${target}`;
      }
    }
  }

  return null;
}

// --- apply_patch path extraction --------------------------------------------
// Matches OpenCode apply_patch markers (both old and new formats):
//   *** Add File: path       /  *** Add File: path
//   *** Update File: path    /  *** Update File: path
//   *** Delete File: path    /  *** Delete File: path
//   *** Move File: from -> to  /  *** Move to: path
function extractPatchPaths(patchText) {
  const text = String(patchText || "");
  const paths = [];
  // Match Add/Update/Delete File: ... AND Move File: ... AND Move to: ...
  const re = /\*\*\*\s+(?:Add|Update|Delete)\s+File:\s*(.+?)\s*$|\*\*\*\s+Move\s+File:\s*(.+?)\s*$|\*\*\*\s+Move\s+to:\s*(.+?)\s*$/gm;
  let m;
  while ((m = re.exec(text)) !== null) {
    if (m[2]) {
      // Move File: from -> to
      const arrow = m[2].trim().match(/^(.*?)\s*->\s*(.*)$/);
      if (arrow) {
        paths.push(arrow[1].trim());
        paths.push(arrow[2].trim());
      } else {
        paths.push(m[2].trim());
      }
    } else {
      // Add/Update/Delete File: path OR Move to: path
      const path = (m[1] || m[3] || "").trim();
      if (path) paths.push(path);
    }
  }
  return paths;
}

// --- Core guard --------------------------------------------------------------
// Throws Error nếu (tool, args) vi phạm. Ngược lại không làm gì.
function guardToolCall(tool, args) {
  const name = String(tool || "").toLowerCase();
  const a = args || {};

  if (name === "read" || name === "write" || name === "edit") {
    const p = a.path || a.filePath || a.file_path;
    if (p && isSensitivePath(p)) {
      throw new Error(
        `opk-safety-guard: BLOCKED — ${name} trên file nhạy cảm: ${p}`,
      );
    }
    return;
  }

  if (name === "apply_patch") {
    const patchText =
      a.patchText || a.patch || a.text || (a.args && a.args.patchText) || "";
    const paths = extractPatchPaths(patchText);
    const bad = paths.find((p) => isSensitivePath(p));
    if (bad) {
      throw new Error(
        `opk-safety-guard: BLOCKED — apply_patch chạm file nhạy cảm: ${bad}`,
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
    const danger = findDangerousCommand(cmd);
    if (danger) {
      throw new Error(`opk-safety-guard: BLOCKED — [${danger}]: ${cmd}`);
    }
    return;
  }
}

/**
 * OpenCode plugin factory. Returns an object with a `tool.execute.before` hook.
 * The hook reads the tool name from `input.tool` and arguments from
 * `output.args`, then delegates to guardToolCall.
 */
const OPKSafetyGuard = async (ctx) => {
  return {
    "tool.execute.before": async (input, output) => {
      const tool = (input && input.tool) || (output && output.tool);
      const args =
        (output && output.args) ||
        (input && input.args) ||
        {};
      guardToolCall(tool, args);
      return output;
    },
  };
};

module.exports = OPKSafetyGuard;
