#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-tx.sh
# opencode-power-kit
#
# Test suite cho opk_tx.py — transaction/journal/rollback layer.
# Coverage:
#   - happy path: begin/stage/commit
#   - rollback restores replaced files and removes created files
#   - MERGE_MARKER idempotency (re-run produces no duplication)
#   - failure injection (OPK_TEST_MODE=1 + OPK_TEST_FAIL_AFTER)
#     -> pre-state hash preserved, out-of-root sentinel untouched,
#        transaction marked rolled_back, re-run idempotent
#   - production refuses failure-injection env
#   - crash recovery (status prepared/applying) via recover --yes
#   - recover refuses without --yes; lock prevents concurrent tx
# Exit 0 = all pass, 1 = any fail.
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TX="python3 $SCRIPT_DIR/opk_tx.py"
SAFE="python3 $SCRIPT_DIR/opk_safe_io.py"

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/opk-tx.XXXXXX")"
PROJ="$TMP_ROOT/proj"
SENTINEL="$TMP_ROOT/sentinel.txt"
mkdir -p "$PROJ"
echo "sentinel-untouched" > "$SENTINEL"

TOTAL=0
PASSED=0
FAILED=0

check() {
  local name="$1" cond="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$cond" -eq 0 ]; then
    PASSED=$((PASSED + 1)); printf "  [ok]   %s\n" "$name"
  else
    FAILED=$((FAILED + 1)); printf "  [FAIL] %s\n" "$name"
  fi
}

expect_rc() {
  local name="$1" want="$2"
  shift 2
  "$@" >/dev/null 2>&1
  local got=$?
  check "$name (rc $got, want $want)" "$([ "$got" -eq "$want" ]; echo $?)"
}

h() { $SAFE hash --root "$PROJ" --rel "$1" | python3 -c 'import json,sys;print(json.load(sys.stdin)["sha256"])'; }

echo "== happy path =="
T1=$($TX begin --root "$PROJ" --reason test | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage CREATE" 0 $TX stage --txid "$T1" --root "$PROJ" --kind CREATE --rel .gitignore --text "node_modules/"
expect_rc "stage REPLACE" 0 $TX stage --txid "$T1" --root "$PROJ" --kind REPLACE --rel settings.txt --text "a=1"
expect_rc "stage MKDIR" 0 $TX stage --txid "$T1" --root "$PROJ" --kind MKDIR --rel .opk-dir
expect_rc "commit" 0 $TX commit --txid "$T1" --root "$PROJ"
check "file written by tx" "$( [ "$($SAFE read --root "$PROJ" --rel .gitignore)" = "node_modules/" ]; echo $?)"
ST=$($TX status --root "$PROJ" --txid "$T1" | python3 -c 'import json,sys;print(json.load(sys.stdin)["status"])')
check "status committed" "$([ "$ST" = "committed" ]; echo $?)"
expect_rc "commit twice is no-op" 0 $TX commit --txid "$T1" --root "$PROJ"

echo "== rollback =="
echo "precious" > "$PROJ/victim.txt"
PRE_HASH=$(h victim.txt)
T2=$($TX begin --root "$PROJ" --reason rb | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage REPLACE victim" 0 $TX stage --txid "$T2" --root "$PROJ" --kind REPLACE --rel victim.txt --text "CLOBBERED"
expect_rc "stage CREATE new" 0 $TX stage --txid "$T2" --root "$PROJ" --kind CREATE --rel new.txt --text "new"
expect_rc "rollback" 0 $TX rollback --txid "$T2" --root "$PROJ"
check "victim restored" "$( [ "$(cat "$PROJ/victim.txt")" = "precious" ]; echo $?)"
check "new.txt removed" "$( [ ! -f "$PROJ/new.txt" ]; echo $?)"
expect_rc "rollback idempotent" 0 $TX rollback --txid "$T2" --root "$PROJ"
expect_rc "commit after rollback refused" 1 $TX commit --txid "$T2" --root "$PROJ"

echo "== merge marker idempotency =="
T3=$($TX begin --root "$PROJ" --reason mm | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage MERGE_MARKER first" 0 $TX stage --txid "$T3" --root "$PROJ" --kind MERGE_MARKER --rel AGENTS.md --marker rules --text "RULE-1"
expect_rc "commit mm" 0 $TX commit --txid "$T3" --root "$PROJ"
T4=$($TX begin --root "$PROJ" --reason mm2 | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage MERGE_MARKER re-run" 0 $TX stage --txid "$T4" --root "$PROJ" --kind MERGE_MARKER --rel AGENTS.md --marker rules --text "RULE-1"
expect_rc "commit mm2" 0 $TX commit --txid "$T4" --root "$PROJ"
N_RULES=$(grep -c "RULE-1" "$PROJ/AGENTS.md")
check "no marker duplication" "$([ "$N_RULES" -eq 1 ]; echo $?)"

echo "== failure injection (test mode) =="
echo "original" > "$PROJ/keep.txt"
KEEP_HASH=$(h keep.txt)
expect_rc "production refuses fail-after env" 1 env OPK_TEST_FAIL_AFTER=CREATE python3 $SCRIPT_DIR/opk_tx.py begin --root "$PROJ" --reason x
T5=$($TX begin --root "$PROJ" --reason inj | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage A" 0 $TX stage --txid "$T5" --root "$PROJ" --kind REPLACE --rel keep.txt --text "MODIFIED"
expect_rc "stage B (inject fail)" 1 env OPK_TEST_MODE=1 OPK_TEST_FAIL_AFTER=MKDIR $TX stage --txid "$T5" --root "$PROJ" --kind MKDIR --rel .injected-dir
check "pre-state restored after injected failure" "$( [ "$(h keep.txt)" = "$KEEP_HASH" ]; echo $?)"
check "sentinel outside root untouched" "$( [ "$(cat "$SENTINEL")" = "sentinel-untouched" ]; echo $?)"
ST5=$($TX status --root "$PROJ" --txid "$T5" | python3 -c 'import json,sys;print(json.load(sys.stdin)["status"])')
check "failed tx marked rolled_back" "$([ "$ST5" = "rolled_back" ]; echo $?)"
expect_rc "re-run stage on new tx works" 0 $TX stage --txid "$( $TX begin --root "$PROJ" --reason rerun | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])' )" --root "$PROJ" --kind MKDIR --rel .rerun-dir

echo "== crash recovery =="
T6=$($TX begin --root "$PROJ" --reason crash | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage before crash" 0 $TX stage --txid "$T6" --root "$PROJ" --kind CREATE --rel crash-file.txt --text "boom"
python3 - "$PROJ/.opk-state/transactions/$T6/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
m["status"] = "applying"
json.dump(m, open(p, "w"))
PY
expect_rc "recover refuses without --yes" 1 $TX recover --root "$PROJ" --txid "$T6"
expect_rc "recover --txid --yes" 0 $TX recover --root "$PROJ" --txid "$T6" --yes
check "crash file removed by recovery" "$( [ ! -f "$PROJ/crash-file.txt" ]; echo $?)"
ST6=$($TX status --root "$PROJ" --txid "$T6" | python3 -c 'import json,sys;print(json.load(sys.stdin)["status"])')
check "recovered tx rolled_back" "$([ "$ST6" = "rolled_back" ]; echo $?)"
expect_rc "recover again is no-op" 0 $TX recover --root "$PROJ" --txid "$T6" --yes

echo "== locking =="
python3 - "$PROJ" <<'PY' &
import fcntl, os, sys, time
proj = sys.argv[1]
os.makedirs(os.path.join(proj, ".opk-state"), exist_ok=True)
fd = os.open(os.path.join(proj, ".opk-state", ".tx-lock"), os.O_RDWR | os.O_CREAT, 0o600)
fcntl.flock(fd, fcntl.LOCK_EX)
time.sleep(3)
PY
LOCKER_PID=$!
sleep 0.4
expect_rc "lock held prevents concurrent begin" 1 $TX begin --root "$PROJ" --reason concurrent
expect_rc "lock held prevents concurrent stage" 1 $TX stage --txid "$T6" --root "$PROJ" --kind MKDIR --rel .x-dir
wait "$LOCKER_PID" 2>/dev/null
expect_rc "begin works after lock released" 0 $TX begin --root "$PROJ" --reason after
check "lock file exists" "$( [ -f "$PROJ/.opk-state/.tx-lock" ]; echo $?)"

echo ""
echo "============================="
echo "  tx: $PASSED/$TOTAL passed"
[ "$FAILED" -eq 0 ] || echo "  FAILED: $FAILED"
echo "============================="
[ "$FAILED" -eq 0 ]
