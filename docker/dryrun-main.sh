#!/usr/bin/env bash
# docker/dryrun-main.sh - Non-interactive dry-run validation of main.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

pass=0
fail=0
results=()

# Test matrix: "distro:pm:de"
TEST_MATRIX=(
    "arch:pacman:hyprland"
    "arch:pacman:kde"
    "arch:pacman:gnome"
    "ubuntu:apt:kde"
    "ubuntu:apt:gnome"
    "fedora:dnf:hyprland"
    "fedora:dnf:kde"
    "fedora:dnf:gnome"
)

run_combo() {
    local distro="$1" pm="$2" de="$3"
    export HYUNARCH_DISTRO="$distro"
    export HYUNARCH_PM="$pm"
    export HYUNARCH_DE="$de"
    export HYUNARCH_NON_INTERACTIVE="1"
    export HYUNARCH_DRY_RUN="1"

    if bash "${PROJECT_ROOT}/main.sh" --dry-run > "/tmp/hyunarch-dryrun-${distro}-${pm}-${de}.log" 2>&1; then
        echo "  PASS: ${distro}/${pm}/${de}"
        (( pass++ )) || true
        results+=("PASS | ${distro} | ${pm} | ${de}")
    else
        echo "  FAIL: ${distro}/${pm}/${de}"
        cat "/tmp/hyunarch-dryrun-${distro}-${pm}-${de}.log"
        (( fail++ )) || true
        results+=("FAIL | ${distro} | ${pm} | ${de}")
    fi
}

echo "=== Hyunarch main.sh dry-run validation ==="
echo ""

for combo in "${TEST_MATRIX[@]}"; do
    IFS=':' read -r d p e <<< "$combo"
    run_combo "$d" "$p" "$e"
done

echo ""
echo "=== Results ==="
printf "%-6s | %-8s | %-8s | %-10s\n" "Status" "Distro" "PM" "DE"
printf '%s\n' "-------+----------+----------+------------"
for r in "${results[@]}"; do
    IFS='|' read -r status d p e <<< "$r"
    printf "%-6s | %-8s | %-8s | %-10s\n" "${status// /}" "${d// /}" "${p// /}" "${e// /}"
done
echo ""
echo "Passed: ${pass} / Failed: ${fail}"
echo ""

[[ "$fail" -eq 0 ]]
