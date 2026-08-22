#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-command-guard.sh
# Kit version comes from ./VERSION; this test has no independent version.
#
# Parity test for the shared Bash guard engine. Reads the shared
# verdict corpus (templates/guard/guard-corpus.json) and asserts
# opk_guard_check (from the wrapper opk-command-guard.sh, which
# sources scripts/guard-rules.sh) returns the expected verdict for
# every case. Exit code 0 = full parity.
# ─────────────────────────────────────────────────────────────────

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

. "$HERE/opk-command-guard.sh"

CORPUS="$ROOT/templates/guard/guard-corpus.json"
[[ -f "$CORPUS" ]] || { echo "FATAL: missing corpus $CORPUS" >&2; exit 2; }

# Cases are emitted as `verdict<TAB>base64(cmd)` per line so multi-line
# commands survive the read loop. Keeps this script free of literal
# dangerous command strings (readable by humans and scanners).
TMP_LIST=$(mktemp)
python3 - "$CORPUS" "$TMP_LIST" <<'PYEOF'
import base64, json, sys
corpus = json.load(open(sys.argv[1]))
out = open(sys.argv[2], "w")
for c in corpus["cases"]:
    out.write(f"{c['verdict']}\t{base64.b64encode(c['cmd'].encode('utf-8')).decode()}\n")
PYEOF

pass=0; fail=0
while IFS= read -r line; do
    want="${line%%$'\t'*}"
    cmd="$(printf '%s' "${line#*$'\t'}" | base64 -d)"
    opk_guard_check "$cmd"
    got=$?
    if [[ $want == "block" && $got -eq 1 ]] || [[ $want == "allow" && $got -eq 0 ]]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "MISMATCH expect=$want got=$( [[ $got -eq 0 ]] && echo allow || echo block ) cmd=[$cmd]" >&2
    fi
done < "$TMP_LIST"
rm -f "$TMP_LIST"

echo "command-guard corpus parity: $pass passed, $fail failed"
if [[ $fail -ne 0 ]]; then exit 1; fi

# ─── Fragment freshness: templates/guard/opk-guard-bashrc must equal
#     what sync-guard-bashrc.sh would generate (read-only via --stdout).
FRAG="$ROOT/templates/guard/opk-guard-bashrc"
if diff -q <("$HERE/sync-guard-bashrc.sh" --stdout 2>/dev/null) "$FRAG" >/dev/null 2>&1; then
    echo "command-guard fragment freshness: in sync ($FRAG)"
else
    echo "command-guard fragment freshness: STALE — run scripts/sync-guard-bashrc.sh" >&2
    exit 1
fi
exit 0
