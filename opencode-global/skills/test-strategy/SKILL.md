# Test Strategy

Skill đề xuất và chạy test chứng minh tính đúng, phù hợp từng task.

## Test pyramid (ưu tiên)

1. **Unit test** (nhiều nhất, nhanh nhất): function/module thuần, mock IO.
2. **Integration test**: 2-3 module + DB thật (sandbox) hoặc container.
3. **E2E test** (ít nhất, chậm nhất): full flow user, Playwright/Cypress.

## Chọn test theo task

### Bug fix
- Repro test viết trước (red), fix code, test pass (green).
- Cover edge case input gần bug.

### Feature mới
- Happy path: 1 test đủ.
- Edge case: input rỗng, null, max, unicode, concurrent.
- Error path: invalid input, timeout, network fail.

### Refactor
- Đảm bảo test hiện có pass.
- Thêm test nếu coverage lỗ hổng.

## Test framework theo stack

- Node/TS: Vitest > Jest. Dùng `pnpm test --run` để CI mode.
- Python: pytest, dùng fixture cho DB.
- Go: stdlib `testing` + testify cho assert.
- Rust: `#[test]`, cargo test.
- Frontend: Vitest + Testing Library, Playwright cho E2E.

## Minimal infra (khi chưa có)

Không có test infra? Dựng 1 file:
```js
// test/smoke.test.js (vitest)
import { describe, it, expect } from 'vitest';
import { func } from '../src/func.js';
describe('func', () => {
  it('handles happy path', () => {
    expect(func('input')).toBe('expected');
  });
});
```

## Test data

- Dùng factory/fixture, không hardcode.
- Reset DB giữa test (transaction rollback hoặc truncate).
- Tránh data thật (PII) trong test.

## CI integration

- Test phải chạy được trong CI (no interactive).
- Tốc độ < 5 phút cho unit + integration.
- E2E tách riêng, chạy trên PR + nightly.

## Output

- Chạy test: paste output pass/fail, số test, duration.
- Đề xuất: list test case còn thiếu.
- Coverage delta: dòng % trước/sau.

Không chạy test trên prod DB. Không test với data thật có PII.
