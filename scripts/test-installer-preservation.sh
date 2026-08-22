#!/usr/bin/env bash
# ============================================================================
# test-installer-preservation.sh
#
# Integration test: OPK installer (merge) phải GIỮ NGUYÊN nội dung tùy chỉnh
# của user, thêm OPK managed block ĐÚNG MỘT LẦN, giữ nguyên custom JSON keys,
# backup, và cài safety plugin. Chạy trên fixture temp (KHÔNG project thật,
# KHÔNG HOME). Dùng merge-opk-project.py trực tiếp (không chạy BMAD/npx).
# ============================================================================
# shellcheck disable=SC2015
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$KIT_DIR/scripts/merge-opk-project.py"

if [ ! -f "$MERGE" ]; then
  echo "test-installer-preservation: thiếu $MERGE" >&2
  exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "cần python3" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -r "$TMP"' EXIT

PASS=0
FAIL=0
check() {
  local name="$1" cond="$2"
  if [ "$cond" = "0" ]; then
    echo "  [ok]   $name"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name"
    FAIL=$((FAIL + 1))
  fi
}

# --- Tạo fixture project ---
FIX="$TMP/myproject"
mkdir -p "$FIX/.opencode"

cat > "$FIX/AGENTS.md" <<'EOF'
# My Custom AGENTS

This is MY custom project instructions. DO-NOT-LOSE-ME.
EOF

cat > "$FIX/OPENCODE.md" <<'EOF'
# My Custom OPENCODE

My custom notes here. KEEP-THIS-LINE.
EOF

cat > "$FIX/opencode.json" <<'EOF'
{
  "model": "my-custom-model",
  "provider": "my-custom-provider",
  "mcp": { "myServer": { "command": "my-mcp" } },
  "plugin": ["my-custom-plugin"],
  "permission": { "*": "ask", "bash": { "*": "ask" } },
  "instructions": ["CUSTOM.md", "CUSTOM.md"]
}
EOF

# --- Run merge (lần 1) ---
python3 "$MERGE" --project-dir "$FIX" >/dev/null 2>&1

# 1) User content preserved
grep -q "DO-NOT-LOSE-ME" "$FIX/AGENTS.md" && check "AGENTS.md user content preserved" 0 || check "AGENTS.md user content preserved" 1
grep -q "KEEP-THIS-LINE" "$FIX/OPENCODE.md" && check "OPENCODE.md user content preserved" 0 || check "OPENCODE.md user content preserved" 1

# 2) OPK managed block added exactly once (count OPEN markers only)
c1=$(grep -c ">>> opencode-power-kit managed:v2" "$FIX/AGENTS.md" || true)
c2=$(grep -c ">>> opencode-power-kit managed:v2" "$FIX/OPENCODE.md" || true)
[ "$c1" -eq 1 ] && [ "$c2" -eq 1 ] && check "OPK managed block added once" 0 || check "OPK managed block added once (AGENTS=$c1 OPENCODE=$c2)" 1

# 3) Custom JSON keys preserved
python3 - "$FIX/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("model") == "my-custom-model", "model lost"
assert d.get("provider") == "my-custom-provider", "provider lost"
assert "myServer" in d.get("mcp", {}), "mcp lost"
assert "my-custom-plugin" in d.get("plugin", []), "custom plugin lost"
assert d["permission"]["*"] == "ask", "custom permission overwritten"
assert d.get("instructions", []) == ["CUSTOM.md"], "instructions not deduplicated/preserved"
assert d.get("default_agent") == "opk-main", "default_agent not installed"
assert d.get("subagent_depth") == 1, "subagent_depth not installed"
read_rules = d["permission"]["read"]
assert read_rules["*.env"] == "deny"
assert read_rules["*.env.*"] == "deny"
assert read_rules["*.env.example"] == "allow"
read_keys = list(read_rules)
assert read_keys.index("*.env.example") > read_keys.index("*.env.*")
print("OK_JSON_KEYS")
PY
[ "${PIPESTATUS[0]}" = "0" ] && check "custom JSON keys preserved (model/provider/mcp/plugin/permission)" 0 || check "custom JSON keys preserved" 1

# 4) Safety plugin installed
[ -f "$FIX/.opencode/plugins/opk-safety-guard.js" ] && check "safety plugin installed" 0 || check "safety plugin installed" 1
[ -f "$FIX/.opencode/plugins/opk-token-guard.js" ] && check "token guard installed" 0 || check "token guard installed" 1
[ -f "$FIX/.opencode/agents/opk-main.md" ] && check "opk-main project agent installed" 0 || check "opk-main project agent installed" 1

# 5) Backup exists
ls "$FIX"/*.opk-bak.* >/dev/null 2>&1
check "backup exists" 0

# --- Run merge (lần 2) — idempotency ---
AGENTS_BEFORE="$(cat "$FIX/AGENTS.md")"
python3 "$MERGE" --project-dir "$FIX" >/dev/null 2>&1
AGENTS_AFTER="$(cat "$FIX/AGENTS.md")"
[ "$AGENTS_BEFORE" = "$AGENTS_AFTER" ] && check "idempotent: AGENTS.md unchanged on 2nd run" 0 || check "idempotent: AGENTS.md unchanged on 2nd run" 1
c1b=$(grep -c ">>> opencode-power-kit managed:v2" "$FIX/AGENTS.md" || true)
[ "$c1b" -eq 1 ] && check "no duplicate marker after 2nd run" 0 || check "no duplicate marker after 2nd run" 1

# Re-verify custom JSON still preserved after 2nd run
python3 - "$FIX/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("model") == "my-custom-model"
assert "my-custom-plugin" in d.get("plugin", [])
print("OK2")
PY
[ "${PIPESTATUS[0]}" = "0" ] && check "custom keys still preserved after 2nd run" 0 || check "custom keys still preserved after 2nd run" 1

# --- Legacy + root migration: JSONC fails closed unless normalization is explicit. ---
MIG="$TMP/migration-project"
mkdir -p "$MIG/.opencode"
printf '# migration fixture\n' >"$MIG/AGENTS.md"
cat >"$MIG/opencode.json" <<'EOF'
{
  "model": "root/model",
  "plugin": ["root-plugin"],
  "instructions": ["ROOT.md", "ROOT.md"]
}
EOF
cat >"$MIG/.opencode/opencode.json" <<'EOF'
{
  // legacy JSONC comment
  "model": "legacy/model",
  "provider": {"legacy": {"options": {"custom": true}}},
  "mcp": {"legacy": {"type": "local", "command": ["legacy-mcp"], "enabled": false}},
  "plugin": ["legacy-plugin"],
  "instructions": ["LEGACY.md", "ROOT.md"]
}
EOF
cp "$MIG/opencode.json" "$TMP/migration-root.before"
cp "$MIG/.opencode/opencode.json" "$TMP/migration-legacy.before"
if python3 "$MERGE" --project-dir "$MIG" >/dev/null 2>&1; then
  check "legacy JSONC fails closed by default" 1
else
  check "legacy JSONC fails closed by default" 0
fi
if cmp -s "$MIG/opencode.json" "$TMP/migration-root.before" && \
   cmp -s "$MIG/.opencode/opencode.json" "$TMP/migration-legacy.before"; then
  check "failed JSONC migration leaves root and legacy byte-identical" 0
else
  check "failed JSONC migration leaves root and legacy byte-identical" 1
fi
shopt -s nullglob
migration_archives=("$MIG"/.opk-trash/legacy-config-*/opencode.json)
shopt -u nullglob
if [ "${#migration_archives[@]}" -eq 0 ]; then
  check "failed JSONC migration creates no archive" 0
else
  check "failed JSONC migration creates no archive" 1
fi

python3 "$MERGE" --project-dir "$MIG" --normalize-jsonc >/dev/null 2>&1
python3 - "$MIG/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["model"] == "root/model"
assert "legacy" in d["provider"] and "legacy" in d["mcp"]
assert d["plugin"][:2] == ["root-plugin", "legacy-plugin"]
assert d["instructions"] == ["ROOT.md", "LEGACY.md"]
PY
check "legacy migration preserves root/provider/MCP and unions lists" "$?"
[ ! -e "$MIG/.opencode/opencode.json" ] && check "legacy config retired after verified root write" 0 || check "legacy config retired after verified root write" 1
shopt -s nullglob
migration_archives=("$MIG"/.opk-trash/legacy-config-*/opencode.json)
root_backups=("$MIG/opencode.json".opk-bak.*)
legacy_backups=("$MIG/.opencode/opencode.json".opk-bak.*)
shopt -u nullglob
[ "${#migration_archives[@]}" -eq 1 ] && [ "${#root_backups[@]}" -eq 1 ] && [ "${#legacy_backups[@]}" -eq 1 ] && \
  check "migration archives legacy and backs up both configs" 0 || check "migration archives legacy and backs up both configs" 1

# Comment-like text inside JSON strings is not treated as JSONC.
LITERALS="$TMP/literal-project"
mkdir -p "$LITERALS"
printf '# literal fixture\n' >"$LITERALS/AGENTS.md"
cat >"$LITERALS/opencode.json" <<'EOF'
{
  "url": "https://example.com/path",
  "line": "text // not comment",
  "block": "/* literal */"
}
EOF
python3 "$MERGE" --project-dir "$LITERALS" --mode power >/dev/null 2>&1
python3 - "$LITERALS/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
assert d["url"] == "https://example.com/path"
assert d["line"] == "text // not comment"
assert d["block"] == "/* literal */"
PY
check "JSON strings containing comment markers remain valid" "$?"

# Root line/block comments both require explicit normalization and a byte-identical backup.
for kind in line block; do
  COMMENTED="$TMP/commented-$kind"
  mkdir -p "$COMMENTED"
  printf '# comment fixture\n' >"$COMMENTED/AGENTS.md"
  if [ "$kind" = line ]; then
    printf '{\n  // keep this comment\n  "model": "fixture/model"\n}\n' >"$COMMENTED/opencode.json"
  else
    printf '{\n  /* keep this block */\n  "model": "fixture/model"\n}\n' >"$COMMENTED/opencode.json"
  fi
  cp "$COMMENTED/opencode.json" "$TMP/commented-$kind.before"
  if python3 "$MERGE" --project-dir "$COMMENTED" --mode power >/dev/null 2>&1; then
    check "root $kind comment fails closed" 1
  else
    check "root $kind comment fails closed" 0
  fi
  cmp -s "$COMMENTED/opencode.json" "$TMP/commented-$kind.before"
  check "root $kind comment remains byte-identical" "$?"
  python3 "$MERGE" --project-dir "$COMMENTED" --mode power --normalize-jsonc >/dev/null 2>&1
  shopt -s nullglob
  comment_backups=("$COMMENTED/opencode.json".opk-bak.*)
  shopt -u nullglob
  backup_match=false
  for comment_backup in "${comment_backups[@]}"; do
    cmp -s "$comment_backup" "$TMP/commented-$kind.before" && backup_match=true
  done
  [ "$backup_match" = true ]
  check "root $kind normalization creates exact backup" "$?"
done

# Archive failure is detected before publishing a merged root config.
ROLLBACK="$TMP/archive-failure"
mkdir -p "$ROLLBACK/.opencode"
printf '# rollback fixture\n' >"$ROLLBACK/AGENTS.md"
printf '{"model":"root/original"}\n' >"$ROLLBACK/opencode.json"
printf '{"provider":{"legacy":{}}}\n' >"$ROLLBACK/.opencode/opencode.json"
printf 'not a directory\n' >"$ROLLBACK/.opk-trash"
cp "$ROLLBACK/opencode.json" "$TMP/archive-failure-root.before"
cp "$ROLLBACK/.opencode/opencode.json" "$TMP/archive-failure-legacy.before"
if python3 "$MERGE" --project-dir "$ROLLBACK" --migrate-only >/dev/null 2>&1; then
  check "archive preflight failure exits nonzero" 1
else
  check "archive preflight failure exits nonzero" 0
fi
if cmp -s "$ROLLBACK/opencode.json" "$TMP/archive-failure-root.before" && \
   cmp -s "$ROLLBACK/.opencode/opencode.json" "$TMP/archive-failure-legacy.before"; then
  check "archive failure preserves root and legacy" 0
else
  check "archive failure preserves root and legacy" 1
fi

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "test-installer-preservation: FAILED ($FAIL failures)"
  exit 1
fi
echo "test-installer-preservation: OK ($PASS checks passed)"
