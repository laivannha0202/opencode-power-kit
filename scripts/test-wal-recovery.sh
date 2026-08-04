#!/usr/bin/env bash
# Persistent WAL (write-ahead log) tests for merge-opk-project.py.
# Verifies crash recovery, rollback hygiene, and fail-closed behavior.
# Uses only temporary HOME/project state (sibling of HOME/kit — never /tmp).
# shellcheck disable=SC2016  # Child-shell snippets intentionally expand positional parameters there.
set -euo pipefail

SOURCE_KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MERGE="$SOURCE_KIT_DIR/scripts/merge-opk-project.py"
PASS=0
FAIL=0

REAL_HOME=""
REAL_HOME_PARENT=""
KIT_REAL="$(realpath -m -- "$SOURCE_KIT_DIR")"
KIT_PARENT="$(realpath -m -- "$(dirname "$KIT_REAL")")"
if [[ -n "${HOME:-}" && "$HOME" == /* ]]; then
  REAL_HOME="$(realpath -m -- "$HOME")"
  [[ "$REAL_HOME" == "/" ]] || REAL_HOME_PARENT="$(realpath -m -- "$(dirname "$REAL_HOME")")"
fi

make_test_root() {
  local raw_candidate candidate created root
  for raw_candidate in "$REAL_HOME" "$REAL_HOME_PARENT" "$KIT_PARENT"; do
    [[ -n "$raw_candidate" ]] || continue
    candidate="$(realpath -m -- "$raw_candidate" 2>/dev/null)" || continue
    [[ -d "$candidate" && -w "$candidate" ]] || continue
    case "$candidate" in
      /|/tmp|/tmp/*|/var/tmp|/var/tmp/*|"$KIT_REAL"|"$KIT_REAL"/*) continue ;;
    esac
    if created="$(mktemp -d "$candidate/.opk-wal-tests.XXXXXX" 2>/dev/null)"; then
      if ! root="$(realpath -e -- "$created" 2>/dev/null)"; then
        rm -rf -- "$created"
        continue
      fi
      case "$root" in
        "$candidate"/.opk-wal-tests.*) ;;
        *) rm -rf -- "$created"; continue ;;
      esac
      case "$root" in
        /|/tmp|/tmp/*|/var/tmp|/var/tmp/*|"$KIT_REAL"|"$KIT_REAL"/*)
          rm -rf -- "$created"
          continue
          ;;
      esac
      printf '%s\n' "$root"
      return 0
    fi
  done
  return 1
}

if ! TMP="$(make_test_root)"; then
  printf 'test-wal-recovery: cannot create a safe sibling temporary directory\n' >&2
  exit 1
fi
if [[ -z "$TMP" || ! -d "$TMP" || "$TMP" == "/" ]]; then
  printf 'test-wal-recovery: invalid temporary directory: %s\n' "$TMP" >&2
  exit 1
fi
readonly TMP

cleanup() {
  local tmp_real
  tmp_real="$(realpath -m -- "${TMP:-}" 2>/dev/null)" || return
  case "$tmp_real" in
    "$REAL_HOME"/.opk-wal-tests.*|"$REAL_HOME_PARENT"/.opk-wal-tests.*|"$KIT_PARENT"/.opk-wal-tests.*)
      [[ -d "$tmp_real" && "$tmp_real" != "/" ]] && rm -rf -- "$tmp_real"
      ;;
    *) printf 'test-wal-recovery: refusing unsafe cleanup path: %s\n' "${TMP:-}" >&2 ;;
  esac
}
trap cleanup EXIT

new_project() { # name -> dir
  local dir="$TMP/$1"
  mkdir -p "$dir/.opencode"
  printf '# wal fixture\n' >"$dir/AGENTS.md"
  printf '%s\n' "$dir"
}

check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    printf '  [ok]   %s\n' "$label"
    PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s (expected: %s, got: %s)\n' "$label" "$expected" "$actual" >&2
    FAIL=$((FAIL + 1))
  fi
}

craft_crash() { # dir: stale WAL with one record for opencode.json + partial mutation
  local dir="$1"
  mkdir -p "$dir/.opk-wal"
  printf '{"backup": "backup-000001.bin", "mode": 420, "path": "opencode.json", "seq": 1}\n' \
    >"$dir/.opk-wal/journal.wal"
  printf '%s' "{\"model\":\"partial/crash-state\"}" >"$dir/opencode.json"
  printf '%s' "{\"model\":\"fixture/original\"}" >"$dir/.opk-wal/backup-000001.bin"
}

printf 'WAL recovery\n'

# --- T1: crafted crash state -> recover_wal restores and cleans up --------
P="$(new_project wal-crash)"
printf '{"model":"fixture/original"}\n' >"$P/opencode.json"
ORIG="$(cat "$P/opencode.json")"
craft_crash "$P"
python3 -c '
import importlib.util
import pathlib
import sys
spec = importlib.util.spec_from_file_location("merge_opk_project", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.recover_wal(pathlib.Path(sys.argv[2]))
' "$MERGE" "$P"
check "recovery restores config byte-identical" "$ORIG" "$(cat "$P/opencode.json")"
check "recovery removes stale WAL directory" "0" "$([[ -d "$P/.opk-wal" ]] && echo 1 || echo 0)"

# --- T2: crafted crash state -> full merge recovers first, then succeeds --
P="$(new_project wal-merge)"
printf '{"model":"fixture/original"}\n' >"$P/opencode.json"
craft_crash "$P"
MERGE_OUT="$(python3 "$MERGE" --project-dir "$P" --mode power 2>&1)" || true
check "full merge recovers stale WAL before writing" "1" "$(grep -c 'recovered interrupted transaction' <<<"$MERGE_OUT")"
check "full merge succeeds after recovery" "0" "$([[ -e "$P/.opk-wal" ]] && echo 1 || echo 0)"
check "full merge left config in managed state" "1" "$(grep -c '"model": "fixture/original"' "$P/opencode.json" || true)"

# --- T3: injected failure rolls back and leaves no WAL --------------------
P="$(new_project wal-rollback)"
printf '{"model":"fixture/keep"}\n' >"$P/opencode.json"
ORIG_CONFIG="$(cat "$P/opencode.json")"
OPK_TEST_MODE=1 OPK_PROJECT_INSTALL_INJECT_FAIL_AFTER='AGENTS.md' \
  python3 "$MERGE" --project-dir "$P" --mode power >/dev/null 2>&1 || true
check "injected failure rolls back config" "$ORIG_CONFIG" "$(cat "$P/opencode.json")"
check "rollback leaves no WAL directory" "0" "$([[ -d "$P/.opk-wal" ]] && echo 1 || echo 0)"

# --- T4: symlinked .opk-wal is refused (fail-closed) ----------------------
P="$(new_project wal-symlink)"
printf '{"model":"fixture/keep"}\n' >"$P/opencode.json"
ln -s "$TMP" "$P/.opk-wal"
RC=0
WAL_OUT="$(python3 "$MERGE" --project-dir "$P" --mode power 2>&1)" || RC=$?
check "symlinked WAL directory is refused" "1" "$([[ "$RC" -ne 0 ]] && echo 1 || echo 0)"
check "symlinked WAL refusal explains itself" "1" "$(grep -c 'unsafe WAL directory' <<<"$WAL_OUT")"

# --- T5: WAL record escaping the project is refused ------------------------
P="$(new_project wal-escape)"
printf '{"model":"fixture/keep"}\n' >"$P/opencode.json"
mkdir -p "$P/.opk-wal"
printf '{"backup": null, "mode": null, "path": "../escape", "seq": 1}\n' \
  >"$P/.opk-wal/journal.wal"
RC=0
WAL_OUT="$(python3 "$MERGE" --project-dir "$P" --mode power 2>&1)" || RC=$?
check "escaping WAL record is refused" "1" "$([[ "$RC" -ne 0 ]] && echo 1 || echo 0)"
check "escaping WAL refusal explains itself" "1" "$(grep -c 'unsafe WAL record path' <<<"$WAL_OUT")"

# --- T6: dry-run is read-only and creates no WAL ---------------------------
P="$(new_project wal-dryrun)"
printf '{"model":"fixture/keep"}\n' >"$P/opencode.json"
DRY_OUT="$(python3 "$MERGE" --project-dir "$P" --mode power --dry-run 2>&1)" || true
check "dry-run creates no WAL directory" "0" "$([[ -d "$P/.opk-wal" ]] && echo 1 || echo 0)"
check "dry-run leaves config untouched" '{"model":"fixture/keep"}' "$(cat "$P/opencode.json")"

# --- T7: successful run leaves no WAL and refuses no-path corruption ------
P="$(new_project wal-success)"
printf '{"model":"fixture/keep"}\n' >"$P/opencode.json"
python3 "$MERGE" --project-dir "$P" --mode power >/dev/null 2>&1
check "successful merge leaves no WAL directory" "0" "$([[ -d "$P/.opk-wal" ]] && echo 1 || echo 0)"

printf '\nWAL recovery: %d passed, %d failed\n' "$PASS" "$FAIL"
((FAIL == 0))
