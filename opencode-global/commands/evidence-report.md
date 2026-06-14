---
description: "Tổng hợp evidence report — git status, git diff, test/verify, files changed, technical decisions. Xuất báo cáo tiếng Việt."
---

# /evidence-report

Tổng hợp evidence hiện tại thành báo cáo tiếng Việt rõ ràng.

## Cách dùng

```
/evidence-report         # báo cáo full
/evidence-report --short # báo cáo ngắn
```

## Flow

### Bước 1: Git status

```bash
git status --short
```

### Bước 2: Git diff

```bash
git diff --stat
git diff --cached --stat
```

### Bước 3: Git log gần nhất

```bash
git log --oneline -5
```

### Bước 4: Verify summary

Kiểm tra các lệnh verify đã chạy gần nhất:
- test result
- lint result
- typecheck result
- build result

### Bước 5: Đọc .opk/work/

```bash
ls -la .opk/work/ 2>/dev/null || echo "No evidence files"
```

### Bước 6: Đọc AI_HANDOFF.md

```bash
cat AI_HANDOFF.md 2>/dev/null || echo "No handoff file"
```

### Bước 7: Xuất báo cáo

```
## Evidence Report

**Ngày:** YYYY-MM-DD HH:MM
**Branch:** ...

### Git Status
- Working tree: clean/dirty
- Staged: N files
- Unstaged: N files
- Untracked: N files

### Changes (git diff --stat)
- file1: +10 -5
- file2: +3 -0

### Recent Commits
- abc1234: commit message
- def5678: commit message

### Verification Status
- Test: PASS ✓ / FAIL ✗ / NOT RUN —
- Lint: PASS ✓ / FAIL ✗ / NOT RUN —
- Typecheck: PASS ✓ / FAIL ✗ / NOT RUN —
- Build: PASS ✓ / FAIL ✗ / NOT RUN —

### Evidence Files
- .opk/work/20260614-xxxxx.md: task description

### Technical Decisions
- ...

### Known Issues
- ...

### Files Changed (detail)
| File | Action | Reason |
|------|--------|--------|
| path/to/file | modified | ... |

### Remaining Work
- ...
```

## Output format

Luôn bằng tiếng Việt. Thuật ngữ kỹ thuật giữ tiếng Anh khi cần.

## Safety rules

- KHÔNG sửa file nào.
- KHÔNG commit.
- KHÔNG push.
- Chỉ đọc và báo cáo.
- Output bằng tiếng Việt.
