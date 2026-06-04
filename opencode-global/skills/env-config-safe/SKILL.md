# Env Config Safe

Quy tắc quản lý env config an toàn cho dự án.

## File convention

| File | Commit? | Mục đích |
|------|---------|----------|
| `.env` | KHÔNG | Giá trị thật local, ignore khỏi git |
| `.env.example` | CÓ | Template, placeholder, giá trị giả |
| `.env.sample` | CÓ | Tương tự `.env.example` |
| `.env.local` | KHÔNG | Override local dev, gitignore |
| `.env.development` | KHÔNG | Auto-load bởi framework dev mode |
| `.env.production` | KHÔNG | Auto-load bởi framework prod mode |
| `.env.test` | CÓ (nếu không có secret) | Giá trị test cố định |

## Quy tắc `.gitignore`

```gitignore
.env
.env.local
.env.*.local
.env.production
# .env.example KHÔNG ignore — phải commit
```

## `.env.example` chuẩn

- Comment mỗi biến: mô tả, ví dụ, required?
- Placeholder rõ ràng: `DB_HOST=localhost` KHÔNG `DB_HOST=your-host`.
- Không chứa secret thật.
- Phân nhóm: `# --- Database ---`, `# --- Auth ---`, `# --- External ---`.

```bash
# --- Database ---
DB_HOST=localhost
DB_PORT=3306
DB_USER=app
DB_PASS=changeme          # placeholder
DB_NAME=app

# --- Auth ---
JWT_SECRET=change-me-32-chars-minimum
JWT_EXPIRES_IN=15m
REFRESH_EXPIRES_IN=7d

# --- External API ---
STRIPE_API_KEY=sk_test_replace_me
```

## Validation lúc boot

- Dùng schema validate env (Joi, Zod, class-validator).
- Fail-fast: app không boot nếu thiếu var bắt buộc.
- Log warning (không log value) khi dùng default fallback.

```ts
import { z } from 'zod';
const envSchema = z.object({
  DB_HOST: z.string().min(1),
  DB_PORT: z.coerce.number().int().positive(),
  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 chars'),
  NODE_ENV: z.enum(['development', 'test', 'production']),
});
const env = envSchema.parse(process.env);
```

## Frontend (Vite)

- Chỉ biến prefix `VITE_` mới expose ra client.
- Tên khác: undefined trong browser (dùng `import.meta.env`).
- KHÔNG đặt secret backend trong `.env` FE. Secret phải ở BE.

## Backend (NestJS / Express)

- Dùng `@nestjs/config` với schema validate.
- Truy cập qua `ConfigService` thay vì `process.env` rải rác.
- Test:
  - `.env.test` giá trị cố định.
  - Mock `ConfigService` trong unit test.

## Secret trong production

- Inject qua Docker / k8s env, không bake vào image.
- Cloud secret manager: AWS Secrets Manager / Vault / Doppler.
- Rotation: lên lịch định kỳ.
- Audit: log khi đọc secret nhạy cảm (không log value).

## Anti-pattern cần tránn

- ❌ Commit `.env` chứa value thật.
- ❌ `.env.example` chứa secret placeholder trông giống thật (`JWT_SECRET=abc123`).
- ❌ `process.env.X` rải rác khắp code (khó test, khó validate).
- ❌ Default fallback cho secret (`JWT_SECRET || 'dev-secret'` — rủi ro lên prod).
- ❌ Log env value lúc boot.
- ❌ Dùng `dotenv` trong code đã có framework config.
- ❌ Frontend `.env` chứa secret backend.

## Reference

- [The Twelve-Factor App - Config](https://12factor.net/config)
- [dotenv](https://github.com/motdotla/dotenv)
- [Zod](https://zod.dev)
- [@nestjs/config](https://docs.nestjs.com/techniques/configuration)
