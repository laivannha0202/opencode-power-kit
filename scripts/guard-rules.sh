#!/usr/bin/env bash
# ============================================================================
# guard-rules.sh — shared Bash safety rules engine (sourced, not executed)
#
# Single rule set for Bash-side guard enforcement. Mirrors
# templates/plugins/opk-safety-guard.js exactly (rule-for-rule parity is
# enforced by test-command-guard.sh + test-safety-plugin.mjs against the
# shared corpus templates/guard/guard-corpus.json).
#
# Usage:
#   source scripts/guard-rules.sh
#   if opk_guard_scan "$cmd" "$root"; then ... safe ...; else ... blocked ...; fi
#
# Context variables:
#   OPK_GUARD_ROOT     project root for messages (default: $PWD)
#   OPK_GUARD_STRICT   block (default) | warn
#   OPK_GUARD_SILENT   set -> no stderr noise, verdict only
#
# Design notes:
#   - NO bypass env var. NO allowlist: an allowlist is what enabled the
#     `rm -rf ./node_modules/../../etc` traversal bypass in the old guard.
#     Use `rm -r` (non-recursive-force) or `git clean -n` instead.
#   - Quote-stripping mirrors the JS plugin so docs containing literal
#     "rm -rf" are not flagged.
#   - Pure Bash (no forks) on the hot path so the DEBUG-trap guard in
#     templates/guard/opk-guard-bashrc stays cheap.
# ============================================================================

if [[ -n "${OPK_GUARD_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
OPK_GUARD_LOADED=1

_opk_guard_strip_quotes() {
  # Strip single/double quoted substrings (mirror of JS stripQuotes).
  local text="$1" out="" c i=0 n=${#1} in_q=""
  while (( i < n )); do
    c="${text:i:1}"
    if [[ -n "$in_q" ]]; then
      if [[ "$c" == "\\" ]]; then
        (( i += 2 ))
        continue
      fi
      if [[ "$c" == "$in_q" ]]; then
        in_q=""
      fi
      (( i += 1 ))
      continue
    fi
    if [[ "$c" == "'" || "$c" == '"' ]]; then
      in_q="$c"
      out+=" "
      (( i += 1 ))
      continue
    fi
    out+="$c"
    (( i += 1 ))
  done
  _opk_guard_result="$out"
}

_opk_guard_split_segments() {
  # Split on newline, &&, ||, ; (mirror of JS splitSegments).
  local text="$1" line seg
  _opk_guard_segments=()
  while IFS= read -r line; do
    IFS=';&|' read -r -a _opk_guard_parts <<<"$line"
    for seg in "${_opk_guard_parts[@]}"; do
      seg="${seg//  / }"
      if [[ -n "$seg" ]]; then
        _opk_guard_segments+=("${seg# }")
      fi
    done
  done <<<"$text"
}

# --- rule patterns (parity with the JS plugin) ----------------------------
# Word boundaries are emulated with explicit character classes because
# this bash's ERE engine rejects [[:<:]]/[[:>:]]/\<...\> (glibc POSIX ERE).
# NOTE: no token may consume a char a following [[:space:]]+ also needs.
_OPK_RM_RF='(^|[^a-zA-Z0-9_])rm([^a-zA-Z0-9_]|$)[^|;&]*(-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+-[a-zA-Z]*[fF][a-zA-Z]*|-[rR][fF]|-[fF][rR]|--recursive[[:space:]]+--force|--force[[:space:]]+--recursive)'
_OPK_GIT_RESET='(^|[^a-zA-Z0-9_])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)*[[:space:]]+reset[[:space:]]+--hard([^a-zA-Z0-9_]|$)'
_OPK_GIT_CLEAN='(^|[^a-zA-Z0-9_])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)*[[:space:]]+clean[[:space:]]+-f'
_OPK_GIT_PUSH_FORCE='(^|[^a-zA-Z0-9_])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)*[[:space:]]+push([^a-zA-Z0-9_]|$)[^|;&]*(--force|-[a-zA-Z]*f[a-zA-Z]*|--force-with-lease)'
_OPK_PIPE_SHELL='\|[[:space:]]*(sudo[[:space:]]+|env[[:space:]]+)?(ba)?sh([^a-zA-Z0-9_]|$)|\|[[:space:]]*zsh([^a-zA-Z0-9_]|$)'
_OPK_SHELL_C='(^|[^a-zA-Z0-9_])(ba)?sh[[:space:]]+-c[[:space:]]+["'"'"'][^"'"'"']*["'"'"']'
_OPK_SQL_CLIENT='(^|[^a-zA-Z0-9_])(mysql|psql|sqlite3?|sqlcmd|pg_dump)([^a-zA-Z0-9_]|$)'
_OPK_SQL_DROP='(^|[^a-zA-Z0-9_])DROP[[:space:]]+TABLE([^a-zA-Z0-9_]|$)'
_OPK_SQL_TRUNCATE='(^|[^a-zA-Z0-9_])TRUNCATE[[:space:]]+[a-zA-Z0-9_]'
_OPK_SQL_DELETE='(^|[^a-zA-Z0-9_])DELETE[[:space:]]+FROM([^a-zA-Z0-9_]|$)'
_OPK_SQL_WHERE='(^|[^a-zA-Z0-9_])WHERE([^a-zA-Z0-9_]|$)'
_OPK_REDIRECT='([[:space:]]*(2?>>?|&>|&>>|1>>?|3>>?)[[:space:]]*)([^[:space:]&|;>]+)'
_OPK_TEE='([[:space:]]*tee[[:space:]]+)([^[:space:]&|;>]+)'

_opk_guard_fast_reject() {
  # Keyword prefilter: skip regex work for obviously safe commands.
  local cmd="$1"
  case "$cmd" in
    *rm*|*git*|*DROP*|*TRUNCATE*|*DELETE*|*curl*|*wget*|*"sh"*|*zsh*|*tee*|*\>*|*sudo*) return 1 ;;
  esac
  return 0
}

_opk_guard_sensitive_path() {
  # Mirrors isSensitivePath() of the JS plugin.
  local p="${1//\\//}"
  p="${p#"${p%%[![:space:]]*}"}" # trim leading spaces
  [[ -n "$p" ]] || return 1
  local low="${p,,}"
  # allowlist: *.example
  case "$low" in
    *.example|*.example.*) return 1 ;;
  esac
  case "$low" in
    *.env|*.envrc|*.pem|*.key|*private-key*|*id_rsa*|*id_ed25519*|*id_ecdsa*|*credential*) return 0 ;;
  esac
  [[ "$low" =~ \.env\.[a-z0-9_-]+$ ]] && return 0
  [[ "$low" =~ (^|[/\\])secrets?$ ]] && return 0
  [[ "$low" =~ (^|[/\\])secret([^a-z0-9_]|$) ]] && return 0
  return 1
}

_opk_guard_redirect_targets() {
  # Extract redirect (>, >>, 2>, &> ...) and tee targets into
  # _opk_guard_targets. Raw scan (quotes not stripped) — erring to block.
  local cmd="$1" rest="$1"
  _opk_guard_targets=()
  while [[ "$rest" =~ $_OPK_REDIRECT ]]; do
    local tok="${BASH_REMATCH[3]}"
    tok="${tok//\"/}"
    tok="${tok//\'/}"
    tok="${tok//\`/}"
    if [[ -n "$tok" && "$tok" != "&1" && "$tok" != "/dev/null" ]]; then
      _opk_guard_targets+=("$tok")
    fi
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
  rest="$cmd"
  while [[ "$rest" =~ $_OPK_TEE ]]; do
    local tok="${BASH_REMATCH[2]}"
    tok="${tok//\"/}"
    tok="${tok//\'/}"
    tok="${tok//\`/}"
    [[ -n "$tok" && "$tok" != "/dev/null" ]] && _opk_guard_targets+=("$tok")
    rest="${rest#*"${BASH_REMATCH[0]}"}"
  done
}

_opk_guard_danger_in() {
  # Scan one quote-stripped text for the four core destructive patterns.
  local text="$1" msg
  if [[ "$text" =~ $_OPK_RM_RF ]]; then
    _opk_guard_violation="rm -rf/-fr: xóa dữ liệu không thể phục hồi"
    return 0
  fi
  if [[ "$text" =~ $_OPK_GIT_RESET ]]; then
    _opk_guard_violation="git reset --hard: mất thay đổi chưa commit"
    return 0
  fi
  if [[ "$text" =~ $_OPK_GIT_CLEAN ]]; then
    _opk_guard_violation="git clean -f: xóa untracked files"
    return 0
  fi
  if [[ "$text" =~ $_OPK_GIT_PUSH_FORCE ]]; then
    _opk_guard_violation="git push --force/-f: ghi đè lịch sử remote"
    return 0
  fi
  return 1
}

# --- public API -----------------------------------------------------------
# opk_guard_scan <cmd> [root] -> 0 safe, 1 dangerous. Prints violation to
# stderr unless OPK_GUARD_SILENT is set.
opk_guard_scan() {
  local cmd="${1:-}" root="${2:-${OPK_GUARD_ROOT:-$PWD}}" raw="$1" stripped="" seg
  _opk_guard_violation=""
  [[ -n "$cmd" ]] || return 0
  if _opk_guard_fast_reject "$cmd"; then
    return 0
  fi
  _opk_guard_strip_quotes "$cmd"
  stripped="$_opk_guard_result"

  # bash -c "..." / sh -c '...' inner scan (on raw, quoted content preserved)
  if [[ "$raw" =~ $_OPK_SHELL_C ]]; then
    local inner="${BASH_REMATCH[0]}"
    inner="${inner#* -c }"
    inner="${inner:1:${#inner}-2}" # drop surrounding quotes
    _opk_guard_strip_quotes "$inner"
    if _opk_guard_danger_in "$_opk_guard_result"; then
      _opk_guard_violation="bash -c: $_opk_guard_violation"
      [[ -n "${OPK_GUARD_SILENT:-}" ]] || echo "opk-guard: BLOCKED — [$_opk_guard_violation]: $cmd" >&2
      return 1
    fi
  fi

  # pipe-to-shell on the whole (quote-stripped) command
  if [[ "$stripped" =~ $_OPK_PIPE_SHELL ]]; then
    _opk_guard_violation="pipe-to-shell: curl/wget/... | sh|bash|zsh — rủi ro thực thi mã từ xa"
    [[ -n "${OPK_GUARD_SILENT:-}" ]] || echo "opk-guard: BLOCKED — [$_opk_guard_violation]: $cmd" >&2
    return 1
  fi

  # core patterns per segment
  _opk_guard_split_segments "$stripped"
  for seg in "${_opk_guard_segments[@]}"; do
    if _opk_guard_danger_in "$seg"; then
      [[ -n "${OPK_GUARD_SILENT:-}" ]] || echo "opk-guard: BLOCKED — [$_opk_guard_violation]: $cmd" >&2
      return 1
    fi
  done

  # SQL: only when a SQL client is actually invoked (no doc false positives)
  if [[ "$raw" =~ $_OPK_SQL_CLIENT ]]; then
    if [[ "$raw" =~ $_OPK_SQL_DROP || "$raw" =~ $_OPK_SQL_TRUNCATE ]] || { [[ "$raw" =~ $_OPK_SQL_DELETE ]] && [[ ! "$raw" =~ $_OPK_SQL_WHERE ]]; }; then
      _opk_guard_violation="SQL DROP/TRUNCATE/DELETE không WHERE: mất dữ liệu bảng"
      [[ -n "${OPK_GUARD_SILENT:-}" ]] || echo "opk-guard: BLOCKED — [$_opk_guard_violation]: $cmd" >&2
      return 1
    fi
  fi

  # redirect / tee into a sensitive file
  if [[ "$raw" == *\>* || "$raw" == *tee* ]]; then
    _opk_guard_redirect_targets "$raw"
    for t in "${_opk_guard_targets[@]:-}"; do
      if _opk_guard_sensitive_path "$t"; then
        _opk_guard_violation="redirect/tee vào file nhạy cảm: $t"
        [[ -n "${OPK_GUARD_SILENT:-}" ]] || echo "opk-guard: BLOCKED — [$_opk_guard_violation]: $cmd" >&2
        return 1
      fi
    done
  fi

  return 0
}
