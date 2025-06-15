#!/bin/bash

source ./../../env.sh

# Imports
source $ROOT_DIR/core/utilities/logger.sh
source $ROOT_DIR/core/utilities/translator.sh

# Function to install packages using the specified package manager
# Usage: install_packages <package_manager> <package1> <package2> ...
install_packages(){
    # Check if a package manager is specified
    if [ -z "$1" ]; then
        log ERROR "$(get_translation no_package_manager_specified)"
        return 1
    fi
    
    # Check if the package manager is installed
    if ! command -v "$1" &> /dev/null; then
        log ERROR "$(get_translation package_manager_not_installed): $1"
        return 1
    fi

    # Select the package manager and install the packages
    # Shift the arguments to get the package names
    local package_manager="$1"
    shift
    
    case "$package_manager" in
        apt)
        sudo apt update && sudo apt install -y "$@"
        ;;
        yay)
        yay -S --noconfirm "$@"
        ;;
        yum)
        sudo yum install -y "$@"
        ;;
        dnf)
        sudo dnf install -y "$@"
        ;;
        pacman)
        sudo pacman -S --noconfirm "$@"
        ;;
        brew)
        brew install "$@"
        ;;
        *)
        log ERROR "$(get_translation unsupported_package_manager): $package_manager"
        return 1
        ;;
    esac
}

# Function to install a package using a custom script block
# Usage: custom_package_installer <script_block>
custom_package_installer(){
    local script_block="$1"
    shift

    if [ -z "$script_block" ]; then
        log WARNING "$(get_translation no_package_installation_command_provided)"
        return 1
    fi

    eval "$script_block"
}

# Function to install initial dependencies
# Usage: install_initial_dependencies <package>
install_initial_dependencies() {
    local package="$1"

    if [ -z "$package" ]; then
        log ERROR "$(get_translation no_package_provided)"
        return 1
    fi

    if command -v "$package" &> /dev/null; then
        log PACKAGE_INFO "$package $(get_translation package_already_installed)"
        return 0
    fi

    local PM=""
    for cmd in yay pacman apt dnf zypper xbps-install emerge apk; do
        if command -v "$cmd" &> /dev/null; then
            PM="$cmd"
            break
        fi
    done

    if [ -z "$PM" ]; then
        log ERROR "$(get_translation package_manager_not_found)"
        return 1
    fi

    case "$PM" in
        yay) yay -S --noconfirm "$package" ;;
        pacman) sudo pacman -Sy --noconfirm "$package" ;;
        apt) sudo apt update && sudo apt install -y "$package" ;;
        dnf) sudo dnf install -y "$package" ;;
        zypper) sudo zypper install -y "$package" ;;
        xbps-install) sudo xbps-install -Sy "$package" ;;
        emerge) sudo emerge "$package" ;;
        apk) sudo apk add "$package" ;;
        *)
            log ERROR "$(get_translation unknown_package_manager): $PM"
            return 1
            ;;
    esac

    if command -v "$package" &> /dev/null; then
        log PACKAGE_SUCCESS "$package $(get_translation package_installation_successful)"
    else
        log PACKAGE_ERROR "$package $(get_translation package_installation_failed)"
    fi
}