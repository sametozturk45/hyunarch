#!/usr/bin/env bash
# lib/ui.sh -- User interface helpers: banners, menus, prompts, plan display.
# All visible output goes to stderr so stdout stays clean for callers.
# Sourced after common.sh and logging.sh.

set -euo pipefail

# ---------------------------------------------------------------------------
# ui_banner() -- print the project banner
# ---------------------------------------------------------------------------
ui_banner() {
  cat >&2 << 'BANNER'

  ██╗  ██╗██╗   ██╗██╗   ██╗███╗   ██╗ █████╗ ██████╗  ██████╗██╗  ██╗
  ██║  ██║╚██╗ ██╔╝██║   ██║████╗  ██║██╔══██╗██╔══██╗██╔════╝██║  ██║
  ███████║ ╚████╔╝ ██║   ██║██╔██╗ ██║███████║██████╔╝██║     ███████║
  ██╔══██║  ╚██╔╝  ██║   ██║██║╚██╗██║██╔══██║██╔══██╗██║     ██╔══██║
  ██║  ██║   ██║   ╚██████╔╝██║ ╚████║██║  ██║██║  ██║╚██████╗██║  ██║
  ╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

  Linux Customization System
  ─────────────────────────────────────────────────────────────────────────

BANNER
}

# ---------------------------------------------------------------------------
# ui_separator() -- print a horizontal line to stderr
# ---------------------------------------------------------------------------
ui_separator() {
  echo "─────────────────────────────────────────────────────────────────────────" >&2
}

# ---------------------------------------------------------------------------
# ui_info() / ui_warn() / ui_error() -- styled one-line messages to stderr
# ---------------------------------------------------------------------------
ui_info() {
  echo "  [INFO]  $*" >&2
}

ui_warn() {
  echo "  [WARN]  $*" >&2
}

ui_error() {
  echo "  [ERROR] $*" >&2
}

# ---------------------------------------------------------------------------
# ui_menu_single() -- numbered list, single selection
# Args: prompt_text item1 item2 ...
# Returns: selected item via stdout (not the number -- the item itself)
# User input is read from /dev/tty so stderr can be redirected.
# ---------------------------------------------------------------------------
ui_menu_single() {
  local prompt="$1"
  shift
  local items=("$@")
  local count="${#items[@]}"

  if [[ "$count" -eq 0 ]]; then
    ui_error "ui_menu_single: no items provided"
    return 1
  fi

  echo "" >&2
  echo "  ${prompt}" >&2
  ui_separator

  local i
  for (( i=0; i<count; i++ )); do
    printf "  %2d) %s\n" "$(( i + 1 ))" "${items[$i]}" >&2
  done

  echo "" >&2

  local choice
  while true; do
    printf "  Enter number [1-%d]: " "$count" >&2
    read -r choice < /dev/tty
    # Validate: must be a positive integer within range
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      # Print the selected item to stdout
      echo "${items[$(( choice - 1 ))]}"
      return 0
    fi
    ui_warn "Invalid selection: '${choice}'. Please enter a number between 1 and ${count}."
  done
}

# ---------------------------------------------------------------------------
# ui_menu_multi() -- numbered list, multi-selection
# Args: prompt_text item1 item2 ...
# Returns: newline-separated selected items via stdout
# Accepts: comma-separated numbers, ranges (1-3), "all", "none"
# ---------------------------------------------------------------------------
ui_menu_multi() {
  local prompt="$1"
  shift
  local items=("$@")
  local count="${#items[@]}"

  if [[ "$count" -eq 0 ]]; then
    ui_error "ui_menu_multi: no items provided"
    return 1
  fi

  echo "" >&2
  echo "  ${prompt}" >&2
  ui_separator

  local i
  for (( i=0; i<count; i++ )); do
    printf "  %2d) %s\n" "$(( i + 1 ))" "${items[$i]}" >&2
  done

  echo "" >&2
  echo "  Enter comma-separated numbers, ranges (e.g. 1-3), 'all', or 'none'." >&2
  echo "" >&2

  local raw_input
  while true; do
    printf "  Your selection: " >&2
    read -r raw_input < /dev/tty
    raw_input="${raw_input// /}"  # strip spaces

    if [[ "$raw_input" == "none" ]]; then
      # Return nothing -- caller gets empty output
      return 0
    fi

    if [[ "$raw_input" == "all" ]]; then
      for item in "${items[@]}"; do
        echo "$item"
      done
      return 0
    fi

    # Parse comma-separated tokens; each may be a number or a range N-M
    local selected_indices=()
    local valid=1
    local token
    IFS=',' read -ra tokens <<< "$raw_input"
    for token in "${tokens[@]}"; do
      if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        local start="${BASH_REMATCH[1]}"
        local end="${BASH_REMATCH[2]}"
        if (( start < 1 || end > count || start > end )); then
          ui_warn "Invalid range: '${token}'. Valid range is 1-${count}."
          valid=0
          break
        fi
        local n
        for (( n=start; n<=end; n++ )); do
          selected_indices+=("$n")
        done
      elif [[ "$token" =~ ^[0-9]+$ ]]; then
        if (( token < 1 || token > count )); then
          ui_warn "Invalid number: '${token}'. Valid range is 1-${count}."
          valid=0
          break
        fi
        selected_indices+=("$token")
      else
        ui_warn "Unrecognized token: '${token}'."
        valid=0
        break
      fi
    done

    if [[ "$valid" -eq 1 ]]; then
      # Deduplicate and output selected items
      local seen=()
      local idx
      for idx in "${selected_indices[@]}"; do
        local item="${items[$(( idx - 1 ))]}"
        local already=0
        local s
        for s in "${seen[@]+"${seen[@]}"}"; do
          if [[ "$s" == "$item" ]]; then
            already=1
            break
          fi
        done
        if [[ "$already" -eq 0 ]]; then
          echo "$item"
          seen+=("$item")
        fi
      done
      return 0
    fi
  done
}

# ---------------------------------------------------------------------------
# ui_confirm() -- yes/no prompt
# Returns: 0 = yes, 1 = no
# ---------------------------------------------------------------------------
ui_confirm() {
  local prompt="${1:-Proceed?}"
  local answer

  echo "" >&2
  while true; do
    printf "  %s [y/N]: " "$prompt" >&2
    read -r answer < /dev/tty
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no|"") return 1 ;;
      *) ui_warn "Please enter 'y' or 'n'." ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# ui_print_plan() -- render the execution plan as a table
# Reads from HYUNARCH_PLAN global array (set in planner.sh)
# ---------------------------------------------------------------------------
ui_print_plan() {
  echo "" >&2
  ui_separator
  echo "  EXECUTION PLAN" >&2
  ui_separator

  if [[ "${#HYUNARCH_PLAN[@]}" -eq 0 ]]; then
    echo "  (empty -- no actions selected)" >&2
    ui_separator
    echo "" >&2
    return 0
  fi

  # Header
  printf "  %-4s  %-8s  %-30s  %-10s  %s\n" \
    "#" "TYPE" "TARGET" "MODE" "SCRIPT" >&2
  ui_separator

  local i
  for (( i=0; i<${#HYUNARCH_PLAN[@]}; i++ )); do
    local entry="${HYUNARCH_PLAN[$i]}"
    local action_type target_id install_mode script_path
    IFS='|' read -r action_type target_id install_mode script_path <<< "$entry"
    printf "  %-4s  %-8s  %-30s  %-10s  %s\n" \
      "$(( i + 1 ))" \
      "$action_type" \
      "$target_id" \
      "$install_mode" \
      "$script_path" >&2
  done

  ui_separator
  echo "  Total: ${#HYUNARCH_PLAN[@]} action(s)" >&2
  echo "" >&2
}

# ---------------------------------------------------------------------------
# ui_confirm_safe() -- confirm with graceful /dev/tty fallback
# Returns: 0 = yes, 1 = no (assumes no if /dev/tty unavailable)
# Used when confirmation is required but /dev/tty may not exist.
# ---------------------------------------------------------------------------
ui_confirm_safe() {
  local prompt="${1:-Proceed?}"
  
  # Check if /dev/tty is readable
  if ! [[ -r /dev/tty ]]; then
    log_warn "ui_confirm_safe: /dev/tty not available (non-interactive context)"
    ui_warn "Unable to prompt interactively -- assuming 'no'."
    return 1
  fi
  
  ui_confirm "$prompt"
}
