# Model Selection Policy — Model-Agnostic

Chính sách model selection trong OpenCode Power Kit (OPK).

## Nguyên tắc cốt lõi

**OPK không chọn, route, benchmark, cache, hay override model.**

- User tự chọn model trong OpenCode UI (Settings → Model).
- Tất cả agent OPK (build-strong, explore, debug-strong, qa-strong…)
  **inherit model mà user đã chọn** — không có per-agent override.
- OPK không đọc `~/.local/share/opencode/auth.json`.
- OPK không tự bật model trả phí.
- OPK không dùng API key trực tiếp.

## Quy tắc

| Quy tắc | Chi tiết |
|---------|----------|
| Không tự chọn model | Không discover, không route, không benchmark |
| Không per-agent override | Mọi agent dùng chung model user đã chọn |
| Không cache model | Không lưu danh sách model vào `.opencode/` |
| Không API key | Không đọc auth.json, không in credential |
| Không model-specific code | Không import provider SDK, không call model API |
| Không automatic model selection | Không gợi ý "dùng model X cho task Y" |

## Cấu hình

```jsonc
// opencode.json — model-agnostic, chỉ cần model mặc định
{
  "model": "provider/model-id",
  // Không cần "agent" section — mọi agent inherit model ở trên
}
```

## `opk model status`

```
$ opk model status
opk: Model-agnostic mode — OPK không quản lý model.
    Chọn model trong OpenCode UI (Settings → Model).
    Tất cả agent OPK inherit model đó.
```

## Khi nào OPK quan tâm đến model?

**Không bao giờ.** OPK không cần biết user đang dùng model nào.
OPK chỉ cung cấp workflow (skill, guard, validator, test runner) —
model execution là trách nhiệm của OpenCode runtime.

## Xem thêm

- [docs/LOCAL_VALIDATION.md](LOCAL_VALIDATION.md) — Cách validate config.
- `opk model status` — Xem model-agnostic policy.
