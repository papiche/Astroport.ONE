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
SERVICE_PORT=$DIFY_PORT
STATUS_FILE="$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

########################################################
## Service-specific functions (must be defined before lib source)
########################################################

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

# Source shared library (provides: print_status, save_connection_status,
# check_port, count_p2p_nodes, check_p2p_connections, close_ipfs_p2p,
# connect_via_swarm)
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/swarm_connector_lib.sh"

########################################################
## Detection Functions
########################################################

check_local_service() {
    local silent="${1:-false}"
    if docker ps 2>/dev/null | grep -q "dify-nginx" || \
       docker ps 2>/dev/null | grep -q "docker-nginx-1"; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local Dify service detected"
        return 0
    fi
    return 1
}

########################################################
## Command Handlers
########################################################

print_header() {
    echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${YELLOW}║${NC}  ${BOLD}Dify.ai Swarm Connector${NC}  (port $DIFY_PORT)          ${BOLD}${YELLOW}║${NC}"
    echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
}

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
