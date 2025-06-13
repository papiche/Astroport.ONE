#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
[[ ! $(which ollama) ]] \
    && echo "STATION NEED TO RUN OLLAMA" \
    && exit 1
##
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "$ME RUNNING"
########################################################################
## G1PalPAY incoming TX detected call
## ./ASTROBOT/${CMD}.sh ${INDEX} ${PLAYER} ${MOATS} ${TXIPUBKEY} ${TH} ${TRAIL} ${TXIAMOUNT}
########################################################################
## TH=/ipfs/CID (source file to pass to AIApi)
## TRAIL=MODE:G1PUB (what API function and who to send response)
## DEFAULT /g1vlog and alert back to emiter
## AIApi : https://github.com/papiche/AiApi
########################################################################
## THIS SCRIPT IS RUN WHEN A WALLET RECEIVED A TRANSACTION WITH COMMENT STARTING WITH N1GPU:
########################################################################
INDEX="$1"
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1

PLAYER="$2"
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | head -n1 | cut -d ' ' -f1)
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
[[ ! $G1PUB ]] && echo "FATAL ERROR - G1PUB ${PLAYER} VIDE. LOCAL PLAYER ONLY."  && exit 1

MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

## CREDIT SOURCE
IPUBKEY="$4"
[[ ! ${IPUBKEY} ]] && echo "ERROR 4 - MISSING COMMAND ISSUER !"  && exit 1

## IPFS CID
TH="$5"
[[ ! ${TH} ]] && echo "ERROR 5 - MISSING IPFS CID !"  && exit 1

TRAIL="$6" ## :G1PUB
API=$(echo ${TRAIL} | cut -d ':' -f 1)
[[ -z $API ]] && API="/g1vlog"

GIPUBKEY=$(echo ${TRAIL} | cut -d ':' -f 2)
[[ ! -z ${GIPUBKEY} ]] \
    && DPUBKEY=${GIPUBKEY} \
    || DPUBKEY=${IPUBKEY}

AMOUNT="$7"
[[ ! ${AMOUNT} ]] && echo "ERROR 7 - AMOUNT=$7 7 "  && exit 1

echo "API : $API"
echo "Sender : ${IPUBKEY})
Amount : ${AMOUNT} G1
... Reply To : $DPUBKEY"

## AMOUNT & RESTRICTION ...

echo "${PLAYER} : ${IPUBKEY} ASK FOR PROCESSING ${TH}
${TRAIL}"

#~ ###################################################################
#~ ## CREATE WORKING TEMP DIRECTORY
#~ ###################################################################
mkdir -p $HOME/.zen/tmp/${MOATS} && echo $HOME/.zen/tmp/${MOATS}

## GET IPFS PARAMETER
#~ RESPIPFS="/ipfs/"$(ipfs add -q "$RESP")


## SENDING GCHANGE & CESIUM+ MESSAGE
#~ $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myDATA} send -d "${DPUBKEY}" -t "N1GPU" -m "${MESSAGE}"
#~ $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/${PLAYER}/secret.dunikey -n ${myCESIUM} send -d "${DPUBKEY}" -t "N1GPU" -m "${MESSAGE}"

