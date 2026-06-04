# OpenAPI Contract

Quy tắc viết + review OpenAPI spec cho API NestJS / Express / bất kỳ stack nào.

## Spec location

- `openapi.yaml` / `openapi.yml` / `openapi.json` ở repo root.
- `swagger/` hoặc `api/` nếu project quy lớn.
- Backend (NestJS): generate từ `@nestjs/swagger` decorator + serve ở `/api/docs`.
- Backend (Express): viết tay + serve qua `swagger-ui-express`.

## Cấu trúc tối thiểu

```yaml
openapi: 3.1.0
info:
  title: <App Name> API
  version: 1.0.0
  description: |
    Mô tả ngắn. Auth flow, base path, version policy.
servers:
  - url: https://api.example.com
    description: Production
  - url: http://localhost:3000
    description: Local dev
tags:
  - name: auth
  - name: users
  - name: posts
paths:
  /auth/login:
    post:
      tags: [auth]
      summary: Login bằng email + password
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/LoginRequest'
      responses:
        '200':
          description: OK
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/LoginResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  schemas:
    LoginRequest:
      type: object
      required: [email, password]
      properties:
        email: { type: string, format: email }
        password: { type: string, minLength: 8 }
    LoginResponse:
      type: object
      required: [accessToken, refreshToken, user]
      properties:
        accessToken: { type: string }
        refreshToken: { type: string }
        user: { $ref: '#/components/schemas/User' }
  responses:
    Unauthorized:
      description: Thiếu / sai token
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/ErrorResponse'
```

## Conventions

- Version trong URL (`/v1/...`) hoặc header (`Accept: application/vnd.api+json;v=1`).
- Path: noun, số nhiều nếu resource là collection (`/users`, `/posts`).
- Method: GET (read), POST (create), PUT/PATCH (update), DELETE (remove).
- Status: 200 (read/update), 201 (create), 204 (delete no body), 400 (validation), 401 (auth), 403 (permission), 404 (not found), 409 (conflict), 422 (unprocessable), 429 (rate limit), 500 (server).
- Error response: nhất quán format. Đề xuất:
  ```json
  { "error": { "code": "USER_NOT_FOUND", "message": "User không tồn tại", "details": [] } }
  ```
- Pagination:
  - Offset: `?page=1&limit=20` → response kèm `total`, `page`, `limit`.
  - Cursor: `?cursor=abc&limit=20` → response kèm `nextCursor`.
  - Có `total` (offset) hoặc `hasMore` (cursor).
- Filter: `?status=active&sort=-createdAt`.
- Sort: prefix `-` = desc, `+` hoặc không = asc.

## Reusability

- `$ref` cho mọi schema lặp lại.
- Tách `components/schemas/`, `components/responses/`, `components/parameters/`.
- Tách `components/securitySchemes/` nếu nhiều cách auth.
- Tránh inline schema phức tạp.

## Security

- `securitySchemes` định nghĩa rõ: bearer, apiKey, oauth2.
- Áp dụng global hoặc per-operation.
- Không định nghĩa scope mơ hồ. Scope cụ thể: `users:read`, `users:write`.

## Validation

- Spec phải khớp code thật. Drift = bug.
- Tool: `spectral` lint + `oasdiff` so version.
- Generate client từ spec (openapi-generator) thay vì viết tay.
- Nếu dùng `@nestjs/swagger`: CI check CLI thật = CLI lý thuyết (spectral lint).

## Anti-pattern cần tránn

- ❌ `additionalProperties: true` mọi nơi (mất type safety).
- ❌ Status code sai ngữ nghĩa (200 cho lỗi).
- ❌ Error response format mỗi endpoint một kiểu.
- ❌ Spec drift so với code (FE/BE mất đồng bộ).
- ❌ Định nghĩa schema trùng lặp, không ref.
- ❌ `nullable: true` không nhất quán (OpenAPI 3.0 dùng `nullable`, 3.1 dùng `type: ['string', 'null']`).

## Reference

- [OpenAPI 3.1 spec](https://spec.openapis.org/oas/v3.1.0)
- [Stoplight Spectral](https://stoplight.io/open-source/spectral)
- [oasdiff](https://github.com/oasdiff/oasdiff)
- [NestJS Swagger](https://docs.nestjs.com/openapi/introduction)
