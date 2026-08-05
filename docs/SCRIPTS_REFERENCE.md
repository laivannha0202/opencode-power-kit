# Danh sách Scripts

OpenCode Power Kit v2.2.0 chỉ hỗ trợ Linux.

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
| `scripts/test-opk-mode.sh` | Kiểm thử exact cwd/nested monorepo, mode, auto gate và JSONC CLI |
| `scripts/test-opk-permissions.sh` | Table-driven strict Power/Safe/Custom/Broken contract tests |
| `scripts/test-agent-permission-contracts.sh` | Fixture tests cho quoted/unquoted/inline YAML permission |
| `scripts/merge-opk-project.py` | Merge root config, fail closed JSONC, atomic write, rollback và migrate legacy |
| `scripts/test-project-installer-path-safety.sh` | Test path safety của project installer: symlink rejection, dirfd atomic write, TOCTOU race và transaction rollback |
| `scripts/test-opencode-jsonc-compatibility.sh` | Test JSONC scanner (comment/trailing comma), conflict `.json`/`.jsonc`, `--normalize-jsonc` và CLI contracts |
| `scripts/check-project-installer-path-safety.py` | Static validator: scan `merge-opk-project.py` chặn open/rmtree/makedirs/shell unsafe |
| `scripts/install-global.py` | Merge global config dưới installer lock, fail closed JSONC, managed assets và RC marker |
| `scripts/opk-permissions.py` | Resolve đúng `--project-dir`, kiểm tra strict Power contract và không in secret |
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
| `scripts/opk-command-guard.sh` | Cảnh báo/chặn lệnh shell nguy hiểm (không có bypass env) |
| `scripts/opk_safe_io.py` | Safe-I/O layer: canonical root, split_rel containment, dirfd + O_NOFOLLOW writes, từ chối symlink/hardlink/`..`, atomic replace kèm fsync; CLI 14 lệnh |
| `scripts/opk_tx.py` | Transaction layer: begin/stage/commit/rollback/recover; backup + sha256 từng op, flock, MERGE_MARKER idempotent, journal + manifest `.opk-state/transactions/`, auto-rollback và crash recovery; từ chối `OPK_TEST_FAIL_AFTER` ngoài test mode |
| `scripts/opk_tx.sh` | Bash wrapper cho transaction CLI; exit code fail-closed 0/1/2/3 |
| `scripts/test-safe-io.sh` | Test safe-I/O: roundtrip, symlink matrix, escape, hardlink alias, atomicity, require-absent (39 checks) |
| `scripts/test-tx.sh` | Test transaction: happy path, rollback, marker idempotency, injected failures, crash recovery, locking (36 checks) |
| `scripts/test-install-tx.sh` | Test install.sh qua transaction: giữ nội dung user, marker idempotent, report ghi đè, crash → recovery (21 checks) |
| `scripts/cleanup-agent-artifacts.sh` | Dọn artifact bằng cơ chế move-to-trash |
| `scripts/audit-ecc.sh` | Audit ECC read-only |
| `scripts/install-ecc-lite.sh` | Cài ECC-lite |
| `scripts/check-ecc-lite.sh` | Kiểm tra ECC-lite |
| `scripts/audit-hermes.sh` | Audit Hermes-lite; mặc định read-only, chỉ `--write` cập nhật `docs/HERMES_AUDIT.md` |
| `scripts/check-hermes-lite.sh` | Kiểm tra Hermes-lite |
| `scripts/hermes-learning-capsule.sh` | Đóng gói learning capsule |

Các entrypoint chính đều nạp `scripts/require-linux.sh`. Release chính thức chỉ
được chấp nhận khi `bash scripts/release-gate.sh` trả exit code `0`.
