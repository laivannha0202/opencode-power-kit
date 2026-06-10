#!/usr/bin/env node
/**
 * opk-safety-guard.js
 *
 * Safety plugin guard cho OpenCode Power Kit.
 * Chặn đọc file nhạy cảm và command nguy hiểm.
 *
 * === INSTALL ===
 * Copy file này vào .opencode/plugins/opk-safety-guard.js
 * Hoặc chạy: opk safety-plugin install
 *
 * === HOW IT WORKS ===
 * Guard này intercepts các tool call và check:
 * 1. File read — chặn đọc .env, *secret*, *private.key*, *token*, *credential*
 * 2. Command execution — chặn rm -rf, git reset --hard, force push,
 *    SQL DROP/TRUNCATE/DELETE không WHERE
 *
 * @version 1.6.4
 */

const SENSITIVE_FILE_PATTERNS = [
  /\.env$/i,
  /\.env\./i,
  /secret/i,
  /private\.key$/i,
  /privatekey/i,
  /token/i,
  /credential/i,
  /\.pem$/i,
  /\.cert$/i,
  /\bghp_[A-Za-z0-9]{20,}\b/,
  /\bsk-[A-Za-z0-9]{20,}\b/,
  /AKIA[0-9A-Z]{16}/,
];

const DANGEROUS_COMMAND_PATTERNS = [
  // rm -rf patterns
  { pattern: /\brm\s+(-rf|--recursive\s+--force)\b/i, severity: 'critical', message: 'rm -rf: nguy cơ xóa dữ liệu' },
  // git reset --hard
  { pattern: /\bgit\s+reset\s+--hard\b/i, severity: 'critical', message: 'git reset --hard: mất thay đổi chưa commit' },
  // git clean -fd
  { pattern: /\bgit\s+clean\s+-f[d]\b/i, severity: 'critical', message: 'git clean -fd: xóa untracked files' },
  // git push --force
  { pattern: /\bgit\s+push\s+(--force|-f)\b/i, severity: 'critical', message: 'git push --force: ghi đè remote history' },
  // SQL DROP TABLE
  { pattern: /\bDROP\s+TABLE\b/i, severity: 'high', message: 'DROP TABLE: nguy cơ mất dữ liệu' },
  // SQL TRUNCATE
  { pattern: /\bTRUNCATE\b/i, severity: 'high', message: 'TRUNCATE: xóa toàn bộ dữ liệu bảng' },
  // SQL DELETE without WHERE
  { pattern: /\bDELETE\s+FROM\b(?!.*\bWHERE\b)/is, severity: 'high', message: 'DELETE FROM không WHERE: xóa toàn bộ bảng' },
];

/**
 * Check nếu file path match sensitive patterns
 */
function isSensitiveFile(filePath) {
  return SENSITIVE_FILE_PATTERNS.some((pattern) => pattern.test(filePath));
}

/**
 * Check nếu command match dangerous patterns
 */
function isDangerousCommand(command) {
  for (const entry of DANGEROUS_COMMAND_PATTERNS) {
    if (entry.pattern.test(command)) {
      return entry;
    }
  }
  return null;
}

/**
 * Guard function — gọi trước mỗi tool action
 * Returns: { blocked: boolean, reason?: string }
 */
function guardCheck(toolName, args) {
  // File read guard
  if (toolName === 'read' || toolName === 'write') {
    const filePath = args?.filePath || args?.path || '';
    if (filePath && isSensitiveFile(filePath)) {
      return {
        blocked: true,
        reason: `opk-safety-guard: BLOCKED — ${toolName} trên file nhạy cảm: ${filePath}`,
      };
    }
  }

  // Bash command guard
  if (toolName === 'bash' || toolName === 'execute') {
    const command = args?.command || args?.cmd || '';
    if (command) {
      const danger = isDangerousCommand(command);
      if (danger) {
        return {
          blocked: true,
          reason: `opk-safety-guard: BLOCKED — [${danger.severity}] ${danger.message}: ${command}`,
        };
      }
    }
  }

  return { blocked: false };
}

module.exports = { guardCheck, isSensitiveFile, isDangerousCommand };
