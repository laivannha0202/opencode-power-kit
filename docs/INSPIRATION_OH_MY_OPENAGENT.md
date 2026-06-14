# Inspiration: oh-my-openagent

> Tài liệu tham khảo ý tưởng từ
> [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent)
> bởi code-yeongyu. KHÔNG copy source code, KHÔNG vendor, KHÔNG add dependency.

---

## oh-my-openagent là gì

oh-my-openagent là một hệ thống orchestration cho AI coding agents với các tính năng:

- **Multi-model / multi-agent orchestration** — Điều phối nhiều agents và models
- **IntentGate** — Hiểu đúng ý định user trước khi chạy
- **ultrawork / ulw-loop** — Lệnh làm việc dài hơi đến khi verify xong
- **Prometheus / Atlas** — Tách planning và execution
- **Doctor sâu** — Kiểm tra system, config, tools, models, team mode
- **LSP + AST-grep workflow** — Structural code search
- **Evidence trail** — Lưu vết các thay đổi
- **Team Mode** — Background agents

---

## Ý tưởng OPK tham khảo

### 1. Intent Routing (từ IntentGate)

**oh-my-openagent:** IntentGate phân loại request thành nhiều intent trước khi dispatch.

**OPK:** `/intent-router` phân loại 10 loại intent, đề xuất agent phù hợp.
Đơn giản hơn — chỉ routing, không có gate logic phức tạp.

### 2. Long Work Loop (từ ultrawork)

**oh-my-openagent:** ultrawork chạy một lệnh dài, tự iterate đến khi verify xong.

**OPK:** `/power-work-lite` chạy workflow 10 bước, nhưng:
- An toàn hơn: luôn git status trước
- Evidence-driven: lưu vào `.opk/work/`
- Vietnamese-first: mọi output tiếng Việt
- Không tự push/reset/clean

### 3. Planning vs Execution (từ Prometheus/Atlas)

**oh-my-openagent:** Tách biệt planning (Prometheus) và execution (Atlas).

**OPK:** Tích hợp trong `/power-work-lite` — plan → build → verify.
Không cần tách thành agents riêng.

### 4. Evidence Trail (từ work continuation)

**oh-my-openagent:** State persistence, work continuation across sessions.

**OPK:** `.opk/work/` + `AI_HANDOFF.md` + `/continue-work` + `/evidence-report`.
Đơn giản hơn — file-based, không cần external state store.

### 5. Deep Doctor (từ doctor system)

**oh-my-openagent:** Doctor kiểm tra system, config, tools, models, team mode.

**OPK:** `doctor --deep` mở rộng read-only checks.
Không kiểm tra models/team mode (vì OPK không có multi-model).

### 6. Structural Code Search (từ LSP + AST-grep)

**oh-my-openagent:** LSP + AST-grep workflow cho code search.

**OPK:** Detect-only trong `/tooling-doctor` — ast-grep, rg, fd.
Không bắt buộc cài, chỉ hướng dẫn.

---

## Ý tưởng OPK KHÔNG tham khảo

1. **Multi-model routing** — OPK chỉ dùng model hiện tại
2. **MCP integration** — OPK giữ no MCP by default
3. **Gateway / server** — OPK là local-first
4. **Team Mode** — OPK không có background agents
5. **Telegram/Discord/Slack** — OPK không có external integrations
6. **Telemetry** — OPK không track usage

---

## Tại sao chỉ tham khảo, không copy

1. **Đơn giản hóa** — oh-my-openagent quá phức tạp cho student project
2. **An toàn** — OPK giữ safety rules strict
3. **Vietnamese-first** — oh-my-openagent English-first
4. **No vendor** — OPK không muốn add dependency không cần thiết
5. **Backward compatible** — Không phá command/agent/skill hiện có

---

## References

- oh-my-openagent: https://github.com/code-yeongyu/oh-my-openagent
- OPK Orchestration Lite: `docs/OPK_ORCHESTRATION_LITE.md`
- License oh-my-openagent: MIT (tham khảo ý tưởng, không copy code)
