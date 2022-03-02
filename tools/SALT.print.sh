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

[[ ! -f ~/.zen/game/players/.current/QR.png ]] && echo "ERROR. Cannot find current connected player" && exit 1
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo)
PLAYER=$(cat ~/.zen/game/players/.current/.player)

PASS=$(cat ~/.zen/game/players/.current/.pass)
SALT=$(cat ~/.zen/game/players/.current/login.june | head -n 1)
PEPPER=$(cat ~/.zen/game/players/.current/login.june | tail -n 1)

LP=$(ls /dev/usb/lp*)
convert ~/.zen/game/players/.current/QR.png -resize 300 /tmp/QR.png
convert ${MY_PATH}/../images/astroport.jpg  -resize 300 /tmp/ASTROPORT.png

convert -gravity northwest -pointsize 20 -fill black -draw "text 20,20 \"$PSEUDO $PLAYER\"" ${MY_PATH}/../images/extension_territoire.jpg /tmp/pseudo.png
convert -gravity northest -pointsize 20 -fill black -draw "text 20,20 \"$PASS\"" /tmp/pseudo.png /tmp/pass.png
convert -gravity northwest -pointsize 20 -fill black -draw "text 20,180 \"$SALT\"" /tmp/pass.png /tmp/salt.png
convert -gravity northest -pointsize 20 -fill black -draw "text 20,180 \"$PEPPER\"" /tmp/salt.png /tmp/done.jpg

brother_ql_create --model QL-700 --label-size 62 /tmp/done.jpg > /tmp/toprint.bin 2>/dev/null
sudo brother_ql_print /tmp/toprint.bin $LP

exit 0
