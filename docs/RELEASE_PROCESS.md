# Quy trình Release

## Yêu cầu trước khi release

- Working tree sạch (`git status` không có thay đổi chưa commit)
- Tất cả tests pass (`opk verify` hoặc `verify.sh`/`verify.ps1`)
- Local tags khớp với file `VERSION`
- `CHANGELOG.md` đã cập nhật cho phiên bản hiện tại

## Các bước thực hiện

### 1. Cập nhật VERSION

```bash
echo "1.x.x" > VERSION
git add VERSION && git commit -m "chore: bump version to 1.x.x"
```

### 2. Cập nhật CHANGELOG.md

- Thêm mục cho phiên bản mới dưới `# Changelog`
- Theo format [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)

### 3. Tạo Release Notes

```bash
cp docs/releases/v1.x.x.md docs/releases/v1.x.x.md
# Chỉnh sửa nội dung
```

### 4. Tag

```bash
git tag v1.x.x
git push origin v1.x.x
```

### 5. Tạo GitHub Release

```bash
gh release create v1.x.x --title "v1.x.x — Release Name" --notes-file docs/releases/v1.x.x.md
```

### 6. Kiểm tra

- Xác nhận GitHub Release đã tồn tại
- Xác nhận tag đã được push
- Xác nhận CI pass trên tag

## Sơ đồ phiên bản

- **Major (x.0.0):** Thay đổi phá vỡ tương thích, viết lại lớn, thay đổi kiến trúc
- **Minor (1.x.0):** Tính năng mới, cải tiến tương thích ngược
- **Patch (1.0.x):** Sửa lỗi, tài liệu, cải tiến không phá vỡ tương thích
