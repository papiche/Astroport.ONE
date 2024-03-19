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
# ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/*
# ~/.zen/game/players/${PLAYER}/G1${WISHNAME}/${G1PUB}/*
# _PLAYER.json

# change SWARM memory
### # ~/.zen/tmp/${IPFSNODEID}/WISH/${WISHNAME}/${PLAYER}/*

PLAYER="$1" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! ${PLAYER} ]] && echo "Please provide PLAYER publish key" && exit 1

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

mkdir -p ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu

###############################
####### NEED G1 / ZEN TO RUN
    [[ ${COINS} == "null" || ${COINS} == "" ]] \
    && echo ">>> ${COINS} : DESACTIVATED - NEED G1 TO REFRESH WISH - EXIT - " \
    && exit 0
echo "%% ${COINS} %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

[[ $(echo "$COINS < 2" | bc -l) -eq 1 ]] && echo ">>> ${COINS} ONLY : 1 G1 + 10 ZEN NEEDED TO CONTINUE" && exit 0

###############################
## EXTRACT G1Voeu from PLAYER TW
echo "Exporting ${PLAYER} TW [tag[G1Voeu]]"
rm -f ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json
tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu --render '.' "${PLAYER}.g1voeu.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'

[[ ! -s ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json ]] \
    && echo "AUCUN G1VOEU - EXIT -" && exit 0

cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json | jq -r 'map(select(.wish != null)) | .[].wish' > ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt
wishnumbers=$(cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt | wc -l)
echo "${wishnumbers} VOEUX : ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt "

## ${PLAYER}.g1wishes.txt contains all TW G1PUB : IPNS key name
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

## GET VoeuTitle LIST
while read WISH
do
    [[ ${WISH} == "" || ${WISH} == "null" ]] && echo "BLURP. EMPTY WISH" && continue
    echo "==============================="
    ## Get ${WISHNAME}
    WISHNAME=$(cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .title')
    [[ ! ${WISHNAME} ]] && echo "WISH sans NOM - CONTINUE -" && continue
    echo "G1Voeu ${WISH} (${WISHNAME})"

    IPNS_VOEUNS=$(cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json  | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .wishns')
    VOEUKEY=$(cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1voeu.json  | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .wish')

    ICHECK=$(ipfs key list -l | grep -w "$VOEUKEY" | cut -d ' ' -f 1 )

    if [[ ! $ICHECK ]]; then
          echo ">>> STATION MISSING $VOEUKEY - RESET ASTRONAUT WISHES - DERIVATED KEYS RECREATE -"
           sed -i "s~G1Voeu~voeu~g" $INDEX
           break
    else
        VCOINS=$($MY_PATH/../tools/COINScheck.sh $VOEUKEY | tail -n 1)
        [[ $VCOINS == "" || $VCOINS == "null" ]] \
        && echo "G1WALLET NOT EXISTING YET : $VCOINS" \
        || echo "WISH G1WALLET = $VCOINS G1"
    fi

    ## RUNNING WISH REFRESH : PLAYER CACHE
    mkdir -p ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/${WISH}

##########################################################################
##########################################################################
    ## RUN SPECIFIC G1Voeu ASTROBOT PROGRAM (like G1CopierYoutube.sh)
    if [[ -s $MY_PATH/../ASTROBOT/G1${WISHNAME}.sh ]]; then
        echo "........................ Astrobot G1${WISHNAME}.sh PROGRAM FOUND !"
        echo "________________________________  Running it *****"
        ${MY_PATH}/../ASTROBOT/G1${WISHNAME}.sh "$INDEX" "${PLAYER}" "$MOATS"
        echo "________________________________   Finished ******"
    else
        echo "......................... NO G1${WISHNAME} PROGRAM... "
    fi
##########################################################################
##########################################################################

###########################################################################################
        ##################################
        ## MAKE MY OWN EXTRACTION : [tag[G1'${WISHNAME}']!tag[G1Voeu]!sort[modified]limit[30]]
        ################################## MOA MAINTENANT
        echo  "> EXPORT [tag[G1${WISHNAME}]!tag[G1Voeu]] § $myIPFSGW${IPNS_VOEUNS}/_${PLAYER}.tiddlers.rss.json"
        tiddlywiki --load ${INDEX} \
                 --output ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME} \
                 --render '.' _${PLAYER}'.tiddlers.rss.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'${WISHNAME}']!tag[G1Voeu]!sort[modified]limit[30]]'


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

            [[ ! -s ${FRIENDTW} ]] && echo "$floop / ${#FINDEX[@]} ${FRIENDTW} VIDE (AMI SANS TW)" && echo && ((floop++)) && continue

            ## GET FRIEND EMAIL = APLAYER (VERIFY TW IS OK)
            tiddlywiki --load ${FRIENDTW} \
                --output ~/.zen/tmp/${MOATS} \
                --render '.' 'MadeInZion.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
            [[ ! -s ~/.zen/tmp/${MOATS}/MadeInZion.json ]] && echo "${PLAYER} MadeInZion : BAD TW (☓‿‿☓) " && continue

            APLAYER=$(cat ~/.zen/tmp/${MOATS}/MadeInZion.json | jq -r .[].player)

            ## EXPORT LAST 30 DAYS G1WishName in _${APLAYER}.tiddlers.rss.json
            rm -f ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.rss.json
            echo "$floop / ${#FINDEX[@]} TRY EXPORT [tag[G1${WISHNAME}]]  FROM $APLAYER TW"
            tiddlywiki --load ${FRIENDTW} \
                                --output ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME} \
                                --render '.' _${APLAYER}'.tiddlers.rss.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'${WISHNAME}']!tag[G1Voeu]!sort[modified]limit[30]]'

            [[ ! -s ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.rss.json ]] \
            && echo "NO ${WISHNAME} - CONTINUE -" \
            && echo && ((floop++)) && continue

            [[ $(cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.rss.json) == "[]" ]] \
            && echo "EMPTY ${WISHNAME} - CONTINUE -" && echo && ((floop++)) \
            && rm ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.rss.json \
            && continue

#####################################################
            echo "## TIDDLERS FOUND ;) MIAM >>> (◕‿‿◕) <<<"
            ##############################
            ## WRITE FRIEND SAME WISH TIDDLERS IN PLAYER TW       ########
            ##############################
            ## SIGN Tiddlers
            cat ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.rss.json \
                | sed "s~${PLAYER}~~g" \
                | sed "s~${APLAYER}~${APLAYER} ${PLAYER}~g" \
                    > ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.signed.json

            ## ADD TO TW
            tiddlywiki --load ${INDEX} \
                        --import ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/_${APLAYER}.tiddlers.signed.json "application/json" \
                        --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "newindex.html" "text/plain"
            ## CHECK IT IS OK
            [[ -s ~/.zen/tmp/${MOATS}/newindex.html ]] \
                && cp ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} \
                && rm ~/.zen/tmp/${MOATS}/newindex.html

            ##############################
            echo  ">>> G1FRIEND § $myIPFS${IPNS_VOEUNS}/_${APLAYER}.tiddlers.rss.json ${WISHNAME}"

            # Extract Origin G1Voeu Tiddler
            tiddlywiki --load ${FRIENDTW} --output ~/.zen/tmp --render '.' "${APLAYER}.${WISHNAME}.json" 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' "${WISHNAME}"
            FWISHNS=$(cat ~/.zen/tmp/${APLAYER}.${WISHNAME}.json | jq -r '.[].wishns')
#            FWISHPROG=$(cat ~/.zen/tmp/${APLAYER}.${WISHNAME}.json | jq -r '.[].text')
# TIDDLER COULD CONTAIN #!/bin/bash PROGRAM !!!
            [[ $FWISHNS == "null" ]] && echo "NO FWISHNS in ~/.zen/tmp/${APLAYER}.${WISHNAME}.json" && echo && ((floop++)) && continue
            echo ">>> ${myIPFS}${FWISHNS}"

###########################################################################################
            ## ADD WISH ON THE WORLD MAP (TODO: EXTRACT REAL GPS)
            echo "${floop}: {
              alpha: Math.random() * 2 * Math.PI,
              delta: Math.random() * 2 * Math.PI,
              name: '"${WISNAME} ${APLAYER}"',
              link: '"${myIPFS}${FWISHNS}"'
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

        IAMAP=$(ipfs add -qw ~/.zen/tmp/world.js | tail -n 1)
        echo "JSON WISH WORLD READY /ipfs/${IAMAP}/world.js"
        ##################################
        ## PREPARE PLAYER G1 QRCODE : QRG1avatar.png
        [[ -s ~/.zen/game/players/${PLAYER}/voeux/${WISHNAME}/${VOEUKEY}/voeu.png ]] \
        && QRLINK=$(ipfs add -q ~/.zen/game/players/${PLAYER}/voeux/${WISHNAME}/${VOEUKEY}/voeu.png | tail -n 1)
        [[ $QRLINK == "" ]] && QRLINK=$(ipfs add -q ~/.zen/game/players/${PLAYER}/QRG1avatar.png | tail -n 1)

        ### APPLY FOR ${WISHNAME} APP MODEL : make index.html
        ################################## ${WISHNAME}/index.html
        if [[ -s ${MY_PATH}/../WWW/${WISHNAME}/index.html ]]; then

        cat ${MY_PATH}/../WWW/${WISHNAME}/index.html \
        | sed -e "s~_LIBRA_~$(myIpfsGw)~g" \
                    -e "s~_G1VOEU_~${WISHNAME}~g" \
                    -e "s~_PLAYER_~${PLAYER}~g" \
                    -e "s~_____~${COINS}~g" \
                    -e "s~_G1PUB_~${G1PUB}~g" \
                    -e "s~_VOEUNS_~${IPNS_VOEUNS}~g" \
                    -e "s~_ASTRONAUTENS_~${ASTRONAUTENS}~g" \
                    -e "s~http://astroport.localhost:1234~${myASTROPORT}~g" \
                    -e "s~QmYdWBx32dP14XcbXF7hhtDq7Uu6jFmDaRnuL5t7ARPYkW/index_fichiers/world.js~${IAMAP}/world.js~g" \
                    -e "s~_ASTRONAUTENS_~${ASTRONAUTENS}~g" \
                    -e "s~QmWUpjGFuF7NhpXgkrCmx8Tbu4xjcFpKhE7Bsvt6HeKYxu/g1ticket_qrcode.png~${QRLINK}~g" \
                    -e "s~http://127.0.0.1:8080~~g" \
        > ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/index.html

        fi
                ### PREPARE WISHNAME index.html - CREATE YOUR OWN DAPP -
        ##################################

###########################################################################################
    ## N1Program are run through PLAYER G1PalPay RUNTIME
        ## CAN BE EXTENDED WITH DATA POST TREATMENT PROGRAMS
        ## RUN Z1Program ASTROBOT PROGRAM
        #~ if [[ -s $MY_PATH/../ASTROBOT/Z1${WISHNAME}.sh ]]; then
            #~ echo "........................ Astrobot Z1${WISHNAME}.sh post-treatment found !"
            #~ echo "________________________________  Running it *****"
            #~ ${MY_PATH}/../ASTROBOT/Z1${WISHNAME}.sh "~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}" "${PLAYER}" "$MOATS"
            #~ echo "________________________________   Finished ******"
        #~ fi

###########################################################################################
        ### ADD ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/*
        ### AND PUBLISH WISH TO IPFS
        echo "++WISH PUBLISHING++ ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/*"
        ls ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/

    ## CREATE .all.json for WISHNAME
        ${MY_PATH}/../tools/json_dir.all.sh ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}

        WISHFLUX=$(ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/* | tail -n 1)  # ADDING JSONS TO IPFS
        ipfs --timeout 180s name publish -k $VOEUKEY /ipfs/$WISHFLUX   # PUBLISH $VOEUKEY

        echo "## ASK ${myIPFSGW}${IPNS_VOEUNS} TO REFRESH" ## TODO LOOP BOOSTRAP & ONLINE FRIENDS
        curl -m 120 -so ~/.zen/tmp/${WISHNAME}.astroindex.html "${myIPFSGW}${IPNS_VOEUNS}" &

        ## MOVE INTO PLAYER AREA
        echo ">>> ${PLAYER} G1${WISHNAME} Ŋ1 FLUX $(myIpfsGw)/${IPNS_VOEUNS}"
        echo "WALLET ${VOEUKEY} FOUNDED by ${G1PUB}"
        cp -f ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${WISHNAME}/* ~/.zen/game/players/${PLAYER}/G1${WISHNAME}/${G1PUB}/ 2>/dev/null

done < ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/${PLAYER}.g1wishes.txt

################################################
### SEND GRATITUDE TO SECTOR
## GET "GPS" TIDDLER
if [[ ${wishnumbers} -gt 0 ]]; then
    tiddlywiki --load ${INDEX} \
        --output ~/.zen/tmp/${MOATS} \
        --render '.' 'GPS.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'GPS'  ## GPS Tiddler
    TWMAPNS=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].umap)
    [[ $TWMAPNS == "null" || $TWMAPNS == "" ]] && TWMAPNS="/ipns/k51qzi5uqu5djg1gqzujq5p60w25mi235gdg0lgkk5qztkfrpi5c22oolrriyu"
    LAT=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lat)
    [[ ${LAT} == "null" || ${LAT} == "" ]] && LAT="0.00"
    LAT=$(makecoord $LAT)
    LON=$(cat ~/.zen/tmp/${MOATS}/GPS.json | jq -r .[].lon)
    [[ ${LON} == "null" || ${LON} == "" ]] && LON="0.00"
    LON=$(makecoord $LON)
    echo "LAT=${LAT}; LON=${LON}; UMAPNS=${TWMAPNS}"
    rm ~/.zen/tmp/${MOATS}/GPS.json
    SLAT="${LAT::-1}"
    SLON="${LON::-1}"
    SECTOR="_${SLAT}_${SLON}"
    RLAT="$(echo ${LAT} | cut -d '.' -f 1)"
    RLON="$(echo ${LON} | cut -d '.' -f 1)"
    REGION="_${RLAT}_${RLON}"
    ##############################################################
    UMAPG1PUB=$(cat ~/.zen/tmp/swarm/12D*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/G1PUB | tail -n 1)
    SECTORG1PUB=$(cat ~/.zen/tmp/swarm/12D*/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}/SECTORG1PUB | tail -n 1)
    [[ ${UMAPG1PUB} == "" ]] && UMAPG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
    [[ ${SECTORG1PUB} == "" ]] && SECTORG1PUB=$(${MY_PATH}/../tools/keygen -t duniter "${UPLANETNAME}${SECTOR}" "${UPLANETNAME}${SECTOR}")
    ##############################################################
    GRATITUDE=$($MY_PATH/../tools/getcoins_from_gratitude_box.sh)
    G1AMOUNT=$(echo "$GRATITUDE / 10" | bc -l | xargs printf "%.2f" | sed "s~,~.~g" )
    echo "***** PLAYER $PLAYER *************************************"
    echo "GRATITUDE ${GRATITUDE} ZEN (${G1AMOUNT} G1)
    to UMAP_${LAT}_${LON} WALLET ${UMAPG1PUB}"
    echo "************************************************************"
    YOUSER=$($MY_PATH/../tools/clyuseryomail.sh "${PLAYER}")
    MYWISHFLUX=$(ipfs add -qHwr ~/.zen/tmp/${IPFSNODEID}/WISH/${PLAYER}/g1voeu/* | tail -n 1)  # ADDING JSONS TO IPFS
    ${MY_PATH}/../tools/PAY4SURE.sh "${HOME}/.zen/game/players/${PLAYER}/secret.dunikey" "${G1AMOUNT}" "${UMAPG1PUB}" "UPLANET:UWISH:$YOUSER:/ipfs/${MYWISHFLUX}"
fi
################################################
################################################ GRATITUDE SENT TO SECTOR

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "TODO : REFRESH WORLD SAME WISH CACHE"
cat ~/.zen/game/world/$WISHNAME/*/.link 2>/dev/null
## ANYTIME  A PLAYER CHOOSE AN ASTROPORT - LOCAL WISH CACHE IS EXTENDED -
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

############################################

exit 0
