---
description: Kiểm tra API contract giữa frontend và backend
agent: review-lite
---

## ⚠️ Scope Guard — Review contract, KHÔNG tự implement

Api-contract-review chỉ review và phân tích drift. **KHÔNG** tự sửa code khi user chỉ yêu cầu
review. Nếu task là docs-only → STOP, dùng main agent.

Kiểm tra API contract giữa frontend và backend:
- Endpoint khớp: method, path, query, body shape.
- Type khớp: string/number/boolean/null, required vs optional, enum values.
- Status code: 200/201/400/401/403/404/422/500 đúng ngữ nghĩa.
- Error format: field, code, message — có nhất quán không?
- Auth header: Bearer/JWT/Cookie — có khớp giữa 2 phía?
- Pagination, filter, sort: cursor vs offset, stable order.
- Breaking change: field rename, type change, removed field.

So sánh OpenAPI/Schema (nếu có) với code thật. Output bảng: Endpoint | Drift | Fix.
Nếu không có schema: dựng schema tối thiểu rồi check.
