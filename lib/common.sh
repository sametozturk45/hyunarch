#!/usr/bin/env bash
# lib/common.sh -- Core bootstrapping, path exports, and utility functions.
# Sourced by main.sh after HYUNARCH_ROOT is set.

set -euo pipefail

# ---------------------------------------------------------------------------
# HYUNARCH_ROOT must be set by the caller (main.sh) before sourcing this file.
# ---------------------------------------------------------------------------
if [[ -z "${HYUNARCH_ROOT:-}" ]]; then
  echo "[common.sh] FATAL: HYUNARCH_ROOT is not set. Source this file from main.sh only." >&2
  exit 1
fi

# Derived path exports
export HYUNARCH_LIB="${HYUNARCH_ROOT}/lib"
export HYUNARCH_CONFIGS="${HYUNARCH_ROOT}/configs"
export HYUNARCH_SCRIPTS="${HYUNARCH_ROOT}/scripts"

# Runtime flags (callers may pre-set these before sourcing)
export HYUNARCH_DRY_RUN="${HYUNARCH_DRY_RUN:-}"
export HYUNARCH_VERBOSE="${HYUNARCH_VERBOSE:-}"

# ---------------------------------------------------------------------------
# die() -- print message to stderr and exit with code 1
# Usage: die "message"
# ---------------------------------------------------------------------------
die() {
  echo "[FATAL] $*" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# require_command() -- assert a command exists on PATH
# Usage: require_command curl
# ---------------------------------------------------------------------------
require_command() {
  local cmd="${1:?require_command: missing argument}"
  if ! command -v "$cmd" > /dev/null 2>&1; then
    die "Required command not found: ${cmd}"
  fi
}

# ---------------------------------------------------------------------------
# require_file() -- assert a file exists and is readable
# Usage: require_file /path/to/file
# ---------------------------------------------------------------------------
require_file() {
  local path="${1:?require_file: missing argument}"
  if [[ ! -f "$path" ]]; then
    die "Required file not found: ${path}"
  fi
  if [[ ! -r "$path" ]]; then
    die "Required file is not readable: ${path}"
  fi
}

# ---------------------------------------------------------------------------
# is_dry_run() -- returns 0 (true) when HYUNARCH_DRY_RUN is non-empty
# ---------------------------------------------------------------------------
is_dry_run() {
  [[ -n "${HYUNARCH_DRY_RUN:-}" ]]
}

# ---------------------------------------------------------------------------
# hyunarch_source() -- safely source a lib/ module with error checking
# Usage: hyunarch_source logging.sh
# ---------------------------------------------------------------------------
hyunarch_source() {
  local module="${1:?hyunarch_source: missing module name}"
  local module_path="${HYUNARCH_LIB}/${module}"

  if [[ ! -f "$module_path" ]]; then
    die "Module not found: ${module_path}"
  fi
  if [[ ! -r "$module_path" ]]; then
    die "Module not readable: ${module_path}"
  fi

  # shellcheck disable=SC1090
  source "$module_path"
}
