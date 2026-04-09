#!/usr/bin/env bash
# lib/config_loader.sh -- Pure-Bash YAML parser for Hyunarch config files.
#
# Parsing strategy:
#   - Read line by line.
#   - Detect top-level section via "key:" at start of line.
#   - Detect new item via "  - id: <value>".
#   - Extract key-value pairs from indented fields.
#   - Strip inline list brackets and quotes; store as comma-separated strings.
#
# Variable naming convention:
#   _CFG_<SECTION>_<ID>_<FIELD>   (uppercase; hyphens replaced by underscores)
#   _CFG_<SECTION>_IDS            (global array of known ids in that section)
#
# apps.yaml has two sections: categories and apps -- each tracked separately.

set -euo pipefail

# ---------------------------------------------------------------------------
# _cfg_normalize_key() -- uppercase and replace hyphens with underscores
# ---------------------------------------------------------------------------
_cfg_normalize_key() {
  local raw="${1:-}"
  # tr is external but universally available; keeps this portable on Linux
  echo "${raw}" | tr '[:lower:]' '[:upper:]' | tr '-' '_'
}

# ---------------------------------------------------------------------------
# _cfg_strip_value() -- remove surrounding quotes, inline list brackets,
#                       trailing comments, and leading/trailing whitespace.
# ---------------------------------------------------------------------------
_cfg_strip_value() {
  local v="$1"
  # Remove leading whitespace
  v="${v#"${v%%[! ]*}"}"
  # Remove trailing whitespace
  v="${v%"${v##*[! ]}"}"
  # Remove surrounding double-quotes
  v="${v#\"}"
  v="${v%\"}"
  # Remove surrounding single-quotes
  v="${v#\'}"
  v="${v%\'}"
  # Remove inline list brackets: [a, b, c] -> a, b, c
  if [[ "$v" == "["*"]" ]]; then
    v="${v#[}"
    v="${v%]}"
  fi
  # Strip spaces around commas to get clean "a,b,c" form
  # Also strip any internal quotes around list items
  v="${v//\"/}"
  v="${v//\'/}"
  v="${v// , /,}"
  v="${v//, /,}"
  v="${v//, /,}"   # second pass catches trailing spaces
  v="${v// ,/,}"
  # Final trim
  v="${v#"${v%%[! ]*}"}"
  v="${v%"${v##*[! ]}"}"
  echo "$v"
}

# ---------------------------------------------------------------------------
# _cfg_parse_file() -- generic parser
# Args: yaml_file  section_name  [extra_section_name ...]
#
# Populates global variables following the naming convention.
# The "section_name" argument controls which top-level YAML key to parse.
# Supports a single optional second top-level section (for apps.yaml).
# ---------------------------------------------------------------------------
_cfg_parse_file() {
  local yaml_file="$1"
  shift
  local primary_section="$1"
  shift
  local extra_section="${1:-}"

  require_file "$yaml_file"

  local current_section=""
  local current_id=""
  local current_id_norm=""

  # Declare the id-index arrays dynamically
  local section_norm
  section_norm="$(_cfg_normalize_key "$primary_section")"
  # shellcheck disable=SC2086
  eval "declare -ga _CFG_${section_norm}_IDS=()"

  if [[ -n "$extra_section" ]]; then
    local extra_section_norm
    extra_section_norm="$(_cfg_normalize_key "$extra_section")"
    # shellcheck disable=SC2086
    eval "declare -ga _CFG_${extra_section_norm}_IDS=()"
  fi

  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and comment-only lines
    [[ -z "$line" ]] && continue
    [[ "$line" =~ ^[[:space:]]*# ]] && continue

    # -----------------------------------------------------------------------
    # Detect top-level section change: "key:" at column 0 with no leading space
    # -----------------------------------------------------------------------
    if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_-]*):([[:space:]]*)$ ]]; then
      current_section="${BASH_REMATCH[1]}"
      current_id=""
      current_id_norm=""
      log_debug "config_loader: entering section '${current_section}'"
      continue
    fi

    # Only process lines that belong to a known section
    if [[ "$current_section" != "$primary_section" ]] && \
       [[ -z "$extra_section" || "$current_section" != "$extra_section" ]]; then
      continue
    fi

    # -----------------------------------------------------------------------
    # Detect new item start: "  - id: <value>"
    # -----------------------------------------------------------------------
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
      local raw_id
      raw_id="$(_cfg_strip_value "${BASH_REMATCH[1]}")"
      current_id="$raw_id"
      current_id_norm="$(_cfg_normalize_key "$raw_id")"

      # Register the id in the correct section's index array
      local sec_to_use="$current_section"
      local sec_norm_to_use
      sec_norm_to_use="$(_cfg_normalize_key "$sec_to_use")"

      # Append to the index array
      eval "_CFG_${sec_norm_to_use}_IDS+=(\"\$current_id\")"
      log_debug "config_loader: new item id='${current_id}' in section='${sec_to_use}'"
      continue
    fi

    # -----------------------------------------------------------------------
    # Detect field line: "    key: value" (two or more spaces of indentation)
    # Must have a current_id to attach to.
    # -----------------------------------------------------------------------
    if [[ -n "$current_id" ]] && \
       [[ "$line" =~ ^[[:space:]]{2,}([a-zA-Z_][a-zA-Z0-9_-]*):[[:space:]]*(.*) ]]; then
      local field_raw="${BASH_REMATCH[1]}"
      local value_raw="${BASH_REMATCH[2]}"

      # Skip lines that are sub-list items under a field (they start with "- ")
      if [[ "$field_raw" == "-" ]]; then
        continue
      fi

      local field_norm
      field_norm="$(_cfg_normalize_key "$field_raw")"
      local value
      value="$(_cfg_strip_value "$value_raw")"

      local sec_norm
      sec_norm="$(_cfg_normalize_key "$current_section")"
      local var_name="_CFG_${sec_norm}_${current_id_norm}_${field_norm}"

      # Guard: variable name must be safe (no special characters from untrusted config)
      if [[ ! "$var_name" =~ ^[A-Z0-9_]+$ ]]; then
        log_warn "config_loader: skipping unsafe variable name '${var_name}'"
        continue
      fi

      printf -v "$var_name" '%s' "$value"
      log_debug "config_loader: set ${var_name}='${value}'"
      continue
    fi

    # -----------------------------------------------------------------------
    # Handle inline list items under a "scripts:" field in presets.yaml
    # They look like:  - "scripts/presets/foo.sh"
    # Append to the existing variable for the field "SCRIPTS".
    # -----------------------------------------------------------------------
    if [[ -n "$current_id" ]] && \
       [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
      local item_raw="${BASH_REMATCH[1]}"
      local item_val
      item_val="$(_cfg_strip_value "$item_raw")"

      # We only handle the scripts sub-list -- append to SCRIPTS field
      local sec_norm
      sec_norm="$(_cfg_normalize_key "$current_section")"
      local var_name="_CFG_${sec_norm}_${current_id_norm}_SCRIPTS"

      if [[ ! "$var_name" =~ ^[A-Z0-9_]+$ ]]; then
        continue
      fi

      local existing="${!var_name:-}"
      if [[ -z "$existing" ]]; then
        printf -v "$var_name" '%s' "$item_val"
      else
        printf -v "$var_name" '%s' "${existing},${item_val}"
      fi
      log_debug "config_loader: appended to ${var_name}='${!var_name}'"
    fi

  done < "$yaml_file"
}

# ---------------------------------------------------------------------------
# Public load functions
# ---------------------------------------------------------------------------

config_load_distros() {
  log_debug "config_loader: loading distros.yaml"
  _cfg_parse_file "${HYUNARCH_CONFIGS}/distros.yaml" "distros"
}

config_load_desktops() {
  log_debug "config_loader: loading desktops.yaml"
  _cfg_parse_file "${HYUNARCH_CONFIGS}/desktops.yaml" "desktops"
}

config_load_presets() {
  log_debug "config_loader: loading presets.yaml"
  _cfg_parse_file "${HYUNARCH_CONFIGS}/presets.yaml" "presets"
}

config_load_themes() {
  log_debug "config_loader: loading themes.yaml"
  _cfg_parse_file "${HYUNARCH_CONFIGS}/themes.yaml" "themes"
}

config_load_apps() {
  log_debug "config_loader: loading apps.yaml (categories + apps)"
  _cfg_parse_file "${HYUNARCH_CONFIGS}/apps.yaml" "categories" "apps"
}

# ---------------------------------------------------------------------------
# config_get_ids() -- return the ids for a section (space-separated on stdout)
# Args: section_name
# ---------------------------------------------------------------------------
config_get_ids() {
  local section="${1:?config_get_ids: missing section argument}"
  local section_norm
  section_norm="$(_cfg_normalize_key "$section")"
  local array_name="_CFG_${section_norm}_IDS"

  # Check the array exists and has elements
  local arr_ref="${array_name}[@]"
  if ! declare -p "$array_name" > /dev/null 2>&1; then
    log_warn "config_get_ids: section '${section}' not loaded or empty"
    return 0
  fi

  local item
  for item in "${!arr_ref}"; do
    echo "$item"
  done
}

# ---------------------------------------------------------------------------
# config_get_field() -- return a single field value for a given (section, id)
# Args: section  id  field
# Prints value to stdout; returns 1 when not found.
# ---------------------------------------------------------------------------
config_get_field() {
  local section="${1:?config_get_field: missing section}"
  local id="${2:?config_get_field: missing id}"
  local field="${3:?config_get_field: missing field}"

  local section_norm id_norm field_norm
  section_norm="$(_cfg_normalize_key "$section")"
  id_norm="$(_cfg_normalize_key "$id")"
  field_norm="$(_cfg_normalize_key "$field")"

  local var_name="_CFG_${section_norm}_${id_norm}_${field_norm}"

  if ! declare -p "$var_name" > /dev/null 2>&1; then
    log_debug "config_get_field: variable not found: ${var_name}"
    return 1
  fi

  echo "${!var_name}"
}

# ---------------------------------------------------------------------------
# config_get_filtered_ids() -- return ids where a comma-separated field
#                              contains filter_value (or "all" keyword).
# Args: section  field  filter_value
# Prints matching ids to stdout (one per line).
# ---------------------------------------------------------------------------
config_get_filtered_ids() {
  local section="${1:?config_get_filtered_ids: missing section}"
  local field="${2:?config_get_filtered_ids: missing field}"
  local filter_value="${3:?config_get_filtered_ids: missing filter_value}"

  local section_norm
  section_norm="$(_cfg_normalize_key "$section")"
  local array_name="_CFG_${section_norm}_IDS"

  if ! declare -p "$array_name" > /dev/null 2>&1; then
    log_warn "config_get_filtered_ids: section '${section}' not loaded"
    return 0
  fi

  local arr_ref="${array_name}[@]"
  local id
  for id in "${!arr_ref}"; do
    local field_value
    field_value="$(config_get_field "$section" "$id" "$field" 2>/dev/null || true)"

    if [[ -z "$field_value" ]]; then
      continue
    fi

    # "all" keyword matches every filter_value
    if _cfg_list_contains "$field_value" "all"; then
      echo "$id"
      continue
    fi

    # Check if filter_value appears in the comma-separated field
    if _cfg_list_contains "$field_value" "$filter_value"; then
      echo "$id"
    fi
  done
}

# ---------------------------------------------------------------------------
# _cfg_list_contains() -- check if a comma-separated list contains a value
# Args: list_string  value
# Returns 0 if found, 1 if not.
# ---------------------------------------------------------------------------
_cfg_list_contains() {
  local list="$1"
  local needle="$2"

  # Normalize: strip spaces around commas
  list="${list//", "/","}"
  list="${list//" ,"/","}"

  local IFS=','
  local item
  for item in $list; do
    # Strip any remaining whitespace from each item
    item="${item#"${item%%[! ]*}"}"
    item="${item%"${item##*[! ]}"}"
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}
