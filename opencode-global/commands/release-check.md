---
description: Kiểm tra VERSION, README badge, CHANGELOG, tag trước release
---

# /release-check

Kiểm tra toàn bộ release artifacts trước khi release.

## Checklist

### 1. VERSION file
```bash
cat VERSION
# So khớp với CHANGELOG.md version mới nhất
```

### 2. CHANGELOG.md
- [Unreleased] section tồn tại? (nếu có thay đổi chưa release)
- Version mới nhất match VERSION file?
- Đủ sections: Added / Changed / Fixed / Removed?
- Date format: `YYYY-MM-DD`.
- Keep a Changelog format?

### 3. README badge
- Version badge khớp VERSION?
- CI badge status?
- Các badge khác (license, bmad, ...) OK?

### 4. Git tag
```bash
git tag -l 'v*' | sort -V | tail -5
# Check tag v{VERSION} chưa tồn tại (tránh overwrite)
```

### 5. Git status
```bash
git status --short
git diff --stat
# Working tree sạch? Chỉ có VERSION/CHANGELOG/README thay đổi?
```

### 6. CI status
Kiểm tra GitHub Actions / CI passes trên main branch.

## Output
```
## Release Check Report
- **VERSION:** v{current} ✓
- **CHANGELOG:** valid ✓ (issues: ...)
- **README badges:** match ✓
- **Git tag:** v{current} (not exists / exists) ✓
- **CI:** green ✓
- **Ready to release:** YES / NO (blockers: ...)
```
