---
description: Verification loop — test sau mỗi thay đổi, không làm tiếp khi chưa verify
subtask: true
agent: ecc-lite-strong
---

# /verify-loop

Verification loop: verify after every change, never stack changes without verification.

## Cách dùng

```
/verify-loop                    # auto-detect và verify
/verify-loop --test-only        # chỉ chạy test
/verify-loop --context <N>      # xem N dòng context của fail
```

## ⚠️ Scope Guard — Verify only

Verify loop **CHỈ** chạy verification commands. **KHÔNG** tự sửa code.

## Loop

```
1. Sửa code (slice ≤ 2 files, ≤ 100 dòng)
2. Chạy lint
3. Chạy typecheck
4. Chạy test
5. Chạy build
6. Nếu pass → commit / next slice
7. Nếu fail → rollback hoặc fix, quay lại bước 2
```

## Verification matrix

| Change type | Verify commands |
|-------------|----------------|
| Backend logic | `npm run lint` + `npm run test:unit` |
| API endpoint | `npm run test:e2e` + `curl` / `httpie` |
| Database schema | `prisma db push --dry-run` + `SELECT COUNT(*)` |
| Frontend component | `npm run lint` + `npm run build` |
| Refactor | Full test suite + typecheck |
| Config change | `npm run build` + dry-run |
| Migration | Backup → `SELECT COUNT(*)` → migration → verify |

## When to use

- Trong build-strong workflow
- Debug session
- Refactor code
- Database migration
- Bất kỳ task nào có nhiều hơn 1 slice

## Output

```
## Verify Loop Report
- **Slice:** {N}/{total}
- **Lint:** pass/fail
- **Typecheck:** pass/fail
- **Test:** pass/fail
- **Build:** pass/fail
- **Status:** PASS / FAIL → {next action}
```
