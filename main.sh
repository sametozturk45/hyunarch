#!/usr/bin/env bash
# main.sh -- Hyunarch Linux Customization System entry point.
#
# Usage:
#   ./main.sh [--dry-run] [--verbose] [--log-file /path/to/file.log]
#
# Environment:
#   HYUNARCH_DRY_RUN  -- set non-empty to skip real script execution
#   HYUNARCH_VERBOSE  -- set non-empty to enable DEBUG logging

set -euo pipefail

# ---------------------------------------------------------------------------
# 1. Resolve HYUNARCH_ROOT (the directory this script lives in)
# ---------------------------------------------------------------------------
_resolve_root() {
  local src="${BASH_SOURCE[0]}"
  # Follow symlinks
  while [[ -L "$src" ]]; do
    local dir
    dir="$(cd -P "$(dirname "$src")" && pwd)"
    src="$(readlink "$src")"
    [[ "$src" != /* ]] && src="${dir}/${src}"
  done
  cd -P "$(dirname "$src")" && pwd
}

HYUNARCH_ROOT="$(_resolve_root)"
export HYUNARCH_ROOT

# ---------------------------------------------------------------------------
# 2. Parse CLI arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      HYUNARCH_DRY_RUN="1"
      export HYUNARCH_DRY_RUN
      shift
      ;;
    --verbose)
      HYUNARCH_VERBOSE="1"
      export HYUNARCH_VERBOSE
      shift
      ;;
    --log-file)
      if [[ -z "${2:-}" ]]; then
        echo "[main.sh] --log-file requires a path argument" >&2
        exit 1
      fi
      HYUNARCH_LOG_FILE="$2"
      export HYUNARCH_LOG_FILE
      shift 2
      ;;
    -h|--help)
      cat >&2 << 'HELP'
Usage: ./main.sh [OPTIONS]

Options:
  --dry-run           Show what would be executed without running scripts.
  --verbose           Enable DEBUG-level logging.
  --log-file FILE     Write logs to FILE instead of the default /tmp path.
  -h, --help          Show this help message.
HELP
      exit 0
      ;;
    *)
      echo "[main.sh] Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 3. Bootstrap: source common.sh, then all lib modules
# ---------------------------------------------------------------------------
# shellcheck disable=SC1091
source "${HYUNARCH_ROOT}/lib/common.sh"

hyunarch_source "logging.sh"
hyunarch_source "ui.sh"
hyunarch_source "config_loader.sh"
hyunarch_source "distro.sh"
hyunarch_source "package_manager.sh"
hyunarch_source "desktop_environment.sh"
hyunarch_source "planner.sh"
hyunarch_source "dispatcher.sh"

# ---------------------------------------------------------------------------
# 4. Initialize logging
# ---------------------------------------------------------------------------
log_init

# ---------------------------------------------------------------------------
# 5. Banner
# ---------------------------------------------------------------------------
ui_banner

if is_dry_run; then
  ui_warn "DRY-RUN mode is active -- no scripts will be executed."
fi

# ---------------------------------------------------------------------------
# 6. Distro, PM, and DE selection (order is fixed per architecture rules)
# ---------------------------------------------------------------------------
distro_select
pm_select
de_select

# ---------------------------------------------------------------------------
# 7. Initialize the execution plan
# ---------------------------------------------------------------------------
plan_init

# ---------------------------------------------------------------------------
# Helper: _menu_install_presets()
# ---------------------------------------------------------------------------
_menu_install_presets() {
  log_section "Preset Selection"

  config_load_presets

  # Collect presets valid for the current DE
  local preset_ids=()
  local preset_names=()
  local pid
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    local dn
    dn="$(config_get_field "presets" "$pid" "display_name" 2>/dev/null || echo "$pid")"
    preset_ids+=("$pid")
    preset_names+=("$dn")
  done < <(config_get_filtered_ids "presets" "desktop_environments" "$HYUNARCH_DE")

  if [[ "${#preset_ids[@]}" -eq 0 ]]; then
    ui_warn "No presets available for desktop environment: ${HYUNARCH_DE}"
    return 0
  fi

  # Presets are opinionated full setups -- single selection only
  local selected_name
  selected_name="$(ui_menu_single "Select a preset (single, opinionated full setup):" "${preset_names[@]}")"

  # Resolve id from name
  local i selected_id=""
  for (( i=0; i<${#preset_names[@]}; i++ )); do
    if [[ "${preset_names[$i]}" == "$selected_name" ]]; then
      selected_id="${preset_ids[$i]}"
      break
    fi
  done

  if [[ -z "$selected_id" ]]; then
    ui_warn "Could not resolve preset id for '${selected_name}'. Skipping."
    return 0
  fi

  # A preset may reference multiple scripts (comma-separated)
  local scripts_raw
  scripts_raw="$(config_get_field "presets" "$selected_id" "scripts" 2>/dev/null || true)"

  if [[ -z "$scripts_raw" ]]; then
    ui_warn "Preset '${selected_id}' has no scripts defined. Skipping."
    return 0
  fi

  local IFS=','
  local script_path
  for script_path in $scripts_raw; do
    script_path="${script_path#"${script_path%%[! ]*}"}"
    script_path="${script_path%"${script_path##*[! ]}"}"
    [[ -z "$script_path" ]] && continue
    plan_add "preset" "$selected_id" "direct" "$script_path"
    ui_info "Added to plan: preset '${selected_id}' -> ${script_path}"
  done
}

# ---------------------------------------------------------------------------
# Helper: _menu_install_themes()
# ---------------------------------------------------------------------------
_menu_install_themes() {
  log_section "Theme Selection"

  config_load_themes

  # Collect themes valid for the current DE
  local theme_ids=()
  local theme_names=()
  local tid
  while IFS= read -r tid; do
    [[ -z "$tid" ]] && continue
    local dn
    dn="$(config_get_field "themes" "$tid" "display_name" 2>/dev/null || echo "$tid")"
    theme_ids+=("$tid")
    theme_names+=("$dn")
  done < <(config_get_filtered_ids "themes" "desktop_environments" "$HYUNARCH_DE")

  if [[ "${#theme_ids[@]}" -eq 0 ]]; then
    ui_warn "No themes available for desktop environment: ${HYUNARCH_DE}"
    return 0
  fi

  # Multi-select for themes
  local selected_output
  selected_output="$(ui_menu_multi "Select themes to install (comma-separated, 'all', or 'none'):" "${theme_names[@]}")"

  if [[ -z "$selected_output" ]]; then
    ui_info "No themes selected."
    return 0
  fi

  local selected_name
  while IFS= read -r selected_name; do
    [[ -z "$selected_name" ]] && continue

    # Resolve id
    local i tid_resolved=""
    for (( i=0; i<${#theme_names[@]}; i++ )); do
      if [[ "${theme_names[$i]}" == "$selected_name" ]]; then
        tid_resolved="${theme_ids[$i]}"
        break
      fi
    done

    if [[ -z "$tid_resolved" ]]; then
      ui_warn "Could not resolve theme id for '${selected_name}'. Skipping."
      continue
    fi

    local script_path
    script_path="$(config_get_field "themes" "$tid_resolved" "script" 2>/dev/null || true)"

    if [[ -z "$script_path" ]]; then
      ui_warn "Theme '${tid_resolved}' has no script defined. Skipping."
      continue
    fi

    plan_add "theme" "$tid_resolved" "direct" "$script_path"
    ui_info "Added to plan: theme '${tid_resolved}' -> ${script_path}"
  done <<< "$selected_output"
}

# ---------------------------------------------------------------------------
# Helper: _menu_install_apps()
# ---------------------------------------------------------------------------
_menu_install_apps() {
  log_section "Application Selection"

  config_load_apps

  # ---- Step 1: Present category list ----
  local cat_ids=()
  local cat_names=()
  local cid
  while IFS= read -r cid; do
    [[ -z "$cid" ]] && continue
    local dn
    dn="$(config_get_field "categories" "$cid" "display_name" 2>/dev/null || echo "$cid")"
    cat_ids+=("$cid")
    cat_names+=("$dn")
  done < <(config_get_ids "categories")

  if [[ "${#cat_ids[@]}" -eq 0 ]]; then
    ui_warn "No categories found in configuration."
    return 0
  fi

  local selected_cats_output
  selected_cats_output="$(ui_menu_multi "Select application categories:" "${cat_names[@]}")"

  if [[ -z "$selected_cats_output" ]]; then
    ui_info "No categories selected."
    return 0
  fi

  # ---- Step 2: For each selected category, show apps filtered by DE ----
  local cat_name
  while IFS= read -r cat_name; do
    [[ -z "$cat_name" ]] && continue

    # Resolve category id
    local ci cat_id=""
    for (( ci=0; ci<${#cat_names[@]}; ci++ )); do
      if [[ "${cat_names[$ci]}" == "$cat_name" ]]; then
        cat_id="${cat_ids[$ci]}"
        break
      fi
    done

    if [[ -z "$cat_id" ]]; then
      ui_warn "Could not resolve category id for '${cat_name}'. Skipping."
      continue
    fi

    log_section "Applications: ${cat_name}"

    # Find apps in this category that are compatible with HYUNARCH_DE
    local app_ids_in_cat=()
    local app_names_in_cat=()
    local aid
    while IFS= read -r aid; do
      [[ -z "$aid" ]] && continue

      # Filter by category
      local app_cat
      app_cat="$(config_get_field "apps" "$aid" "category" 2>/dev/null || true)"
      [[ "$app_cat" != "$cat_id" ]] && continue

      local dn
      dn="$(config_get_field "apps" "$aid" "display_name" 2>/dev/null || echo "$aid")"
      app_ids_in_cat+=("$aid")
      app_names_in_cat+=("$dn")
    done < <(config_get_filtered_ids "apps" "desktop_environments" "$HYUNARCH_DE")

    if [[ "${#app_ids_in_cat[@]}" -eq 0 ]]; then
      ui_info "No applications available in '${cat_name}' for ${HYUNARCH_DE}."
      continue
    fi

    local selected_apps_output
    selected_apps_output="$(ui_menu_multi "Select applications from '${cat_name}':" "${app_names_in_cat[@]}")"

    if [[ -z "$selected_apps_output" ]]; then
      ui_info "No applications selected from '${cat_name}'."
      continue
    fi

    # ---- Step 3: For each selected app, determine install mode ----
    local app_name
    while IFS= read -r app_name; do
      [[ -z "$app_name" ]] && continue

      # Resolve app id
      local ai app_id=""
      for (( ai=0; ai<${#app_names_in_cat[@]}; ai++ )); do
        if [[ "${app_names_in_cat[$ai]}" == "$app_name" ]]; then
          app_id="${app_ids_in_cat[$ai]}"
          break
        fi
      done

      if [[ -z "$app_id" ]]; then
        ui_warn "Could not resolve app id for '${app_name}'. Skipping."
        continue
      fi

      local supports_clean supports_hyunarch
      supports_clean="$(config_get_field "apps" "$app_id" "supports_clean_install" 2>/dev/null || echo "false")"
      supports_hyunarch="$(config_get_field "apps" "$app_id" "supports_hyunarch_config" 2>/dev/null || echo "false")"

      local install_mode=""
      local script_path=""

      if [[ "$supports_clean" == "true" && "$supports_hyunarch" == "true" ]]; then
        # Let the user choose
        local mode_choice
        mode_choice="$(ui_menu_single "Install '${app_name}' with:" "Hyunarch Config" "Clean Install")"
        case "$mode_choice" in
          "Hyunarch Config")
            install_mode="hyunarch"
            script_path="$(config_get_field "apps" "$app_id" "hyunarch_script" 2>/dev/null || true)"
            ;;
          "Clean Install")
            install_mode="clean"
            script_path="$(config_get_field "apps" "$app_id" "clean_install_script" 2>/dev/null || true)"
            ;;
        esac
      elif [[ "$supports_hyunarch" == "true" ]]; then
        install_mode="hyunarch"
        script_path="$(config_get_field "apps" "$app_id" "hyunarch_script" 2>/dev/null || true)"
        ui_info "Auto-selected Hyunarch Config for '${app_name}' (only mode available)."
      elif [[ "$supports_clean" == "true" ]]; then
        install_mode="clean"
        script_path="$(config_get_field "apps" "$app_id" "clean_install_script" 2>/dev/null || true)"
        ui_info "Auto-selected Clean Install for '${app_name}' (only mode available)."
      else
        ui_warn "'${app_name}' has no supported install mode. Skipping."
        continue
      fi

      if [[ -z "$script_path" ]]; then
        ui_warn "'${app_name}' has no script for mode '${install_mode}'. Skipping."
        continue
      fi

      plan_add "app" "$app_id" "$install_mode" "$script_path"
      ui_info "Added to plan: app '${app_id}' (${install_mode}) -> ${script_path}"

    done <<< "$selected_apps_output"

  done <<< "$selected_cats_output"
}

# ---------------------------------------------------------------------------
# Helper: _menu_review_plan()
# ---------------------------------------------------------------------------
_menu_review_plan() {
  plan_display

  local count
  count="$(plan_count)"

  if [[ "$count" -eq 0 ]]; then
    return 0
  fi

  if ui_confirm_safe "Remove an entry from the plan?"; then
    local index_raw
    printf "  Enter entry number to remove [1-%d]: " "$count" >&2
    read -r index_raw < /dev/tty
    if [[ "$index_raw" =~ ^[0-9]+$ ]]; then
      plan_remove "$index_raw"
      ui_info "Entry ${index_raw} removed."
    else
      ui_warn "Invalid number '${index_raw}'. No entry removed."
    fi
  fi
}

# ---------------------------------------------------------------------------
# Helper: _menu_execute_plan()
# ---------------------------------------------------------------------------
_menu_execute_plan() {
  local count
  count="$(plan_count)"

  if [[ "$count" -eq 0 ]]; then
    ui_warn "The execution plan is empty. Add items first."
    return 0
  fi

  log_section "Pre-execution Validation"

  if ! plan_validate; then
    ui_error "Plan validation failed. Please check the errors above."
    if ! ui_confirm "Continue anyway?"; then
      return 0
    fi
  fi

  plan_display

  if ! ui_confirm "Execute the plan now? (${count} action(s))"; then
    ui_info "Execution cancelled."
    return 0
  fi

  dispatch_execute_plan
}

# ---------------------------------------------------------------------------
# 8. Main menu loop
# ---------------------------------------------------------------------------
log_section "Main Menu"

while true; do
  local_count="$(plan_count)"

  echo "" >&2
  ui_separator
  echo "  Hyunarch Main Menu" >&2
  echo "  Distro: ${HYUNARCH_DISTRO}  |  PM: ${HYUNARCH_PM}  |  DE: ${HYUNARCH_DE}" >&2
  ui_separator

  main_choice="$(ui_menu_single "Select an action:" \
    "1) Install Presets" \
    "2) Install Themes" \
    "3) Install Applications" \
    "4) Review Execution Plan [${local_count} item(s)]" \
    "5) Execute Plan" \
    "6) Exit")"

  case "$main_choice" in
    "1) Install Presets")
      _menu_install_presets
      ;;
    "2) Install Themes")
      _menu_install_themes
      ;;
    "3) Install Applications")
      _menu_install_apps
      ;;
    "4) Review Execution Plan"*)
      _menu_review_plan
      ;;
    "5) Execute Plan")
      _menu_execute_plan
      ;;
    "6) Exit")
      echo "" >&2
      ui_info "Exiting Hyunarch. Goodbye."
      log_info "User exited the main menu."
      exit 0
      ;;
    *)
      ui_warn "Unrecognized choice: '${main_choice}'"
      ;;
  esac
done
