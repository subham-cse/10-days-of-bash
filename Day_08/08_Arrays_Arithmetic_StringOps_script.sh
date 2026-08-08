#!/usr/bin/env bash
# ==============================================================================
# Script Name: 08_Arrays_Arithmetic_StringOps_script.sh
# Description: System Resource Aggregator & String Manipulation Engine
# Capabilities: Indexed & associative arrays, native parameter expansion,
#               integer arithmetic computations, and partition metrics aggregation.
# ==============================================================================

set -euo pipefail

# --- ANSI Color Definitions ---
readonly COLOR_RESET="\033[0m"
readonly COLOR_RED="\033[1;31m"
readonly COLOR_GREEN="\033[1;32m"
readonly COLOR_YELLOW="\033[1;33m"
readonly COLOR_BLUE="\033[1;34m"
readonly COLOR_CYAN="\033[1;36m"
readonly COLOR_BOLD="\033[1m"

# --- Logging Functions ---
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

# --- Module 1: Path & String Manipulation via Parameter Expansions ---
demonstrate_string_operations() {
    printf "\n${COLOR_CYAN}=== 1. Native Parameter Expansion Demonstrations ===${COLOR_RESET}\n"
    
    local raw_path="/opt/enterprise/backups/archive-2026-10-07.production.tar.gz"
    
    # 1. Extraction of Directory Path (Longest suffix removal)
    local dir_path="${raw_path%/*}"
    
    # 2. Extraction of Basename (Longest prefix removal)
    local filename="${raw_path##*/}"
    
    # 3. Strip single extension vs all extensions
    local strip_gz="${filename%.gz}"
    local strip_all="${filename%%.*}"
    
    # 4. Search and Replace
    local renamed="${filename//production/staging}"
    
    # 5. String Length
    local str_len="${#raw_path}"
    
    printf "%-25s : %s\n" "Raw Path" "${raw_path}"
    printf "%-25s : %s\n" "Directory Path (\${p%/*})" "${dir_path}"
    printf "%-25s : %s\n" "Filename (\${p##*/})" "${filename}"
    printf "%-25s : %s\n" "Strip .gz (\${f%.gz})" "${strip_gz}"
    printf "%-25s : %s\n" "Strip All Exts (\${f%%.*})" "${strip_all}"
    printf "%-25s : %s\n" "Replace Substring" "${renamed}"
    printf "%-25s : %d characters\n" "Total Path Length" "${str_len}"
}

# --- Module 2: Memory Metrics & Integer Arithmetic ---
demonstrate_memory_arithmetic() {
    printf "\n${COLOR_CYAN}=== 2. Memory Utilization Arithmetic Engine ===${COLOR_RESET}\n"
    
    # Simulating 5 periodic memory samples (in Megabytes)
    local -a memory_samples=(1024 1150 1080 1220 1340)
    local total_mb=0
    local sample_count="${#memory_samples[@]}"
    local sample
    
    log_info "Processing ${sample_count} memory telemetry data points..."
    
    for sample in "${memory_samples[@]}"; do
        total_mb=$(( total_mb + sample ))
    done
    
    local avg_mb=$(( total_mb / sample_count ))
    local avg_gb_int=$(( avg_mb / 1024 ))
    local avg_gb_rem=$(( (avg_mb % 1024) * 100 / 1024 )) # 2 decimal places approximation
    
    printf "%-22s : %d MB\n" "Cumulative Total" "${total_mb}"
    printf "%-22s : %d MB\n" "Calculated Average" "${avg_mb}"
    printf "%-22s : %d.%02d GB\n" "Approximate in GB" "${avg_gb_int}" "${avg_gb_rem}"
}

# --- Module 3: Storage Partition Analysis with Indexed & Associative Arrays ---
demonstrate_partition_arrays() {
    printf "\n${COLOR_CYAN}=== 3. Storage Partition Array Aggregator ===${COLOR_RESET}\n"
    
    # Indexed array of mount points
    local -a mount_points=("/" "/var" "/home" "/opt" "/backup")
    
    # Associative array mapping mount points to simulated usage percentages
    local -A partition_usage=(
        ["/"]="45"
        ["/var"]="88"
        ["/home"]="32"
        ["/opt"]="74"
        ["/backup"]="92"
    )
    
    # Array slicing demonstration: Extract secondary partitions (skip root)
    local -a secondary_mounts=("${mount_points[@]:1:3}")
    log_info "Extracted Sub-Array (Slicing offset 1 length 3): ${secondary_mounts[*]}"
    
    printf "\n%-15s | %-12s | %-10s | %-15s\n" "Mount Point" "Used %" "Available %" "Health Status"
    printf "----------------------------------------------------------------\n"
    
    local mount
    for mount in "${mount_points[@]}"; do
        local used="${partition_usage[${mount}]}"
        local free=$(( 100 - used ))
        local status
        
        if (( used >= 90 )); then
            status="${COLOR_RED}CRITICAL${COLOR_RESET}"
        elif (( used >= 75 )); then
            status="${COLOR_YELLOW}WARNING${COLOR_RESET}"
        else
            status="${COLOR_GREEN}HEALTHY${COLOR_RESET}"
        fi
        
        printf "%-15s | %-11d%% | %-9d%% | %-15b\n" "${mount}" "${used}" "${free}" "${status}"
    done
}

# --- Module 4: Dynamic Array Appending & Bulk Operations ---
demonstrate_array_mutations() {
    printf "\n${COLOR_CYAN}=== 4. Dynamic Array Appending & Key Introspection ===${COLOR_RESET}\n"
    
    local -a cluster_nodes=("node-01" "node-02")
    log_info "Initial cluster array: ${cluster_nodes[*]}"
    
    # Append new worker nodes
    cluster_nodes+=("node-03" "node-04" "node-05")
    log_success "Expanded cluster array (+=): ${cluster_nodes[*]}"
    log_info "Total Active Cluster Nodes: ${#cluster_nodes[@]}"
    
    # Display indexed entries
    local idx
    for idx in "${!cluster_nodes[@]}"; do
        printf "Node Slot [%d] => %s\n" "${idx}" "${cluster_nodes[${idx}]}"
    done
}

# --- Main Driver ---
main() {
    log_info "Starting Arrays, Arithmetic & String Operations Demo..."
    
    demonstrate_string_operations
    demonstrate_memory_arithmetic
    demonstrate_partition_arrays
    demonstrate_array_mutations
    
    printf "\n"
    log_success "All arithmetic and data structure demonstrations completed successfully."
    return 0
}

main "$@"
