#!/bin/bash
## Orpheus Swarm Connector
## Checks for local Orpheus TTS API on port 5005
## Establishes IPFS P2P connection if not available locally
## Uses x_orpheus.sh scripts from swarm nodes for P2P forwarding
## PRIORITY: Nodes with active subscriptions first
########################################################
## IPFS P2P Swarm Integration
########################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

# Configuration
ORPHEUS_PORT=5005

# Function to check if we have an active subscription with a node
check_subscription() {
    local node_id="$1"
    local subscription_file="$HOME/.zen/tmp/${IPFSNODEID}/swarm_subscriptions.json"
    
    if [[ -f "$subscription_file" ]]; then
        # Check if node_id exists in subscriptions and is active
        if jq -e --arg nodeid "$node_id" '.[$nodeid] | select(.status == "active")' "$subscription_file" >/dev/null 2>&1; then
            return 0  # Subscription exists and is active
        fi
    fi
    return 1  # No active subscription
}

# Function to get subscription details
get_subscription_info() {
    local node_id="$1"
    local subscription_file="$HOME/.zen/tmp/${IPFSNODEID}/swarm_subscriptions.json"
    
    if [[ -f "$subscription_file" ]]; then
        jq -r --arg nodeid "$node_id" '.[$nodeid] // empty' "$subscription_file" 2>/dev/null
    fi
}

# Function to check if local Orpheus is running
check_local_orpheus() {
    echo "Checking for local Orpheus TTS service..."
    
    # Check if Docker container is running
    if docker ps | grep orpheus >/dev/null 2>&1; then
        echo "Local Orpheus Docker container is running"
        return 0
    fi
    
    # Check if port is responding
    if netstat -tulnp 2>/dev/null | grep ":$ORPHEUS_PORT " >/dev/null; then
        echo "Local Orpheus TTS API port $ORPHEUS_PORT is available."
        return 0
    fi
    
    echo "No local Orpheus service found"
    return 1
}

# Function to discover Orpheus nodes in the swarm
discover_orpheus_nodes() {
    echo "Discovering Orpheus nodes in the swarm..."
    
    # Check local node first
    if [[ -n "$IPFSNODEID" && -f ~/.zen/tmp/$IPFSNODEID/x_orpheus.sh ]]; then
        echo "Local Orpheus node found: $IPFSNODEID"
        if [[ -f ~/.zen/tmp/$IPFSNODEID/myIPFS.txt ]]; then
            local myipfs=$(cat ~/.zen/tmp/$IPFSNODEID/myIPFS.txt)
            echo "  Connection: $myipfs"
        fi
    fi
    
    # Check swarm nodes with subscription status
    for orpheus_script in ~/.zen/tmp/swarm/*/x_orpheus.sh; do
        if [[ -f "$orpheus_script" ]]; then
            local node_id=$(basename $(dirname "$orpheus_script"))
            local subscription_status="❌ No subscription"
            
            if check_subscription "$node_id"; then
                subscription_status="✅ Active subscription"
                local sub_info=$(get_subscription_info "$node_id")
                local sub_type=$(echo "$sub_info" | jq -r '.type // "unknown"' 2>/dev/null)
                local sub_date=$(echo "$sub_info" | jq -r '.start_date // "unknown"' 2>/dev/null)
                subscription_status="✅ Active subscription ($sub_type since $sub_date)"
            fi
            
            echo "Swarm Orpheus node found: $node_id - $subscription_status"
            
            local myipfs_file=$(dirname "$orpheus_script")/myIPFS.txt
            if [[ -f "$myipfs_file" ]]; then
                local myipfs=$(cat "$myipfs_file")
                echo "  Connection: $myipfs"
                
                # Extract host from myIPFS.txt
                local host=$(echo "$myipfs" | sed -n 's|.*//\([^/]*\)/.*|\1|p')
                if [[ -n "$host" ]]; then
                    echo "  Host: $host"
                fi
            fi
            echo "  Script: $orpheus_script"
        fi
    done
}

# Function to get nodes with subscriptions first, then others
get_prioritized_orpheus_nodes() {
    local subscribed_nodes=()
    local other_nodes=()
    
    # Collect and categorize all available x_orpheus.sh scripts
    for orpheus_script in ~/.zen/tmp/swarm/*/x_orpheus.sh; do
        if [[ -f "$orpheus_script" ]]; then
            local node_id=$(basename $(dirname "$orpheus_script"))
            
            if check_subscription "$node_id"; then
                subscribed_nodes+=("$orpheus_script")
            else
                other_nodes+=("$orpheus_script")
            fi
        fi
    done
    
    # Shuffle both arrays separately
    local shuffled_subscribed
    local shuffled_others
    
    if [[ ${#subscribed_nodes[@]} -gt 0 ]]; then
        readarray -t shuffled_subscribed < <(printf '%s\n' "${subscribed_nodes[@]}" | sort -R)
        echo "Found ${#shuffled_subscribed[@]} Orpheus nodes with active subscriptions" >&2
    fi
    
    if [[ ${#other_nodes[@]} -gt 0 ]]; then
        readarray -t shuffled_others < <(printf '%s\n' "${other_nodes[@]}" | sort -R)
        echo "Found ${#shuffled_others[@]} other Orpheus nodes available" >&2
    fi
    
    # Return subscribed nodes first, then others
    printf '%s\n' "${shuffled_subscribed[@]}" "${shuffled_others[@]}"
}

# Function to get shuffled list of available Orpheus nodes (legacy - kept for compatibility)
get_shuffled_orpheus_nodes() {
    local nodes=()
    
    # Collect all available x_orpheus.sh scripts
    for orpheus_script in ~/.zen/tmp/swarm/*/x_orpheus.sh; do
        if [[ -f "$orpheus_script" ]]; then
            nodes+=("$orpheus_script")
        fi
    done
    
    # Shuffle the array using sort -R
    printf '%s\n' "${nodes[@]}" | sort -R
}

# Function to establish IPFS P2P connection using x_orpheus.sh script
establish_ipfs_p2p() {
    local orpheus_script="$1"
    local node_id=$(basename $(dirname "$orpheus_script"))
    
    echo "Attempting to establish IPFS P2P connection to $node_id..."
    
    # Show subscription status
    if check_subscription "$node_id"; then
        local sub_info=$(get_subscription_info "$node_id")
        local sub_type=$(echo "$sub_info" | jq -r '.type // "unknown"' 2>/dev/null)
        echo "✅ Using subscribed node ($sub_type subscription)"
    else
        echo "⚠️  Using non-subscribed node (limited access)"
    fi
    
    # Check if connection already exists
    if ipfs p2p ls | grep "/x/orpheus-$node_id" >/dev/null; then
        echo "IPFS P2P connection to $node_id already exists"
        return 0
    fi
    
    # Execute the IPFS P2P script directly (it uses port 5005)
    echo "Executing IPFS P2P script for $node_id..."
    if bash "$orpheus_script"; then
        echo "IPFS P2P connection established successfully to $node_id"
        return 0
    else
        echo "Failed to establish IPFS P2P connection to $node_id"
        return 1
    fi
}

# Function to close IPFS P2P connections
close_p2p_connections() {
    echo "Closing Orpheus IPFS P2P connections..."
    local closed=0
    
    # Close all orpheus P2P connections
    for conn in $(ipfs p2p ls | grep "/x/orpheus-" | awk '{print $1}'); do
        echo "Closing P2P connection: $conn"
        if ipfs p2p close -p "$conn"; then
            closed=$((closed + 1))
        fi
    done
    
    if [[ $closed -gt 0 ]]; then
        echo "Closed $closed Orpheus P2P connections."
        return 0
    else
        echo "No Orpheus P2P connections found."
        return 1
    fi
}

# Function to test Orpheus TTS API connection
test_api() {
    echo "Testing Orpheus TTS API connection on port $ORPHEUS_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$ORPHEUS_PORT/docs")
    if [ "$RESPONSE" == "200" ]; then
        echo "Orpheus TTS API is responding correctly."
        return 0
    else
        echo "Orpheus TTS API not responding (HTTP $RESPONSE)."
        return 1
    fi
}

# Function to connect to best available Orpheus node (prioritizing subscriptions)
connect_to_swarm() {
    echo "Searching for available Orpheus nodes in swarm..."
    
    # Get prioritized list of nodes (subscribed first)
    local prioritized_nodes
    readarray -t prioritized_nodes < <(get_prioritized_orpheus_nodes)
    
    if [[ ${#prioritized_nodes[@]} -eq 0 ]]; then
        echo "No Orpheus nodes found in swarm"
        return 1
    fi
    
    echo "Found ${#prioritized_nodes[@]} Orpheus node(s), trying subscribed nodes first..."
    
    # Try each node in priority order
    for orpheus_script in "${prioritized_nodes[@]}"; do
        local node_id=$(basename $(dirname "$orpheus_script"))
        
        if check_subscription "$node_id"; then
            echo "🎯 Trying subscribed Orpheus node: $node_id"
        else
            echo "⚠️  Trying non-subscribed Orpheus node: $node_id"
        fi
        
        if establish_ipfs_p2p "$orpheus_script"; then
            # Test if the connection actually works
            sleep 2
            if test_api; then
                echo "Successfully connected to $node_id and API is responding"
                
                # Show final connection status
                if check_subscription "$node_id"; then
                    echo "🎉 Connected to subscribed node - full access available"
                else
                    echo "⚠️  Connected to non-subscribed node - limited access"
                fi
                return 0
            else
                echo "Connected to $node_id but API not responding, trying next..."
                # Close this connection and try next
                ipfs p2p close -p "/x/orpheus-$node_id" 2>/dev/null
            fi
        else
            echo "Failed to connect to $node_id, trying next..."
        fi
    done
    
    echo "No working Orpheus nodes available in swarm"
    return 1
}

# Function to show subscription status
show_subscription_status() {
    echo "=== ORPHEUS SUBSCRIPTION STATUS ==="
    local subscription_file="$HOME/.zen/tmp/${IPFSNODEID}/swarm_subscriptions.json"
    
    if [[ ! -f "$subscription_file" ]]; then
        echo "No subscription file found"
        return 0
    fi
    
    local orpheus_subs=0
    for orpheus_script in ~/.zen/tmp/swarm/*/x_orpheus.sh; do
        if [[ -f "$orpheus_script" ]]; then
            local node_id=$(basename $(dirname "$orpheus_script"))
            if check_subscription "$node_id"; then
                orpheus_subs=$((orpheus_subs + 1))
                local sub_info=$(get_subscription_info "$node_id")
                local sub_type=$(echo "$sub_info" | jq -r '.type // "unknown"' 2>/dev/null)
                local sub_date=$(echo "$sub_info" | jq -r '.start_date // "unknown"' 2>/dev/null)
                echo "✅ $node_id - $sub_type subscription (since $sub_date)"
            fi
        fi
    done
    
    if [[ $orpheus_subs -eq 0 ]]; then
        echo "❌ No active subscriptions to Orpheus nodes"
        echo "💡 Consider subscribing to nodes for better access and support"
    else
        echo "🎯 $orpheus_subs active Orpheus subscription(s) found"
    fi
}

# Main argument handling
case "$1" in
    "DISCOVER")
        discover_orpheus_nodes
        exit 0
        ;;
    "STATUS")
        show_subscription_status
        exit 0
        ;;
    "OFF")
        close_p2p_connections
        exit $?
        ;;
    "TEST")
        if test_api; then
            exit 0
        else
            echo "Orpheus TTS API not responding."
            exit 1
        fi
        ;;
    *)
        # Normal operation - check local first, then swarm with subscription priority
        if check_local_orpheus && test_api; then
            echo "Local Orpheus TTS API is available and responding on port $ORPHEUS_PORT"
            exit 0
        fi

        # No local service, try to connect to swarm nodes (subscribed first)
        echo "No local Orpheus service, connecting to swarm with subscription priority..."
        if connect_to_swarm; then
            echo "Orpheus TTS API ready at http://localhost:$ORPHEUS_PORT"
            exit 0
        else
            echo "Could not establish connection to any Orpheus TTS API."
            echo ""
            echo "💡 Suggestion: Check subscription status with: $0 STATUS"
            exit 1
        fi
        ;;
esac 