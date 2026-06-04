# OpenCode Power Kit

Toolkit dùng lại cho mọi project OpenCode — cài Superpowers + BMAD Method chỉ với 1 lệnh.

## Cài global toàn bộ OpenCode

```bash
bash ~/opencode-power-kit/install-global.sh
source ~/.bashrc
opencode
```

Sau khi cài global, dùng được:
- `/smart-scan` — quét nhanh project
- `/repo-map` — tạo bản đồ project
- `/bugfix-safe` — sửa bug an toàn
- `/review-diff` — review git diff
- `/token-pack` — tạo gói context Repomix
- `/db-readonly` — kiểm tra DB read-only
- `@plan-lite` hoặc agent `plan-lite` — lập kế hoạch tiết kiệm token

Và các command nâng cấp v2 (lifecycle + review + token):
- `/spec-lite` — đặc tả ngắn (scope, AC, out-of-scope)
- `/plan-work` — chia task nhỏ, có file + test
- `/build-slice` — triển khai 1 slice, ≤ 2 file
- `/test-proof` — chạy/đề xuất test chứng minh
- `/ship-check` — checklist trước commit/push
- `/security-review` — review security (secrets, auth, input)
- `/api-contract-review` — check FE/BE API contract
- `/migration-safe` — kiểm tra migration an toàn
- `/rtk-gain` — chạy `rtk gain` hoặc hướng dẫn cài

## Cài cho 1 project

```bash
# Clone (lần đầu)
git clone https://github.com/nguoikhongten02022005-cell/opencode-power-kit.git ~/opencode-power-kit

# Vào project cần cài
cd /path/to/your/project

# Chạy install
bash ~/opencode-power-kit/install.sh
```

## Cấu trúc

```
~/opencode-power-kit/
├── README.md              # Tài liệu này
├── install.sh             # Script cài per-project
├── install-global.sh      # Script cài global
├── verify.sh              # Script kiểm tra
├── update-bmad.sh         # Script cập nhật BMAD
├── scripts/
│   └── install-token-tools.sh  # Kiểm tra + hướng dẫn cài rtk/tokscale
├── opencode-global/       # Config global
│   ├── agents/            # Agents tiết kiệm token
│   │   ├── plan-lite.md
│   │   ├── review-lite.md
│   │   ├── debug-lite.md
│   │   └── build-strong.md
│   ├── commands/          # Commands theo nhu cầu
│   │   ├── smart-scan.md
│   │   ├── bugfix-safe.md
│   │   ├── review-diff.md
│   │   ├── repo-map.md
│   │   ├── token-pack.md
│   │   ├── db-readonly.md
│   │   ├── spec-lite.md           # v2: đặc tả ngắn
│   │   ├── plan-work.md           # v2: chia task nhỏ
│   │   ├── build-slice.md         # v2: triển khai slice
│   │   ├── test-proof.md          # v2: chứng minh test
│   │   ├── ship-check.md          # v2: checklist ship
│   │   ├── security-review.md     # v2: review security
│   │   ├── api-contract-review.md # v2: review API contract
│   │   ├── migration-safe.md      # v2: check migration
│   │   └── rtk-gain.md            # v2: tối ưu token với rtk
│   └── skills/            # Skills load theo nhu cầu
│       ├── token-smart-code/
│       ├── serena-first/
│       ├── safe-edit/
│       ├── repo-map/
│       ├── js-ts-project/
│       ├── security-review/         # v2
│       ├── api-contract/            # v2
│       ├── database-migration-safe/ # v2
│       ├── test-strategy/           # v2
│       ├── frontend-ui-review/      # v2
│       ├── adr-architecture-decision/ # v2
│       └── rtk-token-optimizer/     # v2
├── templates/
│   ├── AGENTS.md          # Rules cho AI agent
│   ├── OPENCODE.md        # Guide project
│   ├── opencode.json      # Config OpenCode
│   ├── lefthook.yml       # Git hooks
│   ├── knip.json          # Dead code detector
│   └── gitignore-extra.txt # Gitignore bổ sung
└── docs/
    ├── workflow.md        # Quy trình làm việc
    ├── prompts.md         # Prompt mẫu
    └── safety.md          # Rules an toàn
```

## Sau khi install per-project

`install.sh` sẽ thêm vào project:

| File | Mục đích |
|------|----------|
| `AGENTS.md` | Rules bắt buộc cho AI agent |
| `OPENCODE.md` | Guide tech stack + quy trình |
| `.opencode/opencode.json` | Config Superpowers plugin |
| `.gitignore` | Merge thêm ignores |
| `knip.json` | Dead code detection |
| `lefthook.yml` | Pre-commit hooks |
| `opencode-power-install-report.md` | Báo cáo cài đặt |

## Commands

```bash
# Verify project đã cài đúng
bash ~/opencode-power-kit/verify.sh

# Cập nhật BMAD
bash ~/opencode-power-kit/update-bmad.sh

# Kiểm tra rtk / tokscale (không tự cài)
bash ~/opencode-power-kit/scripts/install-token-tools.sh
```

## Nâng cấp mạnh không cần MCP

Bản v2 bổ sung 9 commands + 7 skills tập trung vào **lifecycle** (spec → plan → build → test → ship) và **review chuyên sâu** (security, API contract, migration, UI, ADR). Đặc điểm:

- **Không thêm MCP server nào** vào repo. Tất cả là command + skill chạy local.
- **Không copy token, password, API key, `.env`** vào bất kỳ file nào.
- **Không bulk-copy skill** từ repo khác — mỗi skill viết tay, scoped, có ví dụ cụ thể.
- Tất cả command đều tôn trọng quy tắc `safe-edit`: không xóa file, không push force, không tự chạy curl|sh.

### Commands mới

| Command | Mục đích | Dùng khi |
|---------|----------|----------|
| `/spec-lite` | Đặc tả ngắn (goal, scope, AC, out-of-scope) | Bắt đầu task mới, cần scope rõ trước khi code |
| `/plan-work` | Chia task ≤ 7 bước, mỗi bước có file + test | Sau spec, cần kế hoạch atomic commit được |
| `/build-slice` | Triển khai 1 slice, ≤ 2 file, ≤ 100 dòng diff | Theo plan, mỗi step là 1 slice |
| `/test-proof` | Chạy/đề xuất test chứng minh | Sau khi sửa, cần proof không regress |
| `/ship-check` | Checklist trước commit/push | Trước khi tạo PR / merge |
| `/security-review` | Review security (secrets, auth, input) | Trước merge code có auth/input mới |
| `/api-contract-review` | Check FE/BE API contract | Trước/sau khi thay đổi API |
| `/migration-safe` | Kiểm tra migration an toàn | Trước khi chạy migration DB |
| `/rtk-gain` | Chạy `rtk gain` hoặc hướng dẫn cài | Khi muốn tối ưu token usage |

### Skills mới

| Skill | Phạm vi |
|-------|---------|
| `security-review` | Secrets, auth, input validation, crypto, headers |
| `api-contract` | Endpoint, type, status, error format, auth, pagination |
| `database-migration-safe` | DROP/TRUNCATE/DELETE guard, backfill, rollback |
| `test-strategy` | Pyramid, framework theo stack, minimal infra |
| `frontend-ui-review` | A11y, layout, typography, color, state, performance |
| `adr-architecture-decision` | Format ADR Nygard, khi nào viết |
| `rtk-token-optimizer` | Mapping lệnh thường → rtk, alias gợi ý |

## Cách dùng RTK / tokscale (không bắt buộc)

RTK (Rust Token Killer) wrapper các lệnh shell phổ biến, giảm **40-60% output token**. Tokscale vẽ bar chart token usage để phát hiện request tốn token.

### Kiểm tra nhanh

```bash
bash ~/opencode-power-kit/scripts/install-token-tools.sh
```

Script **không sudo**, **không tự chạy `curl|sh`**, **không bắt buộc cài**. Nó:
1. Phát hiện rtk / tokscale trong `$PATH`.
2. In hướng dẫn cài thủ công nếu thiếu.
3. Tạo `TOKEN_TOOLS_REPORT.md` với hướng dẫn chi tiết.

### Cài thủ công (nếu muốn)

```bash
# Cần Rust/cargo trước
cargo install rtk
cargo install tokscale
# Repo: https://github.com/rtk-ai/rtk
#       https://github.com/hasansezertasan/tokscale
```

### Dùng

```bash
# Thay vì:
ls -la
git status
cargo test

# Dùng:
rtk ls
rtk git status
rtk cargo test
```

Hoặc alias trong `~/.bashrc`:
```bash
alias ls='rtk ls'
alias cat='rtk cat'
alias rg='rtk rg'
alias git='rtk git'
```

Trong OpenCode, dùng command `/rtk-gain` để chạy `rtk gain` (auto-suggest alias).

## Ghi chú quan trọng

- Repo này **không copy MCP config** (`opencode.json` mcp section) từ bất kỳ đâu.
- Tất cả command mới **không touch** `~/.config/opencode/opencode.json` global.
- Nếu user muốn MCP, tự thêm vào project `.opencode/opencode.json` của họ.

## An toàn

- Không copy token, password, API key, `.env`.
- Không copy `~/.config/opencode/opencode.json`.
- Không xóa file ngoài `~/opencode-power-kit`.
- Backup trước khi overwrite.
- Không tự push.

## License

MIT
