---
description: "Workflow làm việc dài an toàn, Vietnamese-first. Lấy cảm hứng từ ultrawork nhưng giữ safety rules strict. Plan → Build → Verify → Evidence."
---

# /power-work-lite

Phiên bản an toàn, gọn, Vietnamese-first của long work workflow.
Lấy cảm hứng từ oh-my-openagent ultrawork, nhưng KHÔNG copy code.

## Cách dùng

```
/power-work-lite <mô tả task>
/power-work-lite "thêm tính năng login với Google OAuth"
/power-work-lite "fix bug payment service không process được"
/power-work-lite "refactor user module theo clean architecture"
```

## Scope Guard

Nếu task chứa keyword "chỉ kiểm tra", "read-only", "docs-only":
→ Chạy `/intent-router` trước, KHÔNG route sang build-strong.
→ Chỉ đọc + báo cáo.

## Workflow (10 bước)

### Bước 1: Git status

```bash
git status --short
```

Ghi lại trạng thái. Nếu dirty → báo danh sách files.

### Bước 2: Đọc project context

- `README.md`, `package.json`, config chính
- `AGENTS.md`, `OPENCODE.md` (nếu có)
- `AI_HANDOFF.md` (nếu có task dang dở)

### Bước 3: Xác định mục tiêu

Phân tích request của user:
- Intent chính là gì?
- Có multi-intent không?
- Rủi ro: DB change? API change? Breaking change?

### Bước 4: Tạo plan ngắn

```
## Plan

**Goal:** ...

**Steps:**
1. [step] — files: ... — verify: ...
2. [step] — files: ... — verify: ...
3. ...

**Checkpoint needed:** Có/Không
**Estimated slices:** N
```

### Bước 5: Chọn agent/workflow

Dựa vào intent:
- Feature → `build-strong` / `build-slice`
- Bug → `debug-strong`
- Test → `qa-strong`
- Security → `security-strong`
- DB → `db-strong`
- API → `api-strong`
- UI → `ui-ux-strong`

### Bước 6: Checkpoint (nếu cần)

Nếu task lớn (> 3 files hoặc có migration):
```bash
/checkpoint
```

### Bước 7: Build theo lát nhỏ

Mỗi slice:
1. Sửa ≤ 2 files, ≤ 100 dòng diff
2. Chạy verify phù hợp
3. Nếu fail → báo rõ fail gì, KHÔNG nói đã xong

### Bước 8: Verify

```bash
# Tùy project
npm test / pnpm test
npm run lint / pnpm lint
npm run typecheck / pnpm typecheck
npm run build / pnpm build
```

Nếu không có test → manual proof rõ ràng.

### Bước 9: Lưu evidence

Tạo file trong `.opk/work/`:

```bash
mkdir -p .opk/work
cat > .opk/work/<timestamp>-<task-slug>.md << 'EOF'
# Evidence: <task name>

**Date:** YYYY-MM-DD HH:MM
**Branch:** ...

## Changes
- file1: mô tả
- file2: mô tả

## Verification
- test: PASS/FAIL
- lint: PASS/FAIL
- build: PASS/FAIL

## Commands run
- `command1`
- `command2`

## Notes
...
EOF
```

### Bước 10: Cập nhật AI_HANDOFF.md

Nếu task dài (> 30 phút hoặc > 5 files):
```bash
/handoff-save
```

### Bước 11: Báo cáo tiếng Việt

```
## Work Report

**Task:** ...

**Đã làm:**
1. [step] — status: done
2. [step] — status: done

**Files đã sửa:**
- path/to/file1: mô tả
- path/to/file2: mô tả

**Verify:**
- test: PASS ✓
- lint: PASS ✓
- build: PASS ✓

**Evidence:** .opk/work/20260614-xxxxx.md

**Rủi ro còn lại:**
- ...

**Việc nên làm tiếp:**
- ...
```

## Hard rules (bắt buộc)

1. **KHÔNG tự push** nếu user chưa yêu cầu rõ.
2. **KHÔNG git reset --hard**.
3. **KHÔNG git clean -fd**.
4. **KHÔNG xóa file user**.
5. **KHÔNG sửa .env/secrets/tokens**.
6. **Nếu test fail** → báo rõ fail gì, KHÔNG nói đã xong.
7. **Luôn git status trước/sau**.
8. **Luôn output bằng tiếng Việt**.
9. **Slice ≤ 2 files, ≤ 100 dòng diff** mỗi lần.

## Khi nào dùng

- Task > 3 files
- Task > 30 phút
- Task cần nhiều step
- Task cần verify nhiều loại
- Task cần evidence trail
- Task cần handoff giữa sessions
