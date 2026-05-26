#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS] INDEX PLAYER [ONE] [SHOUT]"
    echo ""
    echo "Unplug a player from Astroport.ONE station"
    echo ""
    echo "Arguments:"
    echo "  INDEX     Path to player's TW index.html file"
    echo "  PLAYER    Player email address"
    echo "  ONE       Transfer amount: 'ALL' (default) or 'ONE' (1 G1)"
    echo "  SHOUT     Reason for unplugging (optional)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Description:"
    echo "  This script unplugs a player from the Astroport.ONE station."
    echo "  It removes IPNS keys, cleans up local cache, and optionally"
    echo "  transfers excess G1 balance to UPLANETNAME_G1 central bank."
    echo ""
    echo "  ZEN Card Preservation:"
    echo "  - ZEN Card is preserved for capital shares transit via UPLANET.official.sh"
    echo "  - Keeps minimum 1 G1 for capital shares management"
    echo "  - Only transfers excess balance (balance - 1 G1)"
    echo ""
    echo "Examples:"
    echo "  $0 ~/.zen/game/players/user@example.com/ipfs/moa/index.html user@example.com"
    echo "  $0 ~/.zen/game/players/user@example.com/ipfs/moa/index.html user@example.com ALL 'Migration'"
    echo "  $0 ~/.zen/game/players/user@example.com/ipfs/moa/index.html user@example.com ONE 'Quick exit'"
    echo ""
    exit 0
}

# Check for help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
fi

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

## ZEN CARD PRESERVATION FOR CAPITAL SHARES TRANSIT
## The ZEN Card is used to transit capital shares acquired via UPLANET.official.sh
## It should NOT be emptied during unplug - only transfer excess G1 if needed

ALL="ALL"
[[ $ONE == "ONE" ]] && ALL=1

YOUSER=$(${MY_PATH}/../tools/clyuseryomail.sh ${PLAYER})


## REMOVING PLAYER from ASTROPORT
ipfs key rm "${PLAYER}" "${PLAYER}_feed" "${G1PUB}"
for vk in $(ls -d ~/.zen/game/players/${PLAYER}/voeux/*/* 2>/dev/null | rev | cut -d / -f 1 | rev); do
    echo "removing wish ${vk}"
    [[ ${vk} != "" ]] && ipfs key rm ${vk}
done

## SEND CAPTAINEMAIL PLAYER UNPLUG NOTIFICATION
TW=$(ipfs add -Hq ${INDEX} | tail -n 1)

_g1pub=$(cat "${HOME}/.zen/game/players/${PLAYER}/.g1pub" 2>/dev/null || echo "N/A")
_unplug_tmp=$(mktemp)
sed -e "s~_PLAYER_~${PLAYER}~g" \
    -e "s~_IPFSNODEID_SHORT_~${IPFSNODEID:0:8}~g" \
    -e "s~_IPFSNODEID_~${IPFSNODEID}~g" \
    -e "s~_TODATE_~$(date '+%Y-%m-%d %H:%M UTC')~g" \
    -e "s~_SHOUT_~${SHOUT:-Déconnexion standard}~g" \
    -e "s~_LAT_~${LAT:-N/A}~g" \
    -e "s~_LON_~${LON:-N/A}~g" \
    -e "s~_TW_CID_~${TW}~g" \
    -e "s~_MY_IPFS_~${myIPFS}~g" \
    -e "s~_G1PUB_~${_g1pub}~g" \
    "${MY_PATH}/../templates/NOSTR/captain_player_unplug.html" > "$_unplug_tmp"
${MY_PATH}/../tools/mailjet.sh --template "${MY_PATH}/../templates/NOSTR/captain_player_unplug.html" \
    --expire 7d "${CAPTAINEMAIL}" "$_unplug_tmp" "🔌 Joueur déconnecté : ${PLAYER} — ${SHOUT:-Déconnexion standard}"
rm -f "$_unplug_tmp"

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
