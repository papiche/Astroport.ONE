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

########## SEND COINS TO SECTORG1PUB - ẐEN VIRTUAL BANK - EVERY 800 METERS - ;)
LAT=$(makecoord $LAT)
LON=$(makecoord $LON)
##############################################################
## POPULATE UMAP IPNS & G1PUB
$($MY_PATH/../tools/getUMAP_ENV.sh ${LAT} ${LON} | tail -n 1)

## GET COINS
COINS=$($MY_PATH/../tools/COINScheck.sh ${SECTORG1PUB} | tail -n 1)
echo "SECTOR WALLET = ${COINS} G1 : ${SECTORG1PUB}"

## UNPLUG => SEND 10 ZEN
## ALL => SEND ALL to $UPLANETG1PUB

ALL="ALL"
UPLANETG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}")

[[ $ONE == "ONE" ]] && ALL=1
[[ $ALL == "ALL" ]] && echo "DEST = UPLANETG1PUB: ${UPLANETG1PUB}"

YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})
[[ ! -z ${SECTORG1PUB} ]] \
    && echo "> PAY4SURE ZEN:${ALL} WALLET MOVE" \
    && ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${ALL}" "${UPLANETG1PUB}" "UPLANET:${UPLANETG1PUB:0:8}:UNPLUG:${YOUSER}:${ALL}"

## REMOVING PLAYER from ASTROPORT
G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
ipfs key rm "${PLAYER}" "${PLAYER}_feed" "${G1PUB}"
for vk in $(ls -d ~/.zen/game/players/${PLAYER}/voeux/*/* 2>/dev/null | rev | cut -d / -f 1 | rev); do
    echo "removing wish ${vk}"
    [[ ${vk} != "" ]] && ipfs key rm ${vk}
done

## SEND PLAYER LAST KNOW TW
TW=$(ipfs add -Hq ${INDEX} | tail -n 1)
${MY_PATH}/../tools/mailjet.sh "${PLAYER}" "<html><body><h1>Ciao ${PLAYER},</h1> Your TW is unplugged from Astroport : <a href='/ipfs/${TW}'>TW (${TW})</a>.<br>$(cat ~/.zen/game/players/${PLAYER}/secret.june)<br><h3>May the force be with you.</h3></body></html>" "BYE BYE MESSAGE $SHOUT"

echo "PLAYER IPNS KEYS UNPLUGED"
echo "#######################"
echo "CLEANING ~/.zen/game/players/${PLAYER}"
rm -Rf ~/.zen/game/players/${PLAYER-empty}

echo "CLEANING NODE CACHE ~/.zen/tmp/${IPFSNODEID-empty}/*/${PLAYER-empty}*"
rm -Rf ~/.zen/tmp/${IPFSNODEID-empty}/*/${PLAYER-empty}*

##################### REMOVE NEXTCLOUD ACCOUNT
sudo docker exec --user www-data -it nextcloud-aio-nextcloud php occ user:delete ${PLAYER}

echo "CLEANING SESSION CACHE"
rm -Rf ~/.zen/tmp/${MOATS}

exit 0
