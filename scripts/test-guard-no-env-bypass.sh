#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-guard-no-env-bypass.sh
# opencode-power-kit v2.2.0
#
# Regression test: OPK_GUARD_STRICT and any other env var must NOT
# be able to turn a block verdict into an allow. The guard must be
# fail-closed — destructive commands are always blocked regardless
# of environment state.
#
# Usage: bash scripts/test-guard-no-env-bypass.sh
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

. "$HERE/opk-command-guard.sh"

PASS=0
FAIL=0

ok() { echo "  ok   $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }

# --- Helper: simulate the DEBUG-trap glue from opk-guard-bashrc ---
# After the fix, NO env var should allow a dangerous command through.
_simulate_debug_trap() {
  local cmd="$1"
  local env_strict="${OPK_GUARD_STRICT:-}"
  local rc=0
  OPK_GUARD_SILENT=1 opk_guard_scan "$cmd" || rc=1
  # The production glue now ALWAYS blocks when rc=1.
  # It does NOT inspect OPK_GUARD_STRICT anymore.
  return $rc
}

echo "[guard-no-env-bypass]"

# --- Test matrix: every dangerous command + every env value ----------
DANGEROUS_CMDS=(
  "git reset --hard HEAD"
  "git clean -df"
  "rm --recursive --force target"
  "git push --force origin main"
)

# Values that an attacker might set to try to bypass the guard
BYPASS_VALUES=(
  ""
  "block"
  "warn"
  "allow"
  "off"
  "0"
  "false"
  "disabled"
  "random-value"
  "YES"
  "true"
)

echo
echo "  Dangerous commands must ALWAYS block, regardless of OPK_GUARD_STRICT:"

for cmd in "${DANGEROUS_CMDS[@]}"; do
  for val in "${BYPASS_VALUES[@]}"; do
    # Set the env var (or unset if empty)
    if [[ -z "$val" ]]; then
      unset OPK_GUARD_STRICT
      label="unset"
    else
      OPK_GUARD_STRICT="$val"
      label="$val"
    fi
    if _simulate_debug_trap "$cmd"; then
      fail "cmd=[$cmd] OPK_GUARD_STRICT=$label -> ALLOWED (should block)"
    else
      ok "cmd=[$cmd] OPK_GUARD_STRICT=$label -> blocked"
    fi
  done
done

# --- Sentinel test: actual destructive command in a sandbox ---------
echo
echo "  Sentinel test: OPK_GUARD_STRICT=warn must not mutate a file:"

TMP_ROOT="$(mktemp -d)"
TEST_REPO="$TMP_ROOT/repo"

git init -q "$TEST_REPO"
git -C "$TEST_REPO" config user.name test
git -C "$TEST_REPO" config user.email test@example.invalid

printf 'original-content\n' > "$TEST_REPO/file.txt"
git -C "$TEST_REPO" add file.txt
git -C "$TEST_REPO" commit -qm initial

printf 'user-dirty-change\n' > "$TEST_REPO/file.txt"
SENTINEL_BEFORE="$(cat "$TEST_REPO/file.txt")"

# Run a shell with the guard loaded via BASH_ENV and OPK_GUARD_STRICT=warn.
# The shell attempts git reset --hard — it must NOT actually reset.
GUARD_PATH="$ROOT/templates/guard/opk-guard-bashrc"
OUTPUT="$(
  cd "$TEST_REPO"
  OPK_GUARD_STRICT=warn BASH_ENV="$GUARD_PATH" bash -c 'git reset --hard HEAD' 2>&1
)"
SENTINEL_AFTER="$(cat "$TEST_REPO/file.txt")"

if [[ "$SENTINEL_BEFORE" == "$SENTINEL_AFTER" ]]; then
  ok "dirty file preserved with OPK_GUARD_STRICT=warn (blocked)"
else
  fail "DIRTY FILE CHANGED with OPK_GUARD_STRICT=warn — bypass succeeded!"
  echo "    before: $SENTINEL_BEFORE"
    echo "    after:  $SENTINEL_AFTER"
fi

# Also check the output mentions BLOCKED
if echo "$OUTPUT" | grep -q "BLOCKED"; then
  ok "guard emitted BLOCKED message"
else
  fail "guard did NOT emit BLOCKED message"
fi

# --- Benign commands must still work --------------------------------
echo
echo "  Benign commands must still run:"

# git status should not be blocked
if OPK_GUARD_SILENT=1 opk_guard_scan "git status --short"; then
  ok "git status --short -> allowed"
else
  fail "git status --short -> blocked (false positive)"
fi

# git diff should not be blocked
if OPK_GUARD_SILENT=1 opk_guard_scan "git diff"; then
  ok "git diff -> allowed"
else
  fail "git diff -> blocked (false positive)"
fi

# git clean -n (dry-run) should not be blocked
if OPK_GUARD_SILENT=1 opk_guard_scan "git clean -n"; then
  ok "git clean -n -> allowed"
else
  fail "git clean -n -> blocked (false positive)"
fi

# printf safe should not be blocked
if OPK_GUARD_SILENT=1 opk_guard_scan "printf 'safe\n'"; then
  ok "printf 'safe' -> allowed"
else
  fail "printf 'safe' -> blocked (false positive)"
fi

# --- No WARN-AND-RAN string in output -------------------------------
echo
echo "  No warn-to-allow behavior anywhere:"

if grep -q "WARN-AND-RAN" "$ROOT/scripts/sync-guard-bashrc.sh" \
   "$ROOT/scripts/guard-rules.sh" "$ROOT/templates/guard/opk-guard-bashrc" 2>/dev/null; then
  fail "WARN-AND-RAN string still present in guard files"
else
  ok "no WARN-AND-RAN string in guard files"
fi

# --- OPK_GUARD_STRICT must not appear in the DEBUG-trap glue --------
if grep -q 'OPK_GUARD_STRICT' "$ROOT/templates/guard/opk-guard-bashrc" 2>/dev/null; then
  fail "OPK_GUARD_STRICT still referenced in opk-guard-bashrc (bypass risk)"
else
  ok "OPK_GUARD_STRICT not referenced in opk-guard-bashrc DEBUG-trap glue"
fi

# Cleanup
rm -rf "$TMP_ROOT"

# --- Summary ----------------------------------------------------------
echo
echo "=== guard-no-env-bypass summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
