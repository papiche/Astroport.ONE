#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"
################################################################################
## UNPLUG A PLAYER FROM ASTROPORT STATION
############################################
[[ ${IPFSNODEID} == "" ]] && echo "IPFSNODEID is empty - EXIT -" && exit 1

INDEX="$1"
[[ ! -s ${INDEX} ]] && echo "INDEX ${INDEX} NOT FOUND - EXIT -" && exit 1

PLAYER="$2"
[[ ! -s ~/.zen/game/players/${PLAYER}/secret.dunikey ]] && echo "PLAYER ${PLAYER} NOT FOUND - EXIT -" && exit 1

ONE="$3"

## EXPLAIN WHY !
SHOUT="$4"


MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

## PLAYER UMAP ?
## GET "GPS" TIDDLER
tiddlywiki --load ${INDEX} \
    --output ~/.zen/tmp/${MOATS} \
    --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
TWMAPNS=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].umap)
LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
            [[ $LAT == "null" || $LAT == "" ]] && LAT="0.00"
LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
            [[ $LON == "null" || $LON == "" ]] && LON="0.00"
echo "LAT=${LAT}; LON=${LON}; UMAPNS=${TWMAPNS}"
rm ~/.zen/tmp/${MOATS}/GPS.json

########## SEND COINS TO UPLANETNAME_G1 - ẐEN CENTRAL BANK ;)
LAT=$(makecoord $LAT)
LON=$(makecoord $LON)
##############################################################
## POPULATE UMAP IPNS & G1PUB
$($MY_PATH/../tools/getUMAP_ENV.sh ${LAT} ${LON} | tail -n 1)

## GET COINS
COINS=$($MY_PATH/../tools/G1check.sh ${UPLANETNAME_G1} | tail -n 1)
echo "SECTOR WALLET = ${COINS} G1 : ${UPLANETNAME_G1}"

## UNPLUG => SEND 10 ZEN
## ALL => SEND ALL to $UPLANETNAME_G1

ALL="ALL"

[[ $ONE == "ONE" ]] && ALL=1
[[ $ALL == "ALL" ]] && echo "DEST = UPLANETNAME_G1: ${UPLANETNAME_G1}"

YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})

# Check G1 balance of the ZEN Card before attempting transfer
G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
if [[ ! -z ${G1PUB} ]]; then
    BALANCE=$(${MY_PATH}/../tools/G1check.sh ${G1PUB} | tail -n 1)
    echo "ZEN CARD WALLET BALANCE = ${BALANCE} G1 : ${G1PUB}"
    
    if [[ -n ${BALANCE} && ${BALANCE} != "null" && ${BALANCE} != "0" && ${BALANCE} != "0.00" ]]; then
        echo "> PAYforSURE ZEN:${ALL} WALLET MOVE"
        ${MY_PATH}/../tools/PAYforSURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${ALL}" "${UPLANETNAME_G1}" "UPLANET${UPLANETNAME_G1:0:8}:UNPLUG:${YOUSER}:${ALL}" 2>/dev/null
    else
        echo "No G1 balance to transfer from ZEN Card (${BALANCE} G1) - skipping PAYforSURE"
    fi
fi

## REMOVING PLAYER from ASTROPORT
ipfs key rm "${PLAYER}" "${PLAYER}_feed" "${G1PUB}"
for vk in $(ls -d ~/.zen/game/players/${PLAYER}/voeux/*/* 2>/dev/null | rev | cut -d / -f 1 | rev); do
    echo "removing wish ${vk}"
    [[ ${vk} != "" ]] && ipfs key rm ${vk}
done

## CLEANUP NOSTR PROFILE - Remove zencard parameter
## Before unplugging, update NOSTR profile to remove zencard parameter
if [[ -s ~/.zen/game/nostr/${PLAYER}/.secret.nostr ]]; then
    echo "## Cleaning up NOSTR profile - removing ZENCARD parameter..."
    source ~/.zen/game/nostr/${PLAYER}/.secret.nostr
    
    # Update NOSTR profile to remove zencard parameter
    ${MY_PATH}/../tools/nostr_update_profile.py \
        "$NSEC" \
        "wss://relay.copylaradio.com" "$myRELAY" \
        --zencard "" \
        > ~/.zen/tmp/${MOATS}/nostr_cleanup_zencard.log 2>&1
    
    if [[ $? -eq 0 ]]; then
        echo "✅ NOSTR profile cleaned - ZENCARD parameter removed"
    else
        echo "⚠️ NOSTR profile cleanup failed, check log: ~/.zen/tmp/${MOATS}/nostr_cleanup_zencard.log"
    fi
else
    echo "⚠️ NOSTR secret not found, skipping profile cleanup"
fi

## SEND PLAYER LAST KNOW TW
TW=$(ipfs add -Hq ${INDEX} | tail -n 1)
${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "<html><body><h1>Ciao ${PLAYER},</h1> Your TW is unplugged from Astroport : <a href='/ipfs/${TW}'>TW (${TW})</a>.<br>$(cat ~/.zen/game/players/${PLAYER}/secret.june)<br><h3>May the force be with you.</h3></body></html>" "CIAO $SHOUT"

echo "PLAYER IPNS KEYS UNPLUGED"
echo "#######################"
echo "CLEANING ~/.zen/game/players/${PLAYER}"
rm -Rf ~/.zen/game/players/${PLAYER-empty}

echo "CLEANING NODE CACHE ~/.zen/tmp/${IPFSNODEID-empty}/*/${PLAYER-empty}*"
rm -Rf ~/.zen/tmp/${IPFSNODEID-empty}/*/${PLAYER-empty}*

##################### REMOVE NEXTCLOUD ACCOUNT
YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${PLAYER}")
#~ sudo docker exec --user www-data -it nextcloud-aio-nextcloud php occ user:delete ${YOUSER}

echo "CLEANING SESSION CACHE"
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
