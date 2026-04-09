#!/usr/bin/env bash
# lib/distro.sh -- Distro selection and validation.
# Depends on: config_loader.sh, ui.sh, logging.sh

set -euo pipefail

# HYUNARCH_DISTRO is set by distro_select() and exported for child scripts.
export HYUNARCH_DISTRO="${HYUNARCH_DISTRO:-}"

# ---------------------------------------------------------------------------
# distro_select() -- present distro list, set HYUNARCH_DISTRO
# ---------------------------------------------------------------------------
distro_select() {
  log_section "Distro Selection"

  config_load_distros

  # Build parallel arrays: ids and display names for the menu
  local ids=()
  local display_names=()
  local id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    local dn
    dn="$(config_get_field "distros" "$id" "display_name" 2>/dev/null || echo "$id")"
    ids+=("$id")
    display_names+=("$dn")
  done < <(config_get_ids "distros")

  if [[ "${#ids[@]}" -eq 0 ]]; then
    die "No distros found in configuration."
  fi

  local selected_name
  selected_name="$(ui_menu_single "Select your Linux distribution:" "${display_names[@]}")"

  # Map display_name back to id
  local i
  for (( i=0; i<${#display_names[@]}; i++ )); do
    if [[ "${display_names[$i]}" == "$selected_name" ]]; then
      HYUNARCH_DISTRO="${ids[$i]}"
      break
    fi
  done

  if [[ -z "$HYUNARCH_DISTRO" ]]; then
    die "distro_select: failed to resolve id for '${selected_name}'"
  fi

  export HYUNARCH_DISTRO
  log_info "Selected distro: ${HYUNARCH_DISTRO}"
  ui_info "Distro set to: $(distro_get_display_name "$HYUNARCH_DISTRO")"
}

# ---------------------------------------------------------------------------
# distro_get_display_name() -- print the display_name for a given distro id
# ---------------------------------------------------------------------------
distro_get_display_name() {
  local distro_id="${1:?distro_get_display_name: missing distro_id}"
  config_get_field "distros" "$distro_id" "display_name" 2>/dev/null || echo "$distro_id"
}

# ---------------------------------------------------------------------------
# distro_validate() -- verify HYUNARCH_DISTRO is a known id
# ---------------------------------------------------------------------------
distro_validate() {
  if [[ -z "${HYUNARCH_DISTRO:-}" ]]; then
    die "distro_validate: HYUNARCH_DISTRO is not set."
  fi

  local id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if [[ "$id" == "$HYUNARCH_DISTRO" ]]; then
      return 0
    fi
  done < <(config_get_ids "distros")

  die "distro_validate: unknown distro '${HYUNARCH_DISTRO}'. Check configs/distros.yaml."
}
