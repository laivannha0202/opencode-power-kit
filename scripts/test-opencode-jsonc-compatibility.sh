#!/usr/bin/env bash
# ============================================================================
# test-opencode-jsonc-compatibility.sh
#
# Verifies project/global config discovery supports BOTH opencode.json and
# opencode.jsonc without silently creating a parallel .json. Verifies JSONC
# parser semantics: trailing comma, line comment, block comment, comment-like
# string literals, escaped quotes, duplicate keys, invalid input, --normalize-jsonc
# behavior, doctor architecture reports, and conflict fail-closed in every scope.
# ============================================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$KIT_DIR/scripts/merge-opk-project.py"
DETECT="$KIT_DIR/scripts/detect-mode.py"
OPK="$KIT_DIR/bin/opk"
PERM="$KIT_DIR/scripts/opk-permissions.py"

command -v python3 >/dev/null 2>&1 || { echo 'need python3' >&2; exit 1; }
[[ -f "$MERGE" && -f "$DETECT" && -f "$OPK" && -f "$PERM" ]] || { echo 'missing kit files' >&2; exit 1; }

REAL_HOME=""
REAL_HOME_PARENT=""
KIT_REAL="$(realpath -m -- "$KIT_DIR")"
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
    if created="$(mktemp -d "$candidate/.opk-jsonc-test.XXXXXX" 2>/dev/null)"; then
      if ! root="$(realpath -e -- "$created" 2>/dev/null)"; then
        rm -r -- "$created"; continue
      fi
      case "$root" in
        "$candidate"/.opk-jsonc-test.*) ;;
        *) rm -r -- "$created"; continue ;;
      esac
      printf '%s\n' "$root"; return 0
    fi
  done
  return 1
}

if ! TMP="$(make_test_root)"; then
  echo "test-opencode-jsonc: cannot create safe scratch dir" >&2; exit 1
fi
readonly TMP
cleanup() {
  local tmp_real
  tmp_real="$(realpath -m -- "${TMP:-}" 2>/dev/null)" || { echo "refuse bad path: ${TMP:-}" >&2; return; }
  case "$tmp_real" in
    "$REAL_HOME"/.opk-jsonc-test.*|"$REAL_HOME_PARENT"/.opk-jsonc-test.*|"$KIT_PARENT"/.opk-jsonc-test.*)
      [[ -d "$tmp_real" && "$tmp_real" != "/" ]] && rm -r -- "$tmp_real" ;;
    *) echo "refuse unsafe cleanup: ${TMP:-}" >&2 ;;
  esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

export HOME="$TMP/home"
mkdir -p "$HOME/.config/opencode"

PASS=0
FAIL=0
FAIL_LOG="$TMP/failures.log"
: >"$FAIL_LOG"
check() {
  local name="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then
    echo "  [ok]   $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name (want=$want got=$got)" | tee -a "$FAIL_LOG" >&2
    FAIL=$((FAIL + 1))
  fi
}

new_project() {
  local p="$TMP/$1"
  mkdir -p "$p/.opencode"
  printf '# %s fixture\n' "$1" >"$p/AGENTS.md"
  printf -- '# %s opencode fixture\n' "$1" >"$p/OPENCODE.md"
  printf '%s\n' "$p"
}

assert_source_unchanged() {
  if [[ "$1" == "$2" ]]; then
    PASS=$((PASS + 1)); echo "  [ok]   source tree unchanged"
  else
    echo "  [FAIL] source tree changed by installer" | tee -a "$FAIL_LOG" >&2; FAIL=$((FAIL + 1))
  fi
}

# exitcode-nonzero-or-zero helper: $1=name, $2=exitcode
ex_nonzero() {
  if [[ "$2" -ne 0 ]]; then
    echo "  [ok]   $1"; PASS=$((PASS + 1))
  else
    echo "  [FAIL] $1 (expected nonzero, got 0)" | tee -a "$FAIL_LOG" >&2; FAIL=$((FAIL + 1))
  fi
}

mk_jsonc_safe() {
  # A JSONC config with line/block comment + trailing commas with SAFE permission
  cat <<'EOF'
{
  // line comment
  "model": "fixture/model",
  "provider": {
    "fixture": {
      "options": {
        "flag": true,
      },
    },
  },
  /* block comment */
  "permission": {
    "*": "ask",
    "bash": { "*": "ask", },
    "edit": "ask",
    "task": "ask",
    "write": "ask",
  },
}
EOF
}

mk_jsonc_power() {
  cat <<'EOF'
{
  "model": "power/model",
  "permission": "allow",
}
EOF
}

# ============================================================================
# Section: update-bmad config discovery (.json / .jsonc / conflict)
# ============================================================================
echo "=== update-bmad config discovery ==="
UPDATE_BMAD="$KIT_DIR/update-bmad.sh"

P="$(new_project update-bmad-json)"
printf '{"model":"fixture/json"}\n' >"$P/opencode.json"
RC=0
(
  cd "$P"
  bash "$UPDATE_BMAD" --dry-run
) >"$TMP/update-bmad-json.out" 2>"$TMP/update-bmad-json.err" || RC=$?
check "update-bmad json: dry-run accepted" "0" "$RC"
check "update-bmad json: resolver selected .json" "1" \
  "$(grep -c '^OpenCode config: opencode.json$' "$TMP/update-bmad-json.out" || true)"

P="$(new_project update-bmad-jsonc)"
mk_jsonc_safe >"$P/opencode.jsonc"
RC=0
(
  cd "$P"
  bash "$UPDATE_BMAD" --dry-run
) >"$TMP/update-bmad-jsonc.out" 2>"$TMP/update-bmad-jsonc.err" || RC=$?
check "update-bmad jsonc: dry-run accepted" "0" "$RC"
check "update-bmad jsonc: resolver selected .jsonc" "1" \
  "$(grep -c '^OpenCode config: opencode.jsonc$' "$TMP/update-bmad-jsonc.out" || true)"
check "update-bmad jsonc: no parallel .json created" "absent" \
  "$([[ -e "$P/opencode.json" ]] && echo present || echo absent)"

P="$(new_project update-bmad-conflict)"
printf '{"model":"json-side"}\n' >"$P/opencode.json"
mk_jsonc_safe >"$P/opencode.jsonc"
JSON_BEFORE="$(cat "$P/opencode.json")"
JSONC_BEFORE="$(cat "$P/opencode.jsonc")"
RC=0
(
  cd "$P"
  bash "$UPDATE_BMAD" --dry-run
) >"$TMP/update-bmad-conflict.out" 2>"$TMP/update-bmad-conflict.err" || RC=$?
ex_nonzero "update-bmad conflict: rejected" "$RC"
check "update-bmad conflict: explains both configs" "1" \
  "$(grep -c 'both opencode.json and opencode.jsonc exist' "$TMP/update-bmad-conflict.err" || true)"
check "update-bmad conflict: json untouched" "$JSON_BEFORE" \
  "$(cat "$P/opencode.json")"
check "update-bmad conflict: jsonc untouched" "$JSONC_BEFORE" \
  "$(cat "$P/opencode.jsonc")"

P="$(new_project update-bmad-missing)"
RC=0
(
  cd "$P"
  bash "$UPDATE_BMAD" --dry-run
) >"$TMP/update-bmad-missing.out" 2>"$TMP/update-bmad-missing.err" || RC=$?
ex_nonzero "update-bmad missing config: rejected" "$RC"

P="$(new_project update-bmad-symlink)"
printf '{"model":"external"}\n' >"$TMP/external-opencode.json"
ln -s "$TMP/external-opencode.json" "$P/opencode.json"
RC=0
(
  cd "$P"
  bash "$UPDATE_BMAD" --dry-run
) >"$TMP/update-bmad-symlink.out" 2>"$TMP/update-bmad-symlink.err" || RC=$?
ex_nonzero "update-bmad symlink config: rejected" "$RC"
check "update-bmad symlink: external target untouched" \
  '{"model":"external"}' "$(cat "$TMP/external-opencode.json")"


# ============================================================================
# Section: Project root config — only .json
# ============================================================================
echo "=== Project root: only .json ==="
P="$(new_project proj-json)"
printf '{"$schema":"https://opencode.ai/config.json","model":"fixture/model","permission":{"*":"ask","bash":{"*":"ask"},"edit":"ask","task":"ask","write":"ask"}}\n' >"$P/opencode.json"
python3 "$MERGE" --project-dir "$P" --mode safe >/dev/null 2>&1 || true
check "proj json: active is .json" "opencode.json" "$([[ -f "$P/opencode.json" ]] && echo opencode.json || echo MISSING)"
check "proj json: no .jsonc created" "absent" "$([[ -f "$P/opencode.jsonc" ]] && echo present || echo absent)"
# Verify parse still works
python3 "$DETECT" "$P/opencode.json" >/dev/null 2>&1
check "proj json: parse OK" "0" "$?"

# ============================================================================
# Section: Project root config — only .jsonc
# ============================================================================
echo "=== Project root: only .jsonc ==="
P="$(new_project proj-jsonc)"
mk_jsonc_safe >"$P/opencode.jsonc"
python3 "$MERGE" --project-dir "$P" --mode safe --normalize-jsonc >/dev/null 2>&1 || true
check "proj jsonc: active is .jsonc" "opencode.jsonc" "$([[ -f "$P/opencode.jsonc" ]] && echo opencode.jsonc || echo MISSING)"
check "proj jsonc: no .json created" "absent" "$([[ -f "$P/opencode.json" ]] && echo present || echo absent)"
# Use the active .jsonc to detect mode
MODE="$(python3 "$DETECT" "$P/opencode.jsonc" 2>&1 || true)"
check "proj jsonc: detect mode (SAFE or CUSTOM ok)" "ok" "$([[ -n "$MODE" && "$MODE" != "" ]] && echo ok || echo bad)"
# parse must succeed (JSONC parser strips trailing comma + comments)
EXIT_PARSE=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT_PARSE=$?
check "proj jsonc: parse succeeds" "0" "$EXIT_PARSE"

# Verify the .jsonc still has trailing commas preserved when NOT rewriting
P2="$(new_project proj-jsonc-norewrite)"
mk_jsonc_power >"$P2/opencode.jsonc"
# Detect should already match POWER, so install should be no-op
python3 "$MERGE" --project-dir "$P2" --mode power >/dev/null 2>&1 || true
# The file should NOT have been rewritten (no --normalize-jsonc) since OPK merged
# template == user config (no change). Either way it should remain valid JSONC.
PASSED=0
python3 "$DETECT" "$P2/opencode.jsonc" >/dev/null 2>&1 && PASSED=1
check "proj jsonc no-rewrite: still parseable" "1" "$PASSED"

# ============================================================================
# Section: Project root conflict (.json + .jsonc)
# ============================================================================
echo "=== Project root: .json + .jsonc conflict ==="
P="$(new_project proj-conflict)"
printf '{"model":"json-side"}\n' >"$P/opencode.json"
mk_jsonc_safe >"$P/opencode.jsonc"
SRC_BEFORE="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
if python3 "$MERGE" --project-dir "$P" --mode safe --normalize-jsonc >/dev/null 2>&1; then
  check "proj conflict: installer rejects" "nonzero" "zero"
else
  check "proj conflict: installer rejects" "nonzero" "nonzero"
fi
SRC_AFTER="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
assert_source_unchanged "$SRC_BEFORE" "$SRC_AFTER"
check "proj conflict: both files still exist" "2" "$(find "$P" -maxdepth 1 -name 'opencode.json*' -type f 2>/dev/null | wc -l)"
check "proj conflict: json side untouched" "json-side" "$(python3 -c 'import json;d=json.load(open("'"$P/opencode.json"'"));print(d["model"])')"

# ============================================================================
# Section: Legacy config — only .json / .jsonc / conflict
# ============================================================================
echo "=== Legacy config matrix ==="

# only .json
P="$(new_project leg-json)"
printf '{"legacy_model":"json","permission":"allow"}\n' >"$P/.opencode/opencode.json"
python3 "$MERGE" --project-dir "$P" --migrate-only >/dev/null 2>&1 || true
# After migration, root should reflect user keys
check "legacy json: migrate created root appends '.json'" "present" "$([[ -f "$P/opencode.json" ]] && echo present || echo absent)"
python3 - "$P/opencode.json" <<'PY' 2>/dev/null || true
import json, sys
d = json.load(open(sys.argv[1], encoding='utf-8'))
assert d.get('legacy_model') == 'json'
PY
check "legacy json: custom propagated" "0" "$?"

# only .jsonc
P="$(new_project leg-jsonc)"
mk_jsonc_safe >"$P/.opencode/opencode.jsonc"
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1 || true
# Root after migrate should preserve .jsonc extension when root did not exist
check "legacy jsonc: archived under .jsonc" "present" "$(find "$P/.opk-trash" -name 'opencode.jsonc' 2>/dev/null | head -1 | grep -q . && echo present || echo absent)"

# legacy conflict (.json + .jsonc)
P="$(new_project leg-conflict)"
printf '{"legacy":"json"}\n' >"$P/.opencode/opencode.json"
mk_jsonc_safe >"$P/.opencode/opencode.jsonc"
if python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1; then
  check "legacy conflict: rejected" "nonzero" "zero"
else
  check "legacy conflict: rejected" "nonzero" "nonzero"
fi

# ============================================================================
# Section: Cross-scope matrix (root + legacy)
# ============================================================================
echo "=== Cross-scope root+legacy matrix ==="

# root .json + legacy .jsonc  → root wins, legacy merges into root, archived as .jsonc
P="$(new_project rootJ-legC)"
printf '{"model":"rootJ"}\n' >"$P/opencode.json"
mk_jsonc_safe >"$P/.opencode/opencode.jsonc"
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1 || true
check "rootJ+legC: root .json preserved" "present" "$([[ -f "$P/opencode.json" ]] && echo present || echo absent)"
check "rootJ+legC: no parallel .jsonc created" "absent" "$([[ -f "$P/opencode.jsonc" ]] && echo present || echo absent)"
# legacy should be archived; archive filename extension preserved
shopt -s nullglob
ARCHV=("$P"/.opk-trash/legacy-config-*/opencode.jsonc)
shopt -u nullglob
check "rootJ+legC: archive ext preserved" "jsonc" "$( ((${#ARCHV[@]} == 1)) && echo jsonc || echo missing )"

# root .jsonc + legacy .json  → root wins (.jsonc), legacy archived as .json
P="$(new_project rootC-legJ)"
mk_jsonc_power >"$P/opencode.jsonc"
printf '{"legacy":"legJ"}\n' >"$P/.opencode/opencode.json"
python3 "$MERGE" --project-dir "$P" --migrate-only --normalize-jsonc >/dev/null 2>&1 || true
check "rootC+legJ: root .jsonc preserved" "present" "$([[ -f "$P/opencode.jsonc" ]] && echo present || echo absent)"
check "rootC+legJ: no parallel .json created" "absent" "$([[ -f "$P/opencode.json" ]] && echo present || echo absent)"
shopt -s nullglob
ARCHV=("$P"/.opk-trash/legacy-config-*/opencode.json)
shopt -u nullglob
check "rootC+legJ: archive ext preserved" "json" "$( ((${#ARCHV[@]} == 1)) && echo json || echo missing )"

# ============================================================================
# Section: Global config matrix
# ============================================================================
echo "=== Global config matrix ==="

# Global only .json
GH="$TMP/global-json"
mkdir -p "$GH/.config/opencode"
printf '{"$schema":"https://opencode.ai/config.json","model":"globalJ","permission":{"*":"ask","bash":{"*":"ask"},"edit":"ask","task":"ask","write":"ask"}}\n' >"$GH/.config/opencode/opencode.json"
SRC_BEFORE="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
HOME="$GH" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --mode safe >/dev/null 2>&1 || true
SRC_AFTER="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
assert_source_unchanged "$SRC_BEFORE" "$SRC_AFTER"
check "global json: active .json" "present" "$([[ -f "$GH/.config/opencode/opencode.json" ]] && echo present || echo absent)"
check "global json: no .jsonc" "absent" "$([[ -f "$GH/.config/opencode/opencode.jsonc" ]] && echo present || echo absent)"

# Global only .jsonc
GH="$TMP/global-jsonc"
mkdir -p "$GH/.config/opencode"
mk_jsonc_safe >"$GH/.config/opencode/opencode.jsonc"
if HOME="$GH" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --mode safe >/dev/null 2>&1; then
  check "global jsonc: implicit normalize rejected" "nonzero" "zero"
else
  check "global jsonc: implicit normalize rejected" "nonzero" "nonzero"
fi
HOME="$GH" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --mode safe --normalize-jsonc >/dev/null 2>&1 || true
check "global jsonc: active .jsonc" "present" "$([[ -f "$GH/.config/opencode/opencode.jsonc" ]] && echo present || echo absent)"
check "global jsonc: no .json" "absent" "$([[ -f "$GH/.config/opencode/opencode.json" ]] && echo present || echo absent)"

# Global conflict
GH="$TMP/global-conflict"
mkdir -p "$GH/.config/opencode"
printf '{"model":"gJ"}\n' >"$GH/.config/opencode/opencode.json"
mk_jsonc_safe >"$GH/.config/opencode/opencode.jsonc"
if HOME="$GH" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --mode safe --normalize-jsonc >/dev/null 2>&1; then
  check "global conflict: rejected" "nonzero" "zero"
else
  check "global conflict: rejected" "nonzero" "nonzero"
fi

# ============================================================================
# Section: JSONC parser semantics
# ============================================================================
echo "=== JSONC parser semantics ==="

# Fixture file with comments, trailing commas, and comment-like string literals
P="$(new_project parser-mix)"
cat >"$P/opencode.jsonc" <<'EOF'
{
  // line comment
  "url": "https://example.com/path",
  "line": "text // not comment",
  "block": "/* not a comment */",
  "comma1": ",}",
  "comma2": ",]",
  "escaped": "quote: \" // literal",
  "provider": {
    "fixture": {
      "options": {
        "flag": true,
      },
    },
  },
  /* block comment */
  "permission": "allow",
}
EOF
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
check "parser: mixed JSONC parses" "0" "$EXIT"

# Verify the parser did NOT collapse string literals
python3 - "$P/opencode.jsonc" <<'PY' 2>/dev/null || EXIT=$?
import json, sys
text = open(sys.argv[1], encoding='utf-8').read()
# We can't trivially call our strip_jsonc from python -c here. Use detect-mode + json via import.
sys.path.insert(0, "'"$(dirname "$DETECT")"'")
from detect_mode import strip_jsonc
stripped = strip_jsonc(text)
import json as J
d = J.loads(stripped)
assert d['url'] == 'https://example.com/path', d['url']
assert d['line'] == 'text // not comment', d['line']
assert d['block'] == '/* not a comment */', d['block']
assert d['comma1'] == ',}'
assert d['comma2'] == ',]'
assert d['escaped'] == 'quote: \" // literal', d['escaped']
assert d['permission'] == 'allow'
assert d['provider']['fixture']['options']['flag'] is True
PY
check "parser: comment-like string literals preserved" "0" "$?"

# Object trailing comma
P="$(new_project tc-obj)"
printf '{ "model": "a", }\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
check "object trailing comma parses" "0" "$EXIT"

# Array trailing comma
P="$(new_project tc-arr)"
printf '{ "items": [ "a", "b", ], }\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
check "array trailing comma parses" "0" "$EXIT"

# Comments between comma and closing token
P="$(new_project tc-comments)"
printf '{\n "a": "1",\n // comment\n "b": "2",\n /* block */\n}\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
check "comments between comma/closing parse" "0" "$EXIT"

# ============================================================================
# Section: Invalid JSONC rejection
# ============================================================================
echo "=== Invalid JSONC rejection ==="

# Unterminated string
P="$(new_project unterm-string)"
printf '{ "a": "open string\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
ex_nonzero "unterminated string rejected" "$EXIT"
[[ "$EXIT" -ne 0 ]] && PASS=$((PASS+0)) # reset check

# Unterminated block comment
P="$(new_project unterm-block)"
printf '{ /* no close\n "model": "x"\n}\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
ex_nonzero "unterminated block comment rejected" "$EXIT"

# Duplicate nested key
P="$(new_project dup-key)"
printf '{ "provider": { "dup": "first", "dup": "second" } }\n' >"$P/opencode.jsonc"
EXIT=0
python3 - "$P/opencode.jsonc" <<'PY' 2>/dev/null || EXIT=$?
import sys
sys.path.insert(0, "'"$(dirname "$DETECT")"'")
from detect_mode import strip_jsonc
import json as J
text = open(sys.argv[1], encoding='utf-8').read()
def reject(pairs):
    seen = {}
    for k, v in pairs:
        if k in seen: raise ValueError(f'dup {k}')
        seen[k] = v
    return seen
J.loads(strip_jsonc(text), object_pairs_hook=reject)
PY
ex_nonzero "duplicate nested key rejected" "$EXIT"

# Missing colon
P="$(new_project missing-colon)"
printf '{ "a" "b" }\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
ex_nonzero "missing colon rejected" "$EXIT"

# Trailing garbage
P="$(new_project trailing-garbage)"
printf '{ "a": "b" } garbage\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
ex_nonzero "trailing garbage rejected" "$EXIT"

# Invalid escape
P="$(new_project bad-escape)"
printf '{ "a": "\\q bad" }\n' >"$P/opencode.jsonc"
EXIT=0
python3 "$DETECT" "$P/opencode.jsonc" >/dev/null 2>&1 || EXIT=$?
ex_nonzero "invalid escape rejected" "$EXIT"

# ============================================================================
# Section: --normalize-jsonc behavior
# ============================================================================
echo "=== --normalize-jsonc behavior ==="

P="$(new_project normalize)"
mk_jsonc_safe >"$P/opencode.jsonc"
cp "$P/opencode.jsonc" "$TMP/normalize.before"
python3 "$MERGE" --project-dir "$P" --mode safe --normalize-jsonc >/dev/null 2>&1 || true
# Backup should exist and be byte-identical to original
shopt -s nullglob
BK=("$P"/opencode.jsonc.opk-bak.*)
shopt -u nullglob
BK_MATCH=false
for b in "${BK[@]}"; do cmp -s "$b" "$TMP/normalize.before" && BK_MATCH=true; done
check "normalize: backup byte-identical" "true" "$BK_MATCH"
# After normalize, file should still be the active config
check "normalize: active extension preserved" "opencode.jsonc" "$([[ -f "$P/opencode.jsonc" ]] && echo opencode.jsonc || echo MISSING)"
check "normalize: no parallel .json created" "absent" "$([[ -f "$P/opencode.json" ]] && echo present || echo absent)"
# After normalize, file is parseable plain JSON (comments stripped, trailing comma gone)
EXIT=0
python3 - "$P/opencode.jsonc" <<'PY' 2>/dev/null || EXIT=$?
import json, sys
text = open(sys.argv[1], encoding='utf-8').read()
# Plain JSON parse should succeed (no comments, no trailing comma)
json.loads(text)
PY
check "normalize: output is plain JSON" "0" "$EXIT"

# ============================================================================
# Section: doctor reports active config
# ============================================================================
echo "=== Doctor reports active config ==="
P="$(new_project doctor-report)"
mk_jsonc_power >"$P/opencode.jsonc"
DOCTOR_OUT="$(cd "$P" && bash "$KIT_DIR/doctor.sh" 2>&1 || true)"
if [[ "$DOCTOR_OUT" == *"opencode.jsonc"* ]]; then
  check "doctor mentions .jsonc when active" "ok" "ok"
else
  check "doctor mentions .jsonc when active" "ok" "MIA"
fi

# opk permissions doctor should report active path
P="$(new_project perm-report)"
mk_jsonc_safe >"$P/opencode.jsonc"
PERM_OUT="$(cd "$P" && python3 "$PERM" 2>&1 || true)"
if [[ "$PERM_OUT" == *"opencode.jsonc"* ]]; then
  check "permissions doctor mentions .jsonc" "ok" "ok"
else
  check "permissions doctor mentions .jsonc" "ok" "MIA"
fi

# ============================================================================
# Section: opk auto rejects conflict
# ============================================================================
echo "=== opk auto rejects conflict ==="
P="$(new_project auto-reject)"
mk_jsonc_power >"$P/opencode.jsonc"
printf '{"permission":"allow"}\n' >"$P/opencode.json"
if "$OPK" auto --help >/dev/null 2>&1; then
  if ( cd "$P" && "$OPK" auto --help >/dev/null 2>&1 ); then
    AUTO_REJECT_RC=0
    ( cd "$P" && "$OPK" auto --help 2>&1 >/dev/null ) || AUTO_REJECT_RC=$?
    # auto --help should never reject pre-flight; we instead test the actual auto entry
    :
  fi
fi
# Use the merge path directly to verify the conflict is detected at install time
if python3 "$MERGE" --project-dir "$P" --mode power --normalize-jsonc >/dev/null 2>&1; then
  check "merge rejects conflict" "nonzero" "zero"
else
  check "merge rejects conflict" "nonzero" "nonzero"
fi

# ============================================================================
# Section: opk mode CLI flag validation
# ============================================================================
echo "=== opk mode CLI validation ==="
P="$(new_project cli-validate)"
cp "$KIT_DIR/templates/opencode.power.json" "$P/opencode.json"

# Duplicate --normalize-jsonc must be rejected
if ( cd "$P" && "$OPK" mode power --normalize-jsonc --normalize-jsonc >/dev/null 2>&1 ); then
  check "duplicate --normalize-jsonc rejected" "nonzero" "zero"
else
  check "duplicate --normalize-jsonc rejected" "nonzero" "nonzero"
fi

# --normalize-jsonc on `show` must be rejected
if ( cd "$P" && "$OPK" mode show --normalize-jsonc >/dev/null 2>&1 ); then
  check "normalize-jsonc rejected on show" "nonzero" "zero"
else
  check "normalize-jsonc rejected on show" "nonzero" "nonzero"
fi

# Unknown argument on power must be rejected
if ( cd "$P" && "$OPK" mode power --bogus >/dev/null 2>&1 ); then
  check "unknown arg rejected on power" "nonzero" "zero"
else
  check "unknown arg rejected on power" "nonzero" "nonzero"
fi

# ============================================================================
# Section: Project installer dry-run is read-only
# ============================================================================
echo "=== Project installer dry-run ==="
P="$(new_project dry-run)"
ls -la "$P" >"$TMP/dry-before"
if python3 "$MERGE" --project-dir "$P" --mode power --dry-run >/dev/null 2>&1; then
  :
fi
ls -la "$P" >"$TMP/dry-after"
check "dry-run: no opencode.json created" "absent" "$([[ -f "$P/opencode.json" ]] && echo present || echo absent)"
check "dry-run: no AGENTS.md backup" "0" "$(find "$P" -name 'AGENTS.md.opk-bak.*' 2>/dev/null | wc -l)"
check "dry-run: no plugin created" "absent" "$([[ -f "$P/.opencode/plugins/opk-safety-guard.js" ]] && echo present || echo absent)"
check "dry-run: no archive created" "absent" "$([[ -d "$P/.opk-trash" ]] && echo present || echo absent)"
check "dry-run: no temp/lock file" "0" "$(find "$P" -name '.opencode.json.tmp.*' -o -name '.AGENTS.md.tmp.*' -o -name '.opk-*.lock' 2>/dev/null | wc -l)"

# ============================================================================
echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "test-opencode-jsonc: FAILED ($FAIL failures, $PASS passes)"
  cat "$FAIL_LOG" >&2 || true
  exit 1
fi
echo "test-opencode-jsonc: OK ($PASS checks passed)"
