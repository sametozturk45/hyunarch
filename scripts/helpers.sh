#!/bin/bash

GROUP_FILE="./data/group-map.json"
CONFIG_MAP="./data/config-map.json"

get_config_info() {
  local pkg="$1"
  jq -r --arg pkg "$pkg" '
    to_entries[] | .value[] | select(.PackageName == $pkg) | 
    "\(.ConfigPath)|\(.SystemPath)"' "$CONFIG_MAP"
}
