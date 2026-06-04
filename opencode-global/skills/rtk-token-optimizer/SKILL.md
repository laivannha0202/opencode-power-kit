# RTK Token Optimizer

Skill dùng kết hợp rtk (Rust Token Killer) để giảm output token cho lệnh shell.

## Cài rtk

Không tự cài. Xem `scripts/install-token-tools.sh` hoặc:
```bash
cargo install rtk
# Repo: https://github.com/rtk-ai/rtk
```

Nếu chưa có cargo, in hướng dẫn thủ công cho user.

## Lệnh rtk thường dùng

| Thay vì | Dùng | Token saving |
|---------|------|--------------|
| `ls -la` | `rtk ls` | ~70% |
| `cat file.txt` | `rtk cat file.txt` | ~50% (chỉ phần đầu, head/tail) |
| `rg pattern` | `rtk rg pattern` | ~60% (gộp file ngắn) |
| `fd pattern` | `rtk fd pattern` | ~50% |
| `git status` | `rtk git status` | ~60% |
| `git log` | `rtk git log` | ~60% |
| `git diff` | `rtk git diff` | ~70% |
| `cargo test` | `rtk cargo test` | ~80% (summary + failure only) |
| `cargo build` | `rtk cargo build` | ~90% (chỉ error) |
| `npm test` | `rtk npm test` | ~80% |
| `docker ps` | `rtk docker ps` | ~60% |
| `kubectl get pods` | `rtk kubectl get pods` | ~70% |

## Alias gợi ý

Thêm vào `~/.bashrc` (chỉ in, KHÔNG tự sửa):
```bash
alias ls='rtk ls'
alias cat='rtk cat'
alias rg='rtk rg'
alias fd='rtk fd'
alias git='rtk git'
alias cargo='rtk cargo'
alias npm='rtk npm'
```

Sau khi alias: `source ~/.bashrc`. Tất cả lệnh tự qua rtk.

## Khi KHÔNG dùng rtk

- Pipe vào tool khác (vd: `cat file | jq`) — output đã cần format chuẩn.
- Output cần dán nguyên văn (vd: report, config).
- Script tự động (CI) — rtk chỉ tối ưu khi đọc bằng mắt.

## Workflow trong OpenCode

- Khi chạy shell command: ưu tiên `rtk <cmd>`.
- Khi long output: `rtk <cmd> 2>&1 | head -100` hoặc dùng `summary` flag.
- Khi thấy output > 2KB, cân nhắc `rtk` version.

## Output

- Lệnh đã chạy (bản rtk + bản thường nếu cần so sánh).
- Token estimate trước/sau (nếu dùng tokscale).
- Alias gợi ý nếu chưa có.

Xem thêm: `/rtk-gain` command — chạy `rtk gain` để auto-suggest alias.
