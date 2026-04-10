#!/bin/bash
################################################################# dify.ai.me.sh
## Dify Swarm Connector (P2P Only Edition)
## Checks for local Dify on port 8010
## Finally fallback to IPFS P2P swarm discovery
################################################################################
## ZEN[0] Swarm Integration - IPFS Connection Manager for Dify
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

# Configuration
DIFY_PORT=8010
SERVICE_NAME="dify"

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
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║${NC}  ${BOLD}Dify.ai Swarm Connector${NC}  (port $DIFY_PORT)          ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
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
    echo "CONNECTION_PORT=$DIFY_PORT" >> "$STATUS_FILE"
}

########################################################
## Detection Functions
########################################################

check_port() {
    local silent="${1:-false}"
    if netstat -tulnp 2>/dev/null | grep ":$DIFY_PORT " >/dev/null || \
       ss -tln 2>/dev/null | grep -qw ":$DIFY_PORT"; then
        [[ "$silent" != "true" ]] && echo "Port $DIFY_PORT is open."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Port $DIFY_PORT is not available."
        return 1
    fi
}

test_api() {
    local silent="${1:-false}"
    [[ "$silent" != "true" ]] && echo "Testing Dify API on port $DIFY_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$DIFY_PORT/" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "302" ]; then
        [[ "$silent" != "true" ]] && echo "Dify responding correctly."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Dify not responding (HTTP $RESPONSE)."
        return 1
    fi
}

check_local_service() {
    local silent="${1:-false}"
    if docker ps 2>/dev/null | grep -q "dify-nginx" || \
       docker ps 2>/dev/null | grep -q "docker-nginx-1"; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local Dify service detected"
        return 0
    fi
    return 1
}

check_p2p_connections() {
    local silent="${1:-false}"
    local p2p_conns=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | wc -l)
    if [[ $p2p_conns -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "ACTIVE" "IPFS P2P ($p2p_conns connection(s))"
        return 0
    fi
    return 1
}

count_p2p_nodes() {
    local count=0
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        [[ -f "$script" ]] && ((count++))
    done
    [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]] && ((count++))
    echo $count
}

########################################################
## P2P Connection Functions
########################################################

connect_via_swarm() {
    local target="${1:-}"
    echo -e "\n${BOLD}Searching IPFS Swarm for Dify nodes...${NC}"

    local nodes=()
    local node_ids=()

    # Collect available scripts
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        if [[ -f "$script" ]]; then
            nodes+=("$script")
            node_ids+=($(basename $(dirname "$script")))
        fi
    done

    if [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]]; then
        nodes+=("$HOME/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh")
        node_ids+=("$IPFSNODEID")
    fi

    if [[ ${#nodes[@]} -eq 0 ]]; then
        print_status "FAIL" "No Dify nodes found in swarm"
        return 1
    fi

    local selected_script=""
    local selected_node=""

    if [[ -n "$target" && "$target" != "auto" ]]; then
        # Logic to select specific node by number or ID
        if [[ "$target" =~ ^[0-9]+$ ]]; then
            local idx=$((target - 1))
            selected_script="${nodes[$idx]}"
            selected_node="${node_ids[$idx]}"
        else
            for i in "${!node_ids[@]}"; do
                if [[ "${node_ids[$i]}" == *"$target"* ]]; then
                    selected_script="${nodes[$i]}"
                    selected_node="${node_ids[$i]}"
                    break
                fi
            done
        fi
    else
        # Auto-select first available
        selected_script="${nodes[0]}"
        selected_node="${node_ids[0]}"
    fi

    if [[ -n "$selected_script" ]]; then
        echo "Connecting to P2P node: $selected_node"
        if bash "$selected_script" 2>/dev/null; then
            sleep 2
            if test_api "true"; then
                save_connection_status "P2P" "$selected_node"
                print_status "OK" "Connected to $selected_node via IPFS P2P"
                return 0
            else
                ipfs p2p close -p "/x/${SERVICE_NAME}-$selected_node" 2>/dev/null
                print_status "FAIL" "P2P link established but Dify not responding"
            fi
        fi
    fi
    return 1
}

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

cmd_status() {
    print_header
    echo -e "\n${BOLD}Current Status:${NC}"

    if check_port "true"; then
        local active_type="UNKNOWN"
        local active_details=""

        if check_p2p_connections "true"; then
            active_type="P2P Swarm"
            [[ -f "$STATUS_FILE" ]] && source "$STATUS_FILE" && active_details="$CONNECTION_DETAILS"
        elif check_local_service "true"; then
            active_type="LOCAL"
            active_details="Docker Container"
        fi

        if test_api "true"; then
            echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTED${NC} via ${YELLOW}$active_type${NC}"
            [[ -n "$active_details" ]] && echo -e "    └─ Node: $active_details"
            echo -e "    └─ URL: ${GREEN}http://localhost:$DIFY_PORT${NC}"
            return 0
        fi
    fi

    echo -e "\n  ${RED}●${NC} ${BOLD}DISCONNECTED${NC}"
    return 1
}

cmd_scan() {
    print_header
    echo -e "\n${BOLD}Scanning Swarm...${NC}"
    local p2p_count=$(count_p2p_nodes)
    if [[ $p2p_count -gt 0 ]]; then
        print_status "OK" "$p2p_count node(s) found in ~/.zen/tmp/swarm/"
    else
        print_status "FAIL" "No Dify nodes detected in swarm"
    fi
}

########################################################
## Main
########################################################

case "${1^^}" in
    "STATUS"|"ST") cmd_status; exit $? ;;
    "SCAN"|"LIST") cmd_scan; exit 0 ;;
    "OFF"|"STOP")  print_header; close_ipfs_p2p; exit 0 ;;
    "LOCAL")
        if check_local_service && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            echo "Dify Local ready at http://localhost:$DIFY_PORT"; exit 0
        fi
        exit 1 ;;
    "P2P"|"SWARM")
        print_header
        connect_via_swarm "$2" && exit 0; exit 1 ;;
    "HELP"|"-H")
        echo "Usage: $(basename $0) [STATUS|LOCAL|P2P|SCAN|OFF]"; exit 0 ;;
    *)
        # Default Auto-Connect: LOCAL then P2P
        if check_port "true" && test_api "true"; then
            echo "Dify already accessible at http://localhost:$DIFY_PORT"; exit 0
        fi
        if check_local_service "true"; then
            $0 LOCAL && exit 0
        fi
        connect_via_swarm && exit 0
        echo -e "${RED}Error: Dify not found locally or in Swarm.${NC}"
        exit 1 ;;
esac