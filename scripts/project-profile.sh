#!/usr/bin/env bash
# Project/profile detection shared by updater commands.

opk_project_is_safe() {
  local dir="${1:-$PWD}" real home_real kit_real
  real="$(cd "$dir" 2>/dev/null && pwd -P)" || return 1
  home_real="$(cd "${HOME:-/root}" 2>/dev/null && pwd -P)"
  kit_real="$(cd "${OPK_KIT_DIR:-$(dirname "${BASH_SOURCE[0]}")/..}" 2>/dev/null && pwd -P)"
  case "$real" in
    /|/tmp|/tmp/*|/var/tmp|/var/tmp/*|/usr|/usr/*|/etc|/etc/*|"$home_real"|"$kit_real"|"$kit_real"/*) return 1 ;;
  esac
  return 0
}

opk_project_has_repo_marker() {
  local dir="${1:-$PWD}"
  [[ -d "$dir/.git" || -f "$dir/package.json" || -f "$dir/pyproject.toml" || -f "$dir/go.mod" || -f "$dir/Cargo.toml" || -f "$dir/pom.xml" || -f "$dir/build.gradle" ]]
}

opk_detect_profile() {
  local dir="${1:-$PWD}" score=0
  [[ -f "$dir/.opk-profile" ]] && { head -n1 "$dir/.opk-profile"; return 0; }
  [[ -f "$dir/nest-cli.json" || -f "$dir/backend/nest-cli.json" ]] && ((score+=1))
  if grep -RqsE '"(@nestjs/core|@nestjs/common)"' "$dir/package.json" "$dir/backend/package.json" 2>/dev/null; then ((score+=1)); fi
  if grep -RqsE '"(react|@vitejs/plugin-react|vite)"' "$dir/package.json" "$dir/frontend/package.json" 2>/dev/null; then ((score+=1)); fi
  if grep -RqsE '"(mysql2|typeorm|@prisma/client|sequelize)"' "$dir/package.json" "$dir/backend/package.json" 2>/dev/null || { [[ -f "$dir/docker-compose.yml" ]] && grep -qsE 'mysql|mariadb' "$dir/docker-compose.yml"; }; then ((score+=1)); fi
  if (( score >= 3 )); then
    echo "node-nest-react-mysql"
  else
    echo "none"
  fi
}
