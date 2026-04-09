#!/usr/bin/env bash
# tests/unit/test_planner.sh
# Unit tests for lib/planner.sh:
#   - plan_init clears state
#   - plan_add appends entries with correct format
#   - plan_add rejects pipe delimiter in values
#   - plan_count returns correct count
#   - plan_get_entry retrieves by 1-based index
#   - plan_get_entry rejects out-of-range indices
#   - plan_remove deletes entry at given 1-based index
#   - plan_remove rejects out-of-range indices
#   - plan_clear empties the plan
#   - plan_validate passes when all script paths exist
#   - plan_validate fails when a script path is missing
#   - plan_export writes a readable file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYUNARCH_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export HYUNARCH_ROOT HYUNARCH_DRY_RUN="1" HYUNARCH_VERBOSE=""

# shellcheck disable=SC1091
source "${HYUNARCH_ROOT}/lib/common.sh"
hyunarch_source "logging.sh"
hyunarch_source "ui.sh"
hyunarch_source "planner.sh"

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

# ---------------------------------------------------------------------------
# Test 1: plan_init starts with zero entries
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 1: plan_init ---"

plan_init
count="$(plan_count)"
_assert_eq "plan_count after plan_init" "$count" "0"

# ---------------------------------------------------------------------------
# Test 2: plan_add appends entries; plan_count increments
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 2: plan_add and plan_count ---"

plan_init
plan_add "app" "kitty" "hyunarch" "scripts/hyunarch/kitty.sh"
_assert_eq "plan_count after 1 add" "$(plan_count)" "1"

plan_add "theme" "catppuccin-kde" "direct" "scripts/themes/catppuccin-kde.sh"
_assert_eq "plan_count after 2 adds" "$(plan_count)" "2"

plan_add "preset" "hyunarch-kde-full" "direct" "scripts/presets/hyunarch-kde-full.sh"
_assert_eq "plan_count after 3 adds" "$(plan_count)" "3"

# ---------------------------------------------------------------------------
# Test 3: plan_get_entry returns correct pipe-delimited string at 1-based index
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 3: plan_get_entry ---"

entry1="$(plan_get_entry 1)"
_assert_eq "entry 1" "$entry1" "app|kitty|hyunarch|scripts/hyunarch/kitty.sh"

entry2="$(plan_get_entry 2)"
_assert_eq "entry 2" "$entry2" "theme|catppuccin-kde|direct|scripts/themes/catppuccin-kde.sh"

entry3="$(plan_get_entry 3)"
_assert_eq "entry 3" "$entry3" "preset|hyunarch-kde-full|direct|scripts/presets/hyunarch-kde-full.sh"

# Out of range (high)
plan_get_entry 99 > /dev/null 2>&1 && _fail "plan_get_entry 99 should return non-zero" || \
  _pass "plan_get_entry 99: correctly returned non-zero"

# Out of range (zero)
plan_get_entry 0 > /dev/null 2>&1 && _fail "plan_get_entry 0 should return non-zero" || \
  _pass "plan_get_entry 0: correctly returned non-zero"

# ---------------------------------------------------------------------------
# Test 4: plan_remove removes entry at 1-based index, preserves rest
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 4: plan_remove ---"

plan_init
plan_add "app" "kitty"    "hyunarch" "scripts/hyunarch/kitty.sh"
plan_add "app" "neovim"   "clean"    "scripts/apps/neovim-clean.sh"
plan_add "app" "starship" "hyunarch" "scripts/hyunarch/starship.sh"

# Remove the middle entry (index 2 = neovim)
plan_remove 2
_assert_eq "plan_count after remove" "$(plan_count)" "2"

entry_a="$(plan_get_entry 1)"
entry_b="$(plan_get_entry 2)"
_assert_eq "entry 1 after remove is kitty"    "$entry_a" "app|kitty|hyunarch|scripts/hyunarch/kitty.sh"
_assert_eq "entry 2 after remove is starship" "$entry_b" "app|starship|hyunarch|scripts/hyunarch/starship.sh"

# Remove first entry
plan_remove 1
_assert_eq "plan_count after second remove" "$(plan_count)" "1"
entry_remaining="$(plan_get_entry 1)"
_assert_eq "remaining entry is starship" "$entry_remaining" "app|starship|hyunarch|scripts/hyunarch/starship.sh"

# Out-of-range remove (should fail gracefully, not crash)
plan_remove 99 > /dev/null 2>&1 && _fail "plan_remove 99 should return non-zero" || \
  _pass "plan_remove 99: correctly returned non-zero"
_assert_eq "plan_count unchanged after bad remove" "$(plan_count)" "1"

# ---------------------------------------------------------------------------
# Test 5: plan_clear empties the plan
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 5: plan_clear ---"

plan_init
plan_add "app" "firefox" "clean" "scripts/apps/firefox-clean.sh"
plan_add "app" "kitty"   "clean" "scripts/apps/kitty-clean.sh"
_assert_eq "plan_count before clear" "$(plan_count)" "2"

plan_clear
_assert_eq "plan_count after clear" "$(plan_count)" "0"

# get_entry on cleared plan should fail gracefully
plan_get_entry 1 > /dev/null 2>&1 && _fail "plan_get_entry on cleared plan should fail" || \
  _pass "plan_get_entry 1 on empty plan: correctly returned non-zero"

# ---------------------------------------------------------------------------
# Test 6: plan_add rejects values containing the pipe delimiter
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 6: pipe delimiter guard in plan_add ---"

plan_init

_pipe_add_fails() {
  local desc="$1"; shift
  # plan_add calls die() which calls exit -- must run in a subshell to contain it
  local rc=0
  ( plan_add "$@" > /dev/null 2>&1 ) || rc=$?
  if [[ "$rc" -ne 0 ]]; then
    _pass "plan_add with pipe in ${desc}: correctly rejected (exit ${rc})"
  else
    _fail "plan_add with pipe in ${desc}: should have been rejected"
  fi
}

_pipe_add_fails "action_type"  "app|bad" "kitty"   "hyunarch" "scripts/hyunarch/kitty.sh"
_pipe_add_fails "target_id"    "app"     "kit|ty"  "hyunarch" "scripts/hyunarch/kitty.sh"
_pipe_add_fails "install_mode" "app"     "kitty"   "hy|unarch" "scripts/hyunarch/kitty.sh"
_pipe_add_fails "script_path"  "app"     "kitty"   "hyunarch" "scripts/hyunarch/kit|ty.sh"

# Plan should still be at 0 after all failures
_assert_eq "plan count still 0 after rejected adds" "$(plan_count)" "0"

# ---------------------------------------------------------------------------
# Test 7: plan_validate passes when all script paths exist on disk
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 7: plan_validate with valid paths ---"

plan_init
# These scripts exist as placeholders in the project
plan_add "app"    "kitty"              "hyunarch" "scripts/hyunarch/kitty.sh"
plan_add "app"    "neovim"             "clean"    "scripts/apps/neovim-clean.sh"
plan_add "theme"  "catppuccin-kde"     "direct"   "scripts/themes/catppuccin-kde.sh"
plan_add "preset" "hyunarch-kde-full"  "direct"   "scripts/presets/hyunarch-kde-full.sh"

rc=0
plan_validate > /dev/null 2>&1 || rc=$?
if [[ "$rc" -eq 0 ]]; then
  _pass "plan_validate: passes for all existing script paths"
else
  _fail "plan_validate: unexpectedly failed (exit ${rc})"
fi

# ---------------------------------------------------------------------------
# Test 8: plan_validate fails when a script path is missing
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 8: plan_validate with missing path ---"

plan_init
plan_add "app" "ghost-app" "clean" "scripts/apps/does-not-exist.sh"

rc=0
plan_validate > /dev/null 2>&1 || rc=$?
if [[ "$rc" -ne 0 ]]; then
  _pass "plan_validate: correctly fails for missing script path"
else
  _fail "plan_validate: should have failed for missing script path"
fi

# ---------------------------------------------------------------------------
# Test 9: plan_export writes a file containing all entries
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 9: plan_export ---"

plan_init
plan_add "app"   "kitty"  "hyunarch" "scripts/hyunarch/kitty.sh"
plan_add "theme" "nordic-kde" "direct" "scripts/themes/nordic-kde.sh"

export_file="/tmp/hyunarch-test-export-$$.txt"
plan_export "$export_file" > /dev/null 2>&1

if [[ -f "$export_file" ]]; then
  _pass "plan_export: output file exists at ${export_file}"
else
  _fail "plan_export: output file not created"
fi

if grep -q "app|kitty|hyunarch|scripts/hyunarch/kitty.sh" "$export_file"; then
  _pass "plan_export: kitty entry present in file"
else
  _fail "plan_export: kitty entry missing from file"
fi

if grep -q "theme|nordic-kde|direct|scripts/themes/nordic-kde.sh" "$export_file"; then
  _pass "plan_export: nordic-kde entry present in file"
else
  _fail "plan_export: nordic-kde entry missing from file"
fi

rm -f "$export_file"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "  test_planner.sh: ${errors} error(s) found."
  exit 1
fi
echo "  test_planner.sh: all checks passed."
exit 0
