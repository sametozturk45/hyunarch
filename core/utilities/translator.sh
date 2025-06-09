#!/bin/bash

# Return to the script's directory
cd "$(dirname "$(realpath "$0")")"

source ./core/utilities/logger.sh

get_translation() {
    local key="$1"

    if ! command -v jq &> /dev/null; then
        echo "$key"
        return 1
    fi

    if [ -z "$key" ]; then
        log ERROR "Key is not defined!"
        return 1
    fi

    if [ ! -f "scriptConfig.json" ]; then
        log ERROR "scriptConfig.json can't find!"
        return 1
    fi

    local lang
    lang=$(jq -r '.language' scriptConfig.json)

    if [ -z "$lang" ] || [ "$lang" == "null" ]; then
        log ERROR "Can't take any language data!"
        return 1
    fi

    local translation_file="assets/translations/${lang}.json"

    if [ ! -f "$translation_file" ]; then
        log ERROR "Can't find translation file: $translation_file"
        return 1
    fi

    local value
    value=$(jq -r --arg key "$key" '.[$key]' "$translation_file")

    if [ "$value" == "null" ]; then
        log WARNING "Key is not defined: $key"
        return 1
    fi

    echo "$value"
}
