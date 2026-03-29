#!/bin/bash
################################################################################
## Open WebUI Swarm Connector
## Checks for local Open WebUI on port 8000
## Else try SSH tunnel to scorpio (IPv6/IPv4)
## Finally fallback to IPFS P2P swarm discovery
################################################################################
## ZEN[0] Swarm Integration - Enhanced Connection Manager
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

# Configuration
OPENWEBUI_PORT=8000
SERVICE_NAME="open-webui"
## Passerelle SSH — configurable dans ~/.zen/Astroport.ONE/.env
## (my.sh source déjà .env donc SWARM_REMOTE_* est disponible ici)
REMOTE_HOST="${SWARM_REMOTE_HOST:-scorpio.copylaradio.com}"
REMOTE_USER="${SWARM_REMOTE_USER:-frd}"
REMOTE_PORT_IPV4="${SWARM_REMOTE_PORT_IPV4:-2122}"   # Port NAT IPv4
REMOTE_PORT_IPV6="${SWARM_REMOTE_PORT_IPV6:-22}"    # Port SSH direct IPv6
SSH_OPTIONS="-fN -L 127.0.0.1:$OPENWEBUI_PORT:127.0.0.1:$OPENWEBUI_PORT"

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
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}Open WebUI Connection Manager${NC}  (port $OPENWEBUI_PORT)      ${BOLD}${CYAN}║${NC}"
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
    echo "CONNECTION_PORT=$OPENWEBUI_PORT" >> "$STATUS_FILE"
}

########################################################
## Detection Functions
########################################################

check_port() {
    local silent="${1:-false}"
    if netstat -tulnp 2>/dev/null | grep ":$OPENWEBUI_PORT " >/dev/null || \
       ss -tln 2>/dev/null | grep -qw ":$OPENWEBUI_PORT"; then
        [[ "$silent" != "true" ]] && echo "Port $OPENWEBUI_PORT is open."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Port $OPENWEBUI_PORT is not available."
        return 1
    fi
}

test_api() {
    local silent="${1:-false}"
    [[ "$silent" != "true" ]] && echo "Testing Open WebUI API on port $OPENWEBUI_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$OPENWEBUI_PORT/api/config" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ]; then
        [[ "$silent" != "true" ]] && echo "Open WebUI responding correctly."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Open WebUI not responding (HTTP $RESPONSE)."
        return 1
    fi
}

check_local_service() {
    local silent="${1:-false}"
    if docker ps 2>/dev/null | grep -q "open-webui" || \
       pgrep -f "open.webui" >/dev/null 2>&1; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local Open WebUI service detected"
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
    local pid=$(lsof -t -i :$OPENWEBUI_PORT 2>/dev/null)
    if [[ -n "$pid" ]]; then
        local proc_info=$(ps -p $pid -o comm= 2>/dev/null)
        if [[ "$proc_info" == "ssh" ]]; then
            [[ "$silent" != "true" ]] && print_status "ACTIVE" "SSH tunnel (PID: $pid)"
            return 0
        fi
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
## Connection Functions
########################################################

establish_ssh_tunnel() {
    local protocol="${1:-auto}"
    echo -e "\n${BOLD}Establishing SSH tunnel...${NC}"

    if [[ "$protocol" == "auto" || "$protocol" == "ipv6" ]]; then
        if check_ipv6_available "true"; then
            echo "Trying IPv6 connection..."
            if ssh $SSH_OPTIONS -6 $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT_IPV6 2>/dev/null; then
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
            if ssh $SSH_OPTIONS -4 $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT_IPV4 2>/dev/null; then
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
    local pid=$(lsof -t -i :$OPENWEBUI_PORT 2>/dev/null)
    if [[ -n "$pid" ]]; then
        local proc_info=$(ps -p $pid -o comm= 2>/dev/null)
        if [[ "$proc_info" == "ssh" ]]; then
            kill $pid 2>/dev/null
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

    local nodes=()
    local node_ids=()

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
        print_status "FAIL" "No ${SERVICE_NAME} nodes found in swarm"
        return 1
    fi

    local selected_script=""
    local selected_node=""

    if [[ -n "$target" ]]; then
        case "$target" in
            "auto"|"random"|"AUTO"|"RANDOM")
                local shuffled=($(printf '%s\n' "${!nodes[@]}" | sort -R))
                for idx in "${shuffled[@]}"; do
                    selected_script="${nodes[$idx]}"
                    selected_node="${node_ids[$idx]}"
                    echo "Trying node: $selected_node"
                    if bash "$selected_script" 2>/dev/null; then
                        sleep 2
                        if test_api "true"; then
                            save_connection_status "P2P" "$selected_node"
                            print_status "OK" "Connected to $selected_node via IPFS P2P"
                            return 0
                        fi
                        ipfs p2p close -p "/x/${SERVICE_NAME}-$selected_node" 2>/dev/null
                    fi
                done
                print_status "FAIL" "No working nodes available"
                return 1
                ;;
            [0-9]|[0-9][0-9])
                local idx=$((target - 1))
                if [[ $idx -ge 0 && $idx -lt ${#nodes[@]} ]]; then
                    selected_script="${nodes[$idx]}"
                    selected_node="${node_ids[$idx]}"
                else
                    print_status "FAIL" "Invalid selection: $target (valid: 1-${#nodes[@]})"
                    return 1
                fi
                ;;
            *)
                for i in "${!node_ids[@]}"; do
                    if [[ "${node_ids[$i]}" == "$target" || "${node_ids[$i]}" == *"$target"* ]]; then
                        selected_script="${nodes[$i]}"
                        selected_node="${node_ids[$i]}"
                        break
                    fi
                done
                if [[ -z "$selected_script" ]]; then
                    print_status "FAIL" "Node not found: $target"
                    for i in "${!node_ids[@]}"; do
                        echo -e "  [$((i+1))] ${node_ids[$i]:0:30}..."
                    done
                    return 1
                fi
                ;;
        esac
    else
        if [[ ${#nodes[@]} -gt 1 ]]; then
            echo -e "\n${BOLD}Available P2P nodes:${NC}\n"
            for i in "${!node_ids[@]}"; do
                local node_id="${node_ids[$i]}"
                local myipfs_file=$(dirname "${nodes[$i]}")/myIPFS.txt
                local gateway=""
                [[ -f "$myipfs_file" ]] && gateway=$(cat "$myipfs_file")
                local local_marker=""
                [[ "$node_id" == "$IPFSNODEID" ]] && local_marker=" ${GREEN}(local)${NC}"
                echo -e "  ${CYAN}[$((i+1))]${NC} ${node_id:0:20}...${local_marker}"
                [[ -n "$gateway" ]] && echo -e "      └─ $gateway"
            done
            echo ""
            echo -e "${YELLOW}Tip:${NC} Use 'P2P <number>' or 'P2P <node_id>' to select"
            echo ""
            echo -e "Connecting to first available node..."
        fi
        selected_script="${nodes[0]}"
        selected_node="${node_ids[0]}"
    fi

    if [[ -n "$selected_script" ]]; then
        echo "Connecting to: $selected_node"
        if bash "$selected_script" 2>/dev/null; then
            sleep 2
            if test_api "true"; then
                save_connection_status "P2P" "$selected_node"
                print_status "OK" "Connected to $selected_node via IPFS P2P"
                return 0
            else
                ipfs p2p close -p "/x/${SERVICE_NAME}-$selected_node" 2>/dev/null
                print_status "FAIL" "Connected but API not responding"
                return 1
            fi
        else
            print_status "FAIL" "Failed to establish P2P connection to $selected_node"
            return 1
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
    echo -e "\n${BOLD}Current Connection Status:${NC}"

    if check_port "true"; then
        local active_type="UNKNOWN"
        local active_details=""
        local connection_time=""

        if check_ssh_tunnel_active "true"; then
            active_type="SSH"
            [[ -f "$STATUS_FILE" ]] && source "$STATUS_FILE" && active_details="$CONNECTION_DETAILS" && connection_time="$CONNECTION_TIME"
        elif check_p2p_connections "true"; then
            active_type="P2P"
            if [[ -f "$STATUS_FILE" ]]; then
                source "$STATUS_FILE"; active_details="$CONNECTION_DETAILS"; connection_time="$CONNECTION_TIME"
            else
                active_details=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $3}' | head -1)
            fi
        elif check_local_service "true"; then
            active_type="LOCAL"
            active_details="Local service (open-webui)"
        fi

        if test_api "true"; then
            echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTED${NC} via ${CYAN}$active_type${NC}"
            [[ -n "$active_details" ]] && echo -e "    └─ $active_details"
            echo -e "    └─ UI: ${GREEN}http://localhost:$OPENWEBUI_PORT${NC}"
            [[ -n "$connection_time" ]] && echo -e "    └─ Since: $connection_time"
            return 0
        fi
    fi

    echo -e "\n  ${RED}●${NC} ${BOLD}DISCONNECTED${NC}"
    echo -e "    └─ No active Open WebUI connection"
    return 1
}

cmd_scan() {
    print_header
    echo -e "\n${BOLD}Scanning Available Connections:${NC}\n"

    echo -e "${BOLD}[LOCAL]${NC}"
    check_local_service "true" && print_status "OK" "Local Open WebUI service available" || print_status "FAIL" "No local Open WebUI service"

    echo -e "\n${BOLD}[SSH]${NC} → $REMOTE_HOST"
    check_ipv6_available "true" && echo -e "  IPv6: ${GREEN}Available${NC}" || echo -e "  IPv6: ${RED}Not available${NC}"
    check_ipv4_available "true" && echo -e "  IPv4: ${GREEN}Available${NC} (port $REMOTE_PORT_IPV4)" || echo -e "  IPv4: ${RED}Not available${NC}"
    check_ssh_tunnel_active "true" && echo -e "  ${GREEN}●${NC} Tunnel currently ACTIVE"

    echo -e "\n${BOLD}[P2P]${NC} IPFS Swarm Nodes"
    local p2p_count=$(count_p2p_nodes)
    if [[ $p2p_count -gt 0 ]]; then
        print_status "OK" "$p2p_count node(s) available"
        for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
            [[ -f "$script" ]] && echo -e "    ├─ ${CYAN}$(basename $(dirname "$script"))${NC}"
        done
    else
        print_status "FAIL" "No P2P nodes found"
    fi
    check_p2p_connections "true" && echo -e "  ${GREEN}●${NC} P2P currently ACTIVE"
}

cmd_help() {
    print_header
    echo -e "\n${BOLD}Usage:${NC} $(basename $0) [COMMAND] [OPTIONS]\n"
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${CYAN}(none)${NC}       Auto-connect (LOCAL → SSH → P2P)"
    echo -e "  ${CYAN}STATUS${NC}       Show current connection status"
    echo -e "  ${CYAN}SCAN${NC}         Detect all available connections"
    echo -e "  ${CYAN}LOCAL${NC}        Connect via local service"
    echo -e "  ${CYAN}SSH${NC}          Connect via SSH tunnel (auto IPv6/IPv4)"
    echo -e "  ${CYAN}P2P${NC}          Connect via IPFS P2P swarm"
    echo -e "  ${CYAN}P2P <n>${NC}      Connect to node by number"
    echo -e "  ${CYAN}P2P auto${NC}     Random node selection"
    echo -e "  ${CYAN}OFF${NC}          Disconnect all connections"
    echo -e "  ${CYAN}TEST${NC}         Test current API connection"
    echo -e "  ${CYAN}HELP${NC}         Show this help"
}

########################################################
## Main Script
########################################################

case "${1^^}" in
    "STATUS"|"ST")   cmd_status; exit $? ;;
    "SCAN"|"DETECT"|"LIST") cmd_scan; exit 0 ;;
    "HELP"|"-H"|"--HELP")   cmd_help; exit 0 ;;
    "OFF"|"DISCONNECT"|"CLOSE")
        print_header; echo -e "\n${BOLD}Disconnecting...${NC}"
        close_ssh_tunnel; close_ipfs_p2p; exit 0 ;;
    "TEST")   test_api; exit $? ;;
    "LOCAL")
        print_header; echo -e "\n${BOLD}Connecting via LOCAL...${NC}"
        if check_local_service && check_port "true" && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            print_status "OK" "Connected to local Open WebUI"
            echo -e "UI ready at ${GREEN}http://localhost:$OPENWEBUI_PORT${NC}"
            exit 0
        fi
        print_status "FAIL" "Local Open WebUI not available"; exit 1 ;;
    "SSH")
        print_header
        establish_ssh_tunnel "auto" && echo -e "UI ready at ${GREEN}http://localhost:$OPENWEBUI_PORT${NC}" && exit 0; exit 1 ;;
    "SSH6"|"IPV6")
        print_header
        establish_ssh_tunnel "ipv6" && echo -e "UI ready at ${GREEN}http://localhost:$OPENWEBUI_PORT${NC}" && exit 0; exit 1 ;;
    "SSH4"|"IPV4")
        print_header
        establish_ssh_tunnel "ipv4" && echo -e "UI ready at ${GREEN}http://localhost:$OPENWEBUI_PORT${NC}" && exit 0; exit 1 ;;
    "P2P"|"SWARM"|"IPFS")
        print_header
        connect_via_swarm "$2" && echo -e "UI ready at ${GREEN}http://localhost:$OPENWEBUI_PORT${NC}" && exit 0; exit 1 ;;
    "")
        if check_port "true" && test_api "true"; then
            echo "Open WebUI ready at http://localhost:$OPENWEBUI_PORT"; exit 0
        fi
        if establish_ssh_tunnel "auto"; then
            echo "Open WebUI ready via SSH at http://localhost:$OPENWEBUI_PORT"; exit 0
        fi
        echo "SSH unavailable, trying IPFS P2P swarm..."
        if connect_via_swarm; then
            echo "Open WebUI ready via P2P at http://localhost:$OPENWEBUI_PORT"; exit 0
        fi
        echo "Could not establish connection to any Open WebUI instance."; exit 1 ;;
    *)
        echo "Unknown command: $1"; echo "Use '$(basename $0) HELP' for usage."; exit 1 ;;
esac
