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
# Create and print VOEUX.
# Attributed to a place shared through Astroport Ŋ1 confidence network IPFS layer
# PARAMETRES
# Promesse de virement du MONTANT, le nom du joueur PLAYER et sa G1PUB.
################################################################################
MONTANT="$1"
PLAYER="$2"
G1PUB="$3"
QRTW="$4" # Nombre de QR + TW5 à créer

[[ $MONTANT == "" ]] && MONTANT="_?_"
[[ $PLAYER == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
PSEUDO=$(cat ~/.zen/game/players/.current/.pseudo 2>/dev/null)
[[ $PLAYER == "" ]] && echo "Second paramètre PLAYER manquant" && exit 1
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/.current/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "Troisième paramètre G1PUB manquant" && exit 1
[[ $QRTW == "" ]] && QRTW=1

ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
[[ $ASTRONAUTENS == "" ]] && echo "ASTRONAUTE manquant" && exit 1

echo "Bienvenue $PSEUDO ($PLAYER) : $G1PUB"
echo "Astronaute Ŋ1 : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
echo

# BACKING UP IPNS
rm -f ~/.zen/tmp/index.html
ipfs --timeout 5s get -o ~/.zen/tmp/index.html /ipns/$ASTRONAUTENS
if [ ! -f ~/.zen/tmp/index.html ]; then
    echo "ERROR IPNS TIMEOUT"
    TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --key=$G1PUB /ipfs/$TW
else
    cp ~/.zen/tmp/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
fi

# CREATION DE $QRTW BILLETS DE $MONTANT DU
boucle=0;
while [ $boucle -lt $QRTW ]
do
    boucle=$((boucle+1))
    SALT=$(${MY_PATH}/tools/diceware.sh 3 | xargs)
    PEPPER=$(${MY_PATH}/tools/diceware.sh 1 | xargs)

    echo "Entrez un Titre pour ce Voeu"
    read TITRE
    PEPPER=$(echo "$TITRE" | sed -r 's/\<./\U&/g' | sed 's/ //g')

    echo "# CREATION CLEF DE VOEUX"
    ${MY_PATH}/tools/keygen  -t duniter -o ~/.zen/tmp/qrtw.dunikey "$SALT" "$PEPPER"
    WISHKEY=$(cat ~/.zen/tmp/qrtw.dunikey | grep "pub:" | cut -d ' ' -f 2)

    echo "# NOUVEAU VOEU ASTRONAUTE"
    mkdir -p ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/
    ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/qrtw.ipfskey "$SALT" "$PEPPER"
    VOEUXNS=$(ipfs key import $WISHKEY -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/qrtw.ipfskey)
    # CRYPTO BUG. TODO use natools to protect and share key with Ŋ1 only ;)

    echo "# CREATION WORLD UPGRADE DATABASE"
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    mkdir -p ~/.zen/game/world/$WISHKEY/
    echo $PEPPER > ~/.zen/game/world/$WISHKEY/.pepper

    echo "# CREATION TW"
    # ipfs cat /ipfs/bafybeigw5naxqmxt62ljglgzefmfcchp5gulo3yxs5pu7xrxylhzo2obyu > ~/.zen/Astroport.ONE/templates/twdefault.html
    cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/world/$WISHKEY/index.html

    # PERSONNALISATION
    sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_WISHKEY_~${WISHKEY}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_NUMBER_~${SALT}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_SECRET_~${PEPPER}~g" ~/.zen/game/world/$WISHKEY/index.html

    # IPNS KEY is WISHKEY / VOEUXNS
    sed -i "s~_MEDIAKEY_~${WISHKEY}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~k2k4r8naeti1ny2hsk3a0ziwz22urwiu633hauluwopf4vwjk4x68qgk~${VOEUXNS}~g" ~/.zen/game/world/$WISHKEY/index.html
    # ASTROPORT RELAY
    sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/world/$WISHKEY/index.html

    echo "# CREATION QR CODE"
    HOST="$(hostname).local"

    qrencode -s 6 -o "$HOME/.zen/game/world/$WISHKEY/QR.WISHLINK.png" "http://$HOST:8080/ipns/$VOEUXNS"
    qrencode -s 6 -o "$HOME/.zen/game/world/$WISHKEY/QR.ASTROLINK.png" "http://$HOST:8080/ipns/$ASTRONAUTENS"
    qrencode -s 6 -o "$HOME/.zen/game/world/$WISHKEY/QR.G1ASTRO.png" "$G1PUB"
    qrencode -s 6 -o "$HOME/.zen/game/world/$WISHKEY/QR.G1WISH.png" "$WISHKEY"
    qrencode -s 6 -o "$HOME/.zen/game/world/$WISHKEY/QR.IPNS.png" "/ipns/$VOEUXNS"

    # Bricolage avec node tiddlywiki (TODO add tiddler with command line)
    #
    cd ~/.zen/game/world/$WISHKEY
    tiddlywiki $WISHKEY --load ~/.zen/game/world/$WISHKEY/index.html --savewikifolder ./tw/
    cd -

    # PREMIER TYPE
    convert $HOME/.zen/game/world/$WISHKEY/QR.WISHLINK.png -resize 300 /tmp/QR.png
    convert ${MY_PATH}/images/logoastro.png  -resize 220 /tmp/ASTROLOGO.png
    convert ${MY_PATH}/images/logojeu.png  -resize 260 /tmp/MIZLOGO.png

composite -compose Over -gravity NorthWest -geometry +350+10 /tmp/ASTROLOGO.png ${MY_PATH}/images/Brother_600x400.png /tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QR.png /tmp/astroport.png /tmp/one.png
convert -gravity northwest -pointsize 35 -fill black -draw "text 320,250 \"$PSEUDO\"" /tmp/one.png /tmp/hop.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 20,320 \"$PEPPER\"" /tmp/hop.png /tmp/pseudo.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 320,300 \"$SALT\"" /tmp/pseudo.png /tmp/salt.png
convert -gravity northwest -pointsize 40 -fill black -draw "text 320,350 \"$PEPPER\"" /tmp/salt.png /tmp/player.png

    # SECOND TYPE
    convert $HOME/.zen/game/world/$WISHKEY/QR.G1WISH.png -resize 300 /tmp/G1.png
    convert $HOME/.zen/game/world/$WISHKEY/QR.IPNS.png -resize 300 /tmp/IPNS.png

composite -compose Over -gravity NorthWest -geometry +300+0 /tmp/G1.png ${MY_PATH}/images/Brother_600x400.png /tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/IPNS.png /tmp/astroport.png /tmp/one.png
composite -compose Over -gravity NorthWest -geometry +320+280 /tmp/MIZLOGO.png /tmp/one.png /tmp/two.png

convert -gravity northwest -pointsize 50 -fill black -draw "text 30,300 \"Ğ1 RÊVE\"" /tmp/play.png /tmp/voeu.png
convert -gravity northwest -pointsize 28 -fill black -draw "text 32,350 \"$PEPPER\"" /tmp/two.png /tmp/play.png


    # IMAGE IPFS
    IREVE=$(ipfs add -Hq /tmp/voeu.png | tail -n 1)
    sed -i "s~bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a~${IREVE}~g" ~/.zen/game/world/$WISHKEY/index.html

    # PRINTING
    LP=$(ls /dev/usb/lp* | head -n1)
    [[ ! $LP ]] && echo "NO PRINTER FOUND - Brother QL700 validated" # && exit 1
    echo "IMPRESSION VOEU"
    brother_ql_create --model QL-700 --label-size 62 /tmp/player.png > /tmp/toprint.bin 2>/dev/null
    sudo brother_ql_print /tmp/toprint.bin $LP
    brother_ql_create --model QL-700 --label-size 62 /tmp/voeu.png > /tmp/toprint.bin 2>/dev/null
    sudo brother_ql_print /tmp/toprint.bin $LP

    # COPY QR CODE TO PLAYER ZONE
    cp /tmp/player.png /tmp/voeu.png ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/

    # PUBLISHING
    echo "## ${PLAYER} RECORDING YOU WISH INTO BLOCKCHAIN"
    echo "ipfs add -rHq ~/.zen/game/world/$WISHKEY/
    ipfs name publish --key=${WISHKEY} /ipfs/\$IPUSH"
    IPUSH=$(ipfs add -rHq ~/.zen/game/world/$WISHKEY/ | tail -n 1)
    echo $IPUSH > ~/.zen/game/world/$WISHKEY/.chain # Contains last IPFS backup PLAYER KEY
    echo $MOATS > ~/.zen/game/world/$WISHKEY/.moats
    ipfs name publish --key=${WISHKEY} /ipfs/$IPUSH 2>/dev/null

    echo "CAPSULE A REVE $PEPPER : http://127.0.0.1:8080/ipns/$VOEUXNS"


done

exit 0
