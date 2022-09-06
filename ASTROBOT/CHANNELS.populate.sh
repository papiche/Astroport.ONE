#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Construction du canal 'qo-op' à partir des journaux qo-op_$PLAYER
#
################################################################################
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

# Check who is currently current connected PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )

# Astroport Station "Captain" connected?
source ~/.zen/ipfs.sync; echo "CAPTAIN is $CAPTAIN"

[[ $PLAYER != $CAPTAIN ]] && echo "CAPTAIN RUN ONLY. EXIT" && exit 1

MOANS=$(ipfs key list -l | grep -w moa | cut -d ' ' -f 1) ## GET CAPTAIN PLAYER NS PUBKEY
[[ $MOANS == "" ]] &&  echo "NO MOA KEY EXIT" && exit 1

CAPTAINNS=$(ipfs key list -l | grep -w $CAPTAIN | cut -d ' ' -f 1) ## GET CAPTAIN PLAYER NS PUBKEY
CAPTAINMOANS=$(ipfs key list -l | grep -w moa_$CAPTAIN | cut -d ' ' -f 1)
CAPTAINQOOPNS=$(ipfs key list -l | grep -w qo-op_$CAPTAIN | cut -d ' ' -f 1)

    # Copying homepage.html template
    cat ${MY_PATH}/../templates/homepage.html > ~/.zen/game/players/$CAPTAIN/moa/slick.html
    sed -i "s~_IPNSL_~/ipns/$MOANS~g"   ~/.zen/game/players/$CAPTAIN/moa/slick.html
    TAGS=$(${MY_PATH}/get_tagcloud_data.sh | tail -n 1)
    sed -i "s~_TAGCLOUD_~$TAGS~g"   ~/.zen/game/players/$CAPTAIN/moa/slick.html

    cp -R ${MY_PATH}/../templates/styles ~/.zen/game/players/$CAPTAIN/moa/
    cp -R ${MY_PATH}/../templates/js ~/.zen/game/players/$CAPTAIN/moa/

    sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$CAPTAIN/moa/slick.html
    sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/$CAPTAIN/moa/slick.html

                #echo "## PUBLISHING ${CAPTAIN} /ipns/$CAPTAINNS"
                IPUSH=$(ipfs add -rwHq ~/.zen/game/players/$CAPTAIN/moa/* | tail -n 1)
                ipfs name publish --key=${CAPTAIN} /ipfs/$IPUSH 2>/dev/null

echo "http://127.0.0.1:8080/ipns/$CAPTAINNS/slick.html"
echo

# CHECK tokenring
# Indicate who is next.
# If it is my turn...
# UPDATE TW UPDATE CHAIN

for astronaut in $(ls ~/.zen/game/players/); do
    [[ $astronaut == $CAPTAIN ]] && continue
    moans=$(cat ~/.zen/game/players/$astronaut/.moans)
    # CHECK DIFFERENCES FROM LATEST TIME CHECK
    ## GETTING LAST 'player_moa' ONLINE VERSION
    echo "Getting $astronaut/.moans  /ipns/$moans"
    cp ~/.zen/game/players/$astronaut/moa/index.html ~/.zen/tmp/index.html
    ipfs --timeout=10s get -o ~/.zen/game/players/$astronaut/moa/ /ipns/$moans
    IPUSH=$(ipfs add -Hq ~/.zen/game/players/$astronaut/moa/index.html | tail -n 1)

    if [[ $IPUSH != "Qmc5m94Gu7z62RC8waSKkZUrCCBJPyHbkpmGzEePxy2oXJ" ]]; then
        # Qmc5m94Gu7z62RC8waSKkZUrCCBJPyHbkpmGzEePxy2oXJ = VIDE !!
                echo $IPUSH > ~/.zen/game/players/$astronaut/moa/$astronaut.moa.chain
                echo $MOATS > ~/.zen/game/players/$astronaut/moa/$astronaut.moa.ts
                num=$(cat ~/.zen/game/players/$astronaut/moa/$astronaut.moa.n 2>/dev/null) || num=0
                echo $(expr $num + 1) > ~/.zen/game/players/$astronaut/moa/$astronaut.moa.n
                ipfs name publish --key=moa_${astronaut} /ipfs/$IPUSH 2>/dev/null
    # Avance la blockchain CAPTAIN pour archiver les '$astronaut.moa.chain' des Etats modifiés
    [[ $(cat ~/.zen/game/players/$CAPTAIN/moa/$astronaut.moa.chain 2>/dev/null) != "$IPUSH" ]] &&\
        echo $IPUSH > ~/.zen/game/players/$CAPTAIN/moa/$astronaut.moa.chain && \
        echo $MOATS > ~/.zen/game/players/$CAPTAIN/moa/$astronaut.moa.ts && \
        echo "$astronaut 'moa' UPDATE : $MOATS $IPUSH" && \
        diff ~/.zen/tmp/index.html ~/.zen/game/players/$astronaut/moa/index.html | sed -n -e 's/^> //p'
#        echo "<div class='multiple'><h4><a href='http://127.0.0.1:8080/ipns/"${moans}"' target=${moans}>$astronaut</a></h4></div>" >> ~/.zen/game/players/$CAPTAIN/moa/slick.div

    fi

done

exit 0
