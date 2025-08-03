#!/bin/bash

# uMARKET System Monitor
# Monitors the health and performance of the uMARKET system

set -e

# Configuration
LOG_FILE="/tmp/flashmem/umarket_monitor.log"
ALERT_EMAIL="admin@uplanet.com"
MAX_ERROR_RATE=0.1  # 10% error rate threshold
MAX_PROCESSING_TIME=300  # 5 minutes max processing time

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Alert function
send_alert() {
    local message="$1"
    local severity="$2"
    
    log_message "[$severity] $message"
    
    # In a real environment, you would send email/SMS here
    echo -e "${RED}[ALERT] $message${NC}" >&2
}

# Check system dependencies
check_dependencies() {
    local missing_deps=()
    
    [[ ! -x $(command -v jq) ]] && missing_deps+=("jq")
    [[ ! -x $(command -v ipfs) ]] && missing_deps+=("ipfs")
    [[ ! -x $(command -v wget) ]] && missing_deps+=("wget")
    [[ ! -x $(command -v file) ]] && missing_deps+=("file")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        send_alert "Missing dependencies: ${missing_deps[*]}" "CRITICAL"
        return 1
    fi
    
    log_message "✅ All dependencies available"
    return 0
}

# Check IPFS node status
check_ipfs_status() {
    if ! ipfs id >/dev/null 2>&1; then
        send_alert "IPFS node is not running" "CRITICAL"
        return 1
    fi
    
    local peers=$(ipfs swarm peers | wc -l)
    if [[ $peers -lt 5 ]]; then
        send_alert "Low IPFS peer count: $peers" "WARNING"
    else
        log_message "✅ IPFS node healthy with $peers peers"
    fi
    
    return 0
}

# Check uMARKET directories
check_umarket_directories() {
    local umap_count=0
    local market_count=0
    local error_count=0
    
    # Count UMAPs with market data
    while IFS= read -r -d '' umap_path; do
        ((umap_count++))
        if [[ -d "$umap_path/APP/uMARKET" ]]; then
            ((market_count++))
            
            # Check for errors in market data
            if [[ -d "$umap_path/APP/uMARKET/ads" ]]; then
                local json_errors=0
                while IFS= read -r -d '' json_file; do
                    if ! jq . "$json_file" >/dev/null 2>&1; then
                        ((json_errors++))
                        ((error_count++))
                    fi
                done < <(find "$umap_path/APP/uMARKET/ads" -name "*.json" -print0 2>/dev/null)
                
                if [[ $json_errors -gt 0 ]]; then
                    send_alert "Found $json_errors invalid JSON files in $umap_path" "WARNING"
                fi
            fi
            
            # Check for orphaned images
            if [[ -d "$umap_path/APP/uMARKET/Images" ]]; then
                local orphaned_images=0
                while IFS= read -r -d '' image; do
                    local image_name=$(basename "$image")
                    local referenced=false
                    
                    while IFS= read -r -d '' json_file; do
                        if jq -e --arg img "$image_name" '.local_images[] | select(. == $img)' "$json_file" >/dev/null 2>&1; then
                            referenced=true
                            break
                        fi
                    done < <(find "$umap_path/APP/uMARKET/ads" -name "*.json" -print0 2>/dev/null)
                    
                    if [[ "$referenced" == false ]]; then
                        ((orphaned_images++))
                    fi
                done < <(find "$umap_path/APP/uMARKET/Images" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -print0 2>/dev/null)
                
                if [[ $orphaned_images -gt 0 ]]; then
                    send_alert "Found $orphaned_images orphaned images in $umap_path" "WARNING"
                fi
            fi
        fi
    done < <(find ~/.zen/tmp -path "*/UPLANET/*/*/*" -name "HEX" -print0 2>/dev/null)
    
    log_message "📊 UMAP Statistics:"
    log_message "   - Total UMAPs: $umap_count"
    log_message "   - UMAPs with market data: $market_count"
    log_message "   - Total errors found: $error_count"
    
    if [[ $error_count -gt 0 ]]; then
        local error_rate=$(echo "scale=2; $error_count / $market_count" | bc -l 2>/dev/null || echo "0")
        if (( $(echo "$error_rate > $MAX_ERROR_RATE" | bc -l) )); then
            send_alert "High error rate: ${error_rate}%" "CRITICAL"
        fi
    fi
    
    return 0
}

# Check recent market activity
check_recent_activity() {
    local recent_ads=0
    local recent_images=0
    local one_day_ago=$(date -d "24 hours ago" +%s)
    
    # Count recent advertisements
    while IFS= read -r -d '' json_file; do
        local created_at=$(jq -r '.created_at' "$json_file" 2>/dev/null)
        if [[ "$created_at" =~ ^[0-9]+$ ]] && [[ $created_at -gt $one_day_ago ]]; then
            ((recent_ads++))
        fi
    done < <(find ~/.zen/tmp -path "*/UPLANET/*/*/*/APP/uMARKET/ads/*.json" -print0 2>/dev/null)
    
    # Count recent images
    while IFS= read -r -d '' image; do
        local image_time=$(stat -c %Y "$image" 2>/dev/null || echo "0")
        if [[ $image_time -gt $one_day_ago ]]; then
            ((recent_images++))
        fi
    done < <(find ~/.zen/tmp -path "*/UPLANET/*/*/*/APP/uMARKET/Images/*" -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" \) -print0 2>/dev/null)
    
    log_message "📈 Recent Activity (24h):"
    log_message "   - New advertisements: $recent_ads"
    log_message "   - New images: $recent_images"
    
    if [[ $recent_ads -eq 0 ]]; then
        send_alert "No recent market activity detected" "WARNING"
    fi
    
    return 0
}

# Check disk usage
check_disk_usage() {
    local umarket_paths=()
    local total_size=0
    
    while IFS= read -r -d '' path; do
        umarket_paths+=("$path")
        local size=$(du -sb "$path" 2>/dev/null | cut -f1 || echo "0")
        total_size=$((total_size + size))
    done < <(find ~/.zen/tmp -path "*/UPLANET/*/*/*/APP/uMARKET" -type d -print0 2>/dev/null)
    
    local total_size_mb=$((total_size / 1024 / 1024))
    log_message "💾 Disk Usage:"
    log_message "   - Total uMARKET data: ${total_size_mb} MB"
    log_message "   - Number of market directories: ${#umarket_paths[@]}"
    
    if [[ $total_size_mb -gt 1000 ]]; then
        send_alert "High disk usage: ${total_size_mb} MB" "WARNING"
    fi
    
    return 0
}

# Check processing performance
check_processing_performance() {
    local start_time=$(date +%s)
    
    # Simulate a small processing task
    local test_dir="/tmp/umarket_performance_test"
    mkdir -p "$test_dir/ads"
    
    # Create a test advertisement
    cat > "$test_dir/ads/test.json" << 'EOF'
{
    "id": "test_performance",
    "content": "Test advertisement",
    "author_pubkey": "test",
    "created_at": 1703000000,
    "location": {"lat": 0, "lon": 0},
    "local_images": [],
    "umap_id": "test"
}
EOF
    
    # Test _uMARKET.generate.sh performance
    local script_path="$HOME/.zen/Astroport.ONE/tools/_uMARKET.generate.sh"
    if [[ -x "$script_path" ]]; then
        cd "$test_dir"
        local processing_start=$(date +%s)
        if "$script_path" . >/dev/null 2>&1; then
            local processing_end=$(date +%s)
            local processing_time=$((processing_end - processing_start))
            
            log_message "⚡ Performance Test:"
            log_message "   - Processing time: ${processing_time}s"
            
            if [[ $processing_time -gt $MAX_PROCESSING_TIME ]]; then
                send_alert "Slow processing time: ${processing_time}s" "WARNING"
            fi
        else
            send_alert "Performance test failed" "ERROR"
        fi
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    local end_time=$(date +%s)
    local total_time=$((end_time - start_time))
    log_message "⏱️  Total monitoring time: ${total_time}s"
    
    return 0
}

# Generate health report
generate_health_report() {
    local report_file="/tmp/umarket_health_report_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "=== uMARKET System Health Report ==="
        echo "Generated: $(date)"
        echo ""
        echo "=== System Status ==="
        echo "Dependencies: $(check_dependencies >/dev/null && echo "OK" || echo "FAILED")"
        echo "IPFS Status: $(check_ipfs_status >/dev/null && echo "OK" || echo "FAILED")"
        echo ""
        echo "=== Statistics ==="
        check_umarket_directories >/dev/null
        echo ""
        echo "=== Recent Activity ==="
        check_recent_activity >/dev/null
        echo ""
        echo "=== Resource Usage ==="
        check_disk_usage >/dev/null
        echo ""
        echo "=== Performance ==="
        check_processing_performance >/dev/null
        echo ""
        echo "=== Log Summary ==="
        tail -n 20 "$LOG_FILE" 2>/dev/null || echo "No log file found"
    } > "$report_file"
    
    log_message "📋 Health report generated: $report_file"
    echo "$report_file"
}

# Main monitoring function
main() {
    log_message "🔍 Starting uMARKET system monitoring..."
    
    # Run all checks
    check_dependencies
    check_ipfs_status
    check_umarket_directories
    check_recent_activity
    check_disk_usage
    check_processing_performance
    
    log_message "✅ Monitoring completed"
    
    # Generate report if requested
    if [[ "$1" == "--report" ]]; then
        generate_health_report
    fi
}

# Show help
show_help() {
    cat << 'HELP_EOF'
🛒 uMARKET System Monitor

USAGE:
    ./_uMARKET.monitor.sh [OPTIONS]

OPTIONS:
    --report     Generate detailed health report
    --help       Show this help message

DESCRIPTION:
    Monitors the health and performance of the uMARKET system,
    checking dependencies, data integrity, and system performance.

EXAMPLES:
    ./_uMARKET.monitor.sh              # Run basic monitoring
    ./_uMARKET.monitor.sh --report     # Generate detailed report

HELP_EOF
}

# Parse arguments
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --report)
        main --report
        ;;
    "")
        main
        ;;
    *)
        echo "❌ Unknown option: $1" >&2
        show_help
        exit 1
        ;;
esac 