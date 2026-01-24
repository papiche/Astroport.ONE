#!/bin/bash
########################################################################
# power_monitor.sh
# Generic power consumption monitoring wrapper for PowerJoular
# 
# Usage:
#   Start monitoring:  power_monitor.sh start [output_csv]
#   Stop monitoring:   power_monitor.sh stop [csv_file]
#   Generate report:   power_monitor.sh report <csv_file> <output_html> [title] [log_file] [hostname] [duration]
#   Status:            power_monitor.sh status [csv_file]
#
# Note: PID file is automatically derived from CSV file (same path with .pid extension)
#       All files are stored in ~/.zen/tmp/ by default for consistency
#
# Examples:
#   # Start monitoring with default paths
#   power_monitor.sh start
#
#   # Start with custom CSV file (PID file auto-derived)
#   power_monitor.sh start my_process_power.csv
#
#   # Stop monitoring (using CSV file or auto-detected)
#   power_monitor.sh stop my_process_power.csv
#
#   # Generate report
#   power_monitor.sh report my_process_power.csv report.html "My Process" process.log
########################################################################

set -euo pipefail

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Default paths - use /tmp/ to avoid cleanup by 20h12.process.sh
# Note: 20h12.process.sh cleans ~/.zen/tmp/ during execution
DEFAULT_CSV="/tmp/power_monitor_$$.csv"

# Helper function to derive PID file from CSV file
get_pid_file() {
    local csv_file="$1"
    # Derive PID file from CSV: same path with .pid extension
    echo "${csv_file%.csv}.pid"
}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_info() {
    echo "[power_monitor][$(timestamp)] $*" >&2
}

log_error() {
    echo "[power_monitor][$(timestamp)] ERROR: $*" >&2
}

# Check if PowerJoular is available
check_powerjoular() {
    if ! command -v powerjoular >/dev/null 2>&1; then
        log_error "PowerJoular is not available. Please install it first."
        return 1
    fi
    return 0
}

# Start power monitoring
start_monitoring() {
    local csv_file="${1:-$DEFAULT_CSV}"
    # Ensure CSV is in /tmp/ if relative path (to avoid cleanup by 20h12.process.sh)
    if [[ "$csv_file" != /* ]]; then
        csv_file="/tmp/$csv_file"
    fi
    # Ensure directory exists
    mkdir -p "$(dirname "$csv_file")"
    # Derive PID file automatically from CSV file
    local pid_file=$(get_pid_file "$csv_file")
    
    if ! check_powerjoular; then
        return 1
    fi
    
    # Check if already running
    if [[ -f "$pid_file" ]]; then
        local existing_pid=$(cat "$pid_file" 2>/dev/null || echo "")
        if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
            log_info "Power monitoring already running (PID: $existing_pid)"
            echo "$existing_pid"
            echo "$csv_file"
            return 0
        fi
        # Stale PID file, remove it
        rm -f "$pid_file"
    fi
    
    # Remove old CSV file if exists
    rm -f "$csv_file"
    
    # Start PowerJoular in background with append mode (-f) to accumulate measurements
    log_info "Starting PowerJoular monitoring..."
    log_info "  CSV file: $csv_file"
    log_info "  PID file: $pid_file"
    
    sudo powerjoular -f "$csv_file" -t > /dev/null 2>&1 &
    local powerjoular_pid=$!
    
    # Save PID
    echo "$powerjoular_pid" > "$pid_file"
    
    # Wait a moment to ensure PowerJoular started successfully
    sleep 2
    
    # Verify it's still running
    if ! kill -0 "$powerjoular_pid" 2>/dev/null; then
        log_error "PowerJoular failed to start"
        rm -f "$pid_file" "$csv_file"
        return 1
    fi
    
    log_info "PowerJoular started successfully (PID: $powerjoular_pid)"
    echo "$powerjoular_pid"
    echo "$csv_file"
    return 0
}

# Stop power monitoring
stop_monitoring() {
    local input_file="${1:-}"
    local pid_file=""
    
    # If input is a CSV file, derive PID file from it
    if [[ -n "$input_file" ]]; then
        if [[ "$input_file" == *.csv ]]; then
            # Ensure path is absolute (handle relative paths - use /tmp to avoid cleanup)
            if [[ "$input_file" != /* ]]; then
                input_file="/tmp/$input_file"
            fi
            pid_file=$(get_pid_file "$input_file")
        else
            # Assume it's a PID file (legacy support)
            pid_file="$input_file"
        fi
    else
        # Try to find PID file from default CSV
        pid_file=$(get_pid_file "$DEFAULT_CSV")
    fi
    
    if [[ ! -f "$pid_file" ]]; then
        log_info "No PID file found: $pid_file (monitoring may not be running)"
        return 0
    fi
    
    local powerjoular_pid=$(cat "$pid_file" 2>/dev/null || echo "")
    
    if [[ -z "$powerjoular_pid" ]]; then
        log_info "PID file is empty: $pid_file"
        rm -f "$pid_file"
        return 0
    fi
    
    if ! kill -0 "$powerjoular_pid" 2>/dev/null; then
        log_info "PowerJoular process (PID: $powerjoular_pid) is not running"
        rm -f "$pid_file"
        return 0
    fi
    
    log_info "Stopping PowerJoular monitoring (PID: $powerjoular_pid)..."
    sudo kill "$powerjoular_pid" 2>/dev/null || true
    sleep 1
    
    # Verify it stopped
    if kill -0 "$powerjoular_pid" 2>/dev/null; then
        log_error "Failed to stop PowerJoular, trying SIGKILL..."
        sudo kill -9 "$powerjoular_pid" 2>/dev/null || true
        sleep 1
    fi
    
    rm -f "$pid_file"
    log_info "PowerJoular stopped"
    return 0
}

# Get monitoring status
get_status() {
    local input_file="${1:-}"
    local pid_file=""
    
    # If input is a CSV file, derive PID file from it
    if [[ -n "$input_file" ]]; then
        if [[ "$input_file" == *.csv ]]; then
            # Ensure path is absolute (handle relative paths - use /tmp to avoid cleanup)
            if [[ "$input_file" != /* ]]; then
                input_file="/tmp/$input_file"
            fi
            pid_file=$(get_pid_file "$input_file")
        else
            # Assume it's a PID file (legacy support)
            pid_file="$input_file"
        fi
    else
        # Try to find PID file from default CSV
        pid_file=$(get_pid_file "$DEFAULT_CSV")
    fi
    
    if [[ ! -f "$pid_file" ]]; then
        echo "NOT_RUNNING"
        return 0
    fi
    
    local powerjoular_pid=$(cat "$pid_file" 2>/dev/null || echo "")
    
    if [[ -z "$powerjoular_pid" ]]; then
        echo "NOT_RUNNING"
        return 0
    fi
    
    if kill -0 "$powerjoular_pid" 2>/dev/null; then
        echo "RUNNING:$powerjoular_pid"
        return 0
    else
        echo "NOT_RUNNING"
        rm -f "$pid_file"
        return 0
    fi
}

# Generate power consumption report
generate_report() {
    local csv_file="$1"
    local output_html="$2"
    local title="${3:-Power Consumption Report}"
    local log_file="${4:-}"
    local hostname="${5:-$(hostname -f)}"
    local duration="${6:-}"
    
    # Ensure CSV path is absolute (handle relative paths - use /tmp to avoid cleanup)
    if [[ "$csv_file" != /* ]]; then
        csv_file="/tmp/$csv_file"
    fi
    
    if [[ ! -f "$csv_file" ]] || [[ ! -s "$csv_file" ]]; then
        log_error "CSV file not found or empty: $csv_file"
        return 1
    fi
    
    # Count lines in CSV (should be > 1 for valid data)
    local line_count=$(wc -l < "$csv_file" 2>/dev/null || echo "0")
    
    if [[ "$line_count" -le 1 ]]; then
        log_error "CSV file has insufficient data (only $line_count lines)"
        return 1
    fi
    
    log_info "Generating power consumption report..."
    log_info "  CSV: $csv_file"
    log_info "  Output: $output_html"
    log_info "  Title: $title"
    
    # Generate graph first
    local graph_file="${output_html%.html}.png"
    if command -v python3 >/dev/null 2>&1 && [[ -f "${MY_PATH}/generate_powerjoular_graph.py" ]]; then
        python3 "${MY_PATH}/generate_powerjoular_graph.py" \
            "$csv_file" \
            "$graph_file" \
            "$title - $hostname" 2>&1 | while IFS= read -r line; do
                log_info "$line"
            done
    else
        log_error "Python3 or generate_powerjoular_graph.py not available"
        graph_file=""
    fi
    
    # Generate HTML report
    if [[ -f "${MY_PATH}/generate_power_report.sh" ]]; then
        "${MY_PATH}/generate_power_report.sh" \
            "$csv_file" \
            "${graph_file:-}" \
            "${log_file:-/dev/null}" \
            "$output_html" \
            "$hostname" \
            "$duration" \
            "$title" 2>&1 | while IFS= read -r line; do
                log_info "$line"
            done
    else
        log_error "generate_power_report.sh not found"
        return 1
    fi
    
    if [[ -f "$output_html" ]]; then
        log_info "Report generated successfully: $output_html"
        return 0
    else
        log_error "Failed to generate report"
        return 1
    fi
}

# Main command dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        start)
            shift
            start_monitoring "$@"
            ;;
        stop)
            shift
            stop_monitoring "$@"
            ;;
        status)
            shift
            get_status "$@"
            ;;
        report)
            if [[ $# -lt 3 ]]; then
                log_error "Usage: power_monitor.sh report <csv_file> <output_html> [title] [log_file] [hostname] [duration]"
                return 1
            fi
            shift
            generate_report "$@"
            ;;
        help|--help|-h)
            cat << EOF
Power Monitor - Generic power consumption monitoring wrapper

Usage:
  power_monitor.sh <command> [options]

Commands:
  start [csv_file]
    Start power monitoring. PID file is automatically derived from CSV file.
    Returns PID and CSV file path.
    Default CSV: ~/.zen/tmp/power_monitor_$$.csv
    
  stop [csv_file]
    Stop power monitoring. Can use CSV file (PID file auto-detected) or omit for default.
    
  status [csv_file]
    Get monitoring status (RUNNING:PID or NOT_RUNNING).
    Can use CSV file (PID file auto-detected) or omit for default.
    
  report <csv_file> <output_html> [title] [log_file] [hostname] [duration]
    Generate HTML report with power consumption graph.

Examples:
  # Start monitoring with default paths
  PID_CSV=\$(power_monitor.sh start)
  PID=\$(echo "\$PID_CSV" | head -1)
  CSV=\$(echo "\$PID_CSV" | tail -1)
  
  # Do your work...
  
  # Stop monitoring (using CSV file)
  power_monitor.sh stop "\$CSV"
  
  # Generate report
  power_monitor.sh report "\$CSV" report.html "My Process" process.log
  
  # Or with custom CSV file (PID file auto-derived)
  power_monitor.sh start my_process_power.csv
  power_monitor.sh stop my_process_power.csv
  power_monitor.sh report my_process_power.csv report.html "Custom Process"

Note:
  - PID files are automatically derived from CSV files (same path, .pid extension)
  - All files default to ~/.zen/tmp/ for consistency with Astroport.ONE
  - No need to manage PID files manually
EOF
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use 'power_monitor.sh help' for usage information" >&2
            return 1
            ;;
    esac
}

main "$@"
