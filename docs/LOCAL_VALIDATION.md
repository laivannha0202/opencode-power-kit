# Local Validation

> Local validation là kiểm tra authoritative khi GitHub Actions unavailable
> hoặc ở chế độ manual-only (`workflow_dispatch`).

## Nguyên tắc

- **Actions là optional** — Cả hai workflow `ci.yml` và `verify.yml` đều
  chạy thủ công qua `workflow_dispatch`. Không auto-trigger trên push/PR.
- **Local validation là primary** — Mọi thay đổi phải pass local validation
  trước khi commit/push. Actions trên GitHub chỉ là lớp kiểm tra bổ sung.
- **Không yêu cầu GitHub Actions** — Local validation chạy hoàn toàn trên máy
  của bạn. GitHub Actions là optional/manual-only.

## Các lệnh validation

### 0. Formatting guard

Kiểm tra format file, line count, workflow YAML structure:

```bash
python3 scripts/validate-formatting.py
```

### 1. Upstream audit

Kiểm tra tính toàn vẹn của upstream dependencies và audit report:

```bash
python3 scripts/audit-upstreams.py --check
```

### 2. OpenCode pack validation

Kiểm tra cấu trúc commands/agents/skills frontmatter:

```bash
python3 scripts/validate-opencode-pack.py
```

### 3. Verify script

Kiểm tra tổng thể toàn bộ kit:

```bash
bash verify.sh
```

### 4. Doctor (read-only diagnostic)

Chẩn đoán global + project config, structure, không MCP, không secrets:

```bash
bash doctor.sh

# Deep mode (kiểm tra thêm)
bash doctor.sh --deep
```

### 5. Bash syntax check

Kiểm tra cú pháp shell script trước khi commit:

```bash
bash -n bin/opk
bash -n install-global.sh
bash -n bootstrap.sh
bash -n install.sh
bash -n update-bmad.sh
for f in scripts/*.sh; do bash -n "$f"; done
```

### 6. Full validation pipeline

Chạy tất cả validation trong một lần:

```bash
set -e
echo "=== 0) formatting guard ===" && python3 scripts/validate-formatting.py
echo "=== 1) upstream audit ===" && python3 scripts/audit-upstreams.py --check
echo "=== 2) pack validation ===" && python3 scripts/validate-opencode-pack.py
echo "=== 3) verify.sh ===" && bash verify.sh
echo "=== 4) doctor.sh ===" && bash doctor.sh
echo "=== 5) bash -n ===" && bash -n bin/opk && for f in scripts/*.sh; do bash -n "$f"; done
echo "=== ALL PASS ==="
```

## Checklist trước commit/push

- [ ] `python3 scripts/validate-formatting.py` — formatting guard PASS
- [ ] `python3 scripts/audit-upstreams.py --check` — upstream audit PASS
- [ ] `python3 scripts/validate-opencode-pack.py` — pack validation PASS
- [ ] `bash verify.sh` — verify PASS (505 tests, 0 failed)
- [ ] `bash doctor.sh` — diagnostic không có lỗi
- [ ] `bash -n` trên tất cả `.sh` files — syntax OK
- [ ] `git status` — chỉ có file mong muốn thay đổi
- [ ] `git diff --stat` — kiểm tra diff gọn gàng, không có file lạ

## Khi Actions fail trên GitHub

1. Actions là optional — chạy thủ công qua tab "Actions" > workflow > "Run workflow".
2. Nếu Actions fail nhưng local validation PASS:
   - Thường do môi trường GitHub runner khác máy local.
   - Chạy `bash verify.sh` local để xác nhận thực tế.
   - Không phải lỗi code — có thể ignore nếu local PASS.
3. Nếu local validation fail:
   - Sửa lỗi trước, chạy lại local validation cho đến khi PASS.
   - Sau đó mới commit/push.

## Model yếu / flash

Nếu dùng model yếu (flash, low-cost), xem:

- `docs/WEAK_MODEL_GUIDE.md` — Hướng dẫn cho model yếu, slice nhỏ, anti-patterns

## Tài liệu liên quan

- `README.md` — Tổng quan kit, troubleshooting
- `docs/UPSTREAM_AUDIT.md` — Audit chi tiết upstream dependencies
- `docs/safety.md` — Mô hình an toàn
- `docs/workflow.md` — Workflow chi tiết
- `docs/WEAK_MODEL_GUIDE.md` — Hướng dẫn model yếu
