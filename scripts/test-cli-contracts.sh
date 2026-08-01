#!/usr/bin/env bash
# Runtime contract tests for the public opk CLI. Uses only temporary HOME/project state.
# shellcheck disable=SC2016  # Child-shell snippets intentionally expand positional parameters there.
set -euo pipefail

SOURCE_KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$SOURCE_KIT_DIR/scripts/check-cli-file-references.py"
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
PROJECT_CONFIG="$TEST_PROJECT/opencode.json"
mkdir -p "$OPENCODE_CONFIG_DIR" "$TEST_PROJECT/.opencode"
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
  local root="${1:-$SOURCE_KIT_DIR}" snapshot
  if ! snapshot="$(python3 - "$root" <<'PY'
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
assert_contains "version is 2.1.3" "$version_output" "opk 2.1.3"

help_output="$($OPK help 2>&1)"
for entry in "opk mode" "opk permissions" "opk auto" "opk run-auto" "opk safety-plugin" "opk hermes" "opk ecc" "opk supermemory"; do
  assert_contains "help lists $entry" "$help_output" "$entry"
done

assert_nonzero "project safety denies /tmp tree" \
  bash -c 'source "$1/scripts/project-profile.sh"; opk_project_is_safe "$2"' _ "$KIT_DIR" /tmp
assert_nonzero "project safety denies /var/tmp tree" \
  bash -c 'source "$1/scripts/project-profile.sh"; opk_project_is_safe "$2"' _ "$KIT_DIR" /var/tmp

cp "$KIT_DIR/templates/opencode.power.json" "$PROJECT_CONFIG"
cp "$KIT_DIR/templates/opencode.power.json" "$TMP/power-template.before"
cp "$KIT_DIR/templates/opencode.safe.json" "$TMP/safe-template.before"
printf '{"$schema":"https://opencode.ai/config.json","share":"manual"}\n' >"$OPENCODE_CONFIG_DIR/opencode.json"

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
mode_backups=("$PROJECT_CONFIG".opk-bak.*)
shopt -u nullglob
if ((${#mode_backups[@]} >= 1)) && cmp -s "${mode_backups[0]}" "$KIT_DIR/templates/opencode.power.json"; then
  ok "mode safe backs up previous project-local config"
else
  fail "mode safe backs up previous project-local config"
fi
assert_success "mode show after safe succeeds" "$OPK" mode show
mode_output="$LAST_OUTPUT"
assert_contains "mode show reports SAFE" "$mode_output" "SAFE"
assert_success "permissions doctor succeeds in Safe Mode" "$OPK" permissions doctor
assert_contains "permissions doctor reports SAFE" "$LAST_OUTPUT" "Mode: SAFE"
assert_contains "permissions doctor redacts inline config" "$LAST_OUTPUT" "OPENCODE_CONFIG_CONTENT: unset"
assert_nonzero "opk auto refuses Safe Mode" "$OPK" auto --help
sleep 1
assert_success "mode power succeeds" "$OPK" mode power >/dev/null
if cmp -s "$PROJECT_CONFIG" "$KIT_DIR/templates/opencode.power.json"; then
  ok "mode power installs project-local power config"
else
  fail "mode power installs project-local power config"
fi
shopt -s nullglob
mode_backups=("$PROJECT_CONFIG".opk-bak.*)
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
assert_success "permissions doctor succeeds in Power Mode" "$OPK" permissions doctor
assert_contains "permissions doctor reports POWER" "$LAST_OUTPUT" "Mode: POWER"
assert_success "opk auto delegates supported --auto help" "$OPK" auto --help

REAL_OPENCODE="$(command -v opencode)"
FAKE_BIN="$TMP/fake-opencode-bin"
AUTO_CAPTURE="$TMP/run-auto.args"
mkdir -p "$FAKE_BIN"
cat >"$FAKE_BIN/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  debug|--help|--version) exec "$REAL_OPENCODE" "$@" ;;
esac
printf '%s\n' "$@" >"$AUTO_CAPTURE"
EOF
chmod +x "$FAKE_BIN/opencode"
export REAL_OPENCODE AUTO_CAPTURE
assert_success "opk run-auto preserves prompt quoting" env PATH="$FAKE_BIN:$PATH" "$OPK" run-auto 'prompt; $(touch should-not-run)'
if [[ "$(cat "$AUTO_CAPTURE")" == $'run\n--auto\nprompt; $(touch should-not-run)' && ! -e "$TEST_PROJECT/should-not-run" ]]; then
  ok "opk run-auto passes literal prompt without eval"
else
  fail "opk run-auto changed or evaluated prompt"
fi
if [[ "$(cat "$OPENCODE_CONFIG_DIR/opencode.json")" == '{"$schema":"https://opencode.ai/config.json","share":"manual"}' ]]; then
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

SAFETY_CASE_ROOT="$TMP/safety-cases"
SAFETY_OUTSIDE="$TMP/safety-outside"
mkdir -p \
  "$SAFETY_CASE_ROOT/opencode-link" \
  "$SAFETY_CASE_ROOT/plugins-link/.opencode" \
  "$SAFETY_CASE_ROOT/target-link/.opencode/plugins" \
  "$SAFETY_CASE_ROOT/normal" \
  "$SAFETY_CASE_ROOT/existing-opk/.opencode/plugins" \
  "$SAFETY_CASE_ROOT/custom/.opencode/plugins" \
  "$SAFETY_CASE_ROOT/copy-failure/.opencode/plugins" \
  "$SAFETY_OUTSIDE/opencode-target" \
  "$SAFETY_OUTSIDE/plugins-target"
for project in "$SAFETY_CASE_ROOT"/*; do
  printf '# safety installer fixture\n' >"$project/AGENTS.md"
done
printf 'outside opencode sentinel\n' >"$SAFETY_OUTSIDE/opencode-target/sentinel"
printf 'outside plugins sentinel\n' >"$SAFETY_OUTSIDE/plugins-target/sentinel"
printf '%s\n' '@opk-plugin opk-safety-guard' 'outside target sentinel' >"$SAFETY_OUTSIDE/plugin-target.js"
ln -s "$SAFETY_OUTSIDE/opencode-target" "$SAFETY_CASE_ROOT/opencode-link/.opencode"
ln -s "$SAFETY_OUTSIDE/plugins-target" "$SAFETY_CASE_ROOT/plugins-link/.opencode/plugins"
ln -s "$SAFETY_OUTSIDE/plugin-target.js" "$SAFETY_CASE_ROOT/target-link/.opencode/plugins/opk-safety-guard.js"
outside_snapshot_before="$(snapshot_source_tree "$SAFETY_OUTSIDE")"

assert_nonzero ".opencode symlink is rejected" \
  bash -c 'cd "$1" && bash "$2/scripts/install-safety-plugin.sh" --yes' _ \
  "$SAFETY_CASE_ROOT/opencode-link" "$KIT_DIR"
assert_nonzero ".opencode/plugins symlink is rejected" \
  bash -c 'cd "$1" && bash "$2/scripts/install-safety-plugin.sh" --yes' _ \
  "$SAFETY_CASE_ROOT/plugins-link" "$KIT_DIR"
assert_nonzero "safety plugin target symlink is rejected" \
  bash -c 'cd "$1" && bash "$2/scripts/install-safety-plugin.sh" --yes' _ \
  "$SAFETY_CASE_ROOT/target-link" "$KIT_DIR"

assert_success "normal project installs safety plugin" \
  bash -c 'cd "$1" && bash "$2/scripts/install-safety-plugin.sh" --yes' _ \
  "$SAFETY_CASE_ROOT/normal" "$KIT_DIR"
if cmp -s \
  "$SAFETY_CASE_ROOT/normal/.opencode/plugins/opk-safety-guard.js" \
  "$KIT_DIR/templates/plugins/opk-safety-guard.js"; then
  ok "normal safety plugin matches template"
else
  fail "normal safety plugin matches template"
fi

cp "$KIT_DIR/templates/plugins/opk-safety-guard.js" \
  "$SAFETY_CASE_ROOT/existing-opk/.opencode/plugins/opk-safety-guard.js"
printf '// previous OPK plugin fixture\n' \
  >>"$SAFETY_CASE_ROOT/existing-opk/.opencode/plugins/opk-safety-guard.js"
cp "$SAFETY_CASE_ROOT/existing-opk/.opencode/plugins/opk-safety-guard.js" \
  "$TMP/existing-opk.before"
assert_success "existing OPK safety plugin is replaced safely" \
  bash -c 'cd "$1" && bash "$2/scripts/install-safety-plugin.sh" --yes' _ \
  "$SAFETY_CASE_ROOT/existing-opk" "$KIT_DIR"
shopt -s nullglob
opk_backups=("$SAFETY_CASE_ROOT/existing-opk/.opencode/plugins/opk-safety-guard.js.bak."*)
shopt -u nullglob
if ((${#opk_backups[@]} == 1)) && cmp -s "${opk_backups[0]}" "$TMP/existing-opk.before"; then
  ok "existing OPK safety plugin is backed up"
else
  fail "existing OPK safety plugin is backed up"
fi
if cmp -s \
  "$SAFETY_CASE_ROOT/existing-opk/.opencode/plugins/opk-safety-guard.js" \
  "$KIT_DIR/templates/plugins/opk-safety-guard.js"; then
  ok "existing OPK safety plugin is replaced with current template"
else
  fail "existing OPK safety plugin is replaced with current template"
fi

printf 'custom safety plugin sentinel\n' \
  >"$SAFETY_CASE_ROOT/custom/.opencode/plugins/opk-safety-guard.js"
cp "$SAFETY_CASE_ROOT/custom/.opencode/plugins/opk-safety-guard.js" "$TMP/custom.before"
assert_success "custom safety plugin is preserved" \
  bash -c 'cd "$1" && bash "$2/scripts/install-safety-plugin.sh" --yes' _ \
  "$SAFETY_CASE_ROOT/custom" "$KIT_DIR"
if cmp -s "$SAFETY_CASE_ROOT/custom/.opencode/plugins/opk-safety-guard.js" "$TMP/custom.before"; then
  ok "custom safety plugin is not overwritten"
else
  fail "custom safety plugin is not overwritten"
fi

FAILURE_INSTALLER="$KIT_DIR/scripts/install-safety-plugin-failure-fixture.sh"
python3 - "$KIT_DIR/scripts/install-safety-plugin.sh" "$FAILURE_INSTALLER" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
needle = "        link_fd_noreplace(temp_fd, target_name)"
replacement = "        raise OSError(5, 'injected atomic publish failure')"
if source.count(needle) != 1:
    raise SystemExit("unexpected installer fixture shape")
Path(sys.argv[2]).write_text(source.replace(needle, replacement))
PY
assert_nonzero "failed atomic publish is reported" \
  bash -c 'cd "$1" && bash "$2" --yes' _ \
  "$SAFETY_CASE_ROOT/copy-failure" "$FAILURE_INSTALLER"

outside_snapshot_after="$(snapshot_source_tree "$SAFETY_OUTSIDE")"
if [[ "$outside_snapshot_before" == "$outside_snapshot_after" ]]; then
  ok "symlink attacks do not create or change files outside projects"
else
  fail "symlink attacks changed files outside projects"
fi
if compgen -G "$SAFETY_CASE_ROOT/*/.opencode/plugins/.opk-safety-guard.tmp.*" >/dev/null; then
  fail "safety installer leaves no temporary files"
else
  ok "safety installer leaves no temporary files"
fi

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

SUPERMEMORY_ABSENT_BIN="$TMP/supermemory-absent-bin"
SUPERMEMORY_PRESENT_BIN="$TMP/supermemory-present-bin"
mkdir -p "$SUPERMEMORY_ABSENT_BIN" "$SUPERMEMORY_PRESENT_BIN"
for tool in bash cat dirname uname; do
  tool_path="$(command -v "$tool")"
  ln -s "$tool_path" "$SUPERMEMORY_ABSENT_BIN/$tool"
  ln -s "$tool_path" "$SUPERMEMORY_PRESENT_BIN/$tool"
done
for manager in npm npx; do
  cat >"$SUPERMEMORY_ABSENT_BIN/$manager" <<'EOF'
#!/usr/bin/env bash
printf 'package manager called: %s %s\n' "${0##*/}" "$*" >>"$HOME/package-manager-called.log"
exit 97
EOF
  chmod +x "$SUPERMEMORY_ABSENT_BIN/$manager"
done

PATH="$SUPERMEMORY_ABSENT_BIN" assert_success \
  "supermemory init --help succeeds without Supermemory" "$OPK" supermemory init --help
supermemory_output="$LAST_OUTPUT"
assert_contains "missing Supermemory prints install guidance" "$supermemory_output" "Run: opk supermemory install"
if [[ ! -e "$HOME/package-manager-called.log" ]]; then
  ok "missing Supermemory does not call npm or npx"
else
  fail "missing Supermemory called a package manager"
fi

cat >"$SUPERMEMORY_PRESENT_BIN/supermemory" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$HOME/supermemory-called.log"
printf 'fake Supermemory usage\n'
EOF
chmod +x "$SUPERMEMORY_PRESENT_BIN/supermemory"
PATH="$SUPERMEMORY_PRESENT_BIN" assert_success \
  "supermemory init --help delegates to installed executable" "$OPK" supermemory init --help
assert_contains "fake Supermemory output is returned" "$LAST_OUTPUT" "fake Supermemory usage"
if [[ "$(<"$HOME/supermemory-called.log")" == "init --help" ]]; then
  ok "installed Supermemory receives init --help"
else
  fail "installed Supermemory receives init --help"
fi

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
