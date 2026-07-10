#!/usr/bin/env bash
# ============================================================================
# doctor.sh — OpenCode Power Kit health check (read-only)
# Chẩn đoán cấu hình, dependencies, và runtime environment.
#
# Usage:
#   bash doctor.sh              # basic check
#   bash doctor.sh --deep       # extended check (read-only, no side effects)
#   bash doctor.sh --fix        # suggest fixes (no auto-fix yet)
# ============================================================================
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
KIT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
VERSION="$(cat "$KIT_DIR/VERSION" 2>/dev/null || echo "?")"
DEEP=0
FIX_MODE=0

for arg in "$@"; do
  case "$arg" in
    --deep) DEEP=1 ;;
    --fix)  FIX_MODE=1 ;;
    --help|-h)
      echo "Usage: doctor.sh [--deep] [--fix]"
      echo ""
      echo "  --deep   Extended checks (read-only, no side effects)"
      echo "  --fix    Suggest fixes (not auto-applied yet)"
      exit 0
      ;;
  esac
done

# --- Helpers ---
pass()  { echo "  ✅ $*"; }
warn()  { echo "  ⚠️  $*"; }
fail()  { echo "  ❌ $*"; }
info()  { echo "  ℹ️  $*"; }
section() { echo ""; echo "=== $* ==="; }
errors=0

# --- Section 1: Kit integrity ---
section "Kit Integrity"
if [ -f "$KIT_DIR/VERSION" ]; then
  pass "VERSION exists: $(cat "$KIT_DIR/VERSION")"
else
  fail "VERSION file missing"; ((errors++))
fi

if [ -f "$KIT_DIR/install.sh" ]; then
  pass "install.sh exists"
else
  fail "install.sh missing"; ((errors++))
fi

if [ -f "$KIT_DIR/install-global.sh" ]; then
  pass "install-global.sh exists"
else
  fail "install-global.sh missing"; ((errors++))
fi

if [ -f "$KIT_DIR/verify.sh" ]; then
  pass "verify.sh exists"
else
  fail "verify.sh missing"; ((errors++))
fi

if [ -f "$KIT_DIR/bin/opk" ]; then
  pass "bin/opk exists"
else
  fail "bin/opk missing"; ((errors++))
fi

if [ -f "$KIT_DIR/doctor.sh" ]; then
  pass "doctor.sh exists (self-check)"
else
  warn "doctor.sh missing (recursive check)"
fi

# --- Section 2: Templates ---
section "Config Templates"
for tpl in opencode.json opencode.power.json opencode.safe.json; do
  if [ -f "$KIT_DIR/templates/$tpl" ]; then
    pass "templates/$tpl exists"
    # Check permission deny-list (wildcard first, deny last)
    if grep -q '"rm -rf' "$KIT_DIR/templates/$tpl" 2>/dev/null; then
      pass "templates/$tpl has deny-list"
    else
      warn "templates/$tpl may be missing deny-list"
    fi
  else
    fail "templates/$tpl missing"; ((errors++))
  fi
done

if [ -f "$KIT_DIR/templates/plugins/opk-safety-guard.js" ]; then
  pass "Safety plugin exists"
  # Check ESM export
  if grep -q "tool.execute.before" "$KIT_DIR/templates/plugins/opk-safety-guard.js" 2>/dev/null; then
    pass "Safety plugin uses tool.execute.before hook"
  else
    warn "Safety plugin may need tool.execute.before hook"
  fi
else
  warn "Safety plugin template missing"
fi

# --- Section 3: Scripts ---
section "Scripts"
SCRIPT_COUNT=$(find "$KIT_DIR/scripts" -maxdepth 1 \( -name "*.sh" -o -name "*.py" -o -name "*.mjs" \) 2>/dev/null | wc -l)
info "Scripts found: $SCRIPT_COUNT"

# Key scripts
for s in detect-mode.py merge-opk-project.py validate-opencode-pack.py; do
  if [ -f "$KIT_DIR/scripts/$s" ]; then
    pass "scripts/$s exists"
  else
    warn "scripts/$s missing"
  fi
done

# Test scripts
for s in test-permission-rules.py test-safety-plugin.mjs test-opk-mode.sh test-installer-preservation.sh; do
  if [ -f "$KIT_DIR/scripts/$s" ]; then
    pass "scripts/$s exists"
  else
    info "scripts/$s not found (optional)"
  fi
done

# --- Section 4: Agents & Commands ---
section "Agents & Commands"
AGENTS_COUNT=$(find "$KIT_DIR/opencode-global/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
COMMANDS_COUNT=$(find "$KIT_DIR/opencode-global/commands" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
SKILLS_COUNT=$(find "$KIT_DIR/opencode-global/skills" -maxdepth 1 -type d 2>/dev/null | wc -l)
info "Agents: $AGENTS_COUNT, Commands: $COMMANDS_COUNT, Skills: $SKILLS_COUNT"

# GSD reference check
GSD_REF_COUNT=$(find "$KIT_DIR/extras/gsd-agent-reference" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
info "GSD reference agents: $GSD_REF_COUNT"

if [ -d "$KIT_DIR/opencode-global/agents" ]; then
  GSD_ACTIVE=$(find "$KIT_DIR/opencode-global/agents" -maxdepth 1 -name "gsd-*.md" 2>/dev/null | wc -l)
  if [ "$GSD_ACTIVE" -gt 0 ]; then
    warn "$GSD_ACTIVE gsd-*.md still in opencode-global/agents/ (should be in extras/)"
  else
    pass "No GSD agents in active dir (correct: in extras/)"
  fi
fi

# --- Section 5: Python runtime ---
section "Runtime"
for cmd in python3 node npm npx; do
  if command -v "$cmd" >/dev/null 2>&1; then
    ver=""
    case "$cmd" in
      python3) ver="$(python3 --version 2>&1 | head -1)" ;;
      node)    ver="$(node --version 2>&1)" ;;
      npm)     ver="$(npm --version 2>&1)" ;;
      npx)     ver="$(npx --version 2>&1)" ;;
    esac
    pass "$cmd found: $ver"
  else
    warn "$cmd not found on PATH"
  fi
done

# --- Section 6: Project state (if in a project) ---
section "Project State (current dir)"
if [ -f ".opencode/opencode.json" ]; then
  pass ".opencode/opencode.json exists"
  # Check permission mode
  if python3 -c "import json,sys; d=json.load(sys.open('.opencode/opencode.json')); p=d.get('permission'); sys.exit(0 if p=='allow' else 1)" 2>/dev/null; then
    info "Mode: POWER (permission: allow)"
  elif [ -f ".opencode/opencode.json" ]; then
    info "Mode: SAFE or CUSTOM (permission object)"
  fi
else
  info ".opencode/opencode.json not found (not in project?)"
fi

if [ -f ".opencode/plugins/opk-safety-guard.js" ]; then
  pass "Safety plugin installed in project"
else
  info "Safety plugin not installed in project"
fi

if [ -f "AGENTS.md" ]; then
  pass "AGENTS.md exists in project"
else
  info "AGENTS.md not found in project"
fi

# --- Section 7: Deep checks ---
if [ "$DEEP" -eq 1 ]; then
  section "Deep Checks"

  # Check for personal paths
  INFO_COUNT=$(grep -rl '/home/nha' "$KIT_DIR/opencode-global/" 2>/dev/null | wc -l)
  if [ "$INFO_COUNT" -gt 0 ]; then
    fail "$INFO_COUNT files contain personal path /home/nha"; ((errors++))
  else
    pass "No personal paths in opencode-global/"
  fi

  # Check extras paths
  EXTRAS_INFO=$(grep -rl '/home/nha' "$KIT_DIR/extras/" 2>/dev/null | wc -l)
  if [ "$EXTRAS_INFO" -gt 0 ]; then
    warn "$EXTRAS_INFO files in extras/ may contain personal paths"
  else
    pass "No personal paths in extras/"
  fi

  # Check scripts bash -n
  SCRIPT_ERRS=0
  for s in "$KIT_DIR"/scripts/*.sh "$KIT_DIR"/doctor.sh "$KIT_DIR"/verify.sh; do
    if [ -f "$s" ] && ! bash -n "$s" 2>/dev/null; then
      warn "bash -n failed: $(basename "$s")"
      ((SCRIPT_ERRS++))
    fi
  done
  if [ "$SCRIPT_ERRS" -eq 0 ]; then
    pass "All shell scripts pass bash -n"
  else
    warn "$SCRIPT_ERRS script(s) failed bash -n"
  fi

  # Orchestration Lite checks
  if [ -f "$KIT_DIR/docs/OPK_ORCHESTRATION_LITE.md" ]; then
    pass "docs/OPK_ORCHESTRATION_LITE.md exists"
  else
    info "docs/OPK_ORCHESTRATION_LITE.md not found"
  fi

  # .opk/work/ check
  if [ -d ".opk/work" ]; then
    pass ".opk/work/ directory exists"
  else
    info ".opk/work/ not found (created by power-work-lite)"
  fi

  # Vendoring check — no GSD source in active agents
  GSD_SOURCE=$(grep -rl '@opengsd/gsd-core' "$KIT_DIR/opencode-global/" 2>/dev/null | wc -l)
  if [ "$GSD_SOURCE" -gt 0 ]; then
    warn "$GSD_SOURCE files reference @opengsd/gsd-core in opencode-global/ (may be OK in docs)"
  else
    pass "No vendored GSD source in active dir"
  fi
fi

# --- Summary ---
echo ""
echo "=== Summary ==="
if [ "$errors" -gt 0 ]; then
  echo "  ❌ $errors critical issue(s) found."
  echo "  Run 'opk doctor --deep' for extended checks."
  exit 1
else
  echo "  ✅ All basic checks passed."
  if [ "$DEEP" -eq 1 ]; then
    echo "  ✅ Deep checks completed."
  fi
  exit 0
fi
