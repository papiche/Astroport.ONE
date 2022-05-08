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

PASS=$(cat ~/.zen/game/players/.current/.pass)

SALT=$(cat ~/.zen/game/players/.current/login.june | head -n 1)
PEPPER=$(cat ~/.zen/game/players/.current/login.june | tail -n 1)

LP=$(ls /dev/usb/lp*)
convert ~/.zen/game/players/.current/QR.png -resize 300 /tmp/QR.png
convert ${MY_PATH}/../images/astroport.jpg  -resize 300 /tmp/ASTROPORT.png

composite -compose Over -gravity NorthWest -geometry +280+30 /tmp/ASTROPORT.png ${MY_PATH}/../images/carreblanc.png /tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QR.png /tmp/astroport.png /tmp/one.png
composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/.current/QRsec.png /tmp/one.png /tmp/image.png

convert -gravity northwest -pointsize 30 -fill black -draw "text 20,20 \"$PSEUDO $PLAYER\"" /tmp/image.png /tmp/pseudo.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 80,380 \"$PASS\"" /tmp/pseudo.png /tmp/pass.png
convert -gravity northwest -pointsize 20 -fill black -draw "text 300,200 \"$SALT\"" /tmp/pass.png /tmp/salt.png
convert -gravity northwest -pointsize 20 -fill black -draw "text 300,240 \"$PEPPER\"" /tmp/salt.png /tmp/done.jpg

brother_ql_create --model QL-700 --label-size 62 /tmp/done.jpg > /tmp/toprint.bin 2>/dev/null
sudo brother_ql_print /tmp/toprint.bin $LP

exit 0
