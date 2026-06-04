# Dependency Maintenance

Quy tắc update + bảo trì dependency an toàn, không đứt build.

## Lockfile

- Commit lockfile: `package-lock.json` (npm), `pnpm-lock.yaml` (pnpm), `yarn.lock` (yarn), `bun.lockb` (bun).
- KHÔNG tự ý xóa lockfile.
- CI install: `npm ci` (npm) / `pnpm install --frozen-lockfile` / `yarn install --frozen-lockfile`.
- Local: `npm install` OK (sẽ update lockfile).

## Update strategy

### Patch (1.0.x)

- Tự động qua Renovate / Dependabot.
- Changelog thường bugfix, an toàn.
- Test tự động quyết định merge.

### Minor (1.x.0)

- Feature mới, deprecation warning.
- Renovate auto-PR, review changelog.
- Test kỹ nếu dùng feature bị deprecate.

### Major (x.0.0)

- Breaking change.
- Đọc CHANGELOG + migration guide.
- Refactor code theo hướng dẫn.
- Tách PR: 1 commit / major version, dễ revert.
- Test integration + E2E trước khi merge.

## Renovate config (xem `templates/renovate.json.example`)

- Schedule: weekend + off-peak.
- Group: tất cả patch update 1 PR, minor cùng group 1 PR.
- Lock file maintenance: tự động rebase.
- Vulnerability alert: auto-PR ngay.
- Major update: chỉ thông báo, không auto-PR.

## Audit

- `npm audit` / `pnpm audit` mỗi PR.
- Severity HIGH / CRITICAL: block merge.
- Severity MODERATE: review + lên lịch.
- Severity LOW: gộp cuối sprint.

## Tránh đứt build

- Đọc peer dependency warning.
- Major upgrade: làm 1 lần, không gộp nhiều major.
- Test trên feature branch, không trên main.
- Cache dependency qua action cache để CI nhanh.
- Pin version cho tool build (typescript, vite, webpack) — major upgrade thường đứt.

## Khi nào xóa dependency

- Không còn dùng → xóa.
- Có thay thế tốt hơn → migration guide đầy đủ.
- Không còn maintain → fork hoặc thay thế.
- Bundle size > 100KB → xem xét tree-shaking hoặc thay thế.

## Supply chain

- Verify package: lượt download, repo GitHub, tác giả.
- Cảnh báo package mới published (npm takedown thường xuyên).
- Pin exact version cho package nhạy cảm: `"lodash": "4.17.21"`.
- Private registry (npm enterprise, GitHub Packages) cho internal package.
- `npm install --ignore-scripts` nếu nghi ngờ post-install script.

## Reference

- [Renovate docs](https://docs.renovatebot.com)
- [Dependabot docs](https://docs.github.com/en/code-security/dependabot)
- [Snyk](https://snyk.io)
- [npm audit](https://docs.npmjs.com/cli/v10/commands/npm-audit)
