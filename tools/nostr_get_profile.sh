#!/bin/bash
# nostr_get_profile.sh <PUBKEY_HEX>
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

# Check for required arguments
if [[ $# -ne 1 ]]; then
    echo "Usage: $(basename "$0") <PUBKEY_HEX>"
    echo "  Gets profile information for the given public key"
    exit 1
fi

PUBKEY_HEX="$1"

# Query profile using strfry scan
cd $HOME/.zen/strfry
STRFRY_OUTPUT=$(./strfry scan '{"kinds":[0],"authors":["'$PUBKEY_HEX'"]}' 2>/dev/null | head -n 1)
cd - 2>&1>/dev/null

if [[ -z "$STRFRY_OUTPUT" ]]; then
    echo "No profile found for pubkey: $PUBKEY_HEX"
    exit 1
fi

# Extract and display profile information
echo "Profile Information:"
echo "-------------------"
echo "$STRFRY_OUTPUT" | jq -r '.content' | jq -r '
    "Name: \(.name // "Not set")
About: \(.about // "Not set")
Picture: \(.picture // "Not set")
Banner: \(.banner // "Not set")
NIP-05: \(.nip05 // "Not set")
Website: \(.website // "Not set")
Bot: \(.bot // false)"
'

# Display external identities if present
echo -e "\nExternal Identities:"
echo "-------------------"
echo "$STRFRY_OUTPUT" | jq -r '.tags[] | select(.[0] == "i") | "\(.[1])"' | while read -r identity; do
    echo "$identity"
done

exit 0 