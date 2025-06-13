#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# EXPLORE SWARM TW CACHE FOR THIS EMAIL
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

EMAIL="$1"
MOATS="$2"
[[ -z $MOATS ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Si aucun email n'est fourni, lister tous les emails trouvés
if [ -z "$EMAIL" ]; then
    echo "Listing all emails found in sources:"
    echo "LOCAL _____________________________"
    find ${HOME}/.zen/game/players -maxdepth 1 -type d -name "*@*" -exec test -f {}/ipfs/moa/index.html \; -printf "%f " 2>/dev/null
    echo
    echo "CACHE _____________________________"
    find ${HOME}/.zen/tmp/${IPFSNODEID}/TW -maxdepth 1 -type d -name "*@*" -exec test -f {}/index.html \; -printf "%f " 2>/dev/null
    echo
    echo "SWARM _____________________________"
    find ${HOME}/.zen/tmp/swarm/*/TW -maxdepth 1 -type d -name "*@*" -exec test -f {}/index.html \; -printf "%f " 2>/dev/null
    echo
    exit 0
fi

# Cache configuration
CACHE_DIR="${HOME}/.zen/tmp/players_cache"
CACHE_FILE="${CACHE_DIR}/${EMAIL}.ustats"

# Check cache first
if [[ -f "$CACHE_FILE" ]]; then
    cat "$CACHE_FILE"
    exit 0
fi

# Validate email format
[[ ! "${EMAIL}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && {
    echo "export ASTROTW='' # BAD ${EMAIL} FORMAT"
    exit 0
}

# Find index file
INDEX=$(ls ${HOME}/.zen/game/players/${EMAIL}/ipfs/moa/index.html 2>/dev/null) && source="LOCAL"
[[ ! $INDEX ]] && INDEX=$(ls ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/index.html 2>/dev/null) && source="CACHE"
[[ ! $INDEX ]] && INDEX=$(ls ${HOME}/.zen/tmp/swarm/*/TW/${EMAIL}/index.html 2>/dev/null) && source="SWARM"
[[ ! $INDEX ]] && exit 1

# Process remote index if needed
if [[ ${source} != "LOCAL" ]]; then
    ETWLINK=$(grep -o "url='/[^']*'" "${INDEX}" | sed "s|url='||;s|'||")
    ICID=$(echo "${ETWLINK}" | rev | cut -d '/' -f 1 | rev)
    
    if [[ ! -s ${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html ]]; then
        mkdir -p ${HOME}/.zen/tmp/flashmem/tw/${ICID}
        ipfs --timeout=30s cat --progress=false ${ETWLINK} > ${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html
    fi
    INDEX="${HOME}/.zen/tmp/flashmem/tw/${ICID}/index.html"
fi

# Create temp directory for processing
TMP_DIR="${HOME}/.zen/tmp/${MOATS}"
mkdir -p "$TMP_DIR"

# Extract data from TW
tiddlywiki --load ${INDEX} --output ${TMP_DIR} --render '.' 'Astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
tiddlywiki --load ${INDEX} --output ${TMP_DIR} --render '.' 'lightbeams.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '$:/plugins/astroport/lightbeams/saver/ipns/lightbeam-key'
tiddlywiki --load ${INDEX} --output ${TMP_DIR} --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'
tiddlywiki --load ${INDEX} --output ${TMP_DIR} --render '.' 'email.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${EMAIL}"

# Extract values
ASTROPORT=$(jq -r '.[].astroport' ${TMP_DIR}/Astroport.json)
ASTROG1=$(jq -r '.[].g1pub' ${TMP_DIR}/Astroport.json)
TWCHAIN=$(jq -r '.[].chain' ${TMP_DIR}/Astroport.json)
FEEDNS="/ipns/$(jq -r '.[].text' ${TMP_DIR}/lightbeams.json)"
LAT=$(jq -r '.[].lat' ${TMP_DIR}/GPS.json)
LON=$(jq -r '.[].lon' ${TMP_DIR}/GPS.json)
HEX=$(jq -r '.[].hex' ${TMP_DIR}/email.json)
ASTRONAUTENS=$(jq -r '.[].astronautens' ${TMP_DIR}/Astroport.json)

# Handle ASTRONAUTENS
[[ ${source} == "LOCAL" && ( ${ASTRONAUTENS} == "null" || ${ASTRONAUTENS} == "" ) ]] && {
    ASTRONAUTENS="/ipns/$(ipfs key list -l | grep -w ${ASTROG1} | head -n1 | cut -d ' ' -f1)"
}
[[ ${ASTRONAUTENS} == "/ipns/" ]] && ASTRONAUTENS="/ipfs/${TWCHAIN}"

# Calculate ZEN
COINS=$(cat ~/.zen/tmp/coucou/$ASTROG1.COINS)
ZEN=$(echo "($COINS - 1) * 10" | bc | cut -d '.' -f 1)

# Get NHEX from NOSTR Card
NHEX=$(cat ~/.zen/game/nostr/${EMAIL}/HEX 2>/dev/null)
[[ $HEX == "" ]] && HEX=$NHEX

# Cleanup
rm -Rf "$TMP_DIR"

# Output and cache result
mkdir -p "$CACHE_DIR"
output="export ASTROPORT=$ASTROPORT ASTROTW=$ASTRONAUTENS ZEN=$ZEN LAT=$LAT LON=$LON ASTROG1=$ASTROG1 ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS TW=$INDEX HEX=$HEX NHEX=$NHEX source=$source"
echo "$output" > "$CACHE_FILE"
echo "$output"

exit 0
