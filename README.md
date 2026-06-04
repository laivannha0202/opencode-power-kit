# OpenCode Power Kit

Toolkit dùng lại cho mọi project OpenCode — cài Superpowers + BMAD Method chỉ với 1 lệnh.

## Cài đặt nhanh

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
├── install.sh             # Script cài đặt
├── verify.sh              # Script kiểm tra
├── update-bmad.sh         # Script cập nhật BMAD
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

## Sau khi install

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
```

## An toàn

- Không copy token, password, API key, `.env`.
- Không copy `~/.config/opencode/opencode.json`.
- Không xóa file ngoài `~/opencode-power-kit`.
- Backup trước khi overwrite.
- Không tự push.

## License

MIT
