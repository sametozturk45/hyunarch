#!/usr/bin/env bash
# lib/logging.sh -- Structured logging with levels, timestamps, and ANSI color.
# Sourced after common.sh.

set -euo pipefail

# ---------------------------------------------------------------------------
# Internal state
# ---------------------------------------------------------------------------
_LOG_FILE=""
_LOG_USE_COLOR=""

# Detect whether the terminal supports color (stderr must be a tty)
_logging_detect_color() {
  if [[ -t 2 ]] && command -v tput > /dev/null 2>&1 && tput colors > /dev/null 2>&1; then
    local n_colors
    n_colors="$(tput colors 2>/dev/null || echo 0)"
    if [[ "$n_colors" -ge 8 ]]; then
      _LOG_USE_COLOR="1"
    fi
  fi
}

# ---------------------------------------------------------------------------
# log_init() -- create the session log file under /tmp
# ---------------------------------------------------------------------------
log_init() {
  local timestamp
  timestamp="$(date +%Y%m%d-%H%M%S)"
  _LOG_FILE="${HYUNARCH_LOG_FILE:-/tmp/hyunarch-${timestamp}.log}"

  # Create or truncate the log file
  if ! : > "$_LOG_FILE" 2>/dev/null; then
    echo "[logging.sh] WARNING: Cannot write to log file: ${_LOG_FILE}" >&2
    _LOG_FILE=""
  fi

  _logging_detect_color
}

# ---------------------------------------------------------------------------
# _log_write() -- internal: write a formatted log entry
# Args: level, message
# ---------------------------------------------------------------------------
_log_write() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local line="[${timestamp}] [${level}] ${message}"

  # Always write plain text to the log file when available
  if [[ -n "$_LOG_FILE" ]]; then
    echo "$line" >> "$_LOG_FILE"
  fi

  # Colored output to stderr when supported
  if [[ -n "$_LOG_USE_COLOR" ]]; then
    local color_reset
    color_reset="$(tput sgr0)"
    local color=""
    case "$level" in
      DEBUG) color="$(tput setaf 6)" ;;   # cyan
      INFO)  color="$(tput setaf 2)" ;;   # green
      WARN)  color="$(tput setaf 3)" ;;   # yellow
      ERROR) color="$(tput setaf 1)" ;;   # red
      *)     color="" ;;
    esac
    echo "${color}${line}${color_reset}" >&2
  else
    echo "$line" >&2
  fi
}

# ---------------------------------------------------------------------------
# Public log functions
# ---------------------------------------------------------------------------
log_debug() {
  [[ -n "${HYUNARCH_VERBOSE:-}" ]] || return 0
  _log_write "DEBUG" "$@"
}

log_info() {
  _log_write "INFO" "$@"
}

log_warn() {
  _log_write "WARN" "$@"
}

log_error() {
  _log_write "ERROR" "$@"
}

# ---------------------------------------------------------------------------
# log_section() -- print a visible section header to stderr
# ---------------------------------------------------------------------------
log_section() {
  local title="$*"
  local line="================================================================"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  local formatted="[${timestamp}] [SECTION] === ${title} ==="

  if [[ -n "$_LOG_FILE" ]]; then
    {
      echo "$line"
      echo "$formatted"
      echo "$line"
    } >> "$_LOG_FILE"
  fi

  if [[ -n "$_LOG_USE_COLOR" ]]; then
    local bold reset
    bold="$(tput bold)"
    reset="$(tput sgr0)"
    echo "" >&2
    echo "${bold}${line}${reset}" >&2
    echo "${bold}${formatted}${reset}" >&2
    echo "${bold}${line}${reset}" >&2
    echo "" >&2
  else
    echo "" >&2
    echo "$line" >&2
    echo "$formatted" >&2
    echo "$line" >&2
    echo "" >&2
  fi
}
