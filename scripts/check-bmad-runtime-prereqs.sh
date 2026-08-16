#!/usr/bin/env bash
# BMAD 6.11+ rendered skills require uv and a Python >=3.11 environment.
# BMAD 6.11 itself declares Node >=20.12.0.
# This check never installs or upgrades system tools.
set -euo pipefail

fail() {
  printf 'BMAD runtime prerequisite failed: %s\n' "$*" >&2
  return 1
}

command -v node >/dev/null 2>&1 || { fail 'node not found (BMAD 6.11 requires Node >=20.12.0)'; exit 1; }
command -v npx >/dev/null 2>&1 || { fail 'npx not found'; exit 1; }
command -v uv >/dev/null 2>&1 || {
  fail 'uv not found (BMAD 6.11 rendered skills invoke uv at runtime)'
  exit 1
}

node_version="$(node -p 'process.versions.node' 2>/dev/null || true)"
if [[ ! "$node_version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  fail "cannot parse Node version: ${node_version:-unknown}"
  exit 1
fi
node_major="${BASH_REMATCH[1]}"
node_minor="${BASH_REMATCH[2]}"
if (( node_major < 20 || (node_major == 20 && node_minor < 12) )); then
  fail "Node $node_version is too old; BMAD 6.11 requires >=20.12.0"
  exit 1
fi

if ! uv --version >/dev/null 2>&1; then
  fail 'uv exists but `uv --version` failed'
  exit 1
fi

# OPK itself already requires python3. BMAD's renderer carries
# `requires-python = ">=3.11"` metadata and uv resolves the interpreter.
# We intentionally do not auto-install or mutate Python here.
command -v python3 >/dev/null 2>&1 || {
  fail 'python3 not found'
  exit 1
}

printf 'BMAD_RUNTIME_PREREQS=PASS node=%s uv=%s\n' \
  "$node_version" "$(uv --version 2>/dev/null | head -n 1)"
