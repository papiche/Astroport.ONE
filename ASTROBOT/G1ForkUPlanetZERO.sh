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

PLAYERPUB=$(cat $HOME/.zen/game/${PLAYER}/secret.dunikey | grep pub | cut -d ' ' -f 2)
[[ "${PLAYERPUB}" == "" ]] && echo "FATAL ERROR PLAYER KEY MISSING" && exit 1

###################################################################
## tag[ForkUPlanetZERO] TW EXTRACTION
###################################################################
tiddlywiki  --load ${INDEX} \
    --output ~/.zen/tmp/${MOATS} \
    --render '.' 'G1ForkUPlanetZERO.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[ForkUPlanetZERO]]'

echo "PREPARE INLINE JSON : cat ~/.zen/tmp/${MOATS}/G1ForkUPlanetZERO.json | jq -rc .[]"
cat ~/.zen/tmp/${MOATS}/G1ForkUPlanetZERO.json \
        | jq -rc .[] > ~/.zen/tmp/${MOATS}/inlineuplanets.json

while read JSONUPLANET; do

    echo "JSONUPLANET=${JSONUPLANET}"

    UPNAME=$(cat ${JSONUPLANET} | jq .title) # What name is given ?
    [[ "${UPNAME}" == "null" ||  "${UPNAME}" == "" ]] && echo "FATAL ERROR UPNAME .UPname MISSING" && exit 1
    HASH=$(cat ${JSONUPLANET} | jq -r ".hash") ## What text hash it has ?
    [[ "${HASH}" == "null" ||  "${HASH}" == "" ]] && echo "FATAL ERROR UPNAME .hash MISSING" && exit 1
    SECRET=$(cat ${JSONUPLANET} | jq -r ".secret") ## What is secret ?
    [[ "${SECRET}" == "null" ||  "${SECRET}" == "" ]] && echo "FATAL ERROR UPNAME .secret MISSING" && exit 1

    CONTRACT=$(cat ${JSONUPLANET} | jq -r ".text") ## What contract is applying ?
    [[ "${CONTRACT}" == "null" ||  "${CONTRACT}" == "" ]] && CONTRACT="☼☼☼☼☼ floating points ☼☼☼☼☼"
    echo "- CONTRACT -------------------------------------"
    echo $CONTRACT
    echo "--------------------------------------"
    AHAH=$(echo $CONTRACT | sha512sum | cut -d ' ' -f 1)

    [[ $AHAH != $HASH ]] && echo " - WARNING - CONTRACT CHANGED - WARNING -"

    ## CHECK EXISTING ${WISHNAME}.${UPNAME}.swarm.key
    [[ ! -s $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key ]] \
        && MSG=$MSG" ${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key NOT FOUND" && ERR="NO LOCAL KEY"

    ## CREATE 64 bit swarm.key ( maximum individual Fork 1,844674407×10¹⁹ )
    echo -e '/key/swarm/psk/1.0.0/\n/base16/' > $HOME/.zen/tmp/${MOATS}/swarm.key
    head -c 64 /dev/urandom | od -t x1 -A none - | tr -d '\n ' >> $HOME/.zen/tmp/${MOATS}/swarm.key
    echo '' >> $HOME/.zen/tmp/${MOATS}/swarm.key

    ## EXTRACT CURRENT SECRET FROM JSONUPLANET
    ########################################
    OLD16=$(cat ${JSONUPLANET} | jq -r ".secret")

    if [[ ${OLD16} == "" || ${OLD16} == "null" ]]; then

        echo "NO SECRET FOUND" \
        && echo "NEW SECRET SWARM.KEY GENERATION" \
        && cat $HOME/.zen/tmp/${MOATS}/swarm.key \
        && cp $HOME/.zen/tmp/${MOATS}/swarm.key $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key \
        && echo "------- KEY LOADED -----> ${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key"

        ## CREATE SUB WORLD... MONITOR TEXT

    else
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

        ## UPDATE PLAYER LOCAL SWARMKEY FROM VALUE FOUND IN HIS OWN WISH TIDDLER !
        [[ -s ~/.zen/tmp/${MOATS}/swarmkey.decrypted ]] \
                && cp ~/.zen/tmp/${MOATS}/swarmkey.decrypted \
                    $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key \
                || echo "ERROR RELOADING SWARMKEY"
    fi

    #~ RECREATE SECRET
    ${MY_PATH}/../tools/natools.py encrypt \
        -p ${PLAYERPUB} \
        -i $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key \
        -o $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key.enc
    ENCODING=$(cat $HOME/.zen/game/${PLAYER}/${WISHNAME}.${UPNAME}.swarm.key.enc | base16)

    echo "${SECRET}"
    echo "${ENCODING}"
    ## UPDATE JSONUPLANET
    jq '.[] | .UPname = "${UPNAME}" | .hash = "${HASH}" | .secret = "${ENCODING}"' ${JSONUPLANET} > ~/.zen/tmp/${MOATS}/${JSONUPLANET}.up

    ### PUT BACK IN TW
    tiddlywiki --load ${INDEX} \
                --import ~/.zen/tmp/${MOATS}/${JSONUPLANET}.up "application/json" \
                --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "newindex.html" "text/plain"

    if [[ -s ~/.zen/tmp/${MOATS}/newindex.html ]]; then

        [[ $(diff ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} ) ]] \
            && mv ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} \
            && echo "===> Mise à jour ${INDEX}"

    else
        echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/${MOATS}/newindex.html"
        echo "XXXXXXXXXXXXXXXXXXXXXXX"
    fi



done < ~/.zen/tmp/${MOATS}/inlineuplanets.json



exit 0
