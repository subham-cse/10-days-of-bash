#!/usr/bin/env bash
# ==============================================================================
# Script Name : 01_Intro_Environment_Setup_script.sh
# Description : System Environment Inspector & Workspace Validator
# Day         : 01 - Shell Architectures, Execution Contexts & Environment Setup
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Color Definition Constants for ANSI-compatible terminals
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_CYAN="\033[1;36m"

# Standardized Logging Facilities
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

# Trap handler for unexpected termination
cleanup_trap() {
    local exit_code=$?
    if [ "${exit_code}" -ne 0 ]; then
        log_error "Script terminated unexpectedly with exit status: ${exit_code}"
    fi
}
trap cleanup_trap EXIT

# Function: Display system architecture and shell environment details
inspect_shell_environment() {
    log_info "Initiating Shell Architecture and Runtime Inspection..."

    local shell_bin="${SHELL:-unknown}"
    local bash_ver="${BASH_VERSION:-N/A}"
    local os_type
    local kernel_rel
    local machine_arch

    os_type="$(uname -s 2>/dev/null || echo "Unknown-OS")"
    kernel_rel="$(uname -r 2>/dev/null || echo "Unknown-Kernel")"
    machine_arch="$(uname -m 2>/dev/null || echo "Unknown-Arch")"

    printf "\n"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Operating System" "${os_type}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Kernel Release" "${kernel_rel}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Hardware Architecture" "${machine_arch}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Active Shell Binary" "${shell_bin}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Bash Version" "${bash_ver}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Process ID ($$)" "$$"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Parent Process ID ($PPID)" "${PPID}"
    printf "${COLOR_CYAN}%-25s :${COLOR_RESET} %s\n" "Current Working Dir" "$(pwd)"
    printf "\n"

    log_success "Host runtime environment verified successfully."
}

# Function: Verify workspace directory structure and validate permissions
validate_workspace_permissions() {
    local target_dir="${1:-./test_sandbox_day01}"
    log_info "Validating workspace creation and octal permission mask on: ${target_dir}"

    if [ ! -d "${target_dir}" ]; then
        log_info "Creating target workspace directory: ${target_dir}"
        mkdir -p "${target_dir}"
    fi

    # Set standard directory permissions (0755: rwxr-xr-x)
    chmod 755 "${target_dir}"

    local probe_file="${target_dir}/permission_probe.sh"
    log_info "Writing probe script: ${probe_file}"

    cat << 'PROBE_EOF' > "${probe_file}"
#!/usr/bin/env bash
set -euo pipefail
echo "Probe execution successful. Octal bitmask verified."
PROBE_EOF

    # Grant execute permissions
    chmod 755 "${probe_file}"

    # Verify execution permissions before running
    if [ ! -x "${probe_file}" ]; then
        log_error "Execute bit (0100) not active on probe file: ${probe_file}"
        return 1
    fi

    log_info "Executing probe file via direct path invocation..."
    local probe_output
    probe_output="$("${probe_file}")"
    log_success "Probe output: ${probe_output}"

    # Cleanup temporary test artifacts
    rm -rf "${target_dir}"
    log_success "Workspace directory permissions and cleanup verified."
}

# Main Execution Flow
main() {
    local start_time
    start_time="$(date +%s)"

    printf "\n=================================================================\n"
    printf "        10-DAYS-OF-BASH : DAY 01 ENVIRONMENT INSPECTOR           \n"
    printf "=================================================================\n\n"

    inspect_shell_environment

    local sandbox_dir="./sandbox_day01_$$"
    validate_workspace_permissions "${sandbox_dir}"

    local end_time
    end_time="$(date +%s)"
    local duration=$(( end_time - start_time ))

    log_success "Day 01 environment verification completed in ${duration}s without errors."
    exit 0
}

main "$@"
