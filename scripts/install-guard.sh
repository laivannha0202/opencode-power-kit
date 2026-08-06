#!/usr/bin/env bash
# ============================================================================
# install-guard.sh — install/uninstall/check the BASH_ENV command guard
#
# Installs the self-contained guard fragment (templates/guard/opk-guard-bashrc,
# generated from scripts/guard-rules.sh) to:
#     $HOME/.config/opencode-power-kit/guard/opk-guard-bashrc
# and wires the BASH_ENV export into ~/.bashrc (idempotent marker block),
# so every non-interactive bash child (CI, scripts, `opk run`/opencode
# subprocesses) is guarded BEFORE dangerous commands execute.
#
# Usage:
#   bash scripts/install-guard.sh            # install (with confirm)
#   bash scripts/install-guard.sh --yes      # install without confirm
#   bash scripts/install-guard.sh --check    # report status, no changes
#   bash scripts/install-guard.sh --uninstall  # remove fragment + bashrc block
#   opk guard status|install|uninstall       # via CLI wrapper
#
# Safety:
#   - No sudo, no curl|sh
#   - Atomic write (temp file + rename), refuse symlink targets
#   - Idempotent: repeated installs never duplicate the bashrc block
#   - --uninstall only removes OUR marked block, never user lines
#   - No bypass variable, no allowlist — the guard itself rejects both
# ============================================================================
set -euo pipefail

# --- Resolve kit dir ---
SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Config ---
FRAGMENT="$KIT_DIR/templates/guard/opk-guard-bashrc"
GUARD_DIR="${OPK_GUARD_DIR:-$HOME/.config/opencode-power-kit/guard}"
TARGET_FILE="$GUARD_DIR/opk-guard-bashrc"
BASHRC="$HOME/.bashrc"
MARKER_BEGIN="# >>> opencode-power-kit guard (opk guard install) >>>"
MARKER_END="# <<< opencode-power-kit guard <<<"

MODE="install"
SKIP_CONFIRM=0

fail() {
	echo "install-guard: LỖI — $*" >&2
	exit 1
}

parse_args() {
	for a in "$@"; do
		case "$a" in
		--yes | -Y | -y) SKIP_CONFIRM=1 ;;
		--check | status) MODE="check" ;;
		--uninstall | off) MODE="uninstall" ;;
		--help | -h) echo "usage: install-guard.sh [--yes] [--check] [--uninstall]"; exit 0 ;;
		*) fail "tham số không hợp lệ: $a" ;;
		esac
	done
}

guard_installed() {
	[[ -f "$TARGET_FILE" && ! -L "$TARGET_FILE" ]] || return 1
	grep -qF "OPK_GUARD_LOADED" "$TARGET_FILE" 2>/dev/null || return 1
	return 0
}

bashrc_wired() {
	[[ -f "$BASHRC" ]] || return 1
	grep -qF "$MARKER_BEGIN" "$BASHRC" 2>/dev/null || return 1
	grep -qF "$MARKER_END" "$BASHRC" 2>/dev/null || return 1
	return 0
}

# Validate fragment content BEFORE touching anything: it must be the real
# generated guard (marker + engine), not an arbitrary file, and must contain
# neither a bypass variable nor an allowlist.
validate_fragment() {
	[[ -f "$FRAGMENT" && ! -L "$FRAGMENT" ]] || fail "guard fragment không phải regular file: $FRAGMENT"
	grep -qF "opk-guard-bashrc" "$FRAGMENT" || fail "fragment thiếu header marker: $FRAGMENT"
	grep -qF "OPK_GUARD_LOADED" "$FRAGMENT" || fail "fragment thiếu OPK_GUARD_LOADED marker"
	grep -qF "trap '_opk_guard_debug' DEBUG" "$FRAGMENT" || fail "fragment thiếu DEBUG trap glue"
	if rg -q "OPK_GUARD_SKIP|ALLOWLIST_PATTERNS" "$FRAGMENT" >/dev/null 2>&1; then
		fail "fragment chứa bypass (OPK_GUARD_SKIP) hoặc allowlist — từ chối cài"
	fi
}

# Sync-freshness gate: refuse to install a fragment whose embedded engine
# differs from the committed scripts/guard-rules.sh (read-only via --stdout).
check_fresh() {
	local gen
	gen="$("$SCRIPT_DIR/sync-guard-bashrc.sh" --stdout 2>/dev/null)" || fail "không thể generate fragment (sync-guard-bashrc.sh --stdout)"
	if [[ "$gen" != "$(cat "$FRAGMENT")" ]]; then
		fail "fragment template stale so với scripts/guard-rules.sh — chạy scripts/sync-guard-bashrc.sh trước"
	fi
}

install_guard() {
	validate_fragment
	check_fresh

	echo "install-guard: Sẽ cài BASH_ENV command guard:"
	echo "  Fragment: $TARGET_FILE"
	echo "  Bashrc:   $BASHRC (block có marker, idempotent)"
	echo ""
	echo "  Guard chặn trước khi lệnh chạy (mọi bash con non-interactive):"
	echo "    - rm -rf, git reset --hard, git clean -fd, force push (kể cả git -C <dir>)"
	echo "    - curl|sh, wget|sh pipe-to-shell"
	echo "    - SQL DROP TABLE, TRUNCATE, DELETE FROM không WHERE"
	echo "    - Redirect/tee vào file nhạy cảm (.env, secret, private key)"
	echo "  Không có biến bypass, không allowlist — muốn chạy lệnh bị chặn thì chạy bằng tay."
	echo ""

	if [[ "$SKIP_CONFIRM" -eq 0 ]]; then
		read -r -p "Tiếp tục? [y/N] " reply
		case "$reply" in
		[yY] | [yY][eE][sS]) ;;
		*)
			echo "install-guard: Đã hủy."
			exit 0
			;;
		esac
	fi

	# --- Fragment install (atomic, refuse symlinks) ---
	if guard_installed; then
		echo "install-guard: fragment đã cài (giữ nguyên: $TARGET_FILE)"
	else
		[[ ! -L "$GUARD_DIR" ]] || fail "từ chối symlink: $GUARD_DIR"
		[[ ! -e "$GUARD_DIR" || -d "$GUARD_DIR" ]] || fail "guard dir không phải directory: $GUARD_DIR"
		[[ ! -L "$TARGET_FILE" ]] || fail "từ chối symlink target: $TARGET_FILE"
		[[ ! -e "$TARGET_FILE" || -f "$TARGET_FILE" ]] || fail "target không phải regular file: $TARGET_FILE"
		mkdir -p "$GUARD_DIR"
		local tmp
		tmp="$(mktemp "$GUARD_DIR/opk-guard.XXXXXX")"
		cat "$FRAGMENT" > "$tmp"
		chmod 0644 "$tmp"
		mv "$tmp" "$TARGET_FILE"
		echo "install-guard: đã cài fragment -> $TARGET_FILE"
	fi

	# --- Bashrc wiring (idempotent marker block) ---
	if bashrc_wired; then
		echo "install-guard: BASH_ENV block đã có sẵn trong ~/.bashrc (giữ nguyên)"
	else
		[[ -f "$BASHRC" && ! -L "$BASHRC" ]] || fail "~/.bashrc không phải regular file: $BASHRC"
		local tmp_rc
		tmp_rc="$(mktemp "${TMPDIR:-/tmp}/opk-bashrc.XXXXXX")"
		{
			cat "$BASHRC"
			echo ""
			echo "$MARKER_BEGIN"
			echo "export BASH_ENV=\"$TARGET_FILE\""
			echo "# BASH_ENV guards every non-interactive bash child BEFORE commands run."
			echo "$MARKER_END"
		} > "$tmp_rc"
		chmod "$(stat -c %a "$BASHRC")" "$tmp_rc"
		mv "$tmp_rc" "$BASHRC"
		echo "install-guard: đã thêm BASH_ENV export vào ~/.bashrc"
	fi

	echo ""
	echo "install-guard: ✅ Đã cài BASH_ENV command guard."
	echo "   Kiểm tra: opk guard status   |   Gỡ: opk guard uninstall"
	echo "   Guard áp dụng cho bash con mới (CI, script, subprocess)."
}

uninstall_guard() {
	local changed=0
	if [[ -e "$TARGET_FILE" || -L "$TARGET_FILE" ]]; then
		rm -f "$TARGET_FILE"
		echo "install-guard: đã xóa $TARGET_FILE"
		changed=1
	fi
	if [[ -f "$BASHRC" ]]; then
		if grep -qF "$MARKER_BEGIN" "$BASHRC"; then
			local tmp_rc
			tmp_rc="$(mktemp "${TMPDIR:-/tmp}/opk-bashrc.XXXXXX")"
			awk -v b="$MARKER_BEGIN" -v e="$MARKER_END" '
				$0 == b { skip=1; next }
				$0 == e { skip=0; next }
				skip != 1 { print }
			' "$BASHRC" > "$tmp_rc"
			chmod "$(stat -c %a "$BASHRC")" "$tmp_rc"
			mv "$tmp_rc" "$BASHRC"
			echo "install-guard: đã gỡ BASH_ENV block khỏi ~/.bashrc"
			changed=1
		fi
	fi
	[[ $changed -eq 1 ]] && echo "install-guard: ✅ Đã gỡ guard." || echo "install-guard: không có gì để gỡ."
}

check_guard() {
	validate_fragment || fail "guard fragment template hỏng: $FRAGMENT (chạy scripts/sync-guard-bashrc.sh)"
	echo "install-guard: fragment template: OK ($FRAGMENT)"
	if guard_installed; then
		echo "install-guard: fragment đã cài: OK ($TARGET_FILE)"
	else
		echo "install-guard: fragment CHƯA cài ($TARGET_FILE)"
	fi
	if bashrc_wired; then
		echo "install-guard: BASH_ENV block trong ~/.bashrc: OK"
	else
		echo "install-guard: BASH_ENV block CHƯA có trong ~/.bashrc"
	fi
	echo "install-guard: BASH_ENV hiện tại: ${BASH_ENV:-<không set>}"
}

parse_args "$@"
case "$MODE" in
install) install_guard ;;
uninstall) uninstall_guard ;;
check) check_guard ;;
esac
