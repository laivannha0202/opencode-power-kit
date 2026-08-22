#!/usr/bin/env bash
# Runtime doctor/status regression: marker presence is not enough.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$KIT_DIR/scripts/check-runtime-plugins.mjs"
OPK="$KIT_DIR/bin/opk"
DOCTOR="$KIT_DIR/doctor.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/opk-doctor-runtime.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

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

printf 'doctor/runtime plugin validation\n'

node "$CHECKER" \
  --safety "$KIT_DIR/templates/plugins/opk-safety-guard.js" \
  --token "$KIT_DIR/templates/plugins/opk-token-guard.js" \
  >"$TMP/template-check.out" 2>&1
check "template safety+token plugins load and pass smoke behavior" \
  grep -qF 'RUNTIME_PLUGINS=PASS checked=safety+token' \
  "$TMP/template-check.out"

PROJECT="$TMP/project"
mkdir -p "$PROJECT/.opencode/plugins"
printf '{"permission":"ask"}\n' >"$PROJECT/opencode.json"
cp "$KIT_DIR/templates/plugins/opk-safety-guard.js" \
  "$PROJECT/.opencode/plugins/opk-safety-guard.js"
cp "$KIT_DIR/templates/plugins/opk-token-guard.js" \
  "$PROJECT/.opencode/plugins/opk-token-guard.js"

STATUS_OUT="$TMP/status-valid.out"
STATUS_RC=0
(
  cd "$PROJECT"
  OPK_KIT_DIR="$KIT_DIR" "$OPK" safety-plugin status
) >"$STATUS_OUT" 2>&1 || STATUS_RC=$?
check "safety-plugin status accepts valid runtime plugin" \
  test "$STATUS_RC" -eq 0
check "valid safety-plugin status is INSTALLED" \
  grep -qxF INSTALLED "$STATUS_OUT"

DOCTOR_VALID="$TMP/doctor-valid.out"
DOCTOR_VALID_RC=0
(
  cd "$PROJECT"
  bash "$DOCTOR"
) >"$DOCTOR_VALID" 2>&1 || DOCTOR_VALID_RC=$?
check "doctor accepts valid managed runtime pair" \
  test "$DOCTOR_VALID_RC" -eq 0
check "doctor reports executable project runtime guards" \
  grep -qF 'Project runtime guards load and pass smoke behavior' \
  "$DOCTOR_VALID"

# Keep the marker and the literal hook name, but export a factory with no hook.
# The old marker/grep checks falsely considered this installed/healthy.
python3 - "$PROJECT/.opencode/plugins/opk-safety-guard.js" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
needle = "module.exports = OPKSafetyGuard;"
assert text.count(needle) == 1
p.write_text(
    text.replace(
        needle,
        'module.exports = async () => ({ note: "tool.execute.before" });',
        1,
    ),
    encoding="utf-8",
)
PY

BROKEN_STATUS="$TMP/status-broken.out"
BROKEN_STATUS_RC=0
(
  cd "$PROJECT"
  OPK_KIT_DIR="$KIT_DIR" "$OPK" safety-plugin status
) >"$BROKEN_STATUS" 2>&1 || BROKEN_STATUS_RC=$?
check "marker-preserving broken safety plugin is rejected by status" \
  test "$BROKEN_STATUS_RC" -ne 0
check "broken safety status does not print INSTALLED" \
  bash -c '! grep -qxF INSTALLED "$1"' _ "$BROKEN_STATUS"

BROKEN_DOCTOR="$TMP/doctor-broken-safety.out"
BROKEN_DOCTOR_RC=0
(
  cd "$PROJECT"
  bash "$DOCTOR"
) >"$BROKEN_DOCTOR" 2>&1 || BROKEN_DOCTOR_RC=$?
check "doctor rejects marker-preserving broken safety plugin" \
  test "$BROKEN_DOCTOR_RC" -ne 0
check "doctor explains stale/broken project runtime" \
  grep -Eq 'stale|runtime guard|RUNTIME_PLUGINS=FAIL' "$BROKEN_DOCTOR"

# Restore safety, then break token while retaining its marker. Doctor must
# validate token guard's shell.env hook too.
cp "$KIT_DIR/templates/plugins/opk-safety-guard.js" \
  "$PROJECT/.opencode/plugins/opk-safety-guard.js"
python3 - "$PROJECT/.opencode/plugins/opk-token-guard.js" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
text = p.read_text(encoding="utf-8")
needle = "module.exports = OPKTokenGuard;"
assert text.count(needle) == 1
p.write_text(
    text.replace(
        needle,
        'module.exports = async () => ({ "tool.execute.before": async () => {} });',
        1,
    ),
    encoding="utf-8",
)
PY

BROKEN_TOKEN="$TMP/doctor-broken-token.out"
BROKEN_TOKEN_RC=0
(
  cd "$PROJECT"
  bash "$DOCTOR"
) >"$BROKEN_TOKEN" 2>&1 || BROKEN_TOKEN_RC=$?
check "doctor rejects token guard missing shell.env" \
  test "$BROKEN_TOKEN_RC" -ne 0
check "doctor does not false-green broken token guard" \
  bash -c '! grep -qF "All basic checks passed" "$1"' _ "$BROKEN_TOKEN"

printf '\ndoctor-runtime: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
