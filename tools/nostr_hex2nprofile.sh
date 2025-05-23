#!/bin/bash
# nostr_hex2nprofile.sh <SOURCE_HEX> [RELAY1] [RELAY2] ...
MY_PATH="$(dirname "$0")"              # relative
MY_PATH="$( (cd "$MY_PATH" && pwd) )"  # absolutized and normalized

# Check for required jq and python3
if ! command -v jq &> /dev/null
then
    echo "Error: jq could not be found. Please install jq." >&2
    exit 1
fi
if ! command -v python3 &> /dev/null
then
    echo "Error: python3 could not be found. Please install python3." >&2
    exit 1
fi

if [[ $# -lt 1 ]]; then
    echo "Usage: $(basename "$0") <SOURCE_HEX> [RELAY_URL1] [RELAY_URL2] ..." >&2
    echo "  Converts a HEX public key to nprofile, using relays from strfry kind 10002 or provided relays." >&2
    exit 1
fi

SOURCE_HEX="$1"
shift

# Validate SOURCE_HEX (basic check for 64 hex chars)
if ! [[ "$SOURCE_HEX" =~ ^[0-9a-fA-F]{64}$ ]]; then
    echo "Error: Invalid SOURCE_HEX '$SOURCE_HEX'. Must be 64 hexadecimal characters." >&2
    exit 1
fi

FALLBACK_RELAYS=()
while [[ $# -gt 0 ]]; do
    if [[ "$1" =~ ^wss?:// ]]; then
        FALLBACK_RELAYS+=("$1")
    else
        echo "Warning: Ignoring invalid relay URL '$1'." >&2
    fi
    shift
done

PREFERRED_RELAYS_STRFRY=()

# Query existing preferred relays using strfry scan for kind 10002
# This assumes strfry is in $HOME/.zen/strfry and executable
STRFRY_PATH="$HOME/.zen/strfry/strfry"
if [[ ! -x "$STRFRY_PATH" ]]; then
    echo "Warning: strfry not found or not executable at $STRFRY_PATH. Cannot query for preferred relays." >&2
else
    # echo "Querying strfry for preferred relays (kind 10002) for $SOURCE_HEX..." >&2
    STRFRY_OUTPUT=$( (cd "$(dirname "$STRFRY_PATH")" && ./strfry scan '{"kinds":[10002],"authors":["'$SOURCE_HEX'"]}' 2>/dev/null | head -n 1) )

    if [[ -n "$STRFRY_OUTPUT" ]]; then
        # Attempt to parse NIP-65 (relays in event content)
        CONTENT_RELAYS=$(echo "$STRFRY_OUTPUT" | jq -r '.content | fromjson? | to_entries[] | select(.value.read == true and .value.write == true) | .key' 2>/dev/null)
        if [[ -z "$CONTENT_RELAYS" ]]; then # Fallback for null or non-NIP-65 content
            CONTENT_RELAYS=$(echo "$STRFRY_OUTPUT" | jq -r '.content | fromjson? | keys[]?' 2>/dev/null)
        fi
        
        if [[ -n "$CONTENT_RELAYS" ]]; then
            # echo "Found relays in event content (NIP-65 style):" >&2
            readarray -t TEMP_RELAYS < <(echo "$CONTENT_RELAYS")
            for r in "${TEMP_RELAYS[@]}"; do
                if [[ -n "$r" ]] && [[ "$r" != "null" ]]; then
                    # echo "  - $r" >&2
                    PREFERRED_RELAYS_STRFRY+=("$r")
                fi
            done
        fi

        # If no relays from content, or as a fallback, try 'r' tags
        if [[ ${#PREFERRED_RELAYS_STRFRY[@]} -eq 0 ]]; then
            TAG_RELAYS=$(echo "$STRFRY_OUTPUT" | jq -r '.tags[] | select(length > 1 and .[0] == "r") | .[1]' 2>/dev/null)
            if [[ -n "$TAG_RELAYS" ]]; then
                # echo "Found relays in event 'r' tags:" >&2
                readarray -t TEMP_RELAYS < <(echo "$TAG_RELAYS")
                for r in "${TEMP_RELAYS[@]}"; do
                    if [[ -n "$r" ]] && [[ "$r" != "null" ]]; then
                        # echo "  - $r" >&2
                        PREFERRED_RELAYS_STRFRY+=("$r")
                    fi
                done
            fi
        fi
    else
        # echo "No kind 10002 event found in strfry for $SOURCE_HEX." >&2
        true # Explicitly do nothing
    fi
fi

FINAL_RELAY_LIST=()
if [[ ${#PREFERRED_RELAYS_STRFRY[@]} -gt 0 ]]; then
    FINAL_RELAY_LIST=("${PREFERRED_RELAYS_STRFRY[@]}")
    # echo "Using preferred relays from strfry." >&2
elif [[ ${#FALLBACK_RELAYS[@]} -gt 0 ]]; then
    FINAL_RELAY_LIST=("${FALLBACK_RELAYS[@]}")
    # echo "Using provided fallback relays." >&2
else
    # echo "No relays found or provided. nprofile will not include relay hints." >&2
    # true
    echo "No preferred relays found via strfry and no relays provided as arguments. Using default relays." >&2
    FINAL_RELAY_LIST=("wss://relay.copylaradio.com" "ws://127.0.0.1:7777")
fi

# NIP-19 recommends at most 3 relay hints
# Create a comma-separated string of unique relays, limit to 3
RELAY_HINTS_STR=""
UNIQUE_RELAYS_FOR_HINTS=()
TEMP_ASSOC_ARRAY=()
for relay_url in "${FINAL_RELAY_LIST[@]}"; do
    # Check for duplicates using an associative array hack for older bash
    # or just process and let python script handle potential duplicates if any
    is_duplicate=0
    for ur in "${UNIQUE_RELAYS_FOR_HINTS[@]}"; do
        if [[ "$ur" == "$relay_url" ]]; then
            is_duplicate=1
            break
        fi
    done
    if [[ $is_duplicate -eq 0 ]] && [[ ${#UNIQUE_RELAYS_FOR_HINTS[@]} -lt 3 ]]; then
        UNIQUE_RELAYS_FOR_HINTS+=("$relay_url")
    fi
done

for i in "${!UNIQUE_RELAYS_FOR_HINTS[@]}"; do
    RELAY_HINTS_STR+="${UNIQUE_RELAYS_FOR_HINTS[$i]}"
    if [[ $i -lt $((${#UNIQUE_RELAYS_FOR_HINTS[@]} - 1)) ]]; then
        RELAY_HINTS_STR+=,
    fi
done

echo "DEBUG: Relays passed to Python: '$RELAY_HINTS_STR'" >&2 # Debug line

# Call the Python helper script for TLV encoding and Bech32
NPROFILE_OUTPUT=$("$MY_PATH/nostr_encode_nprofile_tlv.py" "$SOURCE_HEX" "$RELAY_HINTS_STR" 2>&1)

if [[ $? -ne 0 ]]; then
    echo "Error generating nprofile:" >&2
    echo "$NPROFILE_OUTPUT" >&2
    exit 1
fi

echo "$NPROFILE_OUTPUT"

exit 0 