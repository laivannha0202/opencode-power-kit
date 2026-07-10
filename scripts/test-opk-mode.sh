#!/usr/bin/env bash
# ============================================================================
# test-opk-mode.sh
#
# Regression test cho mode detection (POWER / SAFE / CUSTOM).
# Tạo project tạm trong thư mục temp an toàn (KHÔNG ghi vào HOME thật).
# Chạy scripts/detect-mode.py trên từng config và xác minh output.
# ============================================================================
set -euo pipefail

KIT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DETECT="$KIT_DIR/scripts/detect-mode.py"

if [ ! -f "$DETECT" ]; then
  echo "test-opk-mode: thiếu $DETECT" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "test-opk-mode: cần python3" >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

check() {
  local name="$1" want="$2" got="$3"
  if [ "$want" = "$got" ]; then
    echo "  [ok]   $name => $got"
    PASS=$((PASS + 1))
  else
    echo "  [FAIL] $name => $got (want $want)"
    FAIL=$((FAIL + 1))
  fi
}

# 1) Power template
cp "$KIT_DIR/templates/opencode.power.json" "$TMP/power.json"
check "opencode.power.json" "POWER" "$(python3 "$DETECT" "$TMP/power.json")"

# 2) Safe template
cp "$KIT_DIR/templates/opencode.safe.json" "$TMP/safe.json"
check "opencode.safe.json" "SAFE" "$(python3 "$DETECT" "$TMP/safe.json")"

# 3) Default template (công bố là POWER)
cp "$KIT_DIR/templates/opencode.json" "$TMP/default.json"
check "opencode.json (default)" "POWER" "$(python3 "$DETECT" "$TMP/default.json")"

# 4) Custom config (mixed) -> CUSTOM
cat > "$TMP/custom.json" <<'EOF'
{
  "permission": {
    "*": "ask",
    "bash": { "*": "allow", "rm -rf*": "deny" },
    "write": "ask",
    "edit": "allow",
    "task": "ask"
  }
}
EOF
check "custom (mixed)" "CUSTOM" "$(python3 "$DETECT" "$TMP/custom.json")"

# 5) Custom with top-level string allow -> POWER
cat > "$TMP/custom2.json" <<'EOF'
{
  "permission": "allow"
}
EOF
check "custom (string allow)" "POWER" "$(python3 "$DETECT" "$TMP/custom2.json")"

# 6) JSONC comment tolerance
cat > "$TMP/jsonc.json" <<'EOF'
{
  // this is a comment
  "permission": {
    "*": "ask",
    "bash": { "*": "ask" },
    "write": "ask",
    "edit": "ask",
    "task": "ask"
  }
}
EOF
check "jsonc safe" "SAFE" "$(python3 "$DETECT" "$TMP/jsonc.json")"

echo ""
if [ "$FAIL" -gt 0 ]; then
  echo "test-opk-mode: FAILED ($FAIL failures)"
  exit 1
fi
echo "test-opk-mode: OK ($PASS checks passed)"
