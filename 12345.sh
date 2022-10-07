#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
## Collect email / phrase 1 / phrase 2 Form
## Generate / Find key & Astronaut PLAYER
## Return TW

MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID)

## CHECK FOR ANY ALREADY RUNNING nc
ncrunning=$(ps auxf --sort=+utime | grep -w 'nc -l -p 1234' | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1)
[[ $ncrunning ]] && echo "already running" && exit 1

myIP=$(hostname -I | awk '{print $1}' | head -n 1)

# Check if Astroport Station already has a "captain"
echo "Register and Connect Astronaut with http://$myIP:1234/?email=&ph1=&ph2="

[[ $DISPLAY ]] && xdg-open "file://$HOME/.zen/Astroport.ONE/templates/instascan.html" 2>/dev/null

function urldecode() { : "${*//+/ }"; echo -e "${_//%/\\x}"; }

while true; do

    # REPLACE myIP in http response template
    sed "s~127.0.0.1~$myIP~g" $HOME/.zen/Astroport.ONE/templates/index.http > ~/.zen/tmp/myIP.http
    URL=$(cat $HOME/.zen/tmp/myIP.http | nc -l -p 1234 -q 1 | grep '^GET' | cut -d ' ' -f2  | cut -d '?' -f2)

    echo "=================================================="
    echo "GET RECEPTION : $URL"
    arr=(${URL//[=&]/ })
    echo "PARAM : ${arr[0]} = ${arr[1]} & ${arr[2]} = ${arr[3]} & ${arr[4]} = ${arr[5]}"

#######################################
### WAITING WITH SELF REDIRECT
rm ~/.zen/tmp/index.redirect
###################################################################################################
while [[ ! -f ~/.zen/tmp/index.redirect && ! $(ps auxf --sort=+utime | grep -w 'nc -l -p 12345' | grep -v -E 'color=auto|grep') ]]; do cat $HOME/.zen/tmp/myIP.http | nc -l -p 12345 -q 1; done &
###################################################################################################

    if [[ ${arr[0]} == "email" ]]; then
    start=`date +%s`

        EMAIL=$(urldecode ${arr[1]})
        SALT=$(urldecode ${arr[3]})
        PEPPER=$(urldecode ${arr[5]})

                PLAYER="$EMAIL"
                PSEUDO=$(echo $PLAYER | cut -d '@' -f 1)
                PSEUDO=${PSEUDO,,}; PSEUDO=${PSEUDO%%[0-9]*}
                # PASS CRYPTING KEY
                PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

            echo "$SALT"
            echo "$PEPPER"

            # CHECK IPNS KEY EXISTENCE
            ipfs key rm gchange 2>/dev/null
            rm -f ~/.zen/tmp/gchange.key
            ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/tmp/gchange.key '$SALT' '$PEPPER'
            GNS=$(ipfs key import gchange -f pem-pkcs8-cleartext ~/.zen/tmp/gchange.key )
            echo "/ipns/$GNS"

            echo "Getting latest online TW..."
            mkdir -p ~/.zen/tmp/TW
            rm -f ~/.zen/tmp/TW/index.html
            YOU=$(ps auxf --sort=+utime | grep -w "ipfs" | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
            LIBRA=$(head -n 2 ~/.zen/Astroport.ONE/A_boostrap_nodes.txt | tail -n 1 | cut -d ' ' -f 2)
            echo "$LIBRA/ipns/$GNS"

            [[ $YOU ]] && ipfs --timeout 12s cat  /ipns/$GNS > ~/.zen/tmp/TW/index.html \
                                || curl -m 12 -so ~/.zen/tmp/TW/index.html "$LIBRA/ipns/$GNS"

            if [ ! -s ~/.zen/tmp/TW/index.html ]; then

                echo "Aucun TW détecté! Creation TW Astronaute"
                ###################################################################################################

                echo "PASS=$PASS"
                ${MY_PATH}/tools/keygen -t duniter -o /tmp/secret.dunikey '$SALT' '$PEPPER'
                echo "key genesis"
                G1PUB=$(cat /tmp/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)

                [[ ! $G1PUB ]] && echo "ERREUR. clef Cesium absente." && exit 1

                    ## CREATE Player personnal files storage and IPFS publish directory
                    mkdir -p ~/.zen/game/players/$PLAYER # Prepare PLAYER datastructure
                    mkdir -p ~/.zen/tmp/

                    mv /tmp/secret.dunikey ~/.zen/game/players/$PLAYER/


                    # Create Player "IPNS Key" (key import)
                    ${MY_PATH}/tools/keygen -t ipfs -o ~/.zen/game/players/$PLAYER/secret.player '$SALT' '$PEPPER'
                    ipfs key import $PLAYER -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/secret.player
                    ipfs key import $G1PUB -f pem-pkcs8-cleartext ~/.zen/game/players/$PLAYER/secret.player

                    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/G1SSB # Prepare astrXbian sub-datastructure
                    mkdir -p ~/.zen/game/players/$PLAYER/ipfs_swarm

                    qrencode -s 12 -o ~/.zen/game/players/$PLAYER/QR.png "$G1PUB"
                    cp ~/.zen/game/players/$PLAYER/QR.png ~/.zen/game/players/$PLAYER/ipfs/QR.png
                    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/ipfs/G1SSB/_g1.pubkey # G1SSB NOTATION (astrXbian compatible)

                    secFromDunikey=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep "sec" | cut -d ' ' -f2)
                    echo "$secFromDunikey" > /tmp/${PSEUDO}.sec
                    openssl enc -aes-256-cbc -salt -in /tmp/${PSEUDO}.sec -out "/tmp/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
                    PASsec=$(cat /tmp/enc.${PSEUDO}.sec | base58) && rm -f /tmp/${PSEUDO}.sec
                    qrencode -s 12 -o $HOME/.zen/game/players/$PLAYER/QRsec.png $PASsec

                    echo "Votre Clef publique G1 est : $G1PUB"; sleep 1

                    ### INITALISATION WIKI dans leurs répertoires de publication IPFS
                    ############ TODO améliorer templates, sed, ajouter index.html, etc...
                    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
                    echo "Nouveau Canal TW Astronaute"
                    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/moa/

                    cp ~/.zen/Astroport.ONE/templates/twdefault.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~_WISHKEY_~${G1PUB}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

                    sed -i "s~_G1PUB_~${G1PUB}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~_QRSEC_~${PASsec}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

                    sed -i "s~G1Voeu~G1Visa~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~Moa~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html


                    GNS=$(ipfs key list -l | grep -w "${PLAYER}" | cut -d ' ' -f 1)
                    # La Clef IPNS porte comme nom G1PUB et PLAYER
                    sed -i "s~_MEDIAKEY_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~k2k4r8kxfnknsdf7tpyc46ks2jb3s9uvd3lqtcv9xlq9rsoem7jajd75~${GNS}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

                    myIP=$(hostname -I | awk '{print $1}' | head -n 1)
                    sed -i "s~127.0.0.1~$myIP~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html
                    sed -i "s~_SECRET_~$myIP~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html # Use ''{{MadeInZion!!secret}}'' field to change KeyKeeper Gateway IP

                    ## ADD SYSTEM TW
                    tiddlywiki  --load ~/.zen/game/players/$PLAYER/ipfs/moa/index.html \
                                        --import ~/.zen/Astroport.ONE/templates/data/local.api.json "application/json" \
                                        --import ~/.zen/Astroport.ONE/templates/data/local.gw.json "application/json" \
                                        --output ~/.zen/tmp --render "$:/core/save/all" "newindex.html" "text/plain"

                    [[ -s ~/.zen/tmp/newindex.html ]] && cp ~/.zen/tmp/newindex.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

                    ## ID CARD
                    convert ~/.zen/game/players/$PLAYER/QR.png -resize 300 /tmp/QR.png
                    convert ${MY_PATH}/images/astroport.jpg  -resize 300 /tmp/ASTROPORT.png

                    composite -compose Over -gravity SouthWest -geometry +280+20 /tmp/ASTROPORT.png ${MY_PATH}/images/Brother_600x400.png /tmp/astroport.png
                    composite -compose Over -gravity NorthWest -geometry +0+0 /tmp/QR.png /tmp/astroport.png /tmp/one.png
                    # composite -compose Over -gravity NorthWest -geometry +280+280 ~/.zen/game/players/.current/QRsec.png /tmp/one.png /tmp/image.png

                    convert -gravity northwest -pointsize 35 -fill black -draw "text 50,300 \"$PSEUDO\"" /tmp/one.png /tmp/image.png
                    convert -gravity northwest -pointsize 30 -fill black -draw "text 300,40 \"$PLAYER\"" /tmp/image.png /tmp/pseudo.png
                    convert -gravity northeast -pointsize 25 -fill black -draw "text 20,180 \"$PASS\"" /tmp/pseudo.png /tmp/pass.png
                    convert -gravity northwest -pointsize 25 -fill black -draw "text 300,100 \"$SALT\"" /tmp/pass.png /tmp/salt.png
                    convert -gravity northwest -pointsize 25     -fill black -draw "text 300,140 \"$PEPPER\"" /tmp/salt.png ~/.zen/game/players/$PLAYER/ID.png

                    # INSERTED IMAGE IPFS
                    IASTRO=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ID.png | tail -n 1)
                    sed -i "s~bafybeidhghlcx3zdzdah2pzddhoicywmydintj4mosgtygr6f2dlfwmg7a~${IASTRO}~g" ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

                    ## MEMORISE PLAYER Ŋ1 ZONE
                    echo "$PLAYER" > ~/.zen/game/players/$PLAYER/.player
                    echo "$PSEUDO" > ~/.zen/game/players/$PLAYER/.pseudo
                    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/.g1pub
                    echo "$GNS" > ~/.zen/game/players/$PLAYER/.playerns
                    echo "$SALT" > ~/.zen/game/players/$PLAYER/secret.june
                    echo "$PEPPER" >> ~/.zen/game/players/$PLAYER/secret.june

                    rm -f ~/.zen/game/players/.current
                    ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

                    qrencode -s 12 -o "$HOME/.zen/game/players/$PLAYER/QR.GNS.png" "http://127.0.0.1:8080/ipns/$GNS"
                    echo; echo "Création de votre clef et QR codes de votre réseau Astroport Ŋ1"

                    echo; echo "*** Espace Astronaute Activé : ~/.zen/game/players/$PLAYER/"
                    echo; echo "*** Votre TW Ŋ7 : $PLAYER"; echo "http://$myIP:8080/ipns/$GNS"


                    echo; echo "Sécurisation de vos clefs par chiffrage SSL... "; sleep 1
                    openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.june" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.june" -k $PASS 2>/dev/null
                    openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.dunikey" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.dunikey" -k $PASS 2>/dev/null
                    openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/$KEYFILE -out" "$HOME/.zen/game/players/$PLAYER/enc.$KEYFILE" -k $PASS 2>/dev/null
                    ## TODO MORE SECURE ?! USE opengpg, natools, etc ...
                    # ${MY_PATH}/natools.py encrypt -p $G1PUB -i ~/.zen/game/players/$PLAYER/secret.dunikey -o "$HOME/.zen/game/players/$PLAYER/secret.dunikey.oasis"

                    #################################################
                    # !! TODO !! # DEMO MODE. REMOVE FOR PRODUCTION
                    echo "$PASS" > ~/.zen/game/players/$PLAYER/.pass
                    # ~/.zen/game/players/$PLAYER/secret.june SECURITY TODO
                    # Astronaut QRCode + PASS = LOGIN (=> DECRYPTING CRYPTO IPFS INDEX)
                    # TODO : Allow Astronaut PASS change ;)
                    #####################################################

                    ## DISCONNECT AND CONNECT CURRENT PLAYER
                    rm -f ~/.zen/game/players/.current
                    ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

                    ## CREATE GCHANGE+ PROFILE
                    ${MY_PATH}/tools/Connect_PLAYER_To_Gchange.sh

                    ## INIT FRIENDSHIP CAPTAIN/ASTRONAUTS (LATER THROUGH GCHANGE)
                    ## ${MY_PATH}/FRIENDS.init.sh
                    ## NO. GCHANGE+ IS THE MAIN INTERFACE, astrXbian manage
                    echo "Bienvenue 'Astronaute' $PSEUDO ($PLAYER)"
                    echo "Retenez votre PASS : $PASS"

                    cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html  ~/.zen/tmp/TW/index.html

                ###################################################################################################
            else

                # Get MadeInZion secret
                tiddlywiki --load ~/.zen/tmp/TW/index.html --output ~/.zen/tmp --render '.' 'miz.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' 'MadeInZion'
                OLDIP=$(cat ~/.zen/tmp/miz.json | jq -r .[].secret)

                ##
                if [[ ! d ~/.zen/game/players/$PLAYER/ipfs/moa ]]; then
                    echo "MISSING ASTRONAUT VISA"
                    echo "ASKING TO $OLDIP"

                    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/moa
                fi

                    # myIP replacement
                    sed -i "s~_SECRET_~$myIP~g" ~/.zen/tmp/TW/index.html
                    sed -i "s~$OLDIP~$myIP~g" ~/.zen/tmp/TW/index.html

                cp ~/.zen/tmp/TW/index.html ~/.zen/game/players/$PLAYER/ipfs/moa/index.html

            fi


                ###################################################################################################
                echo "## PUBLISHING ${PLAYER} /ipns/$GNS/"
                IPUSH=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
                echo $IPUSH > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain # Contains last IPFS backup PLAYER KEY
                echo "/ipfs/$IPUSH"
                echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
                ipfs name publish --key=${PLAYER} /ipfs/$IPUSH 2>/dev/null

                ###################################################################################################
                # EXTRACTION MOA
                rm -f ~/.zen/tmp/tiddlers.json
                tiddlywiki --load ~/.zen/tmp/TW/index.html --output ~/.zen/tmp --render '.' 'tiddlers.json' 'text/plain' '$:/core/templates/exporters/JsonFile' 'exportFilter' '[tag[moa]]'
                TITLE=$(cat ~/.zen/tmp/tiddlers.json | jq -r '.[].title') # Dessin de PLAYER
                PLAYER=$(echo $TITLE | rev | cut -f 1 -d ' ' | rev)

                echo "Bienvenue Astronaute $PLAYER. Nous avons capté votre TW"
                echo "Redirection"
                [[ $YOU ]] && TWLINK="http://$myIP:8080/ipns/$GNS" \
                                    || TWLINK="$LIBRA/ipns/$GNS"
                echo "$TWLINK"

                # Injection TWLINK dans template de redirection.
                sed "s~_TWLINK_~$TWLINK~g" ~/.zen/Astroport.ONE/templates/index.redirect  > ~/.zen/tmp/index.redirect

                ## Attente cloture WAITING 12345. Puis Lancement one shot http server
                while [[ $(ps auxf --sort=+utime | grep -w 'nc -l -p 12345' | grep -v -E 'color=auto|grep') ]]; do sleep 0.5; done
                cat ~/.zen/tmp/index.redirect | nc -l -p 12345 -q 1 &

                ###################################################################################################
                end=`date +%s`
                echo Execution time was `expr $end - $start` seconds.

    fi

###################################################################################################
###################################################################################################
    if [[ ${arr[0]} == "qrcode" ]]; then
        ## Astroport.ONE local use QRCODE Contains PLAYER G1PUB
        QRCODE=$(echo $URL | cut -d ' ' -f2 | cut -d '=' -f 2 | cut -d '&' -f 1)   && echo "Instascan.html QR : $QRCODE"
        g1pubpath=$(grep $QRCODE ~/.zen/game/players/*/.g1pub | cut -d ':' -f 1 2>/dev/null)
        PLAYER=$(echo "$g1pubpath" | rev | cut -d '/' -f 2 | rev 2>/dev/null)

        ## FORCE LOCAL USE ONLY. Remove to open 1234 API
        [[ ! -d ~/.zen/game/players/$PLAYER || $PLAYER == "" ]] && echo "AUCUN PLAYER !!" && exit 1

        ## UNE SECOND HTTP SERVER TO RECEIVE PASS

        [[ ${arr[2]} == "" ]] && continue

        if [[ ${arr[2]} == "TX" ]]; then
            echo "ASK FOR VISA TRANSFER FROM "
        fi

    fi

###################################################################################################
###################################################################################################
    ## Demande de copie d'une URL reçue.
    if [[ ${arr[0]} == "qrcode" &&  ${arr[2]} == "url" ]]; then
        wsource="${arr[3]}"
         [[ ${arr[4]} == "type" ]] && wtype="${arr[5]}" || wtype="Youtube"

        ## LANCEMENT COPIE
        ~/.zen/Astropor.ONE/ajouter_video.sh "$(urldecode $wsource)" "$wtype" "$QRCODE" &

        echo "$QRCODE $wsource"

    fi

    ## ENVOYER MESSAGE GCHANGE POUR QRCODE

    ## Une seule boucle !!!
    [[ "$1" == "ONE" ]] && exit 0

done
exit 0
