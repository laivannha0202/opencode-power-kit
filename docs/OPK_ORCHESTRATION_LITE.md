# OPK Orchestration Lite

> Phiên bản gọn, an toàn, Vietnamese-first của khả năng orchestration,
> lấy cảm hứng từ [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)
> nhưng KHÔNG copy code, KHÔNG vendor, KHÔNG bật MCP, KHÔNG thêm telemetry.

---

## Mục đích

OPK Orchestration Lite biến opencode-power-kit thành một bộ công cụ có khả năng
xử lý task dài tốt hơn, hiểu đúng ý định user trước khi chạy, và tự động
chọn workflow phù hợp — tất cả đều giữ nguyên triết lý:

- **Vietnamese-first** — mọi output bằng tiếng Việt
- **No MCP by default** — không bật Model Context Protocol
- **No telemetry** — không theo dõi usage
- **No vendor** — không copy source code từ oh-my-openagent
- **Backward compatible** — không phá command/agent/skill cũ

---

## Ý tưởng tham khảo từ oh-my-openagent

| Ý tưởng | oh-my-openagent | OPK Orchestration Lite |
|---------|----------------|----------------------|
| **Intent Routing** | IntentGate — phân loại request trước khi chạy | `/intent-router` — phân loại 10 loại intent, đề xuất agent |
| **Long work loop** | ultrawork / ulw-loop — lệnh chạy dài đến khi verify | `/power-work-lite` — workflow 10 bước an toàn |
| **Planning vs Execution** | Prometheus / Atlas — tách planning và execution | Tích hợp trong `/power-work-lite` (plan → build → verify) |
| **Evidence trail** | Work continuation, state persistence | `.opk/work/` + `AI_HANDOFF.md` + `/evidence-report` |
| **Deep doctor** | Doctor kiểm tra system/config/tools/models/team | `doctor --deep` — mở rộng read-only checks |
| **LSP + AST-grep** | Structural code search workflow | Detect-only trong `/tooling-doctor` |

---

## KHÔNG làm gì

1. **KHÔNG copy code** — Chỉ tham khảo ý tưởng workflow
2. **KHÔNG vendor oh-my-openagent** — Không add dependency, không clone, không npm install
3. **KHÔNG bật MCP** — Mọi thứ hoạt động không cần Model Context Protocol
4. **KHÔNG thêm telemetry** — Không có usage tracking, analytics, telemetry hooks
5. **KHÔNG phá backward compatibility** — Tất cả command/agent/skill cũ vẫn hoạt động
6. **KHÔNG tự push/reset/clean** — Luôn tuân thủ safety rules

---

## Các thành phần mới

### 1. `/intent-router` — Phân loại ý định

```
/intent-router "thêm API CRUD user với JWT auth"
```

Phân loại request thành 10 loại:
1. `research` — Tìm hiểu, phân tích
2. `plan` — Lập kế hoạch
3. `implement` — Triển khai code
4. `debug` — Debug, tìm root cause
5. `refactor` — Tối ưu cấu trúc
6. `test` — Viết/chạy test
7. `security` — Kiểm tra bảo mật
8. `release` — Phát hành version
9. `docs` — Tài liệu
10. `fullstack-feature` — Tính năng full-stack

Đề xuất agent phù hợp từ pool 12 agents.

### 2. `/init-deep-lite` — Khởi tạo project context

```
/init-deep-lite
```

- Đọc project hiện tại
- Tạo/cập nhật: `AGENTS.md`, `OPENCODE.md`, `AI_HANDOFF.md`, `docs/PROJECT_CONTEXT.md`, `docs/WORKFLOW.md`
- Không ghi đè nội dung user
- Append section mới có marker `<!-- OPK_INIT_DEEP_LITE_START -->`

### 3. `/power-work-lite` — Workflow làm việc dài

```
/power-work-lite "thêm tính năng X"
```

Phiên bản an toàn, gọn của ultrawork:
1. Git status
2. Đọc README/package/config
3. Xác định mục tiêu
4. Tạo plan ngắn
5. Chọn agent/workflow
6. Sửa theo lát nhỏ
7. Chạy kiểm tra
8. Lưu evidence vào `.opk/work/`
9. Cập nhật `AI_HANDOFF.md` nếu task dài
10. Báo cáo tiếng Việt

### 4. `/continue-work` — Tiếp tục task dang dở

```
/continue-work
```

- Đọc `AI_HANDOFF.md` và `.opk/work/`
- Xác định việc đang dở
- Chạy verify nhẹ
- Tiếp tục task an toàn

### 5. `/evidence-report` — Báo cáo evidence

```
/evidence-report
```

Tổng hợp: git status, git diff --stat, test/verify, file thay đổi, quyết định kỹ thuật.

---

## Workflow tổng quát

```
User request
    │
    ▼
/intent-router ──→ Phân loại intent + đề xuất agent
    │
    ▼
/power-work-lite ──→ Plan → Build → Verify → Evidence
    │
    ├──→ .opk/work/ (lưu evidence)
    ├──→ AI_HANDOFF.md (cập nhật handoff)
    │
    ▼
/evidence-report ──→ Báo cáo tiếng Việt
```

---

## So sánh với oh-my-openagent

| Khía cạnh | oh-my-openagent | OPK Orchestration Lite |
|-----------|----------------|----------------------|
| Complexity | Cao (multi-agent, MCP, gateway) | Thấp (single-agent, no MCP) |
| Setup | Cần cấu hình nhiều | Works out-of-box |
| MCP | Bật mặc định | KHÔNG bật |
| Telemetry | Có | KHÔNG có |
| Language | English-first | Vietnamese-first |
| Safety | Tùy cấu hình | Strict safety rules |
| Target audience | Advanced teams | Students, full-stack devs |

---

## Khi nào dùng

- **Task dài** (> 10 files hoặc > 30 phút) → `/power-work-lite`
- **Task mơ hồ** → `/intent-router` trước, rồi chạy workflow
- **Task dang dở** → `/continue-work`
- **Cần báo cáo** → `/evidence-report`
- **Project mới** → `/init-deep-lite`

---

## Safety guarantees

- KHÔNG tự push
- KHÔNG git reset --hard
- KHÔNG git clean -fd
- KHÔNG xóa file user
- KHÔNG sửa .env/secrets
- KHÔNG bật MCP
- KHÔNG thêm telemetry
- Luôn chạy git status trước/sau
- Luôn báo cáo bằng tiếng Việt
