#!/usr/bin/env bash
# E2E safety tests for the transactional full-stack profile installer.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$KIT_DIR/scripts/install-fullstack-profile.sh"
TMP="$(mktemp -d)"
cleanup() { [[ ! -d "$TMP" ]] || rm -r -- "$TMP"; }
trap cleanup EXIT

pass=0
fail=0

check() {
  local name="$1"
  if shift && "$@"; then
    echo "  [ok]   $name"
    pass=$((pass + 1))
  else
    echo "  [FAIL] $name"
    fail=$((fail + 1))
  fi
}

run_install() {
  local project="$1"
  (
    cd "$project"
    OPK_TEST_MODE=1 bash "$INSTALLER" --yes >/dev/null
  )
}

make_project() {
  local project="$1"
  mkdir -p "$project"
  printf '{"name":"fixture","private":true}\n' >"$project/package.json"
  printf '# User AGENTS\nKEEP-AGENTS\n' >"$project/AGENTS.md"
  printf '# User OPENCODE\nKEEP-OPENCODE\n' >"$project/OPENCODE.md"
}

# ---------------------------------------------------------------------------
# Normal install + idempotency
# ---------------------------------------------------------------------------
P="$TMP/normal"
make_project "$P"
run_install "$P"

grep -qF 'KEEP-AGENTS' "$P/AGENTS.md"
check "normal install preserves AGENTS user content" test "$?" -eq 0
grep -qF 'KEEP-OPENCODE' "$P/OPENCODE.md"
check "normal install preserves OPENCODE user content" test "$?" -eq 0

[[ "$(grep -cF '<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->' "$P/AGENTS.md")" -eq 1 ]]
check "AGENTS managed block exists exactly once" test "$?" -eq 0
[[ "$(grep -cF '<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->' "$P/OPENCODE.md")" -eq 1 ]]
check "OPENCODE managed block exists exactly once" test "$?" -eq 0

command_count="$(find "$P/.opencode/commands/fullstack" -maxdepth 1 -type f -name '*.md' | wc -l)"
[[ "$command_count" -gt 0 ]]
check "fullstack commands installed" test "$?" -eq 0

skill_count="$(find "$P/.agents/skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | wc -l)"
[[ "$skill_count" -gt 0 ]]
check "profile skills installed" test "$?" -eq 0
check "profile report installed" test -f "$P/FULLSTACK_PROFILE_REPORT.md"

run_install "$P"
[[ "$(grep -cF '<!-- OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin -->' "$P/AGENTS.md")" -eq 1 ]]
check "second run does not duplicate AGENTS marker" test "$?" -eq 0

# ---------------------------------------------------------------------------
# AGENTS symlink: must fail without touching referent.
# ---------------------------------------------------------------------------
S="$TMP/symlink-agents"
mkdir -p "$S"
printf '{"name":"fixture"}\n' >"$S/package.json"
printf 'OUTSIDE-AGENTS\n' >"$TMP/outside-agents"
ln -s "$TMP/outside-agents" "$S/AGENTS.md"
printf '# User OPENCODE\n' >"$S/OPENCODE.md"

if run_install "$S"; then
  check "AGENTS symlink is rejected" false
else
  check "AGENTS symlink is rejected" true
fi
grep -q '^OUTSIDE-AGENTS$' "$TMP/outside-agents"
check "AGENTS symlink referent unchanged" test "$?" -eq 0

# ---------------------------------------------------------------------------
# Command destination symlink: later failure must roll back earlier appends.
# ---------------------------------------------------------------------------
C="$TMP/symlink-command-dir"
make_project "$C"
mkdir -p "$C/.opencode/commands" "$TMP/outside-commands"
ln -s "$TMP/outside-commands" "$C/.opencode/commands/fullstack"
before_agents="$(sha256sum "$C/AGENTS.md" | awk '{print $1}')"
before_opencode="$(sha256sum "$C/OPENCODE.md" | awk '{print $1}')"

if run_install "$C"; then
  check "command directory symlink is rejected" false
else
  check "command directory symlink is rejected" true
fi
after_agents="$(sha256sum "$C/AGENTS.md" | awk '{print $1}')"
after_opencode="$(sha256sum "$C/OPENCODE.md" | awk '{print $1}')"
check "command-dir failure rolls back AGENTS" test "$before_agents" = "$after_agents"
check "command-dir failure rolls back OPENCODE" test "$before_opencode" = "$after_opencode"
[[ -z "$(find "$TMP/outside-commands" -mindepth 1 -print -quit)" ]]
check "command-dir symlink referent untouched" test "$?" -eq 0

# ---------------------------------------------------------------------------
# Hardlink target: tx pre-backup rejects aliases before mutation.
# ---------------------------------------------------------------------------
H="$TMP/hardlink-agents"
mkdir -p "$H"
printf '{"name":"fixture"}\n' >"$H/package.json"
printf 'OUTSIDE-HARDLINK\n' >"$TMP/outside-hardlink"
ln "$TMP/outside-hardlink" "$H/AGENTS.md"
printf '# User OPENCODE\n' >"$H/OPENCODE.md"

if run_install "$H"; then
  check "AGENTS hardlink is rejected" false
else
  check "AGENTS hardlink is rejected" true
fi
grep -q '^OUTSIDE-HARDLINK$' "$TMP/outside-hardlink"
check "hardlink referent unchanged" test "$?" -eq 0

# ---------------------------------------------------------------------------
# Report symlink: failure at the final write must roll back the whole tx.
# ---------------------------------------------------------------------------
R="$TMP/report-symlink"
make_project "$R"
printf 'OUTSIDE-REPORT\n' >"$TMP/outside-report"
ln -s "$TMP/outside-report" "$R/FULLSTACK_PROFILE_REPORT.md"
before_agents="$(sha256sum "$R/AGENTS.md" | awk '{print $1}')"
before_opencode="$(sha256sum "$R/OPENCODE.md" | awk '{print $1}')"

if run_install "$R"; then
  check "report symlink is rejected" false
else
  check "report symlink is rejected" true
fi
after_agents="$(sha256sum "$R/AGENTS.md" | awk '{print $1}')"
after_opencode="$(sha256sum "$R/OPENCODE.md" | awk '{print $1}')"
check "report failure rolls back AGENTS" test "$before_agents" = "$after_agents"
check "report failure rolls back OPENCODE" test "$before_opencode" = "$after_opencode"
grep -q '^OUTSIDE-REPORT$' "$TMP/outside-report"
check "report symlink referent unchanged" test "$?" -eq 0
[[ ! -e "$R/.opencode/commands/fullstack" ]]
check "report failure rolls back command tree" test "$?" -eq 0
[[ ! -e "$R/.agents/skills" ]]
check "report failure rolls back skill tree" test "$?" -eq 0

echo
if [[ "$fail" -ne 0 ]]; then
  echo "test-fullstack-installer: FAILED ($fail failures, $pass passed)"
  exit 1
fi
echo "test-fullstack-installer: OK ($pass checks passed)"
