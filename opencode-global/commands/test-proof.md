Chạy và đề xuất test chứng minh tính đúng:
1. Test tự động: unit/integration/e2e phù hợp stack.
2. Test thủ công: command + input + expected output.
3. Edge case: input rỗng, null, max, unicode, concurrent.
4. Repro script: 1 shell snippet copy-paste chạy được.

Output dạng bảng: Case | Input | Expected | Actual | Pass/Fail.
Nếu không có test infra: đề xuất stack test tối thiểu (1 file, 1 framework).
Không chạy test nặng trên prod. Không touch DB thật nếu không có sandbox.
