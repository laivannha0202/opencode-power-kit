#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# test-guard-interactive.sh
# opencode-power-kit v2.2.0
#
# Regression test: interactive Bash shells must survive blocked
# commands.  The guard DEBUG trap must skip the dangerous command
# but NOT terminate the interactive shell.  Safe commands typed
# after a block must still execute.
#
# Usage: bash scripts/test-guard-interactive.sh
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

PASS=0
FAIL=0

ok() { echo "  ok   $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }

GUARD_PATH="$ROOT/templates/guard/opk-guard-bashrc"

echo "[guard-interactive]"

TMP_ROOT="$(mktemp -d)"
cleanup() {
  if [[ -d "$TMP_ROOT" && "$TMP_ROOT" == /tmp/* ]]; then
    find "$TMP_ROOT" -depth -delete 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ======================================================================
# SECTION 1: Interactive shell — blocked command does not kill shell
# ======================================================================
echo
echo "  === Interactive shell survival ==="

# Each test feeds a script of commands to an interactive Bash via stdin.
# The script sources the guard, attempts a dangerous command, then
# runs safe commands and explicit exit.

# --- Test: git reset --hard ---
TEST_DIR="$TMP_ROOT/test-reset-interactive"
mkdir -p "$TEST_DIR"
git init -q "$TEST_DIR"
git -C "$TEST_DIR" config user.name test
git -C "$TEST_DIR" config user.email test@example.invalid
printf 'original\n' > "$TEST_DIR/file.txt"
git -C "$TEST_DIR" add file.txt
git -C "$TEST_DIR" commit -qm initial
printf 'user-dirty-change\n' > "$TEST_DIR/file.txt"

SENTINEL_BEFORE="$(cat "$TEST_DIR/file.txt")"

SCRIPT_FILE="$TEST_DIR/interactive-script.sh"
cat > "$SCRIPT_FILE" <<INTERACTIVE
source "$GUARD_PATH"
git reset --hard HEAD
printf 'BLOCKED_RC=%s\n' "\$?"
printf 'SAFE_AFTER_BLOCK\n'
printf 'FILE_CONTENT=%s\n' "cat $TEST_DIR/file.txt"
INTERACTIVE

set +e
OUTPUT="$(cd "$TEST_DIR" && bash --noprofile --norc -i < "$SCRIPT_FILE" 2>&1)"
RC=$?
set -e

SENTINEL_AFTER="$(cat "$TEST_DIR/file.txt")"

# Assertions
has_blocked_stderr=0
if echo "$OUTPUT" | grep -q "opk-guard: BLOCKED"; then has_blocked_stderr=1; fi
has_after_block=0
if echo "$OUTPUT" | grep -q "BLOCKED_RC="; then has_after_block=1; fi
has_safe_after=0
if echo "$OUTPUT" | grep -q "SAFE_AFTER_BLOCK"; then has_safe_after=1; fi
preserved=0
if [[ "$SENTINEL_BEFORE" == "$SENTINEL_AFTER" ]]; then preserved=1; fi

if [[ $has_blocked_stderr -eq 1 && $has_after_block -eq 1 && $has_safe_after -eq 1 && $preserved -eq 1 ]]; then
  ok "interactive git reset --hard -> blocked, shell survived, safe cmd ran, file preserved"
else
  fail "interactive git reset --hard -> blocked=$has_blocked_stderr after_rc=$has_after_block safe=$has_safe_after preserved=$preserved"
  echo "    OUTPUT: $OUTPUT"
fi

# --- Test: git clean -df ---
TEST_DIR="$TMP_ROOT/test-clean-interactive"
mkdir -p "$TEST_DIR"
git init -q "$TEST_DIR"
git -C "$TEST_DIR" config user.name test
git -C "$TEST_DIR" config user.email test@example.invalid
printf 'tracked\n' > "$TEST_DIR/tracked.txt"
git -C "$TEST_DIR" add tracked.txt
git -C "$TEST_DIR" commit -qm initial
printf 'untracked-sentinel\n' > "$TEST_DIR/untracked.txt"

UNTRACKED_BEFORE="$(cat "$TEST_DIR/untracked.txt")"

SCRIPT_FILE="$TEST_DIR/interactive-script.sh"
cat > "$SCRIPT_FILE" <<INTERACTIVE
source "$GUARD_PATH"
git clean -df
printf 'BLOCKED_RC=%s\n' "\$?"
printf 'SAFE_AFTER_BLOCK\n'
printf 'UNTRACKED=%s\n' "cat $TEST_DIR/untracked.txt"
INTERACTIVE

set +e
OUTPUT="$(cd "$TEST_DIR" && bash --noprofile --norc -i < "$SCRIPT_FILE" 2>&1)"
RC=$?
set -e

UNTRACKED_AFTER="$(cat "$TEST_DIR/untracked.txt" 2>/dev/null || echo "DELETED")"

has_blocked_stderr=0
if echo "$OUTPUT" | grep -q "opk-guard: BLOCKED"; then has_blocked_stderr=1; fi
has_after_block=0
if echo "$OUTPUT" | grep -q "BLOCKED_RC="; then has_after_block=1; fi
has_safe_after=0
if echo "$OUTPUT" | grep -q "SAFE_AFTER_BLOCK"; then has_safe_after=1; fi
preserved=0
if [[ "$UNTRACKED_BEFORE" == "$UNTRACKED_AFTER" ]]; then preserved=1; fi

if [[ $has_blocked_stderr -eq 1 && $has_after_block -eq 1 && $has_safe_after -eq 1 && $preserved -eq 1 ]]; then
  ok "interactive git clean -df -> blocked, shell survived, safe cmd ran, untracked preserved"
else
  fail "interactive git clean -df -> blocked=$has_blocked_stderr after_rc=$has_after_block safe=$has_safe_after preserved=$preserved"
  echo "    OUTPUT: $OUTPUT"
fi

# --- Test: rm --recursive --force ---
TEST_DIR="$TMP_ROOT/test-rm-interactive"
mkdir -p "$TEST_DIR/target"
echo "SENTINEL" > "$TEST_DIR/target/sentinel.txt"

SENTINEL_BEFORE="$(cat "$TEST_DIR/target/sentinel.txt")"

SCRIPT_FILE="$TEST_DIR/interactive-script.sh"
cat > "$SCRIPT_FILE" <<INTERACTIVE
source "$GUARD_PATH"
rm --recursive --force target
printf 'BLOCKED_RC=%s\n' "\$?"
printf 'SAFE_AFTER_BLOCK\n'
printf 'SENTINEL=%s\n' "cat $TEST_DIR/target/sentinel.txt"
INTERACTIVE

set +e
OUTPUT="$(cd "$TEST_DIR" && bash --noprofile --norc -i < "$SCRIPT_FILE" 2>&1)"
RC=$?
set -e

SENTINEL_AFTER="$(cat "$TEST_DIR/target/sentinel.txt" 2>/dev/null || echo "DELETED")"

has_blocked_stderr=0
if echo "$OUTPUT" | grep -q "opk-guard: BLOCKED"; then has_blocked_stderr=1; fi
has_after_block=0
if echo "$OUTPUT" | grep -q "BLOCKED_RC="; then has_after_block=1; fi
has_safe_after=0
if echo "$OUTPUT" | grep -q "SAFE_AFTER_BLOCK"; then has_safe_after=1; fi
preserved=0
if [[ "$SENTINEL_BEFORE" == "$SENTINEL_AFTER" ]]; then preserved=1; fi

if [[ $has_blocked_stderr -eq 1 && $has_after_block -eq 1 && $has_safe_after -eq 1 && $preserved -eq 1 ]]; then
  ok "interactive rm --recursive --force -> blocked, shell survived, safe cmd ran, sentinel preserved"
else
  fail "interactive rm --recursive --force -> blocked=$has_blocked_stderr after_rc=$has_after_block safe=$has_safe_after preserved=$preserved"
  echo "    OUTPUT: $OUTPUT"
fi

# --- Test: git push --force (mock git) ---
TEST_DIR="$TMP_ROOT/test-push-interactive"
MOCK_BIN="$TEST_DIR/mock-bin"
MARKER="$TEST_DIR/force-push-executed"
rm -f "$MARKER"
mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/git" <<MOCKGIT
#!/usr/bin/env bash
if [[ "\$*" == *"--force"* && "\$*" == *"push"* ]]; then
  printf '%s\n' force-push-executed > "$MARKER"
  echo "fatal: mock: refusing force push" >&2
  exit 1
fi
exec /usr/bin/git "$@"
MOCKGIT
chmod +x "$MOCK_BIN/git"

mkdir -p "$TEST_DIR/repo"
git init -q "$TEST_DIR/repo"
git -C "$TEST_DIR/repo" config user.name test
git -C "$TEST_DIR/repo" config user.email test@example.invalid
printf 'initial\n' > "$TEST_DIR/repo/file.txt"
git -C "$TEST_DIR/repo" add file.txt
git -C "$TEST_DIR/repo" commit -qm initial

SCRIPT_FILE="$TEST_DIR/interactive-script.sh"
cat > "$SCRIPT_FILE" <<INTERACTIVE
source "$GUARD_PATH"
git push --force origin main
printf 'BLOCKED_RC=%s\n' "\$?"
printf 'SAFE_AFTER_BLOCK\n'
INTERACTIVE

set +e
OUTPUT="$(cd "$TEST_DIR/repo" && PATH="$MOCK_BIN:$PATH" bash --noprofile --norc -i < "$SCRIPT_FILE" 2>&1)"
RC=$?
set -e

mock_called=0
if [[ -f "$MARKER" ]]; then mock_called=1; fi

has_blocked_stderr=0
if echo "$OUTPUT" | grep -q "opk-guard: BLOCKED"; then has_blocked_stderr=1; fi
has_after_block=0
if echo "$OUTPUT" | grep -q "BLOCKED_RC="; then has_after_block=1; fi
has_safe_after=0
if echo "$OUTPUT" | grep -q "SAFE_AFTER_BLOCK"; then has_safe_after=1; fi

if [[ $has_blocked_stderr -eq 1 && $has_after_block -eq 1 && $has_safe_after -eq 1 && $mock_called -eq 0 ]]; then
  ok "interactive git push --force -> blocked, shell survived, safe cmd ran, mock not called"
else
  fail "interactive git push --force -> blocked=$has_blocked_stderr after_rc=$has_after_block safe=$has_safe_after mock_called=$mock_called"
  echo "    OUTPUT: $OUTPUT"
fi

# ======================================================================
# SECTION 2: Explicit exit 0 ends shell correctly
# ======================================================================
echo
echo "  === Explicit exit 0 ==="

TEST_DIR="$TMP_ROOT/test-exit0"
mkdir -p "$TEST_DIR"

SCRIPT_FILE="$TEST_DIR/interactive-script.sh"
cat > "$SCRIPT_FILE" <<INTERACTIVE
source "$GUARD_PATH"
printf 'BEFORE_EXIT\n'
exit 0
printf 'AFTER_EXIT_SHOULD_NOT_APPEAR\n'
INTERACTIVE

set +e
OUTPUT="$(bash --noprofile --norc -i < "$SCRIPT_FILE" 2>&1)"
RC=$?
set -e

has_before=0
if echo "$OUTPUT" | grep -q "BEFORE_EXIT"; then has_before=1; fi
has_after=0
if echo "$OUTPUT" | grep -q "AFTER_EXIT_SHOULD_NOT_APPEAR"; then has_after=1; fi

if [[ $has_before -eq 1 && $has_after -eq 0 && $RC -eq 0 ]]; then
  ok "explicit exit 0 -> shell exited with 0, no trailing output"
else
  fail "explicit exit 0 -> before=$has_before after_leaked=$has_after rc=$RC"
  echo "    OUTPUT: $OUTPUT"
fi

# ======================================================================
# Summary
# ======================================================================
echo
echo "=== guard-interactive summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
