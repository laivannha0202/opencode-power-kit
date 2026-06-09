---
description: Audit chính opencode-power-kit — cấu trúc, agents, commands, skills, version, best practices
---

# /kit-audit

Audit toàn bộ opencode-power-kit để đảm bảo cấu trúc đúng, version nhất quán, không lỗi.

## ⚠️ Scope Guard — Audit kit, KHÔNG tự sửa code

Kit-audit chỉ audit và báo cáo. **KHÔNG** tự sửa code khi user chỉ yêu cầu audit. Nếu task là
docs-only → chỉ audit docs, không tạo Todo implementation.

## Checks

### 1. VERSION consistency
- `VERSION` file = `CHANGELOG.md` version mới nhất?
- README badge version khớp?
- Verify script `EXPECTED_VERSION` khớp?

### 2. Agent coverage
- `opencode-global/agents/` — mỗi agent có frontmatter đủ? description + mode?
- Agent mode hợp lý (all / subagent)?

### 3. Command coverage
- `opencode-global/commands/` — mỗi command có description frontmatter?
- Tên command unique?

### 4. Skill coverage
- `opencode-global/skills/*/SKILL.md` — mỗi skill có heading + body?
- Skill không empty?

### 5. Script checks
- `scripts/*.sh` — `bash -n` pass?
- `scripts/*.py` — `python3 -m py_compile` pass?

### 6. Verify scripts
- `verify.sh` có check đủ agents/commands mới?
- `validate-opencode-pack.py` EXPECTED_VERSION đúng?
- `verify.ps1` mirror verify.sh?

### 7. CHANGELOG completeness
- Version bump recorded?
- All new features documented?
- Backward compatibility stated?

### 8. .gitignore
- Artifact dirs ignored? `.opk-*`, `.tmp`, `.test`

## Output
```
## Kit Audit Report
- **VERSION:** v{current} (consistent ✓)
- **Agents:** N (frontmatter ok ✓)
- **Commands:** N (frontmatter ok ✓)
- **Skills:** N (heading+body ok ✓)
- **Scripts:** bash -n ✓ / python compile ✓
- **Verify:** verify.sh ✓ / validate.py ✓
- **Issues:** N (details)
- **Overall health:** GOOD / NEEDS_FIX
```
