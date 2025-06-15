#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/../../env.sh"

log() {
    local type="$1"
    shift
    local message="$*"
    local timestamp="$(date '+%d.%m.%Y %H:%M:%S')"

    # Renk kodları
    local RESET='\033[0m'
    local RED='\033[0;31m'
    local YELLOW='\033[0;33m'
    local BLUE='\033[0;34m'
    local GREEN='\033[0;32m'
    local MAGENTA='\033[0;35m'
    local CYAN='\033[0;36m'

    case "$type" in
        ERROR)
            echo -e "${RED}[${timestamp}] ❌ $message${RESET}"
            ;;
        WARNING)
            echo -e "${YELLOW}[${timestamp}] ⚠️  $message${RESET}"
            ;;
        INFO)
            echo -e "${BLUE}[${timestamp}] ℹ️  $message${RESET}"
            ;;
        SUCCESS)
            echo -e "${GREEN}[${timestamp}] ✅ $message${RESET}"
            ;;
        PACKAGE_ERROR)
            echo -e "${MAGENTA}[${timestamp}] 📦❌ $message${RESET}"
            ;;
        PACKAGE_INFO)
            echo -e "${CYAN}[${timestamp}] 📦ℹ️  $message${RESET}"
            ;;
        PACKAGE_SUCCESS)
            echo -e "${GREEN}[${timestamp}] 📦✅ $message${RESET}"
            ;;
        PACKAGE_WARNING)
            echo -e "${YELLOW}[${timestamp}] 📦⚠️ $message${RESET}"
            ;;
        *)
            echo -e "[${timestamp}] $message"
            ;;
    esac
}

