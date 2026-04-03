#!/bin/bash
################################################################################
## Qdrant VectorDB Swarm Connector
## Checks for local Qdrant API on port 6333
## Finally fallback to IPFS P2P swarm discovery
################################################################################
## ZEN[0] Swarm Integration
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true
resolve_swarm_remote_target "scorpio.copylaradio.com" 2122 22

# Configuration
QDRANT_PORT=6333
SERVICE_NAME="qdrant"
## Passerelle SSH — configurable dans ~/.zen/Astroport.ONE/.env
## (my.sh source déjà .env donc SWARM_REMOTE_* est disponible ici)
if [[ -n "${SWARM_REMOTE_TARGET:-}" ]]; then
    IFS='|' read -r REMOTE_HOST REMOTE_PORT_IPV4 REMOTE_PORT_IPV6 <<<"$SWARM_REMOTE_TARGET"
else
    REMOTE_HOST="${SWARM_REMOTE_HOST:-scorpio.copylaradio.com}"
    REMOTE_PORT_IPV4="${SWARM_REMOTE_PORT_IPV4:-2122}"   # Port NAT IPv4
    REMOTE_PORT_IPV6="${SWARM_REMOTE_PORT_IPV6:-22}"    # Port SSH direct IPv6
fi
REMOTE_USER="${SWARM_REMOTE_USER:-frd}"
if [[ -n "${SWARM_REMOTE_TARGET_VPN:-}" && "${SWARM_REMOTE_USE_VPN:-false}" =~ ^(1|true|TRUE|yes|YES|on|ON)$ ]]; then
    IFS='|' read -r REMOTE_HOST_VPN REMOTE_PORT_IPV4_VPN REMOTE_PORT_IPV6_VPN <<<"$SWARM_REMOTE_TARGET_VPN"
else
    REMOTE_HOST_VPN="${SWARM_REMOTE_HOST_VPN:-${WG_HUB:-10.99.99.1}}"
    REMOTE_PORT_IPV4_VPN="${SWARM_REMOTE_PORT_IPV4_VPN:-22}"
    REMOTE_PORT_IPV6_VPN="${SWARM_REMOTE_PORT_IPV6_VPN:-22}"
fi
SSH_OPTIONS="-fN -L 127.0.0.1:$QDRANT_PORT:127.0.0.1:$QDRANT_PORT"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

STATUS_FILE="$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}Qdrant VectorDB Connection Manager${NC}  (port $QDRANT_PORT)  ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}

print_status() {
    case "$1" in
        "OK")     echo -e "  ${GREEN}✓${NC} $2" ;;
        "FAIL")   echo -e "  ${RED}✗${NC} $2" ;;
        "WARN")   echo -e "  ${YELLOW}⚠${NC} $2" ;;
        "INFO")   echo -e "  ${BLUE}ℹ${NC} $2" ;;
        "ACTIVE") echo -e "  ${GREEN}●${NC} $2 ${GREEN}[ACTIVE]${NC}" ;;
        *)        echo -e "  $2" ;;
    esac
}

save_connection_status() {
    mkdir -p "$(dirname "$STATUS_FILE")"
    echo "CONNECTION_TYPE=$1" > "$STATUS_FILE"
    echo "CONNECTION_DETAILS=$2" >> "$STATUS_FILE"
    echo "CONNECTION_TIME=$(date -Iseconds)" >> "$STATUS_FILE"
    echo "CONNECTION_PORT=$QDRANT_PORT" >> "$STATUS_FILE"
}

check_port() {
    local silent="${1:-false}"
    ss -tln 2>/dev/null | grep -qw ":$QDRANT_PORT" && {
        [[ "$silent" != "true" ]] && echo "Port $QDRANT_PORT is open."; return 0
    }
    [[ "$silent" != "true" ]] && echo "Port $QDRANT_PORT is not available."; return 1
}

test_api() {
    local silent="${1:-false}"
    [[ "$silent" != "true" ]] && echo "Testing Qdrant API on port $QDRANT_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$QDRANT_PORT/healthz" --connect-timeout 5)
    if [[ "$RESPONSE" == "200" || "$RESPONSE" == "204" ]]; then
        [[ "$silent" != "true" ]] && echo "Qdrant API responding correctly."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Qdrant API not responding (HTTP $RESPONSE)."
        return 1
    fi
}

check_local_service() {
    local silent="${1:-false}"
    if docker ps 2>/dev/null | grep -q "qdrant" || \
       pgrep -f "qdrant" >/dev/null 2>&1; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local Qdrant service detected"
        return 0
    fi
    return 1
}

check_ipv6_available() {
    local ipv6_addr=$(dig +short AAAA "$REMOTE_HOST" 2>/dev/null | head -1)
    [[ -n "$ipv6_addr" ]] && timeout 3 bash -c "echo >/dev/tcp/[$ipv6_addr]/$REMOTE_PORT_IPV6" 2>/dev/null
}

check_ipv4_available() {
    local ipv4_addr=$(dig +short A "$REMOTE_HOST" 2>/dev/null | head -1)
    [[ -n "$ipv4_addr" ]] && timeout 3 bash -c "echo >/dev/tcp/$ipv4_addr/$REMOTE_PORT_IPV4" 2>/dev/null
}

check_ssh_tunnel_active() {
    local silent="${1:-false}"
    local pid=$(lsof -t -i :$QDRANT_PORT 2>/dev/null)
    [[ -n "$pid" && "$(ps -p $pid -o comm= 2>/dev/null)" == "ssh" ]] && {
        [[ "$silent" != "true" ]] && print_status "ACTIVE" "SSH tunnel (PID: $pid)"; return 0
    }
    return 1
}

check_p2p_connections() {
    local silent="${1:-false}"
    local n=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | wc -l)
    [[ $n -gt 0 ]] && {
        [[ "$silent" != "true" ]] && print_status "ACTIVE" "IPFS P2P ($n connection(s))"; return 0
    }
    return 1
}

count_p2p_nodes() {
    local count=0
    for s in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do [[ -f "$s" ]] && ((count++)); done
    [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]] && ((count++))
    echo $count
}

# Show collection stats
show_collections() {
    local silent="${1:-false}"
    if test_api "true"; then
        local cols=$(curl -s "http://localhost:$QDRANT_PORT/collections" 2>/dev/null | jq -r '.result.collections[].name' 2>/dev/null)
        if [[ -n "$cols" ]]; then
            [[ "$silent" != "true" ]] && echo -e "\n${BOLD}Collections:${NC}"
            echo "$cols" | while read col; do
                [[ "$silent" != "true" ]] && echo -e "    ├─ ${CYAN}$col${NC}"
            done
        else
            [[ "$silent" != "true" ]] && echo -e "    (no collections)"
        fi
    fi
}

establish_ssh_tunnel() {
    local protocol="${1:-auto}"
    echo -e "\n${BOLD}Establishing SSH tunnel...${NC}"

    if [[ "$protocol" == "auto" || "$protocol" == "ipv6" ]]; then
        if check_ipv6_available; then
            echo "Trying IPv6..."
            if ssh $SSH_OPTIONS -6 $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT_IPV6 2>/dev/null; then
                sleep 2
                if check_port "true" && test_api "true"; then
                    save_connection_status "SSH_IPv6" "$REMOTE_HOST:$REMOTE_PORT_IPV6"
                    print_status "OK" "SSH tunnel established via IPv6"; return 0
                fi
                close_ssh_tunnel "true"
            fi
        fi
        [[ "$protocol" == "ipv6" ]] && return 1
    fi

    if [[ "$protocol" == "auto" || "$protocol" == "ipv4" ]]; then
        if check_ipv4_available; then
            echo "Trying IPv4..."
            if ssh $SSH_OPTIONS -4 $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT_IPV4 2>/dev/null; then
                sleep 2
                if check_port "true" && test_api "true"; then
                    save_connection_status "SSH_IPv4" "$REMOTE_HOST:$REMOTE_PORT_IPV4"
                    print_status "OK" "SSH tunnel established via IPv4"; return 0
                fi
                close_ssh_tunnel "true"
            fi
        fi
    fi

    print_status "FAIL" "Failed to establish SSH tunnel"; return 1
}

close_ssh_tunnel() {
    local silent="${1:-false}"
    local pid=$(lsof -t -i :$QDRANT_PORT 2>/dev/null)
    if [[ -n "$pid" && "$(ps -p $pid -o comm= 2>/dev/null)" == "ssh" ]]; then
        kill $pid 2>/dev/null
        [[ "$silent" != "true" ]] && print_status "OK" "SSH tunnel closed (PID: $pid)"
        rm -f "$STATUS_FILE"; return 0
    fi
    [[ "$silent" != "true" ]] && print_status "INFO" "No SSH tunnel to close"; return 1
}

connect_via_swarm() {
    local target="${1:-}"
    echo -e "\n${BOLD}Connecting via IPFS P2P swarm...${NC}"

    local nodes=() node_ids=()
    for s in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        [[ -f "$s" ]] && nodes+=("$s") && node_ids+=($(basename $(dirname "$s")))
    done
    [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]] && \
        nodes+=("$HOME/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh") && node_ids+=("$IPFSNODEID")

    [[ ${#nodes[@]} -eq 0 ]] && { print_status "FAIL" "No ${SERVICE_NAME} nodes found in swarm"; return 1; }

    local selected_script="${nodes[0]}"
    local selected_node="${node_ids[0]}"

    if [[ -n "$target" ]]; then
        case "$target" in
            "auto"|"AUTO"|"random"|"RANDOM")
                local shuffled=($(printf '%s\n' "${!nodes[@]}" | sort -R))
                for idx in "${shuffled[@]}"; do
                    if bash "${nodes[$idx]}" 2>/dev/null; then
                        sleep 2
                        if test_api "true"; then
                            save_connection_status "P2P" "${node_ids[$idx]}"
                            print_status "OK" "Connected to ${node_ids[$idx]} via IPFS P2P"; return 0
                        fi
                        ipfs p2p close -p "/x/${SERVICE_NAME}-${node_ids[$idx]}" 2>/dev/null
                    fi
                done
                print_status "FAIL" "No working nodes available"; return 1 ;;
            [0-9]|[0-9][0-9])
                local idx=$((target - 1))
                [[ $idx -ge 0 && $idx -lt ${#nodes[@]} ]] || { print_status "FAIL" "Invalid: $target"; return 1; }
                selected_script="${nodes[$idx]}"; selected_node="${node_ids[$idx]}" ;;
            *)
                for i in "${!node_ids[@]}"; do
                    [[ "${node_ids[$i]}" == *"$target"* ]] && selected_script="${nodes[$i]}" && selected_node="${node_ids[$i]}" && break
                done
                [[ -z "$selected_script" ]] && { print_status "FAIL" "Node not found: $target"; return 1; } ;;
        esac
    elif [[ ${#nodes[@]} -gt 1 ]]; then
        echo -e "\n${BOLD}Available P2P nodes:${NC}\n"
        for i in "${!node_ids[@]}"; do
            echo -e "  ${CYAN}[$((i+1))]${NC} ${node_ids[$i]:0:20}..."
        done
        echo -e "\n${YELLOW}Tip:${NC} 'P2P <number>' to select. Connecting to first...\n"
    fi

    echo "Connecting to: $selected_node"
    if bash "$selected_script" 2>/dev/null; then
        sleep 2
        if test_api "true"; then
            save_connection_status "P2P" "$selected_node"
            print_status "OK" "Connected to $selected_node via IPFS P2P"; return 0
        fi
        ipfs p2p close -p "/x/${SERVICE_NAME}-$selected_node" 2>/dev/null
        print_status "FAIL" "Connected but API not responding"
    else
        print_status "FAIL" "Failed to connect to $selected_node"
    fi
    return 1
}

close_ipfs_p2p() {
    local silent="${1:-false}"; local closed=0
    for conn in $(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $1}'); do
        ipfs p2p close -p "$conn" 2>/dev/null && ((closed++))
    done
    [[ $closed -gt 0 ]] && { [[ "$silent" != "true" ]] && print_status "OK" "Closed $closed P2P connection(s)"; rm -f "$STATUS_FILE"; return 0; }
    [[ "$silent" != "true" ]] && print_status "INFO" "No P2P connections to close"; return 1
}

########################################################
## Main Script
########################################################

case "${1^^}" in
    "STATUS"|"ST")
        print_header
        if check_port "true" && test_api "true"; then
            local_type="UNKNOWN"
            check_ssh_tunnel_active "true" && local_type="SSH"
            check_p2p_connections "true" && local_type="P2P"
            check_local_service "true" && local_type="LOCAL"
            echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTED${NC} via ${CYAN}$local_type${NC}"
            echo -e "    └─ Dashboard: ${GREEN}http://localhost:$QDRANT_PORT/dashboard${NC}"
            show_collections
        else
            echo -e "\n  ${RED}●${NC} ${BOLD}DISCONNECTED${NC}"
        fi ;;
    "SCAN"|"DETECT"|"LIST")
        print_header; echo -e "\n${BOLD}Scanning...${NC}\n"
        check_local_service "true" && print_status "OK" "Local Qdrant" || print_status "FAIL" "No local Qdrant"
        echo -e "\n${BOLD}[P2P]${NC}"; p2p_count=$(count_p2p_nodes)
        [[ $p2p_count -gt 0 ]] && print_status "OK" "$p2p_count P2P node(s)" || print_status "FAIL" "No P2P nodes"
        for s in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
            [[ -f "$s" ]] && echo -e "    ├─ ${CYAN}$(basename $(dirname "$s"))${NC}"
        done ;;
    "HELP"|"-H"|"--HELP")
        print_header
        echo -e "\n${BOLD}Usage:${NC} $(basename $0) [STATUS|SCAN|LOCAL|SSH|P2P|OFF|TEST|HELP]\n"
        echo -e "  ${CYAN}(none)${NC}    Auto LOCAL→SSH→P2P  |  ${CYAN}P2P <n>${NC}  Node by number"
        echo -e "  ${CYAN}OFF${NC}       Disconnect all       |  ${CYAN}TEST${NC}     Test API"
        echo -e "  ${CYAN}SCAN${NC}      List available nodes |  ${CYAN}STATUS${NC}   Connection status"
        echo -e "\n  Dashboard: http://localhost:$QDRANT_PORT/dashboard" ;;
    "OFF"|"DISCONNECT"|"CLOSE")
        print_header; echo -e "\n${BOLD}Disconnecting...${NC}"
        close_ssh_tunnel; close_ipfs_p2p ;;
    "TEST")   test_api; exit $? ;;
    "LOCAL")
        print_header
        if check_local_service && check_port "true" && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            print_status "OK" "Connected to local Qdrant"
            echo -e "Dashboard: ${GREEN}http://localhost:$QDRANT_PORT/dashboard${NC}"
            show_collections; exit 0
        fi
        print_status "FAIL" "Local Qdrant not available"; exit 1 ;;
    "SSH")    print_header; establish_ssh_tunnel "auto" && echo -e "API: http://localhost:$QDRANT_PORT" && exit 0; exit 1 ;;
    "SSH6")   print_header; establish_ssh_tunnel "ipv6" && exit 0; exit 1 ;;
    "SSH4")   print_header; establish_ssh_tunnel "ipv4" && exit 0; exit 1 ;;
    "P2P"|"SWARM"|"IPFS")
        print_header
        connect_via_swarm "$2" && echo -e "API: http://localhost:$QDRANT_PORT/dashboard" && exit 0; exit 1 ;;
    "")
        if check_port "true" && test_api "true"; then
            echo "Qdrant ready at http://localhost:$QDRANT_PORT/dashboard"; exit 0
        fi
        if establish_ssh_tunnel "auto"; then
            echo "Qdrant ready via SSH at http://localhost:$QDRANT_PORT/dashboard"; exit 0
        fi
        echo "SSH unavailable, trying IPFS P2P swarm..."
        if connect_via_swarm; then
            echo "Qdrant ready via P2P at http://localhost:$QDRANT_PORT/dashboard"; exit 0
        fi
        echo "Could not connect to any Qdrant instance."; exit 1 ;;
    *)
        echo "Unknown command: $1. Use '$(basename $0) HELP'."; exit 1 ;;
esac
