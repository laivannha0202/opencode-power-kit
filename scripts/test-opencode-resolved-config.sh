#!/usr/bin/env bash
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OPENCODE_BIN="$(command -v opencode || true)"
[[ -n "$OPENCODE_BIN" ]] || { echo 'test-opencode-resolved-config: opencode is required' >&2; exit 1; }

TEST_ROOT="$(mktemp -d "${HOME}/.opk-resolved-test.XXXXXX")"
cleanup() {
  case "${TEST_ROOT:-}" in "${HOME}"/.opk-resolved-test.*) [[ ! -d "$TEST_ROOT" ]] || rm -r -- "$TEST_ROOT" ;; esac
}
trap cleanup EXIT

TEST_HOME="$TEST_ROOT/home"
TEST_PROJECT="$TEST_ROOT/project"
mkdir -p "$TEST_HOME/.config/opencode" "$TEST_PROJECT/.opencode"
printf '# resolved config fixture\n' >"$TEST_PROJECT/AGENTS.md"
printf '{"name":"opk-resolved-fixture","private":true}\n' >"$TEST_PROJECT/package.json"
cat >"$TEST_HOME/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "small_model": "fixture/small"
}
EOF
cat >"$TEST_PROJECT/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "fixture/model",
  "provider": {"fixture": {"options": {"custom": true}}},
  "mcp": {"fixture": {"type": "local", "command": ["fixture-mcp"], "enabled": false}},
  "plugin": ["fixture-plugin"],
  "instructions": ["CUSTOM.md", "CUSTOM.md"]
}
EOF
printf '# custom instruction\n' >"$TEST_PROJECT/CUSTOM.md"

source_before="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
env -u OPENCODE_CONFIG -u OPENCODE_CONFIG_DIR -u OPENCODE_CONFIG_CONTENT \
  HOME="$TEST_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null
(
  cd "$TEST_PROJECT"
  python3 "$KIT_DIR/scripts/merge-opk-project.py" --project-dir "$TEST_PROJECT" >/dev/null
  OPK_KIT_DIR="$KIT_DIR" "$KIT_DIR/bin/opk" mode power >/dev/null
  env -u OPENCODE_CONFIG -u OPENCODE_CONFIG_DIR -u OPENCODE_CONFIG_CONTENT \
    HOME="$TEST_HOME" "$OPENCODE_BIN" debug config --pure >"$TEST_ROOT/resolved.json"
)
source_after="$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=all)"
[[ "$source_before" == "$source_after" ]] || { echo 'source tree changed during resolved-config test' >&2; exit 1; }

python3 - "$TEST_ROOT/resolved.json" "$TEST_PROJECT/opencode.json" <<'PY'
import json, sys
resolved = json.load(open(sys.argv[1], encoding="utf-8"))
project = json.load(open(sys.argv[2], encoding="utf-8"))
perm = resolved["permission"]
assert perm["edit"] == "allow"
assert perm["bash"]["*"] == "allow"
assert perm["task"] == "allow" and perm["skill"] == "allow"
assert perm["external_directory"] == "deny"
assert perm["doom_loop"] == "deny"
for pattern in ("rm -rf*", "git reset --hard*", "git clean -f*", "git push --force*", "*DROP TABLE*"):
    assert perm["bash"][pattern] == "deny", pattern
for pattern in ("*.env", "*.env.*", "*secret*", "*.pem", "*.key"):
    assert perm["read"][pattern] == "deny", pattern
assert resolved["model"] == "fixture/model"
assert resolved["small_model"] == "fixture/small"
assert "fixture" in resolved["provider"] and "fixture" in resolved["mcp"]
assert "fixture-plugin" in resolved["plugin"]
assert project["instructions"] == ["CUSTOM.md"]
assert "AGENTS.md" not in project["instructions"] and "OPENCODE.md" not in project["instructions"]
assert resolved["compaction"]["auto"] is True and resolved["compaction"]["prune"] is True
assert "node_modules/**" in resolved["watcher"]["ignore"]
assert not any("ask" in json.dumps(agent.get("permission", {})) for agent in resolved.get("agent", {}).values())
assert resolved["agent"]["build-strong"].get("permission", {}) == {}
PY

[[ ! -e "$TEST_PROJECT/.opencode/opencode.json" ]]
printf 'test-opencode-resolved-config: OK (OpenCode %s)\n' "$($OPENCODE_BIN --version)"
