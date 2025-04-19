#!/bin/bash

# nostr_getN.sh
# Usage: ./nostr_getN.sh <npub_hex> [depth]
# Example: ./nostr_getN.sh aef0d6b21282... 2

NPUB_HEX="$1"
DEPTH="${2:-1}"  # default depth is 1 (N1)

STRFRY_PATH="$HOME/.zen/strfry/strfry" # Define path to strfry executable
STRFRY_CONF="$HOME/.zen/strfry/strfry.conf" # Define path to strfry config

if [ -z "$NPUB_HEX" ]; then
    echo "Usage: $0 <npub_hex> [depth]"
    exit 1
fi

# Function to fetch N1 follows for a given pubkey using strfry
get_n1_follows() {
    local pubkey="$1"
    # Use strfry scan to query local DB. Relay is not used by strfry scan.
    if [ ! -x "$STRFRY_PATH" ]; then
        echo "Error: strfry executable not found at $STRFRY_PATH."
        return 1
    fi
    "$STRFRY_PATH" --config=$STRFRY_CONF scan '{"kinds":[3],"authors":["'$pubkey'"]}' |
        jq -r '.tags[] | select(.[0]=="p") | .[1]' | sort -u
}

# Zone N1
echo "Getting N1 (direct follows) of $NPUB_HEX..."
N1=$(get_n1_follows "$NPUB_HEX")
echo "$N1" > .n1.tmp
cat .n1.tmp

if [ "$DEPTH" == "2" ]; then
    echo "Getting N2 (friends of friends)..."
    > .n2.tmp
    while read -r friend; do
        echo " → $friend"
        get_n1_follows "$friend" >> .n2.tmp # Relay is still passed for potential future use
        sleep 1  # avoid rate limits
    done < .n1.tmp

    sort -u .n2.tmp | grep -v -F -f .n1.tmp | grep -v "$NPUB_HEX" > .n2_filtered.tmp
    echo ""
    echo "Zone N2:"
    cat .n2_filtered.tmp
    echo ""
    echo "All unique follows (N1 + N2):"
    cat .n1.tmp .n2_filtered.tmp | sort -u
    rm .n1.tmp .n2.tmp .n2_filtered.tmp
else
    rm .n1.tmp
fi
