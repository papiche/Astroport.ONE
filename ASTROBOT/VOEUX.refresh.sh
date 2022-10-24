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

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"
###############################
## EXTRACT G1Voeu from PLAYER TW
echo "Exporting $PLAYER TW [tag[G1Voeu]]"
rm -f ~/.zen/tmp/g1voeu.json
tiddlywiki --load ${INDEX} --output ~/.zen/tmp --render '.' 'g1voeu.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1Voeu]]'

[[ ! -s ~/.zen/tmp/g1voeu.json ]] && echo "AUCUN G1VOEU - EXIT -" && exit 1

cat ~/.zen/tmp/g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/g1wishes
echo "NB DE VOEUX : "$(cat ~/.zen/tmp/g1wishes | wc -l)

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

## GET VoeuTitle LIST
while read WISH
do
    [[ $WISH = "" ]] && continue
    echo "==============================="
    echo "G1Voeu $WISH"
    ## Get $WISHNAME TW
    WISHNAME=$(cat ~/.zen/tmp/g1voeu.json | jq .[] | jq -r 'select(.wish=="'$WISH'") | .title')
    [[ ! $WISHNAME ]] && echo "WISH sans NOM - CONTINUE -" && continue
    VOEUNS=$(cat ~/.zen/tmp/g1voeu.json  | jq .[] | jq -r 'select(.wish=="'$WISH'") | .ipns')

    mkdir -p ~/.zen/tmp/$WISHNAME/$WISH

    ## RUN SPECIFIC G1Voeu Treatment (G1CopierYoutube.sh)
    if [[ -s $MY_PATH/G1$WISHNAME.sh ]]; then
        echo "........................ Astrobot G1$WISHNAME.sh program found !"
        echo "________________________________  Running it *****"
        ${MY_PATH}/G1${WISHNAME}.sh "$INDEX" "$PLAYER"
        echo "________________________________   Finished ******"
    else
        echo "......................... G1$WISHNAME No special program found !"
    fi

    ## RUN TW search & copy treatment
    echo "*********************************"
        ##################################
        ## Search for [tag[G1$WISHNAME]] in all Friends TW.
        ## Copy tiddlers ...
        ##################################
        echo "NOW SEARCH Ŋ1 FRIENDS TW's FOR tag=$WISHNAME"
        echo "*********************************"
        ## Search in Local World (NB! G1Voeu TW copied by Connect_PLAYER_To_Gchange.sh)
        FINDEX=($( ls $HOME/.zen/game/players/$PLAYER/FRIENDS/*/index.html))

        for FRIENDTW in ${FINDEX[@]};
        do
            rm -f ~/.zen/tmp/$WISHNAME/g1wishtiddlers.json
            echo "TRY EXPORT [tag[G1$WISHNAME]]  FROM $FINDEX"
            tiddlywiki --load $FRIENDTW \
                                --output ~/.zen/tmp/$WISHNAME --render '.' 'g1wishtiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'$WISHNAME']]'
            [[ ! -s ~/.zen/tmp/$WISHNAME/g1wishtiddlers.json ]] && echo "NO $WISHNAME - CONTINUE" && continue

            echo "## WISHES FOUND ;) MIAM "
            ## TODO ADD EXTRA TAG ?
            echo  ">>> Importing ~/.zen/tmp/$WISHNAME/g1wishtiddlers.json"

            tiddlywiki --load $INDEX \
                            --import "~/.zen/tmp/$WISHNAME/g1wishtiddlers.json" "application/json" \
                            --output ~/.zen/tmp/$WISHNAME/$WISH --render "$:/core/save/all" "newindex.html" "text/plain"

            if [[ -s ~/.zen/tmp/$WISHNAME/$WISH/newindex.html ]]; then
                echo "Updating $INDEX"
                cp ~/.zen/tmp/$WISHNAME/$WISH/newindex.html $INDEX
            else
                echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/$WISHNAME/$WISH/newindex.html"
                echo "XXXXXXXXXXXXXXXXXXXXXXX"
            fi

        done

done < ~/.zen/tmp/g1wishes

############################################

exit 0
