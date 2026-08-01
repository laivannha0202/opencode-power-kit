# Danh sách Scripts

OpenCode Power Kit v2.1.3 chỉ hỗ trợ Linux.

| Script | Mục đích |
|--------|----------|
| `bootstrap.sh` | Cài đặt một lệnh cho Linux |
| `setup.sh` | Menu và entrypoint setup đầy đủ |
| `install-global.sh` | Wrapper Linux cho global config/assets installer an toàn |
| `install.sh` | Cài cấu hình OPK vào project hiện tại |
| `verify.sh` | Kiểm tra cấu trúc, tính năng và validator |
| `doctor.sh` | Chẩn đoán read-only |
| `uninstall.sh` | Gỡ cấu hình project theo marker/backup |
| `update-bmad.sh` | Cập nhật BMAD Method theo version pin |
| `bin/opk` | CLI chính |
| `scripts/require-linux.sh` | Platform guard dùng chung |
| `scripts/release-gate.sh` | Acceptance gate Linux trước merge/release |
| `scripts/timeout.sh` | Timeout portable và dọn process tree |
| `scripts/test-timeout.sh` | Kiểm thử timeout contract |
| `scripts/integration-test.sh` | Kiểm thử cài đặt end-to-end offline |
| `scripts/test-runtime-behavior.sh` | Behavioral regression suite |
| `scripts/test-cli-contracts.sh` | Kiểm thử runtime contract của CLI, mode, safety plugin, integrations và checker |
| `scripts/test-opk-mode.sh` | Kiểm thử detect mode và ghi config project-local có backup |
| `scripts/merge-opk-project.py` | Merge root config, atomic write và migrate legacy config |
| `scripts/install-global.py` | Merge `~/.config/opencode/opencode.json`, managed-copy assets và migrate RC marker |
| `scripts/opk-permissions.py` | Đọc resolved config và báo effective permission mà không in secret |
| `scripts/check-opencode-config-paths.py` | Chặn production code dùng legacy config như active path |
| `scripts/check-agent-permission-contracts.py` | Validate agent ask/edit/bash contracts |
| `scripts/test-global-installer.sh` | Test preservation, managed manifest, RC migration, idempotency và symlink rejection |
| `scripts/test-opencode-resolved-config.sh` | Integration test bằng OpenCode thật với HOME/project fixture |
| `scripts/validate-formatting.py` | Kiểm tra format và Linux-only layout |
| `scripts/validate-opencode-pack.py` | Kiểm tra agents, commands, skills và packaging |
| `scripts/check-cli-file-references.py` | Kiểm tra các file literal mà `bin/opk` tham chiếu đều tồn tại hoặc được guard |
| `scripts/install-fullstack-profile.sh` | Cài profile Node/Nest/React/MySQL |
| `scripts/install-taste-skill.sh` | Cài Taste Skill qua npx |
| `scripts/check-taste-skill.sh` | Kiểm tra Taste Skill không gọi network |
| `scripts/opk-command-guard.sh` | Cảnh báo/chặn lệnh shell nguy hiểm |
| `scripts/cleanup-agent-artifacts.sh` | Dọn artifact bằng cơ chế move-to-trash |
| `scripts/audit-ecc.sh` | Audit ECC read-only |
| `scripts/install-ecc-lite.sh` | Cài ECC-lite |
| `scripts/check-ecc-lite.sh` | Kiểm tra ECC-lite |
| `scripts/audit-hermes.sh` | Audit Hermes-lite; mặc định read-only, chỉ `--write` cập nhật `docs/HERMES_AUDIT.md` |
| `scripts/check-hermes-lite.sh` | Kiểm tra Hermes-lite |
| `scripts/hermes-learning-capsule.sh` | Đóng gói learning capsule |

Các entrypoint chính đều nạp `scripts/require-linux.sh`. Release chính thức chỉ
được chấp nhận khi `bash scripts/release-gate.sh` trả exit code `0`.
