#!/usr/bin/env bash
# BMAD temp-log lifecycle tests.
#
# A failed safe publish must keep the diagnostic temp log (mode 600) instead
# of printing a path that has already been deleted. Both install and update are
# exercised with fake node/npx/uv; no network or real BMAD install is used.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$KIT_DIR/install.sh"
UPDATE="$KIT_DIR/update-bmad.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/opk-bmad-log-test.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

FAKE_BIN="$TMP/fake-bin"
mkdir -p "$FAKE_BIN"

cat >"$FAKE_BIN/node" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "-p" ]]; then
  printf '20.12.0\n'
  exit 0
fi
printf 'fake node only supports -p in this test\n' >&2
exit 2
EOF

cat >"$FAKE_BIN/uv" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
  printf 'uv 0.5.0\n'
  exit 0
fi
printf 'fake uv only supports --version in this test\n' >&2
exit 2
EOF

cat >"$FAKE_BIN/npx" <<'EOF'
#!/usr/bin/env bash
printf 'BMAD_FAKE_LOG_MARKER:%s\n' "${OPK_BMAD_TEST_MARKER:-missing}"
printf 'BMAD fake stderr for diagnostics\n' >&2
exit 0
EOF

chmod 755 "$FAKE_BIN/node" "$FAKE_BIN/uv" "$FAKE_BIN/npx"
TEST_PATH="$FAKE_BIN:$PATH"

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

extract_temp_log() {
  sed -n 's/^.*Log tạm được giữ lại (mode 600): //p' "$1" | tail -n 1
}

check_preserved_log() {
  local label="$1" output="$2" marker="$3" path mode
  path="$(extract_temp_log "$output")"

  check "$label: preserved temp path reported" test -n "$path"
  if [[ -z "$path" ]]; then
    return
  fi

  check "$label: temp log still exists" test -f "$path"
  if [[ -f "$path" ]]; then
    mode="$(stat -c '%a' "$path")"
    check "$label: temp log mode is 600" test "$mode" = "600"
    check "$label: temp log keeps BMAD stdout" \
      grep -qF "BMAD_FAKE_LOG_MARKER:$marker" "$path"
    check "$label: temp log keeps BMAD stderr" \
      grep -qF "BMAD fake stderr for diagnostics" "$path"
    rm -f -- "$path"
  fi
}

printf 'BMAD temp-log lifecycle\n'

# ---------------------------------------------------------------------------
# update-bmad.sh: seed the published log as a symlink so opk_safe_io refuses
# it. The external referent must remain untouched, and the temp log must stay.
# ---------------------------------------------------------------------------
UP="$TMP/update-project"
mkdir -p "$UP"
printf '{"model":"fixture/update"}\n' >"$UP/opencode.json"
UP_SENTINEL="$TMP/update-sentinel.txt"
printf 'update-sentinel\n' >"$UP_SENTINEL"
ln -s "$UP_SENTINEL" "$UP/.opencode-power-bmad-update.log"

UP_OUT="$TMP/update.out"
UP_RC=0
(
  cd "$UP"
  PATH="$TEST_PATH" \
    OPK_BMAD_TEST_MARKER=update \
    bash "$UPDATE" --yes
) >"$UP_OUT" 2>&1 || UP_RC=$?

check "update: unsafe log destination fails" test "$UP_RC" -ne 0
check "update: publish failure is explained" \
  grep -qF "không publish được BMAD log qua safe write" "$UP_OUT"
check "update: symlink referent untouched" \
  grep -qxF "update-sentinel" "$UP_SENTINEL"
check_preserved_log "update" "$UP_OUT" "update"

# ---------------------------------------------------------------------------
# install.sh: same attack/failure condition. Test mode explicitly allows the
# /tmp fixture as a project target. Fake BMAD succeeds; only safe log publish
# is expected to fail.
# ---------------------------------------------------------------------------
IN="$TMP/install-project"
mkdir -p "$IN"
IN_SENTINEL="$TMP/install-sentinel.txt"
printf 'install-sentinel\n' >"$IN_SENTINEL"
ln -s "$IN_SENTINEL" "$IN/.opencode-power-bmad-install.log"

IN_OUT="$TMP/install.out"
IN_RC=0
(
  cd "$IN"
  PATH="$TEST_PATH" \
    OPK_TEST_MODE=1 \
    OPK_ALLOW_DIR="$IN" \
    OPK_BMAD_TEST_MARKER=install \
    bash "$INSTALL"
) >"$IN_OUT" 2>&1 || IN_RC=$?

check "install: unsafe log destination fails" test "$IN_RC" -ne 0
check "install: publish failure is explained" \
  grep -qF "Không publish được BMAD log qua safe write" "$IN_OUT"
check "install: symlink referent untouched" \
  grep -qxF "install-sentinel" "$IN_SENTINEL"
check_preserved_log "install" "$IN_OUT" "install"

printf '\nBMAD temp-log lifecycle: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
