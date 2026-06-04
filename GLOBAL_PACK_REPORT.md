# OpenCode Power Kit - Global Pack Report

- **Thời gian:** $(date '+%Y-%m-%d %H:%M:%S')
- **Repo:** ~/opencode-power-kit

## Đã thêm

### install-global.sh
- Script cài global, không chạy sudo
- Backup ~/.bashrc và opencode.json trước khi sửa
- Tạo ~/.config/opencode nếu chưa có
- Thêm OPENCODE_CONFIG_DIR vào ~/.bashrc
- Đảm bảo ~/.local/bin trong PATH
- Không copy token/secrets
- Không sửa MCP hiện có
- Tạo GLOBAL_INSTALL_REPORT.md

### opencode-global/agents/ (4 agents)

| Agent | Mô tả | Mode |
|-------|--------|------|
| plan-lite.md | Lập kế hoạch nhanh, không sửa file | subagent |
| review-lite.md | Review diff tiết kiệm token | subagent |
| debug-lite.md | Điều tra bug evidence-first | subagent |
| build-strong.md | Triển khai code mạnh | all |

### opencode-global/commands/ (6 commands)

| Command | Mô tả |
|---------|--------|
| /smart-scan | Quét nhanh project |
| /bugfix-safe | Sửa bug an toàn |
| /review-diff | Review git diff |
| /repo-map | Tạo bản đồ project |
| /token-pack | Tạo gói context Repomix |
| /db-readonly | Kiểm tra DB read-only |

### opencode-global/skills/ (5 skills)

| Skill | Mô tả |
|-------|--------|
| token-smart-code | Tiết kiệm token khi code |
| serena-first | Dùng Serena semantic search |
| safe-edit | Quy tắc sửa code an toàn |
| repo-map | Tạo repo map ngắn |
| js-ts-project | Hướng dẫn JS/TS projects |

### Cập nhật
- README.md: thêm mục "Cài global toàn bộ OpenCode"
- verify.sh: kiểm tra OPENCODE_CONFIG_DIR, agents, commands, skills, external tools

## Cách dùng

```bash
# Cài global
bash ~/opencode-power-kit/install-global.sh

# Activate
source ~/.bashrc
opencode

# Thử
/smart-scan
@plan-lite
/repo-map
```

## An toàn
- Không token/password/secrets trong repo
- Backup trước khi sửa ~/.bashrc
- Không sudo
- Không sửa MCP
- Không xóa file
