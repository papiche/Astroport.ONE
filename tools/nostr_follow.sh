#!/bin/bash
# nostr_follow.sh <SOURCE_NSEC> <DESTINATION_HEX1> [DESTINATION_HEX2...] [RELAY]
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

# Check for required arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $(basename "$0") <SOURCE_NSEC> <DESTINATION_HEX1> [DESTINATION_HEX2...] [RELAY]"
    echo "  Follows one or more DESTINATION_HEX using SOURCE_NSEC key"
    exit 1
fi

SOURCE_NSEC="$1"
shift
RELAY=""

# Check if last argument is a relay URL (starts with wss://)
for last; do true; done
if [[ "$last" =~ ^wss:// ]]; then
    RELAY="$last"
    # Remove relay from arguments
    set -- "${@:1:$(($#-1))}"
fi

RELAY="${RELAY:-$myRELAY}"

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
STRFRY_OUTPUT=$(./strfry scan '{"kinds":[3],"authors":["'$SOURCE_HEX'"]}' 2>/dev/null | head -n 1)
cd - 2>&1>/dev/null
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

    # Start with existing tags or empty array
    if [[ -z "$EXISTING_TAGS" ]] || [[ "$EXISTING_TAGS" == "null" ]]; then
        NEW_TAGS="[]"
    else
        NEW_TAGS="$EXISTING_TAGS"
    fi

    # Process each destination hex
    for DESTINATION_HEX in "$@"; do
        # Check if pubkey already exists
        if echo "$EXISTING_P_TAGS_ARRAY" | grep -q -w "$DESTINATION_HEX"; then
            echo "Already following $DESTINATION_HEX"
        else
            # Append the new 'p' tag
            NEW_TAGS=$(echo "$NEW_TAGS" | jq -c '. + [["p", "'"$DESTINATION_HEX"'"]]')
            echo "Adding $DESTINATION_HEX to follow list"
        fi
    done
else
    # Create new follow list with all provided hexes
    NEW_TAGS="[]"
    for DESTINATION_HEX in "$@"; do
        NEW_TAGS=$(echo "$NEW_TAGS" | jq -c '. + [["p", "'"$DESTINATION_HEX"'"]]')
    done
fi

# Send the updated kind 3 event
nostpy-cli send_event \
    -privkey "$NPRIV_HEX" \
    -kind 3 \
    -content "" \
    -tags "$NEW_TAGS" \
    --relay "$RELAY"

echo "Follow list updated with ${#@} new entries"
exit 0
