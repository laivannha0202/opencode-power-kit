---
description: "Tiếp tục task dang dở từ AI_HANDOFF.md và .opk/work/. Đọc context, verify nhẹ, tiếp tục an toàn."
---

# /continue-work

Đọc context từ `AI_HANDOFF.md` và `.opk/work/`, xác định việc đang dở,
và tiếp tục task một cách an toàn.

## Cách dùng

```
/continue-work          # tự đọc và tiếp tục
/continue-work --dry-run # chỉ đọc, không sửa
```

## Flow

### Bước 1: Đọc AI_HANDOFF.md

```bash
cat AI_HANDOFF.md 2>/dev/null || echo "No AI_HANDOFF.md found"
```

Extract:
- Project goal
- Current task
- What changed
- Files changed
- Commands run
- Tests/verification
- Known issues
- Next recommended steps

### Bước 2: Đọc .opk/work/

```bash
ls -la .opk/work/ 2>/dev/null || echo "No .opk/work/ directory"
```

Xem các evidence files gần nhất.

### Bước 3: Git status

```bash
git status --short
```

So sánh với state trong AI_HANDOFF.md.

### Bước 4: Verify nhẹ

Chạy các lệnh verify cơ bản:
```bash
npm test -- --passWithNoTests 2>/dev/null || true
npm run lint 2>/dev/null || true
npm run typecheck 2>/dev/null || true
```

### Bước 5: Xác định việc tiếp theo

Dựa vào:
1. "Next recommended steps" trong AI_HANDOFF.md
2. Known issues chưa fix
3. Verification failures
4. Git status hiện tại

### Bước 6: Tiếp tục task

Nếu `--dry-run`: chỉ báo cáo, không sửa.

Nếu không:
- Tiếp tục theo hướng dẫn trong AI_HANDOFF.md
- Tuân thủ safety rules
- Nếu cần → chạy `/power-work-lite`

### Bước 7: Cập nhật AI_HANDOFF.md

Sau khi xong → `/handoff-save`

### Bước 8: Báo cáo

```
## Continue Work Report

**Task trước:** ...

**Trạng thái hiện tại:**
- Git: clean/dirty
- Verification: pass/fail

**Việc đã làm tiếp:**
- ...

**Files thay đổi:**
- ...

**Next steps:**
- ...
```

## Safety rules

- KHÔNG tự push.
- KHÔNG git reset --hard.
- KHÔNG xóa file.
- Nếu task quá lớn → đề xuất `/power-work-lite` thay vì tự làm.
- Luôn git status trước/sau.
- Output bằng tiếng Việt.

## Khi nào dùng

- Session mới, muốn tiếp tục task cũ
- Sau khi tắt máy/bật lại
- Khi muốn resume work dang dở
- Khi có AI_HANDOFF.md từ session trước
