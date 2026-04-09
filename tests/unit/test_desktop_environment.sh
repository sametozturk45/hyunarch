#!/usr/bin/env bash
# tests/unit/test_desktop_environment.sh
# Tests for lib/desktop_environment.sh:
#   - Hyprland is available for arch and fedora only
#   - Hyprland is NOT available for ubuntu or debian
#   - KDE and GNOME are available for ALL distros (including ubuntu, debian)
#   - de_get_display_name returns the correct display name
#   - de_validate passes for a loaded and set DE id
#   - de_validate fails when HYUNARCH_DE is empty
#   - de_validate fails for a nonexistent DE id

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYUNARCH_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export HYUNARCH_ROOT HYUNARCH_DRY_RUN="1" HYUNARCH_VERBOSE=""

# shellcheck disable=SC1091
source "${HYUNARCH_ROOT}/lib/common.sh"
hyunarch_source "logging.sh"
hyunarch_source "ui.sh"
hyunarch_source "config_loader.sh"
hyunarch_source "desktop_environment.sh"

_LOG_FILE="/dev/null"

errors=0

_fail() { echo "  [FAIL] $*" >&2; (( errors++ )) || true; }
_pass() { echo "  [PASS] $*"; }

# Pre-load desktops config once for all tests
config_load_desktops

# ---------------------------------------------------------------------------
# Helper: check if a DE id appears in the filtered list for a given distro
# ---------------------------------------------------------------------------
_de_available_for_distro() {
  local de_id="$1" distro_id="$2"
  local result
  result="$(config_get_filtered_ids "desktops" "supported_distros" "$distro_id" 2>/dev/null || true)"
  echo "$result" | grep -q "^${de_id}$"
}

# ---------------------------------------------------------------------------
# Test 1: Hyprland availability -- arch and fedora ONLY
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 1: Hyprland availability by distro ---"

for distro_id in arch fedora; do
  if _de_available_for_distro "hyprland" "$distro_id"; then
    _pass "Hyprland available for '${distro_id}'"
  else
    _fail "Hyprland should be available for '${distro_id}'"
  fi
done

for distro_id in ubuntu debian; do
  if ! _de_available_for_distro "hyprland" "$distro_id"; then
    _pass "Hyprland correctly unavailable for '${distro_id}'"
  else
    _fail "Hyprland must NOT be available for '${distro_id}'"
  fi
done

# ---------------------------------------------------------------------------
# Test 2: KDE and GNOME available for ALL supported distros
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 2: KDE and GNOME availability across all distros ---"

for de_id in kde gnome; do
  for distro_id in arch ubuntu debian fedora; do
    if _de_available_for_distro "$de_id" "$distro_id"; then
      _pass "'${de_id}' available for '${distro_id}'"
    else
      _fail "'${de_id}' should be available for '${distro_id}'"
    fi
  done
done

# ---------------------------------------------------------------------------
# Test 3: de_get_display_name returns expected names
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 3: de_get_display_name ---"

declare -A expected_names
expected_names["hyprland"]="Hyprland"
expected_names["kde"]="KDE Plasma"
expected_names["gnome"]="GNOME"

for de_id in "${!expected_names[@]}"; do
  actual="$(de_get_display_name "$de_id" 2>/dev/null)"
  expected="${expected_names[$de_id]}"
  if [[ "$actual" == "$expected" ]]; then
    _pass "de_get_display_name '${de_id}': '${actual}'"
  else
    _fail "de_get_display_name '${de_id}': expected '${expected}', got '${actual}'"
  fi
done

# Unknown DE id should fall back to the id itself
fallback="$(de_get_display_name "unknown-de-xyz" 2>/dev/null)"
if [[ "$fallback" == "unknown-de-xyz" ]]; then
  _pass "de_get_display_name unknown id: falls back to id"
else
  _fail "de_get_display_name unknown id: expected 'unknown-de-xyz', got '${fallback}'"
fi

# ---------------------------------------------------------------------------
# Test 4: de_validate passes for a valid, loaded DE id
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 4: de_validate for known DEs ---"

for de_id in hyprland kde gnome; do
  HYUNARCH_DE="$de_id"
  export HYUNARCH_DE
  rc=0
  ( de_validate > /dev/null 2>&1 ) || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    _pass "de_validate '${de_id}': passed"
  else
    _fail "de_validate '${de_id}': should have passed but got exit ${rc}"
  fi
done

# ---------------------------------------------------------------------------
# Test 5: de_validate fails when HYUNARCH_DE is empty
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 5: de_validate empty HYUNARCH_DE ---"

HYUNARCH_DE=""
export HYUNARCH_DE
rc=0
( de_validate > /dev/null 2>&1 ) || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "de_validate: empty HYUNARCH_DE correctly rejected"
else
  _fail "de_validate: empty HYUNARCH_DE should have been rejected"
fi

# ---------------------------------------------------------------------------
# Test 6: de_validate fails for a nonexistent DE id
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 6: de_validate nonexistent DE id ---"

HYUNARCH_DE="enlightenment"
export HYUNARCH_DE
rc=0
( de_validate > /dev/null 2>&1 ) || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "de_validate 'enlightenment': correctly rejected as unknown"
else
  _fail "de_validate 'enlightenment': should have been rejected"
fi

# ---------------------------------------------------------------------------
# Test 7: DE option isolation -- themes loaded for one DE exclude another DE's themes
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 7: DE-specific theme isolation (cross-check via config_loader) ---"

# Load themes section
hyunarch_source "config_loader.sh" 2>/dev/null || true
config_load_themes 2>/dev/null || true

# catppuccin-hyprland is Hyprland-only
hypr_themes="$(config_get_filtered_ids "themes" "desktop_environments" "hyprland" 2>/dev/null || true)"
kde_themes="$(config_get_filtered_ids  "themes" "desktop_environments" "kde"      2>/dev/null || true)"
gnome_themes="$(config_get_filtered_ids "themes" "desktop_environments" "gnome"    2>/dev/null || true)"

if echo "$hypr_themes" | grep -q "^catppuccin-hyprland$"; then
  _pass "catppuccin-hyprland present in hyprland theme list"
else
  _fail "catppuccin-hyprland missing from hyprland theme list"
fi

if ! echo "$kde_themes" | grep -q "^catppuccin-hyprland$"; then
  _pass "catppuccin-hyprland correctly absent from KDE theme list"
else
  _fail "catppuccin-hyprland INCORRECTLY appears in KDE theme list"
fi

if ! echo "$gnome_themes" | grep -q "^catppuccin-hyprland$"; then
  _pass "catppuccin-hyprland correctly absent from GNOME theme list"
else
  _fail "catppuccin-hyprland INCORRECTLY appears in GNOME theme list"
fi

# nordic-kde is KDE-only
if echo "$kde_themes" | grep -q "^nordic-kde$"; then
  _pass "nordic-kde present in KDE theme list"
else
  _fail "nordic-kde missing from KDE theme list"
fi

if ! echo "$hypr_themes" | grep -q "^nordic-kde$"; then
  _pass "nordic-kde correctly absent from hyprland theme list"
else
  _fail "nordic-kde INCORRECTLY appears in hyprland theme list"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "  test_desktop_environment.sh: ${errors} error(s) found."
  exit 1
fi
echo "  test_desktop_environment.sh: all checks passed."
exit 0
