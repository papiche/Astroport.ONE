#!/bin/bash

# nostr_get_N1.sh
# Usage: ./nostr_get_N1.sh <npub_hex>
# Example: ./nostr_get_N1.sh aef0d6b21282...

NPUB_HEX="$1"

STRFRY_PATH="$HOME/.zen/strfry" # Define path to strfry executable

if [ -z "$NPUB_HEX" ]; then
    echo "Usage: $0 <npub_hex>"
    exit 1
fi

# Function to fetch N1 follows for a given pubkey using strfry
get_n1_follows() {
    local pubkey="$1"
    # Use strfry scan to query local DB. Relay is not used by strfry scan.
    if [ ! -x "$STRFRY_PATH/strfry" ]; then
        echo "Error: strfry executable not found at $STRFRY_PATH."
        return 1
    fi
    cd $STRFRY_PATH
    ./strfry scan '{"kinds":[3],"authors":["'$pubkey'"]}' |
        jq -r '.tags[] | select(.[0]=="p") | .[1]' | sort -u
    cd - 2>&1>/dev/null
}

# Zone N1 - Only level 1 and list output

get_n1_follows "$NPUB_HEX"
