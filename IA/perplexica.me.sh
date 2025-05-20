#!/bin/bash
## Perplexica Swarm Connector
## Checks for local Perplexica API on port 3001
## Establishes SSH tunnel if not available locally
## Will be extended to load balance across Swarm GPU Stations
########################################################
## TODO: Integrate with Swarm GPU Station discovery
########################################################

# Configuration
PERPLEXICA_PORT=3001
REMOTE_USER="frd"
REMOTE_HOST="scorpio.copylaradio.com"
REMOTE_PORT=2122
SSH_OPTIONS="-fN -L $PERPLEXICA_PORT:127.0.0.1:$PERPLEXICA_PORT"

# Function to check if port is open
check_port() {
    if lsof -i :$PERPLEXICA_PORT >/dev/null; then
        #~ echo "Perplexica API port $PERPLEXICA_PORT is already open."
        return 0
    else
        #~ echo "Perplexica API port $PERPLEXICA_PORT is not available."
        return 1
    fi
}

# Function to establish SSH tunnel
establish_tunnel() {
    #~ echo "Attempting to establish SSH tunnel for Perplexica API..."
    if ssh $SSH_OPTIONS $REMOTE_USER@$REMOTE_HOST -p $REMOTE_PORT; then
        #~ echo "SSH tunnel established successfully for Perplexica API."

        # Verify the tunnel actually works
        sleep 2
        if check_port; then
            return 0
        else
            echo "Tunnel established but port $PERPLEXICA_PORT not accessible."
            close_tunnel
            return 1
        fi
    else
        echo "Failed to establish SSH tunnel for Perplexica API."
        return 1
    fi
}

# Function to close SSH tunnel
close_tunnel() {
    echo "Closing Perplexica API SSH tunnel..."
    PID=$(lsof -t -i :$PERPLEXICA_PORT)
    if [ -z "$PID" ]; then
        echo "No SSH tunnel found for port $PERPLEXICA_PORT."
        return 1
    else
        kill $PID
        if [ $? -eq 0 ]; then
            #~ echo "SSH tunnel for Perplexica API closed successfully."
            return 0
        else
            echo "Failed to close SSH tunnel for Perplexica API."
            return 1
        fi
    fi
}

# Function to test Perplexica API connection
test_api() {
    #~ echo "Testing Perplexica API connection..."
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$PERPLEXICA_PORT/api/models")
    if [ "$RESPONSE" == "200" ]; then
        #~ echo "Perplexica API is responding correctly."
        return 0
    else
        echo "Perplexica API not responding (HTTP $RESPONSE)."
        return 1
    fi
}

# Main argument handling
case "$1" in
    "OFF")
        close_tunnel
        exit $?
        ;;
    "TEST")
        if check_port; then
            test_api
            exit $?
        else
            echo "Perplexica API port not open."
            exit 1
        fi
        ;;
    *)
        # Normal operation - check and establish connection if needed
        if check_port; then
            if test_api; then
                exit 0
            else
                echo "Port open but API not responding. Establishing new tunnel..."
                close_tunnel
            fi
        fi

        # Establish new tunnel if needed
        if establish_tunnel; then
            if test_api; then
                #~ echo "Perplexica API ready at http://localhost:$PERPLEXICA_PORT"
                exit 0
            else
                echo "Failed to connect to Perplexica API after tunnel establishment."
                exit 1
            fi
        else
            echo "Could not establish connection to Perplexica API."
            exit 1
        fi
        ;;
esac
