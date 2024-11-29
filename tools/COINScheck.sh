#!/bin/bash
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

echo "COINCHECK ${G1PUB} -> TW : $myIPFS/ipns/${ASTROTOIPFS}"

#######################################################
## CLEANING DAY+1 COINS CACHE FILES
# find ~/.zen/game/players/ -mtime +1 -type f -name "COINS" -exec rm -f '{}' \;
echo "Cleaning ${G1PUB}.COINS"
find ~/.zen/tmp/ -mtime +1 -type f -name "${G1PUB}.COINS" -exec mv '{}' $HOME/.zen/tmp/backup.${G1PUB} \;
echo "Cleaning ${G1PUB}.g1history.json"
find ~/.zen/tmp/coucou/ -mtime +1 -type f -name "${G1PUB}.g1history.json" -exec rm '{}' \;
#######################################################

## IDENTIFY IF "ASTROPORT" PLAYER
# echo "ASTROPATH ? "
ASTROPATH=$(grep $G1PUB ~/.zen/game/players/*/.g1pub 2>/dev/null | cut -d ':' -f 1 | rev | cut -d '/' -f 2- | rev)
echo $ASTROPATH

if [[ -d $ASTROPATH ]]; then
    INNERFILE=$ASTROPATH/ipfs/G1SSB/COINS
fi

mkdir -p $HOME/.zen/tmp/coucou/
COINSFILE=$HOME/.zen/tmp/coucou/${G1PUB}.COINS
#######################################################
## GET EXTERNAL G1 DATA
${MY_PATH}/../tools/GetGCAttributesFromG1PUB.sh ${G1PUB}
#######################################################
#######################################################

# echo "ACTUAL $COINSFILE CONTAINS"
CURCOINS=$(cat $COINSFILE 2>/dev/null)
echo "SOLDE : $CURCOINS G1"

## NO or NULL RESULT in CACHE : REFRESHING
if [[ $CURCOINS == "" || $CURCOINS == "null" ]]; then
    (
    CURCOINS=$(${MY_PATH}/timeout.sh -t 10 ${MY_PATH}/jaklis/jaklis.py balance -p ${G1PUB})
    if [[ "$CURCOINS" == "" ]]; then
        echo "JAKLIS ERROR - switch server ---"
        ## Changing GVA SERVER in tools/jaklis/.env
        GVA=$(${MY_PATH}/../tools/duniter_getnode.sh | tail -n 1)
        [[ ! -z $GVA ]] \
            && sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env \
            && echo "NODE=$GVA" >> ${MY_PATH}/../tools/jaklis/.env \
            && echo "GVA NODE=$GVA" \
            && CURCOINS=$(${MY_PATH}/timeout.sh -t 10 ${MY_PATH}/jaklis/jaklis.py balance -p ${G1PUB})
    fi
    [[ "$CURCOINS" == "null" ]] && echo "EMPTY WALLET"

    echo "$CURCOINS" > "$COINSFILE"

    # PREVENT DUNITER DESYNC (KEEPING ASTROPORT LAST KNOWN VALUE)
    [[ $CURCOINS == "" || $CURCOINS == "null" ]] \
    && [[ -s $HOME/.zen/tmp/backup.${G1PUB} ]] \
    && WASCOINS=$(cat $HOME/.zen/tmp/backup.${G1PUB}) \
    && [[ ${WASCOINS} != "" && ${WASCOINS} != "null" ]] && echo ${WASCOINS} > "$COINSFILE"

    [[ $INNERFILE != "" ]] && cp "$COINSFILE" "$INNERFILE" && echo "LOCAL PLAYER COINS UPDATED"
    echo $CURCOINS
    ) &
fi
#### tail -n 1 FUNCTION RESULT
echo $CURCOINS
exit 0
