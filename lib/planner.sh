#!/usr/bin/env bash
# lib/planner.sh -- Execution plan management.
#
# Plan entry format (pipe-delimited):
#   action_type|target_id|install_mode|script_path
#
#   action_type : preset | theme | app
#   install_mode: clean | hyunarch | direct
#   script_path : relative to HYUNARCH_ROOT
#
# The pipe character '|' must NOT appear in any config field value.

set -euo pipefail

# Global plan array -- must be declared with -g so subshells see it.
declare -ga HYUNARCH_PLAN=()

# ---------------------------------------------------------------------------
# plan_init() -- clear the plan and prepare for a new session
# ---------------------------------------------------------------------------
plan_init() {
  HYUNARCH_PLAN=()
  log_debug "planner: plan initialized"
}

# ---------------------------------------------------------------------------
# plan_add() -- append an entry to the plan
# Args: action_type  target_id  install_mode  script_path
# ---------------------------------------------------------------------------
plan_add() {
  local action_type="${1:?plan_add: missing action_type}"
  local target_id="${2:?plan_add: missing target_id}"
  local install_mode="${3:?plan_add: missing install_mode}"
  local script_path="${4:?plan_add: missing script_path}"

  # Guard: none of the values may contain the pipe delimiter
  local v
  for v in "$action_type" "$target_id" "$install_mode" "$script_path"; do
    if [[ "$v" == *"|"* ]]; then
      die "plan_add: value contains illegal delimiter '|': '${v}'"
    fi
  done

  local entry="${action_type}|${target_id}|${install_mode}|${script_path}"
  HYUNARCH_PLAN+=("$entry")
  log_debug "planner: added entry [${#HYUNARCH_PLAN[@]}]: ${entry}"
}

# ---------------------------------------------------------------------------
# plan_remove() -- remove entry at 1-based index
# ---------------------------------------------------------------------------
plan_remove() {
  local index="${1:?plan_remove: missing index}"
  local count="${#HYUNARCH_PLAN[@]}"

  if ! [[ "$index" =~ ^[0-9]+$ ]] || (( index < 1 || index > count )); then
    log_warn "plan_remove: index '${index}' is out of range (1-${count})"
    return 1
  fi

  local zero_idx=$(( index - 1 ))
  # Rebuild array without the target element
  local new_plan=()
  local i
  for (( i=0; i<count; i++ )); do
    if (( i != zero_idx )); then
      new_plan+=("${HYUNARCH_PLAN[$i]}")
    fi
  done
  HYUNARCH_PLAN=("${new_plan[@]+"${new_plan[@]}"}")
  log_debug "planner: removed entry at index ${index}"
}

# ---------------------------------------------------------------------------
# plan_clear() -- empty the plan
# ---------------------------------------------------------------------------
plan_clear() {
  HYUNARCH_PLAN=()
  log_debug "planner: plan cleared"
}

# ---------------------------------------------------------------------------
# plan_count() -- print the number of plan entries to stdout
# ---------------------------------------------------------------------------
plan_count() {
  echo "${#HYUNARCH_PLAN[@]}"
}

# ---------------------------------------------------------------------------
# plan_display() -- render the plan via ui_print_plan()
# ---------------------------------------------------------------------------
plan_display() {
  ui_print_plan
}

# ---------------------------------------------------------------------------
# plan_get_entry() -- print the entry at 1-based index to stdout
# ---------------------------------------------------------------------------
plan_get_entry() {
  local index="${1:?plan_get_entry: missing index}"
  local count="${#HYUNARCH_PLAN[@]}"

  if ! [[ "$index" =~ ^[0-9]+$ ]] || (( index < 1 || index > count )); then
    log_warn "plan_get_entry: index '${index}' out of range (1-${count})"
    return 1
  fi

  echo "${HYUNARCH_PLAN[$(( index - 1 ))]}"
}

# ---------------------------------------------------------------------------
# plan_validate() -- verify all script paths exist and are readable
# Prints problems to stderr. Returns 1 if any validation fails.
# ---------------------------------------------------------------------------
plan_validate() {
  local errors=0
  local i
  for (( i=0; i<${#HYUNARCH_PLAN[@]}; i++ )); do
    local entry="${HYUNARCH_PLAN[$i]}"
    local action_type target_id install_mode script_path
    IFS='|' read -r action_type target_id install_mode script_path <<< "$entry"

    local absolute_path="${HYUNARCH_ROOT}/${script_path}"

    if [[ -z "$script_path" ]]; then
      log_warn "plan_validate: entry $(( i + 1 )) (${target_id}) has no script path"
      (( errors++ )) || true
      continue
    fi

    if [[ ! -f "$absolute_path" ]]; then
      log_error "plan_validate: script not found for '${target_id}': ${absolute_path}"
      (( errors++ )) || true
      continue
    fi

    if [[ ! -r "$absolute_path" ]]; then
      log_error "plan_validate: script not readable for '${target_id}': ${absolute_path}"
      (( errors++ )) || true
    fi
  done

  if (( errors > 0 )); then
    log_error "plan_validate: ${errors} validation error(s) found."
    return 1
  fi

  log_info "plan_validate: all ${#HYUNARCH_PLAN[@]} entries passed."
  return 0
}

# ---------------------------------------------------------------------------
# plan_export() -- write the plan to a file for auditing or replay
# Args: output_file (optional; defaults to /tmp/hyunarch-plan-<timestamp>.txt)
# ---------------------------------------------------------------------------
plan_export() {
  local out_file="${1:-}"
  if [[ -z "$out_file" ]]; then
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    out_file="/tmp/hyunarch-plan-${ts}.txt"
  fi

  {
    echo "# Hyunarch Execution Plan"
    echo "# Generated: $(date)"
    echo "# Distro:  ${HYUNARCH_DISTRO:-unknown}"
    echo "# PM:      ${HYUNARCH_PM:-unknown}"
    echo "# DE:      ${HYUNARCH_DE:-unknown}"
    echo "#"
    echo "# format: action_type|target_id|install_mode|script_path"
    local entry
    for entry in "${HYUNARCH_PLAN[@]+"${HYUNARCH_PLAN[@]}"}"; do
      echo "$entry"
    done
  } > "$out_file"

  log_info "plan_export: plan written to ${out_file}"
  echo "$out_file"
}
