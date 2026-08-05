#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-install-tx.sh
# opencode-power-kit
#
# Integration test: luồng ghi file của install.sh qua transaction layer.
# Không chạy BMAD/npx — chạy ĐÚNG chuỗi opk_tx.sh mà install.sh gọi:
#   MERGE_MARKER .gitignore + CREATE knip.json/lefthook.yml (một tx)
#   REPLACE opencode-power-install-report.md (tx riêng)
# Kiểm tra: nội dung user giữ nguyên, marker idempotent, report ghi đè,
# lỗi cú pháp install.sh, và khôi phục tx dở dang khi chạy lại.
# Exit 0 = all pass, 1 = any fail.
# ─────────────────────────────────────────────────────────────────
set -uo pipefail

SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TX="$SCRIPT_DIR/opk_tx.sh"
INSTALL="$KIT_DIR/install.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/opk-install-tx.XXXXXX")"
PROJ="$TMP/proj"
mkdir -p "$PROJ"
trap 'rm -rf "$TMP"' EXIT

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

echo "== install.sh syntax =="
check "bash -n install.sh" "$(bash -n "$INSTALL"; echo $?)"
check "opk_tx.sh executable" "$( [ -x "$TX" ]; echo $?)"

echo "== user content preserved + marker merge (install.sh tx flow) =="
cat > "$PROJ/.gitignore" <<'EOF'
# user entries
secret.env
node_modules/
EOF
echo "user-notes" > "$PROJ/AGENTS.md"

TX_ID=$($TX begin --root "$PROJ" --reason "test install flow" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage MERGE_MARKER .gitignore" 0 $TX stage --txid "$TX_ID" --root "$PROJ" \
  --kind MERGE_MARKER --rel .gitignore --marker gitignore-extra \
  --text "$(cat "$KIT_DIR/templates/gitignore-extra.txt")"
expect_rc "stage CREATE knip.json" 0 $TX stage --txid "$TX_ID" --root "$PROJ" \
  --kind CREATE --rel knip.json --file "$KIT_DIR/templates/knip.json" --require-absent
expect_rc "stage CREATE lefthook.yml" 0 $TX stage --txid "$TX_ID" --root "$PROJ" \
  --kind CREATE --rel lefthook.yml --file "$KIT_DIR/templates/lefthook.yml" --require-absent
expect_rc "commit tx1" 0 $TX commit --txid "$TX_ID" --root "$PROJ"
check "user .gitignore lines kept" "$( grep -q "secret.env" "$PROJ/.gitignore"; echo $?)"
check "user AGENTS.md untouched" "$( [ "$(cat "$PROJ/AGENTS.md")" = "user-notes" ]; echo $?)"
check "knip.json created" "$( [ -f "$PROJ/knip.json" ]; echo $?)"
check "lefthook.yml created" "$( [ -f "$PROJ/lefthook.yml" ]; echo $?)"
check "marker present in .gitignore" "$( grep -q "OPK-MARKER: gitignore-extra-begin" "$PROJ/.gitignore"; echo $?)"

echo "== idempotent re-run (install.sh chạy lần 2) =="
N_BLOCKS_BEFORE=$(grep -c "OPK-MARKER: gitignore-extra-begin" "$PROJ/.gitignore")
TX2=$($TX begin --root "$PROJ" --reason "re-run" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage MERGE_MARKER re-run" 0 $TX stage --txid "$TX2" --root "$PROJ" \
  --kind MERGE_MARKER --rel .gitignore --marker gitignore-extra \
  --text "$(cat "$KIT_DIR/templates/gitignore-extra.txt")"
expect_rc "commit tx2" 0 $TX commit --txid "$TX2" --root "$PROJ"
N_BLOCKS_AFTER=$(grep -c "OPK-MARKER: gitignore-extra-begin" "$PROJ/.gitignore")
check "no duplicate marker on re-run" "$([ "$N_BLOCKS_AFTER" -eq "$N_BLOCKS_BEFORE" ]; echo $?)"

echo "== report REPLACE (tx riêng, ghi đè) =="
echo "old report" > "$PROJ/opencode-power-install-report.md"
REPORT_TMP="$(mktemp "${TMPDIR:-/tmp}/opk-report.XXXXXX")"
cat > "$REPORT_TMP" <<'EOF'
# OpenCode Power Kit - Install Report
- **Thời gian:** (test)
EOF
TX3=$($TX begin --root "$PROJ" --reason "report" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage REPLACE report" 0 $TX stage --txid "$TX3" --root "$PROJ" \
  --kind REPLACE --rel opencode-power-install-report.md --file "$REPORT_TMP"
rm -f "$REPORT_TMP"
expect_rc "commit tx3" 0 $TX commit --txid "$TX3" --root "$PROJ"
check "report overwritten" "$( grep -q "Install Report" "$PROJ/opencode-power-install-report.md"; echo $?)"

echo "== crash -> next-run recovery (auto khôi phục như install.sh) =="
echo "precious" > "$PROJ/keep.txt"
TX4=$($TX begin --root "$PROJ" --reason "crash" | python3 -c 'import json,sys;print(json.load(sys.stdin)["tx_id"])')
expect_rc "stage before crash" 0 $TX stage --txid "$TX4" --root "$PROJ" \
  --kind REPLACE --rel keep.txt --text "CLOBBERED"
python3 - "$PROJ/.opk-state/transactions/$TX4/manifest.json" <<'PY'
import json, sys
p = sys.argv[1]
m = json.load(open(p))
m["status"] = "applying"
json.dump(m, open(p, "w"))
PY
PENDING=$($TX status --root "$PROJ" | python3 -c '
import json, sys
txs = json.load(sys.stdin)
print(sum(1 for t in txs if t.get("status") in ("prepared", "applying", "failed")))')
check "pending tx detected" "$([ "$PENDING" -ge 1 ]; echo $?)"
expect_rc "recover --all --yes" 0 $TX recover --root "$PROJ" --all --yes
check "keep.txt restored" "$( [ "$(cat "$PROJ/keep.txt")" = "precious" ]; echo $?)"

echo ""
echo "============================="
echo "  install-tx: $PASSED/$TOTAL passed"
[ "$FAILED" -eq 0 ] || echo "  FAILED: $FAILED"
echo "============================="
[ "$FAILED" -eq 0 ]
