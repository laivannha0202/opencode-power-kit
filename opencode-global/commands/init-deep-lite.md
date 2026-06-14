---
description: "Khởi tạo project context — đọc project, tạo/cập nhật AGENTS.md, OPENCODE.md, AI_HANDOFF.md, docs/PROJECT_CONTEXT.md, docs/WORKFLOW.md. Không ghi đè nội dung user."
---

# /init-deep-lite

Đọc project hiện tại và khởi tạo project context files.
Phiên bản gọn, an toàn — không ghi đè nội dung user.

## Cách dùng

```
/init-deep-lite           # tự detect và tạo/cập nhật
/init-deep-lite --force   # append section mới kể cả file tồn tại
```

## Flow

### Bước 1: Git status

```bash
git status --short
```

Ghi lại trạng thái working tree trước khi bắt đầu.

### Bước 2: Đọc project

- Đọc `README.md` (nếu có)
- Đọc `package.json` (nếu có)
- Đọc `tsconfig.json` / `vite.config.*` / `next.config.*` (nếu có)
- Đọc `prisma/schema.prisma` / `ormconfig` (nếu có)
- Đọc `docker-compose.yml` (nếu có)
- Xác định: language, framework, DB, key scripts

### Bước 3: Tạo/cập nhật files

#### 3.1. `AGENTS.md` (project root)

- **Nếu chưa tồn tại:** Copy từ `templates/AGENTS.md` (nếu OPK installed) hoặc tạo mới với nội dung cơ bản.
- **Nếu đã tồn tại:** KHÔNG ghi đè. Nếu `--force`, append section mới:

```markdown
<!-- OPK_INIT_DEEP_LITE_START -->
## Project Auto-Generated Context

- Language: ...
- Framework: ...
- DB: ...
- Key scripts: ...
- Detected at: YYYY-MM-DD
<!-- OPK_INIT_DEEP_LITE_END -->
```

#### 3.2. `OPENCODE.md` (project root)

- **Nếu chưa tồn tại:** Tạo mới với nội dung cơ bản.
- **Nếu đã tồn tại:** KHÔNG ghi đè. Append nếu `--force`.

#### 3.3. `AI_HANDOFF.md` (project root)

- **Nếu chưa tồn tại:** Copy từ `templates/AI_HANDOFF.md` và điền thông tin detected.
- **Nếu đã tồn tại:** Cập nhật dynamic sections (Current task, Stack) giữ nguyên user content.

#### 3.4. `docs/PROJECT_CONTEXT.md`

- Tạo mới nếu chưa có.
- Nội dung: project goal, stack, architecture overview, key decisions.
- Nếu đã có → KHÔNG sửa.

#### 3.5. `docs/WORKFLOW.md`

- Tạo mới nếu chưa có.
- Nội dung: workflow hiện tại, commands hay dùng, test commands.
- Nếu đã có → KHÔNG sửa.

### Bước 4: Git status sau

```bash
git status --short
```

### Bước 5: Báo cáo

```
## Init Deep Lite Report

**Files đã tạo:**
- AGENTS.md (mới)
- docs/PROJECT_CONTEXT.md (mới)

**Files đã append:**
- AI_HANDOFF.md (cập nhật Stack section)

**Files giữ nguyên (đã tồn tại):**
- OPENCODE.md (user content preserved)

**Files không tìm thấy:**
- package.json (không detect Node project)

**Git status:**
- Working tree: clean/dirty
- New files: AGENTS.md, docs/PROJECT_CONTEXT.md
```

## Safety rules

- KHÔNG ghi đè file đã tồn tại (trừ khi `--force` append section có marker).
- KHÔNG sửa .env, secrets, tokens.
- KHÔNG commit.
- KHÔNG push.
- KHÔNG xóa file.
- Luôn chạy git status trước/sau.
- Output bằng tiếng Việt.

## Marker format

Section mới luôn có marker rõ ràng:

```
<!-- OPK_INIT_DEEP_LITE_START -->
...nội dung...
<!-- OPK_INIT_DEEP_LITE_END -->
```

Để phân biệt với nội dung user và cho phép remove dễ dàng.
