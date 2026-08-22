#!/usr/bin/env bash
# Behavioral contract for bootstrap/setup action selection and --yes forwarding.
set -euo pipefail

SOURCE_KIT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

make_root() {
  local base="${HOME:-}"
  [[ -n "$base" && "$base" == /* && -d "$base" && -w "$base" ]] || return 1
  mktemp -d "$base/.opk-entrypoint-contract.XXXXXX"
}

ROOT="$(make_root)" || {
  echo "test-installer-entrypoints: cannot create safe test root under HOME" >&2
  exit 1
}

cleanup() {
  case "${ROOT:-}" in
    "${HOME}"/.opk-entrypoint-contract.*)
      [[ ! -d "$ROOT" ]] || rm -r -- "$ROOT"
      ;;
    *)
      echo "test-installer-entrypoints: refusing unsafe cleanup path: ${ROOT:-}" >&2
      ;;
  esac
}
trap cleanup EXIT

KIT="$ROOT/kit"
TEST_HOME="$ROOT/home"
PROJECT="$ROOT/project"
LOG="$ROOT/child.log"
mkdir -p "$KIT/scripts" "$KIT/opencode-global" "$TEST_HOME" "$PROJECT"
cp "$SOURCE_KIT/bootstrap.sh" "$KIT/bootstrap.sh"
cp "$SOURCE_KIT/setup.sh" "$KIT/setup.sh"
cp "$SOURCE_KIT/scripts/require-linux.sh" "$KIT/scripts/require-linux.sh"
cp "$SOURCE_KIT/VERSION" "$KIT/VERSION"

cat >"$KIT/fake-child.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "$(basename "$0")" >>"$OPK_ENTRYPOINT_LOG"
for arg in "$@"; do
  printf '\t%s' "$arg" >>"$OPK_ENTRYPOINT_LOG"
done
printf '\n' >>"$OPK_ENTRYPOINT_LOG"
EOF
chmod +x "$KIT/fake-child.sh"

for rel in install-global.sh install.sh doctor.sh verify.sh; do
  cp "$KIT/fake-child.sh" "$KIT/$rel"
  chmod +x "$KIT/$rel"
done
cp "$KIT/fake-child.sh" "$KIT/scripts/install-fullstack-profile.sh"
chmod +x "$KIT/scripts/install-fullstack-profile.sh"

ok() {
  printf '  [ok]   %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

expect_nonzero() {
  local label="$1" outfile="$2"
  shift 2
  local rc=0
  if "$@" >"$outfile" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  if ((rc != 0)); then
    ok "$label"
  else
    fail "$label (unexpected exit 0)"
  fi
}

expect_zero() {
  local label="$1" outfile="$2"
  shift 2
  local rc=0
  if "$@" >"$outfile" 2>&1; then
    rc=0
  else
    rc=$?
  fi
  if ((rc == 0)); then
    ok "$label"
  else
    fail "$label (exit $rc; output=$(cat "$outfile"))"
  fi
}

no_children() {
  local label="$1"
  if [[ ! -s "$LOG" ]]; then
    ok "$label"
  else
    fail "$label (child log: $(cat "$LOG"))"
  fi
}

run_env() {
  env \
    HOME="$TEST_HOME" \
    PATH="/usr/bin:/bin" \
    OPK_ENTRYPOINT_LOG="$LOG" \
    "$@"
}

printf 'installer entrypoint contract\n'

: >"$LOG"
expect_nonzero "bootstrap without action fails closed" "$ROOT/bootstrap-none.out" \
  run_env bash "$KIT/bootstrap.sh"
grep -qF 'Cần chọn action rõ ràng' "$ROOT/bootstrap-none.out" \
  && ok "bootstrap explains explicit action requirement" \
  || fail "bootstrap explains explicit action requirement"
no_children "bootstrap without action invokes no child"

: >"$LOG"
expect_nonzero "bootstrap --yes alone is not an action" "$ROOT/bootstrap-yes.out" \
  run_env bash "$KIT/bootstrap.sh" --yes
no_children "bootstrap --yes alone invokes no child"

: >"$LOG"
expect_nonzero "bootstrap --dry-run alone is not an action" "$ROOT/bootstrap-dry.out" \
  run_env bash "$KIT/bootstrap.sh" --dry-run
no_children "bootstrap --dry-run alone invokes no child"

: >"$LOG"
expect_zero "bootstrap explicit --global --yes succeeds" "$ROOT/bootstrap-global.out" \
  run_env bash "$KIT/bootstrap.sh" --global --yes
if grep -qxF $'install-global.sh\t--yes' "$LOG"; then
  ok "bootstrap forwards explicit global + --yes through setup to installer"
else
  fail "bootstrap forwards explicit global + --yes through setup to installer (log=$(cat "$LOG"))"
fi

: >"$LOG"
expect_nonzero "setup --yes alone is not an action" "$ROOT/setup-yes.out" \
  run_env bash "$KIT/setup.sh" --yes
no_children "setup --yes alone invokes no child"

: >"$LOG"
expect_nonzero "setup --dry-run alone is not an action" "$ROOT/setup-dry.out" \
  run_env bash "$KIT/setup.sh" --dry-run
no_children "setup --dry-run alone invokes no child"

: >"$LOG"
if printf '0\n' | env \
    HOME="$TEST_HOME" \
    PATH="/usr/bin:/bin" \
    OPK_ENTRYPOINT_LOG="$LOG" \
    bash "$KIT/setup.sh" >"$ROOT/setup-menu.out" 2>&1; then
  ok "bare setup keeps interactive menu"
else
  fail "bare setup keeps interactive menu"
fi
no_children "choosing setup menu exit invokes no child"

: >"$LOG"
expect_zero "setup --fullstack --yes succeeds in safe project" "$ROOT/setup-fullstack.out" \
  bash -c '
    cd "$1"
    env HOME="$2" PATH="/usr/bin:/bin" OPK_ENTRYPOINT_LOG="$3" \
      bash "$4/setup.sh" --fullstack --yes
  ' _ "$PROJECT" "$TEST_HOME" "$LOG" "$KIT"
if grep -qxF $'install-fullstack-profile.sh\t--yes' "$LOG"; then
  ok "setup forwards --yes to fullstack child"
else
  fail "setup forwards --yes to fullstack child (log=$(cat "$LOG"))"
fi

: >"$LOG"
expect_zero "setup --all --yes succeeds with fake children" "$ROOT/setup-all.out" \
  bash -c '
    cd "$1"
    env HOME="$2" PATH="/usr/bin:/bin" OPK_ENTRYPOINT_LOG="$3" \
      bash "$4/setup.sh" --all --yes
  ' _ "$PROJECT" "$TEST_HOME" "$LOG" "$KIT"
if grep -qxF $'install-global.sh\t--yes' "$LOG" && \
   grep -qxF $'install-fullstack-profile.sh\t--yes' "$LOG"; then
  ok "setup --all forwards --yes to prompt-capable children"
else
  fail "setup --all forwards --yes to prompt-capable children (log=$(cat "$LOG"))"
fi

printf '\ninstaller-entrypoints: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
