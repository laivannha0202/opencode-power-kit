# API Contract Review

Skill review contract giữa frontend và backend, hoặc giữa 2 service.

## Cần check

### Endpoint shape
- Method (GET/POST/PUT/PATCH/DELETE) đúng ngữ nghĩa không.
- Path naming: nhất quán `/resource` hay `/resources`, có version prefix không.
- Query string vs body: GET không có body, POST/PUT có body.

### Type contract
- Field type: string/number/boolean/null/object/array.
- Required vs optional (không tin tưởng optional mà crash).
- Enum values khớp giữa 2 phía.
- Date format: ISO 8601 string, không timestamp int (trừ khi cố ý).
- Number: int vs float, currency thì dùng string để tránh float precision.

### Status code
- 200 OK, 201 Created (POST), 204 No Content (DELETE).
- 400 Bad Request (validation), 401 Unauthorized, 403 Forbidden.
- 404 Not Found, 409 Conflict (duplicate), 422 Unprocessable.
- 500 Internal Server Error (không leak stack ra response).

### Error response
- Format nhất quán: `{ "error": { "code": "...", "message": "..." } }`.
- Code machine-readable, message human-readable.
- Validation error kèm field-level detail.

### Auth
- Bearer / JWT / Cookie / API key — 2 phía khớp nhau.
- Refresh token flow: rotation, expiry.
- CORS preflight đúng cho credentialed request.

### Pagination & filter
- Cursor-based (ưu tiên) hoặc offset-based.
- Stable order (có `ORDER BY` không ambiguous).
- Total count: có hay không, có cache không.

### Breaking change detection
- Field rename / type change / removed field.
- Bump version (URI hoặc header).
- Deprecation window.

## Workflow

1. Lấy schema: OpenAPI/Swagger/GraphQL SDL/Proto/TS types.
2. So sánh với code thật (rg trong handler, route).
3. Nếu không có schema: dựng schema tối thiểu từ code.
4. Liệt kê drift ra bảng.

## Output
| Endpoint | Drift Type | Expected | Actual | Severity | Fix |

Không tự sửa — chỉ report. Severity: BREAKING (block) | MAJOR | MINOR.
