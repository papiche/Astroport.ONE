#!/bin/bash
################################################################################
## Orpheus Swarm Connector
## Checks for local Orpheus TTS API on port 5005
## Fallback to IPFS P2P swarm discovery (no SSH)
################################################################################
## ZEN[0] Swarm Integration - Enhanced Connection Manager
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

# Configuration
ORPHEUS_PORT=5005
SERVICE_NAME="orpheus"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Connection status file
STATUS_FILE="$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"

########################################################
## Helper Functions
########################################################

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}${SERVICE_NAME^^} TTS Connection Manager${NC}  (port $ORPHEUS_PORT)  ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

print_status() {
    local status="$1"
    local message="$2"
    case "$status" in
        "OK")     echo -e "  ${GREEN}✓${NC} $message" ;;
        "FAIL")   echo -e "  ${RED}✗${NC} $message" ;;
        "WARN")   echo -e "  ${YELLOW}⚠${NC} $message" ;;
        "INFO")   echo -e "  ${BLUE}ℹ${NC} $message" ;;
        "ACTIVE") echo -e "  ${GREEN}●${NC} $message ${GREEN}[ACTIVE]${NC}" ;;
        *)        echo -e "  $message" ;;
    esac
}

save_connection_status() {
    local conn_type="$1"
    local details="$2"
    mkdir -p "$(dirname "$STATUS_FILE")"
    echo "CONNECTION_TYPE=$conn_type" > "$STATUS_FILE"
    echo "CONNECTION_DETAILS=$details" >> "$STATUS_FILE"
    echo "CONNECTION_TIME=$(date -Iseconds)" >> "$STATUS_FILE"
    echo "CONNECTION_PORT=$ORPHEUS_PORT" >> "$STATUS_FILE"
}

########################################################
## Detection Functions
########################################################

# Check if port is open (silent mode available)
check_port() {
    local silent="${1:-false}"
    if netstat -tulnp 2>/dev/null | grep ":$ORPHEUS_PORT " >/dev/null; then
        [[ "$silent" != "true" ]] && echo "Port $ORPHEUS_PORT is open."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Port $ORPHEUS_PORT is not available."
        return 1
    fi
}

# Test Orpheus TTS API connection (silent mode available)
test_api() {
    local silent="${1:-false}"
    [[ "$silent" != "true" ]] && echo "Testing Orpheus TTS API on port $ORPHEUS_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$ORPHEUS_PORT/docs" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ]; then
        [[ "$silent" != "true" ]] && echo "Orpheus TTS API responding correctly."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Orpheus TTS API not responding (HTTP $RESPONSE)."
        return 1
    fi
}

# Check if LOCAL service is running
check_local_service() {
    local silent="${1:-false}"
    # Check Docker container
    if docker ps 2>/dev/null | grep -q "orpheus"; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local Orpheus Docker container detected"
        return 0
    fi
    # Check port
    if netstat -tulnp 2>/dev/null | grep ":$ORPHEUS_PORT " >/dev/null; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local Orpheus service detected on port $ORPHEUS_PORT"
        return 0
    fi
    return 1
}

# Check IPFS P2P connections
check_p2p_connections() {
    local silent="${1:-false}"
    local p2p_conns=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | wc -l)
    if [[ $p2p_conns -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "ACTIVE" "IPFS P2P ($p2p_conns connection(s))"
        return 0
    fi
    return 1
}

# Count available P2P nodes
count_p2p_nodes() {
    local count=0
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        [[ -f "$script" ]] && ((count++))
    done
    [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]] && ((count++))
    echo $count
}

# List available voices
list_voices() {
    local silent="${1:-false}"
    if test_api "true"; then
        [[ "$silent" != "true" ]] && echo -e "\n${BOLD}Available Voices:${NC}"
        [[ "$silent" != "true" ]] && echo -e "    ├─ ${CYAN}pierre${NC} (French male)"
        [[ "$silent" != "true" ]] && echo -e "    └─ ${CYAN}amelie${NC} (French female)"
    fi
}

########################################################
## Connection Functions
########################################################

# Connect via IPFS P2P swarm
connect_via_swarm() {
    local target_node="${1:-}"
    
    echo -e "\n${BOLD}Connecting via IPFS P2P swarm...${NC}"
    
    local nodes=()
    
    # Collect available nodes
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        [[ -f "$script" ]] && nodes+=("$script")
    done
    [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]] && \
        nodes+=("$HOME/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh")
    
    if [[ ${#nodes[@]} -eq 0 ]]; then
        print_status "FAIL" "No ${SERVICE_NAME} nodes found in swarm"
        return 1
    fi
    
    # If target node specified, filter
    if [[ -n "$target_node" ]]; then
        for script in "${nodes[@]}"; do
            local node_id=$(basename $(dirname "$script"))
            if [[ "$node_id" == "$target_node" || "$node_id" == *"$target_node"* ]]; then
                if bash "$script" 2>/dev/null; then
                    sleep 2
                    if test_api "true"; then
                        save_connection_status "P2P" "$node_id"
                        print_status "OK" "Connected to $node_id via IPFS P2P"
                        return 0
                    fi
                fi
            fi
        done
        print_status "FAIL" "Target node $target_node not found or not responding"
        return 1
    fi
    
    # Auto-select: shuffle and try
    local shuffled=($(printf '%s\n' "${nodes[@]}" | sort -R))
    
    for script in "${shuffled[@]}"; do
        local node_id=$(basename $(dirname "$script"))
        echo "Trying node: $node_id"
        
        if bash "$script" 2>/dev/null; then
            sleep 2
            if test_api "true"; then
                save_connection_status "P2P" "$node_id"
                print_status "OK" "Connected to $node_id via IPFS P2P"
                return 0
            else
                ipfs p2p close -p "/x/${SERVICE_NAME}-$node_id" 2>/dev/null
            fi
        fi
    done
    
    print_status "FAIL" "No working ${SERVICE_NAME} nodes available"
    return 1
}

# Close IPFS P2P connections
close_ipfs_p2p() {
    local silent="${1:-false}"
    local closed=0
    
    for conn in $(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $1}'); do
        ipfs p2p close -p "$conn" 2>/dev/null && ((closed++))
    done
    
    if [[ $closed -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "OK" "Closed $closed P2P connection(s)"
        rm -f "$STATUS_FILE"
        return 0
    fi
    [[ "$silent" != "true" ]] && print_status "INFO" "No P2P connections to close"
    return 1
}

########################################################
## Command Handlers
########################################################

# STATUS - Show current connection status
cmd_status() {
    print_header
    echo -e "\n${BOLD}Current Connection Status:${NC}"
    
    local active_type="NONE"
    local active_details=""
    local connection_time=""
    
    # Check what's currently active - ORDER MATTERS!
    # Priority: P2P > Local (most specific first, no SSH for Orpheus)
    if check_port "true"; then
        # 1. Check P2P connections first (ipfs p2p ls shows active connections)
        if check_p2p_connections "true"; then
            active_type="P2P"
            if [[ -f "$STATUS_FILE" ]]; then
                source "$STATUS_FILE"
                active_details="$CONNECTION_DETAILS"
                connection_time="$CONNECTION_TIME"
            else
                active_details=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $3}' | head -1)
            fi
        # 2. Local service (fallback - only if no P2P)
        elif check_local_service "true"; then
            active_type="LOCAL"
            active_details="Local service (Docker)"
        else
            active_type="UNKNOWN"
            active_details="Port open but source unknown"
        fi
        
        if test_api "true"; then
            echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTED${NC} via ${CYAN}$active_type${NC}"
            [[ -n "$active_details" ]] && echo -e "    └─ $active_details"
            echo -e "    └─ API: ${GREEN}http://localhost:$ORPHEUS_PORT${NC}"
            [[ -n "$connection_time" ]] && echo -e "    └─ Since: $connection_time"
            
            # List voices
            list_voices
            return 0
        fi
    fi
    
    echo -e "\n  ${RED}●${NC} ${BOLD}DISCONNECTED${NC}"
    echo -e "    └─ No active ${SERVICE_NAME} connection"
    return 1
}

# SCAN - Detect all available connections
cmd_scan() {
    print_header
    echo -e "\n${BOLD}Scanning Available Connections:${NC}\n"
    
    # 1. LOCAL
    echo -e "${BOLD}[LOCAL]${NC}"
    if check_local_service "true"; then
        print_status "OK" "Local ${SERVICE_NAME} service available"
    else
        print_status "FAIL" "No local ${SERVICE_NAME} service"
    fi
    
    # 2. IPFS P2P (no SSH for Orpheus)
    echo -e "\n${BOLD}[P2P]${NC} IPFS Swarm Nodes"
    local p2p_count=$(count_p2p_nodes)
    
    if [[ $p2p_count -gt 0 ]]; then
        print_status "OK" "$p2p_count node(s) available:"
        
        # List nodes
        for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
            if [[ -f "$script" ]]; then
                local node_id=$(basename $(dirname "$script"))
                local myipfs_file=$(dirname "$script")/myIPFS.txt
                local gateway=""
                [[ -f "$myipfs_file" ]] && gateway=$(cat "$myipfs_file")
                echo -e "    ├─ ${CYAN}$node_id${NC}"
                [[ -n "$gateway" ]] && echo -e "    │  └─ $gateway"
            fi
        done
        
        if [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]]; then
            echo -e "    └─ ${CYAN}$IPFSNODEID${NC} ${GREEN}(local)${NC}"
        fi
    else
        print_status "FAIL" "No P2P nodes found"
    fi
    
    if check_p2p_connections "true"; then
        local active_p2p=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $3}' | head -1)
        echo -e "  ${GREEN}●${NC} P2P currently ACTIVE: $active_p2p"
    fi
    
    # Summary
    echo -e "\n${BOLD}Summary:${NC}"
    echo -e "  Available methods: LOCAL=$(check_local_service true && echo Y || echo N) P2P=$([[ $p2p_count -gt 0 ]] && echo Y || echo N)"
    echo -e "\n${YELLOW}Note:${NC} Orpheus TTS uses LOCAL and P2P only (no SSH tunnel)"
}

# HELP - Show usage
cmd_help() {
    print_header
    echo -e "\n${BOLD}Usage:${NC} $(basename $0) [COMMAND] [OPTIONS]\n"
    
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${CYAN}(none)${NC}      Auto-connect (LOCAL → P2P)"
    echo -e "  ${CYAN}STATUS${NC}      Show current connection status"
    echo -e "  ${CYAN}SCAN${NC}        Detect all available connections"
    echo -e "  ${CYAN}LOCAL${NC}       Connect via local service"
    echo -e "  ${CYAN}P2P${NC}         Connect via IPFS P2P swarm"
    echo -e "  ${CYAN}P2P <node>${NC}  Connect to specific P2P node"
    echo -e "  ${CYAN}VOICES${NC}      List available voices"
    echo -e "  ${CYAN}OFF${NC}         Disconnect all connections"
    echo -e "  ${CYAN}TEST${NC}        Test current API connection"
    echo -e "  ${CYAN}HELP${NC}        Show this help message"
    
    echo -e "\n${BOLD}Examples:${NC}"
    echo -e "  $(basename $0)                    # Auto-connect"
    echo -e "  $(basename $0) SCAN               # See available options"
    echo -e "  $(basename $0) P2P 12D3KooW...    # Connect to specific node"
    echo -e "  $(basename $0) OFF                # Disconnect"
    
    echo -e "\n${BOLD}Voices:${NC}"
    echo -e "  pierre  - French male voice"
    echo -e "  amelie  - French female voice"
}

########################################################
## Main Script
########################################################

case "${1^^}" in
    "STATUS"|"ST")
        cmd_status
        exit $?
        ;;
    "SCAN"|"DETECT"|"LIST"|"DISCOVER")
        cmd_scan
        exit 0
        ;;
    "HELP"|"-H"|"--HELP")
        cmd_help
        exit 0
        ;;
    "OFF"|"DISCONNECT"|"CLOSE")
        print_header
        echo -e "\n${BOLD}Disconnecting...${NC}"
        close_ipfs_p2p
        exit 0
        ;;
    "TEST")
        test_api
        exit $?
        ;;
    "VOICES")
        if test_api "true"; then
            print_header
            list_voices
        else
            echo "No active Orpheus connection. Connect first."
            exit 1
        fi
        exit 0
        ;;
    "LOCAL")
        print_header
        echo -e "\n${BOLD}Connecting via LOCAL...${NC}"
        if check_local_service && check_port "true" && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            print_status "OK" "Connected to local ${SERVICE_NAME}"
            echo -e "API ready at ${GREEN}http://localhost:$ORPHEUS_PORT${NC}"
            list_voices
            exit 0
        fi
        print_status "FAIL" "Local ${SERVICE_NAME} not available"
        exit 1
        ;;
    "P2P"|"SWARM"|"IPFS")
        print_header
        if connect_via_swarm "$2"; then
            echo -e "API ready at ${GREEN}http://localhost:$ORPHEUS_PORT${NC}"
            list_voices
            exit 0
        fi
        exit 1
        ;;
    "")
        # Auto-connect mode (default behavior)
        # Check if already available
        if check_port "true" && test_api "true"; then
            echo "${SERVICE_NAME^} TTS API ready at http://localhost:$ORPHEUS_PORT"
            exit 0
        fi
        
        # Check local service
        if check_local_service "true" && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            echo "${SERVICE_NAME^} TTS API ready (local) at http://localhost:$ORPHEUS_PORT"
            exit 0
        fi
        
        # Fallback to IPFS P2P swarm
        echo "No local service, trying IPFS P2P swarm..."
        if connect_via_swarm; then
            echo "${SERVICE_NAME^} TTS API ready via P2P at http://localhost:$ORPHEUS_PORT"
            exit 0
        fi
        
        echo "Could not establish connection to any ${SERVICE_NAME^} TTS API."
        exit 1
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$(basename $0) HELP' for usage information."
        exit 1
        ;;
esac
