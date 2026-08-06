#!/usr/bin/env bash
# ==============================================================================
# Script Name: 06_Text_Processing_Grep_Sed_Awk_script.sh
# Description: Web Server Access Log Analyzer & Anomaly Reporter
# Capabilities: Grep filtering, Sed sanitization, Awk metrics aggregation & cut slicing
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

# --- Temporary File Cleanup Handler ---
TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t 'log_analyzer')"
cleanup() {
    if [[ -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
}
trap cleanup EXIT

# --- Helper: Generate Mock Access Log ---
generate_mock_log() {
    local target_file="$1"
    log_info "Generating synthetic Nginx/Apache Combined Access Log: ${target_file}"
    
    cat << 'EOF' > "${target_file}"
192.168.1.10 - - [10/Oct/2026:13:55:36 +0000] "GET /index.html HTTP/1.1" 200 4523 "-" "Mozilla/5.0"
192.168.1.15 - - [10/Oct/2026:13:55:37 +0000] "POST /api/v1/login HTTP/1.1" 200 892 "-" "PostmanRuntime/7.28.4"
192.168.1.10 - - [10/Oct/2026:13:55:38 +0000] "GET /static/css/style.css HTTP/1.1" 200 12053 "http://example.com/index.html" "Mozilla/5.0"
10.0.0.45 - - [10/Oct/2026:13:55:39 +0000] "GET /admin.php HTTP/1.1" 404 153 "-" "sqlmap/1.5.2"
192.168.1.10 - - [10/Oct/2026:13:55:40 +0000] "GET /dashboard HTTP/1.1" 200 18450 "http://example.com/index.html" "Mozilla/5.0"
10.0.0.45 - - [10/Oct/2026:13:55:41 +0000] "GET /wp-login.php HTTP/1.1" 404 153 "-" "sqlmap/1.5.2"
172.16.0.99 - - [10/Oct/2026:13:55:42 +0000] "POST /api/v1/checkout HTTP/1.1" 500 241 "-" "Mozilla/5.0"
192.168.1.20 - - [10/Oct/2026:13:55:43 +0000] "GET /products/widget HTTP/1.1" 200 6340 "-" "Mozilla/5.0"
172.16.0.99 - - [10/Oct/2026:13:55:44 +0000] "POST /api/v1/checkout HTTP/1.1" 500 241 "-" "Mozilla/5.0"
10.0.0.45 - - [10/Oct/2026:13:55:45 +0000] "GET /.env HTTP/1.1" 403 272 "-" "Nikto/2.1.6"
192.168.1.15 - - [10/Oct/2026:13:55:46 +0000] "GET /api/v1/user/profile HTTP/1.1" 200 3210 "-" "PostmanRuntime/7.28.4"
10.0.0.45 - - [10/Oct/2026:13:55:47 +0000] "GET /etc/passwd HTTP/1.1" 400 312 "-" "Nikto/2.1.6"
192.168.1.10 - - [10/Oct/2026:13:55:48 +0000] "GET /static/js/bundle.js HTTP/1.1" 200 48210 "http://example.com/dashboard" "Mozilla/5.0"
172.16.0.99 - - [10/Oct/2026:13:55:49 +0000] "POST /api/v1/checkout HTTP/1.1" 500 241 "-" "Mozilla/5.0"
EOF
    log_success "Mock log created with $(wc -l < "${target_file}" | tr -d ' ') records."
}

# --- Module 1: HTTP Status Code Breakdown via Awk ---
analyze_status_codes() {
    local log_file="$1"
    printf "\n${COLOR_CYAN}=== 1. HTTP Status Code Distribution (Awk Grouping) ===${COLOR_RESET}\n"
    
    awk '
    {
        status = $9;
        count[status]++;
        bytes[status] += $10;
        total_requests++;
    }
    END {
        printf "%-12s | %-10s | %-12s | %-10s\n", "Status Code", "Requests", "Bandwidth", "Share"
        printf "--------------------------------------------------------\n"
        for (s in count) {
            pct = (count[s] / total_requests) * 100;
            printf "HTTP %-7s | %-10d | %-9.2f KB | %-5.1f%%\n", s, count[s], bytes[s]/1024, pct;
        }
        printf "--------------------------------------------------------\n"
        printf "Total: %d requests analyzed.\n", total_requests
    }' "${log_file}"
}

# --- Module 2: Unique Client IPs & Traffic Slicing via Cut & Sort ---
analyze_top_clients() {
    local log_file="$1"
    printf "\n${COLOR_CYAN}=== 2. Top Client IP Addresses (Cut + Sort + Uniq) ===${COLOR_RESET}\n"
    
    printf "%-8s | %-18s\n" "Hits" "Client IP"
    printf "------------------------------\n"
    cut -d ' ' -f 1 "${log_file}" | sort | uniq -c | sort -rn | while read -r hits ip; do
        printf "%-8d | %-18s\n" "${hits}" "${ip}"
    done
}

# --- Module 3: Security Anomaly Detection via Grep (4xx & 5xx) ---
extract_anomalies() {
    local log_file="$1"
    printf "\n${COLOR_CYAN}=== 3. Security Anomalies & Failures (Grep ERE Filter) ===${COLOR_RESET}\n"
    
    local client_errors server_errors
    client_errors=$(grep -cE ' " [4][0-9]{2} ' "${log_file}" || true)
    server_errors=$(grep -cE ' " [5][0-9]{2} ' "${log_file}" || true)
    
    log_warn "Client Error Responses (4xx): ${client_errors}"
    log_warn "Server Internal Errors (5xx): ${server_errors}"
    
    printf "\n${COLOR_BOLD}Extracted Critical Incidents (Status >= 400):${COLOR_RESET}\n"
    grep -E ' " [45][0-9]{2} ' "${log_file}" | \
        sed -E 's/^([0-9.]+) .* "([A-Z]+ [^"]+)" ([0-9]{3}) ([0-9]+) .*$/[IP: \1] Status: \3 | Request: \2 | Bytes: \4/'
}

# --- Module 4: URL Sanitization & Path Analysis via Sed ---
analyze_endpoints() {
    local log_file="$1"
    printf "\n${COLOR_CYAN}=== 4. Endpoint Frequency (Sed Extraction + Awk) ===${COLOR_RESET}\n"
    
    # Extract HTTP Method and Path using Sed substitution
    sed -nE 's/.*"([A-Z]+) ([^ ?]+).*" ([0-9]+) .*/\1 \2 \3/p' "${log_file}" | \
    awk '
    {
        endpoint = $1 " " $2;
        count[endpoint]++;
    }
    END {
        printf "%-10s | %-35s | %-6s\n", "Method", "URI Path", "Hits"
        printf "--------------------------------------------------------\n"
        for (ep in count) {
            split(ep, parts, " ");
            printf "%-10s | %-35s | %-6d\n", parts[1], parts[2], count[ep];
        }
    }'
}

# --- Main Driver ---
main() {
    log_info "Initializing Web Server Text Processing Engine..."
    
    local input_file="${1:-}"
    if [[ -z "${input_file}" ]] || [[ ! -f "${input_file}" ]]; then
        input_file="${TMP_DIR}/access.log"
        generate_mock_log "${input_file}"
    else
        log_info "Reading existing access log: ${input_file}"
    fi
    
    analyze_status_codes "${input_file}"
    analyze_top_clients "${input_file}"
    analyze_endpoints "${input_file}"
    extract_anomalies "${input_file}"
    
    printf "\n"
    log_success "Log analysis pipeline completed successfully."
    return 0
}

main "$@"
