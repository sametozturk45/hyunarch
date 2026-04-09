#!/usr/bin/env bash
# tests/run_all.sh -- Discover and run all test_*.sh files under tests/
# Prints a pass/fail summary at the end.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pass_count=0
fail_count=0
failed_tests=()

echo ""
echo "================================================================"
echo "  Hyunarch Test Suite"
echo "================================================================"
echo ""

# Find all test files, sorted
while IFS= read -r test_file; do
  [[ -z "$test_file" ]] && continue
  [[ ! -f "$test_file" ]] && continue

  test_name="$(basename "$test_file")"
  echo "  Running: ${test_name}"
  echo "  ──────────────────────────────────────────────────────────"

  set +e
  bash "$test_file"
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo "  [PASS] ${test_name}"
    (( pass_count++ )) || true
  else
    echo "  [FAIL] ${test_name} (exit code ${rc})"
    (( fail_count++ )) || true
    failed_tests+=("$test_name")
  fi
  echo ""
done < <(find "$SCRIPT_DIR" -name "test_*.sh" | sort)

echo "================================================================"
echo "  Results: ${pass_count} passed, ${fail_count} failed"
echo "================================================================"

if [[ "${#failed_tests[@]}" -gt 0 ]]; then
  echo ""
  echo "  Failed tests:"
  for t in "${failed_tests[@]}"; do
    echo "    - ${t}"
  done
  echo ""
  exit 1
fi

echo ""
exit 0
