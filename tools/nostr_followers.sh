#!/bin/bash
# Function to find who follows a given pubkey by searching kind 3 events that reference it
# nostr_followers.sh
# Usage: ./nostr_followers.sh <npub_hex>
# Example: ./nostr_followers.sh aef0d6b21282...

NPUB_HEX="$1"

if [ -z "$NPUB_HEX" ]; then
    echo "Usage: $0 <npub_hex>"
    exit 1
fi

cd $HOME/.zen/strfry
# Search kind 3 events that contain the NPUB in their tags
./strfry scan '{"kinds":[3]}' |
    jq -r --arg npub "$NPUB_HEX" 'select(.tags[]?[0]=="p" and .tags[]?[1]==$npub) | .pubkey' |
    sort -u
cd - 2>&1>/dev/null

exit 0
