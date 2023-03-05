#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/../tools/my.sh"

################################################################################
# Inspect game wishes, refresh latest IPNS version
# SubProcess Backup and chain
PLAYER="$1" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! ${PLAYER} ]] && echo "Please provide IPFS publish key" && exit 1

MOATS="$2"

    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null)
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "WARNING No ${PLAYER} in keystore --" && ASTRONAUTENS=$ASTRONS
    [[ ! $ASTRONAUTENS ]] && echo "Missing ${PLAYER} IPNS KEY - CONTINUE --" && exit 1

INDEX="$3"
[[ ! $INDEX ]] && INDEX="$HOME/.zen/game/players/${PLAYER}/ipfs/moa/index.html"
[[ ! -s $INDEX ]] && echo "TW ${PLAYER} manquant" && exit 1

mkdir -p ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
###############################
## EXTRACT G1Voeu from PLAYER TW
echo "Exporting ${PLAYER} TW [tag[G1Voeu]]"
rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json
tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu --render '.' "${PLAYER}.g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'

[[ ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json ]] && echo "AUCUN G1VOEU - EXIT -" && exit 0

cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt
echo $(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt | wc -l)" VOEUX : ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt "

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

## GET VoeuTitle LIST
while read WISH
do
    [[ ${WISH} == "" || ${WISH} == "null" ]] && echo "BLURP. EMPTY WISH" && continue
    echo "==============================="
    echo "G1Voeu ${WISH}"
    ## Get ${WISHNAME}
    WISHNAME=$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .title')
    [[ ! ${WISHNAME} ]] && echo "WISH sans NOM - CONTINUE -" && continue

    VOEUNS=$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json  | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .wishns')
    VOEUKEY=$(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json  | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .wish')

    ICHECK=$(ipfs key list -l | grep -w "$VOEUKEY" | cut -d ' ' -f 1 )

    if [[ ! $ICHECK ]]; then
          echo "MISSING $VOEUKEY (new astronaut here) - RESET G1Voeu to voeu"
           sed -i "s~G1Voeu~voeu~g" $INDEX
           continue
    else
        VCOINS=$(~/.zen/Astroport.ONE/tools/timeout.sh -t 20 ${MY_PATH}/../tools/jaklis/jaklis.py balance -p ${VOEUKEY})
        [[ $VCOINS == "" || $VCOINS == "null" ]] \
        && echo "ERROR G1WALLET" \
        || echo "WISH G1WALLET = $VCOINS G1"
    fi

    echo "************************************************************"
    echo "Hop, UNE JUNE pour le Voeu $WISHNAME"
    echo $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey pay -a 1 -p $VOEUKEY -c \'"ASTRO:$VOEUNS G1Voeu $WISHNAME"\' -m
    echo "************************************************************"
    echo "************************************************************"

    $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey pay -a 1 -p $VOEUKEY -c "ASTRO:$VOEUXNS G1Voeu $WISHNAME" -m
    [[ ! $? == 0 ]] \
    && echo "POOOOOOOOOOOOOOOOOOOORRRRRR GUY. YOU CANNOT PAY A G1 FOR A YOUR WISH"

    ## RUNNING WISH REFRESH
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/${WISH}

##########################################################################
##########################################################################
    ## RUN SPECIFIC G1Voeu ASTROBOT PROGRAM (like G1CopierYoutube.sh)
    if [[ -s $MY_PATH/G1${WISHNAME}.sh ]]; then
        echo "........................ Astrobot G1${WISHNAME}.sh program found !"
        echo "________________________________  Running it *****"
        ${MY_PATH}/G1${WISHNAME}.sh "$INDEX" "${PLAYER}" "$MOATS"
        echo "________________________________   Finished ******"
    else
        echo "......................... G1${WISHNAME} REGULAR Ŋ1 RSS JSON"
    fi
##########################################################################
##########################################################################

    ## RUN TW Ŋ1 search & copy treatment
    echo "*********************************"
        ##################################
        ## Search for [tag[G1${WISHNAME}]] in all Friends TW.
        ## Copy tiddlers ...
        ##################################
        echo "NOW SEARCH Ŋ1 FRIENDS TW's FOR tag=G1${WISHNAME}"
        echo "ls ~/.zen/game/players/${PLAYER}/FRIENDS/*/index.html"
        echo "*********************************"
        ## Search in Local World (NB! G1Voeu TW copied by Connect_PLAYER_To_Gchange.sh)
        FINDEX=($( ls $HOME/.zen/game/players/${PLAYER}/FRIENDS/*/index.html))

        for FRIENDTW in ${FINDEX[@]};
        do
            [[ ! -s $FRIENDTW ]] && echo "$FRIENDTW VIDE (AMI SANS TW)" && continue
            APLAYER=$(ls $FRIENDTW | cut -d '/' -f 7)

            rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/${APLAYER}.tiddlers.json ## CLEANING OLD FORMAT (TODO REMOVE)

            rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.json
            echo "TRY EXPORT [tag[G1${WISHNAME}]]  FROM $FRIENDTW"
            tiddlywiki --load $FRIENDTW \
                                --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME} --render '.' _${APLAYER}'.tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'${WISHNAME}']!tag[G1Voeu]]'
            [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.json ]] && echo "NO ${WISHNAME} - CONTINUE -" && continue
            [[ $(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.json) == "[]" ]] && echo "EMPTY ${WISHNAME} - CONTINUE -" && continue

            echo "## TIDDLERS FOUND ;) MIAM >>> (◕‿‿◕) <<<"
            echo  ">>> G1FRIEND § $myIPFS/$VOEUNS/_${APLAYER}.tiddlers.json ${WISHNAME}"

        done
        ##################################
        ## TODO JOIN WITH FRIENDS JSONS
        ################################## MOA MAINTENANT
        echo  ">>> EXPORT [tag[G1${WISHNAME}]!tag[G1Voeu]] § $myIPFSGW/$VOEUNS/_${PLAYER}.tiddlers.json"
        tiddlywiki --load $INDEX \
                 --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME} \
                 --render '.'_ ${PLAYER}'.tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'${WISHNAME}']!tag[G1Voeu]]'

        ##################################
        ## MAKE EARTH MAP TILES
        echo
        echo "DEBUG : s~_LIBRA_~$(myIpfsGw)~g s~_G1VOEU_~${WISHNAME}~g s~_PLAYER_~${PLAYER}~g s~_VOEUNS_~${VOEUNS}~g s~_ASTRONAUTENS_~${ASTRONAUTENS}~g"
        echo
        ##################################
        cat $MY_PATH/../www/PasseportTerre/index.html \
        | sed -e "s~_LIBRA_~$(myIpfsGw)~g" \
                    -e "s~_G1VOEU_~${WISHNAME}~g" \
                    -e "s~_PLAYER_~${PLAYER}~g" \
                    -e "s~_VOEUNS_~${VOEUNS}~g" \
                    -e "s~_ASTRONAUTENS_~${ASTRONAUTENS}~g" \
        > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/index.html
                ### PREPARE WISHNAME index.html
        ##################################

        ### ADD TO IPFS
        echo "++WISH PUBLISHING++ ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/*"
        du -h ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/

        WISHFLUX=$(ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/* | tail -n 1)  # ADDING JSONS TO IPFS
        ipfs name publish -k $VOEUKEY /ipfs/$WISHFLUX   # PUBLISH $VOEUKEY

        ## MOVE INTO PLAYER AREA
        echo ">>> $VOEUKEY : Ŋ1 FLUX $(myIpfsGw)${VOEUNS}"
        echo "~/.zen/game/players/${PLAYER}/G1${WISHNAME}/${G1PUB}"

        mv -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/* ~/.zen/game/players/${PLAYER}/G1${WISHNAME}/${G1PUB}/

done < ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "TODO : REFRESH WORLD SAME WISH"
cat ~/.zen/game/world/$WISHNAME/*/.link 2>/dev/null


echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

############################################

exit 0
