# Local Validation

> Local validation là kiểm tra authoritative khi GitHub Actions unavailable
> hoặc ở chế độ manual-only (`workflow_dispatch`).

## Nguyên tắc

- **Actions là optional** — Cả hai workflow `ci.yml` và `verify.yml` đều
  chạy thủ công qua `workflow_dispatch`. Không auto-trigger trên push/PR.
- **Local validation là primary** — Mọi thay đổi phải pass local validation
  trước khi commit/push. Actions trên GitHub chỉ là lớp kiểm tra bổ sung.
- **Không auto-trigger GitHub Actions** — Local validation chạy hoàn toàn trên máy
  của bạn. Hai workflow chỉ chạy thủ công, nhưng mọi failure khác môi trường phải
  được điều tra và không được bỏ qua khi đánh giá cross-platform release.

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

### 4. PowerShell runtime validation

Chạy timeout contract và PowerShell verifier bằng PowerShell 7:

```powershell
pwsh -NoProfile -File scripts/test-timeout.ps1
pwsh -NoProfile -File verify.ps1 -NoPython
```

Hai lệnh phải chạy trên Ubuntu có `pwsh` và trên Windows. Nếu local không có
`pwsh`, strict release gate phải ghi `REQUIRED SKIP` và exit `1`; skip không
được tính là PASS.

### 5. Doctor (read-only diagnostic)

Chẩn đoán global + project config, structure, không MCP, không secrets:

```bash
bash doctor.sh

# Deep mode (kiểm tra thêm)
bash doctor.sh --deep
```

### 6. Bash syntax check

Kiểm tra cú pháp shell script trước khi commit:

```bash
bash -n bin/opk
bash -n install-global.sh
bash -n bootstrap.sh
bash -n install.sh
bash -n update-bmad.sh
for f in scripts/*.sh; do bash -n "$f"; done
```

### 7. Full validation pipeline

Chạy tất cả validation trong một lần:

```bash
set -e
echo "=== 0) formatting guard ===" && python3 scripts/validate-formatting.py
echo "=== 1) upstream audit ===" && python3 scripts/audit-upstreams.py --check
echo "=== 2) pack validation ===" && python3 scripts/validate-opencode-pack.py
echo "=== 3) verify.sh ===" && bash verify.sh
echo "=== 4) doctor.sh --deep ===" && bash doctor.sh --deep
echo "=== 5) bash -n ===" && bash -n bin/opk && for f in scripts/*.sh; do bash -n "$f"; done
if ! command -v pwsh >/dev/null 2>&1; then
  echo "REQUIRED SKIP: pwsh unavailable" >&2
  exit 1
fi
echo "=== 6) PowerShell timeout ===" && pwsh -NoProfile -File scripts/test-timeout.ps1
echo "=== 7) PowerShell verify ===" && pwsh -NoProfile -File verify.ps1 -NoPython
echo "=== ALL PASS ==="
```

## Checklist trước commit/push

- [ ] `python3 scripts/validate-formatting.py` — formatting guard PASS
- [ ] `python3 scripts/audit-upstreams.py --check` — upstream audit PASS
- [ ] `python3 scripts/validate-opencode-pack.py` — pack validation PASS
- [ ] `bash verify.sh` — verify PASS (505 tests, 0 failed)
- [ ] `bash doctor.sh --deep` — diagnostic không có lỗi
- [ ] `pwsh -NoProfile -File scripts/test-timeout.ps1` — required PowerShell timeout PASS; thiếu `pwsh` là `REQUIRED SKIP`, không phải PASS
- [ ] `pwsh -NoProfile -File verify.ps1 -NoPython` — required PowerShell verify PASS; thiếu `pwsh` là `REQUIRED SKIP`, không phải PASS
- [ ] `bash -n` trên tất cả `.sh` files — syntax OK
- [ ] `git status` — chỉ có file mong muốn thay đổi
- [ ] `git diff --stat` — kiểm tra diff gọn gàng, không có file lạ

## Khi Actions fail trên GitHub

1. Actions chạy thủ công qua tab "Actions" > workflow > "Run workflow".
2. Nếu Actions fail nhưng local validation PASS, phải đọc log và điều tra khác biệt
   giữa local với runner Ubuntu/Windows; không được coi failure là có thể ignore.
3. Nếu local validation fail, sửa lỗi và chạy lại cho đến khi PASS trước khi push.
4. Không tạo release khi bất kỳ required check nào chưa chạy hoặc đang fail.

## Model yếu / flash

Nếu dùng model yếu (flash, low-cost), xem:

- `docs/WEAK_MODEL_GUIDE.md` — Hướng dẫn cho model yếu, slice nhỏ, anti-patterns

## Tài liệu liên quan

- `README.md` — Tổng quan kit, troubleshooting
- `docs/UPSTREAM_AUDIT.md` — Audit chi tiết upstream dependencies
- `docs/safety.md` — Mô hình an toàn
- `docs/workflow.md` — Workflow chi tiết
- `docs/WEAK_MODEL_GUIDE.md` — Hướng dẫn model yếu
