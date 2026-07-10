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
// are exported separately and are unit-tested by scripts/test-safety-plugin.mjs.
//
// @version 2.1.0
// ============================================================================

// --- Sensitive path detection ------------------------------------------------
// Ordered: exact .env, .env.<suffix> (except .example), private keys, etc.
// Allowlist: *.example and anything under a templates/ directory is treated
// as a non-secret sample and is NEVER blocked.
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
  /(^|[\\/])templates([\\/]|$)/, // bundled template samples
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
export function isSensitivePath(filePath) {
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
// Each entry: { id, test(segment) -> bool }. We scan each shell segment
// (split on &&, ||, ; and newline) plus the whole command for pipe-to-shell.
function stripQuotes(cmd) {
  // Remove single- and double-quoted substrings so that searching docs
  // containing the literal text "rm -rf" is not mistaken for a destructive op.
  return String(cmd)
    .replace(/'[^']*'/g, " ")
    .replace(/"[^"]*"/g, " ");
}

const RM_RF_RE = /\brm\b[^|;&]*(-[a-z]*[rR][a-z]*\s+-[a-z]*[fF][a-z]*|-[rR][fF]|-[fF][rR])/;
const GIT_RESET_RE = /\bgit\s+reset\s+--hard\b/;
const GIT_CLEAN_RE = /\bgit\s+clean\s+-f/;
const GIT_PUSH_FORCE_RE = /\bgit\s+push\s+(--force|-[a-zA-Z]*f[a-zA-Z]*)\b/;
const SQL_RE = /\b(DROP\s+TABLE|TRUNCATE\s+TABLE|TRUNCATE\s+)\b/i;
const SQL_DELETE_RE = /\bDELETE\s+FROM\b(?![\s\S]*\bWHERE\b)/i;
const PIPE_SHELL_RE = /\|\s*(ba)?sh\b|\|\s*zsh\b/;

function splitSegments(cmd) {
  return String(cmd)
    .split(/\n/)
    .flatMap((line) => line.split(/&&|\|\||;/))
    .map((s) => s.trim())
    .filter(Boolean);
}

/**
 * Trả về string mô tả rule vi phạm, hoặc null nếu an toàn.
 * Phát hiện command nguy hiểm kể cả khi nằm sau &&, ;, ||, pipe.
 */
export function findDangerousCommand(command) {
  if (!command) return null;
  const raw = String(command);
  const stripped = stripQuotes(raw);

  // Pipe-to-shell must be checked on the whole (quote-stripped) command
  // because the pipe itself is the danger and splitting on | would hide it.
  if (PIPE_SHELL_RE.test(stripped)) {
    return "pipe-to-shell: curl/wget/... | sh|bash|zsh — rủi ro thực thi mã từ xa";
  }

  for (const seg of splitSegments(stripped)) {
    if (RM_RF_RE.test(seg)) {
      return "rm -rf/-fr: xóa dữ liệu không thể phục hồi";
    }
    if (GIT_RESET_RE.test(seg)) {
      return "git reset --hard: mất thay đổi chưa commit";
    }
    if (GIT_CLEAN_RE.test(seg)) {
      return "git clean -f: xóa untracked files";
    }
    if (GIT_PUSH_FORCE_RE.test(seg)) {
      return "git push --force/-f: ghi đè lịch sử remote";
    }
  }

  // SQL: chỉ flag khi command thực sự gọi một SQL client (mysql/psql/...),
  // tránh false positive khi user đọc tài liệu chứa chữ "DROP TABLE" qua grep/cat.
  const HAS_SQL_CLIENT = /\b(mysql|psql|sqlite3?|sqlcmd|pg_dump|psql)\b/i.test(raw);
  if (HAS_SQL_CLIENT && (SQL_RE.test(raw) || SQL_DELETE_RE.test(raw))) {
    return "SQL DROP/TRUNCATE/DELETE không WHERE: mất dữ liệu bảng";
  }

  return null;
}

// --- apply_patch path extraction --------------------------------------------
// Matches OpenCode apply_patch markers:
//   *** Add File: path
//   *** Update File: path
//   *** Delete File: path
//   *** Move File: from -> to
export function extractPatchPaths(patchText) {
  const text = String(patchText || "");
  const paths = [];
  const re = /\*\*\*\s+(Add|Update|Delete|Move)\s+File:\s*(.+?)\s*$/gm;
  let m;
  while ((m = re.exec(text)) !== null) {
    const op = m[1];
    const rest = m[2].trim();
    if (op === "Move") {
      const arrow = rest.match(/^(.*?)\s*->\s*(.*)$/);
      if (arrow) {
        paths.push(arrow[1].trim());
        paths.push(arrow[2].trim());
      } else {
        paths.push(rest);
      }
    } else {
      paths.push(rest);
    }
  }
  return paths;
}

// --- Core guard --------------------------------------------------------------
// Throws Error nếu (tool, args) vi phạm. Ngược lại không làm gì.
export function guardToolCall(tool, args) {
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
export const OPKSafetyGuard = async (ctx) => {
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

export default OPKSafetyGuard;
