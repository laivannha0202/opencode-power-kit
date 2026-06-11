---
description: Chạy ECC audit — clone ECC read-only, phân tích cấu trúc, tạo báo cáo
subtask: true
agent: ecc-lite-strong
---

# /ecc-audit

Read-only audit of Engineering Code Commandments (ECC).

## Cách dùng

```
/ecc-audit
/ecc-audit --dry-run    # chỉ xem plan, không clone
/ecc-audit --yes        # chạy ngay, không confirm
```

## ⚠️ Scope Guard — Read-only audit

ECC-audit **CHỈ** đọc và phân tích ECC. **KHÔNG**:
- Cài đặt ECC globally
- Copy ECC assets vào project
- Sửa .env, secrets, MCP config
- Chạy destructive commands

## Workflow

1. Clone ECC (git clone --depth 1 vào .tmp/ecc/)
2. Phân tích: version, cấu trúc, commandments, scripts, hooks
3. Tạo `docs/ECC_AUDIT.md` với structured report
4. Xoá .tmp/ecc/
5. Report kết quả

## When to use

- Khi muốn hiểu ECC có thể áp dụng được gì cho project hiện tại
- Khi cần reference về ECC principles và structure
- Khi muốn so sánh ECC-lite vs full ECC

## Output

```
## ECC Audit Report
- **Version:** {detected}
- **Files:** N
- **Directories:** N
- **Scripts:** N
- **Commandments found:** N
- **Report:** docs/ECC_AUDIT.md
```
