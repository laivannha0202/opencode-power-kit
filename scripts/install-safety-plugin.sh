#!/usr/bin/env bash
# ============================================================================
# install-safety-plugin.sh
#
# Cài safety plugin guard (opk-safety-guard.js) vào project hiện tại.
# Plugin được copy từ templates/plugins/ vào .opencode/plugins/
#
# Usage:
#   bash scripts/install-safety-plugin.sh
#   bash scripts/install-safety-plugin.sh --yes    (skip confirm)
#   opk safety-plugin install                      (qua CLI wrapper)
#
# Safety:
#   - Không sudo, không curl|sh
#   - Chỉ copy file template, không xóa file user
#   - Backup nếu file đã tồn tại
# ============================================================================
set -euo pipefail

# --- Resolve kit dir ---
SELF="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SELF")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- Config ---
TEMPLATE_FILE="$KIT_DIR/templates/plugins/opk-safety-guard.js"
TARGET_REL=".opencode/plugins/opk-safety-guard.js"
SKIP_CONFIRM=0
PROJECT_DIR=""
TARGET_DIR=""
TARGET_FILE=""

fail() {
	echo "install-safety-plugin: LỖI — $*" >&2
	exit 1
}

validate_destination() {
	[[ "$PROJECT_DIR" == /* && -d "$PROJECT_DIR" ]] || fail "đường dẫn project không hợp lệ: $PROJECT_DIR"
	[[ ! -L "$PROJECT_DIR/.opencode" ]] || fail "từ chối symlink: $PROJECT_DIR/.opencode"
	[[ ! -e "$PROJECT_DIR/.opencode" || -d "$PROJECT_DIR/.opencode" ]] || fail ".opencode không phải directory"
	[[ ! -L "$TARGET_DIR" ]] || fail "từ chối symlink: $TARGET_DIR"
	[[ ! -e "$TARGET_DIR" || -d "$TARGET_DIR" ]] || fail ".opencode/plugins không phải directory"
	[[ ! -L "$TARGET_FILE" ]] || fail "từ chối symlink target: $TARGET_FILE"
	[[ ! -e "$TARGET_FILE" || -f "$TARGET_FILE" ]] || fail "target không phải regular file"
}

for a in "$@"; do
	case "$a" in
	--yes | -Y | -y) SKIP_CONFIRM=1 ;;
	esac
done

# --- Check template exists ---
if [[ ! -f "$TEMPLATE_FILE" || -L "$TEMPLATE_FILE" ]]; then
	fail "không tìm thấy regular template: $TEMPLATE_FILE"
fi

# --- Resolve and validate project/destination before creating anything ---
PROJECT_DIR="$(pwd -P 2>/dev/null)" || fail "không thể chuẩn hóa project hiện tại"
[[ "$PROJECT_DIR" == /* ]] || fail "project phải là đường dẫn tuyệt đối"
[[ "$(realpath -e -- "$PROJECT_DIR" 2>/dev/null)" == "$PROJECT_DIR" ]] || fail "project không phải đường dẫn tuyệt đối hợp lệ"
TARGET_DIR="$PROJECT_DIR/.opencode/plugins"
TARGET_FILE="$PROJECT_DIR/$TARGET_REL"
TARGET_DIR_NORMALIZED="$(realpath -m -- "$TARGET_DIR" 2>/dev/null)" || fail "không thể chuẩn hóa destination directory"
TARGET_FILE_NORMALIZED="$(realpath -m -- "$TARGET_FILE" 2>/dev/null)" || fail "không thể chuẩn hóa destination file"
[[ "$TARGET_DIR_NORMALIZED" == "$PROJECT_DIR/.opencode/plugins" ]] || fail "destination directory thoát khỏi project"
case "$TARGET_FILE_NORMALIZED" in
"$PROJECT_DIR/.opencode/plugins/"*) ;;
*) fail "destination file thoát khỏi $PROJECT_DIR/.opencode/plugins/" ;;
esac
validate_destination

# --- Check project dir ---
if [[ ! -f "$PROJECT_DIR/opencode.json" && ! -f "$PROJECT_DIR/AGENTS.md" && ! -f "$PROJECT_DIR/OPENCODE.md" ]]; then
	echo "install-safety-plugin: CẢNH BÁO — $PROJECT_DIR có vẻ không phải project OpenCode." >&2
	echo "  (Không tìm thấy opencode.json, AGENTS.md, hay OPENCODE.md)" >&2
	if [[ "$SKIP_CONFIRM" -eq 0 ]]; then
		read -r -p "  Tiếp tục cài safety plugin? [y/N] " reply
		case "$reply" in
		[yY] | [yY][eE][sS]) ;;
		*)
			echo "install-safety-plugin: Đã hủy."
			exit 0
			;;
		esac
	fi
fi

# --- Confirm ---
echo "install-safety-plugin: Sẽ cài safety plugin guard vào:"
echo "  Template: $TEMPLATE_FILE"
echo "  Target:   $TARGET_FILE"
echo ""
echo "  Guard chặn:"
echo "    - Đọc file nhạy cảm (.env, secret, private key)"
echo "    - rm -rf, git reset --hard, git clean -fd, force push"
echo "    - SQL DROP TABLE, TRUNCATE, DELETE FROM không WHERE"
echo ""

if [[ "$SKIP_CONFIRM" -eq 0 ]]; then
	read -r -p "Tiếp tục? [y/N] " reply
	case "$reply" in
	[yY] | [yY][eE][sS]) ;;
	*)
		echo "install-safety-plugin: Đã hủy."
		exit 0
		;;
	esac
fi

# --- Safely create/open directories and install relative to directory FDs ---
# Python provides O_NOFOLLOW + dir_fd operations unavailable in portable Bash.
if python3 - "$PROJECT_DIR" "$TEMPLATE_FILE" <<'PY'
import ctypes
import errno
import os
import secrets
import stat
import sys
from datetime import datetime

project, template = sys.argv[1:]
marker = b"@opk-plugin opk-safety-guard"
target_name = "opk-safety-guard.js"
temp_name = None
backup_name = None
project_fd = opencode_fd = plugins_fd = target_fd = template_fd = temp_fd = None
temp_stat = None


def fail(message):
    print(f"install-safety-plugin: LỖI — {message}", file=sys.stderr)
    raise RuntimeError(message)


def open_directory(parent_fd, name):
    try:
        os.mkdir(name, 0o755, dir_fd=parent_fd)
    except FileExistsError:
        pass
    try:
        descriptor = os.open(
            name,
            os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
            dir_fd=parent_fd,
        )
    except OSError as exc:
        fail(f"từ chối directory không an toàn {name}: {exc.strerror}")
    if not stat.S_ISDIR(os.fstat(descriptor).st_mode):
        os.close(descriptor)
        fail(f"{name} không phải directory")
    return descriptor


def lstat_at(parent_fd, name):
    try:
        return os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
    except FileNotFoundError:
        return None


def same_file(left, right):
    return left is not None and right is not None and (left.st_dev, left.st_ino) == (right.st_dev, right.st_ino)


def unique_name(prefix):
    for _ in range(32):
        candidate = f"{prefix}{secrets.token_hex(6)}"
        if lstat_at(plugins_fd, candidate) is None:
            return candidate
    fail(f"không thể tạo tên duy nhất cho {prefix}")


def link_fd_noreplace(source_fd, destination):
    libc = ctypes.CDLL(None, use_errno=True)
    linkat = libc.linkat
    linkat.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_int]
    linkat.restype = ctypes.c_int
    at_empty_path = 0x1000
    if linkat(source_fd, b"", plugins_fd, os.fsencode(destination), at_empty_path) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), destination)


def rename_name_noreplace(source, destination):
    libc = ctypes.CDLL(None, use_errno=True)
    renameat2 = libc.renameat2
    renameat2.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
    renameat2.restype = ctypes.c_int
    rename_noreplace = 1
    if renameat2(
        plugins_fd,
        os.fsencode(source),
        plugins_fd,
        os.fsencode(destination),
        rename_noreplace,
    ) != 0:
        error = ctypes.get_errno()
        raise OSError(error, os.strerror(error), destination)


try:
    if os.path.realpath(".") != project:
        fail("current project thay đổi trước khi mở directory descriptor")
    project_fd = os.open(".", os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    opencode_fd = open_directory(project_fd, ".opencode")
    plugins_fd = open_directory(opencode_fd, "plugins")

    target_stat = lstat_at(plugins_fd, target_name)
    if target_stat is not None:
        if stat.S_ISLNK(target_stat.st_mode):
            fail("từ chối symlink target")
        if not stat.S_ISREG(target_stat.st_mode):
            fail("target không phải regular file")
        target_fd = os.open(target_name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=plugins_fd)
        opened_stat = os.fstat(target_fd)
        if not same_file(target_stat, opened_stat) or not stat.S_ISREG(opened_stat.st_mode):
            fail("target thay đổi trong lúc kiểm tra")
        target_data = bytearray()
        while chunk := os.read(target_fd, 1024 * 1024):
            target_data.extend(chunk)
        if marker not in target_data:
            print("install-safety-plugin: ⚠️  File đã tồn tại nhưng KHÔNG phải OPK plugin.")
            print("   Bỏ qua để không ghi đè plugin tùy chỉnh của bạn.")
            print("   Nếu muốn cài OPK plugin, hãy xóa/đổi tên file rồi chạy lại.")
            sys.exit(20)

    template_fd = os.open(template, os.O_RDONLY | os.O_NOFOLLOW)
    if not stat.S_ISREG(os.fstat(template_fd).st_mode):
        fail("template không phải regular file")

    temp_name = unique_name(".opk-safety-guard.tmp.")
    temp_fd = os.open(
        temp_name,
        os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
        0o600,
        dir_fd=plugins_fd,
    )
    temp_stat = os.fstat(temp_fd)
    while chunk := os.read(template_fd, 1024 * 1024):
        view = memoryview(chunk)
        while view:
            written = os.write(temp_fd, view)
            view = view[written:]
    os.fchmod(temp_fd, 0o644)
    os.fsync(temp_fd)
    temp_stat = os.fstat(temp_fd)

    current_stat = lstat_at(plugins_fd, target_name)
    if target_stat is None:
        if current_stat is not None:
            fail("target xuất hiện trong lúc cài; từ chối ghi đè")
    elif not same_file(target_stat, current_stat):
        fail("target thay đổi trong lúc cài; từ chối ghi đè")
    else:
        timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
        backup_name = unique_name(f"{target_name}.bak.{timestamp}.")
        rename_name_noreplace(target_name, backup_name)
        if not same_file(target_stat, lstat_at(plugins_fd, backup_name)):
            try:
                link_fd_noreplace(target_fd, target_name)
            except OSError as exc:
                if exc.errno != errno.EEXIST:
                    fail(f"không thể khôi phục target sau race: {exc.strerror}")
            fail("target thay đổi trong lúc tạo backup; file đã di chuyển được giữ ở backup")

    try:
        link_fd_noreplace(temp_fd, target_name)
        if not same_file(temp_stat, lstat_at(plugins_fd, target_name)):
            fail("không thể xác minh plugin vừa publish")
        if same_file(temp_stat, lstat_at(plugins_fd, temp_name)):
            os.unlink(temp_name, dir_fd=plugins_fd)
        temp_name = None
    except OSError as exc:
        if backup_name is not None:
            if lstat_at(plugins_fd, target_name) is None:
                try:
                    link_fd_noreplace(target_fd, target_name)
                except OSError as restore_exc:
                    if restore_exc.errno != errno.EEXIST:
                        fail(f"không thể khôi phục OPK plugin: {restore_exc.strerror}")
            live_target = lstat_at(plugins_fd, target_name)
            live_backup = lstat_at(plugins_fd, backup_name)
            if same_file(target_stat, live_target) and same_file(target_stat, live_backup):
                os.unlink(backup_name, dir_fd=plugins_fd)
                backup_name = None
        if exc.errno == errno.EEXIST:
            fail("target xuất hiện trong lúc atomic publish; từ chối ghi đè")
        fail(f"atomic publish thất bại: {exc.strerror}")

    if backup_name is not None:
        print(f"install-safety-plugin: Backup OPK plugin cũ -> {project}/.opencode/plugins/{backup_name}")
except RuntimeError:
    sys.exit(1)
finally:
    if temp_name is not None and plugins_fd is not None:
        try:
            if same_file(temp_stat, lstat_at(plugins_fd, temp_name)):
                os.unlink(temp_name, dir_fd=plugins_fd)
        except FileNotFoundError:
            pass
    for descriptor in (temp_fd, template_fd, target_fd, plugins_fd, opencode_fd, project_fd):
        if descriptor is not None:
            try:
                os.close(descriptor)
            except OSError:
                pass
PY
then
	install_rc=0
else
	install_rc=$?
fi
case "$install_rc" in
0) ;;
20) exit 0 ;;
*) exit "$install_rc" ;;
esac

echo "install-safety-plugin: ✅ Đã cài safety plugin guard (runtime OpenCode plugin)."
echo "   File: $TARGET_FILE"
echo ""
echo "   Đây là RUNTIME plugin — OpenCode sẽ gọi hook tool.execute.before"
echo "   để chặn đọc file nhạy cảm và command nguy hiểm."
echo "   (KHÁC với scripts/opk-command-guard.sh — đó là manual CLI shell guard,"
echo "   không intercept OpenCode tool call.)"
echo ""
echo "   Để kiểm tra: opk safety-plugin status"
