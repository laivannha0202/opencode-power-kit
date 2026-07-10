#!/usr/bin/env bash
# ============================================================================
# release-gate.sh — Release readiness gate
# Kiểm tra tất cả điều kiện trước khi release v2.1.0.
# Exit 0 = PASS (ready to release), exit 1 = FAIL (fix first).
# ============================================================================
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
KIT_DIR="$(cd "$(dirname "$SELF")/.." && pwd)"
VERSION="$(cat "$KIT_DIR/VERSION" 2>/dev/null || echo "?")"
errors=0
warnings=0

pass()  { echo "  ✅ $*"; }
warn()  { echo "  ⚠️  $*"; ((warnings++)); }
fail()  { echo "  ❌ $*"; ((errors++)); }
info()  { echo "  ℹ️  $*"; }
section() { echo ""; echo "=== $* ==="; }

echo "Release Gate — checking readiness for v$VERSION"
echo "Kit: $KIT_DIR"

# --- 1. VERSION file ---
section "1. VERSION"
if [ -f "$KIT_DIR/VERSION" ]; then
  ver="$(cat "$KIT_DIR/VERSION")"
  if [[ "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    pass "VERSION = $ver (valid semver)"
  else
    fail "VERSION = '$ver' (not semver)"
  fi
else
  fail "VERSION file missing"
fi

# --- 2. CHANGELOG ---
section "2. CHANGELOG"
if [ -f "$KIT_DIR/CHANGELOG.md" ]; then
  if grep -q "## \[$VERSION\]" "$KIT_DIR/CHANGELOG.md"; then
    pass "CHANGELOG has section [$VERSION]"
  else
    fail "CHANGELOG missing section [$VERSION]"
  fi
  # Check for duplicate headings
  dupes=$(grep -c "^## \[" "$KIT_DIR/CHANGELOG.md" 2>/dev/null || echo "0")
  info "Total version headings: $dupes"
else
  fail "CHANGELOG.md missing"
fi

# --- 3. Templates ---
section "3. Config Templates"
for tpl in opencode.json opencode.power.json opencode.safe.json; do
  if [ -f "$KIT_DIR/templates/$tpl" ]; then
    pass "templates/$tpl exists"
    # Check permission deny-list
    if grep -q '"rm -rf' "$KIT_DIR/templates/$tpl" 2>/dev/null; then
      pass "templates/$tpl has deny-list"
    else
      fail "templates/$tpl missing deny-list"
    fi
  else
    fail "templates/$tpl missing"
  fi
done

# Check rule ordering: wildcard first, deny last
for tpl in opencode.json opencode.power.json opencode.safe.json; do
  f="$KIT_DIR/templates/$tpl"
  if [ -f "$f" ]; then
    # Find line numbers of permission wildcard vs deny patterns
    # Match the permission block's "*" key specifically (indented, at permission level)
    wc_line=$(grep -n '^\s*"\*":' "$f" | head -1 | cut -d: -f1 || echo "9999")
    deny_line=$(grep -n '"rm -rf' "$f" | head -1 | cut -d: -f1 || echo "0")
    if [ "$wc_line" -lt "$deny_line" ] 2>/dev/null; then
      pass "templates/$tpl: wildcard before deny (correct order)"
    else
      fail "templates/$tpl: deny rules before wildcard (wrong order)"
    fi
  fi
done

# --- 4. Safety Plugin ---
section "4. Safety Plugin"
SP="$KIT_DIR/templates/plugins/opk-safety-guard.js"
if [ -f "$SP" ]; then
  pass "Safety plugin exists"
  if grep -q "tool.execute.before" "$SP"; then
    pass "Uses tool.execute.before hook (ESM)"
  else
    fail "Missing tool.execute.before hook"
  fi
  if grep -q "throw new Error" "$SP"; then
    pass "Uses throw new Error() for blocking"
  else
    fail "Missing throw new Error() pattern"
  fi
else
  fail "Safety plugin missing"
fi

# --- 5. GSD Agents ---
section "5. GSD Agents"
GSD_ACTIVE=$(find "$KIT_DIR/opencode-global/agents" -maxdepth 1 -name "gsd-*.md" 2>/dev/null | wc -l)
if [ "$GSD_ACTIVE" -gt 0 ]; then
  fail "$GSD_ACTIVE GSD agents still in opencode-global/agents/"
else
  pass "No GSD agents in active dir"
fi
GSD_REF=$(find "$KIT_DIR/extras/gsd-agent-reference" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
if [ "$GSD_REF" -gt 0 ]; then
  pass "GSD reference agents in extras/ ($GSD_REF files)"
else
  warn "No GSD reference agents in extras/"
fi

# --- 6. Scripts ---
section "6. Scripts"
for s in detect-mode.py merge-opk-project.py validate-opencode-pack.py; do
  if [ -f "$KIT_DIR/scripts/$s" ]; then
    pass "scripts/$s exists"
  else
    fail "scripts/$s missing"
  fi
done

# Check merge script has os import
if grep -q "^import os" "$KIT_DIR/scripts/merge-opk-project.py" 2>/dev/null; then
  pass "merge-opk-project.py has import os"
else
  fail "merge-opk-project.py missing import os"
fi

# Check detect-mode.py parses JSON (not grep strings)
if grep -q "json.load" "$KIT_DIR/scripts/detect-mode.py" 2>/dev/null; then
  pass "detect-mode.py uses JSON parser"
else
  warn "detect-mode.py may not use JSON parser"
fi

# --- 7. No personal paths ---
section "7. Personal Path Check"
PERSONAL=0
if grep -rl '/home/nha' "$KIT_DIR/opencode-global/" "$KIT_DIR/extras/" >/dev/null 2>&1; then
  PERSONAL=$(grep -rl '/home/nha' "$KIT_DIR/opencode-global/" "$KIT_DIR/extras/" 2>/dev/null | wc -l)
fi
if [ "$PERSONAL" -gt 0 ]; then
  fail "$PERSONAL files contain /home/nha path"
else
  pass "No personal paths in runtime dirs"
fi

# --- 8. Shell syntax ---
section "8. Shell Syntax"
ERRS=0
for s in "$KIT_DIR"/doctor.sh "$KIT_DIR"/verify.sh "$KIT_DIR"/bin/opk "$KIT_DIR"/scripts/*.sh; do
  [ -f "$s" ] || continue
  if ! bash -n "$s" 2>/dev/null; then
    fail "bash -n failed: $(basename "$s")"
    ((ERRS++))
  fi
done
if [ "$ERRS" -eq 0 ]; then
  pass "All shell scripts pass bash -n"
fi

# --- 9. Tests exist ---
section "9. Test Coverage"
for s in test-permission-rules.py test-safety-plugin.mjs test-opk-mode.sh test-installer-preservation.sh; do
  if [ -f "$KIT_DIR/scripts/$s" ]; then
    pass "scripts/$s exists"
  else
    warn "scripts/$s missing"
  fi
done

# --- 10. Evals ---
section "10. Eval Harness"
if [ -d "$KIT_DIR/evals" ]; then
  pass "evals/ directory exists"
else
  warn "evals/ directory not found"
fi

# --- Summary ---
echo ""
echo "============================="
if [ "$errors" -gt 0 ]; then
  echo "❌ RELEASE GATE FAILED — $errors error(s), $warnings warning(s)"
  echo "   Fix errors before releasing."
  exit 1
else
  echo "✅ RELEASE GATE PASSED — $warnings warning(s)"
  echo "   Ready to release v$VERSION"
  exit 0
fi
