#!/usr/bin/env bash
# tests/dispatch/test_script_paths.sh -- Verify every script path referenced
# in config files actually exists on disk.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYUNARCH_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export HYUNARCH_ROOT
HYUNARCH_DRY_RUN="1"
HYUNARCH_VERBOSE=""
export HYUNARCH_DRY_RUN HYUNARCH_VERBOSE

# shellcheck disable=SC1091
source "${HYUNARCH_ROOT}/lib/common.sh"
hyunarch_source "logging.sh"
hyunarch_source "ui.sh"
hyunarch_source "config_loader.sh"

_LOG_FILE="/dev/null"

errors=0
checked=0

_fail() {
  echo "  [FAIL] $*" >&2
  (( errors++ )) || true
}

_pass() {
  echo "  [PASS] $*"
  (( checked++ )) || true
}

_check_script_path() {
  local label="$1"
  local rel_path="$2"

  # Empty path is valid for apps that don't support a mode
  if [[ -z "$rel_path" ]]; then
    return 0
  fi

  local abs_path="${HYUNARCH_ROOT}/${rel_path}"
  if [[ -f "$abs_path" ]]; then
    _pass "${label}: ${rel_path}"
  else
    _fail "${label}: MISSING ${abs_path}"
  fi
}

# ===========================================================================
# Presets
# ===========================================================================
echo ""
echo "  --- presets ---"
config_load_presets

local_ids=()
while IFS= read -r pid; do
  [[ -z "$pid" ]] && continue
  local_ids+=("$pid")
done < <(config_get_ids "presets")

for pid in "${local_ids[@]}"; do
  scripts_raw="$(config_get_field "presets" "$pid" "scripts" 2>/dev/null || true)"
  [[ -z "$scripts_raw" ]] && continue
  IFS=',' read -ra sp_list <<< "$scripts_raw"
  for sp in "${sp_list[@]}"; do
    sp="${sp#"${sp%%[! ]*}"}"
    sp="${sp%"${sp##*[! ]}"}"
    [[ -n "$sp" ]] && _check_script_path "preset:${pid}" "$sp"
  done
done

# ===========================================================================
# Themes
# ===========================================================================
echo ""
echo "  --- themes ---"
config_load_themes

while IFS= read -r tid; do
  [[ -z "$tid" ]] && continue
  sp="$(config_get_field "themes" "$tid" "script" 2>/dev/null || true)"
  _check_script_path "theme:${tid}" "$sp"
done < <(config_get_ids "themes")

# ===========================================================================
# Apps (clean_install_script and hyunarch_script)
# ===========================================================================
echo ""
echo "  --- apps ---"
config_load_apps

while IFS= read -r aid; do
  [[ -z "$aid" ]] && continue

  clean_sp="$(config_get_field "apps" "$aid" "clean_install_script" 2>/dev/null || true)"
  _check_script_path "app:${aid}:clean" "$clean_sp"

  hyun_sp="$(config_get_field "apps" "$aid" "hyunarch_script" 2>/dev/null || true)"
  _check_script_path "app:${aid}:hyunarch" "$hyun_sp"

done < <(config_get_ids "apps")

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "  Checked ${checked} script path(s)."

if [[ "$errors" -gt 0 ]]; then
  echo "  test_script_paths.sh: ${errors} path(s) missing."
  exit 1
fi

echo "  test_script_paths.sh: all script paths exist."
exit 0
