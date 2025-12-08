#!/bin/bash
# Dependencies : jq curl dig
#### comfyui.me.sh : ComfyUI Swarm Connector
## Check for local comfyui 8188 port open
## Else try SSH tunnel to scorpio (IPv6/IPv4)
## Finally fallback to IPFS P2P swarm discovery
########################################################
## ZEN[0] Swarm Integration - GPU Load Balancing
########################################################
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

# Function to check if port is open
check_port() {
    if netstat -tulnp 2>/dev/null | grep ":$COMFYUI_PORT " >/dev/null; then
        echo "Port $COMFYUI_PORT is already open."
        return 0
    else
        echo "Port $COMFYUI_PORT is not open."
        return 1
    fi
}

# Function to test ComfyUI API connection
test_api() {
    echo "Testing ComfyUI API connection on port $COMFYUI_PORT..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$COMFYUI_PORT/system_stats" --connect-timeout 5)
    if [ "$RESPONSE" == "200" ]; then
        echo "ComfyUI API is responding correctly."
        return 0
    else
        echo "ComfyUI API not responding (HTTP $RESPONSE)."
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
    PID=$(lsof -t -i :$COMFYUI_PORT 2>/dev/null)
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
## Main Script - Connection Management
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
    "")
        # No argument = just ensure connection is available
        if check_port && test_api; then
            echo "ComfyUI API ready at http://localhost:$COMFYUI_PORT"
            exit 0
        fi
        
        # Try SSH tunnel to scorpio first (demo mode)
        if establish_ssh_tunnel; then
            echo "ComfyUI API ready via SSH tunnel at http://localhost:$COMFYUI_PORT"
            exit 0
        fi
        
        # Fallback to IPFS P2P swarm (production mode ZEN[0])
        echo "Scorpio unavailable, trying IPFS P2P swarm..."
        if connect_via_swarm; then
            echo "ComfyUI API ready via IPFS P2P at http://localhost:$COMFYUI_PORT"
            exit 0
        fi
        
        echo "Could not establish connection to any ComfyUI service."
        exit 1
        ;;
esac

########################################################
## Image Generation Mode (when prompt is provided)
########################################################

PROMPT="$1"

# Workflow file path
WORKFLOW_FILE="${MY_PATH}/workflow/FluxImage.json"

# ComfyUI API URL
COMFYUI_URL="http://127.0.0.1:$COMFYUI_PORT"

# Ensure connection is available before proceeding
if ! check_port; then
    echo "ComfyUI not available, attempting connection..."
    if ! establish_ssh_tunnel && ! connect_via_swarm; then
        echo "Failed to connect to ComfyUI"
        exit 1
    fi
fi

# Function to check if ComfyUI port is accessible
check_comfyui_port() {
    echo "Checking ComfyUI port: 127.0.0.1:${COMFYUI_PORT}"
    if nc -z "127.0.0.1" "$COMFYUI_PORT" > /dev/null 2>&1; then
        echo "ComfyUI port is accessible."
        return 0
    else
        echo "Error: ComfyUI port is not accessible."
        return 1
    fi
}

# Function to update prompt in workflow JSON
update_prompt() {
    echo "Loading workflow JSON: ${WORKFLOW_FILE}"
    local prompt_json=$(jq -n --arg prompt "$PROMPT" '{text: $prompt}')

    # Update first CLIPTextEncode
    jq --argjson prompt_obj "$prompt_json" \
        '.nodes[] | select(.type == "CLIPTextEncode") | .widgets_values[0] = $prompt_obj.text' \
        "$WORKFLOW_FILE" > temp_workflow.json

    echo "Prompt updated in temp_workflow.json"
}

# Function to send workflow to ComfyUI API
send_workflow() {
    echo "Sending workflow to ComfyUI API..."
    local data
    data=$(jq -c . "temp_workflow.json")
    local response
    local http_code
    local curl_command
    curl_command="curl -s -w \"%{http_code}\" -X POST -H \"Content-Type: application/json\" -d '$data' '$COMFYUI_URL/prompt'"
    echo "Executing: $curl_command"
    response=$(eval "$curl_command" 2>&1)
    http_code=$(echo "$response" | grep -oP '^\d+' | tail -n 1)
    response=$(echo "$response" | grep -vP '^\d+$')

    echo "HTTP code: $http_code"
    echo "API response: $response"

    if [ "$http_code" -ne 200 ]; then
        echo "Error sending workflow, HTTP code: $http_code"
        echo "$response"
        exit 1
    fi

    echo "Workflow sent successfully."
    local prompt_id
    prompt_id=$(echo "$response" | jq -r '.prompt_id')
    echo "Prompt ID: $prompt_id"
    if [ -z "$prompt_id" ]; then
        echo "Error: prompt_id not found in response."
        echo "$response"
        exit 1
    fi
    monitor_progress "$prompt_id"
}

# Function to monitor generation progress
monitor_progress() {
    local prompt_id="$1"
    local progress_url="$COMFYUI_URL/queue/$prompt_id"

    echo "Monitoring progress with ID: $prompt_id"

    while true; do
        local progress_response
        progress_response=$(curl -s "$progress_url")

        if echo "$progress_response" | jq -e '. != null'; then
            local current
            current=$(echo "$progress_response" | jq -r '.progress.value')
            local total
            total=$(echo "$progress_response" | jq -r '.progress.max')

            local status
            status=$(echo "$progress_response" | jq -r '.status')

            if [ "$status" = "completed" ]; then
                echo "Generation completed."
                get_image_result "$prompt_id"
                break
            else
                echo "Progress: $current/$total"
                sleep 1
            fi
        else
            echo "Error retrieving progress."
            echo "$progress_response"
            break
        fi
    done
}

get_image_result() {
    local prompt_id="$1"
    local history_url="$COMFYUI_URL/history/$prompt_id"

    local history_response
    history_response=$(curl -s "$history_url")

    if echo "$history_response" | jq -e '. != null'; then
        local node_id
        node_id=$(echo "$history_response" | jq -r 'keys[0]')

        local image_filename
        image_filename=$(echo "$history_response" | jq -r ".[\"$node_id\"].outputs.\"7\"[0].filename")

        local image_url
        image_url="$COMFYUI_URL/view/$image_filename"

        echo "Generated image: $image_url"
        local output_image="output.png"
        curl -s -o "$output_image" "$image_url"
        echo "Image saved in $output_image"

    else
        echo "Error retrieving history."
        echo "$history_response"
    fi
}

# Main image generation
check_comfyui_port
if [ $? -ne 0 ]; then
    exit 1
fi

update_prompt
send_workflow
rm -f temp_workflow.json
