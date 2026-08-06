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
# Uses real BASH_ENV execution (production DEBUG trap) — not just
# the classifier function — to verify the full guard path.
#
# Usage: bash scripts/test-guard-no-env-bypass.sh
# ─────────────────────────────────────────────────────────────────

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

PASS=0
FAIL=0

ok() { echo "  ok   $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL $*"; FAIL=$((FAIL + 1)); }

GUARD_PATH="$ROOT/templates/guard/opk-guard-bashrc"

echo "[guard-no-env-bypass]"

# ======================================================================
# SECTION 1: BASH_ENV E2E matrix — production fragment, real DEBUG trap
# ======================================================================
echo
echo "  === BASH_ENV E2E matrix (production DEBUG trap) ==="
echo "  Each case runs a fresh Bash process via BASH_ENV."

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

# Environment values to test — unset and empty are distinct
ENV_VALUES=(
  "UNSET|"
  "EMPTY|"
  "block|block"
  "warn|warn"
  "allow|allow"
  "off|off"
  "ZERO|0"
  "FALSE|false"
  "DISABLED|disabled"
  "RANDOM|random-value"
  "YES|YES"
  "TRUE|true"
)

# Destructive commands to test
DESTRUCTIVE_CMDS=(
  "git reset --hard HEAD"
  "git clean -df"
  "rm --recursive --force target"
  "git push --force origin main"
)

# --- Helper: run a command under production BASH_ENV guard ---
# Args: $1=command string, $2=env_var_value ("UNSET"|"EMPTY"|"value")
# Sets OUTPUT and RC globals.
run_guarded() {
  local cmd="$1"
  local env_val="$2"
  set +e
  if [[ "$env_val" == "UNSET" ]]; then
    OUTPUT="$(env -u OPK_GUARD_STRICT BASH_ENV="$GUARD_PATH" bash --noprofile --norc -c "$cmd" 2>&1)"
  elif [[ "$env_val" == "EMPTY" ]]; then
    OUTPUT="$(env OPK_GUARD_STRICT= BASH_ENV="$GUARD_PATH" bash --noprofile --norc -c "$cmd" 2>&1)"
  else
    OUTPUT="$(env "OPK_GUARD_STRICT=$env_val" BASH_ENV="$GUARD_PATH" bash --noprofile --norc -c "$cmd" 2>&1)"
  fi
  RC=$?
  set -e
}

# --- Helper: setup a temp git repo ---
setup_temp_repo() {
  local dir="$1"
  rm -rf "$dir"
  git init -q "$dir"
  git -C "$dir" config user.name test
  git -C "$dir" config user.email test@example.invalid
}

# --- Helper: setup a temp dir with sentinel ---
setup_temp_dir() {
  local dir="$1"
  rm -rf "$dir"
  mkdir -p "$dir/target"
  echo "SENTINEL" > "$dir/target/sentinel.txt"
}

# --- Helper: setup mock git for force-push test ---
setup_mock_git() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat > "$bin_dir/git" <<'MOCKGIT'
#!/usr/bin/env bash
# Mock git: record if force push was actually executed
MARKER_FILE="__FORCE_PUSH_MARKER__"
if [[ "$*" == *"--force"* && "$*" == *"push"* ]]; then
  echo "force-push-executed" > "$MARKER_FILE"
  echo "fatal: mock: refusing force push" >&2
  exit 1
fi
# Delegate safe commands to real git
exec /usr/bin/git "$@"
MOCKGIT
  chmod +x "$bin_dir/git"
}

# --- E2E matrix ---
E2E_TOTAL=0
E2E_PASS=0
E2E_FAIL=0

for cmd in "${DESTRUCTIVE_CMDS[@]}"; do
  for env_spec in "${ENV_VALUES[@]}"; do
    IFS='|' read -r env_name env_val <<< "$env_spec"
    E2E_TOTAL=$((E2E_TOTAL + 1))

    case "$cmd" in
      "git reset --hard HEAD")
        TEST_REPO="$TMP_ROOT/repo-reset-$env_name"
        setup_temp_repo "$TEST_REPO"
        printf 'original\n' > "$TEST_REPO/file.txt"
        git -C "$TEST_REPO" add file.txt
        git -C "$TEST_REPO" commit -qm initial
        printf 'user-dirty-change\n' > "$TEST_REPO/file.txt"

        BEFORE="$(cat "$TEST_REPO/file.txt")"
        run_guarded "git reset --hard HEAD" "$env_val"
        AFTER="$(cat "$TEST_REPO/file.txt")"

        blocked=0
        if echo "$OUTPUT" | grep -q "BLOCKED"; then blocked=1; fi
        preserved=0
        if [[ "$BEFORE" == "$AFTER" ]]; then preserved=1; fi

        if [[ $RC -ne 0 && $blocked -eq 1 && $preserved -eq 1 ]]; then
          ok "reset --hard env=$env_name -> blocked, exit=$RC, file preserved"
          E2E_PASS=$((E2E_PASS + 1))
        else
          fail "reset --hard env=$env_name -> RC=$RC blocked=$blocked preserved=$preserved"
          echo "    OUTPUT: $OUTPUT"
          E2E_FAIL=$((E2E_FAIL + 1))
        fi
        ;;

      "git clean -df")
        TEST_REPO="$TMP_ROOT/repo-clean-$env_name"
        setup_temp_repo "$TEST_REPO"
        printf 'tracked\n' > "$TEST_REPO/tracked.txt"
        git -C "$TEST_REPO" add tracked.txt
        git -C "$TEST_REPO" commit -qm initial
        printf 'untracked-sentinel\n' > "$TEST_REPO/untracked.txt"
        mkdir -p "$TEST_REPO/untracked_dir"
        echo "DIR_SENTINEL" > "$TEST_REPO/untracked_dir/sentinel.txt"

        UF_BEFORE="$(cat "$TEST_REPO/untracked.txt")"
        UDIR_BEFORE="$(cat "$TEST_REPO/untracked_dir/sentinel.txt")"
        run_guarded "git clean -df" "$env_val"
        UF_AFTER="$(cat "$TEST_REPO/untracked.txt" 2>/dev/null || echo "DELETED")"
        UDIR_AFTER="$(cat "$TEST_REPO/untracked_dir/sentinel.txt" 2>/dev/null || echo "DELETED")"

        blocked=0
        if echo "$OUTPUT" | grep -q "BLOCKED"; then blocked=1; fi
        preserved=0
        if [[ "$UF_BEFORE" == "$UF_AFTER" && "$UDIR_BEFORE" == "$UDIR_AFTER" ]]; then preserved=1; fi

        if [[ $RC -ne 0 && $blocked -eq 1 && $preserved -eq 1 ]]; then
          ok "clean -df env=$env_name -> blocked, exit=$RC, untracked preserved"
          E2E_PASS=$((E2E_PASS + 1))
        else
          fail "clean -df env=$env_name -> RC=$RC blocked=$blocked preserved=$preserved"
          echo "    OUTPUT: $OUTPUT"
          E2E_FAIL=$((E2E_FAIL + 1))
        fi
        ;;

      "rm --recursive --force target")
        TEST_DIR="$TMP_ROOT/rm-target-$env_name"
        setup_temp_dir "$TEST_DIR"
        SENT_BEFORE="$(cat "$TEST_DIR/target/sentinel.txt")"
        run_guarded "rm --recursive --force target" "$env_val"
        SENT_AFTER="$(cat "$TEST_DIR/target/sentinel.txt" 2>/dev/null || echo "DELETED")"

        blocked=0
        if echo "$OUTPUT" | grep -q "BLOCKED"; then blocked=1; fi
        preserved=0
        if [[ "$SENT_BEFORE" == "$SENT_AFTER" ]]; then preserved=1; fi

        if [[ $RC -ne 0 && $blocked -eq 1 && $preserved -eq 1 ]]; then
          ok "rm -rf target env=$env_name -> blocked, exit=$RC, sentinel preserved"
          E2E_PASS=$((E2E_PASS + 1))
        else
          fail "rm -rf target env=$env_name -> RC=$RC blocked=$blocked preserved=$preserved"
          echo "    OUTPUT: $OUTPUT"
          E2E_FAIL=$((E2E_FAIL + 1))
        fi
        ;;

      "git push --force origin main")
        MOCK_DIR="$TMP_ROOT/mock-bin-$env_name"
        MARKER="$MOCK_DIR/__FORCE_PUSH_MARKER__"
        rm -f "$MARKER"
        setup_mock_git "$MOCK_DIR"

        TEST_REPO="$TMP_ROOT/repo-push-$env_name"
        setup_temp_repo "$TEST_REPO"

        set +e
        if [[ "$env_val" == "UNSET" ]]; then
          OUTPUT="$(cd "$TEST_REPO" && env -u OPK_GUARD_STRICT BASH_ENV="$GUARD_PATH" PATH="$MOCK_DIR:$PATH" bash --noprofile --norc -c "git push --force origin main" 2>&1)"
        elif [[ "$env_val" == "EMPTY" ]]; then
          OUTPUT="$(cd "$TEST_REPO" && env OPK_GUARD_STRICT= BASH_ENV="$GUARD_PATH" PATH="$MOCK_DIR:$PATH" bash --noprofile --norc -c "git push --force origin main" 2>&1)"
        else
          OUTPUT="$(cd "$TEST_REPO" && env "OPK_GUARD_STRICT=$env_val" BASH_ENV="$GUARD_PATH" PATH="$MOCK_DIR:$PATH" bash --noprofile --norc -c "git push --force origin main" 2>&1)"
        fi
        RC=$?
        set -e

        blocked=0
        if echo "$OUTPUT" | grep -q "BLOCKED"; then blocked=1; fi
        mock_called=0
        if [[ -f "$MARKER" ]]; then mock_called=1; fi

        if [[ $RC -ne 0 && $blocked -eq 1 && $mock_called -eq 0 ]]; then
          ok "push --force env=$env_name -> blocked, exit=$RC, mock not called"
          E2E_PASS=$((E2E_PASS + 1))
        else
          fail "push --force env=$env_name -> RC=$RC blocked=$blocked mock_called=$mock_called"
          echo "    OUTPUT: $OUTPUT"
          E2E_FAIL=$((E2E_FAIL + 1))
        fi
        ;;
    esac
  done
done

echo
echo "  E2E matrix: $E2E_PASS/$E2E_TOTAL passed, $E2E_FAIL failed"

# ======================================================================
# SECTION 2: Benign commands must still work through production BASH_ENV
# ======================================================================
echo
echo "  === Benign commands (must pass through production BASH_ENV) ==="

BENIGN_CMDS=(
  "git status --short"
  "git clean -n"
  "git clean --dry-run"
  "printf 'safe\n'"
)

BENIGN_PASS=0
BENIGN_FAIL=0

for cmd in "${BENIGN_CMDS[@]}"; do
  set +e
  OUTPUT="$(BASH_ENV="$GUARD_PATH" bash --noprofile --norc -c "$cmd" 2>&1)"
  RC=$?
  set -e

  blocked=0
  if echo "$OUTPUT" | grep -q "BLOCKED"; then blocked=1; fi

  if [[ $RC -eq 0 && $blocked -eq 0 ]]; then
    ok "benign [$cmd] -> allowed (exit=0, no BLOCKED)"
    BENIGN_PASS=$((BENIGN_PASS + 1))
  else
    fail "benign [$cmd] -> RC=$RC blocked=$blocked"
    echo "    OUTPUT: $OUTPUT"
    BENIGN_FAIL=$((BENIGN_FAIL + 1))
  fi
done

# ======================================================================
# SECTION 3: Mutation test — prove E2E catches old warn bypass
# ======================================================================
echo
echo "  === Mutation test: old warn-to-allow bypass ==="

MUTATED="$TMP_ROOT/mutated-guard-bashrc"
cp "$GUARD_PATH" "$MUTATED"

# Re-insert the old buggy behavior into the DEBUG trap:
# warn mode returns 0 even when the classifier says block.
# We replace the entire _opk_guard_debug function with the old buggy version.
python3 - "$MUTATED" <<'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, 'r') as f:
    content = f.read()

old_func = re.search(r'_opk_guard_debug\(\) \{.*?\n\}', content, re.DOTALL).group(0)

new_func = """_opk_guard_debug() {
  [[ "${_opk_guard_active:-0}" == "1" ]] && return 0
  local rc=0
  local c="${BASH_COMMAND:-}"
  local _opk_guard_active=1
  case "$c" in
    '' | _opk_guard_* | opk_guard_* | local* | unset* | return* | exit* | :* | '[['* | trap* | source* | shopt*)
      return 0 ;;
  esac
  OPK_GUARD_SILENT=1 opk_guard_scan "$c" "${OPK_GUARD_ROOT:-$PWD}" || rc=1
  if [[ $rc -eq 1 ]]; then
    # OLD BUG: warn mode bypasses the block
    if [[ "${OPK_GUARD_STRICT:-block}" == "warn" ]]; then
      rc=0
    else
      echo "opk-guard: BLOCKED — $c (run it by hand if you are sure)" >&2
      shopt -s extdebug 2>/dev/null || true
    fi
  fi
  return $rc
}"""

content = content.replace(old_func, new_func)
with open(path, 'w') as f:
    f.write(content)
PYEOF

# Run mutated guard with OPK_GUARD_STRICT=warn
MUT_REPO="$TMP_ROOT/mut-repo"
setup_temp_repo "$MUT_REPO"
printf 'original\n' > "$MUT_REPO/file.txt"
git -C "$MUT_REPO" add file.txt
git -C "$MUT_REPO" commit -qm initial
printf 'user-dirty-change\n' > "$MUT_REPO/file.txt"

MUT_BEFORE="$(cat "$MUT_REPO/file.txt")"
set +e
OUTPUT="$(cd "$MUT_REPO" && env OPK_GUARD_STRICT=warn BASH_ENV="$MUTATED" bash --noprofile --norc -c "git reset --hard HEAD" 2>&1)"
MUT_RC=$?
set -e
MUT_AFTER="$(cat "$MUT_REPO/file.txt")"

mutation_caught=0
if [[ "$MUT_BEFORE" != "$MUT_AFTER" ]]; then
  # Mutated guard let the command through — test catches this
  mutation_caught=1
fi
if [[ $MUT_RC -eq 0 ]] && ! echo "$OUTPUT" | grep -q "BLOCKED"; then
  # Mutated guard returned 0 and didn't block — test catches this
  mutation_caught=1
fi

if [[ $mutation_caught -eq 1 ]]; then
  ok "mutation test: old warn bypass DETECTED (dirty file changed or no BLOCKED)"
else
  fail "mutation test: old warn bypass NOT detected — test may be a false positive"
fi

# ======================================================================
# SECTION 4: Static checks — no WARN-AND-RAN, no OPK_GUARD_STRICT in trap
# ======================================================================
echo
echo "  === Static checks ==="

if grep -q "WARN-AND-RAN" "$ROOT/scripts/sync-guard-bashrc.sh" \
   "$ROOT/scripts/guard-rules.sh" "$ROOT/templates/guard/opk-guard-bashrc" 2>/dev/null; then
  fail "WARN-AND-RAN string still present in guard files"
else
  ok "no WARN-AND-RAN string in guard files"
fi

if grep -q 'OPK_GUARD_STRICT' "$ROOT/templates/guard/opk-guard-bashrc" 2>/dev/null; then
  fail "OPK_GUARD_STRICT still referenced in opk-guard-bashrc (bypass risk)"
else
  ok "OPK_GUARD_STRICT not referenced in opk-guard-bashrc DEBUG-trap glue"
fi

# Static checks on the guard files (not self-referential)
if grep -q 'WARN-AND-RAN\|return 0.*warn' "$ROOT/templates/guard/opk-guard-bashrc" 2>/dev/null \
   || grep -q 'WARN-AND-RAN\|return 0.*warn' "$ROOT/scripts/sync-guard-bashrc.sh" 2>/dev/null; then
  fail "WARN-AND-RAN pattern still present in guard files"
else
  ok "no WARN-AND-RAN string in guard files"
fi

if grep -q 'OPK_GUARD_STRICT' "$ROOT/templates/guard/opk-guard-bashrc" 2>/dev/null; then
  fail "OPK_GUARD_STRICT still referenced in opk-guard-bashrc DEBUG-trap glue"
else
  ok "OPK_GUARD_STRICT not referenced in opk-guard-bashrc DEBUG-trap glue"
fi

# ======================================================================
# Summary
# ======================================================================
echo
echo "=== guard-no-env-bypass summary ==="
echo "passed: $PASS"
echo "failed: $FAIL"
echo "e2e-matrix: $E2E_PASS/$E2E_TOTAL"
echo "benign: $BENIGN_PASS/${#BENIGN_CMDS[@]}"

if [[ $FAIL -gt 0 ]]; then
  echo "RESULT: FAIL"
  exit 1
fi
echo "RESULT: PASS"
exit 0
