#!/usr/bin/env bash
# tests/unit/test_package_manager.sh
# Tests for lib/package_manager.sh:
#   - pm_install_cmd returns correct prefix for each known PM
#   - pm_install_cmd calls die for unknown PM
#   - pm_validate passes when HYUNARCH_PM is in the distro's supported list
#   - pm_validate fails when HYUNARCH_PM is NOT in the distro's supported list
#   - pm_validate fails when HYUNARCH_PM is empty
#   - pm_is_available returns 1 for a command that does not exist on PATH
#   - pm_is_available returns 0 for a command that does exist (using 'bash' as proxy)

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

_LOG_FILE="/dev/null"

errors=0

_fail() { echo "  [FAIL] $*" >&2; (( errors++ )) || true; }
_pass() { echo "  [PASS] $*"; }

_assert_eq() {
  local label="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    _pass "${label}: '${actual}'"
  else
    _fail "${label}: expected '${expected}', got '${actual}'"
  fi
}

# Load distros so pm_validate can call config_get_field
config_load_distros

# ---------------------------------------------------------------------------
# Test 1: pm_install_cmd for all known package managers
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 1: pm_install_cmd output for known PMs ---"

declare -A expected_cmds
expected_cmds["pacman"]="sudo pacman -S --noconfirm"
expected_cmds["yay"]="yay -S --noconfirm"
expected_cmds["paru"]="paru -S --noconfirm"
expected_cmds["apt"]="sudo apt install -y"
expected_cmds["dnf"]="sudo dnf install -y"

for pm_name in "${!expected_cmds[@]}"; do
  HYUNARCH_PM="$pm_name"
  export HYUNARCH_PM
  actual="$(pm_install_cmd 2>/dev/null)"
  _assert_eq "pm_install_cmd for '${pm_name}'" "$actual" "${expected_cmds[$pm_name]}"
done

# ---------------------------------------------------------------------------
# Test 2: pm_install_cmd calls die for an unknown PM (subprocess must exit non-zero)
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 2: pm_install_cmd for unknown PM ---"

HYUNARCH_PM="zypper"
export HYUNARCH_PM

rc=0
# Run in a subshell because die calls exit
( HYUNARCH_PM="zypper" pm_install_cmd > /dev/null 2>&1 ) || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "pm_install_cmd 'zypper': correctly called die (exit ${rc})"
else
  _fail "pm_install_cmd 'zypper': should have exited non-zero"
fi

# ---------------------------------------------------------------------------
# Test 3: pm_validate passes when HYUNARCH_PM is in distro's supported list
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 3: pm_validate for valid distro/PM combinations ---"

declare -A valid_combos
valid_combos["arch,pacman"]="arch:pacman"
valid_combos["arch,yay"]="arch:yay"
valid_combos["arch,paru"]="arch:paru"
valid_combos["ubuntu,apt"]="ubuntu:apt"
valid_combos["debian,apt"]="debian:apt"
valid_combos["fedora,dnf"]="fedora:dnf"

for key in "${!valid_combos[@]}"; do
  IFS=',' read -r distro_val pm_val <<< "$key"
  HYUNARCH_DISTRO="$distro_val"
  HYUNARCH_PM="$pm_val"
  export HYUNARCH_DISTRO HYUNARCH_PM
  rc=0
  ( pm_validate > /dev/null 2>&1 ) || rc=$?
  if [[ "$rc" -eq 0 ]]; then
    _pass "pm_validate: ${distro_val}/${pm_val} is valid"
  else
    _fail "pm_validate: ${distro_val}/${pm_val} should be valid but got exit ${rc}"
  fi
done

# ---------------------------------------------------------------------------
# Test 4: pm_validate fails for invalid distro/PM combinations
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 4: pm_validate for invalid distro/PM combinations ---"

declare -A invalid_combos
# ubuntu does not support pacman
invalid_combos["ubuntu,pacman"]="ubuntu:pacman"
# fedora does not support apt
invalid_combos["fedora,apt"]="fedora:apt"
# arch does not support dnf
invalid_combos["arch,dnf"]="arch:dnf"

for key in "${!invalid_combos[@]}"; do
  IFS=',' read -r distro_val pm_val <<< "$key"
  HYUNARCH_DISTRO="$distro_val"
  HYUNARCH_PM="$pm_val"
  export HYUNARCH_DISTRO HYUNARCH_PM
  rc=0
  ( pm_validate > /dev/null 2>&1 ) || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    _pass "pm_validate: ${distro_val}/${pm_val} correctly rejected (exit ${rc})"
  else
    _fail "pm_validate: ${distro_val}/${pm_val} should have been rejected"
  fi
done

# ---------------------------------------------------------------------------
# Test 5: pm_validate fails when HYUNARCH_PM is empty
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 5: pm_validate empty HYUNARCH_PM ---"

HYUNARCH_DISTRO="arch"
HYUNARCH_PM=""
export HYUNARCH_DISTRO HYUNARCH_PM

rc=0
( pm_validate > /dev/null 2>&1 ) || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "pm_validate: empty HYUNARCH_PM correctly rejected"
else
  _fail "pm_validate: empty HYUNARCH_PM should have been rejected"
fi

# ---------------------------------------------------------------------------
# Test 6: pm_is_available returns 1 for nonexistent command
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 6: pm_is_available ---"

rc=0
pm_is_available "this-command-absolutely-does-not-exist-123456" > /dev/null 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "pm_is_available: nonexistent command returns non-zero"
else
  _fail "pm_is_available: nonexistent command should return non-zero"
fi

# bash is always available in this environment
rc=0
HYUNARCH_PM="bash"
pm_is_available > /dev/null 2>&1 || rc=$?
if [[ "$rc" -eq 0 ]]; then
  _pass "pm_is_available: 'bash' (HYUNARCH_PM) returns 0"
else
  _fail "pm_is_available: 'bash' should be available but returned ${rc}"
fi

# Explicit argument path
rc=0
pm_is_available "bash" > /dev/null 2>&1 || rc=$?
if [[ "$rc" -eq 0 ]]; then
  _pass "pm_is_available: explicit 'bash' argument returns 0"
else
  _fail "pm_is_available: explicit 'bash' should return 0 but got ${rc}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "  test_package_manager.sh: ${errors} error(s) found."
  exit 1
fi
echo "  test_package_manager.sh: all checks passed."
exit 0
