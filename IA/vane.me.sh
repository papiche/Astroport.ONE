#!/bin/bash
################################################################################
## Vane Swarm Connector (anciennement Perplexica)
## https://github.com/ItzCrazyKns/Vane
## Cherche l'API Vane sur le port 3002 localement,
## sinon passe par SSH, ou tente l'essaim P2P (IPFS Swarm)
################################################################################
## ZEN[0] Swarm Integration - Enhanced Connection Manager
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true
resolve_swarm_remote_target "scorpio.copylaradio.com" 2122 22

# Configuration
VANE_PORT=${PORT_VANE:-3002}
SERVICE_NAME="vane"
## Passerelle SSH — configurable dans ~/.zen/Astroport.ONE/.env
if [[ -n "${SWARM_REMOTE_TARGET:-}" ]]; then
    IFS='|' read -r REMOTE_HOST REMOTE_PORT_IPV4 REMOTE_PORT_IPV6 <<<"$SWARM_REMOTE_TARGET"
else
    REMOTE_HOST="${SWARM_REMOTE_HOST:-scorpio.copylaradio.com}"
    REMOTE_PORT_IPV4="${SWARM_REMOTE_PORT_IPV4:-2122}"
    REMOTE_PORT_IPV6="${SWARM_REMOTE_PORT_IPV6:-22}"
fi
REMOTE_USER="${SWARM_REMOTE_USER:-frd}"
if [[ -n "${SWARM_REMOTE_TARGET_VPN:-}" && "${SWARM_REMOTE_USE_VPN:-false}" =~ ^(1|true|TRUE|yes|YES|on|ON)$ ]]; then
    IFS='|' read -r REMOTE_HOST_VPN REMOTE_PORT_IPV4_VPN REMOTE_PORT_IPV6_VPN <<<"$SWARM_REMOTE_TARGET_VPN"
else
    REMOTE_HOST_VPN="${SWARM_REMOTE_HOST_VPN:-${WG_HUB:-10.99.99.1}}"
    REMOTE_PORT_IPV4_VPN="${SWARM_REMOTE_PORT_IPV4_VPN:-22}"
    REMOTE_PORT_IPV6_VPN="${SWARM_REMOTE_PORT_IPV6_VPN:-22}"
fi
SSH_OPTIONS="-fN -L 127.0.0.1:$VANE_PORT:127.0.0.1:$VANE_PORT"

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
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}Vane Search Connector${NC}   (port $VANE_PORT)            ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

print_status() {
    local status="$1" message="$2"
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
    mkdir -p "$(dirname "$STATUS_FILE")"
    echo "CONNECTION_TYPE=$1" > "$STATUS_FILE"
    echo "CONNECTION_DETAILS=$2" >> "$STATUS_FILE"
    echo "CONNECTION_TIME=$(date -Iseconds)" >> "$STATUS_FILE"
    echo "CONNECTION_PORT=$VANE_PORT" >> "$STATUS_FILE"
}

check_port() {
    local silent="${1:-false}"
    if netstat -tulnp 2>/dev/null | grep -q ":$VANE_PORT "; then
        [[ "$silent" != "true" ]] && echo "Port $VANE_PORT is open."
        return 0
    fi
    [[ "$silent" != "true" ]] && echo "Port $VANE_PORT is not available."
    return 1
}

test_api() {
    local silent="${1:-false}"
    [[ "$silent" != "true" ]] && echo "Testing Vane API on port $VANE_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        "http://localhost:$VANE_PORT/api/providers" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ]; then
        [[ "$silent" != "true" ]] && echo "Vane API responding correctly."
        return 0
    fi
    [[ "$silent" != "true" ]] && echo "Vane API not responding (HTTP $RESPONSE)."
    return 1
}

check_local_service() {
    local silent="${1:-false}"
    if pgrep -f "vane\|perplexica" >/dev/null 2>&1 || \
       docker ps 2>/dev/null | grep -qE "vane|perplexica" || \
       systemctl is-active --quiet vane 2>/dev/null; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local Vane service detected"
        return 0
    fi
    return 1
}

check_ipv6_available() {
    local silent="${1:-false}"
    local ipv6_addr
    ipv6_addr=$(dig +short AAAA "$REMOTE_HOST" 2>/dev/null | head -1)
    if [ -n "$ipv6_addr" ]; then
        if timeout 3 bash -c "echo >/dev/tcp/[$ipv6_addr]/$REMOTE_PORT_IPV6" 2>/dev/null; then
            [[ "$silent" != "true" ]] && print_status "OK" "IPv6 to $REMOTE_HOST ($ipv6_addr)"
            return 0
        fi
    fi
    [[ "$silent" != "true" ]] && print_status "FAIL" "IPv6 not available"
    return 1
}

check_ipv4_available() {
    local silent="${1:-false}"
    local ipv4_addr
    ipv4_addr=$(dig +short A "$REMOTE_HOST" 2>/dev/null | head -1)
    if [ -n "$ipv4_addr" ]; then
        if timeout 3 bash -c "echo >/dev/tcp/$ipv4_addr/$REMOTE_PORT_IPV4" 2>/dev/null; then
            [[ "$silent" != "true" ]] && print_status "OK" "IPv4 to $REMOTE_HOST ($ipv4_addr:$REMOTE_PORT_IPV4)"
            return 0
        fi
    fi
    [[ "$silent" != "true" ]] && print_status "FAIL" "IPv4 not available"
    return 1
}

check_ssh_tunnel_active() {
    local silent="${1:-false}"
    local pid
    pid=$(lsof -t -i :"$VANE_PORT" 2>/dev/null)
    if [[ -n "$pid" ]]; then
        local proc_info
        proc_info=$(ps -p "$pid" -o comm= 2>/dev/null)
        if [[ "$proc_info" == "ssh" ]]; then
            [[ "$silent" != "true" ]] && print_status "ACTIVE" "SSH tunnel (PID: $pid)"
            return 0
        fi
    fi
    return 1
}

check_p2p_connections() {
    local silent="${1:-false}"
    local p2p_conns
    p2p_conns=$(ipfs p2p ls 2>/dev/null | grep -c "/x/${SERVICE_NAME}")
    if [[ $p2p_conns -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "ACTIVE" "IPFS P2P ($p2p_conns connection(s))"
        return 0
    fi
    return 1
}

establish_ssh_tunnel() {
    local protocol="${1:-auto}"
    echo -e "\n${BOLD}Establishing SSH tunnel...${NC}"

    if [[ "$protocol" == "auto" || "$protocol" == "ipv6" ]]; then
        if check_ipv6_available "true"; then
            echo "Trying IPv6 connection..."
            if ssh $SSH_OPTIONS -6 "$REMOTE_USER@$REMOTE_HOST" -p "$REMOTE_PORT_IPV6" 2>/dev/null; then
                sleep 2
                if check_port "true" && test_api "true"; then
                    save_connection_status "SSH_IPv6" "$REMOTE_HOST:$REMOTE_PORT_IPV6"
                    print_status "OK" "SSH tunnel established via IPv6"
                    return 0
                fi
                close_ssh_tunnel "true"
            fi
        fi
        [[ "$protocol" == "ipv6" ]] && return 1
    fi

    if [[ "$protocol" == "auto" || "$protocol" == "ipv4" ]]; then
        if check_ipv4_available "true"; then
            echo "Trying IPv4 connection..."
            if ssh $SSH_OPTIONS -4 "$REMOTE_USER@$REMOTE_HOST" -p "$REMOTE_PORT_IPV4" 2>/dev/null; then
                sleep 2
                if check_port "true" && test_api "true"; then
                    save_connection_status "SSH_IPv4" "$REMOTE_HOST:$REMOTE_PORT_IPV4"
                    print_status "OK" "SSH tunnel established via IPv4"
                    return 0
                fi
                close_ssh_tunnel "true"
            fi
        fi
    fi

    print_status "FAIL" "Failed to establish SSH tunnel"
    return 1
}

close_ssh_tunnel() {
    local silent="${1:-false}"
    local pid
    pid=$(lsof -t -i :"$VANE_PORT" 2>/dev/null)
    if [[ -n "$pid" ]]; then
        local proc_info
        proc_info=$(ps -p "$pid" -o comm= 2>/dev/null)
        if [[ "$proc_info" == "ssh" ]]; then
            kill "$pid" 2>/dev/null
            [[ "$silent" != "true" ]] && print_status "OK" "SSH tunnel closed (PID: $pid)"
            rm -f "$STATUS_FILE"
            return 0
        fi
    fi
    [[ "$silent" != "true" ]] && print_status "INFO" "No SSH tunnel to close"
    return 1
}

connect_via_swarm() {
    local target="${1:-}"
    echo -e "\n${BOLD}Connecting via IPFS P2P swarm...${NC}"

    local nodes=() node_ids=()
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        [[ -f "$script" ]] && nodes+=("$script") && node_ids+=("$(basename "$(dirname "$script")")")
    done
    if [[ -n "$IPFSNODEID" && -f "$HOME/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh" ]]; then
        nodes+=("$HOME/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh")
        node_ids+=("$IPFSNODEID")
    fi

    if [[ ${#nodes[@]} -eq 0 ]]; then
        print_status "FAIL" "No Vane nodes found in swarm"
        return 1
    fi

    local selected_script="${nodes[0]}"
    local selected_node="${node_ids[0]}"

    if [[ -n "$target" ]]; then
        for i in "${!node_ids[@]}"; do
            if [[ "${node_ids[$i]}" == "$target" || "${node_ids[$i]}" == *"$target"* ]]; then
                selected_script="${nodes[$i]}"
                selected_node="${node_ids[$i]}"
                break
            fi
        done
    fi

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
    print_status "FAIL" "P2P connection to $selected_node failed"
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

# --- MAIN ---
case "${1^^}" in
    "STATUS"|"ST")
        print_header
        if check_port "true" && test_api "true"; then
            echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTED${NC}"
            echo -e "    └─ API: ${GREEN}http://localhost:$VANE_PORT${NC}"
        else
            echo -e "\n  ${RED}●${NC} ${BOLD}DISCONNECTED${NC}"
        fi
        exit $? ;;
    "TEST")
        test_api; exit $? ;;
    "OFF"|"DISCONNECT"|"CLOSE")
        print_header
        close_ssh_tunnel
        close_ipfs_p2p
        rm -f "$STATUS_FILE"
        exit 0 ;;
    "LOCAL")
        print_header
        if check_local_service && check_port "true" && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            print_status "OK" "Connected to local Vane"
            echo -e "API ready at ${GREEN}http://localhost:$VANE_PORT${NC}"
            exit 0
        fi
        print_status "FAIL" "Local Vane not available"
        exit 1 ;;
    "SSH")
        print_header
        establish_ssh_tunnel "auto" && \
            { echo -e "API ready at ${GREEN}http://localhost:$VANE_PORT${NC}"; exit 0; }
        exit 1 ;;
    "SSH6"|"IPV6")
        print_header
        establish_ssh_tunnel "ipv6" && \
            { echo -e "API ready at ${GREEN}http://localhost:$VANE_PORT${NC}"; exit 0; }
        exit 1 ;;
    "SSH4"|"IPV4")
        print_header
        establish_ssh_tunnel "ipv4" && \
            { echo -e "API ready at ${GREEN}http://localhost:$VANE_PORT${NC}"; exit 0; }
        exit 1 ;;
    "P2P"|"SWARM"|"IPFS")
        print_header
        connect_via_swarm "$2" && \
            { echo -e "API ready at ${GREEN}http://localhost:$VANE_PORT${NC}"; exit 0; }
        exit 1 ;;
    *)
        # Auto-connect: local → P2P → SSH (SSH en dernier recours)
        if check_port "true" && test_api "true"; then
            echo "Vane API ready at http://localhost:$VANE_PORT"
            exit 0
        fi
        if check_local_service; then
            save_connection_status "LOCAL" "Local service"
            exit 0
        fi
        if connect_via_swarm; then
            echo "Vane API ready via P2P at http://localhost:$VANE_PORT"
            exit 0
        fi
        echo "P2P unavailable, trying SSH tunnel as fallback..."
        if establish_ssh_tunnel "auto"; then
            echo "Vane API ready via SSH at http://localhost:$VANE_PORT"
            exit 0
        fi
        echo -e "${RED}Error: Vane not found locally or in Swarm.${NC}"
        exit 1 ;;
esac
