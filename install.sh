#!/bin/bash

# Error handling
set -euo pipefail
IFS=$'\n\t'

source ./env.sh

# Imports
source $ROOT_DIR/core/managers/packageManager.sh
source $ROOT_DIR/core/utilities/banner.sh
source $ROOT_DIR/core/utilities/logger.sh
source $ROOT_DIR/core/utilities/translator.sh

# check sudo permission
if [[ $EUID -eq 0 ]]; then
    log ERROR "$(get_translation script_should_be_executed_without_sudo_permission)"
    exit 1
fi

# Check if terminal is running in kitty
if [ -z "${KITTY_WINDOW_ID:-}" ]; then
    # Is kitty installed?
    if ! command -v kitty &> /dev/null; then
        log PACKAGE_INFO "$(get_translation kitty_is_not_found)"
        if ! install_initial_dependencies kitty; then
            log PACKAGE_WARNING "$(get_translation kitty_installation_failed)"
        fi
    fi

    # Check is kitty installed successfully
    if command -v kitty &> /dev/null; then
        log INFO "$(get_translation script_restarting_with_kitty)"
        SCRIPT_PATH="$(realpath "$0")"
        SCRIPT_DIR="$(dirname "$SCRIPT_PATH") "

        # Run the script in kitty terminal
        kitty bash --login -i -c "cd \"$SCRIPT_DIR\" && bash \"$SCRIPT_PATH\"; echo; read -p 'Press any button...'" 2>/dev/null

        # Close existing terminal
        exit 0
    fi
fi