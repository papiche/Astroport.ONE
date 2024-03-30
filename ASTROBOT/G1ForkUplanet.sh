#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

## IT MAKES WISH WALLET MASTER OF NEW UPLANET
## IT MAKES swarm.key as UPLANETNAME
## SAME WISH BE CONNECTED TO THE PRIVATE IPFS MADE FIRST

echo "(✜‿‿✜) Fork UPlanet
This wish makes Player generate or join a private IPFS swarm
It can be use to populate UPlanet ZERO (or not)
All friends with the same wish will share the SECRET
then any can activate a new ipfs daemon connected to that private ZONE
Planet shape could be define from text found in command tiddler
and initiale new euclidian geokeys...
Default :
flaoting points"

echo "$ME RUNNING"

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

MOATS="$3"
[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "${PLAYER} ${INDEX} ${ASTRONAUTENS} ${G1PUB} "
mkdir -p $HOME/.zen/tmp/${MOATS}
echo "~/.zen/tmp/${MOATS}/swarm.key"
JSONWISH="$4"
## SHOW WISH CONTAINS SELF CRYPTED SWARMKEY (+ SIGNERS)
cat ${JSONWISH} | jq -r

PLAYERPUB=$(cat $HOME/.zen/game/${PLAYER}/secret.dunikey | grep pub | cut -d ' ' -f 2)
[[ "${PLAYERPUB}" == "" ]] && echo "FATAL ERROR PLAYER KEY MISSING" && exit 1
WISHNAME=$(cat ${JSONWISH} | jq .title) # ForkUPlanet !
UPNAME=$(cat ${JSONWISH} | jq -r ".name") ## What name is given ?
CONTRACT=$(cat ${JSONWISH} | jq -r ".text") ## What contract is applying ?

## CHECK EXISTING ${WISHNAME}.${UPNAME}.swarm.key
[[ ! -s $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key ]] \
    && MSG=$MSG" ${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key NOT FOUND" && ERR="NO LOCAL KEY"

## CREATE 64 bit swarm.key ( maximum individual Fork 1,844674407×10¹⁹ )
echo -e '/key/swarm/psk/1.0.0/\n/base16/' > $HOME/.zen/tmp/${MOATS}/swarm.key
head -c 64 /dev/urandom | od -t x1 -A none - | tr -d '\n ' >> $HOME/.zen/tmp/${MOATS}/swarm.key
echo '' >> $HOME/.zen/tmp/${MOATS}/swarm.key

## EXTRACT SECRET FROM JSONWISH
###############################
OLD16=$(cat ${JSONWISH} | jq -r ".secret")
[[ ${OLD16} == "" || ${OLD16} == "null" ]] \
    && echo "NO SECRET FOUND" \
    && echo "NEW SECRET SWARM.KEY GENERATION" \
    && cat $HOME/.zen/tmp/${MOATS}/swarm.key \
    && cp $HOME/.zen/tmp/${MOATS}/swarm.key $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key \
    && echo "------- NEW ------ ${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key"

## DEBASE16
echo "${OLD16}" | base16 -d \
        > ~/.zen/tmp/${MOATS}/swarmkey.crypted

## TRY TO DECODE with PLAYER secret.dunikey
${MY_PATH}/../tools/natools.py decrypt \
        -f pubsec \
        -k $HOME/.zen/game/${PLAYER}/secret.dunikey \
        -i ~/.zen/tmp/${MOATS}/swarmkey.crypted \
        -o ~/.zen/tmp/${MOATS}/swarmkey.decrypted

[[ $(diff ~/.zen/tmp/${MOATS}/swarmkey.decrypted $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key) ]] \\
    && echo " SWARM AND LOCAL KEY ARE DIFFERENT " && ERR="TW SWARM CHANGED"

## ALWAYS UPDATE PLAYER LOCAL ?!
cp ~/.zen/tmp/${MOATS}/swarmkey.decrypted \
    $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key

if [[ "$ERR" == "" ]] ; then
    #~ echo "# CRYPTO ENCODING PLAYER KEY WITH PLAYERPUB
    ${MY_PATH}/../tools/natools.py encrypt \
        -p ${PLAYERPUB} \
        -i $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key \
        -o $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key.enc
    ENCODING=$(cat $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key.enc | base16)
    sed -i "s~${OLD16}~${ENCODING}~g" ${JSONWISH}
    echo "ENCODING: ${ENCODING}"

fi



exit 0
