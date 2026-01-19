#!/bin/bash
# nostr_get_profile.sh <PUBKEY_HEX> [--json]
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

# Parse arguments
JSON_OUTPUT=false
PUBKEY_HEX=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        *)
            if [[ -z "$PUBKEY_HEX" ]]; then
                PUBKEY_HEX="$1"
            else
                echo "Error: Unexpected argument: $1"
                echo "Usage: $(basename "$0") <PUBKEY_HEX> [--json]"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check for required arguments
if [[ -z "$PUBKEY_HEX" ]]; then
    echo "Usage: $(basename "$0") <PUBKEY_HEX> [--json]"
    echo "  Gets profile information for the given public key"
    echo "  Use --json to output in JSON format"
    exit 1
fi

# Query profile using strfry scan
cd $HOME/.zen/strfry
STRFRY_OUTPUT=$(./strfry scan '{"kinds":[0],"authors":["'$PUBKEY_HEX'"]}' 2>/dev/null | head -n 1)
cd - 2>&1>/dev/null

if [[ -z "$STRFRY_OUTPUT" ]]; then
    echo "No profile found for pubkey: $PUBKEY_HEX"
    exit 1
fi

if [[ "$JSON_OUTPUT" == true ]]; then
    # Output in JSON format with UMAP CIDs extracted
    echo "$STRFRY_OUTPUT" | jq -c '{
        profile: (.content | fromjson),
        identities: [.tags[] | select(.[0] == "i") | .[1]],
        umap_images: {
            umap_cid: ([.tags[] | select(.[0] == "i" and (.[1] | startswith("umap_cid:"))) | .[1] | split(":")[1]] | first // null),
            usat_cid: ([.tags[] | select(.[0] == "i" and (.[1] | startswith("usat_cid:"))) | .[1] | split(":")[1]] | first // null),
            umap_full_cid: ([.tags[] | select(.[0] == "i" and (.[1] | startswith("umap_full_cid:"))) | .[1] | split(":")[1]] | first // null),
            usat_full_cid: ([.tags[] | select(.[0] == "i" and (.[1] | startswith("usat_full_cid:"))) | .[1] | split(":")[1]] | first // null),
            umaproot: ([.tags[] | select(.[0] == "i" and (.[1] | startswith("umaproot:"))) | .[1] | split(":")[1]] | first // null),
            umap_updated: ([.tags[] | select(.[0] == "i" and (.[1] | startswith("umap_updated:"))) | .[1] | split(":")[1]] | first // null)
        }
    }'
else
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
    
    # Display UMAP image CIDs if present
    UMAP_CID=$(echo "$STRFRY_OUTPUT" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("umap_cid:"))) | .[1] | split(":")[1]] | first // empty')
    USAT_CID=$(echo "$STRFRY_OUTPUT" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("usat_cid:"))) | .[1] | split(":")[1]] | first // empty')
    UMAPROOT=$(echo "$STRFRY_OUTPUT" | jq -r '[.tags[] | select(.[0] == "i" and (.[1] | startswith("umaproot:"))) | .[1] | split(":")[1]] | first // empty')
    
    if [[ -n "$UMAP_CID" || -n "$USAT_CID" || -n "$UMAPROOT" ]]; then
        echo -e "\nUMAP Images (IPFS CIDs):"
        echo "------------------------"
        [[ -n "$UMAP_CID" ]] && echo "zUmap.jpg (profile): $UMAP_CID"
        [[ -n "$USAT_CID" ]] && echo "Usat.jpg (banner):   $USAT_CID"
        [[ -n "$UMAPROOT" ]] && echo "UMAP Root:           $UMAPROOT"
    fi
fi

exit 0