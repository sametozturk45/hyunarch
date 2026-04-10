#!/usr/bin/env bash
# docker/test-all.sh - Run full test suite on all target distros
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export MSYS_NO_PATHCONV=1

DISTROS=(arch ubuntu fedora)

declare -A RESULTS_TESTS
declare -A RESULTS_SHELLCHECK
declare -A RESULTS_DRYRUN

run_step() {
    local label="$1" distro="$2"
    shift 2
    echo ""
    echo "--- [${distro}] ${label} ---"
    if "$@"; then
        echo "  OK: ${label}"
        return 0
    else
        echo "  FAILED: ${label}"
        return 1
    fi
}

overall_exit=0

for distro in "${DISTROS[@]}"; do
    echo ""
    echo "================================================"
    echo " Building: hyunarch-test-${distro}"
    echo "================================================"

    docker build -f "${PROJECT_ROOT}/docker/Dockerfile.${distro}" \
        -t "hyunarch-test-${distro}" \
        "${PROJECT_ROOT}"

    # Tests
    if run_step "Test Suite" "$distro" \
        docker run --rm \
            -v "${PROJECT_ROOT}:/hyunarch:ro" \
            -e HYUNARCH_DRY_RUN=1 \
            "hyunarch-test-${distro}" \
            bash /hyunarch/tests/run_all.sh; then
        RESULTS_TESTS[$distro]="PASS"
    else
        RESULTS_TESTS[$distro]="FAIL"
        overall_exit=1
    fi

    # Shellcheck
    if run_step "ShellCheck" "$distro" \
        docker run --rm \
            -v "${PROJECT_ROOT}:/hyunarch:ro" \
            "hyunarch-test-${distro}" \
            bash -c "shellcheck --severity=error /hyunarch/lib/*.sh /hyunarch/main.sh /hyunarch/docker/*.sh /hyunarch/tests/run_all.sh"; then
        RESULTS_SHELLCHECK[$distro]="PASS"
    else
        RESULTS_SHELLCHECK[$distro]="FAIL"
        overall_exit=1
    fi

    # Dry-run main.sh
    if run_step "Dry-run main.sh" "$distro" \
        docker run --rm \
            -v "${PROJECT_ROOT}:/hyunarch:ro" \
            -e HYUNARCH_DRY_RUN=1 \
            "hyunarch-test-${distro}" \
            bash /hyunarch/docker/dryrun-main.sh; then
        RESULTS_DRYRUN[$distro]="PASS"
    else
        RESULTS_DRYRUN[$distro]="FAIL"
        overall_exit=1
    fi
done

echo ""
echo "================================================"
echo " SUMMARY"
echo "================================================"
printf "%-10s | %-12s | %-12s | %-12s\n" "Distro" "Tests" "ShellCheck" "Dry-run"
printf '%s\n' "-----------+--------------+--------------+--------------"
for distro in "${DISTROS[@]}"; do
    printf "%-10s | %-12s | %-12s | %-12s\n" \
        "$distro" \
        "${RESULTS_TESTS[$distro]:-N/A}" \
        "${RESULTS_SHELLCHECK[$distro]:-N/A}" \
        "${RESULTS_DRYRUN[$distro]:-N/A}"
done
echo ""

exit "$overall_exit"
