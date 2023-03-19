################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
#~ COINScheck.sh
#~ Indiquez une clef publique G1.
#~ Il verifie le montant présent dans le cache
#~ ou le raffraichi quand il est plus ancien que 24H
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/my.sh"
################################################################################

G1PUB="$1"
## TESTING G1PUB VALIDITY

[[ $G1PUB == "" ]] && echo "PLEASE ENTER WALLET G1PUB" && exit 1

echo $(date)

ASTROTOIPFS=$(~/.zen/Astroport.ONE/tools/g1_to_ipfs.py ${G1PUB} 2>/dev/null)
[[ ! ${ASTROTOIPFS} ]] \
&& echo "INVALID G1PUB : ${G1PUB}" \
&& exit 1

echo "TW ? $myIPFS/ipns/${ASTROTOIPFS}"

#######################################################
## CLEANING DAY+1 COINS CACHE FILES
find ~/.zen/game/players/ -mtime +1 -type f -name "COINS" -exec rm -f '{}' 2>/dev/null
find ~/.zen/tmp/ -mtime +1 -type f -name "${G1PUB}.COINS" -exec rm -f '{}' 2>/dev/null
#######################################################

## IDENTIFY IF "ASTROPORT" or "COUCOU" PLAYER
echo "ASTROPATH ? "
ASTROPATH=$(grep $G1PUB ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 | rev | cut -d '/' -f 2- | rev  2>/dev/null)
echo $ASTROPATH

if [[ -d $ASTROPATH ]]; then
    COINSFILE=$ASTROPATH/ipfs/G1SSB/COINS
else
    mkdir -p ~/.zen/tmp/coucou/
    COINSFILE=~/.zen/tmp/coucou/${G1PUB}.COINS
fi

echo "ACTUAL $COINSFILE CONTAINS"
CURCOINS=$(cat $COINSFILE 2>/dev/null)
echo "$CURCOINS G1"

## NO or NULL RESULT in CACHE : REFRESHING
if [[ $CURCOINS == "" || $CURCOINS == "null" ]]; then
    (
    CURCOINS=$(~/.zen/Astroport.ONE/tools/timeout.sh -t 180 ${MY_PATH}/jaklis/jaklis.py balance -p ${G1PUB} | cut -d '.' -f 1)
    echo "$CURCOINS" > "$COINSFILE"
    echo $CURCOINS
    ) &
fi

echo $CURCOINS
exit 0
