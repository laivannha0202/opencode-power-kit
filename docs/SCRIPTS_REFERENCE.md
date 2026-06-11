# Danh sách Scripts

| Script | Mục đích |
|--------|----------|
| `bootstrap.sh` | Bootstrap Linux/macOS — cài agents, commands, skills toàn cục |
| `bootstrap.ps1` | Windows PowerShell tương đương |
| `verify.sh` | Kiểm tra cài đặt kit (Linux/macOS) |
| `verify.ps1` | Kiểm tra cài đặt kit (Windows PowerShell) |
| `setup.sh` | Script setup đầy đủ (Linux/macOS) |
| `setup.ps1` | Script setup đầy đủ (Windows PowerShell) |
| `install-taste-skill.sh` | Cài Taste Skill (npx, Linux/macOS) |
| `install-taste-skill.ps1` | Cài Taste Skill (npx, Windows PowerShell) |
| `check-taste-skill.sh` | Kiểm tra Taste Skill đã cài chưa (Linux/macOS, không gọi network) |
| `check-taste-skill.ps1` | Kiểm tra Taste Skill đã cài chưa (Windows, không gọi network) |
| `install-global.sh` | Cài thành phần toàn cục (agents/commands/skills) |
| `install-project.sh` | Cài thành phần cho project |
| `install-fullstack-profile.sh` | Cài full-stack profile (Node/Nest/React/MySQL) |
| `opk-command-guard.sh` | Lớp bảo vệ: cảnh báo/chặn lệnh shell nguy hiểm |
| `cleanup-agent-artifacts.sh` | Dọn dẹp artifact an toàn |
| `doctor.sh` | Kiểm tra chẩn đoán (read-only) |

Tất cả scripts đều idempotent — an toàn khi chạy nhiều lần.
