#!/bin/bash
########################################################################
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/../tools/my.sh"

## IT SEARCH FOR CURRENT TW ForkUPlanetZERO tag
## IT MAKES $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key
## IT CHECKS FOR SAME UPNAME WISH IN FRIENDS TW
#~ echo "(✜‿‿✜) CURRENT Fork UPlanet
#~ This program makes Player generate or join a private IPFS swarm
#~ All friends with the same wish will share the SECRET
#~ then any can activate a new ipfs daemon connected to that private ZONE
## TIDDLER can contain parameters for UPlanet activation

echo "$ME RUNNING"

CURRENT=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)

########################################################################
[[ ! ${INDEX} ]] && INDEX="$HOME/.zen/game/players/.current/ipfs/moa/index.html"
[[ ! -s ${INDEX} ]] && echo "ERROR - Please provide path to source TW index.html" && exit 1
[[ ! -s ${INDEX} ]] && echo "ERROR - Fichier TW absent. ${INDEX}" && exit 1
ORIGININDEX=${INDEX}

[[ ! ${PLAYER} ]] && PLAYER="$(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
[[ ! ${PLAYER} ]] && echo "ERROR - Please provide PLAYER" && exit 1

ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
[[ ! ${ASTRONAUTENS} ]] && echo "ERROR - Clef IPNS ${PLAYER} introuvable!"  && exit 1

G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub)
[[ ! $G1PUB ]] && echo "ERROR - G1PUB ${PLAYER} VIDE"  && exit 1

[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "${PLAYER} ${INDEX} ${ASTRONAUTENS} ${G1PUB} "
mkdir -p $HOME/.zen/tmp/${MOATS}

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

AHAH=$(echo $CONTRACT | sha512sum | cut -d ' ' -f 1)
echo "%%% CONTRACT HASH %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "$AHAH"
echo "$HASH"
[[ $AHAH != $HASH ]] && echo " - WARNING - CONTRACT CHANGED - WARNING -"

## CHECK EXISTING ${UPNAME}.swarm.key
[[ ! -s $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key ]] \
    && MSG=$MSG" ${PLAYER}/.ipfs/${UPNAME}.swarm.key NOT FOUND" && ERR="NO LOCAL KEY"

## CREATE 32 octets swarm.key ( maximum individual Fork : octal 8^32 = decimal 7,922816251×10^28 )
echo -e '/key/swarm/psk/1.0.0/\n/base16/' > $HOME/.zen/tmp/${MOATS}/swarm.key
head -c 32 /dev/urandom | od -t x1 -A none - | tr -d '\n ' >> $HOME/.zen/tmp/${MOATS}/swarm.key
echo '' >> $HOME/.zen/tmp/${MOATS}/swarm.key

## EXTRACT CURRENT SECRET FROM JSONUPLANET
# which is PLAYER pub encrypted base16 of swarm.key
###################################################
## check if we have a player slot with cyphered key
IN16=$(cat ${JSONUPLANET} | jq -r '."${PLAYER}"')
## secret is only decrypted by wish source player
[[ ${IN16} == "" || ${IN16} == "null" ]] \
    && IN16=$(cat ${JSONUPLANET} | jq -r ".secret") && echo "get IN16 from secret field"

if [[ ${IN16} == "" || ${IN16} == "null" ]]; then

    echo "NO SECRET FOUND" \
    && echo ">> 🔑 ${UPNAME} SECRET SWARM.KEY GENERATION 🔑" \
    && cat $HOME/.zen/tmp/${MOATS}/swarm.key \
    && cp $HOME/.zen/tmp/${MOATS}/swarm.key $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
    && echo "------- KEY LOADED -----> ${PLAYER}/.ipfs/${UPNAME}.swarm.key"

    ## THIS IS A PRIMAL TIDDLER

else
    echo "VERIFICATION ${IN16}"
    ## DEBASE16
    echo "${IN16}" | base16 -d \
            > ~/.zen/tmp/${MOATS}/swarmkey.crypted

    echo ">> natools.py decrypt "
    ## DECODING with PLAYER secret.dunikey
    ${MY_PATH}/../tools/natools.py decrypt \
            -f pubsec \
            -k $HOME/.zen/game/players/${PLAYER}/secret.dunikey \
            -i ~/.zen/tmp/${MOATS}/swarmkey.crypted \
            -o ~/.zen/tmp/${MOATS}/swarmkey.decrypted

    echo ">> comparing decrypted key"
    ## CHEK KEY WITH ACTUAL ONE
    [[ $(diff ~/.zen/tmp/${MOATS}/swarmkey.decrypted $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key) ]] \
        && echo "- 📸 WARNING 📸 - UPDATING ${UPNAME}.swarm.key ..." && ERR="TW SWARM CHANGED"

    ## UPDATE PLAYER LOCAL SWARMKEY FROM VALUE FOUND IN HIS OWN WISH TIDDLER !
    [[ -s ~/.zen/tmp/${MOATS}/swarmkey.decrypted ]] \
            && cp ~/.zen/tmp/${MOATS}/swarmkey.decrypted \
                $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
            && echo "PLAYER ${UPNAME}.swarm.key IS VALID" \
            || { echo "ERROR PLAYER ${UPNAME}.swarm.key IS NOT VALID"; exit 1; }

fi

#~ (RE)CREATE SECRET
${MY_PATH}/../tools/natools.py encrypt \
    -p ${PLAYERPUB} \
    -i $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
    -o $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key.enc
ENCODING=$(cat $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key.enc | base16)
rm $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key.enc
echo "==> base16 ${PLAYER} encrypted swarm.key is secret"
#~ echo "${SECRET}"
#~ echo "${ENCODING}"

#################################################################
## MAKE KEY ENCODING FOR FRIENDS
friends=($(ls ~/.zen/game/players/${PLAYER}/FRIENDS | grep "@" 2>/dev/null))
for f in ${friends[@]};
do
    ## Extract FRIENDG1PUB from TW (Astroport Tiddler)
    ftw=${HOME}/.zen/game/players/${PLAYER}/FRIENDS/${f}/index.html
    [[ ! -s ${ftw} ]] && echo "FRIENDS/${f} : $(cat "$HOME/.zen/game/players/${PLAYER}/FRIENDS/${f}")" && continue

    ## Check if "f=PRESIDENT" in my friend "email" TW
    tiddlywiki --load ${ftw} --output ~/.zen/tmp/${MOATS} --render '.' "${f}_.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${f}"
    PRESIDENT=$(cat ~/.zen/tmp/${MOATS}/${f}_.json | jq -r .[].president)
    [[ ${PRESIDENT} != ${f} ]] && echo "${f} Astroport is run by ${PRESIDENT}... No fork..." && continue

    ## Check if Astroport is different from my node
    tiddlywiki --load ${ftw} --output ~/.zen/tmp/${MOATS} --render '.' "${f}_Astroport.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
    FRIENDG1PUB=$(cat ~/.zen/tmp/${MOATS}/${f}_Astroport.json | jq -r .[].g1pub)
    echo "___________________"
    echo "$f : $FRIENDG1PUB"

    ASTROPORT=$(cat ~/.zen/tmp/${MOATS}/${f}_Astroport.json | jq -r .[].astroport)
    [[ ${ASTROPORT} != "/ipns/${IPFSNODEID}" ]] \
        && echo "FOREIGN ASTROPORT=${ASTROPORT}" \
        && foreign="YES" \
        && ASTROPORTS=("${ASTROPORTS[@]}" "${ASTROPORT}")

    if [[ ${FRIENDG1PUB} && ${FRIENDG1PUB} != "null" ]]; then

        #~ CHECK IF player ALREADY IN JSON
        echo "cat ${JSONUPLANET} | jq -r '.\"${f}\"'"
        FRIENDIN=$(cat ${JSONUPLANET} | jq -r '."${f}"')
        [[ "${FRIENDIN}" != "null" && "${FRIENDIN}" != "" ]] \
            && echo "${FRIENDIN} ALREADY IN FORK ${UPNAME} TIDDLER." \
            && continue

        echo "#~ Create FRIENDG1PUB encrypted version of swarm.key"
        ${MY_PATH}/../tools/natools.py encrypt \
            -p ${FRIENDG1PUB} \
            -i $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key \
            -o $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.${f}.swarm.key.enc
        FENCODING=$(cat $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.${f}.swarm.key.enc | base16)
        rm $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.${f}.swarm.key.enc

        echo "## Addd email=crypt(swarmkey) field to ${JSONUPLANET} tiddler."
        cat ${JSONUPLANET} | jq '. | ."_f_" = "_FENCODING_"' > ~/.zen/tmp/${MOATS}/json.up \
            && sed -i 's/_f_/'"$f"'/g; s/_FENCODING_/'"$FENCODING"'/g' ~/.zen/tmp/${MOATS}/json.up \
            && mv ~/.zen/tmp/${MOATS}/json.up ${JSONUPLANET}

    else
        echo "- FATAL ERROR - Friend TW ${ftw} is broken !!"
        continue

    fi

    if [[ ${foreign} == "YES" ]]; then
    echo "## Check if friend have an ${UPNAME} tiddler and that secret is the same"
        ## SEARCH FOR ${UPNAME} tiddler IN FRIEND TW
        tiddlywiki --load ${ftw} --output ~/.zen/tmp/${MOATS} \
        --render '.' "${f}_${UPNAME}.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${UPNAME}"

        ## CONTROL SWARMKEY DECODING (must be equal)
        OUT16=$(cat ~/.zen/tmp/${MOATS}/${f}_${UPNAME}.json | jq -r '[]."'${PLAYER}'"')
        echo "${IN16}"
        echo "${OUT16}"

        [[ ${IN16} == ${OUT16} ]] \
            && echo "OK STATIONS +1 : TW sharing the same wish. " \
            && OKSTATIONS=("${OKSTATIONS[@]}" "${ASTROPORT}") \
            || echo "NO GOOD! TW not synchronized."

        foreign=""
    fi

done

ZENSTATIONS=($(echo "${OKSTATIONS[@]}" | tr ' ' '\n' | sort -u)) ## REMOVE DUPLICATE
echo "<<< My Friends are located in ${#ASTROPORTS[@]} ASTROPORT(s) : ${#ZENSTATIONS[@]} are OK >>>"

## IPFSNODEID IS FORKING TO NEW UPLANET
if [[ ${#ZENSTATIONS[@]} -ge 3 ]]; then
    echo "UPlanet.ZERO /// ENTERING WARPING ZONE /// ${UPNAME} ACTIVATION"
    ## HERE each PLAYER share the same wish
    # only secret field is "!=" in each, as it is self encoding key
    # we must find our email="The same" in each friends TW
    ## CONTROL
    # round looking in friends TW... Can be done before...

    ## APPLY ?!
    ##################################################
    # Let's engage Astroport.ONE code mutation...
    # tools/my.sh
    SECRETNAME=$(cat $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key | tail -n 1)
    echo "SECRETNAME=$SECRETNAME"

#######################################################################
    echo "# UPlanet Swarm Bootstrap Stations #
# https://ipfs.${UPNAME} ipfs.${UPNAME}
#################################################################
" > ~/.zen/tmp/${MOATS}/new_straps.list

    # Prepare "new_straps.list" from WAN only
    for station in ${ZENSTATIONS[@]}; do
        [[ ! -s ~/.zen/tmp/swarm/${station}/myIPFS.txt ]] \
            && echo "Missing swarm/${station}/myIPFS.txt" \
            && continue

        bootnode=$(cat ~/.zen/tmp/swarm/${station}/myIPFS.txt)
        echo "${bootnode}"
        iptype=$(echo ${bootnode} | cut -d '/' -f 2)
        nodeip=$(echo ${bootnode} | cut -d '/' -f 3)
        isnodeipLAN=$(echo $nodeip | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
        echo " ${iptype} address :: ${nodeip} (= ${isnodeipLAN})"
        [[ ${nodeip} == ${isnodeipLAN} ]] && echo "LAN NODE... no good for bootstrap" && continue

        echo "### OK adding to new_straps.list"
        echo "${bootnode}" >> ~/.zen/tmp/${MOATS}/new_straps.list

    done

## INTRODUCE NEW BOOSTRAP LIST
cp ~/.zen/tmp/${MOATS}/new_straps.list ~/.zen/MY_boostrap_nodes.txt
#######################################################################

    # make G1PalPay refuse not from "UPlanet Master Key" primal TX
    # STABLE COIN : activate OpenCollective sync
    # and adapt 20H12.process.sh

    ## UPNAME = domain.tld
    # PACTHING Astroport.ONE code
    grep -rl --exclude-dir='.git*' 'copylaradio.com' ./ | xargs sed -i "s~copylaradio.com~${UPNAME}~g"


    # now we add key into ~/.ipfs/swarm.key
    #~ cp $HOME/.zen/game/players/${PLAYER}/.ipfs/${UPNAME}.swarm.key ~/.ipfs/swarm.key
    # it will make IPFSNODEID restarting in private mode

fi

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

jq '.[] + {created: $MOATS, modified: $MOATS}' --arg MOATS "$MOATS" "${JSONUPLANET}" > ~/.zen/tmp/${MOATS}/json.up \
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
