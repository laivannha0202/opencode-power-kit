# Release Process

## Prerequisites

- Clean working tree (`git status` shows no uncommitted changes)
- All tests pass (`opk verify` or `verify.sh`/`verify.ps1`)
- Local tags match `VERSION` file
- `CHANGELOG.md` updated for current version

## Steps

### 1. Update VERSION

```bash
echo "1.x.x" > VERSION
git add VERSION && git commit -m "chore: bump version to 1.x.x"
```

### 2. Update CHANGELOG.md

- Add entry for the new version under `# Changelog`
- Follow [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format

### 3. Create Release Notes

```bash
cp docs/releases/v1.x.x.md docs/releases/v1.x.x.md
# Edit to reflect changes
```

### 4. Tag

```bash
git tag v1.x.x
git push origin v1.x.x
```

### 5. Create GitHub Release

```bash
gh release create v1.x.x --title "v1.x.x — Release Name" --notes-file docs/releases/v1.x.x.md
```

### 6. Verify

- Confirm GitHub Release exists
- Confirm tag is pushed
- Confirm CI passes on the tag

## Versioning Scheme

- **Major (x.0.0):** Breaking changes, full rewrites, major architecture shifts
- **Minor (1.x.0):** New features, backward-compatible enhancements
- **Patch (1.0.x):** Bug fixes, documentation, non-breaking improvements
