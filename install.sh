#!/bin/bash

# Error handling
set -euo pipefail
IFS=$'\n\t'

# Imports
source ./core/managers/packageManager.sh
source ./core/utilities/banner.sh
source ./core/utilities/logger.sh
source ./core/utilities/translator.sh

# Check if terminal is running in kitty
if [ -z "${KITTY_WINDOW_ID:-}" ]; then
    # Is kitty installed?
    if ! command -v kitty &> /dev/null; then
        echo "kitty terminali bulunamadı, kuruluyor..."
        if ! install_package kitty; then
            echo "⚠️  Kitty kurulumu başarısız, en iyi deneyim için kitty'i kurup scripti kitty üzerinden başlatmanız tavsiye edilir."
        fi
    fi

    # Check is kitty installed successfully
    if command -v kitty &> /dev/null; then
        echo "Kitty terminali ile yeniden başlatılıyor..."
        SCRIPT_PATH="$(realpath "$0")"
        SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

        # Run the script in kitty terminal
        kitty bash --login -i -c "cd \"$SCRIPT_DIR\" && bash \"$SCRIPT_PATH\"; echo; read -p 'Çıkmak için Enter tuşuna basın...'" 2>/dev/null

        # Close existing terminal
        exit 0
    fi
fi

show_banner