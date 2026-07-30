#!/usr/bin/env bash
# Runtime contract tests for the public opk CLI. Uses only temporary HOME/project state.
set -euo pipefail

SOURCE_KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$SOURCE_KIT_DIR/scripts/check-cli-file-references.py"
REAL_PATH="$PATH"
PASS=0
FAIL=0
LAST_OUTPUT=""

REAL_HOME=""
REAL_HOME_PARENT=""
KIT_REAL="$(realpath -m -- "$SOURCE_KIT_DIR")"
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
    if created="$(mktemp -d "$candidate/.opk-cli-contracts.XXXXXX" 2>/dev/null)"; then
      if ! root="$(realpath -e -- "$created" 2>/dev/null)"; then
        rm -rf -- "$created"
        continue
      fi
      case "$root" in
        "$candidate"/.opk-cli-contracts.*) ;;
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
  printf 'test-cli-contracts: cannot create a safe sibling temporary directory\n' >&2
  exit 1
fi
if [[ -z "$TMP" || ! -d "$TMP" || "$TMP" == "/" ]]; then
  printf 'test-cli-contracts: invalid temporary directory: %s\n' "$TMP" >&2
  exit 1
fi
readonly TMP

cleanup() {
  local tmp_real
  tmp_real="$(realpath -m -- "${TMP:-}" 2>/dev/null)" || {
    printf 'test-cli-contracts: refusing unresolvable cleanup path: %s\n' "${TMP:-}" >&2
    return
  }
  case "$tmp_real" in
    "$REAL_HOME"/.opk-cli-contracts.*|"$REAL_HOME_PARENT"/.opk-cli-contracts.*|"$KIT_PARENT"/.opk-cli-contracts.*)
      [[ -d "$tmp_real" && "$tmp_real" != "/" ]] && rm -rf -- "$tmp_real"
      ;;
    *) printf 'test-cli-contracts: refusing unsafe cleanup path: %s\n' "${TMP:-}" >&2 ;;
  esac
}

on_signal() {
  local status="$1"
  trap - EXIT INT TERM
  cleanup
  exit "$status"
}

trap cleanup EXIT
trap 'on_signal 130' INT
trap 'on_signal 143' TERM

RUNTIME_KIT_DIR="$TMP/kit"
python3 - "$SOURCE_KIT_DIR" "$RUNTIME_KIT_DIR" <<'PY'
import shutil
import sys

shutil.copytree(
    sys.argv[1],
    sys.argv[2],
    symlinks=True,
    ignore=shutil.ignore_patterns(".git"),
)
PY

KIT_DIR="$RUNTIME_KIT_DIR"
OPK="$KIT_DIR/bin/opk"
export HOME="$TMP/home"
export OPENCODE_CONFIG_DIR="$HOME/.config/opencode"
export OPK_KIT_DIR="$KIT_DIR"
TEST_PROJECT="$TMP/project"
PROJECT_CONFIG="$TEST_PROJECT/.opencode/opencode.json"
FAKE_BIN="$TMP/bin"
mkdir -p "$OPENCODE_CONFIG_DIR" "$TEST_PROJECT/.opencode" "$FAKE_BIN"
printf '# CLI contract fixture\n' >"$TEST_PROJECT/AGENTS.md"

ok() {
  printf '  [ok]   %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

assert_contains() {
  local label="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then ok "$label"; else fail "$label: missing '$needle' in: $haystack"; fi
}

assert_success() {
  local label="$1"
  shift
  local rc
  if LAST_OUTPUT="$("$@" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  if ((rc == 0)); then ok "$label"; else fail "$label: exit $rc: $LAST_OUTPUT"; fi
}

assert_nonzero() {
  local label="$1"
  shift
  local rc
  if LAST_OUTPUT="$("$@" 2>&1)"; then
    rc=0
  else
    rc=$?
  fi
  if ((rc != 0)); then ok "$label"; else fail "$label: unexpectedly exited 0: $LAST_OUTPUT"; fi
}


snapshot_source_tree() {
  local snapshot
  if ! snapshot="$(python3 - "$SOURCE_KIT_DIR" <<'PY'
import hashlib
import os
import stat
import sys

root = os.path.realpath(sys.argv[1])
snapshot = hashlib.sha256()


def add_bytes(value: bytes) -> None:
    snapshot.update(len(value).to_bytes(8, "big"))
    snapshot.update(value)


def visit(directory: str, relative_dir: str = "") -> None:
    with os.scandir(directory) as iterator:
        entries = sorted(iterator, key=lambda entry: os.fsencode(entry.name))
    for entry in entries:
        if entry.name == ".git":
            continue
        relative = os.path.join(relative_dir, entry.name) if relative_dir else entry.name
        metadata = entry.stat(follow_symlinks=False)
        add_bytes(os.fsencode(relative))
        snapshot.update(metadata.st_mode.to_bytes(8, "big"))
        if stat.S_ISLNK(metadata.st_mode):
            add_bytes(os.fsencode(os.readlink(entry.path)))
        elif stat.S_ISREG(metadata.st_mode):
            snapshot.update(metadata.st_size.to_bytes(8, "big"))
            with open(entry.path, "rb") as handle:
                while chunk := handle.read(1024 * 1024):
                    snapshot.update(chunk)
        elif stat.S_ISDIR(metadata.st_mode):
            visit(entry.path, relative)


visit(root)
print(snapshot.hexdigest())
PY
)"; then
    printf 'test-cli-contracts: source snapshot failed\n' >&2
    return 1
  fi
  if [[ ! "$snapshot" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'test-cli-contracts: invalid source snapshot: %s\n' "$snapshot" >&2
    return 1
  fi
  printf '%s\n' "$snapshot"
}

printf 'CLI contracts\n'
source_snapshot_before="$(snapshot_source_tree)"

version_output="$($OPK version 2>&1)"
assert_contains "version is 2.1.2" "$version_output" "opk 2.1.2"

help_output="$($OPK help 2>&1)"
for entry in "opk mode" "opk safety-plugin" "opk hermes" "opk ecc" "opk supermemory"; do
  assert_contains "help lists $entry" "$help_output" "$entry"
done

assert_nonzero "project safety denies /tmp tree" \
  bash -c 'source "$1/scripts/project-profile.sh"; opk_project_is_safe "$2"' _ "$KIT_DIR" /tmp
assert_nonzero "project safety denies /var/tmp tree" \
  bash -c 'source "$1/scripts/project-profile.sh"; opk_project_is_safe "$2"' _ "$KIT_DIR" /var/tmp

cp "$KIT_DIR/templates/opencode.power.json" "$PROJECT_CONFIG"
cp "$KIT_DIR/templates/opencode.power.json" "$TMP/power-template.before"
cp "$KIT_DIR/templates/opencode.safe.json" "$TMP/safe-template.before"
printf 'global config sentinel\n' >"$OPENCODE_CONFIG_DIR/opencode.json"

pushd "$TEST_PROJECT" >/dev/null || exit 1
assert_success "mode show succeeds" "$OPK" mode show
mode_output="$LAST_OUTPUT"
assert_contains "mode show reports POWER" "$mode_output" "POWER"
assert_success "mode safe succeeds" "$OPK" mode safe >/dev/null
if cmp -s "$PROJECT_CONFIG" "$KIT_DIR/templates/opencode.safe.json"; then
  ok "mode safe installs project-local safe config"
else
  fail "mode safe installs project-local safe config"
fi
shopt -s nullglob
mode_backups=("$PROJECT_CONFIG".bak.*)
shopt -u nullglob
if ((${#mode_backups[@]} >= 1)) && cmp -s "${mode_backups[0]}" "$KIT_DIR/templates/opencode.power.json"; then
  ok "mode safe backs up previous project-local config"
else
  fail "mode safe backs up previous project-local config"
fi
assert_success "mode show after safe succeeds" "$OPK" mode show
mode_output="$LAST_OUTPUT"
assert_contains "mode show reports SAFE" "$mode_output" "SAFE"
sleep 1
assert_success "mode power succeeds" "$OPK" mode power >/dev/null
if cmp -s "$PROJECT_CONFIG" "$KIT_DIR/templates/opencode.power.json"; then
  ok "mode power installs project-local power config"
else
  fail "mode power installs project-local power config"
fi
shopt -s nullglob
mode_backups=("$PROJECT_CONFIG".bak.*)
shopt -u nullglob
safe_backup=false
for backup in "${mode_backups[@]}"; do
  cmp -s "$backup" "$KIT_DIR/templates/opencode.safe.json" && safe_backup=true
done
if ((${#mode_backups[@]} >= 2)) && [[ "$safe_backup" == true ]]; then
  ok "mode power backs up project-local safe config"
else
  fail "mode power backs up project-local safe config"
fi
if [[ "$(cat "$OPENCODE_CONFIG_DIR/opencode.json")" == "global config sentinel" ]]; then
  ok "mode commands ignore OPENCODE_CONFIG_DIR"
else
  fail "mode commands ignore OPENCODE_CONFIG_DIR"
fi
if cmp -s "$TMP/power-template.before" "$KIT_DIR/templates/opencode.power.json" && \
   cmp -s "$TMP/safe-template.before" "$KIT_DIR/templates/opencode.safe.json"; then
  ok "mode commands leave templates unchanged"
else
  fail "mode commands leave templates unchanged"
fi

assert_success "safety-plugin initial status succeeds" "$OPK" safety-plugin status
safety_output="$LAST_OUTPUT"
assert_contains "safety-plugin initially not installed" "$safety_output" "NOT_INSTALLED"
assert_success "safety-plugin install --yes succeeds" "$OPK" safety-plugin install --yes >/dev/null
if [[ -f .opencode/plugins/opk-safety-guard.js ]]; then ok "safety-plugin installs project plugin"; else fail "safety-plugin installs project plugin"; fi
assert_success "safety-plugin installed status succeeds" "$OPK" safety-plugin status
safety_output="$LAST_OUTPUT"
assert_contains "safety-plugin reports installed" "$safety_output" "INSTALLED"
popd >/dev/null || exit 1

assert_success "Hermes audit dry-run succeeds" "$OPK" hermes audit --dry-run
hermes_output="$LAST_OUTPUT"
assert_contains "Hermes dry-run reports plan" "$hermes_output" "Dry run complete"
assert_success "Hermes status check succeeds" "$OPK" hermes status
hermes_output="$LAST_OUTPUT"
assert_contains "Hermes status emits summary" "$hermes_output" "=== Summary ==="
assert_success "Hermes audit help succeeds" "$OPK" hermes audit --help
hermes_output="$LAST_OUTPUT"
assert_contains "Hermes help emits usage" "$hermes_output" "Usage:"

assert_success "ECC status succeeds" "$OPK" ecc status
ecc_output="$LAST_OUTPUT"
assert_contains "ECC status emits summary" "$ecc_output" "=== Summary ==="

cat >"$FAKE_BIN/npm" <<'EOF'
#!/usr/bin/env bash
printf 'npm called: %s\n' "$*" >>"$HOME/npm-called.log"
exit 97
EOF
chmod +x "$FAKE_BIN/npm"
PATH="$FAKE_BIN:$REAL_PATH" assert_success "supermemory init --help succeeds" "$OPK" supermemory init --help
supermemory_output="$LAST_OUTPUT"
assert_contains "supermemory init --help emits help" "$supermemory_output" "Usage:"
if [[ ! -e "$HOME/npm-called.log" ]]; then ok "supermemory init --help does not download package"; else fail "supermemory init --help called npm"; fi

assert_nonzero "unknown command exits nonzero" "$OPK" definitely-not-an-opk-command
unknown_output="$LAST_OUTPUT"
assert_contains "unknown command explains failure" "$unknown_output" "unknown command"

CHECK_FIXTURE="$TMP/checker-fixture"
mkdir -p "$CHECK_FIXTURE/bin" "$CHECK_FIXTURE/scripts"
printf 'fixture version\n' >"$CHECK_FIXTURE/VERSION"
printf 'fixture notice\n' >"$CHECK_FIXTURE/NOTICE"
printf 'fixture license\n' >"$CHECK_FIXTURE/LICENSE"
cat >"$CHECK_FIXTURE/bin/opk" <<'EOF'
cat "$KIT_DIR/VERSION"
cp "$KIT_DIR/NOTICE" "$HOME/NOTICE"
install -m 0644 "$KIT_DIR/LICENSE" "$HOME/LICENSE"
cat "$KIT_DIR/scripts/../NOTICE"
cp "$HOME/generated-source" "$KIT_DIR/generated.out"
install "$HOME/generated-source" "$KIT_DIR/generated-install.conf"
printf '%s\n' "$KIT_DIR/scripts"
source "$KIT_DIR/scripts/${dynamic_helper}"
if [[ -f "$KIT_DIR/optional.conf" ]]; then
  cat "$KIT_DIR/optional.conf"
fi
if [[ -f "$KIT_DIR/same-line.conf" ]]; then cat "$KIT_DIR/same-line.conf"; fi
if [[ -f "$KIT_DIR/next-line.conf" ]]
then
  cat "$KIT_DIR/next-line.conf"
fi
# cat "$KIT_DIR/comment-only.conf"
cat "$KIT_DIR/NOTICE" # cat "$KIT_DIR/inline-comment.conf"
message='cat "$KIT_DIR/quoted-message.conf"'
echo "$KIT_DIR/quoted-argument.conf"
EOF

assert_success "checker accepts normalized paths, destinations, multiline/same-line guards, and ignores directory/dynamic/comments/strings" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/opk"
checker_output="$LAST_OUTPUT"
assert_contains "fixture checker prints PASS" "$checker_output" "PASS"

cat >"$CHECK_FIXTURE/bin/escape-opk" <<'EOF'
cat "$KIT_DIR/../outside.txt"
EOF
assert_nonzero "checker rejects literal path escaping root" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/escape-opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker explains root escape" "$checker_output" "escapes root"

cat >"$CHECK_FIXTURE/bin/negated-guard-opk" <<'EOF'
if [[ ! -f "$KIT_DIR/negated.conf" ]]; then
  cat "$KIT_DIR/negated.conf"
fi
EOF
assert_nonzero "checker rejects negated existence guard" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/negated-guard-opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker reports negated guard reference" "$checker_output" "missing: negated.conf"

cat >"$CHECK_FIXTURE/bin/or-guard-opk" <<'EOF'
if [[ -f "$KIT_DIR/or.conf" || -n "$ALLOW_MISSING" ]]; then
  cat "$KIT_DIR/or.conf"
fi
EOF
assert_nonzero "checker rejects OR existence guard" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/or-guard-opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker reports OR-guarded reference" "$checker_output" "missing: or.conf"

cat >"$CHECK_FIXTURE/bin/same-line-scope-opk" <<'EOF'
if [[ -f "$KIT_DIR/scoped.conf" ]]; then cat "$KIT_DIR/scoped.conf"; fi
cat "$KIT_DIR/scoped.conf"
EOF
assert_nonzero "checker closes same-line if scope at fi" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/same-line-scope-opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker reports reference after same-line fi" "$checker_output" "missing: scoped.conf"

cat >"$CHECK_FIXTURE/bin/and-semicolon-opk" <<'EOF'
[[ -f "$KIT_DIR/and.conf" ]] && cat "$KIT_DIR/and.conf"; cat "$KIT_DIR/and.conf"
EOF
assert_nonzero "checker stops AND guard at semicolon" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/and-semicolon-opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker reports reference after guarded AND command" "$checker_output" "missing: and.conf"

cat >"$CHECK_FIXTURE/bin/shell-keyword-opk" <<'EOF'
if cat "$KIT_DIR/keyword-if.conf"; then :; fi
! cat "$KIT_DIR/keyword-not.conf"
EOF
assert_nonzero "checker recognizes file consumers after if and ! keywords" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/shell-keyword-opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker reports consumer after if" "$checker_output" "missing: keyword-if.conf"
assert_contains "checker reports consumer after !" "$checker_output" "missing: keyword-not.conf"

rm "$CHECK_FIXTURE/NOTICE"
assert_nonzero "checker rejects missing extensionless cp source" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker identifies missing NOTICE" "$checker_output" "missing: NOTICE"
printf 'fixture notice\n' >"$CHECK_FIXTURE/NOTICE"

rm "$CHECK_FIXTURE/LICENSE"
assert_nonzero "checker rejects missing extensionless install source" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker identifies missing LICENSE" "$checker_output" "missing: LICENSE"
printf 'fixture license\n' >"$CHECK_FIXTURE/LICENSE"

rm "$CHECK_FIXTURE/VERSION"
assert_nonzero "checker rejects missing no-extension literal file" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker identifies missing VERSION" "$checker_output" "missing: VERSION"
printf 'fixture version\n' >"$CHECK_FIXTURE/VERSION"

cat >>"$CHECK_FIXTURE/bin/opk" <<'EOF'
cat "$KIT_DIR/optional.conf"
EOF
assert_nonzero "checker does not apply optional guard to unrelated occurrence" \
  python3 "$CHECKER" --root "$CHECK_FIXTURE" --cli "$CHECK_FIXTURE/bin/opk"
checker_output="$LAST_OUTPUT"
assert_contains "checker identifies unguarded optional.conf occurrence" "$checker_output" "missing: optional.conf"

assert_success "CLI file-reference checker succeeds" python3 "$CHECKER"
checker_output="$LAST_OUTPUT"
assert_contains "CLI file-reference checker prints PASS" "$checker_output" "PASS"

source_snapshot_after="$(snapshot_source_tree)"
if [[ "$source_snapshot_before" == "$source_snapshot_after" ]]; then
  ok "CLI run leaves tracked/untracked source contents unchanged"
else
  fail "CLI run changed tracked/untracked source contents (before=$source_snapshot_before, after=$source_snapshot_after)"
fi

printf '\nCLI contracts: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
