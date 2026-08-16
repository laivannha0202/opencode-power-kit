#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
cleanup() { [[ ! -d "$TMP" ]] || rm -r -- "$TMP"; }
trap cleanup EXIT

HOME_FIX="$TMP/home"
KIT_DIR="$TMP/kit"
mkdir -p "$KIT_DIR/bin" "$KIT_DIR/opencode-global" "$KIT_DIR/templates"
cp "$SOURCE_DIR/install-global.sh" "$SOURCE_DIR/install.sh" "$SOURCE_DIR/VERSION" "$KIT_DIR/"
cp -a "$SOURCE_DIR/bin/." "$KIT_DIR/bin/"
cp -a "$SOURCE_DIR/scripts" "$KIT_DIR/"
cp -a "$SOURCE_DIR/templates/." "$KIT_DIR/templates/"
cp -a "$SOURCE_DIR/opencode-global/agents" "$SOURCE_DIR/opencode-global/commands" \
  "$SOURCE_DIR/opencode-global/skills" "$KIT_DIR/opencode-global/"
mkdir -p "$HOME_FIX/.config/opencode/agents"
cat >"$HOME_FIX/.config/opencode/opencode.json" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "fixture/model",
  "provider": {"fixture": {"options": {"custom": true}}},
  "mcp": {"fixture": {"type": "local", "command": ["fixture-mcp"]}},
  "formatter": {"fixture": {"disabled": true}},
  "lsp": {"fixture": {"disabled": true}},
  "plugin": ["fixture-plugin"],
  "custom_key": "keep-me"
}
EOF
printf '%s\n' 'custom agent - preserve me' >"$HOME_FIX/.config/opencode/agents/build-strong.md"
cat >"$HOME_FIX/.bashrc" <<EOF
export OPENCODE_CONFIG_DIR="$HOME_FIX/custom-outside-marker"
# >>> opencode-power-kit-global
export OPK_KIT_DIR="/old/checkout"
export OPENCODE_CONFIG_DIR="\$OPK_KIT_DIR/opencode-global"
# <<< opencode-power-kit-global
# >>> opencode-power-kit-path
export PATH="\$HOME/.local/bin:\$PATH"
# <<< opencode-power-kit-path
export KEEP_USER_LINE=yes
EOF

before="$(git -C "$SOURCE_DIR" status --porcelain=v1 --untracked-files=all)"
HOME="$HOME_FIX" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null
after="$(git -C "$SOURCE_DIR" status --porcelain=v1 --untracked-files=all)"
[[ "$before" == "$after" ]] || { echo 'source tree changed' >&2; exit 1; }

python3 - "$HOME_FIX/.config/opencode/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["model"] == "fixture/model"
assert "fixture" in d["provider"] and "fixture" in d["mcp"]
assert "fixture" in d["formatter"] and "fixture" in d["lsp"]
assert d["custom_key"] == "keep-me"
assert "fixture-plugin" in d["plugin"]
assert d["permission"]["edit"] == "allow"
assert d["permission"]["external_directory"] == "deny"
assert d["compaction"]["prune"] is True
assert "node_modules/**" in d["watcher"]["ignore"]
assert d["default_agent"] == "opk-main"
assert d["subagent_depth"] == 1
PY

grep -q '^custom agent - preserve me$' "$HOME_FIX/.config/opencode/agents/build-strong.md"
[[ -f "$HOME_FIX/.config/opencode/agents/api-strong.md" ]]
[[ -f "$HOME_FIX/.config/opencode/agents/opk-main.md" ]]
[[ -f "$HOME_FIX/.config/opencode/plugins/opk-safety-guard.js" ]]
[[ -f "$HOME_FIX/.config/opencode/plugins/opk-token-guard.js" ]]
[[ -f "$HOME_FIX/.config/opencode/.opk-managed-assets.json" ]]
grep -q '^export KEEP_USER_LINE=yes$' "$HOME_FIX/.bashrc"
grep -q "^export OPENCODE_CONFIG_DIR=\"$HOME_FIX/custom-outside-marker\"$" "$HOME_FIX/.bashrc"
managed_block="$(awk '/^# >>> opencode-power-kit-global$/{on=1} on{print} /^# <<< opencode-power-kit-global$/{exit}' "$HOME_FIX/.bashrc")"
if grep -q 'OPENCODE_CONFIG_DIR' <<<"$managed_block"; then
  echo 'stale OPENCODE_CONFIG_DIR remained inside managed block' >&2
  exit 1
fi

backup_count="$(printf '%s\n' "$HOME_FIX"/.opencode-power-kit-backup-* | wc -l)"
[[ "$backup_count" -ge 1 ]]

first_hash="$(sha256sum "$HOME_FIX/.config/opencode/opencode.json" "$HOME_FIX/.bashrc")"
HOME="$HOME_FIX" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null
second_hash="$(sha256sum "$HOME_FIX/.config/opencode/opencode.json" "$HOME_FIX/.bashrc")"
[[ "$first_hash" == "$second_hash" ]]
[[ "$(grep -c '^# >>> opencode-power-kit-path$' "$HOME_FIX/.bashrc")" -eq 1 ]]

# No explicit mode defaults a new machine to Safe Mode, not unattended Power Mode.
SAFE_HOME="$TMP/safe-home"
mkdir -p "$SAFE_HOME"
HOME="$SAFE_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes >/dev/null
python3 - "$SAFE_HOME/.config/opencode/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["permission"]["edit"] == "ask"
assert d["permission"]["bash"]["*"] == "ask"
assert d["permission"]["external_directory"] == "deny"
assert d["default_agent"] == "opk-main"
assert d["subagent_depth"] == 1
PY

# A broken/symlinked config target is rejected and its referent is unchanged.
LINK_HOME="$TMP/link-home"
mkdir -p "$LINK_HOME/.config" "$TMP/outside-global"
printf '{"sentinel":"unchanged"}\n' >"$TMP/outside-global/opencode.json"
ln -s "$TMP/outside-global" "$LINK_HOME/.config/opencode"
if HOME="$LINK_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null 2>&1; then
  echo 'symlinked global config directory was accepted' >&2
  exit 1
fi
grep -q '^\{"sentinel":"unchanged"\}$' "$TMP/outside-global/opencode.json"

# JSONC comments fail closed by default and normalize only with an explicit flag.
JSONC_HOME="$TMP/jsonc-home"
mkdir -p "$JSONC_HOME/.config/opencode"
cat >"$JSONC_HOME/.config/opencode/opencode.json" <<'EOF'
{
  // user model comment
  "model": "fixture/model",
  "url": "https://example.com/path",
  "literal": "/* not a comment */"
}
EOF
cp "$JSONC_HOME/.config/opencode/opencode.json" "$TMP/global-jsonc.before"
if HOME="$JSONC_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null 2>&1; then
  echo 'global JSONC was normalized without explicit consent' >&2
  exit 1
fi
cmp -s "$JSONC_HOME/.config/opencode/opencode.json" "$TMP/global-jsonc.before"
HOME="$JSONC_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power --normalize-jsonc >/dev/null
python3 - "$JSONC_HOME/.config/opencode/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["model"] == "fixture/model"
assert d["url"] == "https://example.com/path"
assert d["literal"] == "/* not a comment */"
assert d["permission"]["edit"] == "allow"
PY
shopt -s nullglob
jsonc_backups=("$JSONC_HOME"/.opencode-power-kit-backup-*/.config/opencode/opencode.json)
shopt -u nullglob
jsonc_backup_match=false
for jsonc_backup in "${jsonc_backups[@]}"; do
  cmp -s "$jsonc_backup" "$TMP/global-jsonc.before" && jsonc_backup_match=true
done
[[ "$jsonc_backup_match" == true ]]

# Concurrent installers serialize all config, asset, manifest, RC, and shim writes.
CONCURRENT_HOME="$TMP/concurrent-home"
mkdir -p "$CONCURRENT_HOME"
HOME="$CONCURRENT_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null & first_pid=$!
HOME="$CONCURRENT_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null & second_pid=$!
first_rc=0; wait "$first_pid" || first_rc=$?
second_rc=0; wait "$second_pid" || second_rc=$?
[[ "$first_rc:$second_rc" == "0:0" ]]
python3 - "$CONCURRENT_HOME/.config/opencode/.opk-managed-assets.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["version"] == 1 and isinstance(d["assets"], dict) and d["assets"]
PY
[[ -f "$CONCURRENT_HOME/.config/opencode/.opk-install.lock" ]]
[[ ! -L "$CONCURRENT_HOME/.config/opencode/.opk-install.lock" ]]
[[ "$(grep -c '^# >>> opencode-power-kit-global$' "$CONCURRENT_HOME/.bashrc")" -eq 1 ]]
if compgen -G "$CONCURRENT_HOME/.config/opencode/.*.tmp.*" >/dev/null; then
  echo 'concurrent installer left temporary files' >&2
  exit 1
fi

# Dry-run is read-only even when the target config directory does not exist.
DRY_HOME="$TMP/dry-home"
mkdir -p "$DRY_HOME"
HOME="$DRY_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --dry-run --mode power >/dev/null
[[ ! -e "$DRY_HOME/.config" ]]

# A late RC failure rolls back config/assets/manifest/shim while retaining recovery backups.
ROLLBACK_HOME="$TMP/rollback-home"
mkdir -p "$ROLLBACK_HOME/.config/opencode"
printf '{"model":"fixture/original","custom":"keep"}\n' >"$ROLLBACK_HOME/.config/opencode/opencode.json"
printf '# >>> opencode-power-kit-global\nmalformed marker\n' >"$ROLLBACK_HOME/.bashrc"
cp "$ROLLBACK_HOME/.config/opencode/opencode.json" "$TMP/rollback-config.before"
cp "$ROLLBACK_HOME/.bashrc" "$TMP/rollback-bashrc.before"
if HOME="$ROLLBACK_HOME" SHELL=/bin/bash bash "$KIT_DIR/install-global.sh" --yes --mode power >/dev/null 2>&1; then
  echo 'late RC failure unexpectedly succeeded' >&2
  exit 1
fi
cmp -s "$ROLLBACK_HOME/.config/opencode/opencode.json" "$TMP/rollback-config.before"
cmp -s "$ROLLBACK_HOME/.bashrc" "$TMP/rollback-bashrc.before"
[[ ! -e "$ROLLBACK_HOME/.config/opencode/.opk-managed-assets.json" ]]
[[ ! -e "$ROLLBACK_HOME/.local/bin/opk" ]]
shopt -s nullglob
rollback_assets=("$ROLLBACK_HOME/.config/opencode/agents/"*.md)
rollback_backups=("$ROLLBACK_HOME"/.opencode-power-kit-backup-*)
shopt -u nullglob
[[ "${#rollback_assets[@]}" -eq 0 ]]
[[ "${#rollback_backups[@]}" -ge 1 ]]

printf 'test-global-installer: OK\n'
