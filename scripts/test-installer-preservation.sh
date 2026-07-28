#!/usr/bin/env bash
# ============================================================================
# test-installer-preservation.sh
#
# Integration test: OPK installer (merge) phải GIỮ NGUYÊN nội dung tùy chỉnh
# của user, thêm OPK managed block ĐÚNG MỘT LẦN, giữ nguyên custom JSON keys,
# backup, và cài safety plugin. Chạy trên fixture temp (KHÔNG project thật,
# KHÔNG HOME). Dùng merge-opk-project.py trực tiếp (không chạy BMAD/npx).
# ============================================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MERGE="$KIT_DIR/scripts/merge-opk-project.py"

if [ ! -f "$MERGE" ]; then
  echo "test-installer-preservation: thiếu $MERGE" >&2
  exit 1
fi
command -v python3 >/dev/null 2>&1 || { echo "cần python3" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

cat > "$FIX/.opencode/opencode.json" <<'EOF'
{
  "model": "my-custom-model",
  "provider": "my-custom-provider",
  "mcp": { "myServer": { "command": "my-mcp" } },
  "plugin": ["my-custom-plugin"],
  "permission": { "*": "ask", "bash": { "*": "ask" } },
  "instructions": ["CUSTOM.md"]
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
python3 - "$FIX/.opencode/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("model") == "my-custom-model", "model lost"
assert d.get("provider") == "my-custom-provider", "provider lost"
assert "myServer" in d.get("mcp", {}), "mcp lost"
assert "my-custom-plugin" in d.get("plugin", []), "custom plugin lost"
assert d["permission"]["*"] == "ask", "custom permission overwritten"
assert "AGENTS.md" in d.get("instructions", []), "AGENTS.md not added to instructions"
assert "OPENCODE.md" in d.get("instructions", []), "OPENCODE.md not added to instructions"
print("OK_JSON_KEYS")
PY
[ "${PIPESTATUS[0]}" = "0" ] && check "custom JSON keys preserved (model/provider/mcp/plugin/permission)" 0 || check "custom JSON keys preserved" 1

# 4) Safety plugin installed
[ -f "$FIX/.opencode/plugins/opk-safety-guard.js" ] && check "safety plugin installed" 0 || check "safety plugin installed" 1

# 5) Backup exists
ls "$FIX"/*.opk-bak.* >/dev/null 2>&1 || ls "$FIX/.opencode"/*.opk-bak.* >/dev/null 2>&1
check "backup exists" 0

# --- Run merge (lần 2) — idempotency ---
AGENTS_BEFORE="$(cat "$FIX/AGENTS.md")"
python3 "$MERGE" --project-dir "$FIX" >/dev/null 2>&1
AGENTS_AFTER="$(cat "$FIX/AGENTS.md")"
[ "$AGENTS_BEFORE" = "$AGENTS_AFTER" ] && check "idempotent: AGENTS.md unchanged on 2nd run" 0 || check "idempotent: AGENTS.md unchanged on 2nd run" 1
c1b=$(grep -c ">>> opencode-power-kit managed:v2" "$FIX/AGENTS.md" || true)
[ "$c1b" -eq 1 ] && check "no duplicate marker after 2nd run" 0 || check "no duplicate marker after 2nd run" 1

# Re-verify custom JSON still preserved after 2nd run
python3 - "$FIX/.opencode/opencode.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
assert d.get("model") == "my-custom-model"
assert "my-custom-plugin" in d.get("plugin", [])
print("OK2")
PY
[ "${PIPESTATUS[0]}" = "0" ] && check "custom keys still preserved after 2nd run" 0 || check "custom keys still preserved after 2nd run" 1

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "test-installer-preservation: FAILED ($FAIL failures)"
  exit 1
fi
echo "test-installer-preservation: OK ($PASS checks passed)"
