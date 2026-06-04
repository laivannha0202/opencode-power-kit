Chia task thành các bước nhỏ, mỗi bước có:
- Bước N: mô tả 1 dòng.
- Files: list file path sẽ chạm (ưu tiên ≤ 2 file/bước).
- Test: lệnh cần chạy để verify (test/typecheck/lint/build).
- Done-when: 1 dòng mô tả output kỳ vọng.

Nguyên tắc: tổng ≤ 7 bước. Bước nào > 30 phút thì tách. Mỗi bước commit được. Không sửa file ở bước này.
