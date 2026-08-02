#!/usr/bin/env bash
# Safe updater for OpenCode Power Kit v2.1.1.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
export OPK_KIT_DIR="$KIT_DIR"
source "$SCRIPT_DIR/upstream-versions.sh"
source "$SCRIPT_DIR/project-profile.sh"

MODE="project"; DRY_RUN=0; YES=0; CLEAN=0; PROFILE="auto"
WITH_GSD=0; WITH_OPTIONAL=0; REFRESH_SUPERPOWERS=0; PROJECT_DIR="$PWD"
log(){ printf 'opk: %s\n' "$*"; }
die(){ printf 'opk: ERROR: %s\n' "$*" >&2; exit 1; }
run(){ if ((DRY_RUN)); then printf 'opk: DRY-RUN:'; printf ' %q' "$@"; printf '\n'; else "$@"; fi; }
need(){ [[ -f "$1" ]] || die "missing required file: $1"; }
usage(){ cat <<'USAGE'
Usage:
  update-opk.sh project [--dry-run] [--yes] [--clean] [--profile auto|none|node-nest-react-mysql]
  update-opk.sh all [--dry-run] [--yes] [--with-gsd] [--with-optional] [--refresh-superpowers]

--dry-run is strictly read-only. Mutations fail-fast. Missing optional integrations
remain missing unless --with-optional is explicitly supplied.
USAGE
}

pull_kit(){
  if ! git -C "$KIT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then log "$KIT_DIR is not a git checkout; skip pull"; return; fi
  [[ -z "$(git -C "$KIT_DIR" status --porcelain=v1 --untracked-files=normal)" ]] || { git -C "$KIT_DIR" status --short >&2; die 'kit has modified, staged, or untracked files'; }
  run git -C "$KIT_DIR" pull --ff-only
}
install_global(){ need "$KIT_DIR/install-global.sh"; run bash "$KIT_DIR/install-global.sh" --yes; }
refresh_project(){
  opk_project_is_safe "$PROJECT_DIR" || { log "skip unsafe project directory: $PROJECT_DIR"; return; }
  opk_project_has_repo_marker "$PROJECT_DIR" || { log "skip: no recognized project marker"; return; }
  need "$KIT_DIR/install.sh"; (cd "$PROJECT_DIR" && run bash "$KIT_DIR/install.sh" --yes)
  local selected="$PROFILE"; [[ "$selected" == auto ]] && selected="$(opk_detect_profile "$PROJECT_DIR")"
  case "$selected" in
    none) log 'profile=none; generic project is not forced into full-stack profile' ;;
    node-nest-react-mysql) need "$KIT_DIR/scripts/install-fullstack-profile.sh"; (cd "$PROJECT_DIR" && run bash "$KIT_DIR/scripts/install-fullstack-profile.sh" --yes) ;;
    *) die "unsupported profile: $selected" ;;
  esac
  need "$KIT_DIR/verify.sh"; (cd "$PROJECT_DIR" && run bash "$KIT_DIR/verify.sh")
  if ((CLEAN)); then need "$KIT_DIR/scripts/cleanup-agent-artifacts.sh"; (cd "$PROJECT_DIR" && run bash "$KIT_DIR/scripts/cleanup-agent-artifacts.sh" --apply); fi
}
installed_bmad(){ [[ -d "$PROJECT_DIR/.bmad" || -d "$PROJECT_DIR/_bmad" ]]; }
installed_gsd(){ command -v gsd-core >/dev/null 2>&1 || [[ -d "$PROJECT_DIR/.gsd" || -d "$PROJECT_DIR/.opencode/gsd-core" ]]; }
installed_taste(){ [[ -f "$HOME/.config/opencode/skills/taste-skill/SKILL.md" ]]; }
installed_markitdown(){ command -v markitdown >/dev/null 2>&1; }
installed_supermemory(){ command -v supermemory >/dev/null 2>&1; }
installed_ecc(){ [[ -f "${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}/agents/ecc-lite-strong.md" ]]; }
refresh_bmad(){ local a=(--yes); ((DRY_RUN)) && a=(--dry-run); (cd "$PROJECT_DIR" && BMAD_METHOD_VERSION="$OPK_BMAD_VERSION" bash "$KIT_DIR/update-bmad.sh" "${a[@]}"); }
refresh_gsd(){ local a=(--yes --target "$PROJECT_DIR"); ((DRY_RUN)) && a=(--dry-run --target "$PROJECT_DIR"); GSD_CORE_VERSION="$OPK_GSD_VERSION" bash "$KIT_DIR/scripts/install-gsd-core.sh" "${a[@]}"; }
refresh_taste(){ local a=(--yes --refresh); ((DRY_RUN)) && a=(--dry-run --refresh); bash "$KIT_DIR/scripts/install-taste-skill.sh" "${a[@]}"; }
refresh_markitdown(){ local a=(--yes --upgrade); ((DRY_RUN)) && a=(--dry-run --upgrade); MARKITDOWN_VERSION="$OPK_MARKITDOWN_VERSION" bash "$KIT_DIR/scripts/install-markitdown.sh" "${a[@]}"; }
refresh_supermemory(){ local a=(--yes --upgrade); ((DRY_RUN)) && a=(--dry-run --upgrade); SUPERMEMORY_PACKAGE="$OPK_SUPERMEMORY_PACKAGE" bash "$KIT_DIR/scripts/install-supermemory.sh" "${a[@]}"; }
refresh_ecc(){ local a=(--yes --refresh); ((DRY_RUN)) && a=(--dry-run --refresh); bash "$KIT_DIR/scripts/install-ecc-lite.sh" "${a[@]}"; }
refresh_superpowers(){
  local cache trash
  cache="$HOME/.cache/opencode/packages"
  trash="$KIT_DIR/.opk-trash/superpowers-$(date +%Y%m%d-%H%M%S)"
  [[ -d "$cache" ]] || { log 'Superpowers cache absent'; return; }
  shopt -s nullglob; local paths=("$cache"/superpowers*); shopt -u nullglob; ((${#paths[@]})) || { log 'Superpowers cache absent'; return; }
  if ((DRY_RUN)); then for p in "${paths[@]}"; do log "DRY-RUN: move $p -> $trash/"; done; return; fi
  mkdir -p "$trash"; for p in "${paths[@]}"; do mv "$p" "$trash/"; done
  log "Superpowers cache moved safely; OpenCode resolves upstream on next start"
}
refresh_integrations(){
  opk_project_is_safe "$PROJECT_DIR" || { log 'skip project integrations: no safe project'; return; }
  if installed_bmad || ((WITH_OPTIONAL)); then refresh_bmad; else log 'BMAD not installed; skip'; fi
  if installed_gsd || ((WITH_GSD)) || ((WITH_OPTIONAL)); then refresh_gsd; else log 'GSD not installed; skip'; fi
  if installed_taste || ((WITH_OPTIONAL)); then refresh_taste; else log 'Taste not installed; skip'; fi
  if installed_markitdown || ((WITH_OPTIONAL)); then refresh_markitdown; else log 'MarkItDown not installed; skip'; fi
  if installed_supermemory || ((WITH_OPTIONAL)); then refresh_supermemory; else log 'Supermemory not installed; skip'; fi
  if installed_ecc || ((WITH_OPTIONAL)); then refresh_ecc; else log 'ECC-lite not installed; skip'; fi
  if ((REFRESH_SUPERPOWERS)); then refresh_superpowers; else log 'Superpowers cache unchanged'; fi
}

[[ $# -gt 0 ]] && { MODE="$1"; shift; }
case "$MODE" in project|all) ;; help|-h|--help) usage; exit 0 ;; *) die "unknown mode: $MODE" ;; esac
while (($#)); do case "$1" in
  --dry-run) DRY_RUN=1;; -y|--yes) YES=1;; --clean) CLEAN=1;;
  --profile) shift; (($#)) || die '--profile needs value'; PROFILE="$1";;
  --with-gsd) WITH_GSD=1;; --with-optional) WITH_OPTIONAL=1;; --refresh-superpowers) REFRESH_SUPERPOWERS=1;;
  -h|--help) usage; exit 0;; *) die "unknown flag: $1";; esac; shift; done
[[ "$(id -u)" -ne 0 ]] || die 'do not run updater with sudo/root'
if ((!DRY_RUN && !YES)); then [[ -t 0 ]] || die 'no TTY; pass --yes or --dry-run'; read -r -p "Proceed with OPK $MODE update? [y/N] " a; [[ "$a" =~ ^([yY]|yes|YES)$ ]] || { log aborted; exit 0; }; fi
log "mode=$MODE dry_run=$DRY_RUN project=$PROJECT_DIR"
pull_kit
install_global
refresh_project
[[ "$MODE" == all ]] && refresh_integrations
log 'update completed successfully'
