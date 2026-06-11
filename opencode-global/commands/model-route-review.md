---
description: Model route review — kiểm tra routing, phân quyền, middleware, error handling
subtask: true
agent: ecc-lite-strong
---

# /model-route-review

Review routing, permissions, middleware, and error handling for backend routes.

## Cách dùng

```
/model-route-review                       # review tất cả routes
/model-route-review <path>                # review specific route
/model-route-review --api-only            # chỉ review API routes
/model-route-review --web-only            # chỉ review web routes
```

## ⚠️ Scope Guard — Review only

Model route review **CHỈ** đọc và phân tích routes. **KHÔNG** tự sửa code.

## Checks

### 1. Route structure
- RESTful naming (GET /resource, POST /resource, etc.)
- Version prefix (/api/v1/…)
- Consistent error format
- Proper HTTP status codes

### 2. Auth & permissions
- Authentication guard on protected routes
- Role/permission checks
- Public routes explicitly whitelisted
- No sensitive data in public routes

### 3. Middleware
- Rate limiting on public endpoints
- Input validation (class-validator / zod / joi)
- Request logging
- CORS configuration

### 4. Error handling
- Global error filter
- No stack trace in production
- Consistent error response shape
- Proper logging for 500 errors

## Output

```
## Model Route Review
- **Routes reviewed:** N
- **Auth issues:** N (details)
- **Validation gaps:** N (details)
- **Error handling gaps:** N (details)
- **Overall:** PASS / MINOR / BLOCKER
```

## When to use

- Khi thêm API endpoint mới
- Khi refactor routing structure
- Trước khi ship major feature
- Khi audit security
