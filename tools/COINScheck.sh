#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.2
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

echo "COINCHECK ${G1PUB} (/ipns/${ASTROTOIPFS})"

#######################################################
## CLEANING DAY+30 COINS CACHE FILES
find ~/.zen/tmp/coucou/ -mtime +30 -type f -name "*.COINS" -exec rm -f '{}' \;
echo "Cleaning ${G1PUB}.COINS"
find ~/.zen/tmp/ -mtime +1 -type f -name "${G1PUB}.COINS" -exec mv '{}' $HOME/.zen/tmp/backup.${G1PUB} \;
#######################################################
mkdir -p $HOME/.zen/tmp/coucou/
COINSFILE=$HOME/.zen/tmp/coucou/${G1PUB}.COINS
#######################################################
## GET EXTERNAL G1 DATA
${MY_PATH}/../tools/GetGCAttributesFromG1PUB.sh ${G1PUB}
#######################################################
#######################################################

# Try to get balance immediately without checking cache first
CURCOINS=$(${MY_PATH}/timeout.sh -t 5 ${MY_PATH}/jaklis/jaklis.py balance -p ${G1PUB})

# If immediate check fails, try with a different GVA server
if [[ "$CURCOINS" == "" ]]; then
    echo "JAKLIS GVA SERVER SWITCH ---"
    GVA=$(${MY_PATH}/../tools/duniter_getnode.sh | tail -n 1)
    [[ ! -z $GVA ]] \
        && sed -i '/^NODE=/d' ${MY_PATH}/../tools/jaklis/.env \
        && echo "NODE=$GVA" >> ${MY_PATH}/../tools/jaklis/.env \
        && echo "GVA NODE=$GVA" \
        && CURCOINS=$(${MY_PATH}/timeout.sh -t 5 ${MY_PATH}/jaklis/jaklis.py balance -p ${G1PUB})
fi

# If we got a valid balance, save it to cache
if [[ "$CURCOINS" != "" && "$CURCOINS" != "null" ]]; then
    echo "$CURCOINS" > "$COINSFILE"
    rm $HOME/.zen/tmp/backup.${G1PUB} 2>/dev/null
    echo "$CURCOINS"
    exit 0
fi

# If we still don't have a balance, try to use cached value
if [[ -s $HOME/.zen/tmp/backup.${G1PUB} ]]; then
    cat $HOME/.zen/tmp/backup.${G1PUB}
    exit 0
fi

# If all else fails, return empty
echo ""
exit 1
