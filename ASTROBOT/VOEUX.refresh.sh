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

cat ~/.zen/tmp/g1voeu.json | jq -r '.[].wish' > ~/.zen/tmp/g1wishes

echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%"

## GET VoeuTitle LIST
while read WISH
do
    [[ $WISH = "" ]] && continue
    echo "==============================="
    echo "G1Voeu $WISH"
    ## Get $WISHNAME TW
    WISHNAME=$(cat ~/.zen/game/world/$WISH/.pepper)
    [[ ! $WISHNAME ]] && echo "ERROR - Missing WISHNAME !! CONTINUE" && continue

    WISHINDEX="$HOME/.zen/game/world/$WISH/index.html"
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
    echo "Search & Collect Ŋ1 G1$WISHNAME tids"

    ## CLEAN OLD CACHE
    rm -Rf ~/.zen/tmp/work
    mkdir -p ~/.zen/tmp/work
    echo "VOEU : $WISHNAME : $WISH"
    VOEUNS=$(ipfs key list -l | grep $WISH | cut -d ' ' -f1)
    echo "http://$myIP:8080/ipns/$VOEUNS"
    echo "==============================="

    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "$LIBRA/ipns/$VOEUNS"
    echo "http://$myIP:8080/ipns/$VOEUNS"
    echo "Getting latest online TW..."
    [[ $YOU ]] && ipfs --timeout 12s cat /ipns/$VOEUNS > ~/.zen/tmp/work/index.html \
                        || curl -m 12 -so ~/.zen/tmp/work/index.html "$LIBRA/ipns/$VOEUNS"

    if [[ ! -s ~/.zen/tmp/work/index.html ]]; then
        echo "UNAVAILABLE WISH! If you want to remove $WISHNAME $VOEU"
        echo "ipfs key rm $VOEU && rm -Rf ~/.zen/game/world/$VOEU"
        echo "============================================="
        echo "ipfs name publish -t 72h /ipfs/$(cat ~/.zen/game/world/$VOEU/.chain)"
        echo "============================================="
        ## CONTINUE - COULD WORK ON LOCAL CACHE ??
        continue
    else

        ##################################
        ## Search for [tag[G1$WISHNAME]] in all Friends TW.
        ## Copy tiddlers ...
        ##################################
        echo "NEXT SEARCH Ŋ1 FRIENDS TW's FOR tag=$WISHNAME"
        ## Search in Local World (NB! G1Voeu TW copied by Connect_PLAYER_To_Gchange.sh)
        for pepperpath in $(grep -lw "$WISHNAME" ~/.zen/game/world/*/.pepper);
        do
            G1PUB=$(echo $pepperpath | rev | cut -d '/' -f 2 | rev)
        ##### EACH FRIEND SAME G1VOEU HAVE SAME PEPPER
            VTWINDEX="$HOME/.zen/game/world/$G1PUB/index.html"
        ##### Search Friend TW to get All Tiddlers G1Voeu tiddlers and copy to Player G1Voeu TW
            tiddlywiki --load $VTWINDEX --output ~/.zen/tmp --render '.' 'astroport.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'Astroport'
            FRIENDNS=$(cat ~/.zen/tmp/astroport.json | jq -r .[].astroport)  ## Value exists also in "MadeInZion" tiddler
            G1FRIEND=$(cat ~/.zen/tmp/astroport.json | jq -r .[].g1pub)  ## Value exists also in "MadeInZion" tiddler

            [[ ! $FRIENDNS ]] && echo "ERROR MISSING /ipns/astroport  FOR THAT WISH - CONTINUE -" && continue
            [[ $FRIENDNS == $ASTRONAUTENS ]] && echo "One of My Wish !! - CONTINUE -" && continue

            FINDEX="$HOME/.zen/game/players/$PLAYER/FRIENDS/$G1FRIEND/index.html"

            echo "Expport [tag[G1$WISHNAME]]  from $FINDEX"
            tiddlywiki --load $FINDEX \
                                --output ~/.zen/tmp --render '.' 'g1wishtiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[G1'$WISHNAME']]'
            [[ ! -s ~/.zen/tmp/g1wishtiddlers.json ]] && echo "ERROR - FAILED" && continue

            # TODO Add Friends G1Voeu Tiddlers to my G1Voeu
            ## DIRECTLY LOOP SCAN FRIENDS TW !?
        #####
        done


        echo "DIFFERENCE ?"
        DIFF=$(diff ~/.zen/tmp/work/index.html ~/.zen/game/world/$VOEU/index.html)

        if [[ $DIFF ]]; then
            echo "Upgrade TW local copy..."
            cp ~/.zen/tmp/work/index.html ~/.zen/game/world/$VOEU/index.html
        else
            echo "No change since last Refresh"
        fi
    fi

    # RECORDING CHANGES
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ $DIFF ]] && cp   ~/.zen/game/world/$VOEU/.chain \
                                    ~/.zen/game/world/$VOEU/.chain.$(cat  ~/.zen/game/world/$VOEU/.moats)

    # PUBLISH VOEU TW
    IPUSH=$(ipfs add -Hq ~/.zen/game/world/$VOEU/index.html | tail -n 1)
    ipfs name publish  -t 24h --key=${VOEU} /ipfs/$IPUSH 2>/dev/null

    [[ $DIFF ]] &&  echo $IPUSH > ~/.zen/game/world/$VOEU/.chain; \
                              echo $MOATS > ~/.zen/game/world/$VOEU/.moats

    rm -Rf ~/.zen/tmp/work

    echo "================================================"
    echo "$WISHNAME : http://$myIP:8080/ipns/$VOEUNS"
    echo "================================================"
    echo
    echo "*****************************************************"


done < ~/.zen/tmp/g1wishes

############################################
echo "## WORLD VOEUX LIST = "
myIP=$(hostname -I | awk '{print $1}' | head -n 1)

for v in $(cat ~/.zen/game/players/*/voeux/*/.title); do echo $v ;done

for VOEU in $(ls ~/.zen/game/world/);
do
    echo "$VOEU"
    ## TODO REFESH IPNS
done

exit 0
