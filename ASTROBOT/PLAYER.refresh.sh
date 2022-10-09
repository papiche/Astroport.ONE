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
## Publish All PLAYER TW,
# Run TAG subprocess: tube, voeu
############################################
echo "## RUNNING PLAYER.refresh"

## RUNING FOR ALL LOCAL PLAYERS
for PLAYER in $(ls ~/.zen/game/players/); do

    echo "##################################################################"
    echo ">>>>> PLAYER : $PLAYER"
    echo "##################################################################"
    PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
    ## REFRESH ASTRONAUTE TW
    ASTRONAUTENS=$(ipfs key list -l | grep $PLAYER | cut -d ' ' -f1)
    [[ ! $ASTRONAUTENS ]] && echo "Missing $PLAYER IPNS KEY -- CONTINUE --" && continue

    rm -Rf ~/.zen/tmp/astro
    mkdir -p ~/.zen/tmp/astro

    # Get PLAYER wallet amount
    BAL=$($MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey balance)
    echo "+++ WALLET BALANCE _ $BAL (G1) _"

    myIP=$(hostname -I | awk '{print $1}' | head -n 1)

    echo "Getting latest online TW..."
    YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    echo "$LIBRA/ipns/$ASTRONAUTENS"
    echo "http://$myIP:8080/ipns/$ASTRONAUTENS"
    [[ $YOU ]] && ipfs --timeout 12s cat  /ipns/$ASTRONAUTENS > ~/.zen/tmp/astro/index.html \
                        || curl -m 12 -so ~/.zen/tmp/astro/index.html "$LIBRA/ipns/$ASTRONAUTENS"

    ## PLAYER TW IS ONLINE ?
    if [ ! -s ~/.zen/tmp/astro/index.html ]; then

        echo "ERROR_PLAYERTW_TIMEOUT : /ipns/$ASTRONAUTENS"
        echo "------------------------------------------------"
        echo "MANUAL PROCEDURE NEEDED"
        echo "------------------------------------------------"
        echo "TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)"
        echo "ipfs name publish  -t 72h --key=$PLAYER /ipfs/\$TW"
        continue

    else

        ## CHECK IF myIP IS LAST GATEWAY
        tiddlywiki --load ~/.zen/tmp/astro/index.html  --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
        OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)

        [[ $OLDIP != $myIP ]] && echo "ASTRONAUTE GATEWAY IS http://$OLDIP:8080/ipns/$ASTRONAUTENS - BYPASSING -" && continue

        ## RUN ASTROBOT SUBPROCESS
        ##############################################################
        ## TAG="tube" tiddler => Dowload youtube video links (playlist accepted) ## WISHKEY=PLAYER or G1PUB !
        $MY_PATH/TUBE.copy.sh ~/.zen/tmp/astro/index.html $PLAYER
        ##############################################################
        ##############################################################
        ## TAG="voeu" => Creation G1Voeu "TW"
        $MY_PATH/VOEU.create.sh ~/.zen/tmp/astro/index.html $PLAYER
        ##############################################################

        ## ANY CHANGES ?
        ##############################################################
        DIFF=$(diff ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html)
        if [[ $DIFF ]]; then
            echo "DIFFERENCE DETECTED !! "
            echo "Backup & Upgrade TW local copy..."
            cp ~/.zen/tmp/astro/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        else
            echo "No change since last Refresh..."
        fi
        ##############################################################

    fi

    #

        ##############################################################
        ##############################################################

##########################
# Generate G1BARRE for each wish
for g1wish in $(ls ~/.zen/game/players/$PLAYER/voeux/); do
    wishname=$(cat ~/.zen/game/players/$PLAYER/voeux/$g1wish/.title)
    wishns=$(ipfs key list -l | grep $g1wish | cut -d ' ' -f1)

    echo "MISE A JOUR G1BARRE pour VOEU $wishname : "
    echo "G1WALLET $g1wish"
    echo "G1VOEUTW  /ipns/$wishns"

    # Create last g1barre
    G1BARRE="https://g1sms.fr/g1barre/image.php?pubkey=$g1wish&target=1000&title=$wishname&node=g1.duniter.org&start_date=2022-08-01&display_pubkey=true&display_qrcode=true&progress_color=ff07a4"
    echo "curl -o ~/.zen/tmp/g1barre.png $G1BARRE"
    rm -f ~/.zen/tmp/g1barre.png
    curl -so ~/.zen/tmp/g1barre.png "$G1BARRE"
     # Verify file exists & non/empy before copy new version in "world/$g1wish"
    [[ ! -s ~/.zen/tmp/g1barre.png ]] && echo "No Image ! ERROR. PLEASE VERIFY NETWORK LOCATION FOR G1BARRE" && continue
    cp ~/.zen/tmp/g1barre.png ~/.zen/game/world/$g1wish/g1barre.png
    ##################################################################"
    OLDIG1BAR=$(cat ~/.zen/game/world/$g1wish/.ig1barre)

    BAL=$($MY_PATH/../tools/jaklis/jaklis.py balance -p $g1wish )
    echo "MONTANT (G1) $BAL"
    ##################################################################"
    IG1BAR=$(ipfs add -Hq ~/.zen/game/world/$g1wish/g1barre.png | tail -n 1)
    if [[ $OLDIG1BAR != "" && $OLDIG1BAR != $IG1BAR ]]; then # Update
        echo "NEW VALUE !! Updating G1VOEU Tiddler /ipfs/$IG1BAR"

        ## Replace IG1BAR "in TW" ipfs value (hash unicity is cool !!)
        sed -i "s~${OLDIG1BAR}~${IG1BAR}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        echo $IG1BAR > ~/.zen/game/world/$g1wish/.ig1barre
        echo "Update new g1barre: /ipfs/$IG1BAR"

        MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
        echo "Avancement blockchain TW $PLAYER : $MOATS"
        cp ~/.zen/game/players/$PLAYER/ipfs/moa/.chain ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$MOATS

        TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
        echo "ipfs name publish --key=$PLAYER /ipfs/$TW"
        ipfs name publish --allow-offline --key=$PLAYER /ipfs/$TW

        # MAJ CACHE TW $PLAYER
        echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
        echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
        echo "##################################################################"
        ##################################################################

    fi

    ### NO OLDIG1BAR, MEANS FIRST RUN
    if [[ $OLDIG1BAR == ""  ]]; then # CREATE Tiddler

        TEXT="<a target='_blank' href='"/ipns/${wishns}"'><img src='"/ipfs/${IG1BAR}"'></a><br><br><a target='_blank' href='"/ipns/${wishns}"'>"${wishname}"</a>"

        # NEW G1BAR TIDDLER
        echo "## Creation json tiddler : G1${wishname} /ipfs/${IG1BAR}"
        echo '[
      {
        "title": "'G1${wishname}'",
        "type": "'text/vnd.tiddlywiki'",
        "ipns": "'/ipns/$wishns'",
        "ipfs": "'/ipfs/$IG1BAR'",
        "player": "'/ipfs/$PLAYER'",
        "text": "'$TEXT'",
        "tags": "'g1voeu g1${wishname} $PLAYER'"
      }
    ]
    ' > ~/.zen/tmp/g1${wishname}.bank.json

        rm -f ~/.zen/tmp/newindex.html

        echo "Nouveau G1${wishname}  : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
        tiddlywiki --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html \
                        --import ~/.zen/tmp/g1${wishname}.bank.json "application/json" \
                        --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

        echo "PLAYER TW Update..."
        if [[ -s ~/.zen/tmp/newindex.html ]]; then
            echo "Mise à jour ~/.zen/game/players/$PLAYER/ipfs/moa/index.html"
            cp -f ~/.zen/tmp/newindex.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        fi

        echo $IG1BAR > ~/.zen/game/world/$g1wish/.ig1barre

    fi

done
        ##############################################################
        ##############################################################


############################
## ASTRONAUTE SIGNALING ##
[[ ! $(grep -w "$ASTRONAUTENS" ~/.zen/game/astronautes.txt ) ]] && echo "$PSEUDO:$PLAYER:$ASTRONAUTENS" >> ~/.zen/game/astronautes.txt
############################


    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    [[ $DIFF ]] && cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --allow-offline -t 72h --key=$PLAYER /ipfs/$TW

    [[ $DIFF ]] && echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats

    echo "================================================"
    echo "$PLAYER : http://$myIP:8080/ipns/$ASTRONAUTENS"
    echo "================================================"

done

#################################################################
## IPFSNODEID ROUTING
## PUBLISHING ASTRONAUTS LIST
## EVOLVE TO P2P QOS MAP JSON
ROUTING=$(ipfs add -q ~/.zen/game/astronautes.txt)
echo "PUBLISHING IPFSNODEID / Astronaute List"
ipfs name publish /ipfs/$ROUTING

exit 0
