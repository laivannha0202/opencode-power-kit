#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-safe-io.sh
# opencode-power-kit
#
# Test suite cho opk_safe_io.py — TOCTOU-safe filesystem primitives.
# Coverage:
#   - write/read/verify/hash/backup/restore/remove roundtrips
#   - symlink attack matrix (final, parent, dangling, loop)
#   - escape attempts (.., absolute, empty component)
#   - hardlink alias refusal
#   - atomicity (no temp leftovers) + mode preservation
#   - create_parents
# Exit 0 = all pass, 1 = any fail.
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SAFE_IO="python3 $SCRIPT_DIR/opk_safe_io.py"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/opk-safe-io.XXXXXX")"
trap 'true' EXIT

TOTAL=0
PASSED=0
FAILED=0

check() {
  local name="$1"
  local cond="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$cond" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    printf "  [ok]   %s\n" "$name"
  else
    FAILED=$((FAILED + 1))
    printf "  [FAIL] %s\n" "$name"
  fi
}

expect_exit() {
  local name="$1" want="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  check "$name (exit $want)" "$([ "$got" -eq "$want" ]; echo $?)"
}

PROJ="$TMP_ROOT/proj"
BK="$TMP_ROOT/backups"
mkdir -p "$PROJ" "$BK"

echo "== opk_safe_io roundtrip =="
expect_exit "write new file" 0 $SAFE_IO write --root "$PROJ" --rel .gitignore --text "node_modules/"
expect_exit "verify exists" 0 $SAFE_IO verify --root "$PROJ" --rel .gitignore
expect_exit "verify missing -> 3" 3 $SAFE_IO verify --root "$PROJ" --rel nope.txt
CONTENT=$($SAFE_IO read --root "$PROJ" --rel .gitignore)
check "read content roundtrip" "$([ "$CONTENT" = "node_modules/" ]; echo $?)"
HASH1=$($SAFE_IO hash --root "$PROJ" --rel .gitignore | python3 -c 'import json,sys;print(json.load(sys.stdin)["sha256"])')
check "hash is 64 hex chars" "$([ "${#HASH1}" -eq 64 ]; echo $?)"
MODE1=$($SAFE_IO check --root "$PROJ" --rel .gitignore | python3 -c 'import json,sys;print(json.load(sys.stdin)["mode"])')
expect_exit "overwrite existing" 0 $SAFE_IO write --root "$PROJ" --rel .gitignore --text "dist/"
MODE2=$($SAFE_IO check --root "$PROJ" --rel .gitignore | python3 -c 'import json,sys;print(json.load(sys.stdin)["mode"])')
check "mode preserved across overwrite" "$([ "$MODE1" = "$MODE2" ]; echo $?)"
expect_exit "backup file" 0 $SAFE_IO backup --root "$PROJ" --rel .gitignore --backup-root "$BK" --backup-rel b1
expect_exit "restore from backup" 0 $SAFE_IO restore --root "$PROJ" --rel .gitignore --backup-root "$BK" --backup-rel b1
CONTENT2=$($SAFE_IO read --root "$PROJ" --rel .gitignore)
check "restore restores content" "$([ "$CONTENT2" = "dist/" ]; echo $?)"
expect_exit "remove file" 0 $SAFE_IO remove --root "$PROJ" --rel .gitignore
expect_exit "verify after remove -> 3" 3 $SAFE_IO verify --root "$PROJ" --rel .gitignore
expect_exit "remove missing -> 3" 3 $SAFE_IO remove --root "$PROJ" --rel .gitignore

echo "== symlink attack matrix =="
ln -s /etc/passwd "$PROJ/sym-final"
expect_exit "remove symlink refused -> 2" 2 $SAFE_IO remove --root "$PROJ" --rel sym-final
expect_exit "write through final symlink -> 2" 2 $SAFE_IO write --root "$PROJ" --rel sym-final --text "x"
expect_exit "write through final symlink (require-absent) -> 2" 2 $SAFE_IO write --root "$PROJ" --rel sym-final --text "x" --require-absent
ln -s /etc "$PROJ/sym-parent"
expect_exit "write through parent symlink -> 2" 2 $SAFE_IO write --root "$PROJ" --rel sym-parent/owned --text "x"
ln -s /nonexistent-target "$PROJ/dangling"
expect_exit "write through dangling symlink -> 2" 2 $SAFE_IO write --root "$PROJ" --rel dangling --text "x"
expect_exit "read through dangling symlink -> 2" 2 $SAFE_IO read --root "$PROJ" --rel dangling
ln -s loop-a "$PROJ/loop-a"
ln -s loop-b "$PROJ/loop-b"
expect_exit "write through symlink loop -> 2" 2 $SAFE_IO write --root "$PROJ" --rel loop-a/x --text "x"
expect_exit "check of symlink reports symlink" 0 $SAFE_IO check --root "$PROJ" --rel sym-final

echo "== escape attempts =="
expect_exit ".. component -> 2" 2 $SAFE_IO write --root "$PROJ" --rel ../escape --text "x"
expect_exit ".. hidden in middle -> 2" 2 $SAFE_IO write --root "$PROJ" --rel sub/../escape --text "x"
expect_exit "absolute path -> 2" 2 $SAFE_IO write --root "$PROJ" --rel /abs --text "x"
expect_exit "empty component -> 2" 2 $SAFE_IO write --root "$PROJ" --rel "a//b" --text "x"
expect_exit "trailing dot -> 2" 2 $SAFE_IO write --root "$PROJ" --rel "a/./b" --text "x"
python3 - "$SCRIPT_DIR" <<'PY'
import sys, importlib.util, os
spec = importlib.util.spec_from_file_location(
    "opk_safe_io", os.path.join(sys.argv[1], "opk_safe_io.py"))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
try:
    m.split_rel("a\x00b")
    sys.exit(1)
except m.UnsafePathError:
    sys.exit(0)
PY
check "nul byte refused (module level)" $?

echo "== hardlink alias =="
echo "precious" > "$PROJ/orig"
ln "$PROJ/orig" "$PROJ/orig-alias"
expect_exit "overwrite hardlink alias -> 2" 2 $SAFE_IO write --root "$PROJ" --rel orig --text "clobber"
check "alias target untouched" "$( [ "$(cat "$PROJ/orig")" = "precious" ]; echo $?)"

echo "== atomicity / leftovers =="
expect_exit "write deep path with create-parents" 0 $SAFE_IO write --root "$PROJ" --rel a/b/c/d.txt --text "deep" --create-parents
expect_exit "verify deep file" 0 $SAFE_IO verify --root "$PROJ" --rel a/b/c/d.txt
TEMPS=$(find "$PROJ" -name '.opk-tmp-*' | wc -l)
check "no temp leftovers" "$([ "$TEMPS" -eq 0 ]; echo $?)"
expect_exit "mkdir nested create-parents" 0 $SAFE_IO mkdir --root "$PROJ" --rel x/y/z --create-parents
expect_exit "mkdir existing dir is ok" 0 $SAFE_IO mkdir --root "$PROJ" --rel x/y/z
expect_exit "rmdir non-empty refused -> 1" 1 $SAFE_IO rmdir --root "$PROJ" --rel x
expect_exit "rmdir empty dir" 0 $SAFE_IO rmdir --root "$PROJ" --rel x/y/z

echo "== require-absent / no-clobber =="
printf "existing\n" > "$PROJ/exists.txt"
expect_exit "require-absent on existing file -> 1" 1 $SAFE_IO write --root "$PROJ" --rel exists.txt --text "x" --require-absent
expect_exit "require-absent on new" 0 $SAFE_IO write --root "$PROJ" --rel fresh.txt --text "x" --require-absent
expect_exit "no-clobber on existing -> 1" 1 $SAFE_IO write --root "$PROJ" --rel fresh.txt --text "y" --no-clobber

echo ""
echo "============================="
echo "  safe-io: $PASSED/$TOTAL passed"
[ "$FAILED" -eq 0 ] || echo "  FAILED: $FAILED"
echo "============================="
[ "$FAILED" -eq 0 ]
