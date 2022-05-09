#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
################################################################################
#
[[ $1 != "quiet" ]] && echo "=============================================
MadeInZion DIPLOMATIC PASSPORT
=============================================
A cryptographic key pair to control your P2P Digital Life.
Solar Punk garden forest terraforming game.
=============================================
Bienvenue 'Astronaute'"; sleep 1

echo ""

################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
YOU=$(ps auxf --sort=+utime | grep -w ipfs | grep -v -E 'color=auto|grep' | tail -n 1 | cut -d " " -f 1);
[[ ! $YOU ]] && echo "Lancez 'ipfs daemon' SVP" && exit 1

SALT=$(${MY_PATH}/diceware.sh 4 | xargs)
# [[ $1 != "quiet" ]] && echo "-> SALT : $SALT"

PEPPER=$(${MY_PATH}/diceware.sh 4 | xargs)
# [[ $1 != "quiet" ]] && echo "-> PEPPER : $PEPPER"

echo "Création de votre PSEUDO, votre PLAYER, avec PASS (6 chiffres)"

[[ $1 != "quiet" ]] && echo "CHOISISSEZ UN PSEUDO" && read PSEUDO; PSEUDO=${PSEUDO,,} && [[ $(ls ~/.zen/game/players/$PSEUDO* 2>/dev/null) ]] && echo "CE PSEUDO EST DEJA UN PLAYER. EXIT" && exit 1
# PSEUDO=${PSEUDO,,} #lowercase
PLAYER=${PSEUDO}${RANDOM:0:2}$(${MY_PATH}/diceware.sh 1 | xargs)${RANDOM:0:2}
[[ ! $PSEUDO ]] && PSEUDO=$PLAYER
[[ $1 != "quiet" ]] && echo; echo "Génération de vos identités Astronaute (PLAYER):"; sleep 1; echo "$PLAYER"; sleep 2

PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)

############################################################
######### CLEFS IPNS PLAYER + moa_ + qo-op_
PLAYERNS=$(ipfs key gen $PLAYER)
PLAYERKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "$PLAYER")
# echo "Votre espace Astronaute privé. Compteurs LOVE 'Astroport' (amis de niveau 5)"
# [[ $1 != "quiet" ]] && echo "Votre clef $PLAYER <=> $PLAYERNS ($PLAYERKEYFILE)"; sleep 2
MOANS=$(ipfs key gen moa_$PLAYER)
MOAKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "moa_$PLAYER")
# echo "Coffre personnel multimedia journalisé dans votre 'Astroport' (amis de niveau 3)"
# [[ $1 != "quiet" ]] && echo "Votre clef moa_$PLAYER <=> $MOANS ($MOAKEYFILE)"; sleep 2
QOOPNS=$(ipfs key gen qo-op_$PLAYER)
QOOPKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "qo-op_$PLAYER")
# echo "Votre journal de bord pubié dans le réseau des ambassades/passerelles 'Astroport One' (zone 'publiques' niveau 0 et 1)"
# [[ $1 != "quiet" ]] && echo "Votre clef qo-op_$PLAYER <=> $QOOPNS ($QOOPKEYFILE)"; sleep 2


[[ $1 != "quiet" ]] && echo "Compte Gchange et portefeuille G1.
Utilisez ces identifiants pour rejoindre le réseau JUNE

    $SALT
    $PEPPER

Rendez-vous sur https://gchange.fr"; sleep 3

echo; echo "Création de votre clef 'secret.dunikey' accès aux réseaux DU(G1) + LOVE + IPFS astrXbian."; sleep 2
echo;

G1PUB=$(python3 ${MY_PATH}/key_create_dunikey.py "$SALT" "$PEPPER")

if [[ ! $G1PUB ]]; then
    [[ $1 != "quiet" ]] && echo "Désolé. Nous n'avons pas pu générer votre clef Cesium automatiquement."
else
    ## CREATE Player personnal files storage and IPFS publish directory
    mkdir -p ~/.zen/game/players/$PLAYER # Prepare PLAYER datastructure

    ########################################################################
    #echo "CREATION ~/.zen/game/players/$PLAYER/ipfs.config"; sleep 1
    ########################################################################
    ipfs_ID=$(python3 ~/.zen/astrXbian/zen/tools/create_ipfsnodeid_from_tmp_secret.dunikey.py)
    echo $ipfs_ID > ~/.zen/game/players/$PLAYER/secret.ipfs && source ~/.zen/game/players/$PLAYER/secret.ipfs
    [[ $PrivKEY == "" ]] && echo "ERROR CREATING IPFS IDENTITY" && exit 1
    jq -r --arg PeerID "$PeerID" '.Identity.PeerID=$PeerID' ~/.ipfs/config > ~/.zen/tmp/config.tmp
    jq -r --arg PrivKEY "$PrivKEY" '.Identity.PrivKey=$PrivKEY' ~/.zen/tmp/config.tmp > ~/.zen/tmp/config.ipfs
    jq '.Peering.Peers = []' ~/.zen/tmp/config.ipfs > ~/.zen/tmp/ipfs.config ## RESET .Peering.Peers FRIENDS
    rm -f ~/.zen/tmp/config.tmp ~/.zen/tmp/config.ipfs
    mv ~/.zen/tmp/ipfs.config ~/.zen/game/players/$PLAYER/

    mv /tmp/secret.dunikey ~/.zen/game/players/$PLAYER/

    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/G1SSB # Prepare astrXbian sub-datastructure

    qrencode -s 6 -o ~/.zen/game/players/$PLAYER/QR.png "$G1PUB"
    cp ~/.zen/game/players/$PLAYER/QR.png ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/QR.png
    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/G1SSB/_g1.pubkey # G1SSB NOTATION (astrXbian compatible)

    secFromDunikey=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep "sec" | cut -d ' ' -f2)
    echo "$secFromDunikey" > /tmp/${PSEUDO}.sec
    openssl enc -aes-256-cbc -salt -in /tmp/${PSEUDO}.sec -out "/tmp/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
    PASsec=$(cat /tmp/enc.${PSEUDO}.sec | base58) && rm -f /tmp/${PSEUDO}.sec
    qrencode -s 6 -o $HOME/.zen/game/players/$PLAYER/QRsec.png $PASsec

    [[ $1 != "quiet" ]] && echo "Votre Clef publique G1 est : $G1PUB"; sleep 1

    # TODO ZIP &| ENCRYPT FOR SECURITY (better control to keystore access)
    mkdir -p ~/.zen/game/players/$PLAYER/keystore/
    cp $HOME/.ipfs/keystore/$PLAYERKEYFILE ~/.zen/game/players/$PLAYER/keystore/
    cp $HOME/.ipfs/keystore/$MOAKEYFILE ~/.zen/game/players/$PLAYER/keystore/
    cp $HOME/.ipfs/keystore/$QOOPKEYFILE ~/.zen/game/players/$PLAYER/keystore/

    ### INITALISATION WIKI dans leurs répertoires de publication IPFS
    ############ TODO améliorer templates, sed, ajouter index.html, etc...
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    IPFSNODEID=$(cat ~/.ipfs/config | jq -r .Identity.PeerID) # We should have a Captain already...

    # PLAYER Home ~/.zen/game/players/$PLAYER/index.html
    PLAYERNS=$(ipfs key list -l | grep -w $PLAYER | cut -d ' ' -f 1)
    cp ${MY_PATH}/../templates/playerhome.html ~/.zen/game/players/$PLAYER/index.html
    sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/index.html
    sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/$PLAYER/index.html
    # Not used (yet) TODO make jQuery Slider
    sed -i "s~_MOANS_~${MOANS}~g" ~/.zen/game/players/$PLAYER/index.html
    sed -i "s~_QOOPNS_~${QOOPNS}~g" ~/.zen/game/players/$PLAYER/index.html

                #echo "## PUBLISHING ${PLAYER} /ipns/$PLAYERNS"
                IPUSH=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/index.html | tail -n 1)
                echo $IPUSH > ~/.zen/game/players/$PLAYER/$PLAYER.chain
                echo $MOATS > ~/.zen/game/players/$PLAYER/$PLAYER.ts
                echo 1 > ~/.zen/game/players/$PLAYER/$PLAYER.n
                ipfs name publish --key=${PLAYER} /ipfs/$IPUSH 2>/dev/null

    # Moa WIKI ~/.zen/game/players/$PLAYER/moa/index.html
    mkdir -p ~/.zen/game/players/$PLAYER/moa
    cp ${MY_PATH}/../templates/moawiki.html ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~_MOAID_~${MOANS}~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    STATION=$(ipfs key list -l | grep -w 'moa' | cut -d ' ' -f 1)
    sed -i "s~_QOOP_~${STATION}~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~_MOAKEY_~moa_${PLAYER}~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~k2k4r8opmmyeuee0xufn6txkxlf3qva4le2jlbw6da7zynhw46egxwp2~${MOANS}~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/players/$PLAYER/moa/index.htm
    sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/game/players/$PLAYER/moa/index.htm

    ## Add QRCode, ID Scan login page. Private p2p level 3 exploration
    cp ${MY_PATH}/../templates/instascan.html ~/.zen/game/players/$PLAYER/moa/index.html


                #echo "## PUBLISHING moa_${PLAYER} /ipns/$MOANS"
                IPUSH=$(ipfs add -wHq ~/.zen/game/players/$PLAYER/moa/* | tail -n 1)
                echo $IPUSH > ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.chain
                echo $MOATS > ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.ts
                echo 1 > ~/.zen/game/players/$PLAYER/moa/$PLAYER.moa.n
                ipfs name publish --key=moa_${PLAYER} /ipfs/$IPUSH 2>/dev/null

    # qo-op WIKI ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html (TODO ENHANCE TW TEMPLATE WITH EXTRA PARMETERS, EXTRA TIDDLERS)
    cp ${MY_PATH}/../templates/qoopwiki.html ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~_BIRTHDATE_~${MOATS}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~_PSEUDO_~${PSEUDO}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~_PLAYER_~${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~_MOANS_~${MOANS}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~_QOOPNS_~${QOOPNS}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    STATION=$(ipfs key list -l | grep -w 'qo-op' | cut -d ' ' -f 1)
    sed -i "s~_QOOP_~${STATION}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~_MOAKEY_~qo-op_${PLAYER}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~k2k4r8opmmyeuee0xufn6txkxlf3qva4le2jlbw6da7zynhw46egxwp2~${QOOPNS}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~ipfs.infura.io~tube.copylaradio.com~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html
    sed -i "s~_IPFSNODEID_~${IPFSNODEID}~g" ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html

                #echo "## PUBLISHING qo-op_${PLAYER} /ipns/$QOOPNS"
                IPUSH=$(ipfs add -Hq ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/index.html | tail -n 1)
                echo $IPUSH > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.chain
                echo $MOATS > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.ts
                echo 1 > ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/$PLAYER.qo-op.n
                ipfs name publish --key=qo-op_${PLAYER} /ipfs/$IPUSH 2>/dev/null

    ## MEMORISE PLAYER
    echo "$PSEUDO" > ~/.zen/game/players/$PLAYER/.pseudo
    echo "$G1PUB" > ~/.zen/game/players/$PLAYER/.g1pub
    echo "$IPFSNODEID" > ~/.zen/game/players/$PLAYER/.ipfsnodeid

    echo "$PLAYER" > ~/.zen/game/players/$PLAYER/.player
    # astrXbian compatible IPFS sub structure =>$XZUID
    cp ~/.zen/game/players/$PLAYER/.player ~/.zen/game/players/$PLAYER/ipfs/.$PeerID/_xbian.zuid

    # Record IPNS address for CHANNEL.populate
    echo "$PLAYERNS" > ~/.zen/game/players/$PLAYER/.playerns
    echo "$MOANS" > ~/.zen/game/players/$PLAYER/.moans
    echo "$QOOPNS" > ~/.zen/game/players/$PLAYER/.qoopns

    echo "$SALT" > ~/.zen/game/players/$PLAYER/secret.june
    echo "$PEPPER" >> ~/.zen/game/players/$PLAYER/secret.june

fi

qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.PLAYERNS.png" "/ipns/$PLAYERNS"
qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.MOANS.png" "/ipns/$MOANS"
qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.QOOPNS.png" "/ipns/$QOOPNS"

echo; echo "Création de vos QR codes IPNS, clefs de votre réseau IPFS."; sleep 1

[[ $1 != "quiet" ]] && echo; echo "*** Espace Astronaute Activé : ~/.zen/game/players/$PLAYER/"; sleep 1
[[ $1 != "quiet" ]] && echo; echo "*** Votre Home : $PLAYER"; echo "http://127.0.0.1:8080/ipns/$PLAYERNS"; sleep 2
[[ $1 != "quiet" ]] && echo; echo "*** Votre Journal Astronaute (niveau 3) : moa_$PLAYER"; echo " http://127.0.0.1:8080/ipns/$(ipfs key list -l | grep -w moa_$PLAYER | cut -d ' ' -f 1)"; sleep 2
[[ $1 != "quiet" ]] && echo; echo "*** Votre Journal Passerelle (niveau 0/1) : qo-op_$PLAYER"; echo " http://127.0.0.1:8080/ipns/$(ipfs key list -l | grep -w qo-op_$PLAYER | cut -d ' ' -f 1)"; sleep 2

# PASS CRYPTING KEY
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.june" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.june" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.dunikey" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.dunikey" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/$KEYFILE -out" "$HOME/.zen/game/players/$PLAYER/enc.$KEYFILE" -k $PASS 2>/dev/null
## TODO MORE SECURE ?! USE opengpg, natools, etc ...
# ${MY_PATH}/natools.py encrypt -p $G1PUB -i ~/.zen/game/players/$PLAYER/secret.dunikey -o "$HOME/.zen/game/players/$PLAYER/secret.dunikey.oasis"

[[ $1 != "quiet" ]] && echo; echo "Sécurisation de vos clefs par chiffrage SSL... "; sleep 1

#################################################
# !! TODO !! # DEMO MODE. REMOVE FOR PRODUCTION
echo "$PASS" > ~/.zen/game/players/$PLAYER/.pass
# ~/.zen/game/players/$PLAYER/secret.june SECURITY TODO
# Astronaut QRCode + PASS = LOGIN (=> DECRYPTING CRYPTO IPFS INDEX)
#####################################################

## DISCONNECT AND CONNECT CURRENT PLAYER
rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

## INIT FRIENDSHIP CAPTAIN/ASTRONAUTS
${MY_PATH}/FRIENDS.init.sh

[[ $1 != "quiet" ]] && echo "Bienvenue 'Astronaute' $PSEUDO ($PLAYER)"
[[ $1 != "quiet" ]] && echo "Souvenez-vous bien de votre PASS : $PASS"; sleep 2

echo $PSEUDO > ~/.zen/tmp/PSEUDO ## Return data to start.sh
echo "cool $(${MY_PATH}/face.sh cool)"
exit 0
