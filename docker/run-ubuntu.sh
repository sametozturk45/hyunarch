#!/usr/bin/env bash
# docker/run-ubuntu.sh - Open interactive Ubuntu shell
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

export MSYS_NO_PATHCONV=1

echo "Building hyunarch-test-ubuntu (if needed)..."
docker build -f "${PROJECT_ROOT}/docker/Dockerfile.ubuntu" \
    -t "hyunarch-test-ubuntu" \
    "${PROJECT_ROOT}"

echo "Opening interactive shell in Ubuntu container..."
echo "Project mounted at /hyunarch (read-write)"
echo ""
docker run --rm -it \
    -v "${PROJECT_ROOT}:/hyunarch" \
    "hyunarch-test-ubuntu" \
    bash
