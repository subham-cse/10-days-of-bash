#!/usr/bin/env bash
# ==============================================================================
# Script Name : 03_Conditionals_Test_Operators_script.sh
# Description : System Diagnostic & Compliance Checker Engine
# Day         : 03 - Conditionals, Test Operators & Pattern Matching
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ANSI Terminal Colors
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_CYAN="\033[1;36m"
readonly COLOR_MAGENTA="\033[1;35m"

# Standardized Logging Facade
log_info() {
    printf "${COLOR_BLUE}[INFO]${COLOR_RESET} %s\n" "$*"
}

log_success() {
    printf "${COLOR_GREEN}[PASS]${COLOR_RESET} %s\n" "$*"
}

log_warn() {
    printf "${COLOR_YELLOW}[WARN]${COLOR_RESET} %s\n" "$*" >&2
}

log_error() {
    printf "${COLOR_RED}[FAIL]${COLOR_RESET} %s\n" "$*" >&2
}

# Diagnostic Counter State
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Trap handler
cleanup() {
    local exit_code=$?
    if [ "${exit_code}" -ne 0 ] && [ "${FAILED_CHECKS}" -eq 0 ]; then
        log_error "Diagnostic suite interrupted abnormally (Status: ${exit_code})"
    fi
}
trap cleanup EXIT

# Test 1: Validate Path Existence and File Types
check_filesystem_nodes() {
    local paths_to_probe=("/etc/hosts" "/etc" "/tmp" "./non_existent_fixture_$$")

    log_info "Running File System Inode & Type Diagnostics..."

    for node in "${paths_to_probe[@]}"; do
        ((TOTAL_CHECKS++))
        if [[ -e "${node}" ]]; then
            if [[ -f "${node}" ]]; then
                if [[ -s "${node}" ]]; then
                    log_success "Regular non-empty file confirmed: ${node} (Size > 0)"
                    ((PASSED_CHECKS++))
                else
                    log_warn "Regular file exists but is empty (0 bytes): ${node}"
                    ((PASSED_CHECKS++))
                fi
            elif [[ -d "${node}" ]]; then
                log_success "Directory structure confirmed: ${node}"
                ((PASSED_CHECKS++))
            else
                log_info "Special filesystem node detected: ${node}"
                ((PASSED_CHECKS++))
            fi
        else
            log_warn "Node does not exist (Expected for dummy probe): ${node}"
            ((PASSED_CHECKS++))
        fi
    done
}

# Test 2: Extended Regular Expression Validation (Network Endpoint Format)
check_endpoint_pattern() {
    local endpoints=(
        "db-primary.prod.internal:5432"
        "cache-redis-01.staging.net:6379"
        "invalid_uri_format@@port"
    )
    local regex_pattern='^([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_-]+):([0-9]{2,5})$'

    log_info "Testing Endpoint Formatting with Extended Regex (~=) Matching..."

    for ep in "${endpoints[@]}"; do
        ((TOTAL_CHECKS++))
        if [[ "${ep}" =~ ${regex_pattern} ]]; then
            local host="${BASH_REMATCH[1]}"
            local env="${BASH_REMATCH[2]}"
            local tld="${BASH_REMATCH[3]}"
            local port="${BASH_REMATCH[4]}"
            log_success "Valid Endpoint: [${ep}] -> Host:${host}, Env:${env}.${tld}, Port:${port}"
            ((PASSED_CHECKS++))
        else
            if [[ "${ep}" == *"invalid"* ]]; then
                log_success "Correctly caught and rejected invalid pattern: [${ep}]"
                ((PASSED_CHECKS++))
            else
                log_error "Unexpected regex mismatch on: [${ep}]"
                ((FAILED_CHECKS++))
            fi
        fi
    done
}

# Test 3: Numerical Relational Checks & Resource Thresholds
check_resource_thresholds() {
    local max_allowed_load=85
    local current_simulated_load=62
    local available_disk_gb=40
    local min_required_disk_gb=10

    log_info "Evaluating System Capacity & Integer Comparison Operations..."

    ((TOTAL_CHECKS++))
    if (( current_simulated_load < max_allowed_load )); then
        log_success "CPU Load within safety limits: ${current_simulated_load}% (Threshold: ${max_allowed_load}%)"
        ((PASSED_CHECKS++))
    else
        log_error "CPU Load exceeds threshold: ${current_simulated_load}%"
        ((FAILED_CHECKS++))
    fi

    ((TOTAL_CHECKS++))
    if [[ "${available_disk_gb}" -ge "${min_required_disk_gb}" ]]; then
        log_success "Available disk capacity adequate: ${available_disk_gb}GB (Required: ${min_required_disk_gb}GB)"
        ((PASSED_CHECKS++))
    else
        log_error "Insufficient disk capacity: ${available_disk_gb}GB"
        ((FAILED_CHECKS++))
    fi
}

main() {
    printf "\n=================================================================\n"
    printf "   10-DAYS-OF-BASH : DAY 03 SYSTEM DIAGNOSTIC & COMPLIANCE ENGINE\n"
    printf "=================================================================\n\n"

    check_filesystem_nodes
    printf "\n"
    check_endpoint_pattern
    printf "\n"
    check_resource_thresholds
    printf "\n"

    printf "${COLOR_MAGENTA}---------------- Diagnostic Summary ----------------${COLOR_RESET}\n"
    printf "Total Checks Executed : %d\n" "${TOTAL_CHECKS}"
    printf "Checks Passed         : %d\n" "${PASSED_CHECKS}"
    printf "Checks Failed         : %d\n" "${FAILED_CHECKS}"
    printf "${COLOR_MAGENTA}----------------------------------------------------${COLOR_RESET}\n\n"

    if [ "${FAILED_CHECKS}" -eq 0 ]; then
        log_success "All diagnostic test assertions completed with exit status 0."
        exit 0
    else
        log_error "Diagnostic suite failed with ${FAILED_CHECKS} errors."
        exit 1
    fi
}

main "$@"
