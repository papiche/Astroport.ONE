#!/bin/bash
# nostr_follow.sh <SOURCE_NSEC> <DESTINATION_HEX> [RELAY]
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

# Check for required arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") <SOURCE_NSEC> <DESTINATION_HEX> [RELAY]"
    echo "  Follows DESTINATION_HEX using SOURCE_NSEC key"
    exit 1
fi

SOURCE_NSEC="$1"
DESTINATION_HEX="$2"
RELAY="${3:-$myRELAY}"

# Convert NSEC to HEX
NPRIV_HEX=$(${MY_PATH}/nostr2hex.py "$SOURCE_NSEC")
if [[ -z "$NPRIV_HEX" ]]; then
    echo "Error: Failed to convert NSEC to HEX."
    exit 1
fi

# Get the source pubkey from the NSEC
SOURCE_HEX=$(${MY_PATH}/nostr_nsec2npub2hex.py "$SOURCE_NSEC")

# Query existing follow list using strfry scan
cd $HOME/.zen/strfry
STRFRY_OUTPUT=$(./strfry scan '{"kinds":[3],"authors":["'$SOURCE_HEX'"]}' | head -n 1)
cd -
EXISTING_EVENT="$STRFRY_OUTPUT"

# Initialize the new tags array
NEW_TAGS="[]"

# Check if an existing event was found
if [[ -n "$EXISTING_EVENT" ]]; then
    # Extract the existing tags using jq
    EXISTING_TAGS=$(echo "$EXISTING_EVENT" | jq -r '.tags')

    # Check if existing tags are null or empty string
    if [[ -z "$EXISTING_TAGS" ]] || [[ "$EXISTING_TAGS" == "null" ]]; then
        EXISTING_P_TAGS_ARRAY="[]"
    else
        # Extract existing 'p' tags
        EXISTING_P_TAGS_ARRAY=$(echo "$EXISTING_TAGS" | jq -r '. | to_entries[] | select(.value[0] == "p") | .value[1]')
    fi

    # Check if pubkey already exists
    if echo "$EXISTING_P_TAGS_ARRAY" | grep -q -w "$DESTINATION_HEX"; then
        echo "Already following $DESTINATION_HEX"
        exit 0
    else
        # Append the new 'p' tag
        if [[ -z "$EXISTING_TAGS" ]] || [[ "$EXISTING_TAGS" == "null" ]]; then
            NEW_TAGS="[['p', '$DESTINATION_HEX']]"
        else
            NEW_TAGS=$(echo "$EXISTING_TAGS" | jq -c '. + [["p", "'"$DESTINATION_HEX"'"]]')
        fi
    fi
else
    # Create new follow list
    NEW_TAGS="[['p', '$DESTINATION_HEX']]"
fi

# Send the updated kind 3 event
nostpy-cli send_event \
    -privkey "$NPRIV_HEX" \
    -kind 3 \
    -content "" \
    -tags "$NEW_TAGS" \
    --relay "$RELAY"

echo "Now following $DESTINATION_HEX"
exit 0
