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

Création de votre PSEUDO, votre PLAYER, votre PASS (6 chiffres)
Création de votre SALT PEPPER : compte Gchange et son portefeuille G1.
Création de votre clef DUNITER :  la clef d'accès Cesium
Création de vos clef IPNS : vos balises de publication dans le réseau IPFS.
PLAYER, MOA & STARGATES

Vos identifiants 'Astronaute' sont:
"
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

SALT=$(${MY_PATH}/diceware.sh 4 | xargs)
[[ $1 != "quiet" ]] && echo "-> SALT : $SALT"

PEPPER=$(${MY_PATH}/diceware.sh 4 | xargs)
[[ $1 != "quiet" ]] && echo "-> PEPPER : $PEPPER"

[[ $1 != "quiet" ]] && echo "CHOISISSEZ UN PSEUDO" && read PSEUDO; PSEUDO=${PSEUDO,,} && [[ -d ~/.zen/game/players/$PSEUDO ]] && echo "CE PSEUDO EST DEJA UN PLAYER. EXIT" && exit 1
# PSEUDO=${PSEUDO,,} #lowercase
PLAYER=${PSEUDO}${RANDOM:0:2}$(${MY_PATH}/diceware.sh 1 | xargs)${RANDOM:0:2}
[[ ! $PSEUDO ]] && PSEUDO=$PLAYER
[[ $1 != "quiet" ]] && echo "$PSEUDO voici votre identifiant Astronaute:  $PLAYER"; sleep 1

PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)
[[ $1 != "quiet" ]] && echo "et votre PASS : $PASS"; sleep 2

PLAYERNS=$(ipfs key gen $PLAYER)
PLAYERKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "$PLAYER")
[[ $1 != "quiet" ]] && echo "Votre clef $PLAYER <=> $PLAYERNS ($PLAYERKEYFILE)"; sleep 2
MOANS=$(ipfs key gen moa_$PLAYER)
MOAKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "moa_$PLAYER")
echo "Votre coffre personnel constitués des média que vous aurez embarqué dans votre 'Astroport' (amis de niveau 3)"
[[ $1 != "quiet" ]] && echo "Votre clef moa_$PLAYER <=> $MOANS ($MOAKEYFILE)"; sleep 2
QOOPNS=$(ipfs key gen qo-op_$PLAYER)
QOOPKEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "qo-op_$PLAYER")
echo "Votre journal de bord pubié dans le réseau des ambassades 'Astroport One' (zone 'publique' niveau 0 du réseau Astroport)"
[[ $1 != "quiet" ]] && echo "Votre clef qo-op_$PLAYER <=> $QOOPNS ($QOOPKEYFILE)"; sleep 2


## CREATE Player personnal files storage and IPFS publish directory
mkdir -p ~/.zen/game/players/$PLAYER/ipfs/

echo "$PSEUDO" > ~/.zen/game/players/$PLAYER/.pseudo
echo "$PLAYER" > ~/.zen/game/players/$PLAYER/.player

echo "$SALT" > ~/.zen/game/players/$PLAYER/secret.june
echo "$PEPPER" >> ~/.zen/game/players/$PLAYER/secret.june

[[ $1 != "quiet" ]] && echo "Rendez-vous sur https://gchange.fr
Utilisez ces identifiants pour rejoindre le réseau JUNE
    $SALT
    $PEPPER
"; sleep 3

G1PUB=$(python3 ${MY_PATH}/key_create_dunikey.py "$SALT" "$PEPPER")

if [[ ! $G1PUB ]]; then
    [[ $1 != "quiet" ]] && echo "Désolé. Nous n'avons pas pu générer votre clef Cesium automatiquement."
else

    ########################################################################
    echo "CREATING ~/.zen/game/players/$PLAYER/ipfs.config"
    ########################################################################
    ipfs_ID=$(python3 ~/.zen/astrXbian/zen/tools/create_ipfsnodeid_from_tmp_secret.dunikey.py)
    echo $ipfs_ID > ~/.zen/game/players/$PLAYER/secret.ipfs && source ~/.zen/game/players/$PLAYER/secret.ipfs
    [[ $PrivKEY == "" ]] && echo "ERROR CREATING IPFS IDENTITY" && exit 1
    jq -r --arg PeerID "$PeerID" '.Identity.PeerID=$PeerID' ~/.ipfs/config > ~/.zen/tmp/config.tmp
    jq -r --arg PrivKEY "$PrivKEY" '.Identity.PrivKey=$PrivKEY' ~/.zen/tmp/config.tmp > ~/.zen/tmp/config.ipfs
    jq '.Peering.Peers = []' ~/.zen/tmp/config.ipfs > ~/.zen/tmp/ipfs.config ## RESET .Peering.Peers FRIENDS
    rm -f ~/.zen/tmp/config.tmp ~/.zen/tmp/config.ipfs
    mv ~/.zen/tmp/ipfs.config ~/.zen/game/players/$PLAYER/

    mkdir -p ~/.zen/game/players/$PLAYER/ipfs/.$PeerID # Prepare astrXbian datastructure

    mv /tmp/secret.dunikey ~/.zen/game/players/$PLAYER/
    qrencode -s 6 -o $HOME/.zen/game/players/$PLAYER/QR.png "$G1PUB"

    secFromDunikey=$(cat ~/.zen/game/players/$PLAYER/secret.dunikey | grep "sec" | cut -d ' ' -f2)
    echo "$secFromDunikey" > /tmp/${PSEUDO}.sec
    openssl enc -aes-256-cbc -salt -in /tmp/${PSEUDO}.sec -out "/tmp/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
    PASsec=$(cat /tmp/enc.${PSEUDO}.sec | base58) && rm -f /tmp/${PSEUDO}.sec
    qrencode -s 6 -o $HOME/.zen/game/players/$PLAYER/QRsec.png $PASsec

    [[ $1 != "quiet" ]] && echo "Votre Clef publique G1 est : $G1PUB"; sleep 1
    [[ $1 != "quiet" ]] && echo "SEC $secFromDunikey"; sleep 1
fi

[[ $1 != "quiet" ]] && echo "Rendez-vous sur https://cesium.app et utilisez les mêmes identifiants pour accéder à votre portefeuille JUNE"; sleep 2

cp $HOME/.ipfs/keystore/$KEYFILE ~/.zen/game/players/$PLAYER/
qrencode -s 6 -o "$HOME/.zen/game/players/$PLAYER/QR.IPNSFL.PLAYER.png" "http://localhost:8080/ipns/$IPNS"

[[ $1 != "quiet" ]] && echo; echo; echo "*** Espace privé activé : ~/.zen/game/players/$PLAYER/"; sleep 1
[[ $1 != "quiet" ]] && echo; echo "*** Votre journal de bord : http://localhost:8080/ipns/$IPNS"; sleep 1

# PASS CRYPTING KEY
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.june" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.june" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/secret.dunikey" -out "$HOME/.zen/game/players/$PLAYER/enc.secret.dunikey" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PLAYER/$KEYFILE -out" "$HOME/.zen/game/players/$PLAYER/enc.$KEYFILE" -k $PASS 2>/dev/null
## TODO MORE SECURE ?! USE opengpg, natools, etc ...
# ${MY_PATH}/natools.py encrypt -p $G1PUB -i ~/.zen/game/players/$PLAYER/secret.dunikey -o "$HOME/.zen/game/players/$PLAYER/secret.dunikey.oasis"

[[ $1 != "quiet" ]] && echo "Sécurisation de vos clefs par chiffrage SSL... $PASS"; sleep 1

#################################################
# !!!! # DEV MODE. REMOVE FOR PRODUCTION STATION FORGET PASS
echo "$PASS" > ~/.zen/game/players/$PLAYER/.pass
#################################################

## SET CURRENT PLAYER
rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PLAYER ~/.zen/game/players/.current

## CLEANING CLEAR FILES
rm -f ~/.zen/game/players/$PLAYER/$KEYFILE
rm -f ~/.zen/game/players/$PLAYER/secret.dunikey

[[ $1 != "quiet" ]] && echo "_____DEBUG PLAYER REMOVE COMMANDS____"
[[ $1 != "quiet" ]] && echo "rm -Rf ~/.zen/game/players/$PLAYER"
[[ $1 != "quiet" ]] && echo "ipfs key rm $PLAYER > /dev/null"
[[ $1 != "quiet" ]] && echo "_____DEBUG PLAYER REMOVE COMMANDS____"

[[ $1 != "quiet" ]] && echo "Bienvenue à toi Astronaute $PSEUDO ($PLAYER)"

echo $PSEUDO > ~/.zen/tmp/PSEUDO

exit 0
