# Full-Stack Test Strategy

Test pyramid cho dự án full-stack. (Bản global, áp dụng mọi stack.)

## Pyramid

```
        /\
       /  \         E2E (Playwright / Cypress)
      /----\        - 1-10 user flow chính
     /      \       - chạy nightly hoặc pre-release
    /--------\      Integration
   /          \     - controller + service + DB sandbox
  /            \    - 20-30% effort
 /--------------\   Unit
/                \  - service / hook / util / pure function
                  - 60-70% effort
```

## Phân bổ theo layer

### Backend (NestJS / Express / Fastify)

- **Unit:** test service / guard / pipe / interceptor. Mock repo. Vitest hoặc Jest.
- **Integration:** test module NestJS + DB sandbox. `Test.createTestingModule`. Supertest.
- **E2E:** boot app thật + DB thật. Test 1 flow lớn.
- **Smoke:** `curl /health` sau build.

### Frontend (React / Vue / Svelte)

- **Unit:** component / hook / util. React Testing Library + Vitest.
- **Mock API:** MSW (Mock Service Worker) thay vì `jest.mock`.
- **Integration:** component + API + state. Test render sau khi data về.
- **E2E:** Playwright. Test user flow trên browser thật.

### Database

- **Migration test:** `migrate:up` rồi `migrate:down` phải clean.
- **Schema test:** FK constraint, index đúng.
- **Query test:** repo function với DB sandbox.
- **N+1 detection:** đếm query qua log.

### API contract

- **Contract test:** so OpenAPI spec với handler thật.
- **Drift detection:** spectral + oasdiff.

## CI gate

| Stage | Unit | Integration | E2E | Smoke | Lint | Type | Build |
|-------|------|-------------|-----|-------|------|------|-------|
| Mỗi PR | ✓ | ✓ | – | – | ✓ | ✓ | ✓ |
| Merge main | ✓ | ✓ | – | – | ✓ | ✓ | ✓ |
| Nightly | ✓ | ✓ | ✓ | – | – | – | – |
| Pre-release | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

## Test data

- Fixture: file JSON / factory function. Không hardcode ID.
- Faker: dùng `@faker-js/faker` cho data giả realistic.
- DB seed: riêng file `seed.ts`, gọi khi cần.
- Reset giữa test: transaction rollback (nhanh) hoặc truncate + migrate (chậm, an toàn).
- Parallel test: dùng DB riêng cho mỗi worker.

## Coverage

- Target: 70-80% cho unit test. Không 100% (ROI thấp).
- Branch coverage quan trọng hơn line coverage.
- Critical path (auth, payment) phải cover kỹ.
- Generated code, type definition, migration: exclude.

## Anti-pattern cần tránn

- ❌ E2E test cho unit case (login fail vẫn test ở service).
- ❌ Mock quá nhiều → test pass nhưng prod fail.
- ❌ Test implementation detail (state nội bộ, ref).
- ❌ Snapshot quá nhiều (fragile, không bắt logic).
- ❌ Test phụ thuộc network thật.
- ❌ `it.skip` còn lại trong codebase.
- ❌ Coverage thấp nhưng force 100% → test vô nghĩa.

## Reference

- [Martin Fowler - TestPyramid](https://martinfowler.com/bliki/TestPyramid.html)
- [Google Testing Blog](https://testing.googleblog.com/)
- [Playwright best practices](https://playwright.dev/docs/best-practices)
- [NestJS testing](https://docs.nestjs.com/fundamentals/testing)
- [MSW](https://mswjs.io)
