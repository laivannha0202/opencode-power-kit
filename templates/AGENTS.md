# OpenCode Power Kit Project Rules

## Language

- Trả lời user bằng tiếng Việt theo mặc định.
- Giữ tiếng Anh cho code, command, path, API, package, log, stacktrace và keyword kỹ thuật.
- Chỉ đổi ngôn ngữ khi user yêu cầu rõ.

## Scope

- Yêu cầu read-only/docs-only/"không sửa file" luôn thắng mọi router.
- Khi scope chỉ là review hoặc audit: không gọi build-strong, không sửa code, không commit, không push.
- Không biến một yêu cầu kiểm tra thành implementation nếu user chưa yêu cầu fix.

## Safety

- Kiểm tra `git status --short` trước và sau task có thay đổi file.
- Không dùng `rm -rf`, `git reset --hard`, `git clean -fd`, force push hoặc rewrite history.
- Không đọc, sửa hoặc in `.env`, token, secret, private key hay credential.
- Không chạy `DROP`, `TRUNCATE`, mass `DELETE` hoặc migration dữ liệu nguy hiểm khi chưa có backup và yêu cầu rõ.
- Không tự push, tạo PR, tag hoặc publish nếu user chưa yêu cầu.
- Chỉ stage file có chủ đích; không dùng `git add .` hoặc `git add -A`.
- Tôn trọng file đang dirty của user; không stash, discard hoặc ghi đè thay đổi ngoài scope.

OpenCode permissions chặn thẳng secret reads, destructive commands, external paths và doom loops. Instruction này là lớp bảo vệ bổ sung, không thay thế permission deny rules.

## Workflow

1. Xác định acceptance criteria và file liên quan.
2. Dùng `rg`, `fd`, `git diff --stat` và symbol/LSP search trước khi đọc file lớn.
3. Không scan `.git`, `node_modules`, `dist`, `build`, `coverage`, generated output hoặc lockfile lớn nếu không cần.
4. Với bug: reproduce, tìm root cause, viết regression test, rồi sửa nhỏ nhất.
5. Với behavior mới: test fail trước, implementation tối thiểu, test pass, refactor sau.
6. Chạy targeted test/lint/typecheck cho phần vừa đổi.
7. Chỉ chạy full release gate trước commit cuối và sau commit cuối khi task là release.
8. Báo file đã sửa, lý do, lệnh verify và rủi ro còn lại.

## Lightweight Routing

- Task nhỏ, một module, tối đa 2 file: main/build agent, targeted search, targeted test. Không bắt buộc subagent.
- Review đơn giản: đọc `git diff --stat`, rồi diff/file liên quan. Không bắt buộc Task tool.
- Task nhiều layer hoặc contract FE/BE/DB: mới dùng `build-strong`.
- BMAD chỉ dùng cho project mới, PRD/spec lớn, domain research hoặc nhiều milestone.
- Không spawn agent chỉ vì có thể. Không tự chạy full research cho task cục bộ.
- Không tạo `AI_HANDOFF.md`, report file hoặc checkpoint cho task nhỏ nếu chat đủ truyền đạt.

## Power And Safe Modes

- Power Mode cho phép read/edit/search/bash/task/skill bình thường trong project mà không tạo approval prompt.
- Power Mode vẫn deny destructive commands, secret reads, external directories và doom loops.
- Agent implementation phải kế thừa permission hiện hành; không hardcode `ask`.
- Agent review/read-only giữ `edit: deny` và chỉ allow command đọc cần thiết.
- Safe Mode có thể dùng `ask` cho edit/bash/task và không làm thay đổi model/provider/MCP/plugin.
- Dùng `opk permissions doctor` để xem permission hiệu lực; không suy luận chỉ từ template.

## Search And Output Budget

- Giới hạn phạm vi search và context lines; tránh output toàn repository.
- Dùng `git diff --stat` trước diff chi tiết.
- Không mở generated files hoặc binary.
- Dùng compaction/pruning thay vì xóa capability.
- Giữ tool output đủ để debug; chỉ cắt noise không liên quan.

## Completion

- Không nói pass/fixed/complete nếu chưa chạy command chứng minh trong lượt hiện tại.
- Nếu không thể chạy test, nêu rõ test nào chưa chạy và lý do.
- Cuối task luôn báo `git status --short` nếu đã thay đổi workspace.
