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
. "${HOME}/.zen/Astroport.ONE/tools/my.sh" 2>/dev/null || true
resolve_swarm_remote_target "scorpio.copylaradio.com" 2122 22

# Configuration
QDRANT_PORT=6333
SERVICE_NAME="qdrant"
SERVICE_PORT=$QDRANT_PORT
STATUS_FILE="$HOME/.zen/tmp/${SERVICE_NAME}_connection.status"
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

########################################################
## Service-specific functions (must be defined before lib source)
########################################################

## Fichier vétéran : horodatage du 1er Qdrant OK sur ce node
## Utilisé pour classer les nodes swarm par ancienneté (fiabilité)
VETERAN_FILE="$HOME/.zen/tmp/qdrant_veteran_since"

_record_veteran() {
    [[ -f "$VETERAN_FILE" ]] && return
    date -u +%s > "$VETERAN_FILE"
}

veteran_days() {
    [[ -f "$VETERAN_FILE" ]] || { echo 0; return; }
    local since
    since=$(cat "$VETERAN_FILE" 2>/dev/null)
    [[ -z "$since" ]] && { echo 0; return; }
    echo $(( ( $(date +%s) - since ) / 86400 ))
}

test_api() {
    local silent="${1:-false}"
    [[ "$silent" != "true" ]] && echo "Testing Qdrant API on port $QDRANT_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$QDRANT_PORT/healthz" --connect-timeout 5)
    if [[ "$RESPONSE" == "200" || "$RESPONSE" == "204" ]]; then
        _record_veteran
        [[ "$silent" != "true" ]] && echo "Qdrant API responding correctly (vétéran depuis $(veteran_days) jours)."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Qdrant API not responding (HTTP $RESPONSE)."
        return 1
    fi
}

# Source shared library (provides: print_status, save_connection_status,
# check_port, count_p2p_nodes, check_p2p_connections, close_ipfs_p2p,
# connect_via_swarm)
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../swarm_connector_lib.sh"

########################################################
## Service-specific functions
########################################################

print_header() {
    echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}Qdrant VectorDB Connection Manager${NC}  (port $QDRANT_PORT)  ${BOLD}${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
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

    close_ssh_tunnel "true"

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
    local pids
    pids=$(lsof -t -i :"$QDRANT_PORT" 2>/dev/null)
    local closed=0

    for pid in $pids; do
        if [[ "$(ps -p "$pid" -o comm= 2>/dev/null)" == "ssh" ]]; then
            kill "$pid" 2>/dev/null && ((closed++))
        fi
    done

    if [[ $closed -gt 0 ]]; then
        [[ "$silent" != "true" ]] && print_status "OK" "SSH tunnel(s) closed ($closed PID(s))"
        rm -f "$STATUS_FILE"; return 0
    fi
    [[ "$silent" != "true" ]] && print_status "INFO" "No SSH tunnel to close"; return 1
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
            echo -e "    └─ Vétéran: ${CYAN}$(veteran_days) jour(s)${NC} de service Qdrant continu"
            show_collections
        else
            echo -e "\n  ${RED}●${NC} ${BOLD}DISCONNECTED${NC}"
        fi ;;
    "SCAN"|"DETECT"|"LIST")
        print_header; echo -e "\n${BOLD}Scanning...${NC}\n"
        if check_local_service "true" && check_port "true" && test_api "true"; then
            print_status "OK" "Local Qdrant (vétéran $(veteran_days)j)"
        else
            print_status "FAIL" "No local Qdrant"
        fi
        echo -e "\n${BOLD}[Swarm — trié par ancienneté]${NC}"
        # Lire les 12345.json du swarm et trier par qdrant_veteran_days décroissant
        declare -a _swarm_list=()
        for _s12 in ~/.zen/tmp/swarm/*/12345.json; do
            [[ -f "$_s12" ]] || continue
            _nid=$(basename "$(dirname "$_s12")")
            _days=$(jq -r '.capacities.qdrant_veteran_days // 0' "$_s12" 2>/dev/null || echo 0)
            _score=$(jq -r '.capacities.power_score // 0' "$_s12" 2>/dev/null || echo 0)
            _dom=$(jq -r '.myDOMAIN // ""' "$_s12" 2>/dev/null || echo "")
            _swarm_list+=("${_days}|${_score}|${_nid}|${_dom}")
        done
        # Trier : ancienneté décroissante, puis power_score décroissant
        IFS=$'\n' _sorted=($(printf '%s\n' "${_swarm_list[@]}" | sort -t'|' -k1 -rn -k2 -rn))
        for _entry in "${_sorted[@]}"; do
            IFS='|' read -r _d _sc _n _dom <<< "$_entry"
            [[ $_d -gt 0 ]] && _vet="${GREEN}⭐${_d}j${NC}" || _vet="${YELLOW}nouveau${NC}"
            echo -e "    ├─ ${CYAN}${_dom:-${_n:0:12}}${NC}  score=${_sc}  vétéran=$(echo -e "$_vet")"
        done
        [[ ${#_sorted[@]} -eq 0 ]] && echo -e "    (aucun node swarm avec Qdrant détecté)" ;;
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
        if connect_via_swarm; then
            echo "Qdrant ready via P2P at http://localhost:$QDRANT_PORT/dashboard"; exit 0
        fi
        echo "P2P unavailable, trying SSH tunnel as fallback..."
        if establish_ssh_tunnel "auto"; then
            echo "Qdrant ready via SSH at http://localhost:$QDRANT_PORT/dashboard"; exit 0
        fi
        echo "Could not connect to any Qdrant instance."; exit 1 ;;
    *)
        echo "Unknown command: $1. Use '$(basename $0) HELP'."; exit 1 ;;
esac
