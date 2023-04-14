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
    COINS=$(cat $HOME/.zen/tmp/coucou/${G1PUB}.COINS)
    ASTRONS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null)

    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep -w ${PLAYER} | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "WARNING No ${PLAYER} in keystore --" && ASTRONAUTENS=$ASTRONS
    [[ ! $ASTRONAUTENS ]] && echo "Missing ${PLAYER} IPNS KEY - CONTINUE --" && exit 1

INDEX="$3"
[[ ! $INDEX ]] && INDEX="$HOME/.zen/game/players/${PLAYER}/ipfs/moa/index.html"
[[ ! -s $INDEX ]] && echo "TW ${PLAYER} manquant" && exit 1

mkdir -p ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu

echo "%% $COINS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
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
          echo ">>> STATION MISSING $VOEUKEY - RESET ASTRONAUT WISHES DERIVATED KEYS -"
           sed -i "s~G1Voeu~voeu~g" $INDEX
           continue
    else
        VCOINS=$($MY_PATH/../tools/COINScheck.sh $VOEUKEY | tail -n 1)
        [[ $VCOINS == "" || $VCOINS == "null" ]] \
        && echo "G1WALLET NOT EXISTING YET : $VCOINS" \
        || echo "WISH G1WALLET = $VCOINS G1"
    fi

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

        ## PREPARE Ŋ1 WORLD MAP
        echo "var examples = {};
        examples['locations'] = function() {
        var locations = {
        " > ~/.zen/tmp/world.js
        floop=1

        for FRIENDTW in ${FINDEX[@]};
        do

            [[ ! -s $FRIENDTW ]] && echo "$floop / ${#FINDEX[@]} $FRIENDTW VIDE (AMI SANS TW)" && echo && ((floop++)) && continue

            ## GET FRIEND EMAIL = APLAYER
            tiddlywiki --load $FRIENDTW \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
            [[ ! -s ~/.zen/tmp/${MOATS}/MadeInZion.json ]] && echo "${PLAYER} MadeInZion : BAD TW (☓‿‿☓) " && continue

            APLAYER=$(cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r .[].player)

            rm -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.json
            echo "$floop / ${#FINDEX[@]} TRY EXPORT [tag[G1${WISHNAME}]]  FROM $APLAYER TW"
            tiddlywiki --load $FRIENDTW \
                                --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME} --render '.' _${APLAYER}'.tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'${WISHNAME}']!tag[G1Voeu]!sort[modified]limit[30]]'

            [[ ! -s ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.json ]] \
            && echo "NO ${WISHNAME} - CONTINUE -" \
            && echo && ((floop++)) && continue

            [[ $(cat ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.json) == "[]" ]] \
            && echo "EMPTY ${WISHNAME} - CONTINUE -" && echo && ((floop++)) && continue

            echo "## TIDDLERS FOUND ;) MIAM >>> (◕‿‿◕) <<<"
            echo  ">>> G1FRIEND § $myIPFS/$VOEUNS/_${APLAYER}.tiddlers.json ${WISHNAME}"

            tiddlywiki --load ${FRIENDTW} --output ~/.zen/tmp --render '.' "${APLAYER}.${WISHNAME}.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${WISHNAME}"
            WISHNS=$(cat ~/.zen/tmp/${APLAYER}.${WISHNAME}.json | jq -r '.[].wishns')
            [[ $WISHNS == "null" ]] && echo "NO WISHNS in ~/.zen/tmp/${APLAYER}.${WISHNAME}.json" && echo && ((floop++)) && continue
            echo ">>> ${myIPFS}${WISHNS}"

            echo "${floop}: {
              alpha: Math.random() * 2 * Math.PI,
              delta: Math.random() * 2 * Math.PI,
              name: '"${WISNAME} ${APLAYER}"',
              link: '"${myIPFS}${WISHNS}"'
            }
            ," >> ~/.zen/tmp/world.js

            ((floop++))
        done

        # REMOVE la dernière virgule
        sed -i '$ d' ~/.zen/tmp/world.js
        ##################################
        ## FINISH LOCATIONS
        echo "
        };
           \$('#sphere').earth3d({
            locationsElement: \$('#locations'),
            dragElement: \$('#locations'),
            locations: locations
          });
        };
        " >> ~/.zen/tmp/world.js

        cat ~/.zen/tmp/world.js
        IAMAP=$(ipfs add -qw ~/.zen/tmp/world.js | tail -n 1)
        echo "CREATING /ipfs/${IAMAP}/world.js"

        ##################################
        ## MAKE MY OWN JSON
        ################################## MOA MAINTENANT
        echo  "> EXPORT [tag[G1${WISHNAME}]!tag[G1Voeu]] § $myIPFSGW$VOEUNS/_${PLAYER}.tiddlers.json"
        tiddlywiki --load $INDEX \
                 --output ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME} \
                 --render '.' _${PLAYER}'.tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'${WISHNAME}']!tag[G1Voeu]!sort[modified]limit[30]]'

        ##################################
        ## MAKE EARTH MAP TILES
        echo
        # echo "DEBUG : s~_LIBRA_~$(myIpfsGw)~g s~_G1VOEU_~${WISHNAME}~g s~_PLAYER_~${PLAYER}~g s~_VOEUNS_~${VOEUNS}~g s~_ASTRONAUTENS_~${ASTRONAUTENS}~g"
        echo

        ##################################
        ## INSERT PLAYER G1 QRCODE : QRG1avatar.png
        QRLINK=$(ipfs add -q ~/.zen/game/players/${PLAYER}/voeux/${WISHNAME}/${VOEUKEY}/voeu.png | tail -n 1)
        [[ $QRLINK == "" ]] && QRLINK=$(ipfs add -q ~/.zen/game/players/${PLAYER}/QRG1avatar.png | tail -n 1)


        ################################## PasseportTerre/index.html
        cat $MY_PATH/../www/PasseportTerre/index.html \
        | sed -e "s~_LIBRA_~$(myIpfsGw)~g" \
                    -e "s~_G1VOEU_~${WISHNAME}~g" \
                    -e "s~_PLAYER_~${PLAYER}~g" \
                    -e "s~_____~${COINS}~g" \
                    -e "s~_G1PUB_~${G1PUB}~g" \
                    -e "s~_VOEUNS_~${VOEUNS}~g" \
                    -e "s~_ASTRONAUTENS_~${ASTRONAUTENS}~g" \
                    -e "s~http://astroport.localhost:1234~${myASTROPORT}~g" \
                    -e "s~QmYdWBx32dP14XcbXF7hhtDq7Uu6jFmDaRnuL5t7ARPYkW/index_fichiers/world.js~${IAMAP}/world.js~g" \
                    -e "s~_ASTRONAUTENS_~${ASTRONAUTENS}~g" \
                    -e "s~QmWUpjGFuF7NhpXgkrCmx8Tbu4xjcFpKhE7Bsvt6HeKYxu/g1ticket_qrcode.png~${QRLINK}~g" \
                    -e "s~http://127.0.0.1:8080~~g" \
        > ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/index.html
                ### PREPARE WISHNAME index.html
        ##################################

        ### ADD TO IPFS
        echo "++WISH PUBLISHING++ ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/*"
        ls ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/

        WISHFLUX=$(ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/* | tail -n 1)  # ADDING JSONS TO IPFS
        ipfs name publish -k $VOEUKEY /ipfs/$WISHFLUX   # PUBLISH $VOEUKEY

        echo "## ASK ${myASTROTUBE} $ASTRONAUTENS TO REFRESH"
        curl -m 120 -so ~/.zen/tmp/${WISHNAME}.astroindex.html "${myASTROTUBE}${VOEUNS}" &

        ## MOVE INTO PLAYER AREA
        echo ">>> ${PLAYER} G1${WISHNAME} Ŋ1 FLUX $(myIpfsGw)${VOEUNS}"
        echo "WALLET ${VOEUKEY} FOUNDED by ${G1PUB}"

        #~ echo "************************************************************"
        #~ echo "Hop, 0.1 JUNE pour le Voeu $WISHNAME"
        #~ echo $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey pay -a 0.1 -p $VOEUKEY -c \'"ASTRO:$VOEUNS G1Voeu $WISHNAME"\' -m
        #~ echo "************************************************************"
        #~ echo "************************************************************"

        #~ $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey pay -a 0.1 -p $VOEUKEY -c "ASTRO:$VOEUXNS G1Voeu $WISHNAME" -m
        #~ [[ ! $? == 0 ]] \
        #~ && echo "POOOOOOOOOOOOOOOOOOOORRRRRR GUY. YOU CANNOT PAY A G1 FOR YOUR WISH"

        cp -f ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${WISHNAME}/* ~/.zen/game/players/${PLAYER}/G1${WISHNAME}/${G1PUB}/ 2>/dev/null

done < ~/.zen/tmp/${IPFSNODEID}/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "TODO : REFRESH WORLD SAME WISH"
cat ~/.zen/game/world/$WISHNAME/*/.link 2>/dev/null


echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

############################################

exit 0
