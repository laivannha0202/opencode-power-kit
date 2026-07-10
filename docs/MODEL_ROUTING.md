# Model Routing

Hướng dẫn cấu hình model routing trong OpenCode Power Kit.

## Tổng quan

OpenCode hỗ trợ cấu hình nhiều model/provider khác nhau cho các use case
riêng biệt. Model routing cho phép bạn định tuyến task phù hợp nhất tới
model phù hợp nhất, tối ưu cả chất lượng lẫn chi phí.

## Cấu trúc

Model routing được cấu hình trong `opencode.json` (project root hoặc
`.opencode/opencode.json`):

```jsonc
{
  // Model mặc định cho mọi task
  "model": "anthropic/claude-sonnet-4-20250514",

  // Provider definitions
  "provider": {
    "anthropic": {
      "apiKey": "env:ANTHROPIC_API_KEY"
    },
    "openai": {
      "apiKey": "env:OPENAI_API_KEY"
    }
  },

  // Model overrides per task type (optional)
  "modelRouting": {
    // Code generation — dùng model mạnh nhất
    "code": "anthropic/claude-sonnet-4-20250514",

    // Quick edits — dùng model nhanh/rẻ hơn
    "quick": "openai/gpt-4o-mini",

    // Review — dùng model analytical
    "review": "anthropic/claude-sonnet-4-20250514",

    // Research — dùng model có context lớn
    "research": "anthropic/claude-sonnet-4-20250514"
  }
}
```

## Task Types

| Type | Description | Default Model |
|------|-------------|---------------|
| `code` | Code generation, refactoring, bug fix | Claude Sonnet |
| `quick` | Simple edits, renames, formatting | GPT-4o Mini |
| `review` | Code review, PR review | Claude Sonnet |
| `research` | Research, documentation, planning | Claude Sonnet |
| `all` | Fallback for everything else | Default model |

## Tips

1. **Bắt đầu đơn giản** — Chỉ cấu hình `"model"` mặc định. Thêm routing
   sau khi xác định bottleneck.

2. **Dùng model nhỏ cho quick tasks** — `gpt-4o-mini` hoặc `claude-haiku`
   tiết kiệm chi phí cho edit đơn giản.

3. **Provider key qua env** — Luôn dùng `"env:ANTHROPIC_API_KEY"` thay vì
   hardcode key trong config.

4. **Model routing là optional** — Nếu không cấu hình `modelRouting`,
   mọi task dùng model mặc định.

## Xem thêm

- [templates/opencode.models.example.jsonc](../templates/opencode.models.example.jsonc)
  — Template ví dụ với model routing đầy đủ.
- [docs/LOCAL_VALIDATION.md](LOCAL_VALIDATION.md) — Cách validate config.
