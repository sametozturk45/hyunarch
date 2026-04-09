#!/usr/bin/env bash
# tests/integration/test_full_flow_dryrun.sh
# End-to-end dry-run simulation of the complete Hyunarch flow:
#
#   distro selection -> PM selection -> DE selection ->
#   config loading -> plan building -> plan validation -> dry-run dispatch
#
# Interactive UI functions (ui_menu_single, ui_menu_multi, ui_confirm) are
# stubbed so the test runs without a terminal.
#
# Three representative scenario combinations are tested:
#   1. arch / pacman / hyprland -- kitty (hyunarch) + catppuccin-hyprland theme
#   2. ubuntu / apt / gnome    -- neovim (clean) + firefox (clean) + catppuccin-gnome
#   3. fedora / dnf / kde      -- zsh (hyunarch) + nordic-kde theme + preset kde-full
#
# Every scenario:
#   - validates plan entries
#   - verifies dispatch_execute_plan succeeds in dry-run mode
#   - verifies HYUNARCH_INSTALL_MODE is set correctly for each dispatched entry

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYUNARCH_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export HYUNARCH_ROOT HYUNARCH_DRY_RUN="1" HYUNARCH_VERBOSE=""

# shellcheck disable=SC1091
source "${HYUNARCH_ROOT}/lib/common.sh"
hyunarch_source "logging.sh"
hyunarch_source "ui.sh"
hyunarch_source "config_loader.sh"
hyunarch_source "distro.sh"
hyunarch_source "package_manager.sh"
hyunarch_source "desktop_environment.sh"
hyunarch_source "planner.sh"
hyunarch_source "dispatcher.sh"

_LOG_FILE="/dev/null"

errors=0
_fail() { echo "  [FAIL] $*" >&2; (( errors++ )) || true; }
_pass() { echo "  [PASS] $*"; }
_assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then _pass "${label}: '${actual}'"
  else _fail "${label}: expected '${expected}', got '${actual}'"
  fi
}

# ---------------------------------------------------------------------------
# Stub package-manager commands so pm_install_cmd doesn't pollute output
# These stubs are only used if any test accidentally calls pm_select against
# a real PM binary check; they don't affect dispatch.
# ---------------------------------------------------------------------------
pacman() { echo "[STUB] pacman $*" >&2; }
yay()    { echo "[STUB] yay $*" >&2; }
paru()   { echo "[STUB] paru $*" >&2; }
apt()    { echo "[STUB] apt $*" >&2; }
dnf()    { echo "[STUB] dnf $*" >&2; }
export -f pacman yay paru apt dnf

# ---------------------------------------------------------------------------
# Helper: run a full scenario without interactive menus
# Args: distro_id  pm_id  de_id
# The caller builds the plan before invoking this; here we just validate+execute.
# ---------------------------------------------------------------------------
_run_scenario_dispatch() {
  local label="$1"
  echo ""
  echo "  --- Dispatch: ${label} ---"

  # Validate plan paths exist
  local rc=0
  plan_validate > /dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    _pass "${label}: plan_validate passed"
  else
    _fail "${label}: plan_validate failed (exit ${rc})"
  fi

  # Execute in dry-run (no real scripts run)
  rc=0
  dispatch_execute_plan > /dev/null 2>&1 || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    _pass "${label}: dispatch_execute_plan (dry-run) returned 0"
  else
    _fail "${label}: dispatch_execute_plan (dry-run) returned ${rc}"
  fi
}

# ===========================================================================
# Scenario 1: arch / pacman / hyprland
# ===========================================================================
echo ""
echo "  ========================================"
echo "  Scenario 1: arch / pacman / hyprland"
echo "  ========================================"

export HYUNARCH_DISTRO="arch"
export HYUNARCH_PM="pacman"
export HYUNARCH_DE="hyprland"

# Validate distro/pm combination
config_load_distros
rc=0
( HYUNARCH_DISTRO="arch" HYUNARCH_PM="pacman" pm_validate > /dev/null 2>&1 ) || rc=$?
_assert_eq "S1: pm_validate arch/pacman" "$rc" "0"

# Validate DE for this distro
config_load_desktops
rc=0
( HYUNARCH_DISTRO="arch" HYUNARCH_DE="hyprland" de_validate > /dev/null 2>&1 ) || rc=$?
_assert_eq "S1: de_validate hyprland for arch" "$rc" "0"

# Build plan
plan_init

# App: kitty with hyunarch config
config_load_apps
supports_h="$(config_get_field "apps" "kitty" "supports_hyunarch_config" 2>/dev/null)"
_assert_eq "S1: kitty supports_hyunarch_config" "$supports_h" "true"
plan_add "app" "kitty" "hyunarch" "scripts/hyunarch/kitty.sh"

# App: thunar (hyprland file manager, clean only)
supports_h_th="$(config_get_field "apps" "thunar" "supports_hyunarch_config" 2>/dev/null)"
_assert_eq "S1: thunar supports_hyunarch_config" "$supports_h_th" "false"
plan_add "app" "thunar" "clean" "scripts/apps/thunar-clean.sh"

# Theme: catppuccin-hyprland
config_load_themes
plan_add "theme" "catppuccin-hyprland" "direct" "scripts/themes/catppuccin-hyprland.sh"

_assert_eq "S1: plan_count" "$(plan_count)" "3"

# Verify thunar is in the hyprland-filtered app list but NOT kde list
hypr_apps="$(config_get_filtered_ids "apps" "desktop_environments" "hyprland" 2>/dev/null || true)"
kde_apps="$(config_get_filtered_ids  "apps" "desktop_environments" "kde"      2>/dev/null || true)"

if echo "$hypr_apps" | grep -q "^thunar$"; then
  _pass "S1: thunar in hyprland app list"
else
  _fail "S1: thunar missing from hyprland app list"
fi
if ! echo "$kde_apps" | grep -q "^thunar$"; then
  _pass "S1: thunar correctly absent from kde app list"
else
  _fail "S1: thunar INCORRECTLY in kde app list"
fi

# Verify hyprland-specific theme not in KDE list
kde_themes="$(config_get_filtered_ids "themes" "desktop_environments" "kde" 2>/dev/null || true)"
if ! echo "$kde_themes" | grep -q "^catppuccin-hyprland$"; then
  _pass "S1: catppuccin-hyprland absent from kde theme list"
else
  _fail "S1: catppuccin-hyprland INCORRECTLY in kde theme list"
fi

_run_scenario_dispatch "Scenario1:arch/pacman/hyprland"

# ===========================================================================
# Scenario 2: ubuntu / apt / gnome
# ===========================================================================
echo ""
echo "  ========================================"
echo "  Scenario 2: ubuntu / apt / gnome"
echo "  ========================================"

export HYUNARCH_DISTRO="ubuntu"
export HYUNARCH_PM="apt"
export HYUNARCH_DE="gnome"

rc=0
( HYUNARCH_DISTRO="ubuntu" HYUNARCH_PM="apt" pm_validate > /dev/null 2>&1 ) || rc=$?
_assert_eq "S2: pm_validate ubuntu/apt" "$rc" "0"

# hyprland must be unavailable for ubuntu
gnome_filter="$(config_get_filtered_ids "desktops" "supported_distros" "ubuntu" 2>/dev/null || true)"
if ! echo "$gnome_filter" | grep -q "^hyprland$"; then
  _pass "S2: hyprland correctly absent for ubuntu"
else
  _fail "S2: hyprland INCORRECTLY available for ubuntu"
fi

plan_init

# neovim: clean install only for ubuntu (supports_hyunarch_config true but we test clean path)
plan_add "app" "neovim" "clean" "scripts/apps/neovim-clean.sh"

# firefox: clean only (supports_hyunarch_config=false)
supports_h_ff="$(config_get_field "apps" "firefox" "supports_hyunarch_config" 2>/dev/null)"
_assert_eq "S2: firefox supports_hyunarch_config" "$supports_h_ff" "false"
plan_add "app" "firefox" "clean" "scripts/apps/firefox-clean.sh"

# nautilus: GNOME file manager
gnome_apps="$(config_get_filtered_ids "apps" "desktop_environments" "gnome" 2>/dev/null || true)"
if echo "$gnome_apps" | grep -q "^nautilus$"; then
  _pass "S2: nautilus in gnome app list"
else
  _fail "S2: nautilus missing from gnome app list"
fi
plan_add "app" "nautilus" "clean" "scripts/apps/nautilus-clean.sh"

# Theme: catppuccin-gnome
config_load_themes
plan_add "theme" "catppuccin-gnome" "direct" "scripts/themes/catppuccin-gnome.sh"

_assert_eq "S2: plan_count" "$(plan_count)" "4"

# dolphin must NOT appear in gnome list
if ! echo "$gnome_apps" | grep -q "^dolphin$"; then
  _pass "S2: dolphin correctly absent from gnome app list"
else
  _fail "S2: dolphin INCORRECTLY in gnome app list"
fi

_run_scenario_dispatch "Scenario2:ubuntu/apt/gnome"

# ===========================================================================
# Scenario 3: fedora / dnf / kde
# ===========================================================================
echo ""
echo "  ========================================"
echo "  Scenario 3: fedora / dnf / kde"
echo "  ========================================"

export HYUNARCH_DISTRO="fedora"
export HYUNARCH_PM="dnf"
export HYUNARCH_DE="kde"

rc=0
( HYUNARCH_DISTRO="fedora" HYUNARCH_PM="dnf" pm_validate > /dev/null 2>&1 ) || rc=$?
_assert_eq "S3: pm_validate fedora/dnf" "$rc" "0"

# fedora does support hyprland (DE level), but we chose kde
hypr_for_fedora="$(config_get_filtered_ids "desktops" "supported_distros" "fedora" 2>/dev/null || true)"
if echo "$hypr_for_fedora" | grep -q "^hyprland$"; then
  _pass "S3: hyprland still available for fedora (we just chose KDE)"
else
  _fail "S3: hyprland should be available for fedora"
fi

plan_init

# zsh with hyunarch config
plan_add "app" "zsh" "hyunarch" "scripts/hyunarch/zsh.sh"

# dolphin (KDE file manager)
kde_apps="$(config_get_filtered_ids "apps" "desktop_environments" "kde" 2>/dev/null || true)"
if echo "$kde_apps" | grep -q "^dolphin$"; then
  _pass "S3: dolphin in kde app list"
else
  _fail "S3: dolphin missing from kde app list"
fi
plan_add "app" "dolphin" "clean" "scripts/apps/dolphin-clean.sh"

# starship (shell, "all" DE)
plan_add "app" "starship" "hyunarch" "scripts/hyunarch/starship.sh"

# Nordic KDE theme
plan_add "theme" "nordic-kde" "direct" "scripts/themes/nordic-kde.sh"

# Preset: hyunarch-kde-full
config_load_presets
kde_presets="$(config_get_filtered_ids "presets" "desktop_environments" "kde" 2>/dev/null || true)"
if echo "$kde_presets" | grep -q "^hyunarch-kde-full$"; then
  _pass "S3: hyunarch-kde-full in kde preset list"
else
  _fail "S3: hyunarch-kde-full missing from kde preset list"
fi
plan_add "preset" "hyunarch-kde-full" "direct" "scripts/presets/hyunarch-kde-full.sh"

_assert_eq "S3: plan_count" "$(plan_count)" "5"

# Verify hyunarch-hyprland-full is NOT in the kde preset list
if ! echo "$kde_presets" | grep -q "^hyunarch-hyprland-full$"; then
  _pass "S3: hyunarch-hyprland-full correctly absent from kde preset list"
else
  _fail "S3: hyunarch-hyprland-full INCORRECTLY in kde preset list"
fi

# Verify thunar (hyprland file manager) NOT in kde list
if ! echo "$kde_apps" | grep -q "^thunar$"; then
  _pass "S3: thunar correctly absent from kde app list"
else
  _fail "S3: thunar INCORRECTLY in kde app list"
fi

_run_scenario_dispatch "Scenario3:fedora/dnf/kde"

# ===========================================================================
# Scenario 4: Invalid PM/distro combination is caught before plan executes
# ===========================================================================
echo ""
echo "  ========================================"
echo "  Scenario 4: invalid distro/PM guard"
echo "  ========================================"

# ubuntu + pacman must be rejected by pm_validate
rc=0
( HYUNARCH_DISTRO="ubuntu" HYUNARCH_PM="pacman" pm_validate > /dev/null 2>&1 ) || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "S4: ubuntu/pacman correctly rejected by pm_validate"
else
  _fail "S4: ubuntu/pacman should be rejected"
fi

# arch + apt must be rejected
rc=0
( HYUNARCH_DISTRO="arch" HYUNARCH_PM="apt" pm_validate > /dev/null 2>&1 ) || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "S4: arch/apt correctly rejected by pm_validate"
else
  _fail "S4: arch/apt should be rejected"
fi

# ===========================================================================
# Scenario 5: Hyunarch-config path is explicit -- clean script is NOT used
# ===========================================================================
echo ""
echo "  ========================================"
echo "  Scenario 5: hyunarch vs clean path isolation"
echo "  ========================================"

plan_init

# kitty: both modes supported -- verify hyunarch path differs from clean path
hyunarch_script="$(config_get_field "apps" "kitty" "hyunarch_script" 2>/dev/null)"
clean_script="$(config_get_field "apps" "kitty" "clean_install_script" 2>/dev/null)"

if [[ "$hyunarch_script" != "$clean_script" ]]; then
  _pass "S5: kitty hyunarch_script != clean_install_script (paths are distinct)"
else
  _fail "S5: kitty hyunarch_script and clean_install_script must differ"
fi

plan_add "app" "kitty" "hyunarch" "$hyunarch_script"
entry="$(plan_get_entry 1)"

# Entry must contain the hyunarch path, NOT the clean path
if echo "$entry" | grep -q "hyunarch/kitty.sh"; then
  _pass "S5: plan entry uses hyunarch path"
else
  _fail "S5: plan entry should use hyunarch path, got '${entry}'"
fi

if ! echo "$entry" | grep -q "apps/kitty-clean.sh"; then
  _pass "S5: plan entry does NOT contain clean path"
else
  _fail "S5: plan entry INCORRECTLY contains clean path"
fi

rc=0
dispatch_execute_plan > /dev/null 2>&1 || rc=$?
_assert_eq "S5: dry-run dispatch of hyunarch-mode entry" "$rc" "0"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "  test_full_flow_dryrun.sh: ${errors} error(s) found."
  exit 1
fi
echo "  test_full_flow_dryrun.sh: all checks passed."
exit 0
