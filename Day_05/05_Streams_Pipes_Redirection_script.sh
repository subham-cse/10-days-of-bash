#!/usr/bin/env bash
# ==============================================================================
# Script Name : 05_Streams_Pipes_Redirection_script.sh
# Description : Multi-Stream Logger & File Descriptor Routing Engine
# Day         : 05 - POSIX Streams, File Descriptors, Pipes & Redirection Mechanics
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ANSI Color Codes
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_CYAN="\033[1;36m"

# File Paths for Log Artifacts
readonly LOG_DIR="./logs_day05_$$"
readonly COMBINED_LOG="${LOG_DIR}/combined.log"
readonly ERROR_LOG="${LOG_DIR}/error.log"
readonly STDOUT_LOG="${LOG_DIR}/stdout.log"

# Standardized Logging Facade (Writes directly to terminal via standard streams)
log_info() {
    printf "${COLOR_BLUE}[INFO]${COLOR_RESET} %s\n" "$*"
}

log_success() {
    printf "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} %s\n" "$*"
}

log_warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %s\n" "$*" >&2
}

log_error() {
    printf "${COLOR_RED}[ERROR]${COLOR_RESET} %s\n" "$*" >&2
}

# Cleanup handler on exit
cleanup() {
    local exit_code=$?
    # Close custom file descriptors if open
    exec 3>&- 2>/dev/null || true
    exec 4>&- 2>/dev/null || true

    if [ -d "${LOG_DIR}" ]; then
        rm -rf "${LOG_DIR}"
    fi

    if [ "${exit_code}" -ne 0 ]; then
        log_error "Multi-stream execution terminated with status: ${exit_code}"
    fi
}
trap cleanup EXIT

# Initialize log workspace
initialize_logging_subsystem() {
    mkdir -p "${LOG_DIR}"
    touch "${COMBINED_LOG}" "${ERROR_LOG}" "${STDOUT_LOG}"
    log_info "Log repository initialized at: ${LOG_DIR}"
}

# Function 1: File descriptor allocation and dual stream tee routing
demonstrate_custom_file_descriptors() {
    log_info "Allocating Custom File Descriptor 3 (Output Log) and 4 (Error Log)..."

    # Open FD 3 for writing to STDOUT_LOG and FD 4 for writing to ERROR_LOG
    exec 3>> "${STDOUT_LOG}"
    exec 4>> "${ERROR_LOG}"

    # Write structured messages directly to custom file descriptors
    local timestamp
    timestamp="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"

    printf "[%s] [FD3_STDOUT] Application service kernel started.\n" "${timestamp}" >&3
    printf "[%s] [FD4_STDERR] Minor cache synchronization warning (handled).\n" "${timestamp}" >&4

    # Close custom file descriptors
    exec 3>&-
    exec 4>&-

    log_success "Custom file descriptor streams written and closed cleanly."
}

# Function 2: Pipeline routing with tee and /dev/null suppression
demonstrate_pipeline_redirection() {
    log_info "Demonstrating pipeline filtering, tee splitting, and /dev/null suppression..."

    # Generate synthetic telemetry stream
    local telemetry_data="metric.cpu.usage=45\nnoise.debug.heartbeat=ack\nmetric.mem.usage=62\nnoise.debug.ping=pong\nerror.disk.full=false"

    # Pipe data: filter out debug noise to /dev/null, tee valid metrics to combined log & terminal
    printf "${COLOR_CYAN}--- Streaming Telemetry Data Through Filter Pipeline ---${COLOR_RESET}\n"

    printf "%b\n" "${telemetry_data}" \
        | grep -v "noise\." \
        | tee -a "${COMBINED_LOG}" \
        | while read -r line; do
            printf "  -> Streamed Metric: %s\n" "${line}"
          done

    printf "${COLOR_CYAN}-------------------------------------------------------${COLOR_RESET}\n\n"

    # Discard command stderr completely into /dev/null
    log_info "Executing command with stderr discarded to /dev/null..."
    ls /path/to/nonexistent/directory/$$ 2>/dev/null || true
    log_success "Suppression of noisy stderr verified."
}

# Function 3: Verify captured stream logs
verify_logged_artifacts() {
    log_info "Verifying physical log files on disk..."

    local combined_lines
    local stdout_lines
    local error_lines

    combined_lines="$(wc -l < "${COMBINED_LOG}" | tr -d ' ')"
    stdout_lines="$(wc -l < "${STDOUT_LOG}" | tr -d ' ')"
    error_lines="$(wc -l < "${ERROR_LOG}" | tr -d ' ')"

    printf "\n"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s (%d lines)\n" "Combined Log" "${COMBINED_LOG}" "${combined_lines}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s (%d lines)\n" "Standard Out Log (FD 3)" "${STDOUT_LOG}" "${stdout_lines}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s (%d lines)\n" "Standard Error Log (FD 4)" "${ERROR_LOG}" "${error_lines}"
    printf "\n"

    if [ "${combined_lines}" -gt 0 ] && [ "${stdout_lines}" -gt 0 ] && [ "${error_lines}" -gt 0 ]; then
        log_success "All stream redirection targets verified with valid non-zero payloads."
    else
        log_error "Log verification failed: Empty stream logs detected."
        return 1
    fi
}

main() {
    printf "\n=================================================================\n"
    printf "   10-DAYS-OF-BASH : DAY 05 MULTI-STREAM & REDIRECTION ENGINE    \n"
    printf "=================================================================\n\n"

    initialize_logging_subsystem
    demonstrate_custom_file_descriptors
    demonstrate_pipeline_redirection
    verify_logged_artifacts

    log_success "Day 05 stream redirection and file descriptor engine completed successfully."
    exit 0
}

main "$@"
