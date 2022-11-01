#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
################################################################################
# Inspect game wishes, refresh latest IPNS version
# SubProcess Backup and chain
INDEX="$1"
[[ ! $INDEX ]] && echo "Please provide path to source TW index.html - EXIT -" && exit 1
[[ ! -f $INDEX ]] && echo "Fichier TW absent. $INDEX - EXIT -" && exit 1

PLAYER="$2" ## IPNS KEY NAME - G1PUB - PLAYER ...
[[ ! $PLAYER ]] && echo "Please provide IPFS publish key" && exit 1
ASTRONAUTENS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)

[[ ! $ASTRONAUTENS ]] && echo "$PLAYER CLEF IPNS INTROUVABLE - EXIT -" && exit 1

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)
myIP=$(hostname -I | awk '{print $1}' | head -n 1)

mkdir -p ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
###############################
## EXTRACT G1Voeu from PLAYER TW
echo "Exporting $PLAYER TW [tag[G1Voeu]]"
rm -f ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1voeu.json
tiddlywiki --load ${INDEX} --output ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS} --render '.' 'g1voeu.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'

[[ ! -s ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1voeu.json ]] && echo "AUCUN G1VOEU - EXIT -" && exit 1

cat ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1wishes.txt
echo "NB DE VOEUX : "$(cat ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1wishes.txt | wc -l)

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

## GET VoeuTitle LIST
while read WISH
do
    [[ ${WISH} = "" ]] && continue
    echo "==============================="
    echo "G1Voeu ${WISH}"
    ## Get ${WISHNAME} TW
    WISHNAME=$(cat ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1voeu.json | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .title')
    [[ ! ${WISHNAME} ]] && echo "WISH sans NOM - CONTINUE -" && continue
    VOEUNS=$(cat ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1voeu.json  | jq .[] | jq -r 'select(.wish=="'${WISH}'") | .ipns')

    mkdir -p ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/${WISHNAME}/${WISH}


    ## RUN SPECIFIC G1Voeu ASTROBOT PROGRAM (like G1CopierYoutube.sh)
    if [[ -s $MY_PATH/G1${WISHNAME}.sh ]]; then
        echo "........................ Astrobot G1${WISHNAME}.sh program found !"
        echo "________________________________  Running it *****"
        ${MY_PATH}/G1${WISHNAME}.sh "$INDEX" "$PLAYER"
        echo "________________________________   Finished ******"
    else
        echo "......................... G1${WISHNAME} No special program found !"
    fi

    ## RUN TW search & copy treatment
    echo "*********************************"
        ##################################
        ## Search for [tag[G1${WISHNAME}]] in all Friends TW.
        ## Copy tiddlers ...
        ##################################
        echo "NOW SEARCH Ŋ1 FRIENDS TW's FOR tag=${WISHNAME}"
        echo "ls ~/.zen/game/players/$PLAYER/FRIENDS/*/index.html"
        echo "*********************************"
        ## Search in Local World (NB! G1Voeu TW copied by Connect_PLAYER_To_Gchange.sh)
        FINDEX=($( ls $HOME/.zen/game/players/$PLAYER/FRIENDS/*/index.html))

        for FRIENDTW in ${FINDEX[@]};
        do
            [[ ! -s $FRIENDTW ]] && echo "$FRIENDTW VIDE (AMI SANS TW)" && continue
            PLAYER=$(ls $FRIENDTW | cut -d '/' -f 7)

            rm -f ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/${WISHNAME}/${PLAYER}.tiddlers.json
            echo "TRY EXPORT [tag[G1${WISHNAME}]]  FROM $FRIENDTW"
            tiddlywiki --load $FRIENDTW \
                                --output ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/${WISHNAME} --render '.' ${PLAYER}'.tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'${WISHNAME}']]'
            [[ ! -s ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/${WISHNAME}/${PLAYER}.tiddlers.json ]] && echo "NO ${WISHNAME} - CONTINUE -" && continue
            [[ $(cat ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/${WISHNAME}/${PLAYER}.tiddlers.json) == "[]" ]] && echo "EMPTY ${WISHNAME} - CONTINUE -" && continue

            echo "## WISHES FOUND ;) MIAM "
            ######################################
            ## TODO ADD EXTRA TAG ?
            # Remove G1${WISHNAME} with WISHNAME Initial TIDDLER
            # Reduce importation with extra filters days:created[-1]
            # Apply Extra filters... TODO LEARN https://talk.tiddlywiki.org/t/how-to-filter-and-delete-multiple-tiddlers/4950/2?u=papiche
            echo  ">>> Importing ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/${WISHNAME}/${PLAYER}.tiddlers.json"

            tiddlywiki --load $INDEX \
                            --import "$HOME/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/${WISHNAME}/${PLAYER}.tiddlers.json" "application/json" \
                            --output ~/.zen/tmp --render "$:/core/save/all" "${ASTRONAUTENS}.newindex.html" "text/plain"

            if [[ -s ~/.zen/tmp/${ASTRONAUTENS}.newindex.html ]]; then
                echo "Updating $INDEX"
                cp ~/.zen/tmp/${ASTRONAUTENS}.newindex.html $INDEX
            else
                echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/${ASTRONAUTENS}.newindex.html"
                echo "XXXXXXXXXXXXXXXXXXXXXXX"
            fi

        done

done < ~/.zen/tmp/${IPFSNODEID}/g1voeu/${ASTRONAUTENS}/g1wishes.txt

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

############################################

exit 0
