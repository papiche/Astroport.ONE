#!/bin/bash

# Global uMARKET Deployment Script
# Integrates global aggregation into the UPlanet workflow

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRON_JOB_NAME="global_umarket_aggregation"
LOG_FILE="/tmp/flashmem/global_umarket_deploy.log"

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

# Show help
show_help() {
    cat << 'HELP_EOF'
🌐 Global uMARKET Deployment Script

USAGE:
    ./_uMARKET.deploy_global.sh [OPTIONS]

OPTIONS:
    --install        Install global uMARKET aggregation
    --uninstall      Remove global uMARKET aggregation
    --status         Check deployment status
    --test           Run a test aggregation
    --schedule HOURS Set aggregation schedule in hours (default: 6)
    --help           Show this help message

DESCRIPTION:
    Deploys the global uMARKET aggregation system into the UPlanet workflow.
    This script integrates automatic aggregation of local and swarm market data.

EXAMPLES:
    ./_uMARKET.deploy_global.sh --install           # Install with default 6h schedule
    ./_uMARKET.deploy_global.sh --install --schedule 2  # Install with 2h schedule
    ./_uMARKET.deploy_global.sh --status            # Check current status
    ./_uMARKET.deploy_global.sh --test              # Run test aggregation
    ./_uMARKET.deploy_global.sh --uninstall         # Remove deployment

HELP_EOF
}

# Check if script is run as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo "❌ This script should not be run as root" >&2
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    [[ ! -f "$SCRIPT_DIR/_uMARKET.aggregate.sh" ]] && missing_deps+=("_uMARKET.aggregate.sh")
    [[ ! -f "$SCRIPT_DIR/_uMARKET.monitor.sh" ]] && missing_deps+=("_uMARKET.monitor.sh")
    [[ ! -x $(command -v crontab) ]] && missing_deps+=("crontab")
    [[ ! -x $(command -v ipfs) ]] && missing_deps+=("ipfs")
    [[ ! -x $(command -v jq) ]] && missing_deps+=("jq")
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo "❌ Missing dependencies: ${missing_deps[*]}" >&2
        exit 1
    fi
    
    log_message "✅ All dependencies available"
}

# Create system directories
create_directories() {
    mkdir -p /tmp/flashmem
    mkdir -p ~/.zen/tmp/umarket_global
    mkdir -p ~/.zen/logs
    
    log_message "✅ System directories created"
}

# Create aggregation script
create_aggregation_script() {
    local schedule_hours="${1:-6}"
    local script_path="$HOME/.zen/scripts/run_global_umarket.sh"
    
    mkdir -p "$(dirname "$script_path")"
    
    cat > "$script_path" << 'SCRIPT_EOF'
#!/bin/bash

# Global uMARKET Aggregation Runner
# This script is called by cron to run global aggregation

set -e

# Configuration
SCRIPT_DIR="$HOME/.zen/Astroport.ONE/tools"
LOG_FILE="/tmp/flashmem/global_umarket.log"
OUTPUT_DIR="/tmp/flashmem/umarket_global"
LOCK_FILE="/tmp/flashmem/global_umarket.lock"

# Prevent multiple instances
if [[ -f "$LOCK_FILE" ]]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
    if [[ -n "$PID" ]] && kill -0 "$PID" 2>/dev/null; then
        echo "$(date): Another aggregation is already running (PID: $PID)" >> "$LOG_FILE"
        exit 0
    else
        rm -f "$LOCK_FILE"
    fi
fi

echo $$ > "$LOCK_FILE"

# Log start
echo "$(date): Starting global uMARKET aggregation" >> "$LOG_FILE"

# Run aggregation
    if "$SCRIPT_DIR/_uMARKET.aggregate.sh" --output "$OUTPUT_DIR" --verbose >> "$LOG_FILE" 2>&1; then
    echo "$(date): Global aggregation completed successfully" >> "$LOG_FILE"
    
    # Get the CID
    if [[ -f "$OUTPUT_DIR/public/market.json" ]]; then
        CID=$(ipfs add -r "$OUTPUT_DIR" | tail -n1 | awk '{print $2}' 2>/dev/null || echo "")
        if [[ -n "$CID" ]]; then
            echo "$(date): Published to IPFS: $CID" >> "$LOG_FILE"
            
            # Update the global marketplace link
            echo "$CID" > "$HOME/.zen/tmp/global_umarket.cid"
            
            # Optional: Publish to IPNS for persistent access
            # ipfs name publish "$CID" >> "$LOG_FILE" 2>&1 || true
        fi
    fi
else
    echo "$(date): Global aggregation failed" >> "$LOG_FILE"
    exit 1
fi

# Cleanup lock file
rm -f "$LOCK_FILE"

# Log completion
echo "$(date): Global uMARKET aggregation finished" >> "$LOG_FILE"
SCRIPT_EOF

    chmod +x "$script_path"
    log_message "✅ Aggregation script created: $script_path"
}

# Install cron job
install_cron_job() {
    local schedule_hours="${1:-6}"
    local script_path="$HOME/.zen/scripts/run_global_umarket.sh"
    
    # Calculate cron schedule (every N hours)
    local cron_schedule="0 */$schedule_hours * * *"
    
    # Create temporary crontab
    (crontab -l 2>/dev/null | grep -v "$CRON_JOB_NAME"; echo "$cron_schedule $script_path # $CRON_JOB_NAME") | crontab -
    
    log_message "✅ Cron job installed with schedule: every $schedule_hours hours"
    log_message "📅 Cron schedule: $cron_schedule"
}

# Remove cron job
remove_cron_job() {
    (crontab -l 2>/dev/null | grep -v "$CRON_JOB_NAME") | crontab -
    log_message "✅ Cron job removed"
}

# Check deployment status
check_status() {
    echo "🔍 Checking Global uMARKET deployment status..."
    echo ""
    
    # Check if aggregation script exists
    local script_path="$HOME/.zen/scripts/run_global_umarket.sh"
    if [[ -f "$script_path" ]]; then
        echo "✅ Aggregation script: $script_path"
    else
        echo "❌ Aggregation script: Not found"
    fi
    
    # Check if cron job is installed
    if crontab -l 2>/dev/null | grep -q "$CRON_JOB_NAME"; then
        echo "✅ Cron job: Installed"
        local cron_line=$(crontab -l 2>/dev/null | grep "$CRON_JOB_NAME")
        echo "📅 Schedule: $cron_line"
    else
        echo "❌ Cron job: Not installed"
    fi
    
    # Check if global marketplace exists
    if [[ -f "$HOME/.zen/tmp/global_umarket.cid" ]]; then
        local cid=$(cat "$HOME/.zen/tmp/global_umarket.cid")
        echo "✅ Global marketplace: $cid"
        echo "🌐 Access: http://127.0.0.1:8080/ipfs/$cid/"
    else
        echo "❌ Global marketplace: Not found"
    fi
    
    # Check recent logs
    if [[ -f "/tmp/flashmem/global_umarket.log" ]]; then
        echo ""
        echo "📋 Recent log entries:"
        tail -n 5 "/tmp/flashmem/global_umarket.log" 2>/dev/null || echo "No recent logs"
    fi
    
    # Check system health
    echo ""
    echo "🏥 System health check:"
    if [[ -f "$SCRIPT_DIR/_uMARKET.monitor.sh" ]]; then
        "$SCRIPT_DIR/_uMARKET.monitor.sh" 2>/dev/null | head -n 10 || echo "Health check failed"
    else
        echo "❌ Monitor script not found"
    fi
}

# Run test aggregation
run_test() {
    echo "🧪 Running test aggregation..."
    
    if [[ ! -f "$SCRIPT_DIR/_uMARKET.aggregate.sh" ]]; then
        echo "❌ _uMARKET.aggregate.sh not found" >&2
        exit 1
    fi
    
    # Run test aggregation
    local test_output="/tmp/flashmem/test_global_umarket"
    local cid=$("$SCRIPT_DIR/_uMARKET.aggregate.sh" --output "$test_output" --verbose)
    
    if [[ -n "$cid" ]]; then
        echo "✅ Test aggregation successful"
        echo "📊 CID: $cid"
        echo "🌐 Test access: http://127.0.0.1:8080/ipfs/$cid/"
        
        # Show statistics
        if [[ -f "$test_output/public/market.json" ]]; then
            local ad_count=$(jq '.ads | length' "$test_output/public/market.json" 2>/dev/null || echo "0")
            echo "📈 Advertisements found: $ad_count"
        fi
        
        # Cleanup test data
        rm -rf "$test_output"
    else
        echo "❌ Test aggregation failed" >&2
        exit 1
    fi
}

# Install deployment
install_deployment() {
    local schedule_hours="${1:-6}"
    
    log_message "🚀 Installing Global uMARKET deployment..."
    
    check_root
    check_dependencies
    create_directories
    create_aggregation_script "$schedule_hours"
    install_cron_job "$schedule_hours"
    
    # Run initial aggregation
    log_message "🔄 Running initial aggregation..."
    if run_test >/dev/null 2>&1; then
        log_message "✅ Initial aggregation successful"
    else
        log_message "⚠️  Initial aggregation failed, but deployment completed"
    fi
    
    log_message "🎉 Global uMARKET deployment completed successfully!"
    log_message "📅 Next aggregation in $schedule_hours hours"
    log_message "📋 Check status with: $0 --status"
}

# Uninstall deployment
uninstall_deployment() {
    log_message "🗑️  Uninstalling Global uMARKET deployment..."
    
    remove_cron_job
    
    # Remove aggregation script
    local script_path="$HOME/.zen/scripts/run_global_umarket.sh"
    if [[ -f "$script_path" ]]; then
        rm -f "$script_path"
        log_message "✅ Aggregation script removed"
    fi
    
    # Remove global marketplace CID
    if [[ -f "$HOME/.zen/tmp/global_umarket.cid" ]]; then
        rm -f "$HOME/.zen/tmp/global_umarket.cid"
        log_message "✅ Global marketplace CID removed"
    fi
    
    log_message "✅ Global uMARKET deployment uninstalled"
}

# Main function
main() {
    local action=""
    local schedule_hours=6
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                action="install"
                shift
                ;;
            --uninstall)
                action="uninstall"
                shift
                ;;
            --status)
                action="status"
                shift
                ;;
            --test)
                action="test"
                shift
                ;;
            --schedule)
                schedule_hours="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "❌ Unknown option: $1" >&2
                show_help
                exit 1
                ;;
        esac
    done
    
    # Default action
    if [[ -z "$action" ]]; then
        action="status"
    fi
    
    # Execute action
    case "$action" in
        install)
            install_deployment "$schedule_hours"
            ;;
        uninstall)
            uninstall_deployment
            ;;
        status)
            check_status
            ;;
        test)
            run_test
            ;;
        *)
            echo "❌ Unknown action: $action" >&2
            exit 1
            ;;
    esac
}

# Run main function
main "$@" 