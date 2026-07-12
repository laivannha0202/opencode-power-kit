---
description: Backend HTTP/API route review — review routing structure, auth, permissions, middleware, validation, error handling
subtask: true
agent: ecc-lite-strong
---

# /backend-route-review

Review backend HTTP/API routes: routing structure, permissions, middleware, and error handling.

**Scope:** Backend route review only — KHÔNG liên quan đến model selection, model routing, hay AI model choice.

## Cách dùng

```
/backend-route-review                       # review tất cả routes
/backend-route-review <path>                # review specific route
/backend-route-review --api-only            # chỉ review API routes
/backend-route-review --web-only            # chỉ review web routes
```

## Scope Guard — Review only

`/backend-route-review` **CHỈ** đọc và phân tích routes. **KHÔNG** tự sửa code.

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
## Backend Route Review
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
