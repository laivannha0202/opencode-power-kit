#!/usr/bin/env bash
# OpenCode Power Kit — business logic for the opk CLI router.
# Sourced by bin/opk after KIT_DIR resolution; never executed standalone.
# Each opk_* function below is invoked by exactly one leaf of the bin/opk case.
# shellcheck disable=SC2034  # Some globals are exported by downstream scripts.

# --- Shared guards ---------------------------------------------------------

path_has_symlink(){
  local rel="$2" current="$1" part
  local -a parts
  IFS='/' read -r -a parts <<<"$rel"
  for part in "${parts[@]}"; do
    [[ -n "$part" ]] || continue
    current="$current/$part"
    [[ ! -L "$current" ]] || return 0
  done
  return 1
}

safe_project(){ source "$KIT_DIR/scripts/project-profile.sh"; export OPK_KIT_DIR="$KIT_DIR"; opk_project_is_safe "$PWD"; }
safe_opencode_project(){ safe_project && opk_project_has_opencode_marker "$PWD"; }

opencode_has_auto(){ command -v opencode >/dev/null 2>&1 && opencode --help 2>&1 | grep -q -- '--auto'; }


_opk_require_managed_runtime_asset(){
  local installed="$1" source="$2" marker="$3" label="$4"
  [[ -f "$installed" && ! -L "$installed" ]] || err "$label missing/unsafe; run: opk install"
  grep -qF "$marker" "$installed" || err "$label is custom/unmanaged; unattended mode refuses it"
  [[ -f "$source" && ! -L "$source" ]] || err "$label source missing/unsafe in OPK kit"
  cmp -s "$installed" "$source" || err "$label is stale; run: opk install"
}

_opk_require_runtime_guards(){
  local project="$1"
  _opk_require_managed_runtime_asset "$project/.opencode/plugins/opk-safety-guard.js" "$KIT_DIR/templates/plugins/opk-safety-guard.js" '@opk-plugin opk-safety-guard' 'safety guard'
  _opk_require_managed_runtime_asset "$project/.opencode/plugins/opk-token-guard.js" "$KIT_DIR/templates/plugins/opk-token-guard.js" '@opk-plugin opk-token-guard' 'token guard'
  _opk_require_managed_runtime_asset "$project/.opencode/agents/opk-main.md" "$KIT_DIR/opencode-global/agents/opk-main.md" '@opk-managed-agent opk-main' 'opk-main agent'
}

_opk_require_power_mode(){
  safe_opencode_project || err 'run inside a safe project with a project marker'
  need "$KIT_DIR/scripts/opk-permissions.py"
  local project
  project="$(pwd -P)" || err 'cannot resolve current project'
  python3 "$KIT_DIR/scripts/opk-permissions.py" --project-dir "$project" --require-power || \
    err 'effective Power contract failed; run: opk permissions doctor'
  _opk_require_runtime_guards "$project"
}

# --- Mode: show|power|safe|migrate ----------------------------------------

_opk_mode_preflight(){  # action "$@" -> validates args, sets OPK_MODE_PROJECT
  local action="$1"; shift
  local -a normalize_args=()
  local seen_normalize=0 option
  for option in "$@"; do
    [[ "$option" == --normalize-jsonc ]] || \
      err 'mode: use show|power|safe|migrate [--normalize-jsonc]'
    if [[ "$action" == show ]]; then
      err 'mode show: --normalize-jsonc is not allowed'
    fi
    if [[ $seen_normalize -eq 1 ]]; then
      err 'mode: duplicate --normalize-jsonc'
    fi
    seen_normalize=1
    normalize_args=(--normalize-jsonc)
  done
  local project target target_jsonc legacy
  project="$(pwd -P)" || err 'cannot resolve current project'
  target="$project/opencode.json"
  target_jsonc="$project/opencode.jsonc"
  legacy="$project/.opencode/opencode.json"
  [[ ! -L "$target" ]] || err 'mode: refusing symlink config target'
  [[ ! -L "$target_jsonc" ]] || err 'mode: refusing symlink config target'
  [[ ! -e "$target" || -f "$target" ]] || err 'mode: config target is not a regular file'
  [[ ! -e "$target_jsonc" || -f "$target_jsonc" ]] || err 'mode: config target is not a regular file'
  [[ ! -L "$legacy" ]] || err 'mode: refusing symlink legacy config'
  [[ ! -e "$legacy" || -f "$legacy" ]] || err 'mode: legacy config is not a regular file'
  if [[ -e "$target" && -e "$target_jsonc" ]]; then
    err 'mode: conflict: both opencode.json and opencode.jsonc exist'
  fi
  OPK_MODE_PROJECT="$project"
  OPK_MODE_NORMALIZE=${seen_normalize:-0}
}

opk_mode_show(){
  _opk_mode_preflight show "$@"
  need "$KIT_DIR/scripts/opk-permissions.py"
  exec python3 "$KIT_DIR/scripts/opk-permissions.py" --project-dir "$OPK_MODE_PROJECT"
}

_opk_mode_merge(){  # action "$@" — shared by power/safe/migrate
  local action="$1"; shift
  _opk_mode_preflight "$action" "$@"
  safe_opencode_project || err 'run inside a safe project with a project marker'
  if [[ "$action" != migrate ]]; then
    [[ -e "$OPK_MODE_PROJECT/.opencode/opencode.json" ]] && err 'mode: legacy config exists; run opk mode migrate first'
  fi
  need "$KIT_DIR/scripts/merge-opk-project.py"
  if [[ "$action" == migrate ]]; then
    if [[ $OPK_MODE_NORMALIZE -eq 1 ]]; then
      exec python3 "$KIT_DIR/scripts/merge-opk-project.py" --project-dir "$OPK_MODE_PROJECT" --migrate-only --normalize-jsonc
    fi
    exec python3 "$KIT_DIR/scripts/merge-opk-project.py" --project-dir "$OPK_MODE_PROJECT" --migrate-only
  fi
  if [[ $OPK_MODE_NORMALIZE -eq 1 ]]; then
    exec python3 "$KIT_DIR/scripts/merge-opk-project.py" --project-dir "$OPK_MODE_PROJECT" --mode "$action" --normalize-jsonc
  fi
  exec python3 "$KIT_DIR/scripts/merge-opk-project.py" --project-dir "$OPK_MODE_PROJECT" --mode "$action"
}

opk_mode_power(){ _opk_mode_merge power "$@"; }
opk_mode_safe(){ _opk_mode_merge safe "$@"; }
opk_mode_migrate(){ _opk_mode_merge migrate "$@"; }

# --- Permissions -----------------------------------------------------------

opk_permissions_doctor(){
  need "$KIT_DIR/scripts/opk-permissions.py"
  local project
  project="$(pwd -P)" || err 'cannot resolve current project'
  exec python3 "$KIT_DIR/scripts/opk-permissions.py" --project-dir "$project"
}

# --- Auto mode -------------------------------------------------------------

opk_auto(){
  _opk_require_power_mode
  opencode_has_auto || err 'installed OpenCode does not support --auto; update OpenCode manually'
  exec opencode --auto "$@"
}

opk_run_auto(){
  (($# > 0)) || err 'run-auto: provide a prompt'
  _opk_require_power_mode
  opencode_has_auto || err 'installed OpenCode does not support --auto; update OpenCode manually'
  exec opencode run --auto "$@"
}

# --- Safety plugin ---------------------------------------------------------

opk_safety_plugin_status(){
  # Public command remains scoped to the safety plugin only.
  # Unattended mode separately requires safety + token + opk-main.
  local installed=".opencode/plugins/opk-safety-guard.js"
  local source="$KIT_DIR/templates/plugins/opk-safety-guard.js"
  local checker="$KIT_DIR/scripts/check-runtime-plugins.mjs"

  need "$source"
  need "$checker"

  if [[ ! -e "$installed" && ! -L "$installed" ]]; then
    echo AVAILABLE_NOT_INSTALLED
    return 0
  fi

  if [[ ! -f "$installed" || -L "$installed" ]]; then
    echo "BROKEN safety plugin target is missing/unsafe" >&2
    return 1
  fi

  if ! cmp -s "$installed" "$source"; then
    echo "BROKEN safety plugin is stale/custom; run: opk safety-plugin install --yes" >&2
    return 1
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "BROKEN node is required to validate safety plugin runtime" >&2
    return 1
  fi

  if ! node "$checker" --safety "$installed" >/dev/null; then
    echo "BROKEN safety plugin cannot load/pass runtime smoke checks" >&2
    return 1
  fi

  echo INSTALLED
  return 0
}

# --- BASH_ENV guard (opk guard status|install|uninstall) -------------------

opk_guard_status(){
  local installed=0 wired=0
  local frag="${OPK_GUARD_DIR:-$HOME/.config/opencode-power-kit/guard}/opk-guard-bashrc"
  [[ -f "$frag" && ! -L "$frag" ]] && grep -qF 'OPK_GUARD_LOADED' "$frag" 2>/dev/null && installed=1
  if [[ -f "$HOME/.bashrc" ]]; then
    grep -qF '# >>> opencode-power-kit guard (opk guard install) >>>' "$HOME/.bashrc" 2>/dev/null && \
    grep -qF '# <<< opencode-power-kit guard <<<' "$HOME/.bashrc" 2>/dev/null && wired=1
  fi
  if [[ $installed -eq 1 && $wired -eq 1 ]]; then
    echo INSTALLED
    return 0
  fi
  echo "PARTIAL (fragment=$installed bashrc=$wired) — run: opk guard install"
}


# --- BMAD ------------------------------------------------------------------

opk_bmad_status(){
  # shellcheck source=scripts/upstream-versions.sh
  source "$KIT_DIR/scripts/upstream-versions.sh"
  echo "BMAD pin: ${BMAD_METHOD_VERSION:-$OPK_BMAD_VERSION}"
  [[ -d .bmad || -d _bmad ]] && echo INSTALLED || echo NOT_INSTALLED
}

opk_bmad_update(){
  # shellcheck source=scripts/upstream-versions.sh
  source "$KIT_DIR/scripts/upstream-versions.sh"
  local version="$OPK_BMAD_VERSION"
  case "${1:---stable}" in
    --stable) shift || true;;
    --next) version=next; shift || true;;
    --version) shift; version="${1:-}"; [[ -n "$version" ]] || err 'missing version'; shift;;
  esac
  BMAD_METHOD_VERSION="$version" bash "$KIT_DIR/update-bmad.sh" "$@"
}

# --- Taste skill -----------------------------------------------------------

opk_taste_status(){
  [[ -f "$HOME/.config/opencode/skills/taste-skill/SKILL.md" ]] && echo INSTALLED || echo NOT_INSTALLED
}

opk_taste_doctor(){
  local t
  for t in node npm npx; do command -v "$t" || true; done
}

opk_taste_off(){
  local d trash
  d="$HOME/.config/opencode/skills/taste-skill"
  [[ -d "$d" ]] || return 0
  trash="$KIT_DIR/.opk-trash/taste-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$trash"
  mv "$d" "$trash/"
}

# --- ECC / Hermes off (move known component files into .opk-trash) ---------

_opk_trash_move(){  # prefix: ecc|hermes — moves the component files, keeps current logic
  local prefix="$1" raw_base lexical_base base kit_real home_real trash trash_real rel src dest moved=0
  local -a components existing
  case "$prefix" in
    hermes) components=(agents/hermes-lite-strong.md commands/hermes-audit.md commands/hermes-budget.md commands/hermes-kanban.md commands/hermes-learn.md commands/hermes-memory.md commands/hermes-reflect.md commands/hermes-research.md commands/hermes-skill.md) ;;
    ecc) components=(agents/ecc-lite-strong.md commands/ecc-audit.md commands/quality-gate.md commands/research-first.md commands/verify-loop.md commands/backend-route-review.md commands/harness-audit.md) ;;
    *) err "unsupported trash manifest: $prefix" ;;
  esac
  command -v realpath >/dev/null 2>&1 || err 'realpath is required'
  raw_base="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  lexical_base="$(realpath -ms -- "$raw_base")" || err 'cannot normalize OpenCode config directory'
  base="$(realpath -m -- "$raw_base")" || err 'cannot resolve OpenCode config directory'
  [[ "$lexical_base" == "$base" ]] || err "refusing symlinked OpenCode config directory: $raw_base"
  kit_real="$(realpath -e -- "$KIT_DIR")" || err 'cannot resolve kit directory'
  home_real="$(realpath -m -- "${HOME:-/root}")" || err 'cannot resolve home directory'
  case "$base" in
    /|/bin|/bin/*|/boot|/boot/*|/dev|/dev/*|/etc|/etc/*|/lib|/lib/*|/lib64|/lib64/*|/proc|/proc/*|/root|/run|/run/*|/sbin|/sbin/*|/sys|/sys/*|/tmp|/tmp/*|/usr|/usr/*|/var|/var/*|"$home_real") err "unsafe OpenCode config directory: $base" ;;
    "$kit_real"|"$kit_real"/*) err 'refusing to trash files from the OPK source tree' ;;
  esac
  existing=()
  for rel in "${components[@]}"; do
    [[ "$rel" != /* && "$rel" != *'..'* ]] || err "unsafe component path: $rel"
    path_has_symlink "$base" "$rel" && err "refusing symlink component path: $base/$rel"
    src="$base/$rel"
    if [[ -e "$src" ]]; then
      [[ -f "$src" ]] || err "component is not a regular file: $src"
      existing+=("$rel")
    fi
  done
  ((${#existing[@]} > 0)) || return 0
  path_has_symlink "$base" '.opk-trash' && err "refusing symlink trash directory: $base/.opk-trash"
  trash="$base/.opk-trash/$prefix-$(date +%Y%m%d-%H%M%S-%N)"
  trash_real="$(realpath -m -- "$trash")" || err 'cannot resolve trash destination'
  case "$trash_real" in "$base/.opk-trash/"*) ;; *) err 'trash destination escapes OpenCode config directory' ;; esac
  [[ ! -e "$trash" && ! -L "$trash" ]] || err "trash destination already exists: $trash"
  for rel in "${existing[@]}"; do
    dest="$trash/$rel"
    [[ ! -e "$dest" && ! -L "$dest" ]] || err "trash destination already exists: $dest"
  done
  for rel in "${existing[@]}"; do
    mkdir -p -- "$trash/$(dirname "$rel")" || err "cannot create trash destination: $trash"
  done
  path_has_symlink "$base" '.opk-trash' && err "refusing symlink trash directory: $base/.opk-trash"
  for rel in "${existing[@]}"; do
    src="$base/$rel"; dest="$trash/$rel"
    if ! mv -- "$src" "$dest"; then
      echo "opk: move failed; recover files from: $trash" >&2
      return 1
    fi
    moved=1
  done
  ((moved == 0)) || echo "MOVED_TO $trash"
}

opk_ecc_off(){ _opk_trash_move ecc; }
opk_hermes_off(){ _opk_trash_move hermes; }

# --- Trash listing ---------------------------------------------------------

opk_trash_known(){
  local raw_base lexical_base base trash entry name mtime found=0
  command -v realpath >/dev/null 2>&1 || err 'realpath is required'
  raw_base="${OPENCODE_CONFIG_DIR:-$HOME/.config/opencode}"
  lexical_base="$(realpath -ms -- "$raw_base")" || err 'cannot normalize OpenCode config directory'
  base="$(realpath -m -- "$raw_base")" || err 'cannot resolve OpenCode config directory'
  [[ "$lexical_base" == "$base" ]] || err "refusing symlinked OpenCode config directory: $raw_base"
  trash="$base/.opk-trash"
  path_has_symlink "$base" '.opk-trash' && err "refusing symlink trash directory: $trash"
  if [[ ! -d "$trash" ]]; then
    echo "TRASH_EMPTY"
    return 0
  fi
  for entry in "$trash"/*/; do
    [[ -e "$entry" ]] || continue
    name="$(basename "$entry")"
    mtime="$(stat -c '%y' "$entry" 2>/dev/null | cut -d'.' -f1)"
    echo "$name $mtime"
    found=1
  done
  ((found == 1)) || echo "TRASH_EMPTY"
}

# --- Superpowers -----------------------------------------------------------

opk_superpowers_status(){
  grep -q 'obra/superpowers' "$KIT_DIR/templates/opencode.json" && echo CONFIGURED || echo MISSING
}

# --- Legacy recovery -------------------------------------------------------

opk_recover_legacy(){
  local project archive
  project="$(pwd -P)" || err 'cannot resolve current project'
  archive="${1:-}"
  python3 -c '
import importlib.util
import pathlib
import sys
spec = importlib.util.spec_from_file_location("merge_opk_project", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
project = pathlib.Path(sys.argv[2])
archive = pathlib.Path(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] else None
module.recover_legacy(project, archive)
' "$KIT_DIR/scripts/merge-opk-project.py" "$project" "$archive" || err 'legacy recovery failed'
}

# --- One-command update (opk all) ------------------------------------------

opk_all(){
  bash "$KIT_DIR/install-global.sh" --yes
  if safe_project; then
    bash "$KIT_DIR/install.sh" --yes
    # shellcheck source=scripts/project-profile.sh
    profile="$(source "$KIT_DIR/scripts/project-profile.sh"; opk_detect_profile "$PWD")"
    [[ "$profile" == node-nest-react-mysql ]] && bash "$KIT_DIR/scripts/install-fullstack-profile.sh" --yes || true
    bash "$KIT_DIR/verify.sh"
  fi
}
