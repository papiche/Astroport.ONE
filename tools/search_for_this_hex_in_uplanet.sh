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
    # SWARM UMAP HEX
    echo "SWARM UMAP HEX"
    cat ${HOME}/.zen/tmp/swarm/*/UPLANET/__/*/*/*/HEX 2>/dev/null

    # SWARM PLAYERs HEX
    echo "SWARM PLAYERs HEX"
    cat ${HOME}/.zen/tmp/swarm/*/TW/*/HEX 2>/dev/null
    
    # LOCAL TOTAL HEX
    echo "LOCAL PLAYERs HEX"
    cat ${HOME}/.zen/game/nostr/*@*.*/HEX 2>/dev/null

    exit 0
fi

# Search for the specific HEX in SWARM PLAYERs 
echo "Searching for HEX: $HEX"
FOUND_DIR=$(find ${HOME}/.zen/tmp/swarm/*/TW/* -name "HEX" -exec grep -l "$HEX" {} \; 2>/dev/null)

if [ -n "$FOUND_DIR" ]; then
    echo "Found HEX in directory: $FOUND_DIR"
    G1PUBNOSTR_FILE=$(dirname "$FOUND_DIR")/G1PUBNOSTR
    if [ -f "$G1PUBNOSTR_FILE" ]; then
        echo "G1PUBNOSTR value:"
        cat "$G1PUBNOSTR_FILE"
    else
        echo "G1PUBNOSTR file not found in the directory"
    fi
else
    echo "HEX not found in UPLANET directories"
fi

exit 0
