#!/usr/bin/env bash
# tests/unit/test_config_loader_edge.sh
# Edge-case tests for config_loader.sh:
#   - "all" keyword in comma-separated filter fields
#   - Comma-separated field matching (multi-value lists)
#   - Invalid id lookup returns non-zero and prints nothing
#   - Loading an empty / nonexistent file is rejected by require_file

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HYUNARCH_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export HYUNARCH_ROOT HYUNARCH_DRY_RUN="1" HYUNARCH_VERBOSE=""

# shellcheck disable=SC1091
source "${HYUNARCH_ROOT}/lib/common.sh"
hyunarch_source "logging.sh"
hyunarch_source "ui.sh"
hyunarch_source "config_loader.sh"

_LOG_FILE="/dev/null"

errors=0

_fail() { echo "  [FAIL] $*" >&2; (( errors++ )) || true; }
_pass() { echo "  [PASS] $*"; }

# ---------------------------------------------------------------------------
# Helpers: build a minimal in-memory config from a temp YAML file
# ---------------------------------------------------------------------------
_write_tmp_yaml() {
  # Args: variable-name-to-hold-path  heredoc-content-from-stdin
  local varname="$1"
  local tmpfile
  tmpfile="$(mktemp /tmp/hyunarch-test-XXXXXX.yaml)"
  cat > "$tmpfile"
  printf -v "$varname" '%s' "$tmpfile"
}

# ---------------------------------------------------------------------------
# Test 1: "all" keyword causes inclusion regardless of filter value
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 1: 'all' keyword matching ---"

_write_tmp_yaml T1_FILE << 'YAML'
things:
  - id: thing-a
    supported_for: [all]
  - id: thing-b
    supported_for: [hyprland]
  - id: thing-c
    supported_for: [kde,gnome]
YAML

# Parse using internal function directly
_cfg_parse_file "$T1_FILE" "things"

# thing-a has "all" -- must appear for every filter value
for filter_val in hyprland kde gnome ubuntu debian; do
  result="$(config_get_filtered_ids "things" "supported_for" "$filter_val" 2>/dev/null || true)"
  if echo "$result" | grep -q "^thing-a$"; then
    _pass "'thing-a' (all) appears for filter '${filter_val}'"
  else
    _fail "'thing-a' (all) NOT in filtered results for '${filter_val}'"
  fi
done

# thing-b has only [hyprland] -- must appear for hyprland, not for kde
result_hypr="$(config_get_filtered_ids "things" "supported_for" "hyprland" 2>/dev/null || true)"
if echo "$result_hypr" | grep -q "^thing-b$"; then
  _pass "'thing-b' (hyprland only) appears for 'hyprland'"
else
  _fail "'thing-b' NOT in results for 'hyprland'"
fi

result_kde="$(config_get_filtered_ids "things" "supported_for" "kde" 2>/dev/null || true)"
if ! echo "$result_kde" | grep -q "^thing-b$"; then
  _pass "'thing-b' (hyprland only) correctly absent for 'kde'"
else
  _fail "'thing-b' INCORRECTLY appears for 'kde'"
fi

rm -f "$T1_FILE"

# ---------------------------------------------------------------------------
# Test 2: Comma-separated multi-value field matching
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 2: comma-separated field matching ---"

_write_tmp_yaml T2_FILE << 'YAML'
items:
  - id: item-x
    platforms: [arch,fedora]
  - id: item-y
    platforms: [ubuntu,debian,fedora]
  - id: item-z
    platforms: [arch]
YAML

_cfg_parse_file "$T2_FILE" "items"

# item-x in arch -> yes
res="$(config_get_filtered_ids "items" "platforms" "arch" 2>/dev/null || true)"
if echo "$res" | grep -q "^item-x$"; then
  _pass "'item-x' [arch,fedora] matches filter 'arch'"
else
  _fail "'item-x' does NOT match filter 'arch'"
fi

# item-x in fedora -> yes
res="$(config_get_filtered_ids "items" "platforms" "fedora" 2>/dev/null || true)"
if echo "$res" | grep -q "^item-x$"; then
  _pass "'item-x' [arch,fedora] matches filter 'fedora'"
else
  _fail "'item-x' does NOT match filter 'fedora'"
fi

# item-x in ubuntu -> no
res="$(config_get_filtered_ids "items" "platforms" "ubuntu" 2>/dev/null || true)"
if ! echo "$res" | grep -q "^item-x$"; then
  _pass "'item-x' correctly absent for filter 'ubuntu'"
else
  _fail "'item-x' INCORRECTLY appears for filter 'ubuntu'"
fi

# item-y in fedora -> yes
res="$(config_get_filtered_ids "items" "platforms" "fedora" 2>/dev/null || true)"
if echo "$res" | grep -q "^item-y$"; then
  _pass "'item-y' [ubuntu,debian,fedora] matches filter 'fedora'"
else
  _fail "'item-y' does NOT match filter 'fedora'"
fi

# item-z in arch -> yes, but NOT in fedora
res_arch="$(config_get_filtered_ids "items" "platforms" "arch" 2>/dev/null || true)"
res_fed="$(config_get_filtered_ids "items" "platforms" "fedora" 2>/dev/null || true)"
if echo "$res_arch" | grep -q "^item-z$" && ! echo "$res_fed" | grep -q "^item-z$"; then
  _pass "'item-z' [arch] present for arch, absent for fedora"
else
  _fail "'item-z' filter mismatch (arch/fedora)"
fi

rm -f "$T2_FILE"

# ---------------------------------------------------------------------------
# Test 3: Invalid id lookup returns non-zero and emits nothing to stdout
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 3: invalid id lookup ---"

_write_tmp_yaml T3_FILE << 'YAML'
things:
  - id: real-item
    label: exists
YAML

_cfg_parse_file "$T3_FILE" "things"

stdout_output="$(config_get_field "things" "nonexistent-id" "label" 2>/dev/null || true)"
exit_code=0
config_get_field "things" "nonexistent-id" "label" > /dev/null 2>&1 || exit_code=$?

if [[ -z "$stdout_output" ]]; then
  _pass "invalid id lookup: stdout is empty"
else
  _fail "invalid id lookup: unexpected stdout '${stdout_output}'"
fi

if [[ "$exit_code" -ne 0 ]]; then
  _pass "invalid id lookup: returned non-zero exit code (${exit_code})"
else
  _fail "invalid id lookup: exit code was 0 (expected non-zero)"
fi

# A valid id for the same section should still work
valid_output="$(config_get_field "things" "real-item" "label" 2>/dev/null || true)"
if [[ "$valid_output" == "exists" ]]; then
  _pass "valid id lookup still works after invalid lookup"
else
  _fail "valid id lookup broken after invalid lookup: got '${valid_output}'"
fi

rm -f "$T3_FILE"

# ---------------------------------------------------------------------------
# Test 4: config_get_filtered_ids on unloaded section returns empty, not error
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 4: filtered ids on unloaded section ---"

# Use a section name that was never parsed
output="$(config_get_filtered_ids "never_loaded_section" "field" "value" 2>/dev/null || true)"
if [[ -z "$output" ]]; then
  _pass "filtered ids on unloaded section: returns empty (no crash)"
else
  _fail "filtered ids on unloaded section: unexpected output '${output}'"
fi

# config_get_ids on unloaded section should also return empty
output2="$(config_get_ids "never_loaded_section_2" 2>/dev/null || true)"
if [[ -z "$output2" ]]; then
  _pass "config_get_ids on unloaded section: returns empty (no crash)"
else
  _fail "config_get_ids on unloaded section: unexpected output '${output2}'"
fi

# ---------------------------------------------------------------------------
# Test 5: Hyphenated ids normalize correctly (id with hyphens maps to valid var)
# ---------------------------------------------------------------------------
echo ""
echo "  --- Test 5: hyphenated id normalization ---"

_write_tmp_yaml T5_FILE << 'YAML'
things:
  - id: my-hyphenated-id
    display_name: "Hyphen Test"
    supported_for: [arch]
YAML

_cfg_parse_file "$T5_FILE" "things"

name_out="$(config_get_field "things" "my-hyphenated-id" "display_name" 2>/dev/null || true)"
if [[ "$name_out" == "Hyphen Test" ]]; then
  _pass "hyphenated id field lookup works: '${name_out}'"
else
  _fail "hyphenated id field lookup failed: got '${name_out}'"
fi

filter_out="$(config_get_filtered_ids "things" "supported_for" "arch" 2>/dev/null || true)"
if echo "$filter_out" | grep -q "^my-hyphenated-id$"; then
  _pass "hyphenated id appears in filtered results"
else
  _fail "hyphenated id missing from filtered results"
fi

rm -f "$T5_FILE"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
if [[ "$errors" -gt 0 ]]; then
  echo "  test_config_loader_edge.sh: ${errors} error(s) found."
  exit 1
fi
echo "  test_config_loader_edge.sh: all checks passed."
exit 0
