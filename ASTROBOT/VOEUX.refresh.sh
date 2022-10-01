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
# Backup and chain

[[ $PLAYER == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
############################################
echo "## WORLD VOEUX"

for v in $(cat ~/.zen/game/players/*/voeux/*/.title); do echo $v ;done

for voeu in $(ls ~/.zen/game/world/);
do
    echo "VOEU : $voeu"
    voeuns=$(ipfs key list -l | grep $voeu | cut -d ' ' -f1)
    echo "http://127.0.0.1:8080/ipns/$voeuns"
    echo
    W=$(cat ~/.zen/game/world/$voeu/.pepper 2>/dev/null)
    echo $W

    rm -Rf ~/.zen/tmp/work
    mkdir -p ~/.zen/tmp/work

    echo "Getting latest online TW..."
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "$LIBRA/ipns/$voeuns"
    [[ $YOU ]] && ipfs --timeout 12s cat /ipns/$voeuns > ~/.zen/tmp/work/index.html \
                        || curl -so ~/.zen/tmp/work/index.html "$LIBRA/ipns/$voeuns"

    if [[ ! -s ~/.zen/tmp/work/index.html ]]; then
        echo "UNAVAILABLE WISH! If you want to remove $W $voeu"
        echo "ipfs key rm $voeu && rm -Rf ~/.zen/game/world/$voeu"
        echo "============================================="
        echo "ipfs name publish -t 72h /ipfs/$(cat ~/.zen/game/world/$voeu/.chain)"

        continue
    else
        ## Replace tube links with downloaded video
        $MY_PATH/TUBE.copy.sh ~/.zen/tmp/work/index.html $voeu

        ## LAN TO WAN MIGRATION
        myIP=$(hostname -I | awk '{print $1}' | head -n 1)
        sed -i "s~192.168.199.191~${myIP}~g" ~/.zen/tmp/work/index.html
        echo $myIP > ~/.zen/game/world/$voeu/.myIP
        echo "Setting new IP : $myIP"

        echo "DIFFERENCE ?"
        DIFF=$(diff ~/.zen/tmp/work/index.html ~/.zen/game/world/$voeu/index.html)

        if [[ $DIFF ]]; then
            echo "Backup & Upgrade TW local copy..."
            cp -f ~/.zen/game/world/$voeu/index.html ~/.zen/game/world/$voeu/index.backup.html
            cp ~/.zen/tmp/work/index.html ~/.zen/game/world/$voeu/index.html
        else
            echo "No change since last Refresh"
        fi
    fi

    # RECORDING BLOCKCHAIN TIC
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ $DIFF ]] && cp ~/.zen/game/world/$voeu/.chain ~/.zen/game/world/$voeu/.chain.$MOATS

    IPUSH=$(ipfs add -Hq ~/.zen/game/world/$voeu/index.html | tail -n 1)
    ipfs name publish  -t 72h --key=${voeu} /ipfs/$IPUSH 2>/dev/null

    [[ $DIFF ]] && echo $IPUSH > ~/.zen/game/world/$voeu/.chain
    echo $MOATS > ~/.zen/game/world/$voeu/.moats

    rm -Rf ~/.zen/tmp/work

#    if [[ -d ~/.zen/game/players/$PLAYER/voeux/$voeu ]]; then
#        echo "==========================="
#        echo "Voeu$W : commande de suppression"
#        echo "ipfs key rm $voeu
#        rm -Rf ~/.zen/game/world/$voeu
#        rm -Rf ~/.zen/game/players/$PLAYER/voeux/$voeu"
#        echo "==========================="
#    fi

    echo "================================================"
    echo "$W : http://127.0.0.1:8080/ipns/$voeuns"
    echo "================================================"

done

exit 0
