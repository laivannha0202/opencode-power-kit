#!/usr/bin/env bash
# ============================================================================
# test-opk-mode.sh
#
# Regression test cho mode detection (POWER / SAFE / CUSTOM).
# Tạo project tạm trong thư mục temp an toàn (KHÔNG ghi vào HOME thật).
# Chạy scripts/detect-mode.py trên từng config và xác minh output.
# ============================================================================
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
        rm -rf -- "$created"
        continue
      fi
      case "$root" in
        "$candidate"/.opk-mode-test.*) ;;
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
      [[ -d "$tmp_real" && "$tmp_real" != "/" ]] && rm -rf -- "$tmp_real"
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
PROJECT_CONFIG="$TEST_PROJECT/.opencode/opencode.json"
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

# 5) Custom with top-level string allow -> POWER
cat > "$TMP/custom2.json" <<'EOF'
{
  "permission": "allow"
}
EOF
check "custom (string allow)" "POWER" "$(python3 "$DETECT" "$TMP/custom2.json")"

# 6) JSONC comment tolerance
cat > "$TMP/jsonc.json" <<'EOF'
{
  // this is a comment
  "permission": {
    "*": "ask",
    "bash": { "*": "ask" },
    "write": "ask",
    "edit": "ask",
    "task": "ask"
  }
}
EOF
check "jsonc safe" "SAFE" "$(python3 "$DETECT" "$TMP/jsonc.json")"

# 7) Real CLI integration: mode is always project-local and ignores OPENCODE_CONFIG_DIR.
cp "$KIT_DIR/templates/opencode.power.json" "$PROJECT_CONFIG"
cp "$KIT_DIR/templates/opencode.power.json" "$TMP/power-template.before"
cp "$KIT_DIR/templates/opencode.safe.json" "$TMP/safe-template.before"
printf 'global config sentinel\n' >"$OPENCODE_CONFIG_DIR/opencode.json"

pushd "$TEST_PROJECT" >/dev/null
check "CLI mode show (initial)" "POWER" "$("$OPK" mode show)"
if "$OPK" mode safe; then
  check "CLI mode safe target" "SAFE" "$(python3 "$DETECT" "$PROJECT_CONFIG")"
else
  check "CLI mode safe command" "exit 0" "nonzero"
fi
shopt -s nullglob
mode_backups=("$PROJECT_CONFIG".bak.*)
shopt -u nullglob
power_backup=false
for backup in "${mode_backups[@]}"; do
  cmp -s "$backup" "$KIT_DIR/templates/opencode.power.json" && power_backup=true
done
check "CLI mode safe backup" "true" "$power_backup"
check "CLI mode show (safe)" "SAFE" "$("$OPK" mode show)"

if "$OPK" mode power; then
  check "CLI mode power target" "POWER" "$(python3 "$DETECT" "$PROJECT_CONFIG")"
else
  check "CLI mode power command" "exit 0" "nonzero"
fi
shopt -s nullglob
mode_backups=("$PROJECT_CONFIG".bak.*)
shopt -u nullglob
safe_backup=false
for backup in "${mode_backups[@]}"; do
  cmp -s "$backup" "$KIT_DIR/templates/opencode.safe.json" && safe_backup=true
done
check "CLI mode power backup" "true" "$safe_backup"
check "CLI mode show (power)" "POWER" "$("$OPK" mode show)"
popd >/dev/null

if [[ "$(cat "$OPENCODE_CONFIG_DIR/opencode.json")" == "global config sentinel" ]]; then
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

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "test-opk-mode: FAILED ($FAIL failures)"
  exit 1
fi
echo "test-opk-mode: OK ($PASS checks passed)"
