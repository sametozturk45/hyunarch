#!/usr/bin/env bash
# tests/config/test_config_parse.sh -- Parse all configs and verify expected
# ids, field values, and filtering logic.

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

# Initialize logging to /dev/null for tests
_LOG_FILE="/dev/null"

errors=0

_fail() {
  echo "  [FAIL] $*" >&2
  (( errors++ )) || true
}

_pass() {
  echo "  [PASS] $*"
}

_assert_id_present() {
  local section="$1"
  local expected_id="$2"
  local found=0
  local id
  while IFS= read -r id; do
    [[ "$id" == "$expected_id" ]] && found=1 && break
  done < <(config_get_ids "$section")
  if [[ "$found" -eq 1 ]]; then
    _pass "id '${expected_id}' present in section '${section}'"
  else
    _fail "id '${expected_id}' MISSING from section '${section}'"
  fi
}

_assert_field_eq() {
  local section="$1" id="$2" field="$3" expected="$4"
  local actual
  actual="$(config_get_field "$section" "$id" "$field" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" ]]; then
    _pass "field ${section}.${id}.${field} = '${expected}'"
  else
    _fail "field ${section}.${id}.${field}: expected '${expected}', got '${actual}'"
  fi
}

_assert_filtered_contains() {
  local section="$1" field="$2" filter="$3" expected_id="$4"
  local found=0
  local id
  while IFS= read -r id; do
    [[ "$id" == "$expected_id" ]] && found=1 && break
  done < <(config_get_filtered_ids "$section" "$field" "$filter")
  if [[ "$found" -eq 1 ]]; then
    _pass "filter ${section}[${field}=${filter}] contains '${expected_id}'"
  else
    _fail "filter ${section}[${field}=${filter}] does NOT contain '${expected_id}'"
  fi
}

_assert_filtered_excludes() {
  local section="$1" field="$2" filter="$3" excluded_id="$4"
  local found=0
  local id
  while IFS= read -r id; do
    [[ "$id" == "$excluded_id" ]] && found=1 && break
  done < <(config_get_filtered_ids "$section" "$field" "$filter")
  if [[ "$found" -eq 0 ]]; then
    _pass "filter ${section}[${field}=${filter}] correctly excludes '${excluded_id}'"
  else
    _fail "filter ${section}[${field}=${filter}] INCORRECTLY includes '${excluded_id}'"
  fi
}

# ===========================================================================
# distros.yaml
# ===========================================================================
echo ""
echo "  --- distros.yaml ---"
config_load_distros

_assert_id_present "distros" "arch"
_assert_id_present "distros" "ubuntu"
_assert_id_present "distros" "debian"
_assert_id_present "distros" "fedora"

_assert_field_eq "distros" "arch"   "display_name"              "Arch Linux"
_assert_field_eq "distros" "ubuntu" "default_package_manager"   "apt"
_assert_field_eq "distros" "fedora" "default_package_manager"   "dnf"

# pacman should appear in arch's supported_package_managers
arch_pms="$(config_get_field "distros" "arch" "supported_package_managers" 2>/dev/null || true)"
if echo "$arch_pms" | grep -q "pacman"; then
  _pass "arch supported_package_managers contains 'pacman'"
else
  _fail "arch supported_package_managers missing 'pacman': got '${arch_pms}'"
fi

# ===========================================================================
# desktops.yaml
# ===========================================================================
echo ""
echo "  --- desktops.yaml ---"
config_load_desktops

_assert_id_present "desktops" "hyprland"
_assert_id_present "desktops" "kde"
_assert_id_present "desktops" "gnome"

_assert_field_eq "desktops" "hyprland" "display_name" "Hyprland"
_assert_field_eq "desktops" "kde"      "display_name" "KDE Plasma"

# hyprland is only for arch and fedora
_assert_filtered_contains  "desktops" "supported_distros" "arch"   "hyprland"
_assert_filtered_contains  "desktops" "supported_distros" "fedora" "hyprland"
# kde and gnome use "all" -- must appear for ubuntu too
_assert_filtered_contains  "desktops" "supported_distros" "ubuntu" "kde"
_assert_filtered_contains  "desktops" "supported_distros" "ubuntu" "gnome"
# hyprland must NOT appear for ubuntu
_assert_filtered_excludes  "desktops" "supported_distros" "ubuntu" "hyprland"
# hyprland must NOT appear for debian
_assert_filtered_excludes  "desktops" "supported_distros" "debian" "hyprland"

# ===========================================================================
# presets.yaml
# ===========================================================================
echo ""
echo "  --- presets.yaml ---"
config_load_presets

_assert_id_present "presets" "hyunarch-hyprland-full"
_assert_id_present "presets" "hyunarch-kde-full"
_assert_id_present "presets" "hyunarch-gnome-full"

_assert_filtered_contains "presets" "desktop_environments" "hyprland" "hyunarch-hyprland-full"
_assert_filtered_excludes "presets" "desktop_environments" "kde"      "hyunarch-hyprland-full"
_assert_filtered_contains "presets" "desktop_environments" "kde"      "hyunarch-kde-full"

# ===========================================================================
# themes.yaml
# ===========================================================================
echo ""
echo "  --- themes.yaml ---"
config_load_themes

_assert_id_present "themes" "catppuccin-hyprland"
_assert_id_present "themes" "catppuccin-kde"
_assert_id_present "themes" "catppuccin-gnome"
_assert_id_present "themes" "nordic-kde"

# nordic-kde is KDE-only
_assert_filtered_contains "themes" "desktop_environments" "kde"      "nordic-kde"
_assert_filtered_excludes "themes" "desktop_environments" "hyprland" "nordic-kde"
_assert_filtered_excludes "themes" "desktop_environments" "gnome"    "nordic-kde"

# ===========================================================================
# apps.yaml
# ===========================================================================
echo ""
echo "  --- apps.yaml ---"
config_load_apps

# Categories
_assert_id_present "categories" "terminal"
_assert_id_present "categories" "browser"
_assert_id_present "categories" "editor"
_assert_id_present "categories" "file_manager"
_assert_id_present "categories" "shell"

# Apps
_assert_id_present "apps" "kitty"
_assert_id_present "apps" "firefox"
_assert_id_present "apps" "neovim"
_assert_id_present "apps" "thunar"
_assert_id_present "apps" "dolphin"
_assert_id_present "apps" "nautilus"
_assert_id_present "apps" "zsh"
_assert_id_present "apps" "starship"

# DE filtering for file managers
_assert_filtered_contains "apps" "desktop_environments" "hyprland" "thunar"
_assert_filtered_excludes "apps" "desktop_environments" "kde"      "thunar"
_assert_filtered_excludes "apps" "desktop_environments" "gnome"    "thunar"

_assert_filtered_contains "apps" "desktop_environments" "kde"      "dolphin"
_assert_filtered_excludes "apps" "desktop_environments" "hyprland" "dolphin"

_assert_filtered_contains "apps" "desktop_environments" "gnome"    "nautilus"
_assert_filtered_excludes "apps" "desktop_environments" "kde"      "nautilus"

# "all" apps appear everywhere
_assert_filtered_contains "apps" "desktop_environments" "hyprland" "kitty"
_assert_filtered_contains "apps" "desktop_environments" "kde"      "kitty"
_assert_filtered_contains "apps" "desktop_environments" "gnome"    "kitty"
_assert_filtered_contains "apps" "desktop_environments" "hyprland" "firefox"

# Field checks
_assert_field_eq "apps" "firefox" "supports_hyunarch_config" "false"
_assert_field_eq "apps" "kitty"   "supports_hyunarch_config" "true"
_assert_field_eq "apps" "kitty"   "hyunarch_script"          "scripts/hyunarch/kitty.sh"
_assert_field_eq "apps" "neovim"  "clean_install_script"     "scripts/apps/neovim-clean.sh"

# ===========================================================================
# Summary
# ===========================================================================
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "  test_config_parse.sh: ${errors} error(s) found."
  exit 1
fi

echo "  test_config_parse.sh: all checks passed."
exit 0
