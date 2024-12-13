#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "${MY_PATH}/tools/my.sh"

TS=$(date -u +%s%N | cut -b1-13)
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
#~ mkdir -p ~/.zen/tmp/${MOATS}

### CHECK and CORRECT .current
CURRENT=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
[[ ${CURRENT} == "" ]] \
    && lastplayer=$(ls -t ~/.zen/game/players 2>/dev/null | grep "@" | head -n 1) \
    && [[ ${lastplayer} ]] \
    && rm ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${lastplayer} ~/.zen/game/players/.current && CURRENT=${lastplayer}

UPLANETG1PUB=$(${MY_PATH}/tools/keygen -t duniter "${UPLANETNAME}" "${UPLANETNAME}")

echo '
    _    ____ _____ ____   ___  ____   ___  ____ _____    ___  _   _ _____
   / \  / ___|_   _|  _ \ / _ \|  _ \ / _ \|  _ \_   _|  / _ \| \ | | ____|
  / _ \ \___ \ | | | |_) | | | | |_) | | | | |_) || |   | | | |  \| |  _|
 / ___ \ ___) || | |  _ <| |_| |  __/| |_| |  _ < | |   | |_| | |\  | |___
/_/   \_\____/ |_| |_| \_\\___/|_|    \___/|_| \_\|_|    \___/|_| \_|_____|

Astroport is a Web3 engine running UPlanet hosting TW5s on IPFS, and more...
'${IPFSNODEID}'

@@@@@@@@@@@@@@@@@@
CAPTAIN = '${CURRENT}'
on UPLANET = '${UPLANETG1PUB}'
@@@@@@@@@@@@@@@@@@'
echo

## VERIFY SOFTWARE DEPENDENCIES
[[ ! $(which ipfs) ]] && echo "EXIT. Vous devez avoir installé ipfs CLI sur votre ordinateur" && echo "https://dist.ipfs.io/#go-ipfs" && exit 1
YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER")
[[ ! $YOU ]] && echo "Lancez 'ipfs daemon' SVP sudo systemctl start ipfs" && exit 1


if [[ ${CURRENT} == "" ]]; then
    ## NO CAPTAIN
    echo "NO CAPTAIN ONBOARD !!!"
fi

echo 'PRESS CTRL+C or ENTER... '; read
## CREATE AND OR CONNECT USER
PS3=' ____ Select  ___ ? '
players=( "NEW PLAYER" "PRINT ZENCARD" $(ls ~/.zen/game/players  | grep "@" 2>/dev/null))
## MULTIPLAYER

select fav in "${players[@]}"; do
    case $fav in
    "PRINT ZENCARD")
        ## DIRECT VISA.print.sh
        echo "'Email ?'"
        read EMAIL
        [[ ${EMAIL} == "" ]] && EMAIL=$(cat ~/.zen/game/players/.current/.player 2>/dev/null)
        echo "'Secret 1 ?'"
        read SALT
        [[ ${SALT} == "" ]] && SALT=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
        echo "'Secret 2?'"
        read PEPPER
        [[ ${PEPPER} == "" ]] && PEPPER=$(${MY_PATH}/tools/diceware.sh 4 | xargs)
        echo "'PIN ?'"
        read PASS
        echo "${MY_PATH}/tools/VISA.print.sh" "${EMAIL}"  "'"$SALT"'" "'"$PEPPER"'" "'"$PASS"'"
        ${MY_PATH}/tools/VISA.print.sh "${EMAIL}"  "$SALT" "$PEPPER" "$PASS" ##

         [[ ${EMAIL} != "" && ${EMAIL} != $(cat ~/.zen/game/players/.current/.player 2>/dev/null) ]] && rm -Rf ~/.zen/game/players/${EMAIL}/

        exit
        ;;
    "NEW PLAYER")
        echo "'Email ?'"
        read EMAIL
        [[ ${EMAIL} == "" ]] && break
        echo "'Secret 1'"
        read PPASS
        [[ ${PPASS} == "" ]] \
            && PPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
        echo "'Secret 2'"
        read NPASS
        [[ ${NPASS} == "" ]] \
            && NPASS=$(${MY_PATH}/tools/diceware.sh $(( $(${MY_PATH}/tools/getcoins_from_gratitude_box.sh) + 1 )) | xargs)
        echo "'Latitude ?'"
        read LAT
        [[ ${LAT} == "" ]] && LAT="0.00"
        echo "'Longitude ?'"
        read LON
        [[ ${LON} == "" ]] && LON="0.00"
        echo "${MY_PATH}/RUNTIME/VISA.new.sh" "${PPASS}" "${NPASS}" "${EMAIL}" "UPlanet" "fr" "${LAT}" "${LON}"
        ${MY_PATH}/RUNTIME/VISA.new.sh "${PPASS}" "${NPASS}" "${EMAIL}" "UPlanet" "fr" "${LAT}" "${LON}"
        fav=$(cat ~/.zen/tmp/PSEUDO 2>/dev/null) && rm ~/.zen/tmp/PSEUDO
        echo "Astronaute $fav bienvenue sur UPlanet..."
        exit
        ;;
    "")
        echo "Choix obligatoire. exit"
        exit
        ;;
    *) echo "Salut $fav"
        break
        ;;
    esac
done
PLAYER=$fav

####### NO CURRENT ? PLAYER = .current
[[ ! -d $(readlink ~/.zen/game/players/.current) ]] \
    && rm -f ~/.zen/game/players/.current \
    && ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

pass=$(cat ~/.zen/game/players/$PLAYER/.pass 2>/dev/null)
########################################## DEVEL
echo "ENTER PASS -- FREE MODE -- $pass" && read PASS

## DECODE CURRENT PLAYER CRYPTO
# echo "********* DECODAGE SecuredSocketLayer *********"
# rm -f ~/.zen/tmp/${PLAYER}.dunikey 2>/dev/null
# openssl enc -aes-256-cbc -d -in "$HOME/.zen/game/players/${PLAYER}/enc.secret.dunikey" -out "$HOME/.zen/tmp/${PLAYER}.dunikey" -k $pass 2>&1>/dev/null
[[ $PASS != $pass ]] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

## CURRENT CHANGE ?
#~ [[  ${CURRENT} !=  ${PLAYER} ]] \
#~ && echo "BECOME ADMIN ? hit ENTER for NO, write something for YES" && read ADM \
#~ && [[ ${ADM} != "" ]] \
#~ && rm -f ~/.zen/game/players/.current \
#~ && ln -s ~/.zen/game/players/${PLAYER} ~/.zen/game/players/.current

echo "________LOGIN OK____________";
echo
echo "DECHIFFRAGE CLEFS ASTRONAUTE"
echo "PASS Astroport.ONE  : $(cat ~/.zen/game/players/$PLAYER/.pass 2>/dev/null)"
export G1PUB=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
[ ! ${G1PUB} ] && echo "ERROR. MAUVAIS PASS. EXIT" && exit 1

echo "G1PUB Astronaute : $G1PUB"
echo "ENTREE ACCORDEE"
echo
export ASTRONAUTENS=$(ipfs key list -l | grep -w "$PLAYER" | cut -d ' ' -f 1)

echo "$(cat ~/.zen/game/players/${PLAYER}/.pseudo 2>/dev/null) TW/Moa"
echo "$myIPFS/ipns/$ASTRONAUTENS"
echo "Activation Réseau P2P Astroport !"

[[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && xdg-open "http://ipfs.localhost:8080/ipns/$ASTRONAUTENS"

echo
PS3="$PLAYER choose : __ "
choices=("PRINT VISA" "UNPLUG PLAYER" "QUIT")
select fav in  "${choices[@]}"; do
    case $fav in
    "PRINT VISA")
        echo "IMPRESSION"
        ${MY_PATH}/tools/VISA.print.sh "$PLAYER"
        ;;

    "UNPLUG PLAYER")
        echo "ATTENTION ${PLAYER} DECONNEXION DE VOTRE TW !!"
        echo  "Enter to continue. Ctrl+C to stop"
        read
        ${MY_PATH}/RUNTIME/PLAYER.unplug.sh "${HOME}/.zen/game/players/${PLAYER}/ipfs/moa/index.html" "${PLAYER}"

        break
        ;;

    #~ "AJOUTER VLOG")
        #~ echo "Lancement Webcam..."
        #~ ${MY_PATH}/tools/vlc_webcam.sh "$PLAYER"
        #~ ;;

    "MAKE A WHISH")
        echo "QRCode à coller sur les lieux ou objets portant une Gvaleur"
        cp ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html
        ${MY_PATH}/RUNTIME/G1Voeu.sh "" "$PLAYER" "$HOME/.zen/tmp/$PLAYER.html"
        DIFF=$(diff ~/.zen/game/players/$PLAYER/ipfs/moa/index.html ~/.zen/tmp/$PLAYER.html)
        if [[ $DIFF ]]; then
            echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/moa/.moats
            cp   ~/.zen/game/players/$PLAYER/ipfs/moa/.chain \
                    ~/.zen/game/players/$PLAYER/ipfs/moa/.chain.$(cat ~/.zen/game/players/$PLAYER/ipfs/moa/.moats)

            TW=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/moa/index.html | tail -n 1)
            ipfs name publish --key=$PLAYER /ipfs/$TW

            echo $TW > ~/.zen/game/players/$PLAYER/ipfs/moa/.chain
        fi
    echo "================================================"
    echo "$PLAYER : $myIPFS/ipns/$ASTRONAUTENS"
    echo "================================================"
        ;;

    "PRINT QRVOEU")
        ${MY_PATH}/tools/VOEUX.print.sh $PLAYER
        ;;

    "QUIT")
        echo "CIAO" && exit 0
        ;;

    "")
        echo "Mauvais choix."
        ;;

    esac
done

exit 0
