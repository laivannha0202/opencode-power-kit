#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
# install-gsd-core.sh
# opencode-power-kit v1.3.4
#
# Optional integration with the official GSD Core installer.
#
# This script does NOT vendor or copy GSD Core source. It only
# invokes the official installer:
#
#     npx @opengsd/gsd-core@latest
#
# GSD Core is a separate, third-party project (see THIRD_PARTY.md).
# opencode-power-kit only DETECTS existing installs and FORWARDS
# to the official installer. It does not modify GSD source.
#
# SAFETY:
#   - --dry-run prints the planned command and exits 0.
#   - --yes   skips the confirmation prompt.
#   - Refuses to run if `node` / `npm` / `npx` is missing.
#   - Never runs `rm -rf`, `git reset --hard`, `git clean -fd`,
#     or force push. The GSD installer is responsible for its
#     own safety; we only add a clear wrapper.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
GSD_PACKAGE="@opengsd/gsd-core"
GSD_INVOKE=(npx "${GSD_PACKAGE}@latest")

MODE="interactive"
TARGET_DIR=""

# ─── Usage ────────────────────────────────────────────────────────
usage() {
	cat <<EOF
Usage: ${SCRIPT_NAME} [--dry-run] [--yes] [--target DIR]

Optional helper that invokes the official GSD Core installer:
    npx ${GSD_PACKAGE}@latest

FLAGS:
  --dry-run        Print the command that would run. Do not execute.
  --yes            Skip the confirmation prompt before invoking npx.
  --target DIR     Pass-through directory argument to the installer.
                   (Forwarded as 'npx ... <DIR>'; the GSD installer
                   decides what to do with it.)
  -h, --help       Show this help.

NOTES:
  - Requires \`node\`, \`npm\`, and \`npx\` on PATH.
  - This script does NOT vendor or copy GSD source. It only
    forwards to the official installer.
  - This script is opt-in. It is NEVER invoked automatically.

EXAMPLES:
  ${SCRIPT_NAME} --dry-run
  ${SCRIPT_NAME} --yes
  ${SCRIPT_NAME} --target /path/to/your/project --yes
EOF
}

# ─── Argument parsing ─────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
	case "$1" in
	--dry-run)
		MODE="dry-run"
		shift
		;;
	--yes)
		MODE="yes"
		shift
		;;
	--target)
		if [[ $# -lt 2 ]]; then
			echo "ERROR: --target requires a directory argument" >&2
			exit 2
		fi
		TARGET_DIR="$2"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "ERROR: unknown option: $1" >&2
		usage >&2
		exit 2
		;;
	esac
done

# ─── Pre-flight: tooling ──────────────────────────────────────────
if ! command -v node >/dev/null 2>&1; then
	echo "ERROR: 'node' is not on PATH. Install Node.js first." >&2
	exit 1
fi
if ! command -v npm >/dev/null 2>&1; then
	echo "ERROR: 'npm' is not on PATH. Install npm first." >&2
	exit 1
fi
if ! command -v npx >/dev/null 2>&1; then
	echo "ERROR: 'npx' is not on PATH. Install npx first." >&2
	exit 1
fi

# ─── Pre-flight: warn if offline / no npm cache (best effort) ─────
# We do not abort here — the installer will produce a clear error
# if it cannot reach the registry.

# ─── Plan command ─────────────────────────────────────────────────
PLAN=("${GSD_INVOKE[@]}")
if [[ -n "${TARGET_DIR}" ]]; then
	PLAN+=("${TARGET_DIR}")
fi

echo "=== install-gsd-core ==="
echo "Mode:     ${MODE}"
echo "Package:  ${GSD_PACKAGE}@latest"
echo "Command:  ${PLAN[*]}"
if [[ -n "${TARGET_DIR}" ]]; then
	echo "Target:   ${TARGET_DIR}"
else
	echo "Target:   (no --target; installer will prompt or use cwd)"
fi
echo

# ─── Dry run ──────────────────────────────────────────────────────
if [[ "${MODE}" == "dry-run" ]]; then
	echo "Dry run complete. Re-run with --yes to actually invoke npx."
	exit 0
fi

# ─── Interactive confirmation ─────────────────────────────────────
if [[ "${MODE}" == "interactive" ]]; then
	if [[ ! -t 0 ]]; then
		echo "ERROR: no TTY available; refusing to run without --yes." >&2
		exit 1
	fi
	read -r -p "Invoke '${PLAN[*]}' now? [y/N] " reply
	case "${reply}" in
	y | Y | yes | YES) : ;;
	*)
		echo "aborted."
		exit 0
		;;
	esac
fi

# ─── Invoke ───────────────────────────────────────────────────────
# We do NOT pipe through sudo or shell substitutions. npx owns its
# own prompts and security checks.
echo "==> ${PLAN[*]}"
exec "${PLAN[@]}"
