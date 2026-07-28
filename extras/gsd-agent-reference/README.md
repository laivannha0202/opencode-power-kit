# GSD Agent Reference (snapshot — NOT bundled / NOT auto-loaded)

Thư mục này chứa **snapshot / reference** của 33 GSD-style agent definitions.
Chúng được chuyển ra khỏi `opencode-global/agents/` vì chúng phụ thuộc vào
upstream GSD Core (`gsd-core`) chưa được đóng gói trong kit, và nhiều file
tham chiếu đường dẫn cá nhân của maintainer không hợp lệ với người dùng khác.

## Quan trọng

- **Đây KHÔNG phải là runtime agent pool.** OpenCode sẽ KHÔNG tự load các
  file `.md` trong thư mục này.
- Các agent này **không được quảng cáo là bundled-ready**. Chúng chỉ để tham khảo
  cấu trúc GSD (phases, orchestrator, researcher, planner, ...).
- Đường dẫn cá nhân đã được thay bằng placeholder trung lập:
  - `${OPK_GSD_CORE_DIR}/gsd-core/...`
  - `${OPK_GLOBAL_DIR}/...`
  Thay vì hardcode đường dẫn cá nhân.

## Cách cài GSD chính thức (opt-in)

GSD Core là upstream optional, cài qua:

```bash
opk gsd            # forward sang official installer, version-pinned
opk gsd status     # kiểm tra GSD đã được cài chưa
```

Hoặc trực tiếp từ upstream (pin version, KHÔNG dùng @latest):

```bash
npx @opengsd/gsd-core@<pinned-version>
```

## Upstream & license

- Upstream: Open General Software Development (GSD) — `@opengsd/gsd-core`
- License: xem upstream repository.
- Phiên bản: kit chỉ forward; version được pin qua biến `GSD_CORE_VERSION`
  (mặc định một stable version, override bằng env var).

## Tại sao không bundle source?

GSD Core là một hệ thống lớn, thay đổi nhanh. Việc vendor source vào kit sẽ:
- vi phạm nguyên tắc "optional upstream do `opk gsd` cài";
- tạo ra 33 agent hỏng (thiếu orchestrator/reference/template) trong runtime pool;
- rò rỉ đường dẫn cá nhân của maintainer.

Do đó GSD agent reference chỉ nằm ở đây để tham khảo, không nằm trong
`opencode-global/agents/`.
