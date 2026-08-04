#!/usr/bin/env bash
# ==============================================================================
# Script Name : 04_Loops_Iteration_Control_script.sh
# Description : Batch Service Poller & Cluster Health Monitor Engine
# Day         : 04 - Loops, Iteration Mechanics & Execution Control Flow
# ==============================================================================

set -euo pipefail
IFS=$'\n\t'

# ANSI Terminal Styling
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_CYAN="\033[1;36m"

# Standardized Logging Facade
log_info() {
    printf "${COLOR_BLUE}[INFO]${COLOR_RESET} %s\n" "$*"
}

log_success() {
    printf "${COLOR_GREEN}[HEALTHY]${COLOR_RESET} %s\n" "$*"
}

log_warn() {
    printf "${COLOR_YELLOW}[RETRY]${COLOR_RESET} %s\n" "$*" >&2
}

log_error() {
    printf "${COLOR_RED}[UNHEALTHY]${COLOR_RESET} %s\n" "$*" >&2
}

# Trap handler for graceful shutdown
cleanup() {
    local exit_code=$?
    if [ "${exit_code}" -ne 0 ]; then
        log_error "Service poller exited prematurely with status: ${exit_code}"
    fi
}
trap cleanup EXIT

# Simulated service cluster node inventory
readonly NODES=("api-gateway-01" "auth-service-02" "worker-queue-03" "db-replica-04")
readonly MAX_RETRIES=3
readonly POLL_INTERVAL_SEC=1

# Mock health check probe function
simulate_node_probe() {
    local node_name="$1"
    local attempt="$2"

    # Deterministic simulation: worker-queue-03 recovers on attempt 2
    if [[ "${node_name}" == "worker-queue-03" && "${attempt}" -lt 2 ]]; then
        return 1
    fi
    return 0
}

# Function 1: C-style arithmetic iteration over cluster nodes
poll_cluster_health() {
    log_info "Initiating cluster node health sweep across ${#NODES[@]} registered instances..."
    local total_nodes=${#NODES[@]}
    local healthy_nodes=0

    # C-style 3-expression loop
    for (( i=0; i<total_nodes; i++ )); do
        local node="${NODES[$i]}"
        local is_healthy=false

        log_info "Polling Node [$((i+1))/${total_nodes}]: ${node}..."

        # While loop with bounded retry condition
        local attempt=1
        while [ "${attempt}" -le "${MAX_RETRIES}" ]; do
            if simulate_node_probe "${node}" "${attempt}"; then
                log_success "Node ${node} responded with HTTP 200 OK (Attempt: ${attempt})"
                is_healthy=true
                ((healthy_nodes++))
                break
            else
                log_warn "Node ${node} probe failed on attempt ${attempt}/${MAX_RETRIES}. Backing off..."
                sleep "${POLL_INTERVAL_SEC}"
                ((attempt++))
            fi
        done

        if [ "${is_healthy}" = false ]; then
            log_error "Node ${node} failed to achieve healthy status after ${MAX_RETRIES} attempts."
        fi
    done

    printf "\n"
    log_info "Sweep Summary: ${healthy_nodes}/${total_nodes} nodes operating within nominal parameters."
}

# Function 2: 'Until' loop demonstrating countdown and state synchronization
execute_countdown_synchronization() {
    local sync_target_seconds=3
    local current_counter=0

    log_info "Awaiting distributed cluster lease synchronization via 'until' gate..."

    # 'until' loop continues while expression returns NON-ZERO (false)
    until (( current_counter >= sync_target_seconds )); do
        ((current_counter++))
        printf "  --> Synchronization tick [%d/%d]...\n" "${current_counter}" "${sync_target_seconds}"
        sleep 1
    done

    log_success "Distributed state synchronization achieved."
}

# Function 3: Iteration with multi-level nested break & continue demonstration
process_nested_service_matrices() {
    local environments=("staging" "production")
    local tiers=("frontend" "backend" "analytics")

    log_info "Scanning multi-tier deployment matrix..."

    for env in "${environments[@]}"; do
        for tier in "${tiers[@]}"; do
            if [[ "${env}" == "staging" && "${tier}" == "analytics" ]]; then
                log_info "Skipping unprovisioned tier [${env} -> ${tier}] via continue..."
                continue
            fi

            printf "  [DEPLOY MATRIX] Validated configuration for: %s :: %s\n" "${env}" "${tier}"
        done
    done
}

main() {
    printf "\n=================================================================\n"
    printf "      10-DAYS-OF-BASH : DAY 04 SERVICE POLLER & HEALTH ENGINE    \n"
    printf "=================================================================\n\n"

    poll_cluster_health
    printf "\n"
    execute_countdown_synchronization
    printf "\n"
    process_nested_service_matrices
    printf "\n"

    log_success "Day 04 iteration and loop control execution completed successfully."
    exit 0
}

main "$@"
