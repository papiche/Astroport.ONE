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
[[ $PLAYER == "" ]] && echo "Second paramètre PLAYER manquant" && exit 1
PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "Troisième paramètre G1PUB manquant" && exit 1
[[ $QRTW == "" ]] && QRTW=1

ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
[[ $ASTRONAUTENS == "" ]] && echo "ASTRONAUTE manquant" && exit 1

echo "Bienvenue $PSEUDO ($PLAYER) : $G1PUB"
echo

########################################################
# BACKING UP Astronaute TW IPNS
mkdir -p ~/.zen/tmp/TW
rm -f ~/.zen/tmp/TW/index.html
ipfs --timeout 6s cat /ipns/$ASTRONAUTENS > ~/.zen/tmp/TW/index.html

if [ ! -s ~/.zen/tmp/TW/index.html ]; then
    echo "ERROR IPNS TIMEOUT. Restoring local backup..."
    TW=$(ipfs add -rHq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
    ipfs name publish --key=$PLAYER /ipfs/$TW
else
    # Backup
    ## TODO index.html are different => Add signaling tiddler
    cp ~/.zen/tmp/TW/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
fi
########################################################


# CREATION DU VOEU (TODO: REMOVE OR ACTIVATE LOOP ?)
boucle=0;
while [ $boucle -lt $QRTW ]
do
    boucle=$((boucle+1))
    SALT=$(${MY_PATH}/tools/diceware.sh 3 | xargs)
    PEPPER=$(${MY_PATH}/tools/diceware.sh 1 | xargs)

    echo "Entrez un Titre pour ce Voeu"
    read TITRE
    PEPPER=$(echo "$TITRE" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords

    echo "# CREATION CLEF DE VOEUX"
    ${MY_PATH}/tools/keygen  -t duniter -o ~/.zen/tmp/qrtw.dunikey "$SALT" "$PEPPER"
    WISHKEY=$(cat ~/.zen/tmp/qrtw.dunikey | grep "pub:" | cut -d ' ' -f 2)

    echo "# NOUVEAU VOEU ASTRONAUTE"
    mkdir -p ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/
    ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/qrtw.ipfskey "$SALT" "$PEPPER"
    VOEUXNS=$(ipfs key import $WISHKEY -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/qrtw.ipfskey)
    # CRYPTO BUG. TODO use natools to protect and share key with Ŋ1 only ;)
    myIP=$(hostname -I | awk '{print $1}' | head -n 1)
    echo " QR code fonctionnel sur réseau IP local (qo-op) : $myIP"

    echo "# UPGRADING WORLD WHISHKEY DATABASE"
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    mkdir -p ~/.zen/game/world/$WISHKEY/
    echo $PEPPER > ~/.zen/game/world/$WISHKEY/.pepper

    echo "# CREATION TW"
    ##########################################################################################
    # ipfs cat /ipfs/bafybeierk6mgrlwpowdcfpvibujhg2b6upjfl3gryw2k72f7smxt6cqtiu > ~/.zen/Astroport.ONE/templates/twdefault.html
    ##########################################################################################
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
    # ASTROPORT LOCAL IP RELAY == Smartphone doesn't resolve LAN DNS. So using Astroport Station IP
    sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~127.0.0.1~$myIP~g" ~/.zen/game/world/$WISHKEY/index.html

    # ADD API GW TIDDLERS for IPFS SAVE
    ##########################################################################################
    # [{"title":"$:/ipfs/saver/api/http/local/5001","tags":"$:/ipfs/core $:/ipfs/saver/api","text":"http://127.0.0.1:5001"}]
    # [{"title":"$:/ipfs/saver/gateway/local/myip","tags":"$:/ipfs/core $:/ipfs/saver/gateway","text":"http://127.0.0.1:8080"}]
    ##########################################################################################
    tiddlywiki  --verbose --load ~/.zen/game/world/$WISHKEY/index.html \
                        --import ~/.zen/Astroport.ONE/templates/data/local.api.json "application/json" \
                        --import ~/.zen/Astroport.ONE/templates/data/local.gw.json "application/json" \
                        --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"
    [[ -s ~/.zen/tmp/newindex.html ]] && cp ~/.zen/tmp/newindex.html ~/.zen/game/world/$WISHKEY/index.html

ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://'$myIP':8080", "http://127.0.0.1:8080", "http://astroport", "https://astroport.com", "https://qo-op.com", "https://tube.copylaradio.com", "http://'$(hostname)'.local:8080" ]'
## RESTART IPFS !?

    echo "# CREATION QR CODE"

    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.WISHLINK.png" "http://$myIP:8080/ipns/$VOEUXNS"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.ASTROLINK.png" "http://$myIP:8080/ipns/$ASTRONAUTENS"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.G1ASTRO.png" "$G1PUB"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.G1WISH.png" "$WISHKEY"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.IPNS.png" "/ipns/$VOEUXNS"

    # Bricolage avec node tiddlywiki (TODO add tiddler with command line)
    # A suivre .... https://talk.tiddlywiki.org/t/how-to-add-extract-modify-tiddlers-from-command-line-to-do-ipfs-media-transfer/4345/4
    # cd ~/.zen/game/world/$WISHKEY
    # tiddlywiki $WISHKEY --load ~/.zen/game/world/$WISHKEY/index.html --savewikifolder ./tw/
    # cd -

#################################
    # PREMIER TYPE /tmp/player.png
    convert $HOME/.zen/game/world/$WISHKEY/QR.WISHLINK.png -resize 300 /tmp/QRWISHLINK.png
    convert ${MY_PATH}/images/logoastro.png  -resize 220 /tmp/ASTROLOGO.png

composite -compose Over -gravity NorthWest -geometry +350+10 /tmp/ASTROLOGO.png ${MY_PATH}/images/Brother_600x400.png /tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QRWISHLINK.png /tmp/astroport.png /tmp/one.png
convert -gravity northwest -pointsize 35 -fill black -draw "text 320,250 \"$PSEUDO\"" /tmp/one.png /tmp/hop.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 20,320 \"$PEPPER\"" /tmp/hop.png /tmp/pseudo.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 320,300 \"$SALT\"" /tmp/pseudo.png /tmp/salt.png
convert -gravity northwest -pointsize 33 -fill black -draw "text 320,350 \"$PEPPER\"" /tmp/salt.png /tmp/player.png

#################################
    # SECOND TYPE /tmp/voeu.png
    convert $HOME/.zen/game/world/$WISHKEY/QR.G1WISH.png -resize 300 /tmp/G1WISH.png
    convert ${MY_PATH}/images/logojeu.png  -resize 260 /tmp/MIZLOGO.png

composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/G1WISH.png ${MY_PATH}/images/Brother_600x400.png /tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +300+0 /tmp/QRWISHLINK.png /tmp/astroport.png /tmp/one.png
composite -compose Over -gravity NorthWest -geometry +320+280 /tmp/MIZLOGO.png /tmp/one.png /tmp/two.png

convert -gravity northwest -pointsize 28 -fill black -draw "text 32,350 \"$PEPPER\"" /tmp/two.png /tmp/pep.png
convert -gravity northwest -pointsize 50 -fill black -draw "text 30,300 \"Ğ1 VOEU\"" /tmp/pep.png /tmp/voeu.png


    # IMAGE DASN IPFS
    IVOEUPLAY=$(ipfs add -Hq /tmp/player.png | tail -n 1)

    IVOEU=$(ipfs add -Hq /tmp/voeu.png | tail -n 1)
    ## Replace Template G1Voeu image
    sed -i "s~bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a~${IVOEU}~g" ~/.zen/game/world/$WISHKEY/index.html

    # NEW IVEU TIDDLER
    echo "## Creation json tiddler : Qr${PEPPER} /ipfs/${IVOEU}"
    echo '[
  {
    "title": "'Voeu${PEPPER}'",
    "type": "'image/jpeg'",
    "ipns": "'/ipns/$VOEUXNS'",
    "text": "''",
    "tags": "'$:/isAttachment $:/isEmbedded voeu ${PEPPER}'",
    "_canonical_uri": "'/ipfs/${IVOEUPLAY}'"
  }
]
' > ~/.zen/game/world/$WISHKEY/${PEPPER}.voeu.json



    rm -f ~/.zen/tmp/newindex.html

    echo "Nouveau Qr$PEPPER dans MOA $PSEUDO : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
    tiddlywiki --verbose --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html \
                    --import ~/.zen/game/world/$WISHKEY/${PEPPER}.voeu.json "application/json" \
                    --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

    echo "PLAYER TW Update..."
    if [[ -s ~/.zen/tmp/newindex.html ]]; then
        echo "Mise à jour ~/.zen/game/players/$PLAYER/ipfs/moa/index.html"
        cp -f ~/.zen/tmp/newindex.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
        MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
        echo "Avancement blockchain TW $PLAYER : $MOATS"
        cp ~/.zen/game/players/$PLAYER/ipfs/moa/.chain ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.old

        TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
        echo "ipfs name publish --key=$PLAYER /ipfs/$TW"
        ipfs name publish --key=$PLAYER /ipfs/$TW

        # MAJ CACHE TW $PLAYER
        echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
        echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
        echo
    fi

    # PRINTING
    LP=$(ls /dev/usb/lp* | head -n1)
    [[ ! $LP ]] && echo "NO PRINTER FOUND - Brother QL700 validated"
    echo "IMPRESSION VOEU"
    brother_ql_create --model QL-700 --label-size 62 /tmp/player.png > /tmp/toprint.bin 2>/dev/null
    sudo brother_ql_print /tmp/toprint.bin $LP
    brother_ql_create --model QL-700 --label-size 62 /tmp/voeu.png > /tmp/toprint.bin 2>/dev/null
    sudo brother_ql_print /tmp/toprint.bin $LP

    # COPY QR CODE TO PLAYER ZONE
    cp /tmp/player.png /tmp/voeu.png ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/
    echo "$PEPPER" > ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/.title
    echo "http://$myIP:8080/ipns/$VOEUXNS" > ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/.link
    cp ~/.zen/game/world/$WISHKEY/QR.WISHLINK.png ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/

    # PUBLISHING
    echo "## ${PLAYER} RECORDING YOU WISH INTO BLOCKCHAIN"
    echo "ipfs add -Hq ~/.zen/game/world/$WISHKEY/index.html
    ipfs name publish --key=${WISHKEY} /ipfs/\$IPUSH"
    IPUSH=$(ipfs add -Hq ~/.zen/game/world/$WISHKEY/index.html | tail -n 1)
    ipfs name publish --key=${WISHKEY} /ipfs/$IPUSH 2>/dev/null

    echo $IPUSH > ~/.zen/game/world/$WISHKEY/.chain
    echo $MOATS > ~/.zen/game/world/$WISHKEY/.moats

    ## Creating Cesium+ Profil
    $MY_PATH/tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey -n "https://g1.data.presles.fr" set --name "G1Voeu $PEPPER" --avatar "/home/$USER/.zen/Astroport.ONE/images/logojune.jpg" --site "https://astroport.com/ipns/$VOEUXNS" #CESIUM+
    [[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED !!!!"


    echo "Astronaute Ŋ1 : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"

    echo "CAPSULE A REVE $PEPPER : http://127.0.0.1:8080/ipns/$VOEUXNS"


done

exit 0
