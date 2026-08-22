#!/usr/bin/env bash
# ============================================================================
# guard-rules.sh — shared Bash safety rules engine (sourced, not executed)
#
# Token-aware Bash guard.  Quoted strings are lexed rather than deleted, so
# executable options such as `rm "-rf"` remain visible while documentation
# commands such as `rg "rm -rf" README.md` remain allowed.
#
# Mirrors templates/plugins/opk-safety-guard.js for runtime command verdicts.
# ============================================================================

if [[ -n "${OPK_GUARD_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
OPK_GUARD_LOADED=1

_opk_guard_violation=""

_opk_guard_emit_block() {
  local cmd="$1"
  [[ -n "${OPK_GUARD_SILENT:-}" ]] || \
    echo "opk-guard: BLOCKED — [$_opk_guard_violation]: $cmd" >&2
  return 1
}

_opk_guard_split_segments() {
  local text="$1" current="" quote="" escaped=0 c i=0 n=${#1}
  _opk_guard_segments=()

  while (( i < n )); do
    c="${text:i:1}"

    if (( escaped )); then
      current+="$c"
      escaped=0
      (( i += 1 ))
      continue
    fi

    if [[ -n "$quote" ]]; then
      current+="$c"
      if [[ "$c" == '\' && "$quote" == '"' ]]; then
        escaped=1
      elif [[ "$c" == "$quote" ]]; then
        quote=""
      fi
      (( i += 1 ))
      continue
    fi

    if [[ "$c" == "'" || "$c" == '"' ]]; then
      quote="$c"
      current+="$c"
      (( i += 1 ))
      continue
    fi

    case "$c" in
      $'\n'|';'|'|'|'&')
        if [[ -n "${current//[[:space:]]/}" ]]; then
          _opk_guard_segments+=("$current")
        fi
        current=""
        if [[ ( "$c" == "|" || "$c" == "&" ) && "${text:i+1:1}" == "$c" ]]; then
          (( i += 1 ))
        fi
        ;;
      *)
        current+="$c"
        ;;
    esac
    (( i += 1 ))
  done

  if [[ -n "${current//[[:space:]]/}" ]]; then
    _opk_guard_segments+=("$current")
  fi
}

_opk_guard_tokenize() {
  local text="$1" token="" quote="" c i=0 n=${#1} active=0 escaped=0
  _opk_guard_tokens=()

  while (( i < n )); do
    c="${text:i:1}"

    if (( escaped )); then
      token+="$c"
      active=1
      escaped=0
      (( i += 1 ))
      continue
    fi

    if [[ -n "$quote" ]]; then
      if [[ "$c" == '\' && "$quote" == '"' ]]; then
        escaped=1
      elif [[ "$c" == "$quote" ]]; then
        quote=""
      else
        token+="$c"
        active=1
      fi
      (( i += 1 ))
      continue
    fi

    if [[ "$c" == "'" || "$c" == '"' ]]; then
      quote="$c"
      active=1
      (( i += 1 ))
      continue
    fi

    if [[ "$c" =~ [[:space:]] ]]; then
      if (( active )); then
        _opk_guard_tokens+=("$token")
        token=""
        active=0
      fi
      (( i += 1 ))
      continue
    fi

    if [[ "$c" == '\' ]]; then
      escaped=1
      active=1
      (( i += 1 ))
      continue
    fi

    token+="$c"
    active=1
    (( i += 1 ))
  done

  if (( escaped )); then token+='\'; fi
  if (( active )); then _opk_guard_tokens+=("$token"); fi
}

_opk_guard_exe_name() {
  local value="${1//\\//}"
  _opk_guard_result="${value##*/}"
}

_opk_guard_is_assignment() {
  [[ "${1:-}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]
}

_opk_guard_short_has() {
  local token="${1:-}" letter="${2:-}"
  [[ "$token" == -?* && "$token" != --* && "${token:1}" == *"$letter"* ]]
}

_opk_guard_unwrap() {
  local -n toks=$1
  local i=0 exe tok guard=0 n=${#toks[@]}
  _opk_guard_exe=""
  _opk_guard_args=()

  while (( i < n )) && _opk_guard_is_assignment "${toks[i]}"; do
    (( i += 1 ))
  done

  while (( i < n && guard < 8 )); do
    (( guard += 1 ))
    _opk_guard_exe_name "${toks[i]}"
    exe="$_opk_guard_result"

    case "$exe" in
      sudo)
        (( i += 1 ))
        while (( i < n )) && [[ "${toks[i]}" == -* ]]; do
          tok="${toks[i]}"
          case "$tok" in
            -u|-g|-h|-p|-C|-R|-T) (( i += 2 )) ;;
            *) (( i += 1 )) ;;
          esac
        done
        ;;
      command)
        (( i += 1 ))
        if (( i < n )) && [[ "${toks[i]}" == "-v" || "${toks[i]}" == "-V" ]]; then
          _opk_guard_exe="command-query"
          return 0
        fi
        while (( i < n )) && [[ "${toks[i]}" == "-p" ]]; do (( i += 1 )); done
        ;;
      env)
        (( i += 1 ))
        while (( i < n )); do
          tok="${toks[i]}"
          if _opk_guard_is_assignment "$tok"; then
            (( i += 1 ))
            continue
          fi
          case "$tok" in
            -i|--ignore-environment|-0|--null) (( i += 1 )); continue ;;
            -u|--unset|-C|--chdir) (( i += 2 )); continue ;;
            --unset=*|--chdir=*) (( i += 1 )); continue ;;
          esac
          break
        done
        ;;
      *)
        _opk_guard_exe="$exe"
        (( i += 1 ))
        while (( i < n )); do
          _opk_guard_args+=("${toks[i]}")
          (( i += 1 ))
        done
        return 0
        ;;
    esac
  done
}

_opk_guard_rm_danger() {
  local recursive=0 force=0 arg
  for arg in "$@"; do
    [[ "$arg" == "--" ]] && break
    [[ "$arg" == "--recursive" ]] && recursive=1
    [[ "$arg" == "--force" ]] && force=1
    if _opk_guard_short_has "$arg" r || _opk_guard_short_has "$arg" R; then recursive=1; fi
    if _opk_guard_short_has "$arg" f || _opk_guard_short_has "$arg" F; then force=1; fi
  done
  (( recursive && force ))
}

_opk_guard_git_danger() {
  local -a args=("$@")
  local i=0 n=${#args[@]} arg sub
  while (( i < n )); do
    arg="${args[i]}"
    case "$arg" in
      -C|-c|--git-dir|--work-tree|--namespace) (( i += 2 )); continue ;;
      --git-dir=*|--work-tree=*|--namespace=*) (( i += 1 )); continue ;;
    esac
    break
  done

  (( i < n )) || return 1
  sub="${args[i]}"
  (( i += 1 ))

  case "$sub" in
    reset)
      while (( i < n )); do
        if [[ "${args[i]}" == "--hard" ]]; then
          _opk_guard_violation="git reset --hard: mất thay đổi chưa commit"
          return 0
        fi
        (( i += 1 ))
      done
      ;;
    clean)
      while (( i < n )); do
        if [[ "${args[i]}" == "--force" ]] || _opk_guard_short_has "${args[i]}" f || _opk_guard_short_has "${args[i]}" F; then
          _opk_guard_violation="git clean -f: xóa untracked files"
          return 0
        fi
        (( i += 1 ))
      done
      ;;
    push)
      while (( i < n )); do
        if [[ "${args[i]}" == "--force" || "${args[i]}" == --force-with-lease* ]] || _opk_guard_short_has "${args[i]}" f; then
          _opk_guard_violation="git push --force/-f: ghi đè lịch sử remote"
          return 0
        fi
        (( i += 1 ))
      done
      ;;
  esac
  return 1
}

_opk_guard_scan_text_core() {
  local text="$1" depth="${2:-0}" seg payload i host_seen=0 arg
  (( depth <= 6 )) || return 1

  _opk_guard_split_segments "$text"
  local -a segments=("${_opk_guard_segments[@]}")

  for seg in "${segments[@]}"; do
    _opk_guard_tokenize "$seg"
    local -a tokens=("${_opk_guard_tokens[@]}")
    ((${#tokens[@]})) || continue

    _opk_guard_unwrap tokens
    local exe="$_opk_guard_exe"
    local -a args=("${_opk_guard_args[@]}")

    case "$exe" in
      rm)
        if _opk_guard_rm_danger "${args[@]}"; then
          _opk_guard_violation="rm recursive+force: xóa dữ liệu không thể phục hồi"
          return 0
        fi
        ;;
      git)
        if _opk_guard_git_danger "${args[@]}"; then return 0; fi
        ;;
      bash|sh|zsh)
        i=0
        while (( i < ${#args[@]} )); do
          arg="${args[i]}"
          if [[ "$arg" =~ ^-[A-Za-z]*c[A-Za-z]*$ ]]; then
            payload="${args[i+1]:-}"
            if [[ -n "$payload" ]] && _opk_guard_scan_text_core "$payload" "$((depth + 1))"; then
              _opk_guard_violation="$exe -c: $_opk_guard_violation"
              return 0
            fi
            break
          fi
          (( i += 1 ))
        done
        ;;
      eval)
        payload="${args[*]:-}"
        if [[ -n "$payload" ]] && _opk_guard_scan_text_core "$payload" "$((depth + 1))"; then
          _opk_guard_violation="eval: $_opk_guard_violation"
          return 0
        fi
        ;;
      ssh)
        i=0
        while (( i < ${#args[@]} )); do
          arg="${args[i]}"
          if [[ "$arg" == -* ]]; then
            case "$arg" in
              -b|-c|-D|-E|-e|-F|-I|-i|-J|-L|-l|-m|-O|-o|-p|-Q|-R|-S|-W|-w) (( i += 2 )) ;;
              *) (( i += 1 )) ;;
            esac
            continue
          fi
          (( i += 1 )) # host
          break
        done
        if (( i < ${#args[@]} )); then
          payload="${args[*]:i}"
          if _opk_guard_scan_text_core "$payload" "$((depth + 1))"; then
            _opk_guard_violation="ssh payload: $_opk_guard_violation"
            return 0
          fi
        fi
        ;;
    esac
  done
  return 1
}

_opk_guard_pipe_to_shell() {
  local text="$1" left right first
  # Remove || so only a real single pipe is considered.
  local work="${text//||/$'\034'}"
  while [[ "$work" == *"|"* ]]; do
    left="${work%%|*}"
    right="${work#*|}"
    first="${right%%|*}"
    _opk_guard_tokenize "$first"
    local -a tokens=("${_opk_guard_tokens[@]}")
    if ((${#tokens[@]})); then
      _opk_guard_unwrap tokens
      case "$_opk_guard_exe" in
        bash|sh|zsh)
          local has_operand=0 a
          for a in "${_opk_guard_args[@]}"; do
            [[ "$a" == -* ]] || has_operand=1
          done
          if (( ! has_operand )); then return 0; fi
          ;;
      esac
    fi
    work="$right"
  done
  return 1
}

_opk_guard_sensitive_path() {
  local p="${1//\\//}"
  p="${p#"${p%%[![:space:]]*}"}"
  [[ -n "$p" ]] || return 1
  local low="${p,,}"
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

_OPK_SQL_CLIENT='(^|[^a-zA-Z0-9_])(mysql|psql|sqlite3?|sqlcmd)([^a-zA-Z0-9_]|$)'
_OPK_SQL_DROP='(^|[^a-zA-Z0-9_])(DROP[[:space:]]+TABLE|DROP[[:space:]]+DATABASE)([^a-zA-Z0-9_]|$)'
_OPK_SQL_TRUNCATE='(^|[^a-zA-Z0-9_])TRUNCATE[[:space:]]+([a-zA-Z0-9_]|TABLE)'
_OPK_SQL_DELETE='(^|[^a-zA-Z0-9_])DELETE[[:space:]]+FROM([^a-zA-Z0-9_]|$)'
_OPK_SQL_WHERE='(^|[^a-zA-Z0-9_])WHERE([^a-zA-Z0-9_]|$)'
_OPK_REDIRECT='([[:space:]]*(2?>>?|&>|&>>|1>>?|3>>?)[[:space:]]*)([^[:space:]&|;>]+)'
_OPK_TEE='([[:space:]]*tee[[:space:]]+)([^[:space:]&|;>]+)'

_opk_guard_redirect_targets() {
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

opk_guard_scan() {
  local cmd="${1:-}" root="${2:-${OPK_GUARD_ROOT:-$PWD}}" t
  _opk_guard_violation=""
  [[ -n "$cmd" ]] || return 0

  if _opk_guard_scan_text_core "$cmd" 0; then
    _opk_guard_emit_block "$cmd"
    return 1
  fi

  if _opk_guard_pipe_to_shell "$cmd"; then
    _opk_guard_violation="pipe-to-shell: curl/wget/... | sh|bash|zsh — rủi ro thực thi mã từ xa"
    _opk_guard_emit_block "$cmd"
    return 1
  fi

  if [[ "$cmd" =~ $_OPK_SQL_CLIENT ]]; then
    if [[ "$cmd" =~ $_OPK_SQL_DROP || "$cmd" =~ $_OPK_SQL_TRUNCATE ]] || \
       { [[ "$cmd" =~ $_OPK_SQL_DELETE ]] && [[ ! "$cmd" =~ $_OPK_SQL_WHERE ]]; }; then
      _opk_guard_violation="SQL DROP/TRUNCATE/DELETE không WHERE: mất dữ liệu bảng"
      _opk_guard_emit_block "$cmd"
      return 1
    fi
  fi

  if [[ "$cmd" == *">"* || "$cmd" == *tee* ]]; then
    _opk_guard_redirect_targets "$cmd"
    for t in "${_opk_guard_targets[@]:-}"; do
      if _opk_guard_sensitive_path "$t"; then
        _opk_guard_violation="redirect/tee vào file nhạy cảm: $t"
        _opk_guard_emit_block "$cmd"
        return 1
      fi
    done
  fi

  return 0
}
