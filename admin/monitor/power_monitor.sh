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
#
#   # Report from 24/7 PowerJoular CSV (last 24h only)
#   power_monitor.sh report-from-24h <output_html> [title] [log_file] [hostname] [duration] [ipfsnodeid] [log_full_url]
#   Uses POWER_24H_CSV (default /var/lib/powerjoular/power_24h.csv) from systemd powerjoular.service
#
#   # Reliable daily/monthly/total kWh (persistent history, independent of report generation)
#   power_monitor.sh power-stats
########################################################################

set -euo pipefail

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Default paths - use /tmp/ to avoid cleanup by 20h12.process.sh
# Note: 20h12.process.sh cleans ~/.zen/tmp/ during execution
DEFAULT_CSV="/tmp/power_monitor_$$.csv"
# 24/7 PowerJoular systemd service CSV (see tools/systemd/powerjoular.service)
POWER_24H_CSV="${POWER_24H_CSV:-/var/lib/powerjoular/power_24h.csv}"
# Historique quotidien persistant (kWh/jour) — sous ~/.zen/game/ (durable, pas lié
# à IPFSNODEID) pour calculer un ratio compute/watt fiable (PAF Armateur)
POWER_HISTORY_FILE="${POWER_HISTORY_FILE:-$HOME/.zen/game/power_history.json}"

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
    
    # Remove old CSV file if exists and pre-create with current user ownership
    # This ensures powerjoular writes to a user-owned file (even when run with sudo)
    rm -f "$csv_file"
    touch "$csv_file"
    chown "$USER:$USER" "$csv_file" 2>/dev/null || true
    
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
    local ipfsnodeid="${7:-}"
    local log_full_url="${8:-}"

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
            "$title" \
            "$ipfsnodeid" \
            "$log_full_url" 2>&1 | while IFS= read -r line; do
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

# Extract last 24 hours from 24/7 PowerJoular CSV into output CSV (PowerJoular format: timestamp,power,cpu_power,gpu_power)
extract_last_24h() {
    local source_csv="$1"
    local output_csv="$2"
    if [[ -z "$source_csv" ]] || [[ -z "$output_csv" ]]; then
        log_error "extract_last_24h requires <source_csv> <output_csv>"
        return 1
    fi
    local readable_csv="$source_csv"
    if [[ ! -r "$source_csv" ]]; then
        readable_csv="/tmp/power_monitor_24h_source_$$.csv"
        if ! sudo cp "$source_csv" "$readable_csv" 2>/dev/null; then
            log_error "Cannot read 24/7 CSV (use sudo to copy): $source_csv"
            return 1
        fi
        sudo chown "$USER:$USER" "$readable_csv" 2>/dev/null || sudo chmod 644 "$readable_csv"
        trap "rm -f '$readable_csv'" RETURN
    fi
    if [[ ! -s "$readable_csv" ]]; then
        log_error "24/7 CSV is empty: $source_csv"
        return 1
    fi
    python3 - "${readable_csv}" "$output_csv" << 'PYEXTRACT'
import sys
from datetime import datetime, timedelta

if len(sys.argv) != 3:
    sys.exit(1)
in_path, out_path = sys.argv[1], sys.argv[2]
cutoff = datetime.now() - timedelta(hours=24)
out_lines = []
with open(in_path, 'r') as f:
    for i, line in enumerate(f):
        line = line.rstrip('\n')
        if not line:
            continue
        if i == 0 and (line.startswith('timestamp') or line.startswith('date') or not line[0].isdigit()):
            out_lines.append(line + '\n')
            continue
        parts = line.split(',', 1)
        if len(parts) < 2:
            continue
        try:
            ts = datetime.strptime(parts[0].strip(), '%Y-%m-%d %H:%M:%S')
        except ValueError:
            try:
                ts = datetime.strptime(parts[0].strip(), '%Y-%m-%d %H:%M:%S.%f')
            except ValueError:
                continue
        if ts >= cutoff:
            out_lines.append(line + '\n')
with open(out_path, 'w') as out_f:
    out_f.writelines(out_lines)
PYEXTRACT
}

# Enregistre le kWh du jour dans l'historique persistant, indépendamment de la
# génération du rapport HTML/graphique (fiabilité : un échec matplotlib ou jq
# sur le rapport ne doit jamais empêcher l'enregistrement de la donnée d'énergie).
# Idempotent : un second appel le même jour écrase l'entrée du jour (pas de double-compte).
record_daily_history() {
    local csv_file="$1"
    local history_file="${2:-$POWER_HISTORY_FILE}"

    if [[ "$csv_file" != /* ]]; then
        csv_file="/tmp/$csv_file"
    fi
    if [[ ! -s "$csv_file" ]]; then
        log_error "record_daily_history: CSV file not found or empty: $csv_file"
        return 1
    fi

    mkdir -p "$(dirname "$history_file")"
    [[ -s "$history_file" ]] || echo '{"since":null,"days":{}}' > "$history_file"

    # Moyenne des watts (colonne 3 = Total Power) + horodatage premier/dernier échantillon
    local stats
    stats=$(awk -F',' '
        NR>1 && $3 != "" {
            sum += $3; n++
            if (n == 1) first = $1
            last = $1
        }
        END { if (n > 0) printf "%.4f\t%d\t%s\t%s\n", sum/n, n, first, last }
    ' "$csv_file" 2>/dev/null || true)

    if [[ -z "$stats" ]]; then
        log_error "record_daily_history: no usable samples in $csv_file"
        return 1
    fi

    local avg_w n_samples first_ts last_ts
    IFS=$'\t' read -r avg_w n_samples first_ts last_ts <<< "$stats"

    if [[ -z "${n_samples:-}" || "$n_samples" -lt 2 ]]; then
        log_error "record_daily_history: insufficient samples (${n_samples:-0}) — skip"
        return 1
    fi

    # Durée réellement couverte par les échantillons (heures) — plus fiable qu'un 24h fixe
    # sur un premier jour de monitoring partiel ou après un redémarrage powerjoular.
    local hours
    hours=$(python3 -c "
from datetime import datetime
try:
    f = datetime.strptime('$first_ts', '%Y-%m-%d %H:%M:%S')
    l = datetime.strptime('$last_ts', '%Y-%m-%d %H:%M:%S')
    h = (l - f).total_seconds() / 3600
    print(f'{h:.4f}' if h > 0 else '24')
except Exception:
    print('24')
" 2>/dev/null || echo "24")
    [[ -z "$hours" ]] && hours=24

    local kwh
    kwh=$(awk -v w="$avg_w" -v h="$hours" 'BEGIN{printf "%.6f", (w*h)/1000}' 2>/dev/null || echo "0")

    local today
    today=$(date +%Y-%m-%d)

    jq --arg day "$today" \
       --argjson avg_w "$avg_w" \
       --argjson kwh "$kwh" \
       --argjson hours "$hours" \
       --argjson samples "$n_samples" \
       '.since = (.since // $day) |
        .days[$day] = {avg_w: $avg_w, kwh: $kwh, hours: $hours, samples: $samples}' \
       "$history_file" > "${history_file}.tmp" 2>/dev/null \
        && mv "${history_file}.tmp" "$history_file" \
        || { log_error "record_daily_history: jq update failed"; rm -f "${history_file}.tmp"; return 1; }

    log_info "Daily energy recorded: $today = ${kwh} kWh (avg ${avg_w} W over ${hours}h, $n_samples samples)"
}

# Agrégats fiables pour le classement swarm : kWh du jour / du mois / total depuis
# le début du monitoring, + puissance moyenne récente (30 derniers jours) pour un
# ratio compute/watt stable (pas de bruit d'un seul jour atypique).
power_stats() {
    local history_file="${1:-$POWER_HISTORY_FILE}"
    local empty='{"since":null,"today_kwh":0,"month_kwh":0,"total_kwh":0,"avg_w_recent":0,"days_recorded":0}'

    if [[ ! -s "$history_file" ]]; then
        echo "$empty"
        return 0
    fi

    local today month
    today=$(date +%Y-%m-%d)
    month=$(date +%Y-%m)

    jq -c --arg today "$today" --arg month "$month" '
        (.days[$today].kwh // 0) as $today_kwh |
        ([.days | to_entries[] | select(.key | startswith($month)) | .value.kwh] | add // 0) as $month_kwh |
        ([.days[]?.kwh] | add // 0) as $total_kwh |
        (.days | to_entries | sort_by(.key) | reverse | .[0:30] | map(.value.avg_w)) as $recent |
        {
            since: .since,
            today_kwh: $today_kwh,
            month_kwh: $month_kwh,
            total_kwh: $total_kwh,
            avg_w_recent: (if ($recent|length) > 0 then ($recent | add / length) else 0 end),
            days_recorded: (.days | length)
        }
    ' "$history_file" 2>/dev/null || echo "$empty"
}

# Generate report from 24/7 CSV (last 24h only). Uses POWER_24H_CSV.
report_from_24h() {
    local output_html="$1"
    local title="${2:-Power Consumption Report - Last 24h}"
    local log_file="${3:-}"
    local hostname="${4:-$(hostname -f)}"
    local duration="${5:-24h}"
    local ipfsnodeid="${6:-}"
    local log_full_url="${7:-}"
    local source_csv="${POWER_24H_CSV}"
    if [[ -z "$output_html" ]]; then
        log_error "Usage: power_monitor.sh report-from-24h <output_html> [title] [log_file] [hostname] [duration] [ipfsnodeid] [log_full_url]"
        return 1
    fi
    if [[ ! -f "$source_csv" ]]; then
        log_error "24/7 PowerJoular CSV not found: $source_csv (is powerjoular.service running?)"
        return 1
    fi
    local last24_csv="/tmp/power_monitor_last24h_$$.csv"
    trap "rm -f '$last24_csv'" RETURN
    log_info "Extracting last 24h from $source_csv..."
    if ! extract_last_24h "$source_csv" "$last24_csv"; then
        return 1
    fi
    local line_count=$(wc -l < "$last24_csv" 2>/dev/null || echo "0")
    if [[ "$line_count" -le 1 ]]; then
        log_error "Insufficient data in last 24h (only $line_count lines)"
        return 1
    fi
    log_info "Reporting from $line_count samples (last 24h)"

    # Enregistrement de l'historique AVANT le rapport HTML/graphique : la donnée
    # d'énergie doit rester fiable même si la génération du rapport échoue ensuite.
    record_daily_history "$last24_csv" || log_error "record_daily_history failed (non bloquant)"

    generate_report "$last24_csv" "$output_html" "$title" "$log_file" "$hostname" "$duration" "$ipfsnodeid" "$log_full_url"
}

# Trim 24/7 PowerJoular CSV to last 24h only (saves disk space). Stops powerjoular.service, overwrites CSV, restarts.
trim_24h_csv() {
    local source_csv="${1:-$POWER_24H_CSV}"
    if [[ -z "$source_csv" ]]; then
        log_error "Usage: power_monitor.sh trim-24h-csv [csv_path]"
        return 1
    fi
    if [[ ! -f "$source_csv" ]] && ! sudo test -f "$source_csv" 2>/dev/null; then
        log_error "24/7 CSV not found: $source_csv"
        return 1
    fi
    local trimmed_csv="/tmp/power_monitor_trimmed_$$.csv"
    trap "rm -f '$trimmed_csv'" RETURN
    log_info "Trimming 24/7 CSV to last 24h (to save disk space)..."
    if ! extract_last_24h "$source_csv" "$trimmed_csv"; then
        return 1
    fi
    local line_count=$(wc -l < "$trimmed_csv" 2>/dev/null || echo "0")
    if [[ "$line_count" -le 1 ]]; then
        log_error "Insufficient data to trim (only $line_count lines in last 24h)"
        return 1
    fi
    log_info "Stopping powerjoular.service to replace CSV..."
    if ! sudo systemctl stop powerjoular.service 2>/dev/null; then
        log_error "Failed to stop powerjoular.service (sudo systemctl stop powerjoular)"
        return 1
    fi
    sleep 1
    if ! sudo cp "$trimmed_csv" "$source_csv"; then
        log_error "Failed to overwrite $source_csv with trimmed data"
        sudo systemctl start powerjoular.service 2>/dev/null || true
        return 1
    fi
    log_info "Starting powerjoular.service..."
    if ! sudo systemctl start powerjoular.service; then
        log_error "Failed to start powerjoular.service"
        return 1
    fi
    log_info "Trimmed 24/7 CSV to last 24h ($line_count lines). Service restarted."
    return 0
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
        report-from-24h)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: power_monitor.sh report-from-24h <output_html> [title] [log_file] [hostname] [duration] [ipfsnodeid] [log_full_url]"
                return 1
            fi
            shift
            report_from_24h "$@"
            ;;
        trim-24h-csv)
            shift
            trim_24h_csv "$@"
            ;;
        record-daily-history)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: power_monitor.sh record-daily-history <csv_file> [history_file]"
                return 1
            fi
            shift
            record_daily_history "$@"
            ;;
        power-stats)
            shift
            power_stats "$@"
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
    
  report-from-24h <output_html> [title] [log_file] [hostname] [duration] [ipfsnodeid] [log_full_url]
    Generate report from 24/7 PowerJoular CSV (last 24h). Uses POWER_24H_CSV
    (default /var/lib/powerjoular/power_24h.csv). Requires powerjoular.service.
    
  trim-24h-csv [csv_path]
    Trim 24/7 CSV to last 24h only (saves disk). Stops powerjoular.service,
    overwrites CSV, restarts. Call after report-from-24h in 20h12. Uses POWER_24H_CSV if omitted.

  record-daily-history <csv_file> [history_file]
    Compute today's avg watts + kWh from csv_file and upsert into the persistent
    daily history (default ~/.zen/game/power_history.json). Called automatically
    by report-from-24h, independently of HTML/graph report generation.

  power-stats [history_file]
    Print JSON {since, today_kwh, month_kwh, total_kwh, avg_w_recent, days_recorded}
    aggregated from the persistent daily history.

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
