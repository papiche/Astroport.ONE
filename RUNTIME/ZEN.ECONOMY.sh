################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ ZEN.ECONOMY.sh
#~ Make payments between UPlanet / NODE / Captain & NOSTR / PLAYERS Cards
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/../tools/my.sh"
################################################################################
start=`date +%s`

#######################################################################
#~ echo "UPlanet Secret Name (ipfs) : ${UPLANETNAME}"
echo "UPlanet G1PUB : ${UPLANETG1PUB}"
UCOIN=$(${MY_PATH}/../tools/COINScheck.sh ${UPLANETG1PUB} | tail -n 1)
UZEN=$(echo "($UCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$UZEN Ẑen"
NODEG1PUB=$($MY_PATH/../tools/ipfs_to_g1.py ${IPFSNODEID})
echo "NODE G1PUB : ${NODEG1PUB}"
NODECOIN=$(${MY_PATH}/../tools/COINScheck.sh ${NODEG1PUB} | tail -n 1)
NODEZEN=$(echo "($NODECOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$NODEZEN Ẑen"
echo "CAPTAIN G1PUB : ${CAPTAING1PUB}"
CAPTAINCOIN=$(${MY_PATH}/../tools/COINScheck.sh ${NODEG1PUB} | tail -n 1)
CAPTAINZEN=$(echo "($CAPTAINCOIN - 1) * 10" | bc | cut -d '.' -f 1)
echo "$CAPTAINZEN Ẑen"
#######################################################################
#### NOSTR & ZEN CARD are paying during NOSTRCARD.refresh.sh & PLAYER.refresh.sh
NOSTRS=($(ls -t ~/.zen/game/nostr/ 2>/dev/null | grep "@" ))
PLAYERS=($(ls -t ~/.zen/game/players/ 2>/dev/null | grep "@" ))
echo "NODE hosts NOSTR : ${#NOSTRS[@]} / ZEN : ${#PLAYERS[@]}"

## EVERY DAY CAPTAIN PAY PAF/28
[[ -z $PAF ]] && PAF=56
[[ -z $NCARD ]] && NCARD=4
[[ -z $ZCARD ]] && ZCARD=15
DAILYPAF=$(makecoord $(echo "$PAF / 28" | bc))
echo "ZEN ECONOMY : $PAF ($DAILYPAF ZEN) :: NCARD=$NCARD // ZCARD=$ZCARD"
DAILYG1=$(makecoord $(echo "$DAILYPAF / 10" | bc ))

## UPLANET WALLET CONTAINS "ASSET VALUE"
if [[ $(echo "$CAPTAINZEN > $DAILYPAF" | bc -l) -eq 1 ]]; then
    ## CAPTAIN PAY NODE : ECONOMY +
    ${MY_PATH}/../tools/PAY4SURE.sh "$HOME/.zen/game/players/.current/secret.dunikey" "$DAILYG1" "${NODEG1PUB}" "NOSTR:${UPLANETG1PUB:0:8}:PAF"
else
    ## UPLANET IS PAYING NODE: ECONOMY -
    ${MY_PATH}/../tools/PAY4SURE.sh "$HOME/.zen/game/uplanet.dunikey" "$DAILYG1" "${NODEG1PUB}" "NOSTR:${UPLANETG1PUB:0:8}:PAF"
fi

exit 0
