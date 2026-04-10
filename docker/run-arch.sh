#!/usr/bin/env bash
# docker/run-arch.sh - Open interactive Arch Linux shell
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export MSYS_NO_PATHCONV=1

echo "Building hyunarch-test-arch (if needed)..."
docker build -f "${PROJECT_ROOT}/docker/Dockerfile.arch" \
    -t "hyunarch-test-arch" \
    "${PROJECT_ROOT}"

echo "Opening interactive shell in Arch Linux container..."
echo "Project mounted at /hyunarch (read-write)"
echo ""
docker run --rm -it \
    -v "${PROJECT_ROOT}:/hyunarch" \
    "hyunarch-test-arch" \
    bash
