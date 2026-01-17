#!/bin/bash
# Dependencies : jq curl dig nc
################################################################################
## ComfyUI Swarm Connector
## Checks for local ComfyUI API on port 8188
## Else try SSH tunnel to scorpio (IPv6/IPv4)
## Finally fallback to IPFS P2P swarm discovery
################################################################################
## ZEN[0] Swarm Integration - Enhanced Connection Manager + GPU Load Balancing
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

# Configuration
COMFYUI_PORT=8188
SERVICE_NAME="comfyui"
REMOTE_USER="frd"
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT_IPV4=2122  # Port for IPv4 NAT access
REMOTE_PORT_IPV6=22    # Port for direct IPv6 access
SSH_OPTIONS="-fN -L 127.0.0.1:$COMFYUI_PORT:127.0.0.1:$COMFYUI_PORT"

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
    echo -e "${BOLD}${CYAN}║${NC}  ${BOLD}${SERVICE_NAME^^} Connection Manager${NC}  (port $COMFYUI_PORT)        ${BOLD}${CYAN}║${NC}"
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
    echo "CONNECTION_PORT=$COMFYUI_PORT" >> "$STATUS_FILE"
}

########################################################
## Detection Functions
########################################################

# Check if port is open (silent mode available)
check_port() {
    local silent="${1:-false}"
    if netstat -tulnp 2>/dev/null | grep ":$COMFYUI_PORT " >/dev/null; then
        [[ "$silent" != "true" ]] && echo "Port $COMFYUI_PORT is open."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "Port $COMFYUI_PORT is not available."
        return 1
    fi
}

# Test ComfyUI API connection (silent mode available)
test_api() {
    local silent="${1:-false}"
    [[ "$silent" != "true" ]] && echo "Testing ComfyUI API on port $COMFYUI_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$COMFYUI_PORT/system_stats" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ]; then
        [[ "$silent" != "true" ]] && echo "ComfyUI API responding correctly."
        return 0
    else
        [[ "$silent" != "true" ]] && echo "ComfyUI API not responding (HTTP $RESPONSE)."
        return 1
    fi
}

# Check if LOCAL service is running
check_local_service() {
    local silent="${1:-false}"
    if pgrep -f "comfyui" >/dev/null 2>&1 || \
       pgrep -f "main.py.*--listen" >/dev/null 2>&1 || \
       systemctl is-active --quiet comfyui 2>/dev/null; then
        [[ "$silent" != "true" ]] && print_status "OK" "Local ComfyUI service detected"
        return 0
    fi
    return 1
}

# Check IPv6 connectivity
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

# Check IPv4 connectivity
check_ipv4_available() {
    local silent="${1:-false}"
    if timeout 3 bash -c "echo >/dev/tcp/$REMOTE_HOST/$REMOTE_PORT_IPV4" 2>/dev/null; then
        [[ "$silent" != "true" ]] && print_status "OK" "IPv4 to $REMOTE_HOST:$REMOTE_PORT_IPV4"
        return 0
    fi
    [[ "$silent" != "true" ]] && print_status "FAIL" "IPv4 not available"
    return 1
}

# Check if SSH tunnel is active
check_ssh_tunnel_active() {
    local silent="${1:-false}"
    local pid=$(lsof -t -i :$COMFYUI_PORT 2>/dev/null)
    if [[ -n "$pid" ]]; then
        local proc_info=$(ps -p $pid -o comm= 2>/dev/null)
        if [[ "$proc_info" == "ssh" ]]; then
            [[ "$silent" != "true" ]] && print_status "ACTIVE" "SSH tunnel (PID: $pid)"
            return 0
        fi
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

# Get system stats from ComfyUI
get_system_stats() {
    local silent="${1:-false}"
    if test_api "true"; then
        local stats=$(curl -s "http://localhost:$COMFYUI_PORT/system_stats" 2>/dev/null)
        if [[ -n "$stats" ]]; then
            [[ "$silent" != "true" ]] && echo -e "\n${BOLD}System Stats:${NC}"
            local gpu_name=$(echo "$stats" | jq -r '.devices[0].name // "N/A"' 2>/dev/null)
            local gpu_vram=$(echo "$stats" | jq -r '.devices[0].vram_total // 0' 2>/dev/null)
            local gpu_vram_free=$(echo "$stats" | jq -r '.devices[0].vram_free // 0' 2>/dev/null)
            
            if [[ "$gpu_vram" != "0" && "$gpu_vram" != "null" ]]; then
                local vram_gb=$(echo "scale=1; $gpu_vram / 1073741824" | bc 2>/dev/null)
                local vram_free_gb=$(echo "scale=1; $gpu_vram_free / 1073741824" | bc 2>/dev/null)
                [[ "$silent" != "true" ]] && echo -e "    ├─ GPU: ${CYAN}$gpu_name${NC}"
                [[ "$silent" != "true" ]] && echo -e "    └─ VRAM: ${vram_free_gb}GB free / ${vram_gb}GB total"
            fi
        fi
    fi
}

########################################################
## Connection Functions
########################################################

# Establish SSH tunnel
establish_ssh_tunnel() {
    local protocol="${1:-auto}"  # auto, ipv6, ipv4
    
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

# Close SSH tunnel
close_ssh_tunnel() {
    local silent="${1:-false}"
    local pid=$(lsof -t -i :$COMFYUI_PORT 2>/dev/null)
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
    # Priority: SSH tunnel > P2P > Local (most specific first)
    if check_port "true"; then
        # 1. Check SSH tunnel first (process on port is 'ssh')
        if check_ssh_tunnel_active "true"; then
            active_type="SSH"
            if [[ -f "$STATUS_FILE" ]]; then
                source "$STATUS_FILE"
                active_details="$CONNECTION_DETAILS"
                connection_time="$CONNECTION_TIME"
            fi
        # 2. Check P2P connections (ipfs p2p ls shows active connections)
        elif check_p2p_connections "true"; then
            active_type="P2P"
            if [[ -f "$STATUS_FILE" ]]; then
                source "$STATUS_FILE"
                active_details="$CONNECTION_DETAILS"
                connection_time="$CONNECTION_TIME"
            else
                active_details=$(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}" | awk '{print $3}' | head -1)
            fi
        # 3. Local service (fallback - only if no tunnel or P2P)
        elif check_local_service "true"; then
            active_type="LOCAL"
            active_details="Local service (ComfyUI)"
        else
            active_type="UNKNOWN"
            active_details="Port open but source unknown"
        fi
        
        if test_api "true"; then
            echo -e "\n  ${GREEN}●${NC} ${BOLD}CONNECTED${NC} via ${CYAN}$active_type${NC}"
            [[ -n "$active_details" ]] && echo -e "    └─ $active_details"
            echo -e "    └─ API: ${GREEN}http://localhost:$COMFYUI_PORT${NC}"
            [[ -n "$connection_time" ]] && echo -e "    └─ Since: $connection_time"
            
            # Show GPU stats
            get_system_stats
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
    
    # 2. SSH
    echo -e "\n${BOLD}[SSH] ${NC}→ $REMOTE_HOST"
    local ssh_available=false
    
    echo -n "  IPv6: "
    if check_ipv6_available "true"; then
        echo -e "${GREEN}Available${NC} (port $REMOTE_PORT_IPV6)"
        ssh_available=true
    else
        echo -e "${RED}Not available${NC}"
    fi
    
    echo -n "  IPv4: "
    if check_ipv4_available "true"; then
        echo -e "${GREEN}Available${NC} (port $REMOTE_PORT_IPV4)"
        ssh_available=true
    else
        echo -e "${RED}Not available${NC}"
    fi
    
    if check_ssh_tunnel_active "true"; then
        echo -e "  ${GREEN}●${NC} Tunnel currently ACTIVE"
    fi
    
    # 3. IPFS P2P
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
    echo -e "  Available methods: LOCAL=$(check_local_service true && echo Y || echo N) SSH=$([[ "$ssh_available" == "true" ]] && echo Y || echo N) P2P=$([[ $p2p_count -gt 0 ]] && echo Y || echo N)"
}

# HELP - Show usage
cmd_help() {
    print_header
    echo -e "\n${BOLD}Usage:${NC} $(basename $0) [COMMAND] [OPTIONS]\n"
    
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  ${CYAN}(none)${NC}      Auto-connect (LOCAL → SSH → P2P)"
    echo -e "  ${CYAN}STATUS${NC}      Show current connection status + GPU info"
    echo -e "  ${CYAN}SCAN${NC}        Detect all available connections"
    echo -e "  ${CYAN}LOCAL${NC}       Connect via local service"
    echo -e "  ${CYAN}SSH${NC}         Connect via SSH tunnel"
    echo -e "  ${CYAN}SSH6${NC}        Connect via SSH tunnel (IPv6 only)"
    echo -e "  ${CYAN}SSH4${NC}        Connect via SSH tunnel (IPv4 only)"
    echo -e "  ${CYAN}P2P${NC}         Connect via IPFS P2P swarm"
    echo -e "  ${CYAN}P2P <node>${NC}  Connect to specific P2P node"
    echo -e "  ${CYAN}OFF${NC}         Disconnect all connections"
    echo -e "  ${CYAN}TEST${NC}        Test current API connection"
    echo -e "  ${CYAN}HELP${NC}        Show this help message"
    
    echo -e "\n${BOLD}Examples:${NC}"
    echo -e "  $(basename $0)                    # Auto-connect"
    echo -e "  $(basename $0) SCAN               # See available options"
    echo -e "  $(basename $0) SSH                # Force SSH connection"
    echo -e "  $(basename $0) P2P 12D3KooW...    # Connect to specific node"
    echo -e "  $(basename $0) STATUS             # Check GPU status"
    echo -e "  $(basename $0) OFF                # Disconnect"
}

########################################################
## Main Script - Command Handler
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
        close_ssh_tunnel
        close_ipfs_p2p
        exit 0
        ;;
    "TEST")
        test_api
        exit $?
        ;;
    "LOCAL")
        print_header
        echo -e "\n${BOLD}Connecting via LOCAL...${NC}"
        if check_local_service && check_port "true" && test_api "true"; then
            save_connection_status "LOCAL" "Local service"
            print_status "OK" "Connected to local ${SERVICE_NAME}"
            echo -e "API ready at ${GREEN}http://localhost:$COMFYUI_PORT${NC}"
            get_system_stats
            exit 0
        fi
        print_status "FAIL" "Local ${SERVICE_NAME} not available"
        exit 1
        ;;
    "SSH")
        print_header
        if establish_ssh_tunnel "auto"; then
            echo -e "API ready at ${GREEN}http://localhost:$COMFYUI_PORT${NC}"
            get_system_stats
            exit 0
        fi
        exit 1
        ;;
    "SSH6"|"IPV6")
        print_header
        if establish_ssh_tunnel "ipv6"; then
            echo -e "API ready at ${GREEN}http://localhost:$COMFYUI_PORT${NC}"
            get_system_stats
            exit 0
        fi
        exit 1
        ;;
    "SSH4"|"IPV4")
        print_header
        if establish_ssh_tunnel "ipv4"; then
            echo -e "API ready at ${GREEN}http://localhost:$COMFYUI_PORT${NC}"
            get_system_stats
            exit 0
        fi
        exit 1
        ;;
    "P2P"|"SWARM"|"IPFS")
        print_header
        if connect_via_swarm "$2"; then
            echo -e "API ready at ${GREEN}http://localhost:$COMFYUI_PORT${NC}"
            get_system_stats
            exit 0
        fi
        exit 1
        ;;
    "")
        # Auto-connect mode (default behavior)
        # Check if already available
        if check_port "true" && test_api "true"; then
            echo "${SERVICE_NAME^} API ready at http://localhost:$COMFYUI_PORT"
            exit 0
        fi
        
        # Try SSH tunnel first
        if establish_ssh_tunnel "auto"; then
            echo "${SERVICE_NAME^} API ready via SSH at http://localhost:$COMFYUI_PORT"
            exit 0
        fi
        
        # Fallback to IPFS P2P swarm
        echo "SSH unavailable, trying IPFS P2P swarm..."
        if connect_via_swarm; then
            echo "${SERVICE_NAME^} API ready via P2P at http://localhost:$COMFYUI_PORT"
            exit 0
        fi
        
        echo "Could not establish connection to any ${SERVICE_NAME^} API."
        exit 1
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$(basename $0) HELP' for usage information."
        exit 1
        ;;
esac
