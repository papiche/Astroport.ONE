#!/bin/bash
################################################################################
## MiroFish Swarm Connector (P2P / Local / SSH)
## Cherche l'API MiroFish sur le port 5050 localement,
## sinon passe par SSH, ou tente l'essaim P2P (IPFS Swarm)
################################################################################
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true
resolve_swarm_remote_target "scorpio.copylaradio.com" 2122 22

# Configuration
MIROFISH_PORT=${PORT_MIROFISH:-5050}
SERVICE_NAME="mirofish"

if [[ -n "${SWARM_REMOTE_TARGET:-}" ]]; then
    IFS='|' read -r REMOTE_HOST REMOTE_PORT_IPV4 REMOTE_PORT_IPV6 <<<"$SWARM_REMOTE_TARGET"
else
    REMOTE_HOST="${SWARM_REMOTE_HOST:-scorpio.copylaradio.com}"
    REMOTE_PORT_IPV4="${SWARM_REMOTE_PORT_IPV4:-2122}"
    REMOTE_PORT_IPV6="${SWARM_REMOTE_PORT_IPV6:-22}"
fi
REMOTE_USER="${SWARM_REMOTE_USER:-frd}"
SSH_OPTIONS="-fN -L 127.0.0.1:$MIROFISH_PORT:127.0.0.1:$MIROFISH_PORT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

STATUS_FILE="$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}MiroFish Swarm Connector${NC}   (port $MIROFISH_PORT)         ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

print_status() {
    local status="$1" message="$2"
    case "$status" in
        "OK")     echo -e "  ${GREEN}✓${NC} $message" ;;
        "FAIL")   echo -e "  ${RED}✗${NC} $message" ;;
        "ACTIVE") echo -e "  ${GREEN}●${NC} $message ${GREEN}[ACTIVE]${NC}" ;;
        *)        echo -e "  $message" ;;
    esac
}

save_connection_status() {
    mkdir -p "$(dirname "$STATUS_FILE")"
    echo "CONNECTION_TYPE=$1" > "$STATUS_FILE"
    echo "CONNECTION_DETAILS=$2" >> "$STATUS_FILE"
    echo "CONNECTION_TIME=$(date -Iseconds)" >> "$STATUS_FILE"
}

check_port() {
    local silent="${1:-false}"
    if netstat -tulnp 2>/dev/null | grep -q ":$MIROFISH_PORT "; then
        [[ "$silent" != "true" ]] && echo "Port $MIROFISH_PORT is open."
        return 0
    fi
    [[ "$silent" != "true" ]] && echo "Port $MIROFISH_PORT is not available."
    return 1
}

test_api() {
    local silent="${1:-false}"
    # On teste l'accès à MiroFish (racine ou ping API)
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$MIROFISH_PORT/" --connect-timeout 5)
    if[ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "302" ]; then
        [[ "$silent" != "true" ]] && echo "MiroFish responding correctly."
        return 0
    fi
    [[ "$silent" != "true" ]] && echo "MiroFish not responding (HTTP $RESPONSE)."
    return 1
}

check_local_service() {
    if docker ps 2>/dev/null | grep -q "mirofish"; then
        print_status "OK" "Local MiroFish Docker container detected"
        return 0
    fi
    return 1
}

check_p2p_connections() {
    local p2p_conns=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | wc -l)
    if [[ $p2p_conns -gt 0 ]]; then
        print_status "ACTIVE" "IPFS P2P ($p2p_conns connection(s))"
        return 0
    fi
    return 1
}

connect_via_swarm() {
    echo -e "\n${BOLD}Connecting via IPFS P2P swarm...${NC}"
    local nodes=() node_ids=()
    
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
        print_status "FAIL" "No MiroFish nodes found in swarm"
        return 1
    fi
    
    # Auto-select the first available node
    local selected_script="${nodes[0]}"
    local selected_node="${node_ids[0]}"
    
    echo "Connecting to: $selected_node"
    if bash "$selected_script" 2>/dev/null; then
        sleep 2
        if test_api "true"; then
            save_connection_status "P2P" "$selected_node"
            print_status "OK" "Connected to $selected_node via IPFS P2P"
            return 0
        fi
        ipfs p2p close -p "/x/${SERVICE_NAME}-$selected_node" 2>/dev/null
    fi
    return 1
}

close_ipfs_p2p() {
    for conn in $(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $1}'); do
        ipfs p2p close -p "$conn" 2>/dev/null
    done
    rm -f "$STATUS_FILE"
}

# --- MAIN ---
case "${1^^}" in
    "TEST")
        test_api "true"
        exit $? ;;
    "OFF"|"STOP")
        print_header; close_ipfs_p2p; exit 0 ;;
    "LOCAL")
        if check_local_service && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            exit 0
        fi
        exit 1 ;;
    "P2P"|"SWARM")
        print_header; connect_via_swarm && exit 0; exit 1 ;;
    *)
        # AUTO Connect
        if check_port "true" && test_api "true"; then
            echo "MiroFish ready at http://localhost:$MIROFISH_PORT"
            exit 0
        fi
        if check_local_service; then
            exit 0
        fi
        connect_via_swarm && exit 0
        echo -e "${RED}Error: MiroFish not found locally or in Swarm.${NC}"
        exit 1 ;;
esac