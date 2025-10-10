#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

HEX="$1"
# If no HEX is provided, list all found HEXes
if [ -z "$HEX" ]; then
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
    echo "SWARM PLAYERs HEX"
    cat ${HOME}/.zen/tmp/swarm/*/TW/*/HEX 2>/dev/null | sort -u
    
    # LOCAL TOTAL HEX
    echo "LOCAL PLAYERs HEX"
    cat ${HOME}/.zen/game/nostr/*@*.*/HEX 2>/dev/null | sort -u

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
