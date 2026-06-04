# Full-Stack Test Strategy

Chiến lược test cho dự án full-stack: FE (React/Vite) + BE (NestJS) + DB (MySQL).

## Test Pyramid

```
        /\
       /  \         E2E (Playwright)
      /----\        - happy path chính
     /      \       - 1-5 flow
    /--------\      Integration (supertest, Nest TestingModule)
   /          \     - controller + service + DB sandbox
  /------------\    Unit (Vitest/Jest)
 /              \   - service / hook / util
                  - nhanh, nhiều
```

## Phân bổ effort

- Unit: 60-70% test. Nhanh, deterministic.
- Integration: 20-30%. Test contract giữa layer.
- E2E: 5-10%. Test user flow thật. Tốn thời gian, dễ flake.

## Backend (NestJS)

### Unit test

- Framework: Jest hoặc Vitest.
- Test service với mock repo:
  ```ts
  const mockRepo = { find: jest.fn().mockResolvedValue([...]) };
  const service = new UsersService(mockRepo as any);
  expect(await service.findAll()).toEqual([...]);
  expect(mockRepo.find).toHaveBeenCalled();
  ```
- Test guard: truyền mock ExecutionContext.
- Test pipe: truyền value + metadata.
- Test interceptor: truyền mock CallHandler.
- Test util: pure function, edge case.
- KHÔNG mock quá nhiều → test trở nên vô nghĩa.

### Integration test

- Dùng `Test.createTestingModule` thật, không mock module.
- DB: dùng testcontainer (Docker MySQL) hoặc sqlite-in-memory (nếu schema đơn giản).
- Reset DB giữa test: transaction rollback hoặc truncate + migrate.
- Supertest:
  ```ts
  const app = moduleRef.createNestApplication();
  await app.init();
  return request(app.getHttpServer()).post('/auth/login').send({...});
  ```
- Test 1 module đầy đủ: controller → service → repo → DB.

### E2E test (backend)

- Boot app thật + DB thật.
- Test 1 flow lớn: register → login → create resource → fetch.
- Mỗi file test = 1 endpoint hoặc 1 flow.
- Cleanup: dùng unique email / username / ID để tránh conflict.

## Frontend (React + Vite)

### Unit test

- Vitest + React Testing Library.
- Test component render: `render(<Button>X</Button>); expect(screen.getByText('X')).toBeInTheDocument();`
- Test user interaction: `fireEvent.click / userEvent.click`.
- Test hook: `renderHook` từ RTL.
- Test util: pure function.
- KHÔNG test implementation detail (state nội bộ, ref).

### Mock API

- MSW (Mock Service Worker) cho unit test:
  ```ts
  const handlers = [
    http.get('/api/users', () => HttpResponse.json([{ id: 1, name: 'A' }])),
  ];
  const server = setupServer(...handlers);
  beforeAll(() => server.listen());
  afterEach(() => server.resetHandlers());
  ```
- Ưu tiên MSW hơn jest.mock — gần với production hơn.

### Integration test (FE)

- Test component + API client + state:
  - Render component gọi API qua React Query.
  - MSW trả về data mẫu.
  - Assert UI render đúng sau khi data về.
- Test form: điền + submit + assert callback / navigate.

### E2E test (Playwright)

- Test trên browser thật (Chromium / Firefox / WebKit).
- Mỗi file = 1 user flow:
  - `auth.spec.ts`: login, logout, register.
  - `users.spec.ts`: list, create, edit, delete.
  - `checkout.spec.ts`: add to cart → checkout → success.
- Page Object Model cho element + action tái sử dụng.
- Test data: dùng fixture / factory, không hardcode ID.
- Chạy song song: `test.describe.parallel`.
- Retry: 1 lần cho CI.

## Database

### Schema test

- Migration test: chạy `migrate:up` rồi `migrate:down` phải clean.
- Seed test: chạy seed trên DB test, assert row count.
- FK constraint: assert orphan không thể insert.

### Query test

- Test repo function với DB thật (sandbox).
- Test N+1: dùng query log, assert số query.
- Test pagination: cursor / offset hoạt động đúng ở boundary.

## Smoke test

- Sau build: start app + curl health endpoint.
- Lệnh: `curl -f http://localhost:3000/health` (exit non-zero nếu fail).
- Chạy trong CI sau khi build production.

## CI gate

- Mỗi PR:
  - Unit test (BE + FE) chạy song song.
  - Lint + typecheck.
  - Build (BE + FE).
  - Integration test BE (testcontainer).
- Nightly hoặc trước release:
  - E2E Playwright.
  - Smoke test trên staging.
  - Performance test (k6 / artillery) nếu cần.

## Anti-pattern cần tránh

- ❌ Test implementation detail (state nội bộ, ref).
- ❌ Snapshot test quá nhiều (fragile, không bắt logic).
- ❌ E2E cho unit case (login fail → vẫn phải test ở service).
- ❌ Test phụ thuộc network thật (gọi API thật từ internet).
- ❌ Test không reset state → flake.
- ❌ Skip test khi `it.skip` — fix hoặc xóa.
- ❌ Mock quá nhiều → test pass nhưng prod fail.

## Reference

- [Vitest](https://vitest.dev)
- [React Testing Library](https://testing-library.com/react)
- [NestJS testing](https://docs.nestjs.com/fundamentals/testing)
- [Playwright](https://playwright.dev)
- [MSW](https://mswjs.io)
- [Testcontainers](https://testcontainers.com)
