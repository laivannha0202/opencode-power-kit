# ADR — Architecture Decision Record

Skill viết ADR ngắn gọn cho mỗi quyết định kiến trúc quan trọng.

## Khi nào viết

- Chọn framework / library mới (Vue vs React, Prisma vs Drizzle).
- Thay đổi data model có ảnh hưởng rộng.
- Quyết định infra (Postgres vs Mongo, self-host vs SaaS).
- Quy ước mới (folder structure, naming, module boundary).
- Không viết ADR cho: bug fix nhỏ, refactor local, config tweak.

## Format (Michael Nygard)

File: `docs/adr/NNNN-title-with-dashes.md`

```markdown
# NNNN. Tiêu đề ngắn

- **Status:** Proposed | Accepted | Deprecated | Superseded by NNNN
- **Date:** YYYY-MM-DD
- **Deciders:** ai quyết

## Context
Vấn đề gì? Bối cảnh ra sao? Force nào đang đè (time, skill, cost, scale)?

## Decision
Chọn gì? Sơ lược 1-2 đoạn.

## Consequences
### Positive
- Lợi gì?

### Negative
- Mất gì, đánh đổi gì?

### Risks
- Rủi ro cần theo dõi?

## Alternatives Considered
- Phương án A: ... tại sao không chọn.
- Phương án B: ... tại sao không chọn.

## References
- Link doc, RFC, benchmark, prior art.
```

## Quy tắc

- 1 ADR = 1 quyết định. Không nhét nhiều thứ.
- Ngắn (1-2 trang). Reviewer đọc trong 5 phút.
- Status cập nhật khi superseded.
- Không xóa ADR cũ — chỉ đánh `Superseded by NNNN`.

## Workflow

1. Phát hiện cần quyết định kiến trúc.
2. Viết ADR với status `Proposed`.
3. Review với team / stakeholder.
4. Update status `Accepted` (hoặc `Rejected`).
5. Implement + link từ code (comment `// see ADR-0007`).

## Output

- File path ADR mới.
- Tóm tắt 1 đoạn cho PR description.
- Liệt kê ADR cũ có liên quan (supersede).
