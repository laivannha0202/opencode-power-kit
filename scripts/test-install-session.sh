#!/usr/bin/env bash
# Install-session lifecycle regression tests.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MERGE="$KIT_DIR/scripts/merge-opk-project.py"
TX="$KIT_DIR/scripts/opk_tx.py"
SESSION="$KIT_DIR/scripts/opk_install_session.py"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/opk-install-session.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  if "$@"; then
    PASS=$((PASS + 1))
    printf '  [ok]   %s\n' "$name"
  else
    FAIL=$((FAIL + 1))
    printf '  [FAIL] %s\n' "$name" >&2
  fi
}

tx_begin() {
  python3 "$TX" begin --root "$1" --reason "$2" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["tx_id"])'
}

printf 'install-session lifecycle\n'

P="$TMP/project"
mkdir -p "$P/.opencode"
printf 'USER AGENTS ORIGINAL\n' >"$P/AGENTS.md"
printf 'USER OPENCODE ORIGINAL\n' >"$P/OPENCODE.md"
printf '{"model":"fixture/original","mcp":{"keep":true}}\n' >"$P/opencode.json"
printf 'user-ignore\n' >"$P/.gitignore"

cp "$P/AGENTS.md" "$TMP/agents.orig"
cp "$P/OPENCODE.md" "$TMP/opencode-md.orig"
cp "$P/opencode.json" "$TMP/config.orig"
cp "$P/.gitignore" "$TMP/gitignore.orig"

MERGE_JSON="$(
  python3 "$MERGE" --project-dir "$P" --mode power --json
)"
WAL="$(
  printf '%s' "$MERGE_JSON" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["wal_archive"])'
)"
check "merger returns committed WAL archive" test -f "$P/$WAL/journal.wal"

TX1="$(tx_begin "$P" "session-test: files")"
python3 "$TX" stage --root "$P" --txid "$TX1" \
  --kind MERGE_MARKER --rel .gitignore --marker session-test \
  --text 'managed-ignore' >/dev/null
python3 "$TX" stage --root "$P" --txid "$TX1" \
  --kind CREATE --rel knip.json --text '{"managed":true}' >/dev/null
python3 "$TX" commit --root "$P" --txid "$TX1" >/dev/null

TXR="$(tx_begin "$P" "session-test: report")"
SESSION_JSON="$(
  python3 "$SESSION" create \
    --root "$P" \
    --merge-json "$MERGE_JSON" \
    --txid "$TX1" \
    --txid "$TXR" \
    --lease test-session
)"
SID="$(
  printf '%s' "$SESSION_JSON" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["session_id"])'
)"

python3 "$TX" stage --root "$P" --txid "$TXR" \
  --kind REPLACE --rel opencode-power-install-report.md \
  --text 'managed report' >/dev/null
python3 "$TX" commit --root "$P" --txid "$TXR" >/dev/null
python3 "$SESSION" finalize --root "$P" --session "$SID" >/dev/null

STATUS="$(
  python3 "$SESSION" show --root "$P" --session "$SID" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])'
)"
check "session finalized as installed" test "$STATUS" = installed

cp "$P/AGENTS.md" "$TMP/agents.post"
printf '\nUSER EDIT AFTER INSTALL\n' >>"$P/AGENTS.md"

RC=0
python3 "$SESSION" uninstall --root "$P" --session "$SID" --yes \
  >"$TMP/conflict.out" 2>"$TMP/conflict.err" || RC=$?
check "post-install user edit refuses uninstall" test "$RC" -ne 0
check "failed preflight leaves report untouched" \
  test -f "$P/opencode-power-install-report.md"
check "failed preflight leaves tx-created file untouched" \
  test -f "$P/knip.json"

cp "$TMP/agents.post" "$P/AGENTS.md"
python3 "$SESSION" uninstall --root "$P" --session "$SID" --yes >/dev/null

check "AGENTS restored byte-identical" cmp -s "$P/AGENTS.md" "$TMP/agents.orig"
check "OPENCODE restored byte-identical" cmp -s "$P/OPENCODE.md" "$TMP/opencode-md.orig"
check "root config restored byte-identical" cmp -s "$P/opencode.json" "$TMP/config.orig"
check ".gitignore restored byte-identical" cmp -s "$P/.gitignore" "$TMP/gitignore.orig"
check "tx-created knip removed" test ! -e "$P/knip.json"
check "install report removed" test ! -e "$P/opencode-power-install-report.md"
check "OPK safety runtime removed when absent before install" \
  test ! -e "$P/.opencode/plugins/opk-safety-guard.js"
check "OPK token runtime removed when absent before install" \
  test ! -e "$P/.opencode/plugins/opk-token-guard.js"

STATUS="$(
  python3 "$SESSION" show --root "$P" --session "$SID" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])'
)"
check "session marked uninstalled" test "$STATUS" = uninstalled
check "consumed WAL archive removed" test ! -e "$P/$WAL"

BACKUPS_LEFT="$(
  find "$P" -maxdepth 2 -type f -name '*.opk-bak.*' -print -quit
)"
check "session recovery copies cleaned after uninstall" test -z "$BACKUPS_LEFT"

printf '\nlegacy-config session restore\n'
P2="$TMP/legacy"
mkdir -p "$P2/.opencode"
printf '{"model":"legacy/original","plugin":["legacy-plugin"]}\n' \
  >"$P2/.opencode/opencode.json"
cp "$P2/.opencode/opencode.json" "$TMP/legacy.orig"

MERGE2="$(
  python3 "$MERGE" --project-dir "$P2" --mode power --json
)"
T2="$(tx_begin "$P2" "legacy-session")"
python3 "$TX" commit --root "$P2" --txid "$T2" >/dev/null
S2_JSON="$(
  python3 "$SESSION" create \
    --root "$P2" \
    --merge-json "$MERGE2" \
    --txid "$T2" \
    --lease legacy-test
)"
S2="$(
  printf '%s' "$S2_JSON" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["session_id"])'
)"
python3 "$SESSION" finalize --root "$P2" --session "$S2" >/dev/null
python3 "$SESSION" uninstall --root "$P2" --session "$S2" --yes >/dev/null

check "legacy original restored" \
  cmp -s "$P2/.opencode/opencode.json" "$TMP/legacy.orig"
check "merge-created root config removed for legacy project" \
  test ! -e "$P2/opencode.json"

printf '\nleased-transaction session uninstall\n'
P3="$TMP/leased"
mkdir -p "$P3"
T3_JSON="$(
  python3 "$TX" begin \
    --root "$P3" \
    --reason "leased-session" \
    --lease leased-test
)"
T3="$(
  printf '%s' "$T3_JSON" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["tx_id"])'
)"
python3 "$TX" stage \
  --root "$P3" \
  --txid "$T3" \
  --kind CREATE \
  --rel leased.txt \
  --text 'managed leased file' \
  --lease leased-test >/dev/null
python3 "$TX" commit \
  --root "$P3" \
  --txid "$T3" \
  --lease leased-test >/dev/null

S3_JSON="$(
  python3 "$SESSION" create \
    --root "$P3" \
    --txid "$T3" \
    --lease leased-test
)"
S3="$(
  printf '%s' "$S3_JSON" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["session_id"])'
)"
python3 "$SESSION" finalize \
  --root "$P3" \
  --session "$S3" >/dev/null

check "leased transaction target exists before uninstall" \
  test -f "$P3/leased.txt"

python3 "$SESSION" uninstall \
  --root "$P3" \
  --session "$S3" \
  --yes >/dev/null

check "session uninstall rolls back leased transaction" \
  test ! -e "$P3/leased.txt"

S3_STATUS="$(
  python3 "$SESSION" show \
    --root "$P3" \
    --session "$S3" |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])'
)"
check "leased session marked uninstalled" \
  test "$S3_STATUS" = uninstalled

printf '\ninstall-session: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
