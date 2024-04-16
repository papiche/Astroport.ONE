#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

## IT MAKES WISH OF NEW PRIVATE UPLANET
## IT MAKES $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key
## Then used to create an private IPFS swarm

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

CURRENT=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)

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

PLAYERPUB=$(cat $HOME/.zen/game/players/${PLAYER}/secret.dunikey | grep pub | cut -d ' ' -f 2)
[[ "${PLAYERPUB}" == "" ]] && echo "FATAL ERROR PLAYER KEY MISSING" && exit 1

###################################################################
## tag[ForkUPlanetZERO] TW EXTRACTION
###################################################################
tiddlywiki  --load ${INDEX} \
    --output ~/.zen/tmp/${MOATS} \
    --render '.' 'G1ForkUPlanetZERO.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[ForkUPlanetZERO]]'

## KEEP ONLY ONE tag[ForkUPlanetZERO] WISH !
echo "PREPARE INLINE JSON : cat ~/.zen/tmp/${MOATS}/G1ForkUPlanetZERO.json | jq -rc .[]"
cat ~/.zen/tmp/${MOATS}/G1ForkUPlanetZERO.json \
        | jq -rc .[] | head -n 1 > ~/.zen/tmp/${MOATS}/ONEuplanet.json

JSONUPLANET="${HOME}/.zen/tmp/${MOATS}/ONEuplanet.json"

[[ ! -s ${JSONUPLANET} ]] \
    && echo "NO tag[ForkUPlanetZERO] for $PLAYER" && exit 0

UPNAME=$(cat ${JSONUPLANET} | jq -r ".title") # What name is given ?
[[ "${UPNAME}" == "null" ||  "${UPNAME}" == "" ]] \
    && echo "NO FORK UPLANET NAME .title MISSING" && exit 1

HASH=$(cat ${JSONUPLANET} | jq -r ".hash") ## What text hash it has ?
SECRET=$(cat ${JSONUPLANET} | jq -r ".secret") ## What is secret ?

CONTRACT=$(cat ${JSONUPLANET} | jq -r ".text") ## What contract is applying ?
[[ "${CONTRACT}" == "null" || "${CONTRACT}" == "" ]] && CONTRACT="☼☼☼☼☼ floating points ☼☼☼☼☼"
echo "- CONTRACT -------------------------------------"
echo "$CONTRACT"
echo "--------------------------------------"
AHAH=$(echo $CONTRACT | sha512sum | cut -d ' ' -f 1)

[[ $AHAH != $HASH ]] && echo " - WARNING - CONTRACT CHANGED - WARNING -"

## CHECK EXISTING ${UPNAME}.swarm.key
[[ ! -s $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key ]] \
    && MSG=$MSG" ${PLAYER}/.ipfs/${UPNAME}.swarm.key NOT FOUND" && ERR="NO LOCAL KEY"

## CREATE 32 octets swarm.key ( maximum individual Fork 7,922816251×10²⁸ )
echo -e '/key/swarm/psk/1.0.0/\n/base16/' > $HOME/.zen/tmp/${MOATS}/swarm.key
head -c 32 /dev/urandom | od -t x1 -A none - | tr -d '\n ' >> $HOME/.zen/tmp/${MOATS}/swarm.key
echo '' >> $HOME/.zen/tmp/${MOATS}/swarm.key

## EXTRACT CURRENT SECRET FROM JSONUPLANET
# which is PLAYER pub encrypted base16 of swarm.key
###################################################
OLD16=$(cat ${JSONUPLANET} | jq -r ".secret")

if [[ ${OLD16} == "" || ${OLD16} == "null" ]]; then

    echo "NO SECRET FOUND" \
    && echo "NEW SECRET SWARM.KEY GENERATION" \
    && cat $HOME/.zen/tmp/${MOATS}/swarm.key \
    && cp $HOME/.zen/tmp/${MOATS}/swarm.key $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
    && echo "------- KEY LOADED -----> ${PLAYER}/.ipfs/${UPNAME}.swarm.key"

    ## CREATE SUB WORLD... MONITOR TEXT

else
    ## DEBASE16
    echo "${OLD16}" | base16 -d \
            > ~/.zen/tmp/${MOATS}/swarmkey.crypted

    ## TRY TO DECODE with PLAYER secret.dunikey
    ${MY_PATH}/../tools/natools.py decrypt \
            -f pubsec \
            -k $HOME/.zen/game/players/${PLAYER}/secret.dunikey \
            -i ~/.zen/tmp/${MOATS}/swarmkey.crypted \
            -o ~/.zen/tmp/${MOATS}/swarmkey.decrypted

    [[ $(diff ~/.zen/tmp/${MOATS}/swarmkey.decrypted $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key) ]] \
        && echo " SWARM AND LOCAL KEY ARE DIFFERENT " && ERR="TW SWARM CHANGED"

    ## UPDATE PLAYER LOCAL SWARMKEY FROM VALUE FOUND IN HIS OWN WISH TIDDLER !
    [[ -s ~/.zen/tmp/${MOATS}/swarmkey.decrypted ]] \
            && cp ~/.zen/tmp/${MOATS}/swarmkey.decrypted \
                $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
            && echo "PLAYER LOCAL SWARMKEY UPDATED" \
            || echo "ERROR RELOADING SWARMKEY"
fi

#~ (RE)CREATE SECRET
${MY_PATH}/../tools/natools.py encrypt \
    -p ${PLAYERPUB} \
    -i $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
    -o $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key.enc
ENCODING=$(cat $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key.enc | base16)
rm $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key.enc
echo "==> base16 ${PLAYER} encrypted swarm.key"
echo "${SECRET}"
echo "${ENCODING}"

#################################################################
## MAKE SAME ENCODING FOR FRIENDS
friends=($(ls ~/.zen/game/players/${PLAYER}/FRIENDS | grep "@" 2>/dev/null))
for f in ${friends[@]};
do
    ## Extract FRIENDG1PUB from TW (Astroport Tiddler)
    ftw=${HOME}/.zen/game/players/${PLAYER}/FRIENDS/${f}/index.html
    tiddlywiki --load ${ftw} --output ~/.zen/tmp/${MOATS} --render '.' "${f}_Astroport.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
    FRIENDG1PUB=$(cat ~/.zen/tmp/${MOATS}/${f}_Astroport.json | jq -r .[].g1pub)
    ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/${f}_Astroport.json | jq -r .[].astroport)
    [[ ${ASTROPORT} != "/ipns/${IPFSNODEID}" ]] && echo "FOREIGN ASTROPORT=${ASTROPORT}" && foreign="YES"
    echo "$f : $FRIENDG1PUB"

    ASTROPORTS=("${ASTROPORTS[@]}" "${ATROPORT}")

    if [[ ${FRIENDG1PUB} && ${FRIENDG1PUB} != "null" ]]; then

        #~ CHECK IF ALREADY IN JSON
        echo "cat ${JSONUPLANET} | jq -r '.\"${f}\"'"
        FRIENDIN=$(cat ${JSONUPLANET} | jq -r '."${f}"')
        [[ "${FRIENDIN}" != "null" && "${FRIENDIN}" != "" ]] && echo "${FRIENDIN} OK" && continue

        #~ CREATE FRIENDG1PUB
        ${MY_PATH}/../tools/natools.py encrypt \
            -p ${FRIENDG1PUB} \
            -i $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
            -o $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.${f}.swarm.key.enc
        FENCODING=$(cat $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.${f}.swarm.key.enc | base16)
        rm $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.${f}.swarm.key.enc

        cat ${JSONUPLANET} | jq '. | ."_f_" = "_FENCODING_"' > ~/.zen/tmp/${MOATS}/json.up \
            && sed -i 's/_f_/'"$f"'/g; s/_FENCODING_/'"$FENCODING"'/g' ~/.zen/tmp/${MOATS}/json.up \
            && mv ~/.zen/tmp/${MOATS}/json.up ${JSONUPLANET}

    else
        echo "- FATAL ERROR - Friend TW ${ftw} is broken !!"
        continue
    fi

    ZENSTATIONS=($(echo "${ASTROPORTS[@]}" | tr ' ' '\n' | sort -u))
    ## CHECK IF FRIEND HAVE THE SAME ${UPNAME} tiddler
    if [[ ${foreign} == "YES" ]]; then

        ## SEARCH FOR ${UPNAME} tiddler IN FRIEND TW
        tiddlywiki --load ${ftw} --output ~/.zen/tmp/${MOATS} --render '.' "${f}_${UPNAME}.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${UPNAME}"
        cat ~/.zen/tmp/${MOATS}/${f}_${UPNAME}.json | jq -r '[]."'${PLAYER}'"'

        ## CONTROL SWARMKEY DECODING (must be similar to our)

        ## IPFSNODEID IS FORKING TO NEW UPLANET
        if [[ ${#ZENSTATIONS[@]} -gt 5 ]]; then
            echo "UPlanet.ZERO WARPING... Activating ${UPNAME}"

        fi

    fi

done


echo "<<< MY FRIENDS ARE LOCATED IN ${#ZENSTATIONS[@]} FOREIGN ASTROPORT >>>"

## UPDATE JSONUPLANET
cat ${JSONUPLANET} | jq '. | ."UPname" = "_UPNAME_"' > ~/.zen/tmp/${MOATS}/json.up \
    && sed -i 's/_UPNAME_/'"$UPNAME"'/g' ~/.zen/tmp/${MOATS}/json.up \
    && mv ~/.zen/tmp/${MOATS}/json.up ${JSONUPLANET}
cat ${JSONUPLANET} | jq '. | ."hash" = "_HASH_"' > ~/.zen/tmp/${MOATS}/json.up \
    && sed -i 's/_HASH_/'"$AHAH"'/g' ~/.zen/tmp/${MOATS}/json.up \
    && mv ~/.zen/tmp/${MOATS}/json.up ${JSONUPLANET}
cat ${JSONUPLANET} | jq '. | ."secret" = "_SECRET_"' > ~/.zen/tmp/${MOATS}/json.up \
    && sed -i 's/_SECRET_/'"$ENCODING"'/g' ~/.zen/tmp/${MOATS}/json.up \
    && mv ~/.zen/tmp/${MOATS}/json.up ${JSONUPLANET}

### PUT BACK IN TW
tiddlywiki --load ${INDEX} \
            --import ${JSONUPLANET} "application/json" \
            --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "newindex.html" "text/plain"

if [[ -s ~/.zen/tmp/${MOATS}/newindex.html ]]; then

    [[ $(diff ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} ) ]] \
        && mv ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} \
        && echo "===> Mise à jour ${INDEX}"

    cat ${JSONUPLANET} | jq

else
    echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/${MOATS}/newindex.html"
    echo "XXXXXXXXXXXXXXXXXXXXXXX"
fi

rm -Rf ~/.zen/tmp/${MOATS}

exit 0
