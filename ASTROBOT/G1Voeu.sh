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
# Create G1VOEU TW for PLAYER
# Mon Titre => G1MonTitre => PEPPER
## PARAM : "TITRE DU VOEU" "PLAYER" "INDEX"
################################################################################
TITRE="$1"
PLAYER="$2"
INDEX="$3"

[[ $PLAYER == "" ]] && PLAYER=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ $PLAYER == "" ]] && echo "Second paramètre PLAYER manquant" && exit 1
PSEUDO=$(cat ~/.zen/game/players/$PLAYER/.pseudo 2>/dev/null)
[[ $G1PUB == "" ]] && G1PUB=$(cat ~/.zen/game/players/$PLAYER/.g1pub 2>/dev/null)
[[ $G1PUB == "" ]] && echo "Troisième paramètre G1PUB manquant" && exit 1

[[ ! $INDEX ]] && echo "MISSING ASTRONAUTE TW index.html - EXIT -" && exit 1

echo "Working on $INDEX"

ASTRONAUTENS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
[[ $ASTRONAUTENS == "" ]] && echo "CLEF IPNS ASTRONAUTE MANQUANTE - EXIT -" && exit 1

echo "Bienvenue $PSEUDO ($PLAYER) : $G1PUB"
echo

######################################################################


#####################################################
# CREATION DU TW G1VOEU
#####################################################
    SALT=$(${MY_PATH}/../tools/diceware.sh 3 | xargs)
    echo "$SALT"

    echo "## TITRE POUR CE VOEU ? "
    [[ ! $TITRE ]] && read TITRE
    PEPPER=$(echo "$TITRE" | sed -r 's/\<./\U&/g' | sed 's/ //g') # CapitalGluedWords
    echo "$PEPPER" && [[ ! $PEPPER ]] && echo "EMPTY PEPPER - ERROR" && exit 1

    echo "## keygen CLEF DE VOEUX"
    ${MY_PATH}/../tools/keygen  -t duniter -o ~/.zen/tmp/qrtw.dunikey "$SALT" "$PEPPER"
    WISHKEY=$(cat ~/.zen/tmp/qrtw.dunikey | grep "pub:" | cut -d ' ' -f 2)
    echo "WISHKEY (G1PUB) = $WISHKEY"

    echo "# NOUVEAU VOEU"
    mkdir -p ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/
    ${MY_PATH}/../tools/keygen -t ipfs -o ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/qrtw.ipfskey "$SALT" "$PEPPER"
    ipfs key import $WISHKEY -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/qrtw.ipfskey
    VOEUNS=$(ipfs key list -l | grep -w "$WISHKEY" | cut -d ' ' -f 1 )
    echo "/ipns/$VOEUNS"

    ## TEST IPFS
    ipfs --timeout=6s cat /ipns/$VOEUNS > ~/.zen/tmp/$VOEUNS.html
    [[ -s ~/.zen/tmp/$VOEUNS.html ]] && echo "HEY !!! UN TW EXISTE POUR CE VOEU !  ~/.zen/tmp/$VOEUNS.html  - EXIT -" && exit 1

    # CRYPTO BUG. TODO use natools to protect and share key with Ŋ1 only ;)
    myIP=$(hostname -I | awk '{print $1}' | head -n 1)
    echo " Passerelle : $myIP"

    echo "# UPGRADING WORLD WHISHKEY DATABASE"
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

    mkdir -p ~/.zen/game/world/$WISHKEY/
    ## A la fois Titre du tag et Pepper construction de clef
    echo $PEPPER > ~/.zen/game/world/$WISHKEY/.pepper

    echo "# CREATION TW"
    ##########################################################################################
    # ipfs key import _MEDIAKEY_ ~/.zen/Astroport.ONE/templates/_MEDIAKEY_.keystore.key
    ##############
    # ipfs cat /ipfs/bafybeibqdoegifzejykmc3qw3e3drgsa5i7az6xwjlfcx7rbtcoj5unpkq > ~/.zen/Astroport.ONE/templates/twdefault.html
    # INTRODUCE HIDING CONTROL (read only from https) https $:/tags/Stylesheet
    # ipfs cat /ipfs/bafybeidkur2tfbmqwscgmkfh76vmbcqay2m4gznxv5emkenxeffmrgywky > ~/.zen/Astroport.ONE/templates/twdefault.html
    ##########################################################################################
    cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/world/$WISHKEY/index.html
    # TODO : CREATE ONE TEMPLATE / REMOVE USELESS TID

    # PERSONNALISATION "MadeInZion"
    sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_WISHKEY_~${WISHKEY}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_NUMBER_~${SALT}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_SECRET_~${PEPPER}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_ASTROPORT_~${ASTRONAUTENS}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~_QRSEC_~${myIP}~g" ~/.zen/game/world/$WISHKEY/index.html

    # IPNS KEY is WISHKEY / VOEUNS
    sed -i "s~_MEDIAKEY_~${WISHKEY}~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~k2k4r8kxfnknsdf7tpyc46ks2jb3s9uvd3lqtcv9xlq9rsoem7jajd75~${VOEUNS}~g" ~/.zen/game/world/$WISHKEY/index.html

    # ASTROPORT LOCAL IP RELAY == Smartphone doesn't resolve LAN DNS. So using Astroport Station IP
    sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/world/$WISHKEY/index.html
    sed -i "s~127.0.0.1~$myIP~g" ~/.zen/game/world/$WISHKEY/index.html

    # ADD API GW TIDDLERS for IPFS SAVE
    ##########################################################################################
    # [{"title":"$:/ipfs/saver/api/http/local/5001","tags":"$:/ipfs/core $:/ipfs/saver/api","text":"http://127.0.0.1:5001"}]
    # [{"title":"$:/ipfs/saver/gateway/local/myip","tags":"$:/ipfs/core $:/ipfs/saver/gateway","text":"http://127.0.0.1:8080"}]
    ##########################################################################################
    tiddlywiki  --load ~/.zen/game/world/$WISHKEY/index.html \
                        --import ~/.zen/Astroport.ONE/templates/data/local.api.json "application/json" \
                        --import ~/.zen/Astroport.ONE/templates/data/local.gw.json "application/json" \
                        --deletetiddlers '"Dessin de Moa"' \
                        --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

    [[ -s ~/.zen/tmp/newindex.html ]] && cp ~/.zen/tmp/newindex.html ~/.zen/game/world/$WISHKEY/index.html
    [[ ! -s ~/.zen/tmp/newindex.html ]] && echo "ERROR ~/.zen/tmp/newindex.html  MISSING" && exit 1

## EXTEND ipfs daemon accreditation
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["http://'$myIP':8080", "http://127.0.0.1:8080", "http://astroport:8080", "http://astroport.com:8080", "https://astroport.com", "https://qo-op.com", "http://qo-op.com:8080", "https://tube.copylaradio.com", "http://'$(hostname)'.local:8080" ]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin ## CORS
echo "RESTART IPFS !?"

    echo "# CREATION QR CODE"

    LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
    LIBRA="http://qo-op.com:8080"

    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.WISHLINK.png" "$LIBRA/ipns/$VOEUNS"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.ASTROLINK.png" "$LIBRA/ipns/$ASTRONAUTENS"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.G1ASTRO.png" "$G1PUB"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.G1WISH.png" "$WISHKEY"
    qrencode -s 12 -o "$HOME/.zen/game/world/$WISHKEY/QR.IPNS.png" "/ipns/$VOEUNS"

    # Bricolage avec node tiddlywiki (TODO add tiddler with command line)
    # A suivre .... https://talk.tiddlywiki.org/t/how-to-add-extract-modify-tiddlers-from-command-line-to-do-ipfs-media-transfer/4345/4
    # cd ~/.zen/game/world/$WISHKEY
    # tiddlywiki $WISHKEY --load ~/.zen/game/world/$WISHKEY/index.html --savewikifolder ./tw/
    # cd -

#################################
    # PREMIER TYPE ~/.zen/tmp/player.png
    convert $HOME/.zen/game/world/$WISHKEY/QR.WISHLINK.png -resize 300 ~/.zen/tmp/QRWISHLINK.png
    convert ${MY_PATH}/../images/logoastro.png  -resize 220 ~/.zen/tmp/ASTROLOGO.png

composite -compose Over -gravity NorthWest -geometry +350+10 ~/.zen/tmp/ASTROLOGO.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +0+0 ~/.zen/tmp/QRWISHLINK.png ~/.zen/tmp/astroport.png ~/.zen/tmp/one.png
convert -gravity northwest -pointsize 35 -fill black -draw "text 320,250 \"$PLAYER\"" ~/.zen/tmp/one.png ~/.zen/tmp/hop.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 20,320 \"$PEPPER\"" ~/.zen/tmp/hop.png ~/.zen/tmp/pseudo.png
convert -gravity northwest -pointsize 30 -fill black -draw "text 320,300 \"$SALT\"" ~/.zen/tmp/pseudo.png ~/.zen/tmp/salt.png
convert -gravity northwest -pointsize 33 -fill black -draw "text 320,350 \"$PEPPER\"" ~/.zen/tmp/salt.png ~/.zen/tmp/player.png

#################################
    # SECOND TYPE ~/.zen/tmp/voeu.png
    convert $HOME/.zen/game/world/$WISHKEY/QR.G1WISH.png -resize 300 ~/.zen/tmp/G1WISH.png
    convert ${MY_PATH}/../images/logojeu.png  -resize 260 ~/.zen/tmp/MIZLOGO.png

composite -compose Over -gravity NorthWest -geometry +0+0 ~/.zen/tmp/G1WISH.png ${MY_PATH}/../images/Brother_600x400.png ~/.zen/tmp/astroport.png
composite -compose Over -gravity NorthWest -geometry +300+0 ~/.zen/tmp/QRWISHLINK.png ~/.zen/tmp/astroport.png ~/.zen/tmp/one.png
composite -compose Over -gravity NorthWest -geometry +320+280 ~/.zen/tmp/MIZLOGO.png ~/.zen/tmp/one.png ~/.zen/tmp/two.png

convert -gravity northwest -pointsize 28 -fill black -draw "text 32,350 \"Ğ1 VOEU\"" ~/.zen/tmp/two.png ~/.zen/tmp/pep.png
convert -gravity northwest -pointsize 50 -fill black -draw "text 30,300 \"$PEPPER\"" ~/.zen/tmp/pep.png ~/.zen/tmp/voeu.png

    # IMAGE DANS IPFS
    IVOEUPLAY=$(ipfs add -Hq ~/.zen/tmp/player.png | tail -n 1)

    IVOEU=$(ipfs add -Hq ~/.zen/tmp/voeu.png | tail -n 1)
    ## Replace Template G1Voeu image
    sed -i "s~bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a~${IVOEU}~g" ~/.zen/game/world/$WISHKEY/index.html

#    TEXT="<a target='_blank' href='"/ipns/${VOEUNS}"'><img src='"/ipfs/${IVOEUPLAY}"'></a><br><br><a target='_blank' href='"/ipns/${VOEUNS}"'>"${PEPPER}"</a>"
#:[tag[G1CopierYoutube]] [tag[pdf]]
    # Contains QRCode linked to G1VoeuTW and BUTTON listing G1Voeux
    TEXT="<a target='_blank' href='#:[tag[G1"$PEPPER"]]' ><img src='"/ipfs/${IVOEUPLAY}"'></a>
    <br><a target='_blank' href='"/ipns/${VOEUNS}"'>TW G1Voeu "$PLAYER"</a><br><br>
    <\$button class='tc-tiddlylink'>
    <\$list filter='[tag[G1"${PEPPER}"]]'>
   <\$action-navigate \$to=<<currentTiddler>> \$scroll=no/>
    </\$list>
    Afficher tous les G1"${PEPPER}"
    </$button>"

    # NEW IVEU TIDDLER
    echo "## Creation json tiddler : Qr${PEPPER} /ipfs/${IVOEU}"
    echo '[
  {
    "title": "'${PEPPER}'",
    "type": "'text/vnd.tiddlywiki'",
    "astronautens": "'$ASTRONAUTENS'",
    "ipns": "'$VOEUNS'",
    "wish": "'$WISHKEY'",
    "text": "'$TEXT'",
    "tags": "'G1Voeu G1${PEPPER} ${PLAYER}'"
  }
]
' > ~/.zen/game/world/$WISHKEY/${PEPPER}.voeu.json



    rm -f ~/.zen/tmp/newindex.html

    echo "Nouveau Qr$PEPPER dans MOA $PSEUDO : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
    tiddlywiki --verbose --load $INDEX \
                        --deletetiddlers '[tag[voeu]]' \
                        --import ~/.zen/game/world/$WISHKEY/${PEPPER}.voeu.json "application/json" \
                        --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

    echo "PLAYER TW Update..."
    if [[ -s ~/.zen/tmp/newindex.html ]]; then
        echo "Mise à jour $INDEX"
        cp -f ~/.zen/tmp/newindex.html $INDEX
    else
        echo "ERROR INTO ~/.zen/game/world/$WISHKEY/${PEPPER}.voeu.json"
    fi

    # PRINTING
    LP=$(ls /dev/usb/lp* | head -n1)
    if [[ ! $LP ]]; then
        echo "NO PRINTER FOUND - Plug a Brother QL700 or Add your printer"
    else
        echo "IMPRESSION VOEU"
        brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/player.png > ~/.zen/tmp/toprint.bin 2>/dev/null
        sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP
        brother_ql_create --model QL-700 --label-size 62 ~/.zen/tmp/voeu.png > ~/.zen/tmp/toprint.bin 2>/dev/null
        sudo brother_ql_print ~/.zen/tmp/toprint.bin $LP
    fi

    # COPY QR CODE TO PLAYER ZONE
    cp ~/.zen/tmp/player.png ~/.zen/tmp/voeu.png ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/
    echo "$PEPPER" > ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/.title
    echo "http://$myIP:8080/ipns/$VOEUNS" > ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/.link
    cp ~/.zen/game/world/$WISHKEY/QR.WISHLINK.png ~/.zen/game/players/$PLAYER/voeux/$WISHKEY/

    # PUBLISHING
    echo "## ${PLAYER} RECORDING YOU WISH INTO IPFS"
    echo "ipfs add -Hq ~/.zen/game/world/$WISHKEY/index.html
    ipfs name publish --key=${WISHKEY} /ipfs/\$IPUSH"
    IPUSH=$(ipfs add -Hq ~/.zen/game/world/$WISHKEY/index.html | tail -n 1)
    ipfs name publish --key=${WISHKEY} /ipfs/$IPUSH 2>/dev/null

    echo $IPUSH > ~/.zen/game/world/$WISHKEY/.chain
    echo $MOATS > ~/.zen/game/world/$WISHKEY/.moats

    echo
    echo "Astronaute TW : http://127.0.0.1:8080/ipns/$ASTRONAUTENS"
    echo "Nouveau G1Voeu : $PEPPER (document de contrôle de copie Ŋ1)"
    echo "TW $PEPPER : http://127.0.0.1:8080/ipns/$VOEUNS"

    echo "## TO RECEIVE G1RONDS Creating Cesium+ Profil #### timeout long ... patience ...."
    $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/tmp/qrtw.dunikey -n "https://g1.data.presles.fr" set --name "G1Voeu $PEPPER" --avatar "/home/$USER/.zen/Astroport.ONE/images/logojune.jpg" --site "https://astroport.com/ipns/$VOEUNS" #CESIUM+
    [[ ! $? == 0 ]] && echo "CESIUM PROFILE CREATION FAILED !!!!"

    echo "************************************************************"
    echo "Hop, UNE JUNE pour le Voeu $PEPPER"
    echo $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey pay -a 1 -p $WISHKEY -c \'"$VOEUNS G1Voeu $PEPPER"\' -m
    echo "************************************************************"

    $MY_PATH/../tools/jaklis/jaklis.py -k ~/.zen/game/players/$PLAYER/secret.dunikey pay -a 1 -p $WISHKEY -c "$VOEUXNS G1Voeu $PEPPER" -m
    echo "************************************************************"

exit 0
