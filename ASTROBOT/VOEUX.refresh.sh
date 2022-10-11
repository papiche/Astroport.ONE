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

############################################
echo "## WORLD VOEUX"
myIP=$(hostname -I | awk '{print $1}' | head -n 1)

for v in $(cat ~/.zen/game/players/*/VOEUx/*/.title); do echo $v ;done

for VOEU in $(ls ~/.zen/game/world/);
do
    ## CLEAN OLD CACHE
    rm -Rf ~/.zen/tmp/work
    mkdir -p ~/.zen/tmp/work
    echo "==============================="
    echo "VOEU : $VOEU"
    VOEUNS=$(ipfs key list -l | grep $VOEU | cut -d ' ' -f1)
    WISHNAME=$(cat ~/.zen/game/world/$VOEU/.pepper 2>/dev/null)
    echo "$WISHNAME"
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

        continue
    else
        echo "SEARCH VOEU TW FOR tag=tube"
        ## TAG="tube" tiddler => Dowload youtube video links (playlist accepted) ## WISHKEY=G1PUB !
        $MY_PATH/G1CopierYoutube.sh ~/.zen/tmp/work/index.html $VOEU

        echo "NEXT SEARCH Ŋ1 FRIENDS TW's FOR tag=$WISHNAME"

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
    ipfs name publish  -t 72h --key=${VOEU} /ipfs/$IPUSH 2>/dev/null

    [[ $DIFF ]] &&  echo $IPUSH > ~/.zen/game/world/$VOEU/.chain; \
                              echo $MOATS > ~/.zen/game/world/$VOEU/.moats

    rm -Rf ~/.zen/tmp/work

    echo "================================================"
    echo "$WISHNAME : http://$myIP:8080/ipns/$VOEUNS"
    echo "================================================"
    echo
    echo "*****************************************************"

done

exit 0
