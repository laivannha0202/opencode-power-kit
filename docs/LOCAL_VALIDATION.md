# Local Validation

> OpenCode Power Kit v2.1.0 là bản **Linux-only**. Kiểm thử local Linux là
> nguồn xác nhận phát hành chính thức của repository.

## Nguyên tắc

- Chỉ hỗ trợ kernel Linux (`uname -s` phải trả về `Linux`).
- Không phát hành kèm PowerShell, CMD, BAT hoặc bộ kiểm thử Windows.
- Không dùng GitHub Actions làm release gate; thư mục workflow được giữ trống.
- Mọi thay đổi phải vượt qua `scripts/release-gate.sh` trước khi merge.
- Release gate phải trả exit code `0`; không đổi failure thành warning hay skip.
- Không tạo tag/release nếu working tree chứa thay đổi ngoài phạm vi.

## Các lệnh validation

### 0. Platform contract

```bash
test "$(uname -s)" = "Linux"
bash -c 'source scripts/require-linux.sh; opk_require_linux'
```

### 1. Formatting guard

```bash
python3 scripts/validate-formatting.py
```

### 2. Upstream audit

```bash
python3 scripts/audit-upstreams.py --check
```

### 3. OpenCode pack validation

```bash
python3 scripts/validate-opencode-pack.py
```

### 4. Shell syntax

```bash
bash -n bin/opk
for file in ./*.sh scripts/*.sh; do
  bash -n "$file"
done
```

### 5. Behavioral tests

```bash
python3 scripts/test-permission-rules.py
node scripts/test-safety-plugin.mjs
bash scripts/test-opk-mode.sh
bash scripts/test-installer-preservation.sh
bash scripts/test-timeout.sh all
bash scripts/test-runtime-behavior.sh
bash evals/run.sh
```

### 6. Kit verifier

```bash
bash verify.sh
```

### 7. Doctor

```bash
bash doctor.sh
bash doctor.sh --deep
```

### 8. Integration

```bash
bash scripts/integration-test.sh
```

### 9. Release gate

```bash
bash scripts/release-gate.sh
```

## Full validation pipeline

Lệnh dưới đây là acceptance command chính:

```bash
set -euo pipefail
test "$(uname -s)" = "Linux"
python3 scripts/validate-formatting.py
python3 scripts/audit-upstreams.py --check
python3 scripts/validate-opencode-pack.py
bash verify.sh
bash doctor.sh --deep
bash scripts/integration-test.sh
bash scripts/release-gate.sh
git diff --check
echo "ALL LINUX VALIDATION PASSED"
```

## Checklist trước commit/push

- [ ] Platform guard PASS.
- [ ] Formatting guard PASS.
- [ ] Upstream audit PASS.
- [ ] OpenCode pack validation PASS.
- [ ] Tất cả shell scripts vượt qua `bash -n`.
- [ ] Timeout tests PASS.
- [ ] Runtime behavior tests PASS.
- [ ] Eval contracts PASS.
- [ ] `verify.sh` PASS, không có failure.
- [ ] `doctor.sh --deep` PASS.
- [ ] Integration test PASS.
- [ ] `scripts/release-gate.sh` trả exit code `0`.
- [ ] Không còn file `.ps1`, `.cmd`, `.bat`.
- [ ] Không còn workflow GitHub Actions hoạt động.
- [ ] `git diff --check` PASS.
- [ ] `git status` chỉ chứa thay đổi dự kiến.

## Tài liệu liên quan

- `README.md` — tổng quan và cài đặt Linux.
- `docs/WEAK_MODEL_GUIDE.md` — cách chia nhỏ công việc cho model yếu.
- `docs/safety.md` — mô hình an toàn.
- `docs/workflow.md` — workflow triển khai.
