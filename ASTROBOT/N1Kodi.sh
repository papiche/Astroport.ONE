#!/bin/bash
########################################################################
# Version: 0.5
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
# PAD COCODING : https://pad.p2p.legal/s/G1Kodi
# KODI SERVICE : Publish and Merge Friends Kodi Movies into RSS Stream
########################################################################
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

echo "$ME RUNNING"

########################################################################
########################################################################
INDEX="$1"
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1
ORIGININDEX=${INDEX}

PLAYER="$2"
[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
[[ ! $G1PUB ]] && echo "ERROR - G1PUB ${PLAYER} VIDE"  && exit 1

# Extract tag=tube from TW
MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "${PLAYER} ${INDEX} ${ASTRONAUTENS} ${G1PUB} "
#~ ###################################################################
#~ ## CREATE APP NODE PLAYER PUBLICATION DIRECTORY
#~ ###################################################################
mkdir -p $HOME/.zen/tmp/${MOATS} && echo $HOME/.zen/tmp/${MOATS}
mkdir -p $HOME/.zen/game/players/${PLAYER}/G1Kodi/

echo "EXPORT Kodi Wish for ${PLAYER}"
rm -f ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json
tiddlywiki  --load ${INDEX} \
                    --output ~/.zen/game/players/${PLAYER}/G1Kodi \
                    --render '.' 'Kodi.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Kodi'

[[ $(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json ) == "[]" ]] \
    && echo "AUCUN VOEU G1KODI - EXIT -" \
    && rm -Rf $HOME/.zen/game/players/${PLAYER}/G1Kodi \
    && exit 0

WISH=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json | jq -r '.[].wish')
WISHNS=$(cat ~/.zen/game/players/${PLAYER}/G1Kodi/Kodi.json | jq -r '.[].wishns')
echo "G1KODI: $WISH ${myIPFS}$WISHNS"
#~ ###################################################################

find ~/.zen/game/players/${PLAYER}/FRIENDS -mindepth 1 -maxdepth 1 -type d | rev | cut -f 1 -d '/' | rev > ~/.zen/tmp/${MOATS}/twfriends




exit 0

## ./userdata/mediasources.xml
## ./userdata/sources.xml
