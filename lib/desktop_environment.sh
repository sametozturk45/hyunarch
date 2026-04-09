#!/usr/bin/env bash
# lib/desktop_environment.sh -- Desktop environment selection filtered by distro.
# Depends on: config_loader.sh, ui.sh, logging.sh, distro.sh

set -euo pipefail

export HYUNARCH_DE="${HYUNARCH_DE:-}"

# ---------------------------------------------------------------------------
# de_select() -- filter desktops by HYUNARCH_DISTRO, present menu, set HYUNARCH_DE
# ---------------------------------------------------------------------------
de_select() {
  log_section "Desktop Environment Selection"

  if [[ -z "${HYUNARCH_DISTRO:-}" ]]; then
    die "de_select: HYUNARCH_DISTRO is not set. Run distro_select() first."
  fi

  config_load_desktops

  # Collect desktops compatible with the selected distro
  local compatible_ids=()
  local compatible_names=()
  local id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    local dn
    dn="$(config_get_field "desktops" "$id" "display_name" 2>/dev/null || echo "$id")"
    compatible_ids+=("$id")
    compatible_names+=("$dn")
  done < <(config_get_filtered_ids "desktops" "supported_distros" "$HYUNARCH_DISTRO")

  if [[ "${#compatible_ids[@]}" -eq 0 ]]; then
    die "de_select: no desktop environments available for distro '${HYUNARCH_DISTRO}'."
  fi

  local selected_name
  selected_name="$(ui_menu_single "Select your desktop environment:" "${compatible_names[@]}")"

  # Map display_name back to id
  local i
  for (( i=0; i<${#compatible_names[@]}; i++ )); do
    if [[ "${compatible_names[$i]}" == "$selected_name" ]]; then
      HYUNARCH_DE="${compatible_ids[$i]}"
      break
    fi
  done

  if [[ -z "$HYUNARCH_DE" ]]; then
    die "de_select: failed to resolve id for '${selected_name}'"
  fi

  export HYUNARCH_DE
  log_info "Selected desktop environment: ${HYUNARCH_DE}"
  ui_info "Desktop environment set to: $(de_get_display_name "$HYUNARCH_DE")"
}

# ---------------------------------------------------------------------------
# de_get_display_name() -- print the display_name for a given DE id
# ---------------------------------------------------------------------------
de_get_display_name() {
  local de_id="${1:?de_get_display_name: missing de_id}"
  config_get_field "desktops" "$de_id" "display_name" 2>/dev/null || echo "$de_id"
}

# ---------------------------------------------------------------------------
# de_validate() -- verify HYUNARCH_DE is a known and compatible DE id
# ---------------------------------------------------------------------------
de_validate() {
  if [[ -z "${HYUNARCH_DE:-}" ]]; then
    die "de_validate: HYUNARCH_DE is not set."
  fi

  # Ensure the id exists in the loaded desktops section
  local id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if [[ "$id" == "$HYUNARCH_DE" ]]; then
      return 0
    fi
  done < <(config_get_ids "desktops")

  die "de_validate: unknown desktop environment '${HYUNARCH_DE}'. Check configs/desktops.yaml."
}
