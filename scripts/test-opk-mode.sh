#!/usr/bin/env bash
# ============================================================================
# test-opk-mode.sh
#
# Regression test cho mode detection (POWER / SAFE / CUSTOM).
# Tạo project tạm trong thư mục temp an toàn (KHÔNG ghi vào HOME thật).
# Chạy scripts/detect-mode.py trên từng config và xác minh output.
# ============================================================================
# shellcheck disable=SC2016
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETECT="$KIT_DIR/scripts/detect-mode.py"

if [ ! -f "$DETECT" ]; then
  echo "test-opk-mode: thiếu $DETECT" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "test-opk-mode: cần python3" >&2
  exit 1
fi

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
    if created="$(mktemp -d "$candidate/.opk-mode-test.XXXXXX" 2>/dev/null)"; then
      if ! root="$(realpath -e -- "$created" 2>/dev/null)"; then
        rm -r -- "$created"
        continue
      fi
      case "$root" in
        "$candidate"/.opk-mode-test.*) ;;
        *) rm -r -- "$created"; continue ;;
      esac
      case "$root" in
        /|/tmp|/tmp/*|/var/tmp|/var/tmp/*|"$KIT_REAL"|"$KIT_REAL"/*)
          rm -r -- "$created"
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
  echo "test-opk-mode: không thể tạo thư mục temp sibling an toàn" >&2
  exit 1
fi
readonly TMP
cleanup() {
  local tmp_real
  tmp_real="$(realpath -m -- "${TMP:-}" 2>/dev/null)" || {
    echo "test-opk-mode: từ chối cleanup path không resolve được: ${TMP:-}" >&2
    return
  }
  case "$tmp_real" in
    "$REAL_HOME"/.opk-mode-test.*|"$REAL_HOME_PARENT"/.opk-mode-test.*|"$KIT_PARENT"/.opk-mode-test.*)
      [[ -d "$tmp_real" && "$tmp_real" != "/" ]] && rm -r -- "$tmp_real"
      ;;
    *) echo "test-opk-mode: từ chối cleanup path không an toàn: ${TMP:-}" >&2 ;;
  esac
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

export HOME="$TMP/home"
export OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
export OPK_KIT_DIR="$KIT_DIR"
OPK="$KIT_DIR/bin/opk"
TEST_PROJECT="$TMP/project"
PROJECT_CONFIG="$TEST_PROJECT/opencode.json"
LEGACY_CONFIG="$TEST_PROJECT/.opencode/opencode.json"
mkdir -p "$HOME" "$OPENCODE_CONFIG_DIR" "$TEST_PROJECT/.opencode"
printf '# mode integration fixture\n' >"$TEST_PROJECT/AGENTS.md"

PASS=0
FAIL=0

check() {
  local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "  [ok]   $name => $got"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name => $got (want $want)"
    FAIL=$((FAIL + 1))
  fi
}

show_mode() {
  "$OPK" mode show | awk -F': ' '$1 == "Mode" { print $2 }'
}

# 0) OpenCode wildcard semantics. Keep this aligned with the OpenCode version
# pinned by required CI. Only * and ? are wildcard tokens; [] is literal, and
# a trailing " *" is optional (for example "git *" also matches "git").
if python3 - "$KIT_DIR/scripts" <<'PY'
import sys

sys.path.insert(0, sys.argv[1])
from opk_mode import evaluate_rules, wildcard_match

# * and ? are the only wildcard tokens.
assert wildcard_match("file1.txt", "file?.txt")
assert not wildcard_match("file12.txt", "file?.txt")
assert wildcard_match("prefix-any-suffix", "prefix*suffix")

# Regex/glob character-class syntax is literal in OpenCode permission patterns.
assert not wildcard_match("filea.txt", "file[ab].txt")
assert wildcard_match("file[ab].txt", "file[ab].txt")
assert not wildcard_match("filex.txt", "file[!a].txt")
assert wildcard_match("file[!a].txt", "file[!a].txt")
assert wildcard_match("foo+bar", "foo+bar")

# OpenCode normalizes slashes before matching.
assert wildcard_match(r"C:\Windows\System32\drivers", "C:/Windows/System32/*")

# OpenCode v1.18.20 special-cases a trailing space+star as optional.
assert wildcard_match("git", "git *")
assert wildcard_match("git status", "git *")
assert not wildcard_match("gitx", "git *")

# Permission object order remains last-match-wins.
rules = {
    "*": "allow",
    "*.env": "deny",
    "*.env.example": "allow",
}
assert evaluate_rules(rules, "app.env") == "deny"
assert evaluate_rules(rules, "app.env.example") == "allow"
PY
then
  check "OpenCode wildcard contract" "pass" "pass"
else
  check "OpenCode wildcard contract" "pass" "fail"
fi

# 1) Power template
cp "$KIT_DIR/templates/opencode.power.json" "$TMP/power.json"
check "opencode.power.json" "POWER" "$(python3 "$DETECT" "$TMP/power.json")"

# 2) Safe template
cp "$KIT_DIR/templates/opencode.safe.json" "$TMP/safe.json"
check "opencode.safe.json" "SAFE" "$(python3 "$DETECT" "$TMP/safe.json")"

# 3) Default template (công bố là POWER)
cp "$KIT_DIR/templates/opencode.json" "$TMP/default.json"
check "opencode.json (default)" "POWER" "$(python3 "$DETECT" "$TMP/default.json")"

# 4) Custom config (mixed) -> CUSTOM
cat > "$TMP/custom.json" <<'EOF'
{
  "permission": {
    "*": "ask",
    "bash": { "*": "allow", "rm -rf*": "deny" },
    "write": "ask",
    "edit": "allow",
    "task": "ask"
  }
}
EOF
check "custom (mixed)" "CUSTOM" "$(python3 "$DETECT" "$TMP/custom.json")"

# 5) Top-level string "allow" is an INCOMPLETE Power contract (missing the
#    external_directory / doom_loop denies and the deny contracts) -> CUSTOM.
#    detect-mode.py and opk mode show share one strict engine (opk_mode.py),
#    so both must agree — see check 7 below.
cat > "$TMP/custom2.json" <<'EOF'
{
  "permission": "allow"
}
EOF
check "custom (string allow, incomplete contract)" "CUSTOM" "$(python3 "$DETECT" "$TMP/custom2.json")"

# 6) JSONC comment tolerance — full SAFE contract with a comment -> SAFE
python3 - "$KIT_DIR/templates/opencode.safe.json" > "$TMP/jsonc.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print("// this is a comment")
print(json.dumps(d, indent=2, ensure_ascii=False))
PY
check "jsonc safe" "SAFE" "$(python3 "$DETECT" "$TMP/jsonc.json")"

# 7) Real CLI integration: mode merges the root project config and ignores OPENCODE_CONFIG_DIR.
cat >"$PROJECT_CONFIG" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "fixture/model",
  "provider": {"fixture": {"options": {"custom": true}}},
  "mcp": {"fixture": {"type": "local", "command": ["fixture-mcp"], "enabled": false}},
  "plugin": ["fixture-plugin"],
  "permission": "allow"
}
EOF
cp "$PROJECT_CONFIG" "$TMP/project-config.before"
cp "$KIT_DIR/templates/opencode.power.json" "$TMP/power-template.before"
cp "$KIT_DIR/templates/opencode.safe.json" "$TMP/safe-template.before"
printf '{"$schema":"https://opencode.ai/config.json","share":"manual"}\n' >"$OPENCODE_CONFIG_DIR/opencode.json"

pushd "$TEST_PROJECT" >/dev/null
check "CLI mode show rejects incomplete allow-only contract" "CUSTOM" "$(show_mode)"
if "$OPK" mode safe; then
  check "CLI mode safe target" "SAFE" "$(python3 "$DETECT" "$PROJECT_CONFIG")"
else
  check "CLI mode safe command" "exit 0" "nonzero"
fi
shopt -s nullglob
  mode_backups=("$PROJECT_CONFIG".opk-bak.*)
shopt -u nullglob
power_backup=false
for backup in "${mode_backups[@]}"; do
  cmp -s "$backup" "$TMP/project-config.before" && power_backup=true
done
check "CLI mode safe backup" "true" "$power_backup"
check "CLI mode show (safe)" "SAFE" "$(show_mode)"
python3 - "$PROJECT_CONFIG" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["model"] == "fixture/model"
assert "fixture" in d["provider"]
assert "fixture" in d["mcp"]
assert "fixture-plugin" in d["plugin"]
PY
check "CLI mode safe preserves custom config" "0" "$?"

if "$OPK" mode power; then
  check "CLI mode power target" "POWER" "$(python3 "$DETECT" "$PROJECT_CONFIG")"
else
  check "CLI mode power command" "exit 0" "nonzero"
fi
shopt -s nullglob
mode_backups=("$PROJECT_CONFIG".opk-bak.*)
shopt -u nullglob
safe_backup=false
for backup in "${mode_backups[@]}"; do
  python3 "$DETECT" "$backup" 2>/dev/null | grep -qx SAFE && safe_backup=true
done
check "CLI mode power backup" "true" "$safe_backup"
check "CLI mode show (power)" "POWER" "$(show_mode)"

# 8) Explicit legacy migration keeps custom keys, writes root, and moves legacy to project trash.
mv "$PROJECT_CONFIG" "$LEGACY_CONFIG"
if "$OPK" mode migrate; then
  check "CLI mode migrate creates root config" "true" "$([[ -f "$PROJECT_CONFIG" ]] && echo true || echo false)"
  check "CLI mode migrate retires legacy config" "false" "$([[ -e "$LEGACY_CONFIG" ]] && echo true || echo false)"
  shopt -s nullglob
  migrated_legacy=("$TEST_PROJECT"/.opk-trash/legacy-config-*/opencode.json)
  shopt -u nullglob
  check "CLI mode migrate archives legacy config" "true" "$( ((${#migrated_legacy[@]} == 1)) && echo true || echo false )"
else
  check "CLI mode migrate command" "exit 0" "nonzero"
fi
popd >/dev/null

if [[ "$(cat "$OPENCODE_CONFIG_DIR/opencode.json")" == '{"$schema":"https://opencode.ai/config.json","share":"manual"}' ]]; then
  check "CLI ignores OPENCODE_CONFIG_DIR" "unchanged" "unchanged"
else
  check "CLI ignores OPENCODE_CONFIG_DIR" "unchanged" "modified"
fi
if cmp -s "$TMP/power-template.before" "$KIT_DIR/templates/opencode.power.json" && \
   cmp -s "$TMP/safe-template.before" "$KIT_DIR/templates/opencode.safe.json"; then
  check "CLI leaves templates unchanged" "unchanged" "unchanged"
else
  check "CLI leaves templates unchanged" "unchanged" "modified"
fi

# 9) Parse errors fail closed and leave a recovery backup without replacing the source.
BROKEN_PROJECT="$TMP/broken-project"
mkdir -p "$BROKEN_PROJECT/.opencode"
printf '# broken fixture\n' >"$BROKEN_PROJECT/AGENTS.md"
printf '{ invalid jsonc\n' >"$BROKEN_PROJECT/.opencode/opencode.json"
cp "$BROKEN_PROJECT/.opencode/opencode.json" "$TMP/broken.before"
pushd "$BROKEN_PROJECT" >/dev/null
if "$OPK" mode migrate >/dev/null 2>&1; then
  check "legacy parse error fails closed" "nonzero" "zero"
else
  check "legacy parse error fails closed" "nonzero" "nonzero"
fi
popd >/dev/null
check "legacy parse error preserves original" "unchanged" "$(cmp -s "$TMP/broken.before" "$BROKEN_PROJECT/.opencode/opencode.json" && echo unchanged || echo changed)"
shopt -s nullglob
broken_backups=("$BROKEN_PROJECT/.opencode/opencode.json".opk-bak.*)
shopt -u nullglob
check "legacy parse error creates recovery backup" "true" "$( ((${#broken_backups[@]} == 1)) && echo true || echo false )"

# 10) Root config symlinks are rejected without touching the referent.
SYMLINK_PROJECT="$TMP/symlink-project"
mkdir -p "$SYMLINK_PROJECT"
printf '# symlink fixture\n' >"$SYMLINK_PROJECT/AGENTS.md"
printf '{"sentinel":"unchanged"}\n' >"$TMP/outside-config.json"
ln -s "$TMP/outside-config.json" "$SYMLINK_PROJECT/opencode.json"
pushd "$SYMLINK_PROJECT" >/dev/null
if "$OPK" mode power >/dev/null 2>&1; then
  check "mode rejects symlink config" "nonzero" "zero"
else
  check "mode rejects symlink config" "nonzero" "nonzero"
fi
popd >/dev/null
check "symlink referent remains unchanged" '{"sentinel":"unchanged"}' "$(cat "$TMP/outside-config.json")"

# 11) Concurrent mode writes serialize on the project directory and leave no temp files.
CONCURRENT_PROJECT="$TMP/concurrent-project"
mkdir -p "$CONCURRENT_PROJECT"
printf '# concurrent fixture\n' >"$CONCURRENT_PROJECT/AGENTS.md"
cp "$KIT_DIR/templates/opencode.safe.json" "$CONCURRENT_PROJECT/opencode.json"
(
  cd "$CONCURRENT_PROJECT"
  "$OPK" mode power >/dev/null
) & first_pid=$!
(
  cd "$CONCURRENT_PROJECT"
  "$OPK" mode power >/dev/null
) & second_pid=$!
first_rc=0; wait "$first_pid" || first_rc=$?
second_rc=0; wait "$second_pid" || second_rc=$?
check "concurrent mode runs succeed" "0:0" "$first_rc:$second_rc"
check "concurrent mode result is POWER" "POWER" "$(python3 "$DETECT" "$CONCURRENT_PROJECT/opencode.json")"
shopt -s nullglob
mode_temps=("$CONCURRENT_PROJECT"/.opencode.json.tmp.*)
shopt -u nullglob
check "mode leaves no temporary config" "0" "${#mode_temps[@]}"

# 12) Nested Git projects use the exact current directory, never the Git top-level.
MONO="$TMP/monorepo"
NESTED="$MONO/apps/web"
mkdir -p "$NESTED"
git -C "$MONO" init -q
printf '# root fixture\n' >"$MONO/AGENTS.md"
printf '# nested fixture\n' >"$NESTED/AGENTS.md"
cp "$KIT_DIR/templates/opencode.power.json" "$MONO/opencode.json"
cp "$KIT_DIR/templates/opencode.safe.json" "$NESTED/opencode.json"
pushd "$NESTED" >/dev/null
check "nested SAFE overrides root POWER for doctor" "SAFE" "$(show_mode)"
if "$OPK" auto --help >/dev/null 2>&1; then
  check "nested SAFE blocks auto" "nonzero" "zero"
else
  check "nested SAFE blocks auto" "nonzero" "nonzero"
fi
popd >/dev/null

cp "$KIT_DIR/templates/opencode.safe.json" "$MONO/opencode.json"
cp "$KIT_DIR/templates/opencode.power.json" "$NESTED/opencode.json"
pushd "$NESTED" >/dev/null
check "nested POWER overrides root SAFE for doctor" "POWER" "$(show_mode)"

# Power permissions alone are intentionally insufficient for unattended mode.
# Missing reviewed runtime assets must fail closed until the public mode command
# repairs/installs safety guard + token guard + opk-main.
if "$OPK" auto --help >/dev/null 2>&1; then
  check "nested POWER without runtime assets blocks auto" "nonzero" "zero"
else
  check "nested POWER without runtime assets blocks auto" "nonzero" "nonzero"
fi

if "$OPK" mode power >/dev/null 2>&1; then
  runtime_assets_ok=false
  if [[ -f "$NESTED/.opencode/plugins/opk-safety-guard.js" && \
        -f "$NESTED/.opencode/plugins/opk-token-guard.js" && \
        -f "$NESTED/.opencode/agents/opk-main.md" ]]; then
    runtime_assets_ok=true
  fi
  check "nested POWER repair installs reviewed runtime assets" "true" "$runtime_assets_ok"
else
  check "nested POWER repair command" "zero" "nonzero"
fi

if "$OPK" auto --help >/dev/null 2>&1; then
  check "nested POWER with reviewed runtime allows auto" "zero" "zero"
else
  check "nested POWER with reviewed runtime allows auto" "zero" "nonzero"
fi
popd >/dev/null

# 13) CLI JSONC normalization requires the dedicated explicit flag.
JSONC_PROJECT="$TMP/jsonc-project"
mkdir -p "$JSONC_PROJECT"
printf '# JSONC fixture\n' >"$JSONC_PROJECT/AGENTS.md"
printf '{\n  // preserve by default\n  "model": "fixture/model"\n}\n' >"$JSONC_PROJECT/opencode.json"
cp "$JSONC_PROJECT/opencode.json" "$TMP/jsonc-project.before"
pushd "$JSONC_PROJECT" >/dev/null
if "$OPK" mode power >/dev/null 2>&1; then
  check "CLI mode refuses implicit JSONC normalization" "nonzero" "zero"
else
  check "CLI mode refuses implicit JSONC normalization" "nonzero" "nonzero"
fi
check "CLI mode leaves refused JSONC unchanged" "unchanged" "$(cmp -s "$JSONC_PROJECT/opencode.json" "$TMP/jsonc-project.before" && echo unchanged || echo changed)"
if "$OPK" mode power --normalize-jsonc >/dev/null 2>&1; then
  check "CLI mode accepts explicit JSONC normalization" "zero" "zero"
else
  check "CLI mode accepts explicit JSONC normalization" "zero" "nonzero"
fi
popd >/dev/null

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "test-opk-mode: FAILED ($FAIL failures)"
  exit 1
fi
echo "test-opk-mode: OK ($PASS checks passed)"
