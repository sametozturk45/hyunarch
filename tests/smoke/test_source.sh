#!/usr/bin/env bash
# tests/smoke/test_source.sh -- Verify each lib module can be sourced cleanly
# and exposes its expected functions.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYUNARCH_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export HYUNARCH_ROOT

# We need a writable /tmp for log_init; guard in case we're in a restricted env.
HYUNARCH_DRY_RUN="1"
HYUNARCH_VERBOSE=""
export HYUNARCH_DRY_RUN HYUNARCH_VERBOSE

errors=0

_fail() {
  echo "  [FAIL] $*" >&2
  (( errors++ )) || true
}

_pass() {
  echo "  [PASS] $*"
}

# ---------------------------------------------------------------------------
# Source common.sh first (required by all others)
# ---------------------------------------------------------------------------
# shellcheck disable=SC1091
if source "${HYUNARCH_ROOT}/lib/common.sh" 2>/dev/null; then
  _pass "source lib/common.sh"
else
  _fail "source lib/common.sh"
  exit 1
fi

# Check common.sh functions
for fn in die require_command require_file is_dry_run hyunarch_source; do
  if declare -F "$fn" > /dev/null 2>&1; then
    _pass "function exists: ${fn}"
  else
    _fail "function missing: ${fn}"
  fi
done

# ---------------------------------------------------------------------------
# Source each remaining module via hyunarch_source()
# ---------------------------------------------------------------------------
modules=(logging.sh ui.sh config_loader.sh distro.sh package_manager.sh desktop_environment.sh planner.sh dispatcher.sh)

for mod in "${modules[@]}"; do
  if hyunarch_source "$mod" 2>/dev/null; then
    _pass "hyunarch_source ${mod}"
  else
    _fail "hyunarch_source ${mod}"
  fi
done

# ---------------------------------------------------------------------------
# Check expected functions per module
# ---------------------------------------------------------------------------
declare -A expected_functions
expected_functions["logging"]="log_init log_debug log_info log_warn log_error log_section"
expected_functions["ui"]="ui_banner ui_menu_single ui_menu_multi ui_confirm ui_print_plan ui_separator ui_info ui_warn ui_error"
expected_functions["config_loader"]="config_load_distros config_load_desktops config_load_presets config_load_themes config_load_apps config_get_ids config_get_field config_get_filtered_ids"
expected_functions["distro"]="distro_select distro_get_display_name distro_validate"
expected_functions["package_manager"]="pm_select pm_validate pm_install_cmd pm_is_available"
expected_functions["desktop_environment"]="de_select de_get_display_name de_validate"
expected_functions["planner"]="plan_init plan_add plan_remove plan_clear plan_count plan_display plan_get_entry plan_validate plan_export"
expected_functions["dispatcher"]="dispatch_single dispatch_execute_plan"

for module_key in "${!expected_functions[@]}"; do
  for fn in ${expected_functions[$module_key]}; do
    if declare -F "$fn" > /dev/null 2>&1; then
      _pass "function exists: ${fn}"
    else
      _fail "function missing: ${fn} (expected from ${module_key})"
    fi
  done
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "  test_source.sh: ${errors} error(s) found."
  exit 1
fi

echo "  test_source.sh: all checks passed."
exit 0
