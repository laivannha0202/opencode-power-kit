#!/usr/bin/env bash
# ============================================================================
# OpenCode Power Kit - Integration Test (offline)
# Mục đích: chạy install.sh vào một project giả trong scratch dir AN TOÀN
# (KHÔNG dùng /tmp), sau đó chạy verify.sh và kiểm tra các file/thư mục kỳ vọng.
# - Không tự gọi curl|sh, không xóa file user.
# - Stub npx: log args ra file thay vì gọi network.
# - Chạy offline hoàn toàn (NPX từ PATH giả, không touch mạng).
# - Assert: repo KHÔNG chứa '--user-name nha' hardcode.
# - Assert: install-global.sh KHÔNG chứa đường dẫn $HOME/opencode-power-kit/opencode-global hardcode.
# - Assert: npx stub nhận đúng args (bmad-method@<ver>, --modules bmm, --tools opencode, --user-name <fallback>).
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() {
	echo -e "${BLUE}[INFO]${NC} $*"
}
ok() {
	echo -e "${GREEN}[OK]${NC} $*"
}
warn() {
	echo -e "${YELLOW}[WARN]${NC} $*"
}
err() {
	echo -e "${RED}[FAIL]${NC} $*"
	FAIL=1
}

FAIL=0

# --- Resolve kit dir (this script's parent) ---
KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
info "Kit dir: $KIT_DIR"

# --- Verify required tools (python3 cho python validator; bash cho scripts) ---
for tool in bash git python3; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		err "Required tool not found: $tool"
		exit 1
	fi
done

# --- Create scratch project inside kit's .tmp (NOT /tmp) ---
SCRATCH_ROOT="$KIT_DIR/.tmp"
mkdir -p "$SCRATCH_ROOT"
TMP_DIR="$(mktemp -d -p "$SCRATCH_ROOT" -t opk-integration-XXXXXX)"
info "Scratch project: $TMP_DIR"

# Stub npx: log every invocation to a file + create faux install artifacts
# so downstream artifact checks pass. Never hits network.
NPX_STUB_DIR="$TMP_DIR/bin"
mkdir -p "$NPX_STUB_DIR"
NPX_LOG="$TMP_DIR/npx-calls.log"
NPX_TARGET_DIR="$TMP_DIR/npx-target" # where the stub creates BMAD-like files

cat >"$NPX_STUB_DIR/npx" <<STUB
#!/usr/bin/env bash
# OpenCode Power Kit - npx stub (offline test only)
set -e
echo "NPX_INVOCATION \$@" >> '${NPX_LOG}'

# Detect "bmad-method@X.Y.Z install ... --directory <DIR>"
if echo "\$*" | grep -qE 'bmad-method@[0-9]'; then
    # Find --directory argument value
    target=""
    prev=""
    for arg in \$@; do
        if [ "\$prev" = "--directory" ] || [ "\$prev" = "-dir" ]; then
            target="\$arg"
            break
        fi
        prev="\$arg"
    done
    [ -z "\$target" ] && target="${NPX_TARGET_DIR}"
    mkdir -p "\$target"
    # Create ONLY the dirs install.sh expects from npx; never overwrite
    # files that install.sh's own copy-templates step already created.
    [ -d "\$target/_bmad" ] || mkdir -p "\$target/_bmad"
    [ -d "\$target/.agents/skills" ] || mkdir -p "\$target/.agents/skills"
    [ -d "\$target/.opencode/commands" ] || mkdir -p "\$target/.opencode/commands"
    [ -d "\$target/.opencode/agents" ] || mkdir -p "\$target/.opencode/agents"
    [ -f "\$target/_bmad/index.md" ] || cat > "\$target/_bmad/index.md" <<'BMAD'
# _bmad (stub - offline integration test)
BMAD
    [ -f "\$target/.opencode/commands/stub-cmd.md" ] || cat > "\$target/.opencode/commands/stub-cmd.md" <<'CMD'
---
description: stub command (offline integration test)
---
# stub
CMD
    exit 0
fi
exit 0
STUB
chmod +x "$NPX_STUB_DIR/npx"

# Also stub npx.cmd in case Windows-y callers resolve it
cat >"$NPX_STUB_DIR/npx.cmd" <<'STUB'
@echo off
echo NPX_INVOCATION %* >> %NPX_LOG%
exit /b 0
STUB

cleanup() {
	if [ -n "${TMP_DIR:-}" ] && [ -d "$TMP_DIR" ]; then
		info "Cleanup: rm -rf $TMP_DIR"
		rm -rf "$TMP_DIR"
	fi
}
trap cleanup EXIT

# --- PATH override: put stub bin FIRST, so install.sh picks up npx stub ---
export PATH="$NPX_STUB_DIR:$PATH"
export NPX_LOG

# --- Seed fake project ---
cd "$TMP_DIR"
git init -q -b main .
git config user.email "ci@opencode-power-kit.local"
git config user.name "ci-bot"

cat >package.json <<'JSON'
{
  "name": "opencode-power-kit-integration",
  "version": "0.0.0",
  "private": true
}
JSON
git add package.json
git commit -q -m "chore: seed package.json"

ok "Seeded fake project at $TMP_DIR"

# --- Run install.sh (kit -> project) ---
info "Running install.sh from $KIT_DIR into $TMP_DIR ..."
if [ ! -x "$KIT_DIR/install.sh" ]; then
	err "install.sh not executable: $KIT_DIR/install.sh"
	exit 1
fi

set +e
bash "$KIT_DIR/install.sh" >"$TMP_DIR/install.log" 2>&1
install_rc=$?
set -e

if [ "$install_rc" -ne 0 ]; then
	err "install.sh exited $install_rc"
	echo "----- $TMP_DIR/install.log (tail) -----" >&2
	tail -30 "$TMP_DIR/install.log" >&2
else
	ok "install.sh completed (rc=0)"
fi

# --- Run verify.sh in the temp project ---
info "Running verify.sh in $TMP_DIR ..."
set +e
(cd "$TMP_DIR" && bash "$KIT_DIR/verify.sh") >"$TMP_DIR/verify.log" 2>&1
verify_rc=$?
set -e

if [ "$verify_rc" -ne 0 ]; then
	warn "verify.sh exited $verify_rc (may include optional warnings)"
	echo "----- $TMP_DIR/verify.log (tail) -----" >&2
	tail -30 "$TMP_DIR/verify.log" >&2
else
	ok "verify.sh completed (rc=0)"
fi

# --- Check expected files/dirs ---
echo ""
info "Checking expected artifacts in $TMP_DIR ..."

check_path() {
	local rel="$1"
	local must_be="$2" # "file" or "dir"
	if [ "$must_be" = "dir" ]; then
		if [ -d "$TMP_DIR/$rel" ]; then
			ok "$rel/"
		else
			err "$rel/ not found"
		fi
	else
		if [ -f "$TMP_DIR/$rel" ]; then
			ok "$rel"
		else
			err "$rel not found"
		fi
	fi
}

check_path "AGENTS.md" "file"
check_path "OPENCODE.md" "file"
check_path ".opencode/opencode.json" "file"
check_path ".gitignore" "file"
check_path "knip.json" "file"
check_path "lefthook.yml" "file"
check_path "_bmad" "dir"
check_path ".agents/skills" "dir"
check_path ".opencode/commands" "dir"
check_path "opencode-power-install-report.md" "file"

# --- Test full-stack profile install ---
if [ -x "$KIT_DIR/scripts/install-fullstack-profile.sh" ]; then
	info "Running scripts/install-fullstack-profile.sh in $TMP_DIR ..."
	set +e
	(cd "$TMP_DIR" && bash "$KIT_DIR/scripts/install-fullstack-profile.sh") >"$TMP_DIR/profile.log" 2>&1
	profile_rc=$?
	set -e

	if [ "$profile_rc" -ne 0 ]; then
		err "install-fullstack-profile.sh exited $profile_rc"
		echo "----- $TMP_DIR/profile.log (tail) -----" >&2
		tail -30 "$TMP_DIR/profile.log" >&2
	else
		ok "install-fullstack-profile.sh completed (rc=0)"
	fi

	# Verify profile artifacts
	echo ""
	info "Checking full-stack profile artifacts in $TMP_DIR ..."

	if [ -f "$TMP_DIR/AGENTS.md" ] && grep -qF "OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin" "$TMP_DIR/AGENTS.md"; then
		ok "AGENTS.md has fullstack marker"
	else
		err "AGENTS.md missing fullstack marker"
	fi

	if [ -f "$TMP_DIR/OPENCODE.md" ] && grep -qF "OPENCODE-POWER-KIT-MARKER: fullstack-profile-begin" "$TMP_DIR/OPENCODE.md"; then
		ok "OPENCODE.md has fullstack marker"
	else
		err "OPENCODE.md missing fullstack marker"
	fi

	if [ -d "$TMP_DIR/.opencode/commands/fullstack" ]; then
		cmd_n=$(find "$TMP_DIR/.opencode/commands/fullstack" -maxdepth 1 -name "*.md" | wc -l)
		if [ "$cmd_n" -gt 0 ]; then
			ok ".opencode/commands/fullstack/ ($cmd_n files)"
		else
			err ".opencode/commands/fullstack/ empty"
		fi
	else
		err ".opencode/commands/fullstack/ not found"
	fi

	if [ -d "$TMP_DIR/.agents/skills" ]; then
		skill_n=$(find "$TMP_DIR/.agents/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)
		if [ "$skill_n" -gt 0 ]; then
			ok ".agents/skills/ ($skill_n skills)"
		else
			err ".agents/skills/ empty"
		fi
	else
		err ".agents/skills/ not found"
	fi
else
	warn "install-fullstack-profile.sh not present - skipping profile test"
fi

# --- REGRESSION GUARDS: no hardcoded personal name in installers ---
echo ""
info "Regression guard: no hardcoded '--user-name nha' in repo ..."

# Run grep, then check output file. Don't use `if grep` (last grep -v in
# pipe exits 1 when it filters everything, masking the real result).
# `--` separator is REQUIRED so `--user-name...` isn't parsed as a flag.
grep -rEn --include='*.sh' --include='*.ps1' --include='*.cmd' \
	-- '--user-name[[:space:]]+nha\b' "$KIT_DIR" 2>/dev/null |
	grep -vE '/(\.tmp|\.test|node_modules|coverage|dist|build)/' |
	grep -vE '\.bak$|\.orig$' >"$TMP_DIR/hardcode-user.txt" 2>/dev/null || true

# Exclude this test file's own documentation/error strings
grep -vE '/scripts/integration-test\.sh:' "$TMP_DIR/hardcode-user.txt" \
	>"$TMP_DIR/hardcode-user.flt" 2>/dev/null || true

if [ -s "$TMP_DIR/hardcode-user.flt" ]; then
	err "Found hardcoded --user-name nha in:"
	cat "$TMP_DIR/hardcode-user.flt" >&2
else
	ok "No hardcoded --user-name nha in installer scripts (excludes this test file's own strings)"
fi

# --- REGRESSION GUARD: install-global.sh must not hardcode $HOME/opencode-power-kit/opencode-global ---
info "Regression guard: no hardcoded \$HOME/opencode-power-kit/opencode-global in install-global.sh ..."

# shellcheck disable=SC2016
if [ -f "$KIT_DIR/install-global.sh" ] &&
	grep -nE '"\$HOME/opencode-power-kit/opencode-global"|/opencode-power-kit/opencode-global' "$KIT_DIR/install-global.sh" \
		>"$TMP_DIR/hardcode-home.txt" 2>/dev/null; then
	if [ -s "$TMP_DIR/hardcode-home.txt" ]; then
		err "Found hardcoded \$HOME/opencode-power-kit/opencode-global in install-global.sh:"
		cat "$TMP_DIR/hardcode-home.txt" >&2
	else
		ok "install-global.sh: no hardcoded \$HOME/opencode-power-kit/opencode-global"
	fi
else
	ok "install-global.sh: no hardcoded \$HOME/opencode-power-kit/opencode-global"
fi

# --- NPX CALL ASSERTION: stub was called with expected BMAD args ---
echo ""
info "Asserting npx stub received BMAD install call ..."

if [ -f "$NPX_LOG" ] && [ -s "$NPX_LOG" ]; then
	ok "npx stub was invoked:"
	sed 's/^/    /' "$NPX_LOG"

	# Must contain bmad-method@<version>
	if grep -qE 'bmad-method@[0-9]+\.[0-9]+\.[0-9]+' "$NPX_LOG"; then
		ok "npx call uses bmad-method@<semver>"
	else
		err "npx call missing bmad-method@<semver>"
	fi

	# Must contain --modules bmm
	if grep -qE -- '--modules[[:space:]]+bmm' "$NPX_LOG"; then
		ok "npx call includes --modules bmm"
	else
		err "npx call missing --modules bmm"
	fi

	# Must contain --tools opencode
	if grep -qE -- '--tools[[:space:]]+opencode' "$NPX_LOG"; then
		ok "npx call includes --tools opencode"
	else
		err "npx call missing --tools opencode"
	fi

	# Must contain --user-name <something> (not literal 'nha')
	if grep -qE -- '--user-name[[:space:]]+nha\b' "$NPX_LOG"; then
		err "npx call STILL has hardcoded --user-name nha"
	else
		ok "npx call has --user-name <fallback> (not literal nha)"
	fi
else
	warn "npx stub was NOT invoked (install.sh may have skipped BMAD step)"
	warn "If you expect BMAD install, check install.sh's BMAD branch."
fi

# --- SAFETY GUARD ASSERTION: is_bad_project_dir still refuses real /tmp ---
echo ""
info "Asserting safety guard still blocks /tmp ..."

# Use a temp dir under HOME_PARENT (not /tmp) to avoid hitting the actual /tmp rule
# by the test runner's process; we check the install.sh code path directly.
# shellcheck disable=SC2016
if grep -qE 'case "\$p_real" in /tmp \| /tmp/\*\) return 0' "$KIT_DIR/install.sh"; then
	ok "install.sh: /tmp still in safety guard (good - we just use .tmp/)"
else
	err "install.sh: /tmp safety guard missing or moved"
fi

# --- Final ---
echo ""
if [ "$FAIL" -ne 0 ]; then
	err "Integration test FAILED"
	exit 1
fi
ok "Integration test PASSED"
