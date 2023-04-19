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
. "$MY_PATH/my.sh"

PLAYER="$1"

[[ ! -f ~/.zen/game/players/${PLAYER}/QR.png ]] &&\
        echo "ERREUR. Aucun PLAYER Astronaute connecté .ERREUR  ~/.zen/game/players/${PLAYER}/" && exit 1

# Check who is .current PLAYER
PLAYER=$(cat ~/.zen/game/players/${PLAYER}/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
ASTRONAUTENS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null) || ( echo "noastronautens" && exit 1 )

PASS=$(cat ~/.zen/game/players/${PLAYER}/.pass)

source ~/.zen/game/players/${PLAYER}/secret.june
[[ $SALT == "" ]] && echo "BAD ACCOUNT. PLEASE BACKUP. MOVE. RESTORE." && exit 1

LP=$(ls /dev/usb/lp*)

PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

# USE G1BILLET GENERATOR
[[ -s ~/.zen/G1BILLET/MAKE_G1BILLET.sh ]] \
&& echo ~/.zen/G1BILLET/MAKE_G1BILLET.sh "$SALT" "$PEPPER" "___" "$G1PUB" "$PASS" "xbian" "$ASTRONAUTENS" "$PLAYER" \
&& ~/.zen/G1BILLET/MAKE_G1BILLET.sh "$SALT" "$PEPPER" "___" "$G1PUB" "$PASS" "xbian" "$ASTRONAUTENS" "$PLAYER"

s=$(${MY_PATH}/diceware.sh 1 | xargs)
p=$(${MY_PATH}/diceware.sh 1 | xargs)
BILLETNAME=$(echo "$SALT" | sed 's/ /_/g')

mv ~/.zen/G1BILLET/tmp/g1billet/$PASS/$BILLETNAME.BILLET.jpg ~/.zen/tmp/$PASS.jpg

[[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open ~/.zen/tmp/$PASS.jpg

        #~ USALT=$(echo "$SALT" | jq -Rr @uri)
        #~ UPEPPER=$(echo "$PEPPER" | jq -Rr @uri)
        #~ echo "/?${s}=${USALT}&${p}=${UPEPPER}" > ~/.zen/tmp/topgp
        #~ cat ~/.zen/tmp/topgp | gpg --symmetric --armor --batch --passphrase "$PASS" -o ~/.zen/tmp/gpg.${PASS}.asc

        #~ DISCO="$(cat ~/.zen/tmp/gpg.${PASS}.asc | tr '-' '~' | tr '\n' '-'  | tr '+' '_' | jq -Rr @uri )"
        #~ echo "$DISCO"
        #~ ## Add logo to QRCode
        #~ cp ${MY_PATH}/../images/g1magicien.png ~/.zen/tmp/fond.png

        #~ ## MAKE amzqr WITH astro:// LINK
        #~ amzqr -d ~/.zen/tmp \
                    #~ -l H \
                    #~ -p ~/.zen/tmp/fond.png \
                    #~ "$DISCO"

        #~ ## ADD PLAYER EMAIL
        #~ convert -gravity southeast -pointsize 28 -fill black -draw "text 5,3 \"$EMAIL\"" ~/.zen/tmp/fond_qrcode.png ~/.zen/tmp/${PASS}.TW.png

[[ $XDG_SESSION_TYPE == 'x11' ]] && xdg-open  ~/.zen/G1BILLET/tmp/fond_qrcode.png


brother_ql_create --model QL-700 --label-size 62 ~/.zen/G1BILLET/tmp/fond_qrcode.png > ~/.zen/tmp/bill.bin 2>/dev/null
sudo brother_ql_print ~/.zen/tmp/bill.bin $LP

convert ~/.zen/game/players/${PLAYER}/QRG1avatar.png -resize 300 ~/.zen/tmp/QR.png
convert ${MY_PATH}/../images/astroport.jpg  -resize 300 ~/.zen/tmp/ASTROPORT.png

composite -compose Over -gravity SouthWest -geometry +280+20 ~/.zen/tmp/ASTROPORT.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 ~/.zen/tmp/QR.png ~/.zen/tmp/astroport.png ~/.zen/tmp/one.png
# composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/${PLAYER}/QRsec.png ~/.zen/tmp/one.png ~/.zen/tmp/image.png

convert -gravity northwest -pointsize 35 -fill black -draw "text 50,300 \"$PSEUDO\"" ~/.zen/tmp/one.png ~/.zen/tmp/image.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 300,40 \"$PLAYER\"" ~/.zen/tmp/image.png ~/.zen/tmp/pseudo.png
convert -gravity northeast -pointsize 25 -fill black -draw "text 20,180 \"$PASS\"" ~/.zen/tmp/pseudo.png ~/.zen/tmp/pass.png
convert -gravity northwest -pointsize 25 -fill black -draw "text 300,100 \"$SALT\"" ~/.zen/tmp/pass.png ~/.zen/tmp/salt.png
convert -gravity northwest -pointsize 25     -fill black -draw "text 300,140 \"$PEPPER\"" ~/.zen/tmp/salt.png ~/.zen/tmp/done.jpg

brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/done.jpg > ~/.zen/tmp/toprint.bin 2>/dev/null
sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP

################################################################
### PRINT PLAYER TW myIP link

playerns=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f1)
qrencode -s 12 -o "$HOME/.zen/tmp/QR.ASTRO.png" "$myIPFSGW/ipns/$playerns"
convert $HOME/.zen/tmp/QR.ASTRO.png -resize 600 ~/.zen/tmp/playerns.png

brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/playerns.png > ~/.zen/tmp/toprint.bin 2>/dev/null
sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP
################################################################

exit 0
