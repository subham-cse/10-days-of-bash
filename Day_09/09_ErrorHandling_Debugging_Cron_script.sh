#!/usr/bin/env bash
# ==============================================================================
# Script Name: 09_ErrorHandling_Debugging_Cron_script.sh
# Description: Resilient Execution Wrapper, Signal Trap & Crontab Validator
# Capabilities: Strict error trapping, stack-trace dump, lock file management,
#               and Cron schedule expression syntax validation.
# ==============================================================================

set -euo pipefail

# --- ANSI Color Formatting ---
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_CYAN="\033[1;36m"
readonly COLOR_BOLD="\033[1m"

# Custom xtrace prompt for deep debugging (activated if bash -x is used)
export PS4='+ [${BASH_SOURCE}:${LINENO}] ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# --- Logging Framework ---
log_info() {
    printf "${COLOR_BLUE}[INFO]${COLOR_RESET} %b\n" "$*"
}

log_success() {
    printf "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} %b\n" "$*"
}

log_warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %b\n" "$*"
}

log_error() {
    printf "${COLOR_RED}[ERROR]${COLOR_RESET} %b\n" "$*" >&2
}

# --- Runtime Scratch Space & PID Lock ---
WORK_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'resilient_job')"
LOCK_FILE="${WORK_DIR}/process.lock"

# --- Signal & Exit Trap Cleanup Engine ---
cleanup_handler() {
    local exit_code=$?
    log_info "Initiating cleanup handler for PID $$ (Exit Status: ${exit_code})..."
    
    if [[ -f "${LOCK_FILE}" ]]; then
        rm -f "${LOCK_FILE}"
        log_info "Lock file released."
    fi
    
    if [[ -d "${WORK_DIR}" ]]; then
        rm -rf "${WORK_DIR}"
        log_info "Temporary working directory purged: ${WORK_DIR}"
    fi
    
    if [[ "${exit_code}" -eq 0 ]]; then
        log_success "Script terminated cleanly."
    else
        log_warn "Script exited with non-zero status code: ${exit_code}"
    fi
}

interruption_handler() {
    local signal_name="$1"
    log_warn "Caught signal: ${signal_name}. Halting workers safely..."
    exit 130
}

# --- Automated Stack Trace Dump on Error ---
stack_trace_handler() {
    local err_line="$1"
    local last_command="$2"
    local err_code="$3"
    
    printf "\n${COLOR_RED}==================== CRITICAL EXECUTION FAILURE ====================${COLOR_RESET}\n" >&2
    printf "${COLOR_BOLD}Failed Command :${COLOR_RESET} %s\n" "${last_command}" >&2
    printf "${COLOR_BOLD}Failed Line    :${COLOR_RESET} %s\n" "${err_line}" >&2
    printf "${COLOR_BOLD}Exit Status    :${COLOR_RESET} %s\n" "${err_code}" >&2
    printf "${COLOR_BOLD}Call Stack Hierarchy:${COLOR_RESET}\n" >&2
    
    local stack_depth="${#FUNCNAME[@]}"
    local i
    for (( i = 1; i < stack_depth; i++ )); do
        local func="${FUNCNAME[$i]}"
        local src="${BASH_SOURCE[$i]:-unknown}"
        local line="${BASH_LINENO[$((i - 1))]}"
        printf "  --> [%d] %s() at %s:%s\n" "${i}" "${func}" "${src}" "${line}" >&2
    done
    printf "${COLOR_RED}====================================================================${COLOR_RESET}\n\n" >&2
}

# Register Traps
trap cleanup_handler EXIT
trap 'interruption_handler SIGINT' INT
trap 'interruption_handler SIGTERM' TERM
trap 'stack_trace_handler "${LINENO}" "${BASH_COMMAND}" "$?"' ERR

# --- Module 1: Lock File Management Engine ---
acquire_lock() {
    log_info "Attempting to acquire exclusive execution lock..."
    if [[ -e "${LOCK_FILE}" ]]; then
        log_error "Lock file exists at ${LOCK_FILE}. Another instance is running."
        return 1
    fi
    printf "%d\n" "$$" > "${LOCK_FILE}"
    log_success "Lock acquired successfully for PID $$."
}

# --- Module 2: Crontab Syntax & Expression Validator ---
validate_cron_expression() {
    local expression="$1"
    printf "\n${COLOR_CYAN}=== Validating Cron Expression: '${expression}' ===${COLOR_RESET}\n"
    
    # Split into 5 space-separated components
    local -a fields=(${expression})
    if [[ "${#fields[@]}" -ne 5 ]]; then
        log_error "Invalid Cron syntax: Expected 5 fields (min hour dom mon dow), received ${#fields[@]}."
        return 1
    fi
    
    local min="${fields[0]}"
    local hour="${fields[1]}"
    local dom="${fields[2]}"
    local mon="${fields[3]}"
    local dow="${fields[4]}"
    
    printf "%-18s : %s\n" "Minute (0-59)" "${min}"
    printf "%-18s : %s\n" "Hour (0-23)" "${hour}"
    printf "%-18s : %s\n" "Day of Month (1-31)" "${dom}"
    printf "%-18s : %s\n" "Month (1-12)" "${mon}"
    printf "%-18s : %s\n" "Day of Week (0-7)" "${dow}"
    
    # Basic field token validation
    local field
    for field in "${fields[@]}"; do
        if ! [[ "${field}" =~ ^(\*|[0-9,\/\-]+)$ ]]; then
            log_error "Illegal characters detected in cron field: '${field}'"
            return 1
        fi
    done
    
    log_success "Cron expression syntax is structurally valid."
    return 0
}

# --- Module 3: Simulated Safe Worker Function ---
execute_safe_task() {
    log_info "Executing task in isolated scratch environment: ${WORK_DIR}"
    local payload="${WORK_DIR}/payload.txt"
    
    printf "Timestamp: %s | Host: %s\n" "$(date -u)" "${HOSTNAME:-localhost}" > "${payload}"
    log_info "Task payload created: $(wc -c < "${payload}" | tr -d ' ') bytes."
}

# --- Main Driver ---
main() {
    log_info "Starting Defensive Error Handling & Cron Inspection Engine..."
    
    acquire_lock
    execute_safe_task
    
    # Test valid and complex cron expressions
    validate_cron_expression "*/15 2 * * 1-5"
    validate_cron_expression "0 0 1 * *"
    
    log_success "All tasks completed successfully without triggering fault traps."
    return 0
}

main "$@"
