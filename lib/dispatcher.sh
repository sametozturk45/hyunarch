#!/usr/bin/env bash
# lib/dispatcher.sh -- Execute the plan entries produced by planner.sh.
# Each entry is parsed, validated, and dispatched via direct bash invocation.
# eval is never used for script execution.

set -euo pipefail

# ---------------------------------------------------------------------------
# dispatch_single() -- execute one plan entry string
# Args: entry_string (action_type|target_id|install_mode|script_path)
# Returns: exit code of the script (or 0 in dry-run mode)
# ---------------------------------------------------------------------------
dispatch_single() {
  local entry="${1:?dispatch_single: missing entry}"

  local action_type target_id install_mode script_path
  IFS='|' read -r action_type target_id install_mode script_path <<< "$entry"

  if [[ -z "$script_path" ]]; then
    log_error "dispatch_single: no script path in entry: ${entry}"
    return 1
  fi

  local absolute_path="${HYUNARCH_ROOT}/${script_path}"

  # Validate script exists and is executable
  if [[ ! -f "$absolute_path" ]]; then
    log_error "dispatch_single: script not found: ${absolute_path}"
    return 1
  fi
  if [[ ! -r "$absolute_path" ]]; then
    log_error "dispatch_single: script not readable: ${absolute_path}"
    return 1
  fi

  # Export install mode so child scripts can inspect it
  export HYUNARCH_INSTALL_MODE="$install_mode"

  log_info "dispatch: [${action_type}] ${target_id} (mode=${install_mode}) -> ${script_path}"

  if is_dry_run; then
    log_info "dispatch: DRY-RUN -- skipping execution of ${script_path}"
    return 0
  fi

  # Direct invocation -- no eval
  bash "$absolute_path"
  local exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    log_info "dispatch: [OK] ${target_id} completed successfully."
  else
    log_error "dispatch: [FAIL] ${target_id} exited with code ${exit_code}."
  fi

  return "$exit_code"
}

# ---------------------------------------------------------------------------
# dispatch_execute_plan() -- iterate HYUNARCH_PLAN and run each entry
# On failure, asks the user whether to continue or abort.
# Uses ui_confirm_safe to handle non-interactive contexts gracefully.
# ---------------------------------------------------------------------------
dispatch_execute_plan() {
  local total="${#HYUNARCH_PLAN[@]}"

  if [[ "$total" -eq 0 ]]; then
    log_warn "dispatch_execute_plan: plan is empty, nothing to do."
    ui_warn "The execution plan is empty."
    return 0
  fi

  log_section "Executing Plan (${total} action(s))"

  local success_count=0
  local failure_count=0
  local i

  for (( i=0; i<total; i++ )); do
    local entry="${HYUNARCH_PLAN[$i]}"
    local action_type target_id install_mode script_path
    IFS='|' read -r action_type target_id install_mode script_path <<< "$entry"

    echo "" >&2
    ui_separator
    echo "  [$(( i + 1 ))/${total}] ${action_type}: ${target_id} (${install_mode})" >&2
    ui_separator

    local rc=0
    dispatch_single "$entry" || rc=$?

    if [[ "$rc" -eq 0 ]]; then
      (( success_count++ )) || true
    else
      (( failure_count++ )) || true
      ui_error "Action '${target_id}' failed (exit code ${rc})."

      # Ask whether to continue with the remaining plan
      # Use ui_confirm_safe which handles /dev/tty unavailability gracefully
      if ! ui_confirm_safe "Continue with remaining $(( total - i - 1 )) action(s)?"; then
        log_warn "dispatch: user aborted after failure of '${target_id}'"
        ui_warn "Execution aborted by user."
        break
      fi
    fi
  done

  echo "" >&2
  ui_separator
  echo "  Execution complete: ${success_count} succeeded, ${failure_count} failed." >&2
  ui_separator

  log_info "dispatch_execute_plan: done. success=${success_count} failure=${failure_count}"

  if [[ "$failure_count" -gt 0 ]]; then
    return 1
  fi
  return 0
}
