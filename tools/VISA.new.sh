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
"
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

SALT=$(${MY_PATH}/diceware.sh 4 | xargs)
[[ $1 != "quiet" ]] && echo "-> SALT : $SALT"

PEPPER=$(${MY_PATH}/diceware.sh 4 | xargs)
[[ $1 != "quiet" ]] && echo "-> PEPPER : $PEPPER"

[[ $1 != "quiet" ]] && echo "ENTREZ UN PSEUDO" && read PSEUDO
PLAYER=$(${MY_PATH}/diceware.sh 1 | xargs)${RANDOM:0:2}$(${MY_PATH}/diceware.sh 1 | xargs)${RANDOM:0:2}
[[ ! $PSEUDO ]] && PSEUDO=$PLAYER
[[ $1 != "quiet" ]] && echo "-> $PSEUDO : $PLAYER"

PASS=$(echo "${RANDOM}${RANDOM}${RANDOM}${RANDOM}" | tail -c-7)
[[ $1 != "quiet" ]] && echo "-> PASS : $PASS"

IPNS=$(ipfs key gen $PLAYER)
KEYFILE=$(${MY_PATH}/give_me_keystore_filename.py "$PLAYER")
[[ $1 != "quiet" ]] && echo "-> IPNS KEY : $KEYFILE /ipns/$IPNS"

## CREATE Player personnal files storage and IPFS publish directory
mkdir -p ~/.zen/game/players/$PSEUDO/public

echo "$PSEUDO" > ~/.zen/game/players/$PSEUDO/.pseudo
echo "$PLAYER" > ~/.zen/game/players/$PSEUDO/.player

echo "$SALT" > ~/.zen/game/players/$PSEUDO/login.june
echo "$PEPPER" >> ~/.zen/game/players/$PSEUDO/login.june

G1PUB=$(python3 ${MY_PATH}/key_create_dunikey.py "$SALT" "$PEPPER")
mv /tmp/secret.dunikey ~/.zen/game/players/$PSEUDO/
qrencode -s 6 -o $HOME/.zen/game/players/$PSEUDO/QR.png "$G1PUB"

secFromDunikey=$(cat ~/.zen/game/players/$PSEUDO/secret.dunikey | grep "sec" | cut -d ' ' -f2)
echo "$secFromDunikey" > /tmp/${PSEUDO}.sec
openssl enc -aes-256-cbc -salt -in /tmp/${PSEUDO}.sec -out "/tmp/enc.${PSEUDO}.sec" -k $PASS 2>/dev/null
PASsec=$(cat /tmp/enc.${PSEUDO}.sec | base58) && rm -f /tmp/${PSEUDO}.sec
qrencode -s 6 -o $HOME/.zen/game/players/$PSEUDO/QRsec.png $PASsec

[[ $1 != "quiet" ]] && echo "-> G1PUB QRCODE : $G1PUB"
[[ $1 != "quiet" ]] && echo "SEC $secFromDunikey"

cp $HOME/.ipfs/keystore/$KEYFILE ~/.zen/game/players/$PSEUDO/
qrencode -s 6 -o "$HOME/.zen/game/players/$PSEUDO/IPNS.png" "/ipns/$IPNS"

[[ $1 != "quiet" ]] && echo "PLAYER LOCAL REPOSITORY ~/.zen/game/players/$PSEUDO/"

# PASS CRYPTING KEY
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PSEUDO/login.june" -out "$HOME/.zen/game/players/$PSEUDO/enc.login.june" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PSEUDO/secret.dunikey" -out "$HOME/.zen/game/players/$PSEUDO/enc.secret.dunikey" -k $PASS 2>/dev/null
openssl enc -aes-256-cbc -salt -in "$HOME/.zen/game/players/$PSEUDO/$KEYFILE -out" "$HOME/.zen/game/players/$PSEUDO/enc.$KEYFILE" -k $PASS 2>/dev/null
## MORE SECURE ?! USE opengpg

G1PUB=$(cat ~/.zen/game/players/$PSEUDO/secret.dunikey | grep 'pub:' | cut -d ' ' -f 2)
${MY_PATH}/natools.py encrypt -p $G1PUB -i ~/.zen/game/players/$PSEUDO/secret.dunikey -o "$HOME/.zen/game/players/$PSEUDO/secret.dunikey.oasis"

#################################################
# !!!! # DEV MODE. REMOVE FOR PRODUCTION STATION FORGET PASS
echo "$PASS" > ~/.zen/game/players/$PSEUDO/.pass
#################################################

## SET CURRENT PLAYER
rm -f ~/.zen/game/players/.current
ln -s ~/.zen/game/players/$PSEUDO ~/.zen/game/players/.current

## CLEANING CLEAR FILES
rm -f ~/.zen/game/players/$PSEUDO/$KEYFILE
rm -f ~/.zen/game/players/$PSEUDO/secret.dunikey

[[ $1 != "quiet" ]] && echo "____MANUAL REMOVAL COMMANDS____"
[[ $1 != "quiet" ]] && echo "rm -Rf ~/.zen/game/players/$PSEUDO"
[[ $1 != "quiet" ]] && echo "ipfs key rm $PSEUDO > /dev/null"
[[ $1 != "quiet" ]] && ls -a ~/.zen/game/players/$PSEUDO

[[ $1 == "quiet" ]] && echo "$PSEUDO"

exit 0
