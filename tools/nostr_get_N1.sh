#!/bin/bash
# Function to fetch N1 follows for a given pubkey using strfry
# nostr_get_N1.sh
# Usage: ./nostr_get_N1.sh <npub_hex>
# Example: ./nostr_get_N1.sh aef0d6b21282...

NPUB_HEX="$1"

if [ -z "$NPUB_HEX" ]; then
    echo "Usage: $0 <npub_hex>"
    exit 1
fi

cd $HOME/.zen/strfry
./strfry scan '{"kinds":[3],"authors":["'$NPUB_HEX'"]}' |
        jq -r '.tags[] | select(.[0]=="p") | .[1]' | sort -u
cd - 2>&1>/dev/null

exit 0
