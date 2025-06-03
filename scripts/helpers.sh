#!/bin/bash

DEPS_FILE="./data/dependencies.json"
APP_CONFIG="./data/appconfig.json"

get_config_info() {
    local pkg="$1"
    local config_info
    
    # appconfig.json'dan direkt olarak yapılandırma bilgisini al
    config_info=$(jq -r --arg pkg "$pkg" '.[$pkg] | "\(.ConfigPath)|\(.SystemPath)"' "$APP_CONFIG")
    
    if [[ "$config_info" == "|" || "$config_info" == "null|null" ]]; then
        echo ""
    else
        echo "$config_info"
    fi
}

get_package_info() {
    local pkg="$1"
    local group="$2"
    
    # dependencies.json'dan paket bilgisini al
    jq -r --arg pkg "$pkg" --arg group "$group" \
        '.[$group][] | select(.PackageName == $pkg) | "\(.DisplayName)|\(.Description)"' "$DEPS_FILE"
}

get_group_packages() {
    local group="$1"
    
    # Belirli bir gruptaki tüm paketleri listele
    jq -r --arg group "$group" '.[$group][] | .PackageName' "$DEPS_FILE"
}

list_groups() {
    # Tüm grupları listele
    jq -r 'keys[]' "$DEPS_FILE"
}
