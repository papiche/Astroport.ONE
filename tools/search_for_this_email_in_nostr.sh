#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# ON LINE echo script! LAST LINE export VARIABLE values
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

# Function to get email data in JSON format
get_email_json() {
    local email="$1"
    local source=""
    local hexgate=""
    local lat=""
    local lon=""
    local g1pubnostr=""
    local npub=""
    local relay=""

    # LOCAL
    hexgate=$(cat ${HOME}/.zen/game/nostr/${email}/HEX 2>/dev/null)
    if [ -n "$hexgate" ]; then
        source="LOCAL"
        if [ -f "${HOME}/.zen/game/nostr/${email}/GPS" ]; then
            source ${HOME}/.zen/game/nostr/${email}/GPS 2>/dev/null
            lat="$LAT"
            lon="$LON"
        fi
        g1pubnostr=$(cat ${HOME}/.zen/game/nostr/${email}/G1PUBNOSTR 2>/dev/null)
        npub=$(cat ${HOME}/.zen/game/nostr/${email}/NPUB 2>/dev/null)
        relay="$myRELAY"
    fi

    # CACHE
    if [ -z "$hexgate" ]; then
        hexgate=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${email}/HEX 2>/dev/null)
        if [ -n "$hexgate" ]; then
            source="CACHE"
            if [ -f "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${email}/GPS" ]; then
                source ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${email}/GPS 2>/dev/null
                lat="$LAT"
                lon="$LON"
            fi
            g1pubnostr=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${email}/G1PUBNOSTR 2>/dev/null)
            npub=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${email}/NPUB 2>/dev/null)
            relay=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/12345.json 2>/dev/null | jq -r '.myRELAY' 2>/dev/null)
        fi
    fi

    # SWARM
    if [ -z "$hexgate" ]; then
        local swarm_dir=$(find ${HOME}/.zen/tmp/swarm -path "*/TW/${email}/HEX" -printf "%h" 2>/dev/null | head -1)
        if [ -n "$swarm_dir" ]; then
            hexgate=$(cat ${swarm_dir}/HEX 2>/dev/null)
            if [ -n "$hexgate" ]; then
                source="SWARM"
                # Find the correct 12345.json file in swarm directory first
                local swarm_node_dir=$(echo "$swarm_dir" | sed 's|/TW/.*||')
                # Get GPS coordinates
                if [ -f "${swarm_dir}/GPS" ]; then
                    source ${swarm_dir}/GPS 2>/dev/null
                    lat="$LAT"
                    lon="$LON"
                fi
                # Get other data
                g1pubnostr=$(cat ${swarm_dir}/G1PUBNOSTR 2>/dev/null)
                npub=$(cat ${swarm_dir}/NPUB 2>/dev/null)
                relay=$(cat ${swarm_node_dir}/12345.json 2>/dev/null | jq -r '.myRELAY' 2>/dev/null)
            fi
        fi
    fi

    # Output JSON if hexgate found
    if [ -n "$hexgate" ]; then
        jq -n \
            --arg email "$email" \
            --arg source "$source" \
            --arg hex "$hexgate" \
            --arg lat "$lat" \
            --arg lon "$lon" \
            --arg g1pubnostr "$g1pubnostr" \
            --arg npub "$npub" \
            --arg relay "$relay" \
            '{
                email: $email,
                source: $source,
                hex: $hex,
                lat: $lat,
                lon: $lon,
                g1pubnostr: $g1pubnostr,
                npub: $npub,
                relay: $relay
            }'
    fi
}

# Parse parameters
ALL_JSON=false
EMAIL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --all)
            ALL_JSON=true
            shift
            ;;
        *)
            EMAIL="$1"
            shift
            ;;
    esac
done

# Handle --all parameter
if [ "$ALL_JSON" = true ]; then
    echo "["
    first=true
    
    # LOCAL emails
    for email_dir in ${HOME}/.zen/game/nostr/*@*; do
        if [ -d "$email_dir" ]; then
            email=$(basename "$email_dir")
            if [ "$first" = true ]; then
                first=false
            else
                echo ","
            fi
            get_email_json "$email"
        fi
    done
    
    # CACHE emails
    if [ -d "${HOME}/.zen/tmp/${IPFSNODEID}/TW" ]; then
        for email_dir in ${HOME}/.zen/tmp/${IPFSNODEID}/TW/*@*; do
            if [ -d "$email_dir" ]; then
                email=$(basename "$email_dir")
                # Skip if already found in LOCAL
                if [ ! -d "${HOME}/.zen/game/nostr/${email}" ]; then
                    if [ "$first" = true ]; then
                        first=false
                    else
                        echo ","
                    fi
                    get_email_json "$email"
                fi
            fi
        done
    fi
    
    # SWARM emails
    if [ -d "${HOME}/.zen/tmp/swarm" ]; then
        for swarm_dir in ${HOME}/.zen/tmp/swarm/*/TW/*@*; do
            if [ -d "$swarm_dir" ]; then
                email=$(basename "$swarm_dir")
                # Skip if already found in LOCAL or CACHE
                if [ ! -d "${HOME}/.zen/game/nostr/${email}" ] && [ ! -d "${HOME}/.zen/tmp/${IPFSNODEID}/TW/${email}" ]; then
                    if [ "$first" = true ]; then
                        first=false
                    else
                        echo ","
                    fi
                    get_email_json "$email"
                fi
            fi
        done
    fi
    
    echo "]"
    exit 0
fi

# Si aucun email n'est fourni, lister tous les emails trouvés
if [ -z "$EMAIL" ]; then
    echo "Listing all emails found in sources:"
    echo "LOCAL _____________________________"
    find ${HOME}/.zen/game/nostr -maxdepth 1 -type d -name "*@*" -printf "%f " 2>/dev/null
    echo
    echo "CACHE _____________________________"
    find ${HOME}/.zen/tmp/${IPFSNODEID}/TW -maxdepth 1 -type d -name "*@*" -printf "%f " 2>/dev/null
    echo
    echo "SWARM _____________________________"
    find ${HOME}/.zen/tmp/swarm/*/TW -maxdepth 1 -type d -name "*@*" -printf "%f " 2>/dev/null
    echo
    exit 0
fi

if [[ "${EMAIL}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then

    # LOCAL
    HEXGATE=$(cat ${HOME}/.zen/game/nostr/${EMAIL}/HEX 2>/dev/null) \
                        && source="LOCAL" && source ${HOME}/.zen/game/nostr/${EMAIL}/GPS 2>/dev/null \
                        && G1PUBNOSTR=$(cat ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR 2>/dev/null) \
                        && NPUB=$(cat ${HOME}/.zen/game/nostr/${EMAIL}/NPUB 2>/dev/null) \
                        && RELAY=$myRELAY
 
    # CACHE
    [[ -z $HEXGATE ]] && HEXGATE=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/HEX 2>/dev/null) \
                        && source="CACHE" && source ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/GPS 2>/dev/null \
                        && G1PUBNOSTR=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/G1PUBNOSTR 2>/dev/null) \
                        && NPUB=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/NPUB 2>/dev/null) \
                        && RELAY=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/12345.json 2>/dev/null | jq -r '.myRELAY' 2>/dev/null)
 
    # SWARM
    [[ -z $HEXGATE ]] && SWARM_DIR=$(find ${HOME}/.zen/tmp/swarm -path "*/TW/${EMAIL}/HEX" -printf "%h" 2>/dev/null | head -1) \
                        && HEXGATE=$(cat ${SWARM_DIR}/HEX 2>/dev/null) \
                        && source="SWARM" \
                        && SWARM_NODE_DIR=$(echo "$SWARM_DIR" | sed 's|/TW/.*||') \
                        && source ${SWARM_DIR}/GPS 2>/dev/null \
                        && G1PUBNOSTR=$(cat ${SWARM_DIR}/G1PUBNOSTR 2>/dev/null) \
                        && NPUB=$(cat ${SWARM_DIR}/NPUB 2>/dev/null) \
                        && RELAY=$(cat ${SWARM_NODE_DIR}/12345.json 2>/dev/null | jq -r '.myRELAY' 2>/dev/null)
 
    [[ -z $HEXGATE ]] && exit 1
 
    ## OUTPUT
    echo "export source=${source} HEX=${HEXGATE} LAT=${LAT} LON=${LON} EMAIL=${EMAIL} G1PUBNOSTR=${G1PUBNOSTR} NPUB=${NPUB} RELAY=${RELAY}"
    exit 0

fi

exit 0
