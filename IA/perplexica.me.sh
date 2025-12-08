#!/bin/bash
## Perplexica Swarm Connector
## Checks for local Perplexica API on port 3001
## Else try SSH tunnel to scorpio (IPv6/IPv4)
## Finally fallback to IPFS P2P swarm discovery
########################################################
## ZEN[0] Swarm Integration
########################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh" 2>/dev/null || true

# Configuration
PERPLEXICA_PORT=3001
SERVICE_NAME="perplexica"
REMOTE_USER="frd"
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT_IPV4=2122  # Port for IPv4 NAT access
REMOTE_PORT_IPV6=22    # Port for direct IPv6 access
SSH_OPTIONS="-fN -L 127.0.0.1:$PERPLEXICA_PORT:127.0.0.1:$PERPLEXICA_PORT"

# Function to check if port is open
check_port() {
    if netstat -tulnp 2>/dev/null | grep ":$PERPLEXICA_PORT " >/dev/null; then
        echo "Perplexica API port $PERPLEXICA_PORT is already open."
        return 0
    else
        echo "Perplexica API port $PERPLEXICA_PORT is not available."
        return 1
    fi
}

# Function to test Perplexica API connection
test_api() {
    echo "Testing Perplexica API connection on port $PERPLEXICA_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PERPLEXICA_PORT/api/models" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ]; then
        echo "Perplexica API is responding correctly."
        return 0
    else
        echo "Perplexica API not responding (HTTP $RESPONSE)."
        return 1
    fi
}

# Function to check IPv6 connectivity to remote host
check_ipv6_available() {
    local ipv6_addr
    ipv6_addr=$(dig +short AAAA "$REMOTE_HOST" 2>/dev/null | head -1)
    if [ -n "$ipv6_addr" ]; then
        echo "IPv6 address found: $ipv6_addr"
        # Test IPv6 connectivity with timeout
        if timeout 3 bash -c "echo >/dev/tcp/[$ipv6_addr]/$REMOTE_PORT_IPV6" 2>/dev/null; then
            echo "IPv6 connectivity to $REMOTE_HOST:$REMOTE_PORT_IPV6 OK"
            return 0
        fi
    fi
    echo "IPv6 not available"
    return 1
}

# Function to establish SSH tunnel to scorpio
establish_ssh_tunnel() {
    echo "Attempting to establish SSH tunnel to scorpio..."
    
    # Try IPv6 first (direct connection on port 22)
    if check_ipv6_available; then
        echo "Trying IPv6 connection on port $REMOTE_PORT_IPV6..."
        if ssh $SSH_OPTIONS -6 $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT_IPV6 2>/dev/null; then
            echo "SSH tunnel established via IPv6."
            sleep 2
            if check_port && test_api; then
                return 0
            fi
            close_ssh_tunnel
        fi
        echo "IPv6 connection failed, trying IPv4..."
    fi
    
    # Fallback to IPv4 (NAT via port 2122)
    echo "Trying IPv4 connection on port $REMOTE_PORT_IPV4..."
    if ssh $SSH_OPTIONS -4 $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT_IPV4 2>/dev/null; then
        echo "SSH tunnel established via IPv4."
        sleep 2
        if check_port && test_api; then
            return 0
        fi
        close_ssh_tunnel
    fi
    
    echo "Failed to establish SSH tunnel to scorpio."
    return 1
}

# Function to close SSH tunnel
close_ssh_tunnel() {
    echo "Closing SSH tunnel..."
    PID=$(lsof -t -i :$PERPLEXICA_PORT 2>/dev/null)
    if [ -n "$PID" ]; then
        kill $PID 2>/dev/null
        echo "SSH tunnel closed."
    fi
}

########################################################
## IPFS P2P Swarm Discovery Functions
########################################################

# Function to get shuffled list of available service nodes
get_shuffled_nodes() {
    local nodes=()
    
    # Collect all available x_<service>.sh scripts from swarm
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        if [[ -f "$script" ]]; then
            nodes+=("$script")
        fi
    done
    
    # Also check local node
    if [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]]; then
        nodes+=("$HOME/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh")
    fi
    
    # Shuffle the array using sort -R
    printf '%s\n' "${nodes[@]}" | sort -R
}

# Function to establish IPFS P2P connection
establish_ipfs_p2p() {
    local script="$1"
    local node_id=$(basename $(dirname "$script"))
    
    echo "Attempting IPFS P2P connection to $node_id..."
    
    # Check if connection already exists
    if ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}-$node_id" >/dev/null; then
        echo "IPFS P2P connection to $node_id already exists"
        return 0
    fi
    
    # Execute the IPFS P2P script
    if bash "$script" 2>/dev/null; then
        echo "IPFS P2P connection established to $node_id"
        return 0
    else
        echo "Failed IPFS P2P connection to $node_id"
        return 1
    fi
}

# Function to close IPFS P2P connections
close_ipfs_p2p() {
    echo "Closing ${SERVICE_NAME} IPFS P2P connections..."
    local closed=0
    
    for conn in $(ipfs p2p ls 2>/dev/null | grep "/x/${SERVICE_NAME}-" | awk '{print $1}'); do
        echo "Closing P2P connection: $conn"
        if ipfs p2p close -p "$conn" 2>/dev/null; then
            closed=$((closed + 1))
        fi
    done
    
    if [[ $closed -gt 0 ]]; then
        echo "Closed $closed P2P connections."
        return 0
    else
        echo "No P2P connections found."
        return 1
    fi
}

# Function to connect via IPFS P2P swarm
connect_via_swarm() {
    echo "Searching for ${SERVICE_NAME} nodes in ZEN[0] swarm..."
    
    local shuffled_nodes
    readarray -t shuffled_nodes < <(get_shuffled_nodes)
    
    if [[ ${#shuffled_nodes[@]} -eq 0 ]]; then
        echo "No ${SERVICE_NAME} nodes found in swarm"
        return 1
    fi
    
    echo "Found ${#shuffled_nodes[@]} ${SERVICE_NAME} node(s), trying randomly..."
    
    for script in "${shuffled_nodes[@]}"; do
        local node_id=$(basename $(dirname "$script"))
        echo "Trying ${SERVICE_NAME} node: $node_id"
        
        if establish_ipfs_p2p "$script"; then
            sleep 2
            if test_api; then
                echo "Successfully connected to $node_id via IPFS P2P"
                return 0
            else
                echo "Connected but API not responding, trying next..."
                ipfs p2p close -p "/x/${SERVICE_NAME}-$node_id" 2>/dev/null
            fi
        fi
    done
    
    echo "No working ${SERVICE_NAME} nodes available in swarm"
    return 1
}

# Function to discover available nodes
discover_nodes() {
    echo "Discovering ${SERVICE_NAME} nodes..."
    echo ""
    
    # Check local node
    if [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_${SERVICE_NAME}.sh ]]; then
        echo "Local node: $IPFSNODEID"
        if [[ -f ~/.zen/tmp/$IPFSNODEID/myIPFS.txt ]]; then
            echo "  Connection: $(cat ~/.zen/tmp/$IPFSNODEID/myIPFS.txt)"
        fi
    fi
    
    # Check swarm nodes
    for script in ~/.zen/tmp/swarm/*/x_${SERVICE_NAME}.sh; do
        if [[ -f "$script" ]]; then
            local node_id=$(basename $(dirname "$script"))
            echo "Swarm node: $node_id"
            local myipfs_file=$(dirname "$script")/myIPFS.txt
            if [[ -f "$myipfs_file" ]]; then
                echo "  Connection: $(cat "$myipfs_file")"
            fi
        fi
    done
}

########################################################
## Main Script
########################################################

case "$1" in
    "DISCOVER")
        discover_nodes
        exit 0
        ;;
    "OFF")
        close_ssh_tunnel
        close_ipfs_p2p
        exit 0
        ;;
    "TEST")
        test_api
        exit $?
        ;;
    *)
        # Check if already available
        if check_port && test_api; then
            echo "Perplexica API ready at http://localhost:$PERPLEXICA_PORT"
            exit 0
        fi
        
        # Try SSH tunnel to scorpio first (demo mode)
        if establish_ssh_tunnel; then
            echo "Perplexica API ready via SSH tunnel at http://localhost:$PERPLEXICA_PORT"
            exit 0
        fi
        
        # Fallback to IPFS P2P swarm (production mode ZEN[0])
        echo "Scorpio unavailable, trying IPFS P2P swarm..."
        if connect_via_swarm; then
            echo "Perplexica API ready via IPFS P2P at http://localhost:$PERPLEXICA_PORT"
            exit 0
        fi
        
        echo "Could not establish connection to any Perplexica API."
        exit 1
        ;;
esac
