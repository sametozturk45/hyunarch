#!/bin/bash

# Return to the script's directory
source "$(dirname "${BASH_SOURCE[0]}")/../../env.sh"

source $ROOT_DIR/core/utilities/logger.sh

get_translation() {
    local key="$1"

    if ! command -v jq &> /dev/null; then
        echo "$key"
        return 1
    fi

    if [ -z "$key" ]; then
        log ERROR "$(get_translation key_not_found)"
        return 1
    fi

    if [ ! -f "scriptConfig.json" ]; then
        log ERROR "$(get_translation script_config_not_found)"
        return 1
    fi

    local lang
    lang=$(jq -r '.language' scriptConfig.json)

    if [ -z "$lang" ] || [ "$lang" == "null" ]; then
        log ERROR "$(get_translation cant_take_any_language_data)"
        return 1
    fi

    local translation_file="$ROOT_DIR/assets/translations/${lang}.json"

    if [ ! -f "$translation_file" ]; then
        log ERROR "$(get_translation cant_find_translation_file): $translation_file"
        return 1
    fi

    local value
    value=$(jq -r --arg key "$key" '.[$key]' "$translation_file")

    if [ "$value" == "null" ]; then
        log WARNING "$(get_translation translation_key_not_found): $key"
        return 1
    fi

    echo "$value"
}
