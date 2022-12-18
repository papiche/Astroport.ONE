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

PLAYER="$1"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

[[ ! -f ~/.zen/game/players/${PLAYER}/QR.png ]] &&\
        echo "ERREUR. Aucun PLAYER Astronaute connecté .ERREUR  ~/.zen/game/players/${PLAYER}/" && exit 1

# Check who is .current PLAYER
PLAYER=$(cat ~/.zen/game/players/${PLAYER}/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )


PASS=$(cat ~/.zen/game/players/${PLAYER}/.pass)

SALT=$(cat ~/.zen/game/players/${PLAYER}/secret.june | head -n 1)
PEPPER=$(cat ~/.zen/game/players/${PLAYER}/secret.june | tail -n 1)

LP=$(ls /dev/usb/lp*)

convert ~/.zen/game/players/${PLAYER}/QR.png -resize 300 /tmp/QR.png
convert ${MY_PATH}/../images/astroport.jpg  -resize 300 /tmp/ASTROPORT.png

composite -compose Over -gravity SouthWest -geometry +280+20 /tmp/ASTROPORT.png ${MY_PATH}/../images/Brother_600x400.png /tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QR.png /tmp/astroport.png /tmp/one.png
# composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/${PLAYER}/QRsec.png /tmp/one.png /tmp/image.png

convert -gravity northwest -pointsize 35 -fill black -draw "text 50,300 \"$PSEUDO\"" /tmp/one.png /tmp/image.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 300,40 \"$PLAYER\"" /tmp/image.png /tmp/pseudo.png
convert -gravity northeast -pointsize 25 -fill black -draw "text 20,180 \"$PASS\"" /tmp/pseudo.png /tmp/pass.png
convert -gravity northwest -pointsize 25 -fill black -draw "text 300,100 \"$SALT\"" /tmp/pass.png /tmp/salt.png
convert -gravity northwest -pointsize 25     -fill black -draw "text 300,140 \"$PEPPER\"" /tmp/salt.png /tmp/done.jpg

brother_ql_create --model QL-700 --label-size 62 /tmp/done.jpg > /tmp/toprint.bin 2>/dev/null
sudo brother_ql_print /tmp/toprint.bin $LP

################################################################
### PRINT PLAYER TW myIP link
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(route -n |awk '$1 == "0.0.0.0" {print $2}' | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"

TUBE=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 3)

playerns=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)
qrencode -s 12 -o "$HOME/.zen/tmp/QR.ASTRO.png" "http://$TUBE:8080/ipns/$playerns"
convert $HOME/.zen/tmp/QR.ASTRO.png -resize 600 /tmp/playerns.png

brother_ql_create --model QL-700 --label-size 62 /tmp/playerns.png > /tmp/toprint.bin 2>/dev/null
sudo brother_ql_print /tmp/toprint.bin $LP
################################################################

exit 0
