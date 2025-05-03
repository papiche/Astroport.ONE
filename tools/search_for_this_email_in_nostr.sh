#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# ON LINE echo script! LAST LINE export VARIABLE values
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"

EMAIL="$1"

if [[ "${EMAIL}" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then

    HEXGATE=$(cat ${HOME}/.zen/game/nostr/${EMAIL}/HEX 2>/dev/null) \
                        && source="LOCAL" && source ${HOME}/.zen/game/nostr/${EMAIL}/GPS &&
    [[ -z $HEXGATE ]] && HEXGATE=$(cat ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/HEX 2>/dev/null) \
                        && source="CACHE" && source ${HOME}/.zen/tmp/${IPFSNODEID}/TW/${EMAIL}/GPS
    [[ -z $HEXGATE ]] && HEXGATE=$(cat ${HOME}/.zen/tmp/swarm/*/TW/${EMAIL}/HEX 2>/dev/null) \
                        && source="SWARM" && source ${HOME}/.zen/tmp/swarm/*/TW/${EMAIL}/GPS
    [[ -z $HEXGATE ]] && exit 1
    ## TODO ? SEARCH WITH DNSLINK
    G1PUBNOSTR=$(cat ${HOME}/.zen/game/nostr/${EMAIL}/G1PUBNOSTR)
    echo "export source=${source} HEX=${HEXGATE} LAT=${LAT} LON=${LON} EMAIL=${EMAIL} G1PUBNOSTR=${G1PUBNOSTR}"
    exit 0

fi

exit 0
