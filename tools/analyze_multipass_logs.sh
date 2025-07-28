#!/bin/bash
################################################################################
# analyze_multipass_logs.sh
# Analyze NOSTR MULTIPASS logs for debugging and monitoring
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

LOGFILE="$HOME/.zen/tmp/nostr_multipass.log"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --tail N        Show last N lines (default: 50)"
    echo "  -e, --errors        Show only errors and warnings"
    echo "  -m, --metrics       Show metrics summary"
    echo "  -p, --player EMAIL  Show logs for specific player"
    echo "  -s, --summary       Show execution summary"
    echo "  -w, --watch         Watch logs in real time"
    echo "  -h, --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --tail 100                    # Show last 100 lines"
    echo "  $0 --errors                      # Show only errors"
    echo "  $0 --player user@example.com     # Show logs for specific user"
    echo "  $0 --metrics                     # Show performance metrics"
    echo "  $0 --watch                       # Real-time monitoring"
}

show_errors() {
    echo "=== ERRORS AND WARNINGS ==="
    if [[ -f "$LOGFILE" ]]; then
        grep -E "\[(ERROR|WARN)\]" "$LOGFILE" | tail -20
    else
        echo "No log file found: $LOGFILE"
    fi
}

show_metrics() {
    echo "=== PERFORMANCE METRICS ==="
    if [[ -f "$LOGFILE" ]]; then
        echo "Cache Hit Rates:"
        cache_hits=$(grep -c "CACHE_HIT" "$LOGFILE")
        cache_misses=$(grep -c "CACHE_MISS" "$LOGFILE")
        if [[ $((cache_hits + cache_misses)) -gt 0 ]]; then
            hit_rate=$(echo "scale=2; $cache_hits * 100 / ($cache_hits + $cache_misses)" | bc -l)
            echo "  - Wallet Cache: $hit_rate% hit rate ($cache_hits hits / $cache_misses misses)"
        fi
        
        primal_cached=$(grep -c "PRIMAL_CACHED" "$LOGFILE")
        primal_discovered=$(grep -c "PRIMAL_DISCOVERED" "$LOGFILE")
        primal_first_day=$(grep -c "PRIMAL_FIRST_DAY" "$LOGFILE")
        primal_too_early=$(grep -c "PRIMAL_TOO_EARLY" "$LOGFILE")
        primal_pending=$(grep -c "PRIMAL_PENDING" "$LOGFILE")
        echo "  - PRIMAL Cache: $primal_cached cached / $primal_discovered discovered"
        echo "  - PRIMAL Timing: $primal_first_day first-day / $primal_too_early too-early / $primal_pending pending"
        
        echo ""
        echo "Payment Statistics:"
        payment_success=$(grep -c "PAYMENT_SUCCESS" "$LOGFILE")
        payment_failed=$(grep -c "PAYMENT_FAILED" "$LOGFILE")
        primo_tx_sent=$(grep -c "PRIMO_TX_SENT" "$LOGFILE")
        primo_tx_failed=$(grep -c "PRIMO_TX_FAILED" "$LOGFILE")
        welcome_emails=$(grep -c "WELCOME_EMAIL_SENT" "$LOGFILE")
        echo "  - Weekly payments: ✅ $payment_success | ❌ $payment_failed"
        echo "  - PRIMO TX (UPlanet): ✅ $primo_tx_sent | ❌ $primo_tx_failed"
        echo "  - Welcome emails: $welcome_emails"
        
        echo ""
        echo "Recent Execution Times:"
        grep "EXECUTION_TIME_SECONDS" "$LOGFILE" | tail -5 | while read line; do
            seconds=$(echo "$line" | grep -o "EXECUTION_TIME_SECONDS=[0-9]*" | cut -d= -f2)
            minutes=$(echo "scale=2; $seconds / 60" | bc -l)
            echo "  - ${minutes}m (${seconds}s)"
        done
    else
        echo "No log file found: $LOGFILE"
    fi
}

show_player_logs() {
    local player="$1"
    echo "=== LOGS FOR PLAYER: $player ==="
    if [[ -f "$LOGFILE" ]]; then
        grep "\[$player\]" "$LOGFILE" | tail -20
    else
        echo "No log file found: $LOGFILE"
    fi
}

show_summary() {
    echo "=== EXECUTION SUMMARY ==="
    if [[ -f "$LOGFILE" ]]; then
        echo "Last execution summary:"
        grep -A 10 "NOSTR REFRESH SUMMARY" "$LOGFILE" | tail -15
    else
        echo "No log file found: $LOGFILE"
    fi
}

watch_logs() {
    echo "=== WATCHING LOGS (Ctrl+C to stop) ==="
    if [[ -f "$LOGFILE" ]]; then
        tail -f "$LOGFILE"
    else
        echo "No log file found: $LOGFILE"
        echo "Waiting for log file creation..."
        while [[ ! -f "$LOGFILE" ]]; do sleep 1; done
        tail -f "$LOGFILE"
    fi
}

# Parse arguments
case "${1:-}" in
    -t|--tail)
        tail -n "${2:-50}" "$LOGFILE" 2>/dev/null || echo "No log file found: $LOGFILE"
        ;;
    -e|--errors)
        show_errors
        ;;
    -m|--metrics)
        show_metrics
        ;;
    -p|--player)
        [[ -z "$2" ]] && echo "Error: Player email required" && exit 1
        show_player_logs "$2"
        ;;
    -s|--summary)
        show_summary
        ;;
    -w|--watch)
        watch_logs
        ;;
    -h|--help)
        usage
        ;;
    "")
        echo "=== NOSTR MULTIPASS LOG ANALYZER ==="
        echo "Log file: $LOGFILE"
        if [[ -f "$LOGFILE" ]]; then
            echo "Log size: $(du -h "$LOGFILE" | cut -f1)"
            echo "Last modified: $(stat -c %y "$LOGFILE")"
            echo ""
            echo "Recent activity (last 10 lines):"
            tail -10 "$LOGFILE"
        else
            echo "Status: No log file found"
        fi
        echo ""
        echo "Use --help for more options"
        ;;
    *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
esac

exit 0 