#!/usr/bin/env bash

# ============================================================================
# OpenCode Power Kit - Verify Script
# Kiểm tra project và global config đã được cài đặt đúng chưa
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

check() {
	local desc="$1" path="$2"
	if [ -e "$path" ]; then
		echo -e "  ${GREEN}✅${NC} $desc"
		((++PASS))
	else
		echo -e "  ${RED}❌${NC} $desc — KHÔNG TÌM THẤY: $path"
		((++FAIL))
	fi
}

check_warn() {
	local desc="$1" path="$2"
	if [ -e "$path" ]; then
		echo -e "  ${GREEN}✅${NC} $desc"
		((++PASS))
	else
		echo -e "  ${YELLOW}⚠️${NC} $desc — không bắt buộc: $path"
		((++WARN))
	fi
}

echo ""
echo "=========================================="
echo "  OpenCode Power Kit - Verify"
echo "  Project: $(pwd)"
echo "=========================================="
echo ""

# --- Global config checks ---
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
GLOBAL_DIR="$KIT_DIR/opencode-global"

echo "🌍 Global config (opencode-global/):"
check "OPENCODE_CONFIG_DIR env in ~/.bashrc" "$HOME/.bashrc"
if grep -qF 'OPENCODE_CONFIG_DIR' "$HOME/.bashrc" 2>/dev/null; then
	echo -e "  ${GREEN}✅${NC} OPENCODE_CONFIG_DIR đã set trong ~/.bashrc"
	((++PASS))
else
	echo -e "  ${RED}❌${NC} OPENCODE_CONFIG_DIR chưa set trong ~/.bashrc"
	((++FAIL))
fi

echo ""
echo "📁 Global agents:"
check "plan-lite.md" "$GLOBAL_DIR/agents/plan-lite.md"
check "review-lite.md" "$GLOBAL_DIR/agents/review-lite.md"
check "debug-lite.md" "$GLOBAL_DIR/agents/debug-lite.md"
check "build-strong.md" "$GLOBAL_DIR/agents/build-strong.md"

echo ""
echo "📁 Global commands:"
check "smart-scan.md" "$GLOBAL_DIR/commands/smart-scan.md"
check "bugfix-safe.md" "$GLOBAL_DIR/commands/bugfix-safe.md"
check "review-diff.md" "$GLOBAL_DIR/commands/review-diff.md"
check "repo-map.md" "$GLOBAL_DIR/commands/repo-map.md"
check "token-pack.md" "$GLOBAL_DIR/commands/token-pack.md"
check "db-readonly.md" "$GLOBAL_DIR/commands/db-readonly.md"
echo "  --- v2: lifecycle + review + token ---"
check "spec-lite.md" "$GLOBAL_DIR/commands/spec-lite.md"
check "plan-work.md" "$GLOBAL_DIR/commands/plan-work.md"
check "build-slice.md" "$GLOBAL_DIR/commands/build-slice.md"
check "test-proof.md" "$GLOBAL_DIR/commands/test-proof.md"
check "ship-check.md" "$GLOBAL_DIR/commands/ship-check.md"
check "security-review.md" "$GLOBAL_DIR/commands/security-review.md"
check "api-contract-review.md" "$GLOBAL_DIR/commands/api-contract-review.md"
check "migration-safe.md" "$GLOBAL_DIR/commands/migration-safe.md"
check "rtk-gain.md" "$GLOBAL_DIR/commands/rtk-gain.md"

echo ""
echo "📁 Global skills:"
check "token-smart-code/SKILL.md" "$GLOBAL_DIR/skills/token-smart-code/SKILL.md"
check "serena-first/SKILL.md" "$GLOBAL_DIR/skills/serena-first/SKILL.md"
check "safe-edit/SKILL.md" "$GLOBAL_DIR/skills/safe-edit/SKILL.md"
check "repo-map/SKILL.md" "$GLOBAL_DIR/skills/repo-map/SKILL.md"
check "js-ts-project/SKILL.md" "$GLOBAL_DIR/skills/js-ts-project/SKILL.md"
echo "  --- v2: review + strategy + ADR ---"
check "security-review/SKILL.md" "$GLOBAL_DIR/skills/security-review/SKILL.md"
check "api-contract/SKILL.md" "$GLOBAL_DIR/skills/api-contract/SKILL.md"
check "database-migration-safe/SKILL.md" "$GLOBAL_DIR/skills/database-migration-safe/SKILL.md"
check "test-strategy/SKILL.md" "$GLOBAL_DIR/skills/test-strategy/SKILL.md"
check "frontend-ui-review/SKILL.md" "$GLOBAL_DIR/skills/frontend-ui-review/SKILL.md"
check "adr-architecture-decision/SKILL.md" "$GLOBAL_DIR/skills/adr-architecture-decision/SKILL.md"
check "rtk-token-optimizer/SKILL.md" "$GLOBAL_DIR/skills/rtk-token-optimizer/SKILL.md"

echo ""
echo "📁 Scripts:"
check "install-token-tools.sh" "$KIT_DIR/scripts/install-token-tools.sh"

echo ""
echo "🔧 External tools:"
for tool in repomix rg fd ast-grep serena; do
	if command -v "$tool" &>/dev/null; then
		echo -e "  ${GREEN}✅${NC} $tool"
		((++PASS))
	else
		echo -e "  ${YELLOW}⚠️${NC} $tool — không tìm thấy (không bắt buộc)"
		((++WARN))
	fi
done

echo ""
echo "🔧 Token optimization tools (không bắt buộc, không fail nếu thiếu):"
for tool in rtk tokscale; do
	if command -v "$tool" &>/dev/null; then
		echo -e "  ${GREEN}✅${NC} $tool"
		((++PASS))
	else
		echo -e "  ${YELLOW}⚠️${NC} $tool — chưa cài. Chạy: bash scripts/install-token-tools.sh"
		((++WARN))
	fi
done

# --- Detect runtime context: kit repo itself vs downstream target project ---
# When verify.sh runs from inside the kit repo (e.g. CI, pre-release sanity
# check), the three target-project generated files (AGENTS.md, OPENCODE.md,
# .opencode/opencode.json) are NOT committed here — they are produced by
# the installer into downstream projects. Treat their absence as WARN so
# the kit itself can ship clean (0 fail) without lying about a real
# downstream install.
IS_KIT_REPO=false
if [ "$(pwd)" = "$KIT_DIR" ]; then
	IS_KIT_REPO=true
fi

# --- Per-project checks ---
echo ""
echo "=========================================="
echo "  Per-project: $(pwd)"
echo "=========================================="
echo ""

echo "📁 Files bắt buộc:"
if [ "$IS_KIT_REPO" = true ]; then
	# Kit repo mode: target-project generated files are expected to be absent.
	for f in "AGENTS.md" "OPENCODE.md" ".opencode/opencode.json"; do
		if [ -e "$f" ]; then
			echo -e "  ${GREEN}✅${NC} $f"
			((++PASS))
		else
			echo -e "  ${YELLOW}⚠️${NC} $f — target-project file, generated bởi installer (kit repo: bỏ qua, không fail)"
			((++WARN))
		fi
	done
else
	check "AGENTS.md" "AGENTS.md"
	check "OPENCODE.md" "OPENCODE.md"
	check ".opencode/opencode.json" ".opencode/opencode.json"
fi

echo ""
echo "📁 Files tùy chọn:"
check_warn "knip.json" "knip.json"
check_warn "lefthook.yml" "lefthook.yml"

echo ""
echo "📁 Gitignore:"
if [ -f ".gitignore" ]; then
	if grep -qF "# >>> opencode-power-kit" .gitignore 2>/dev/null; then
		echo -e "  ${GREEN}✅${NC} .gitignore có nội dung Power Kit"
		((++PASS))
	else
		echo -e "  ${YELLOW}⚠️${NC} .gitignore chưa có nội dung Power Kit"
		((++WARN))
	fi
else
	echo -e "  ${RED}❌${NC} .gitignore không tồn tại"
	((++FAIL))
fi

echo ""
echo "📦 opencode.json content:"
if [ -f ".opencode/opencode.json" ]; then
	if grep -q "superpowers" .opencode/opencode.json 2>/dev/null; then
		echo -e "  ${GREEN}✅${NC} Có superpowers plugin"
		((++PASS))
	else
		echo -e "  ${RED}❌${NC} Thiếu superpowers plugin"
		((++FAIL))
	fi
	if grep -q "AGENTS.md" .opencode/opencode.json 2>/dev/null; then
		echo -e "  ${GREEN}✅${NC} Có AGENTS.md instruction"
		((++PASS))
	else
		echo -e "  ${RED}❌${NC} Thiếu AGENTS.md instruction"
		((++FAIL))
	fi
fi

echo ""
echo "🔐 Safety check:"
SAFE=true

for f in .env .env.local .env.production; do
	if [ -f "$f" ]; then
		echo -e "  ${RED}❌${NC} CẢNH BÁO: $f tồn tại — đừng commit!"
		SAFE=false
	fi
done

if [ -f ".opencode/opencode.json" ]; then
	if grep -qiE "(token|password|secret|api_key)" .opencode/opencode.json 2>/dev/null; then
		echo -e "  ${RED}❌${NC} opencode.json có chứa token/password — KIỂM TRA LẠI!"
		SAFE=false
	fi
fi

if [ "$SAFE" = true ]; then
	echo -e "  ${GREEN}✅${NC} Không phát hiện secrets"
	((++PASS))
fi

# --- No-MCP guard ---
# Power Kit v2 cam kết không copy MCP config vào repo.
# Check opencode-global/ templates có chứa mcp section thật không.
if grep -rE '^\s*"mcp"\s*:\s*\{' "$GLOBAL_DIR" 2>/dev/null; then
	echo -e "  ${RED}❌${NC} opencode-global/ có chứa MCP config — KHÔNG ĐƯỢC copy vào repo!"
	((++FAIL))
else
	echo -e "  ${GREEN}✅${NC} opencode-global/ không có MCP config (đúng cam kết v2)"
	((++PASS))
fi

# --- Pack validation (frontmatter for commands/agents, skills structure) ---
echo ""
echo "📦 Pack validation (commands/agents/skills frontmatter):"
if [ -x "$KIT_DIR/scripts/validate-opencode-pack.py" ] || [ -f "$KIT_DIR/scripts/validate-opencode-pack.py" ]; then
	if command -v python3 >/dev/null 2>&1; then
		if python3 "$KIT_DIR/scripts/validate-opencode-pack.py"; then
			echo -e "  ${GREEN}✅${NC} Pack validation pass"
			((++PASS))
		else
			echo -e "  ${RED}❌${NC} Pack validation fail — xem output ở trên"
			((++FAIL))
		fi
	else
		echo -e "  ${YELLOW}⚠️${NC} python3 không có — bỏ qua pack validation"
		((++WARN))
	fi
else
	echo -e "  ${YELLOW}⚠️${NC} scripts/validate-opencode-pack.py không tồn tại"
	((++WARN))
fi

echo ""
echo "[v1.3.3] Safety workflows"
check_warn "v1.3.3 /cleanup-safe command" "opencode-global/commands/cleanup-safe.md"
check_warn "v1.3.3 /handoff-save command" "opencode-global/commands/handoff-save.md"
check_warn "v1.3.3 /checkpoint command" "opencode-global/commands/checkpoint.md"
check_warn "v1.3.3 cleanup-agent-artifacts.sh" "scripts/cleanup-agent-artifacts.sh"
check_warn "v1.3.3 templates/AI_HANDOFF.md" "templates/AI_HANDOFF.md"
if grep -F -q '.opk-trash/' .gitignore 2>/dev/null; then
	echo -e "  ${GREEN}✅${NC} v1.3.3 .opk-trash/ in .gitignore"
	((++PASS))
else
	echo -e "  ${RED}❌${NC} v1.3.3 .opk-trash/ missing from .gitignore"
	((++FAIL))
fi
if grep -F -q '.opk-checkpoints/' .gitignore 2>/dev/null; then
	echo -e "  ${GREEN}✅${NC} v1.3.3 .opk-checkpoints/ in .gitignore"
	((++PASS))
else
	echo -e "  ${RED}❌${NC} v1.3.3 .opk-checkpoints/ missing from .gitignore"
	((++FAIL))
fi
if grep -q "Natural Language Auto Router" "templates/AGENTS.md" 2>/dev/null &&
	grep -q "Natural Language Auto Router" "templates/OPENCODE.md" 2>/dev/null; then
	echo -e "  ${GREEN}✅${NC} v1.3.3 Natural Language Auto Router present in AGENTS.md + OPENCODE.md"
	((++PASS))
else
	echo -e "  ${YELLOW}⚠️${NC} v1.3.3 Natural Language Auto Router missing in templates/"
	((++WARN))
fi
expected_v="1.3.3"
current_v="$(tr -d '[:space:]' <VERSION 2>/dev/null || echo unknown)"
if [ "$current_v" = "$expected_v" ]; then
	echo -e "  ${GREEN}✅${NC} v1.3.3 VERSION == $expected_v"
	((++PASS))
else
	echo -e "  ${YELLOW}⚠️${NC} v1.3.3 VERSION is '$current_v', expected '$expected_v'"
	((++WARN))
fi

echo ""
echo "=========================================="
echo "  Kết quả: ${GREEN}$PASS pass${NC} | ${RED}$FAIL fail${NC} | ${YELLOW}$WARN warn${NC}"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
	echo ""
	echo -e "${RED}❌ Có $FAIL lỗi. Hãy chạy lại install hoặc kiểm tra thủ công.${NC}"
	exit 1
else
	echo ""
	echo -e "${GREEN}✅ Project đã sẵn sàng với OpenCode Power Kit!${NC}"
fi
