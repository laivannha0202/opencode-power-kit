#!/usr/bin/env bash
# Shared platform guard for supported OPK entrypoints.

opk_require_linux() {
	local platform
	platform="$(uname -s 2>/dev/null || true)"
	if [[ "$platform" != "Linux" ]]; then
		echo "opk: nền tảng không được hỗ trợ: ${platform:-unknown}. OpenCode Power Kit v2.1.0 chỉ hỗ trợ Linux." >&2
		return 126
	fi
}
