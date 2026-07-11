# Model Routing — Free-Only Mode

Hướng dẫn cấu hình model routing trong OpenCode Power Kit.
**OPK free-model orchestration: không yêu cầu API key của OpenAI/Anthropic.**

## Tổng quan

OpenCode hỗ trợ cấu hình nhiều model/provider khác nhau. OPK tự phát hiện
model miễn phí và định tuyến task phù hợp. **Không cần API key riêng** —
người dùng đăng nhập provider bằng giao diện OpenCode hoặc `/connect`.

## Quan trọng

- **OPK không quản lý, đọc hoặc ghi credential.**
- **OPK chỉ dùng các model mà `opencode models` trả về.**
- **Free models là thời hạn và có thể thay đổi.**
- **FREE_ONLY không tự động fallback sang model có phí.**

## Cấu trúc

Model routing được cấu hình trong `opencode.json` (project root hoặc
`.opencode/opencode.json`):

```jsonc
{
  // Model mặc định — lấy exact ID từ: opencode models --refresh --verbose
  "model": "REPLACE_WITH_OUTPUT_FROM_OPENCODE_MODELS",

  // Optional: Per-agent model routing
  "agent": {
    "build": {
      "mode": "primary",
      "model": "REPLACE_WITH_BEST_FREE_MODEL"
    },
    "explore": {
      "mode": "subagent",
      "model": "REPLACE_WITH_SECOND_FREE_MODEL"
    }
  }
}
```

## Free-Only Mode

Khi `OPK_FREE_ONLY=1`:

- Chỉ dùng model được xác định miễn phí
- Không fallback sang model có phí
- Nếu không có model free → dừng với thông báo rõ ràng
- Model không rõ giá bị loại khỏi pool mặc định

## Task Types

| Type | Description | Routing Strategy |
|------|-------------|------------------|
| `code` | Code generation, refactoring | Model free mạnh nhất |
| `quick` | Simple edits, renames | Model free nhanh |
| `review` | Code review, PR review | Model free khác (reviewer) |
| `research` | Research, documentation | Model free nhanh |
| `all` | Fallback | Default free model |

## Tips

1. **Bắt đầu đơn giản** — Chạy `opencode models --refresh --verbose`
   để xem danh sách model free hiện có.

2. **Dùng `opk model discover-free`** — Tự phát hiện model miễn phí.

3. **Không hardcode model slug** — Danh sách free có thể thay đổi.

4. **Model routing là optional** — Nếu không cấu hình `agent`,
   mọi task dùng model mặc định.

## Xem thêm

- [templates/opencode.models.example.jsonc](../templates/opencode.models.example.jsonc)
  — Template ví dụ với free-model routing.
- [docs/LOCAL_VALIDATION.md](LOCAL_VALIDATION.md) — Cách validate config.
