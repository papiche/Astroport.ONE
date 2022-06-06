#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
# PREPARE BROTHER QL STICKERS
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

[[ ! -f ~/.zen/game/players/.current/QR.png ]] &&\
        echo "ERREUR. Aucun PLAYER Astronaute connecté .ERREUR  ~/.zen/game/players/.current/" && exit 1

# Check who is .current PLAYER
PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )

IPFSNODEID=$(cat ~/.zen/game/players/.current/.ipfsnodeid 2>/dev/null) || ( echo "noipfsnodeid" && exit 1 )


PLAYERNS=$(cat ~/.zen/game/players/.current/.playerns 2>/dev/null) || ( echo "noplayerns" && exit 1 )
## Kept for old account upgrade Now in VISA.new
qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.PLAYERNS.png" "http://astroport:8080/ipns/$PLAYERNS"

echo "Raffraichissement IPNS $PLAYERNS"
# CONTROL AND OR REPUBLISH
                rm -f ~/.zen/tmp/index.html
                # TRYING TO LOAD PLAYERNS
                ipfs get --timeout=10s -o ~/.zen/tmp/index.html /ipns/$PLAYERNS/index.html
                # NO IPNS RESPONSE... REPUBLISH
                [[ ! -f ~/.zen/tmp/index.html ]] && \
                    IPUSH=$(cat ~/.zen/game/players/$PLAYER/$PLAYER.chain 2>/dev/null) && \
                    ipfs name publish --key=${PLAYER} /ipfs/$IPUSH 2>/dev/null
                # IPNS MEMORIZE BLOCKCHAIN
                [[ -f ~/.zen/tmp/index.html ]] && \
                    cp -f ~/.zen/tmp/index.html ~/.zen/game/players/$PLAYER/ && \
                    echo $MOATS > ~/.zen/game/players/$PLAYER/$PLAYER.ts && \
                    echo $(($(cat ~/.zen/game/players/$PLAYER/$PLAYER.n) + 1)) > ~/.zen/game/players/$PLAYER/$PLAYER.n &&\
                    IPUSH=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ | tail -n 1) &&\
                    echo $IPUSH > ~/.zen/game/players/$PLAYER/$PLAYER.chain

MOANS=$(cat ~/.zen/game/players/.current/.moans 2>/dev/null) || ( echo "noplayermoans" && exit 1 )
qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.MOANS.png" "http://astroport:8080/ipns/$MOANS"

echo "Raffraichissement IPNS $MOANS"
# CONTROL AND OR REPUBLISH
                rm -f ~/.zen/tmp/index.html
                # TRYING TO LOAD PLAYERNS
                ipfs get --timeout=10s -o ~/.zen/tmp/index.html /ipns/$MOANS/index.html
                # NO IPNS RESPONSE... REPUBLISH
                [[ ! -f ~/.zen/tmp/index.html ]] && \
                    IPUSH=$(cat ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.chain 2>/dev/null) && \
                    ipfs name publish --key=moa_${PLAYER} /ipfs/$IPUSH 2>/dev/null
                # IPNS MEMORIZE BLOCKCHAIN
                [[ -f ~/.zen/tmp/index.html ]] && \
                    cp -f ~/.zen/tmp/index.html ~/.zen/game/players/$PLAYER/moa/ && \
                    echo $MOATS > ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.ts && \
                    echo $(($(cat ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.n) + 1)) > ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.n &&\
                    IPUSH=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/moa/ | tail -n 1) &&\
                    echo $IPUSH > ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.chain


QOOPNS=$(cat ~/.zen/game/players/.current/.qoopns 2>/dev/null) || ( echo "noplayerqoopns" && exit 1 )
qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.QOOPNS.png" "http://astroport:8080/ipns/$QOOPNS"

echo "Raffraichissement IPNS $QOOPNS"
# CONTROL AND OR REPUBLISH
                rm -f ~/.zen/tmp/index.html
                # TRYING TO LOAD PLAYERNS
                ipfs get --timeout=10s -o ~/.zen/tmp/index.html /ipns/$QOOPNS/index.html

                # NO IPNS RESPONSE... REPUBLISH
                [[ ! -f ~/.zen/tmp/index.html ]] && \
                    IPUSH=$(cat ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.chain 2>/dev/null) && \
                    ipfs name publish --key=qo-op_${PLAYER} /ipfs/$IPUSH 2>/dev/null
                # IPNS MEMORIZE BLOCKCHAIN
                [[ -f ~/.zen/tmp/index.html ]] && \
                    cp -f ~/.zen/tmp/index.html ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/ && \
                    echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.ts && \
                    echo $(($(cat ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.n) + 1)) > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.n &&\
                    IPUSH=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html | tail -n 1) &&\
                    echo $IPUSH > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.chain

PASS=$(cat ~/.zen/game/players/.current/.pass)

SALT=$(cat ~/.zen/game/players/.current/secret.june | head -n 1)
PEPPER=$(cat ~/.zen/game/players/.current/secret.june | tail -n 1)

LP=$(ls /dev/usb/lp*)
convert ~/.zen/game/players/.current/QR.QOOPNS.png -resize 300 /tmp/QR.png
convert ${MY_PATH}/../images/astroport.jpg  -resize 300 /tmp/ASTROPORT.png

composite -compose Over -gravity NorthWest -geometry +280+30 /tmp/ASTROPORT.png ${MY_PATH}/../images/demi.png /tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QR.png /tmp/astroport.png /tmp/one.png
convert -gravity northwest -pointsize 50 -fill black -draw "text 300,200 \"TW\"" /tmp/pass.png /tmp/salt.png
convert -gravity northwest -pointsize 20 -fill black -draw "text 300,240 \"$PLAYER\"" /tmp/salt.png /tmp/done.jpg

brother_ql_create --model QL-700 --label-size 62 /tmp/done.jpg > /tmp/toprint.bin 2>/dev/null
sudo brother_ql_print /tmp/toprint.bin $LP

exit 0
