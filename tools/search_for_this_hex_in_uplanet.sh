#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Parse parameters
JSON_OUTPUT=false
HEX=""
FILTER_GEO=false
FILTER_MULTIPASS=false
FILTER_UMAP=false
FILTER_SECTOR=false
FILTER_REGION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --geo)
            FILTER_GEO=true
            shift
            ;;
        --multipass)
            FILTER_MULTIPASS=true
            shift
            ;;
        --umap)
            FILTER_UMAP=true
            shift
            ;;
        --sector)
            FILTER_SECTOR=true
            shift
            ;;
        --region)
            FILTER_REGION=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [HEX] [options]"
            echo ""
            echo "Search for HEX keys in UPLANET directories"
            echo ""
            echo "Arguments:"
            echo "  HEX         Specific HEX to search for"
            echo ""
            echo "Options:"
            echo "  --json      Output in JSON format"
            echo "  --geo       Filter: All geographic keys (umap, sector, region)"
            echo "  --multipass Filter: Only MULTIPASS keys"
            echo "  --umap      Filter: Only UMAP keys"
            echo "  --sector    Filter: Only SECTOR keys"
            echo "  --region    Filter: Only REGION keys"
            echo "  --help      Show this help"
            echo ""
            echo "Examples:"
            echo "  $0 --json --multipass"
            echo "  $0 --json --geo"
            echo "  $0 abc123... --json"
            exit 0
            ;;
        *)
            HEX="$1"
            shift
            ;;
    esac
done
# If no HEX is provided, list all found HEXes
if [ -z "$HEX" ]; then
    if [ "$JSON_OUTPUT" = true ]; then
        echo "["
        first=true
        
        # Function to add HEX to JSON output
        add_hex_to_json() {
            local hex="$1"
            local type="$2"
            local source="$3"
            
            if [ -n "$hex" ]; then
                if [ "$first" = true ]; then
                    first=false
                else
                    echo ","
                fi
                echo "  {"
                echo "    \"hex\": \"$hex\","
                echo "    \"type\": \"$type\","
                echo "    \"source\": \"$source\""
                echo "  }"
            fi
        }
        
        # SWARM MULTIPASS HEX
        if [[ "$FILTER_MULTIPASS" = true || ("$FILTER_GEO" = false && "$FILTER_UMAP" = false && "$FILTER_SECTOR" = false && "$FILTER_REGION" = false) ]]; then
            while IFS= read -r hex; do
                add_hex_to_json "$hex" "multipass" "swarm"
            done < <(cat ${HOME}/.zen/tmp/swarm/*/TW/*/HEX 2>/dev/null | sort -u)
        fi
        
        # LOCAL MULTIPASS HEX
        if [[ "$FILTER_MULTIPASS" = true || ("$FILTER_GEO" = false && "$FILTER_UMAP" = false && "$FILTER_SECTOR" = false && "$FILTER_REGION" = false) ]]; then
            while IFS= read -r hex; do
                add_hex_to_json "$hex" "multipass" "local"
            done < <(cat ${HOME}/.zen/game/nostr/*@*.*/HEX 2>/dev/null | sort -u)
        fi
        
        # SWARM UMAP HEX
        if [[ "$FILTER_UMAP" = true || "$FILTER_GEO" = true || ("$FILTER_MULTIPASS" = false && "$FILTER_SECTOR" = false && "$FILTER_REGION" = false) ]]; then
            while IFS= read -r hex; do
                add_hex_to_json "$hex" "umap" "swarm"
            done < <(cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX 2>/dev/null | sort -u)
        fi
        
        # SWARM UMAP HEX_SECTOR
        if [[ "$FILTER_SECTOR" = true || "$FILTER_GEO" = true || ("$FILTER_MULTIPASS" = false && "$FILTER_UMAP" = false && "$FILTER_REGION" = false) ]]; then
            while IFS= read -r hex; do
                add_hex_to_json "$hex" "sector" "swarm"
            done < <(cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX_SECTOR 2>/dev/null | sort -u)
        fi
        
        # SWARM UMAP HEX_REGION
        if [[ "$FILTER_REGION" = true || "$FILTER_GEO" = true || ("$FILTER_MULTIPASS" = false && "$FILTER_UMAP" = false && "$FILTER_SECTOR" = false) ]]; then
            while IFS= read -r hex; do
                add_hex_to_json "$hex" "region" "swarm"
            done < <(cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX_REGION 2>/dev/null | sort -u)
        fi
        
        echo "]"
    else
        echo "To find a G1PUBNOSTR, you need to provide a HEX"
        echo "Listing all HEXes found in UPLANET directories:"

        # SWARM UMAP HEX
        echo "SWARM UMAP HEX"
        cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX 2>/dev/null | sort -u

        # SWARM UMAP HEX_SECTOR
        echo "SWARM UMAP HEX_SECTOR" 
        cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX_SECTOR 2>/dev/null | sort -u

        # SWARM UMAP HEX_REGION
        echo "SWARM UMAP HEX_REGION"
        cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX_REGION 2>/dev/null | sort -u

        # SWARM PLAYERs HEX
        echo "SWARM MULTIPASS HEX"
        cat ${HOME}/.zen/tmp/swarm/*/TW/*/HEX 2>/dev/null | sort -u
        
        # LOCAL TOTAL HEX
        echo "LOCAL MULTIPASS HEX"
        cat ${HOME}/.zen/game/nostr/*@*.*/HEX 2>/dev/null | sort -u
    fi

    exit 0
fi

# Search for the specific HEX in SWARM PLAYERs (TW directories)
# echo "Searching for HEX: $HEX"
FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/swarm/*/TW/*/HEX 2>/dev/null | head -n 1)
[[ -z "$FOUND_FILE" ]] && FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/${IPFSNODEID}/TW/*/HEX 2>/dev/null | head -n 1)

if [ -n "$FOUND_FILE" ]; then
    # echo "Found HEX in TW directory: $FOUND_FILE"
    G1PUBNOSTR_FILE=$(dirname "$FOUND_FILE")/G1PUBNOSTR
    if [ -f "$G1PUBNOSTR_FILE" ]; then
        # echo "G1PUBNOSTR value:"
        cat "$G1PUBNOSTR_FILE"
        exit 0
    fi
fi

# If not found in TW, search in UPLANET sectors (HEX, HEX_REGION, HEX_SECTOR)
FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX 2>/dev/null | head -n 1)
[[ -z "$FOUND_FILE" ]] && FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/*/*/*/HEX 2>/dev/null | head -n 1)

if [ -n "$FOUND_FILE" ]; then
    # echo "Found HEX in UPLANET directory: $FOUND_FILE"
    G1PUB_FILE=$(dirname "$FOUND_FILE")/G1PUB
    if [ -f "$G1PUB_FILE" ]; then
        # echo "G1PUB value:"
        cat "$G1PUB_FILE"
        exit 0
    fi
fi

# If not found any HEX, search in HEX_SECTOR
FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX_SECTOR 2>/dev/null | head -n 1)
[[ -z "$FOUND_FILE" ]] && FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/*/*/*/HEX_SECTOR 2>/dev/null | head -n 1)

if [ -n "$FOUND_FILE" ]; then
    # echo "Found HEX in UPLANET HEX_SECTOR: $FOUND_FILE"
    SECTORG1PUB_FILE=$(dirname "$FOUND_FILE")/SECTORG1PUB
    if [ -f "$SECTORG1PUB_FILE" ]; then
        # echo "SECTORG1PUB value:"
        cat "$SECTORG1PUB_FILE"
        exit 0
    fi
fi

# If not found any HEX, search in HEX_REGION
FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX_REGION 2>/dev/null | head -n 1)
[[ -z "$FOUND_FILE" ]] && FOUND_FILE=$(grep -l "$HEX" ${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/*/*/*/HEX_REGION 2>/dev/null | head -n 1)

if [ -n "$FOUND_FILE" ]; then
    # echo "Found HEX in UPLANET HEX_REGION: $FOUND_FILE"
    REGIONG1PUB_FILE=$(dirname "$FOUND_FILE")/REGIONG1PUB
    if [ -f "$REGIONG1PUB_FILE" ]; then
        # echo "REGIONG1PUB value:"
        cat "$REGIONG1PUB_FILE"
        exit 0
    fi
fi

exit 0
