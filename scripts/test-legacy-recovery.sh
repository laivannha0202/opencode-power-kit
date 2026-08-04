#!/usr/bin/env bash
# Legacy archive manifest + recovery tests for merge-opk-project.py / opk recover-legacy.
# Verifies manifest creation, byte-identical recovery, idempotency, tamper
# detection, and fail-closed path handling.
# Uses only temporary HOME/project state (sibling of HOME/kit — never /tmp).
# shellcheck disable=SC2016  # Child-shell snippets intentionally expand positional parameters there.
set -euo pipefail

SOURCE_KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MERGE="$SOURCE_KIT_DIR/scripts/merge-opk-project.py"
OPK="$SOURCE_KIT_DIR/bin/opk"
PASS=0
FAIL=0

REAL_HOME=""
REAL_HOME_PARENT=""
KIT_REAL="$(realpath -m -- "$SOURCE_KIT_DIR")"
KIT_PARENT="$(realpath -m -- "$(dirname "$KIT_REAL")")"
if [[ -n "${HOME:-}" && "$HOME" == /* ]]; then
  REAL_HOME="$(realpath -m -- "$HOME")"
  [[ "$REAL_HOME" == "/" ]] || REAL_HOME_PARENT="$(realpath -m -- "$(dirname "$REAL_HOME")")"
fi

make_test_root() {
  local raw_candidate candidate created root
  for raw_candidate in "$REAL_HOME" "$REAL_HOME_PARENT" "$KIT_PARENT"; do
    [[ -n "$raw_candidate" ]] || continue
    candidate="$(realpath -m -- "$raw_candidate" 2>/dev/null)" || continue
    [[ -d "$candidate" && -w "$candidate" ]] || continue
    case "$candidate" in
      /|/tmp|/tmp/*|/var/tmp|/var/tmp/*|"$KIT_REAL"|"$KIT_REAL"/*) continue ;;
    esac
    if created="$(mktemp -d "$candidate/.opk-legacy-tests.XXXXXX" 2>/dev/null)"; then
      if ! root="$(realpath -e -- "$created" 2>/dev/null)"; then
        rm -rf -- "$created"
        continue
      fi
      case "$root" in
        "$candidate"/.opk-legacy-tests.*) ;;
        *) rm -rf -- "$created"; continue ;;
      esac
      case "$root" in
        /|/tmp|/tmp/*|/var/tmp|/var/tmp/*|"$KIT_REAL"|"$KIT_REAL"/*)
          rm -rf -- "$created"
          continue
          ;;
      esac
      printf '%s\n' "$root"
      return 0
    fi
  done
  return 1
}

if ! TMP="$(make_test_root)"; then
  printf 'test-legacy-recovery: cannot create a safe sibling temporary directory\n' >&2
  exit 1
fi
if [[ -z "$TMP" || ! -d "$TMP" || "$TMP" == "/" ]]; then
  printf 'test-legacy-recovery: invalid temporary directory: %s\n' "$TMP" >&2
  exit 1
fi
readonly TMP

cleanup() {
  local tmp_real
  tmp_real="$(realpath -m -- "${TMP:-}" 2>/dev/null)" || return
  case "$tmp_real" in
    "$REAL_HOME"/.opk-legacy-tests.*|"$REAL_HOME_PARENT"/.opk-legacy-tests.*|"$KIT_PARENT"/.opk-legacy-tests.*)
      [[ -d "$tmp_real" && "$tmp_real" != "/" ]] && rm -rf -- "$tmp_real"
      ;;
    *) printf 'test-legacy-recovery: refusing unsafe cleanup path: %s\n' "${TMP:-}" >&2 ;;
  esac
}
trap cleanup EXIT

new_project() { # name -> dir
  local dir="$TMP/$1"
  mkdir -p "$dir/.opencode"
  printf '# legacy fixture\n' >"$dir/AGENTS.md"
  printf '%s\n' "$dir"
}

mk_jsonc_legacy() { # writes JSONC legacy config to the current directory
  printf '{\n  // legacy comment\n  "model": "legacy/model",\n  "permission": { "*": "ask" },\n}\n' \
    >.opencode/opencode.jsonc
}

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  [ok]   %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s (expected: %s, got: %s)\n' "$label" "$expected" "$actual" >&2
    FAIL=$((FAIL + 1))
  fi
}

manifest_field() { # dir field -> value
  python3 -c '
import json
import sys
manifest = json.load(open(sys.argv[1], encoding="utf-8"))
print(manifest.get(sys.argv[2]))
' "$1/manifest.json" "$2"
}

printf 'Legacy archive + recovery\n'

# --- T1: migrate writes a manifest alongside the archived config ----------
P="$(new_project arc-manifest)"
( cd "$P" && mk_jsonc_legacy )
ORIG_CONTENT="$(cat "$P/.opencode/opencode.jsonc")"
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1
MAP=("$P"/.opk-trash/legacy-config-*/)
ARCHIVE="${MAP[0]%/}"
check "archive dir created" "1" "$([[ -n "$ARCHIVE" && -d "$ARCHIVE" ]] && echo 1 || echo 0)"
check "manifest created" "1" "$([[ -f "$ARCHIVE/manifest.json" ]] && echo 1 || echo 0)"
check "manifest schema" "opk-legacy-archive/v1" "$(manifest_field "$ARCHIVE" schema)"
check "manifest original path" ".opencode/opencode.jsonc" "$(manifest_field "$ARCHIVE" original)"
check "manifest moved_to path" ".opk-trash/${ARCHIVE##*/}/opencode.jsonc" "$(manifest_field "$ARCHIVE" moved_to)"
check "manifest sha256 matches content" "1" "$(python3 -c "
import hashlib, json, sys
m = json.load(open('$ARCHIVE/manifest.json', encoding='utf-8'))
sys.exit(0 if m['sha256'] == hashlib.sha256(open('$ARCHIVE/opencode.jsonc','rb').read()).hexdigest() else 1)" && echo 1 || echo 0)"
check "manifest mode recorded" "0o$(stat -c '%a' "$ARCHIVE/opencode.jsonc")" "$(python3 -c "
import json, sys
m = json.load(open('$ARCHIVE/manifest.json', encoding='utf-8'))
print(oct(m['mode']))")"
check "archived content byte-identical" "$ORIG_CONTENT" "$(cat "$ARCHIVE/opencode.jsonc")"
check "legacy file removed from .opencode" "absent" "$([[ -e "$P/.opencode/opencode.jsonc" ]] && echo present || echo absent)"

# --- T2: opk recover-legacy restores byte-identically ----------------------
RECOVER_OUT="$(cd "$P" && "$OPK" recover-legacy 2>&1)" || true
check "recover restores original content" "$ORIG_CONTENT" "$(cat "$P/.opencode/opencode.jsonc")"
check "recover reports restored path" "1" "$(grep -c 'legacy config recovered -> .opencode/opencode.jsonc' <<<"$RECOVER_OUT")"
check "recover marks manifest recovered" "marked" "$([[ "$(manifest_field "$ARCHIVE" recovered_at)" != "None" ]] && echo marked || echo null)"
check "recover keeps archive dir" "1" "$([[ -d "$ARCHIVE" ]] && echo 1 || echo 0)"

# --- T3: recover is idempotent ----------------------------------------------
ALREADY_OUT="$(cd "$P" && "$OPK" recover-legacy 2>&1)" || true
check "recover again is a no-op" "1" "$(grep -c 'legacy config already in place' <<<"$ALREADY_OUT")"
check "recover again keeps content" "$ORIG_CONTENT" "$(cat "$P/.opencode/opencode.jsonc")"

# --- T4: no archives -> clean message, exit 0 -------------------------------
P="$(new_project arc-none)"
NOARC_OUT="$(cd "$P" && "$OPK" recover-legacy 2>&1)" || true
check "no archives is a clean no-op" "1" "$(grep -c 'no legacy archives to recover' <<<"$NOARC_OUT")"

# --- T5: tampered archived content is refused -------------------------------
P="$(new_project arc-tamper)"
( cd "$P" && mk_jsonc_legacy )
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1
TARCHIVE=("$P"/.opk-trash/legacy-config-*/)
TARCHIVE="${TARCHIVE[0]%/}"
printf '{"model":"evil"}\n' >"$TARCHIVE/opencode.jsonc"
RC=0
TAMPER_OUT="$(cd "$P" && "$OPK" recover-legacy 2>&1)" || RC=$?
check "tampered archive is refused" "1" "$([[ "$RC" -ne 0 ]] && echo 1 || echo 0)"
check "tamper refusal explains itself" "1" "$(grep -q 'checksum mismatch' <<<"$TAMPER_OUT" && echo 1 || echo 0)"

# --- T6: symlinked .opk-trash is refused -------------------------------------
P="$(new_project arc-symlink)"
( cd "$P" && mk_jsonc_legacy )
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1
rm -rf "$P/.opk-trash"
ln -s "$TMP" "$P/.opk-trash"
RC=0
SYML_OUT="$(cd "$P" && "$OPK" recover-legacy 2>&1)" || RC=$?
check "symlinked trash is refused" "1" "$([[ "$RC" -ne 0 ]] && echo 1 || echo 0)"
check "symlink refusal explains itself" "1" "$(grep -q 'unsafe trash directory' <<<"$SYML_OUT" && echo 1 || echo 0)"

# --- T7: explicit archive dir argument ---------------------------------------
P="$(new_project arc-explicit)"
( cd "$P" && mk_jsonc_legacy )
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1
EARC=("$P"/.opk-trash/legacy-config-*/)
EARC="${EARC[0]%/}"
rm -f "$P/.opencode/opencode.jsonc"
EXP_OUT="$(cd "$P" && "$OPK" recover-legacy "$EARC" 2>&1)" || true
check "explicit archive restores file" "$ORIG_CONTENT" "$(cat "$P/.opencode/opencode.jsonc")"
check "explicit archive reported" "1" "$(grep -c 'legacy config recovered' <<<"$EXP_OUT")"

# --- T8: conflicting existing file is refused --------------------------------
P="$(new_project arc-conflict)"
( cd "$P" && mk_jsonc_legacy )
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1
printf '{"model":"other/kept"}\n' >"$P/.opencode/opencode.jsonc"
RC=0
CONF_OUT="$(cd "$P" && "$OPK" recover-legacy 2>&1)" || RC=$?
check "conflicting file is refused" "1" "$([[ "$RC" -ne 0 ]] && echo 1 || echo 0)"
check "conflict refusal explains itself" "1" "$(grep -q 'refusing to overwrite existing file' <<<"$CONF_OUT" && echo 1 || echo 0)"
check "conflicting file untouched" '{"model":"other/kept"}' "$(cat "$P/.opencode/opencode.jsonc")"

# --- T9: escaping manifest path is refused ------------------------------------
P="$(new_project arc-escape)"
mkdir -p "$P/.opk-trash/legacy-config-escape-1"
printf '{"schema":"opk-legacy-archive/v1","archived_at":"20260101-000000-000000000-1","original":"../escape","moved_to":".opk-trash/legacy-config-escape-1/opencode.jsonc","sha256":"abc","mode":420,"recovered_at":null}\n' \
  >"$P/.opk-trash/legacy-config-escape-1/manifest.json"
printf '{"model":"evil"}\n' >"$P/.opk-trash/legacy-config-escape-1/opencode.jsonc"
RC=0
ESC_OUT="$(cd "$P" && "$OPK" recover-legacy 2>&1)" || RC=$?
check "escaping manifest path is refused" "1" "$([[ "$RC" -ne 0 ]] && echo 1 || echo 0)"
check "escape refusal explains itself" "1" "$(grep -q 'unsafe archive path' <<<"$ESC_OUT" && echo 1 || echo 0)"
check "escape did not write outside project" "0" "$([[ -e "$TMP/escape" ]] && echo 1 || echo 0)"

printf '\nLegacy archive + recovery: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
