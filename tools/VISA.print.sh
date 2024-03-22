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

SALT="$2"
PEPPER="$3"

PASS="$4"

MOATS="$5"

[[ ! ${MOATS} ]] && MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
mkdir -p ~/.zen/tmp/${MOATS}

if [[ ${SALT} == ""  || ${PEPPER} == "" ]]; then

    [[ ! -f ~/.zen/game/players/${PLAYER}/QR.png ]] &&\
            echo "ERREUR. Aucun PLAYER Astronaute connecté .ERREUR  ~/.zen/game/players/${PLAYER}/" && exit 1

    # Check who is .current PLAYER
    PLAYER=$(cat ~/.zen/game/players/${PLAYER}/.player 2>/dev/null) || ( echo "noplayer" && exit 1 )
    PSEUDO=$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null) || ( echo "nopseudo" && exit 1 )
    G1PUB=$(cat ~/.zen/game/players/${PLAYER}/.g1pub 2>/dev/null) || ( echo "nog1pub" && exit 1 )
    ASTRONAUTENS=$(cat ~/.zen/game/players/${PLAYER}/.playerns 2>/dev/null) || ( echo "noastronautens" && exit 1 )

    PASS=$(cat ~/.zen/game/players/${PLAYER}/.pass)

    source ~/.zen/game/players/${PLAYER}/secret.june

else

    echo "VIRTUAL PLAYER ${PLAYER} WELCOME - CREATING AstroID"
    VIRTUAL=1
    G1PUB=$(${MY_PATH}/keygen -t duniter "${SALT}" "${PEPPER}")
    ASTRONAUTENS=$(${MY_PATH}/keygen -t ipfs "${SALT}" "${PEPPER}")
    PSEUDO="UPlanet"

    mkdir -p ~/.zen/game/players/${PLAYER}/
    CIMG="${MY_PATH}/../images/zenticket.png"
    amzqr "${G1PUB}" -l H -p "$CIMG" -c -n QRG1avatar.png -d ~/.zen/game/players/${PLAYER}/

fi


[[ $SALT == "" ]] && echo "BAD ACCOUNT. PLEASE BACKUP. MOVE. RESTORE." && exit 1

LP=$(ls /dev/usb/lp* | head -n 1 2>/dev/null)

[[ ${PASS} == "" ]] && PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-5) ## GENERATE 4 DIGIT PIN

# USE G1BILLET GENERATOR
[[ -s ~/.zen/G1BILLET/MAKE_G1BILLET.sh ]] \
&& echo ~/.zen/G1BILLET/MAKE_G1BILLET.sh "$SALT" "$PEPPER" "___" "$G1PUB" "${PASS}" "${PSEUDO-xastro}" "$ASTRONAUTENS" "$PLAYER" \
&& ~/.zen/G1BILLET/MAKE_G1BILLET.sh "$SALT" "$PEPPER" "___" "$G1PUB" "${PASS}" "${PSEUDO-xastro}" "$ASTRONAUTENS" "$PLAYER" \
|| ( echo "MISSING G1BILLET ENGINE - ERROR - " && exit 1 )

s=$(${MY_PATH}/diceware.sh 1 | xargs)
p=$(${MY_PATH}/diceware.sh 1 | xargs)
BILLETNAME=$(echo "$SALT" | sed 's/ /_/g')

## GET IMAGE FROM G1BILLET ENGINE
cp ~/.zen/G1BILLET/tmp/g1billet/${PASS}/${BILLETNAME}.BILLET.jpg ~/.zen/tmp/${MOATS}/${PASS}.jpg

[[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open ~/.zen/tmp/${MOATS}/${PASS}.jpg

#~ [[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open  ~/.zen/G1BILLET/tmp/g1billet/${PASS}/${BILLETNAME}.TW.png


#~ [[ $LP ]] \
#~ && brother_ql_create --model QL-700 --label-size 62 ~/.zen/G1BILLET/tmp/g1billet/${PASS}/${BILLETNAME}.TW.png > ~/.zen/tmp/${MOATS}/bill.bin 2>/dev/null \
#~ && sudo brother_ql_print ~/.zen/tmp/${MOATS}/bill.bin $LP
#~ #############

convert ~/.zen/game/players/${PLAYER}/QRG1avatar.png -resize 300 ~/.zen/tmp/${MOATS}/QR.png
convert ${MY_PATH}/../images/astroport.jpg  -resize 260 ~/.zen/tmp/${MOATS}/astroport.jpg

composite -compose Over -gravity NorthEast -geometry +42+72 ~/.zen/tmp/${MOATS}/astroport.jpg ${MY_PATH}/../images/Brother_600x300.png ~/.zen/tmp/${MOATS}/one.png
composite -compose Over -gravity NorthWest -geometry +0+12 ~/.zen/tmp/${MOATS}/QR.png ~/.zen/tmp/${MOATS}/one.png ~/.zen/tmp/${MOATS}/astroport.png
# composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/${PLAYER}/QRsec.png ~/.zen/tmp/${MOATS}/one.png ~/.zen/tmp/${MOATS}/image.png

convert -gravity NorthEast -pointsize 18 -fill black -draw "text 42,32 \"$PLAYER\"" ~/.zen/tmp/${MOATS}/astroport.png ~/.zen/tmp/${MOATS}/image.png
convert -gravity NorthWest -pointsize 18 -fill black -draw "text 20,2 \"$G1PUB\"" ~/.zen/tmp/${MOATS}/image.png ~/.zen/tmp/${MOATS}/pseudo.png
convert -gravity SouthEast -pointsize 30 -fill black -draw "text 100, 72 \"${PASS}\"" ~/.zen/tmp/${MOATS}/pseudo.png ~/.zen/tmp/${MOATS}/pass.png
convert -gravity SouthEast -pointsize 16 -fill black -draw "text 10,25 \"$SALT\"" ~/.zen/tmp/${MOATS}/pass.png ~/.zen/tmp/${MOATS}/salt.png
convert -gravity SouthEast -pointsize 16 -fill black -draw "text 10,10 \"$PEPPER\"" ~/.zen/tmp/${MOATS}/salt.png ~/.zen/tmp/${MOATS}/ZenCard.${PASS}.jpg

[[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open  ~/.zen/tmp/${MOATS}/ZenCard.${PASS}.jpg

## PRINT VISA
[[ $LP ]] \
&& brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/${MOATS}/ZenCard.${PASS}.jpg > ~/.zen/tmp/${MOATS}/toprint.bin 2>/dev/null \
&& sudo brother_ql_print ~/.zen/tmp/${MOATS}/toprint.bin $LP

## PRINT PGP AstroID
convert ~/.zen/G1BILLET/tmp/g1billet/${PASS}/${BILLETNAME}.ZENCARD.png  -resize 400 ~/.zen/tmp/${MOATS}/ASTROPORT.png
convert -gravity NorthWest -pointsize 15 -fill black -draw "text 20,2 \"$G1PUB\"" ~/.zen/tmp/${MOATS}/ASTROPORT.png ~/.zen/tmp/${MOATS}/one.png

composite -compose Over -gravity Center -geometry +0+0 ~/.zen/tmp/${MOATS}/one.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/${MOATS}/AstroID.${PASS}.jpg


[[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open ~/.zen/tmp/${MOATS}/AstroID.${PASS}.jpg

[[ $LP ]] \
&& brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/${MOATS}/AstroID.${PASS}.jpg > ~/.zen/tmp/${MOATS}/toprint.bin 2>/dev/null \
&& sudo brother_ql_print ~/.zen/tmp/${MOATS}/toprint.bin $LP

echo "DEBUG ~/.zen/tmp/${MOATS}"
ls ~/.zen/tmp/${MOATS}
echo "DEBUG"

## SELECTIVE CLEANING
#~ rm -f ~/.zen/tmp/${MOATS}/*.bin
#~ rm -f ~/.zen/tmp/${MOATS}/*.png

exit 0
