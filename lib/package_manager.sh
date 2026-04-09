#!/usr/bin/env bash
# lib/package_manager.sh -- Package manager selection and validation.
# Depends on: config_loader.sh, ui.sh, logging.sh, distro.sh

set -euo pipefail

export HYUNARCH_PM="${HYUNARCH_PM:-}"

# ---------------------------------------------------------------------------
# pm_select() -- determine and set HYUNARCH_PM
# If the distro has a single supported PM, auto-selects it.
# If multiple, presents a menu.
# ---------------------------------------------------------------------------
pm_select() {
  log_section "Package Manager Selection"

  if [[ -z "${HYUNARCH_DISTRO:-}" ]]; then
    die "pm_select: HYUNARCH_DISTRO is not set. Run distro_select() first."
  fi

  local pm_list_raw
  pm_list_raw="$(config_get_field "distros" "$HYUNARCH_DISTRO" "supported_package_managers" 2>/dev/null || true)"

  if [[ -z "$pm_list_raw" ]]; then
    die "pm_select: no supported_package_managers found for distro '${HYUNARCH_DISTRO}'."
  fi

  # Split comma-separated PM list into an array
  local pms=()
  local pm_raw
  IFS=',' read -ra pms <<< "$pm_list_raw"

  # Trim whitespace from each element
  local trimmed_pms=()
  for pm_raw in "${pms[@]}"; do
    pm_raw="${pm_raw#"${pm_raw%%[! ]*}"}"
    pm_raw="${pm_raw%"${pm_raw##*[! ]}"}"
    [[ -n "$pm_raw" ]] && trimmed_pms+=("$pm_raw")
  done

  if [[ "${#trimmed_pms[@]}" -eq 0 ]]; then
    die "pm_select: PM list for '${HYUNARCH_DISTRO}' is empty after parsing."
  fi

  if [[ "${#trimmed_pms[@]}" -eq 1 ]]; then
    HYUNARCH_PM="${trimmed_pms[0]}"
    ui_info "Package manager auto-selected: ${HYUNARCH_PM}"
  else
    local selected
    selected="$(ui_menu_single "Select package manager for $(distro_get_display_name "$HYUNARCH_DISTRO"):" "${trimmed_pms[@]}")"
    HYUNARCH_PM="$selected"
  fi

  export HYUNARCH_PM
  log_info "Selected package manager: ${HYUNARCH_PM}"
}

# ---------------------------------------------------------------------------
# pm_validate() -- verify HYUNARCH_PM is known
# ---------------------------------------------------------------------------
pm_validate() {
  if [[ -z "${HYUNARCH_PM:-}" ]]; then
    die "pm_validate: HYUNARCH_PM is not set."
  fi

  local pm_list_raw
  pm_list_raw="$(config_get_field "distros" "$HYUNARCH_DISTRO" "supported_package_managers" 2>/dev/null || true)"

  if [[ -z "$pm_list_raw" ]]; then
    die "pm_validate: cannot retrieve supported_package_managers for '${HYUNARCH_DISTRO}'."
  fi

  local IFS=','
  local pm
  for pm in $pm_list_raw; do
    pm="${pm#"${pm%%[! ]*}"}"
    pm="${pm%"${pm##*[! ]}"}"
    if [[ "$pm" == "$HYUNARCH_PM" ]]; then
      return 0
    fi
  done

  die "pm_validate: '${HYUNARCH_PM}' is not a supported package manager for '${HYUNARCH_DISTRO}'."
}

# ---------------------------------------------------------------------------
# pm_install_cmd() -- print the install command prefix for the active PM
# ---------------------------------------------------------------------------
pm_install_cmd() {
  local pm="${HYUNARCH_PM:?pm_install_cmd: HYUNARCH_PM is not set}"
  case "$pm" in
    pacman) echo "sudo pacman -S --noconfirm" ;;
    yay)    echo "yay -S --noconfirm" ;;
    paru)   echo "paru -S --noconfirm" ;;
    apt)    echo "sudo apt install -y" ;;
    dnf)    echo "sudo dnf install -y" ;;
    *)      die "pm_install_cmd: unknown package manager '${pm}'" ;;
  esac
}

# ---------------------------------------------------------------------------
# pm_is_available() -- check if the PM binary exists on PATH
# Returns 0 if found, 1 if not.
# ---------------------------------------------------------------------------
pm_is_available() {
  local pm="${1:-${HYUNARCH_PM:-}}"
  if [[ -z "$pm" ]]; then
    log_warn "pm_is_available: no PM specified"
    return 1
  fi
  command -v "$pm" > /dev/null 2>&1
}
