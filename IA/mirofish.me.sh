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
SERVICE_PORT=$MIROFISH_PORT
STATUS_FILE="$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"

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

########################################################
## Service-specific functions (must be defined before lib source)
########################################################

test_api() {
    local silent="${1:-false}"
    # On teste l'accès à MiroFish (racine ou ping API)
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$MIROFISH_PORT/" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ] || [ "$RESPONSE" == "302" ]; then
        [[ "$silent" != "true" ]] && echo "MiroFish responding correctly."
        return 0
    fi
    [[ "$silent" != "true" ]] && echo "MiroFish not responding (HTTP $RESPONSE)."
    return 1
}

# Source shared library (provides: print_status, save_connection_status,
# check_port, count_p2p_nodes, check_p2p_connections, close_ipfs_p2p,
# connect_via_swarm)
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/swarm_connector_lib.sh"

########################################################
## Service-specific functions
########################################################

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}MiroFish Swarm Connector${NC}   (port $MIROFISH_PORT)         ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

check_local_service() {
    if docker ps 2>/dev/null | grep -q "mirofish"; then
        print_status "OK" "Local MiroFish Docker container detected"
        return 0
    fi
    return 1
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
        print_header; connect_via_swarm "$2" && exit 0; exit 1 ;;
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
