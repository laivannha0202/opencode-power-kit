#!/usr/bin/env bash
set -euo pipefail
KIT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$KIT_DIR/scripts/require-linux.sh"
opk_require_linux
source "$KIT_DIR/scripts/upstream-versions.sh"
[[ "$(id -u)" -ne 0 ]] || { echo 'ERROR: do not run with sudo/root' >&2; exit 1; }
MODE=interactive
while (($#)); do
  case "$1" in
    --dry-run) MODE=dry-run ;;
    --yes|-y) MODE=yes ;;
    -h|--help) echo 'Usage: update-bmad.sh [--dry-run] [--yes]'; exit 0 ;;
    *) echo "ERROR: unknown flag: $1" >&2; exit 2 ;;
  esac
  shift
done
VERSION="${BMAD_METHOD_VERSION:-$OPK_BMAD_VERSION}"
TARGET="$(pwd -P)"
if ! ACTIVE_CONFIG="$(python3 - "$KIT_DIR/scripts" "$TARGET" <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, sys.argv[1])
from opk_mode import resolve_config_path

try:
    path = resolve_config_path(Path(sys.argv[2]), required=True)
except ValueError as exc:
    print(f"ERROR: {exc}", file=sys.stderr)
    raise SystemExit(1)

print(path.name)
PY
)"; then
  echo 'ERROR: run opk install first or opk mode migrate; exactly one of opencode.json/opencode.jsonc is required' >&2
  exit 1
fi
echo "OpenCode config: $ACTIVE_CONFIG"
CMD=(npx --yes "bmad-method@$VERSION" install --modules bmm --tools opencode --user-name "${OPK_USER_NAME:-${USER:-User}}" --communication-language Vietnamese --document-output-language Vietnamese --directory "$TARGET" -y)
printf 'BMAD plan:'; printf ' %q' "${CMD[@]}"; printf '\n'
[[ "$MODE" == dry-run ]] && exit 0
if ! bash "$KIT_DIR/scripts/check-bmad-runtime-prereqs.sh"; then
  echo "ERROR: BMAD $VERSION runtime prerequisites failed; update aborted before project mutation." >&2
  exit 1
fi
command -v npx >/dev/null || { echo 'ERROR: npx not found' >&2; exit 1; }
if [[ "$MODE" == interactive ]]; then
  [[ -t 0 ]] || { echo 'ERROR: pass --yes' >&2; exit 1; }
  read -r -p 'Update BMAD? [y/N] ' a
  [[ "$a" =~ ^([yY]|yes|YES)$ ]] || exit 0
fi

# --- Per-run lease + global update lock (giống install.sh) ---
# hold-lock mở + validate + flock .install.lock trong MỘT fd (O_NOFOLLOW);
# process giữ lock được kill ở EXIT trap -> flock tự giải phóng.
LEASE="update-$$-$(date +%s)"
LOCK_OUT="$(mktemp "${TMPDIR:-/tmp}/opk-lock.XXXXXX")"
python3 "$KIT_DIR/scripts/opk_tx.py" hold-lock --root "$TARGET" >"$LOCK_OUT" 2>&1 &
LOCK_PID=$!
LOCK_ACQUIRED=0
for _ in $(seq 1 100); do
  if grep -q '"ok": true' "$LOCK_OUT" 2>/dev/null; then
    LOCK_ACQUIRED=1
    break
  fi
  if ! kill -0 "$LOCK_PID" 2>/dev/null; then
    break
  fi
  sleep 0.05
done
if [[ "$LOCK_ACQUIRED" != 1 ]]; then
  echo "ERROR: không lấy được update lock (.opk-state/.install.lock):" >&2
  cat "$LOCK_OUT" >&2
  rm -f "$LOCK_OUT"
  exit 1
fi
rm -f "$LOCK_OUT"
trap 'kill "$LOCK_PID" 2>/dev/null || true' EXIT

# --- Khôi phục giao dịch dở dang từ lần install/update bị gián đoạn ---
# Chạy SAU khi giữ lock: không có tiến trình khác đang ghi.
TX_SH="$KIT_DIR/scripts/opk_tx.sh"
pending="$("$TX_SH" status --root "$TARGET" 2>/dev/null | python3 -c '
import json, sys
try:
    txs = json.load(sys.stdin)
except Exception:
    txs = []
print(sum(1 for t in txs if t.get("status") in ("prepared", "applying", "failed")))
' 2>/dev/null || echo 0)"
if [[ "${pending:-0}" -gt 0 ]] 2>/dev/null; then
  echo "WARN: có $pending giao dịch dở dang — đang khôi phục..."
  "$TX_SH" recover --root "$TARGET" --all --yes
fi

# --- Failure injection (test-only, fail-closed ngoài test) ---
if [[ "${OPK_TEST_INJECT_FAIL:-}" == before-publish ]]; then
  if [[ "${OPK_TEST_MODE:-0}" != 1 ]]; then
    echo "ERROR: OPK_TEST_INJECT_FAIL=before-publish chỉ được phép trong OPK_TEST_MODE=1 (test-only)." >&2
    exit 1
  fi
  echo "WARN: OPK_TEST_INJECT_FAIL=before-publish — dừng update (test-only)." >&2
  echo "ERROR: Injected failure tại phase: before-publish (OPK_TEST_INJECT_FAIL)" >&2
  exit 1
fi

# --- Chạy npx, capture vào TEMP log ---
# Không bao giờ shell-redirect vào path trong project: symlink được seed
# sẵn ở đích sẽ khiến redirect ghi xuyên qua nó. Publish qua safe write
# layer (từ chối symlink/hardlink) sau khi npx thoát.
LOG_NAME=".opencode-power-bmad-update.log"
LOG="$TARGET/$LOG_NAME"
TMP_LOG="$(mktemp "${TMPDIR:-/tmp}/opk-bmad.XXXXXX")"
if ! chmod 600 "$TMP_LOG"; then
  rm -f "$TMP_LOG"
  echo "ERROR: cannot secure BMAD temp log with mode 600" >&2
  exit 1
fi
rc=0
"${CMD[@]}" >"$TMP_LOG" 2>&1 || rc=$?
if ! python3 "$KIT_DIR/scripts/opk_safe_io.py" write \
  --root "$TARGET" \
  --rel "$LOG_NAME" \
  --stdin <"$TMP_LOG" >/dev/null 2>&1; then
  echo "ERROR: không publish được BMAD log qua safe write (đích không an toàn?): $LOG" >&2
  echo "Log tạm được giữ lại (mode 600): $TMP_LOG" >&2
  echo "Xóa thủ công sau khi debug: rm -f -- \"$TMP_LOG\"" >&2
  exit 1
fi
# Publish succeeded, so the project log is now the durable diagnostic copy.
rm -f "$TMP_LOG"
if [[ "$rc" -ne 0 ]]; then
  echo "ERROR: BMAD $VERSION update THẤT BẠI (exit code: $rc)" >&2
  echo "Full log: $LOG" >&2
  echo "----- tail -50 của log -----" >&2
  tail -50 "$LOG" 2>/dev/null || echo "(không đọc được log)" >&2
  exit "$rc"
fi
echo "BMAD $VERSION updated"
