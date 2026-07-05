# Weak Model Guide

> Hướng dẫn cho model yếu / flash / low-cost làm việc với OpenCode Power Kit.

## Core Rules

- Luôn chạy `git status --short` đầu tiên.
- Không edit quá 2 file trong một slice trừ khi được yêu cầu rõ ràng.
- Không chạy các lệnh phá hủy:
  - `rm -rf`
  - `git reset --hard`
  - `git clean -fd`
  - `git push --force`
- Nếu task không rõ, chỉ inspect và report — không tự ý sửa.
- Không sửa `.env`, secrets, tokens, credentials, hoặc private keys.
- Ưu tiên slice nhỏ:
  - backend slice
  - frontend slice
  - database slice
  - test slice
  - docs slice
- Sau khi edit, chạy validation nhỏ nhất liên quan.
- Báo cáo cuối phải có:
  - files changed
  - commands run
  - validation result
  - remaining risks

## Full-stack Task Pattern

Với task full-stack, dùng thứ tự sau:

1. Hiểu request và scope.
2. Inspect routes, services, UI pages, database models hiện có.
3. Đề xuất plan ngắn.
4. Implement một slice.
5. Validate.
6. Report evidence.
7. Chỉ tiếp tục nếu slice tiếp theo rõ ràng.

## Recommended Commands

Dùng các lệnh scope-lite:

- `/intent-router`
- `/plan-work`
- `/build-slice`
- `/test-proof`
- `/evidence-report`

## Anti-patterns

Tránh các prompt quá rộng:

```
❌  fix all
❌  complete everything
❌  rewrite project
```

Thay bằng prompt chính xác:

```
✅  Fix only the login API validation bug. Do not edit more than 2 files.
✅  Add the missing try/catch to the Stripe checkout handler. No refactoring.
```

## Validation Trước Commit

Luôn chạy trước commit:

```bash
python3 scripts/validate-formatting.py
python3 scripts/audit-upstreams.py --check
python3 scripts/validate-opencode-pack.py
bash verify.sh
bash doctor.sh
git status --short
```

## Xem thêm

- `docs/LOCAL_VALIDATION.md` — Quy trình local validation đầy đủ
- `docs/safety.md` — Mô hình an toàn
- `templates/opencode.safe.json` — Safe Mode config
- `templates/AGENTS.md` — Agent delegation reference
