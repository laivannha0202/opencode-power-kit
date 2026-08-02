#!/usr/bin/env bash
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECKER="$KIT_DIR/scripts/opk-permissions.py"
SOURCE_BEFORE="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
TMP="$(mktemp -d)"
trap 'rm -r -- "$TMP"' EXIT

PASS=0
FAIL=0

ok() {
  printf '  [ok]   %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  [FAIL] %s\n' "$1" >&2
  FAIL=$((FAIL + 1))
}

expect_mode() {
  local name="$1" expected="$2" fixture="$3" project output mode
  project="$TMP/projects/$name"
  mkdir -p "$project"
  cp "$fixture" "$project/resolved.json"
  if output="$(PATH="$TMP/bin:$PATH" python3 "$CHECKER" --project-dir "$project" --json 2>&1)"; then
    :
  fi
  mode="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["mode"])' <<<"$output" 2>/dev/null || true)"
  if [[ "$mode" == "$expected" ]]; then
    ok "$name => $expected"
  else
    fail "$name => ${mode:-unparseable} (want $expected): $output"
  fi
}

mkdir -p "$TMP/bin" "$TMP/projects" "$TMP/fixtures"
cat >"$TMP/bin/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --version) printf '1.18.10\n' ;;
  --help) printf 'Usage: opencode [--auto]\n' ;;
  debug)
    [[ "${2:-}" == config && "${3:-}" == --pure ]]
    printf '%s\n' "$PWD" >"${OPK_TEST_CWD_FILE:?}"
    cat "$PWD/resolved.json"
    ;;
  *) exit 64 ;;
esac
EOF
chmod +x "$TMP/bin/opencode"
export OPK_TEST_CWD_FILE="$TMP/cwd"

python3 - "$KIT_DIR/templates/opencode.power.json" "$KIT_DIR/templates/opencode.safe.json" "$TMP/fixtures" <<'PY'
import copy
import json
import sys
from pathlib import Path

power = json.load(open(sys.argv[1], encoding="utf-8"))
safe = json.load(open(sys.argv[2], encoding="utf-8"))
out = Path(sys.argv[3])

def write(name, value):
    (out / f"{name}.json").write_text(json.dumps(value), encoding="utf-8")

write("power", power)
write("safe", safe)

for key in ("read", "skill", "task"):
    value = copy.deepcopy(power)
    value["permission"][key] = "ask"
    write(f"{key}-ask", value)

for key in ("external_directory", "doom_loop"):
    value = copy.deepcopy(power)
    value["permission"][key] = "ask"
    write(f"{key}-ask", value)

value = copy.deepcopy(power)
value["permission"]["bash"]["*"] = "ask"
write("bash-ask", value)

value = copy.deepcopy(power)
value["agent"] = {"build": {"permission": {"edit": "ask"}}}
write("agent-ask", value)

value = copy.deepcopy(power)
del value["permission"]["bash"]["git reset --hard*"]
write("missing-destructive-deny", value)

value = copy.deepcopy(power)
del value["permission"]["read"]["*.pem"]
write("missing-secret-deny", value)

value = copy.deepcopy(power)
value["permission"]["bash"]["*"] = value["permission"]["bash"].pop("*")
write("deny-before-wildcard", value)

value = copy.deepcopy(power)
value["permission"]["bash"]["rm -rf /tmp/cache"] = "allow"
write("late-narrow-allow", value)

write("invalid-permission", {"permission": ["allow"]})
PY

printf 'Permission classification\n'
expect_mode power POWER "$TMP/fixtures/power.json"
expect_mode safe SAFE "$TMP/fixtures/safe.json"
for fixture in read-ask skill-ask task-ask external_directory-ask doom_loop-ask bash-ask agent-ask missing-destructive-deny missing-secret-deny deny-before-wildcard late-narrow-allow; do
  expect_mode "$fixture" CUSTOM "$TMP/fixtures/$fixture.json"
done
expect_mode invalid-permission BROKEN "$TMP/fixtures/invalid-permission.json"

exact="$TMP/projects/exact-cwd"
mkdir -p "$exact"
cp "$TMP/fixtures/power.json" "$exact/resolved.json"
PATH="$TMP/bin:$PATH" python3 "$CHECKER" --project-dir "$exact" --json >/dev/null
if [[ "$(<"$OPK_TEST_CWD_FILE")" == "$(realpath "$exact")" ]]; then
  ok "debug config runs in exact project directory"
else
  fail "debug config changed project directory"
fi

ln -s "$exact" "$TMP/project-link"
if PATH="$TMP/bin:$PATH" python3 "$CHECKER" --project-dir "$TMP/project-link" --json >/dev/null 2>&1; then
  fail "symlink project path is rejected"
else
  ok "symlink project path is rejected"
fi

if PATH="$TMP/bin:$PATH" python3 "$CHECKER" --project-dir "$exact" --require-power >/dev/null 2>&1; then
  ok "require-power accepts complete Power contract"
else
  fail "require-power rejected complete Power contract"
fi

cp "$TMP/fixtures/agent-ask.json" "$exact/resolved.json"
if PATH="$TMP/bin:$PATH" python3 "$CHECKER" --project-dir "$exact" --require-power >/dev/null 2>&1; then
  fail "require-power rejects agent ask"
else
  ok "require-power rejects agent ask"
fi

printf '\nPermission tests: %d passed, %d failed\n' "$PASS" "$FAIL"
SOURCE_AFTER="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
if [[ "$SOURCE_BEFORE" != "$SOURCE_AFTER" ]]; then
  fail "permission tests changed source tree"
fi
((FAIL == 0))
