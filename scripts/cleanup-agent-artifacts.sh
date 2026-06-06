#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# cleanup-agent-artifacts.sh
# opencode-power-kit v1.3.3
#
# Safely clean up temporary, debug, scratch, and reproduction files
# that an agent (or a developer) may have created.
#
# SAFETY GUARANTEES:
#   - Default mode is --dry-run (no file is moved or deleted).
#   - --apply only MOVES files into .opk-trash/<timestamp>/, never
#     deletes them. Files can be recovered from the trash.
#   - Tracked files are never touched.
#   - Files inside protected directories are never touched.
#   - No `rm -rf`, no `git clean -fd`, no `git reset --hard`,
#     no force push. This script is read-mostly and move-only.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Defaults ─────────────────────────────────────────────────────
MODE="dry-run"
TIMESTAMP="$(date -u +%Y%m%d-%H%M%S)"
TRASH_DIR=".opk-trash/${TIMESTAMP}"
SCRIPT_NAME="$(basename "$0")"

# Patterns the agent is allowed to clean (regex matched against the
# basename or the relative path of an untracked file).
ALLOWED_PATTERNS=(
	'^\.tmp/'
	'^\.test/'
	'^\.opk-scratch/'
	'\.tmp$'
	'\.bak$'
	'\.orig$'
	'\.log$'
	'^repro-.*'
	'^debug-.*'
)

# Directories that must NEVER be touched, even if they contain
# untracked files that match a pattern.
PROTECTED_DIRS=(
	'src'
	'app'
	'backend'
	'frontend'
	'prisma'
	'migrations'
	'public'
	'docs'
	'.git'
	'.opencode'
	'.agents'
	'_bmad'
)

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--apply]

  --dry-run   List what would be moved. Default. Nothing is touched.
  --apply     Move matched files into ${TRASH_DIR}/.
  -h, --help  Show this help.

The script is idempotent and safe to re-run.
EOF
}

# ─── Argument parsing ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		MODE="dry-run"
		shift
		;;
	--apply)
		MODE="apply"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "Unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

# ─── Pre-flight ───────────────────────────────────────────────────
if ! command -v git >/dev/null 2>&1; then
	echo "ERROR: git is required for safe cleanup." >&2
	exit 1
fi

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	echo "ERROR: not inside a git working tree. Refusing to run." >&2
	exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

# ─── Helpers ──────────────────────────────────────────────────────
matches_pattern() {
	local path="$1"
	local p
	for p in "${ALLOWED_PATTERNS[@]}"; do
		if [[ "${path}" =~ ${p} ]]; then
			return 0
		fi
	done
	return 1
}

is_protected() {
	local path="$1"
	local d
	for d in "${PROTECTED_DIRS[@]}"; do
		# Match exact dir or dir/ prefix
		if [[ "${path}" == "${d}" || "${path}" == "${d}/"* ]]; then
			return 0
		fi
	done
	return 1
}

# ─── Collect candidates ───────────────────────────────────────────
declare -a MOVE_LIST=()
declare -a SKIP_LIST=()
declare -a IGNORED_LIST=()

# Use git status --porcelain so we can filter to untracked (??) only.
# This guarantees tracked files are never considered.
while IFS= read -r line; do
	# porcelain v1: two status chars + space + path
	# We only care about "??" (untracked) entries.
	[[ "${line:0:2}" == "??" ]] || continue

	raw_path="${line:3}"
	# Strip surrounding quotes git may add for paths with spaces
	path="${raw_path#\"}"
	path="${path%\"}"

	# Reject anything inside a protected dir
	if is_protected "${path}"; then
		SKIP_LIST+=("${path}  (reason: protected directory)")
		continue
	fi

	# Reject anything that does not match an allowed pattern
	if ! matches_pattern "${path}"; then
		IGNORED_LIST+=("${path}  (reason: not in allowlist)")
		continue
	fi

	MOVE_LIST+=("${path}")
done < <(git status --porcelain --untracked-files=all || true)

# ─── Report ───────────────────────────────────────────────────────
echo "=== cleanup-agent-artifacts ==="
echo "Mode:        ${MODE}"
echo "Repo root:   ${REPO_ROOT}"
echo "Trash dir:   ${TRASH_DIR}"
echo "Timestamp:   ${TIMESTAMP}"
echo
if [[ ${#MOVE_LIST[@]} -gt 0 ]]; then
	echo "Matched (would move): ${#MOVE_LIST[@]}"
	for f in "${MOVE_LIST[@]}"; do
		echo "  + ${f}"
	done
else
	echo "Matched (would move): 0"
fi
echo
if [[ ${#SKIP_LIST[@]} -gt 0 ]]; then
	echo "Skipped (protected):  ${#SKIP_LIST[@]}"
	for f in "${SKIP_LIST[@]}"; do
		echo "  ! ${f}"
	done
else
	echo "Skipped (protected):  0"
fi
echo
if [[ ${#IGNORED_LIST[@]} -gt 0 ]]; then
	echo "Ignored (not in allowlist): ${#IGNORED_LIST[@]}"
	for f in "${IGNORED_LIST[@]}"; do
		echo "  - ${f}"
	done
else
	echo "Ignored (not in allowlist): 0"
fi
echo

# ─── Act (or don't) ───────────────────────────────────────────────
if [[ "${MODE}" == "dry-run" ]]; then
	echo "Dry run complete. Re-run with --apply to move ${#MOVE_LIST[@]} item(s) into ${TRASH_DIR}/."
	exit 0
fi

# --apply: move only, never delete.
if [[ ${#MOVE_LIST[@]} -eq 0 ]]; then
	echo "Nothing to move. Exiting cleanly."
	exit 0
fi

mkdir -p "${TRASH_DIR}"

move_count=0
move_failed=0
for f in "${MOVE_LIST[@]}"; do
	dest="${TRASH_DIR}/${f}"
	dest_dir="$(dirname "${dest}")"
	mkdir -p "${dest_dir}"
	if git mv -- "${f}" "${dest}" 2>/dev/null; then
		move_count=$((move_count + 1))
	elif mv -- "${f}" "${dest}" 2>/dev/null; then
		move_count=$((move_count + 1))
	else
		echo "  ! FAILED to move: ${f}" >&2
		move_failed=$((move_failed + 1))
	fi
done

echo "Moved ${move_count} item(s) into ${TRASH_DIR}/."
if [[ ${move_failed} -gt 0 ]]; then
	echo "WARNING: ${move_failed} item(s) could not be moved. Inspect manually." >&2
fi
echo "Files were MOVED, not deleted. Recover with: mv ${TRASH_DIR}/* ."
exit 0
