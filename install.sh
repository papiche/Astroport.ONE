#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
TS=$(date -u +%s%N | cut -b1-13)

echo "
                          oMMWMMMMMMMMMMMMMMMMoccdocc::xMMMMMMMMMMMMMMWMW00MMx  '   .o0XNXx: ...'',..  .,lxKNMN0d'
                   ,:::;cxNMMMMMMMMMMMMMMMMMMM.  ,.    cMMMMMMMMMMMMMMMMMMMMMXd;.'oKMMMMMMMMWMMMMMMMMXNMMMMMMMMMMMNkc;.
             ,oOKWMMMMMMMMMMMMMMMMMMNXXXNMMMMM;.,  .c, cMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMKd,
          'xWMMMMMMMMMMMMMMMMMMMMMMXl:::oKWMMM.        cMMMMMMMMMMdccXMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNkKMMMMNWMMMMMMMMMX:
         xMMMMMMMMMMMMMMMMMMMMMMMMWx::::::0MMM;.,'..:' cMMMMMMMMMMd::KMMMMMMMMMMMMMMMMWk:.'x:,KMMMMNo. ...  'lo' ,0KMMMMMMMMMO
        0MMMMMMMMMMM0.,,'lMMMMMWlc::::::::0MMM.  .. . .,WMMMMMMMMMd::KMMMMMMMMMMMMMMWo;.      :MXldd          :     ,kMMMMMMMM0
       xMMMMMMMX0KKKx.cc::NNNWNW::::::::::0MMM,..   ,.''KMMMMMWWMMd::KMx...0MMMMMMMWc.         ,dc            .     .lWMMMMMMMM:
      .MMMMMkdc .... .cc:  ,.. :...;;,''',0MWW'...  ..''0XMkc;::c0o::k:.    XWkkXKM0.                                ,XMMMMMMMMXoc;;.
     cWMMMMM'   ;ll: .llc  l.  cll,   .,,.0X    .,. ..,,' k' .,,,,,,;.      ..     .               :c '  ,; ,.   c;   ,c:..;NMMMMMMMN:
'NMNXMMMxccl.   ;ll: .llc  l.  cll,   'll.O;  ...   ,..'     ''.''''.                             .XkoM0;W0XNk'k,X0.        'WMMMMMMMMo
NMMMMWNl        ;ll: .llc  l.  :ll,   'll ...          .     .......                               lxcd' .OXl''.cXk.;   .  .clxWMMMMMMMN
MMMMM'          ;ll: .llc  o.  :ll,   'cc '''    ,.          ,'.,,,,                                      .        :.   'o      cWMMMMMM
MMMMW.          .,,'  ::;  ;.  ',,.   .;, ...    ..          .......                                                     .;'    ,WMMMMMM
MMMMX                                                                                                                         .dOK00OkxN
MMMMK   :oooo;      ;looooooooo. .ooooooooooo' 'oooooooooooc    'loooooooc.   cooooooooool'   .loooooool.  'ooooooooooo:   ;oooooooooo.0
MMMM0..0MMMMMX    'NMMMMMMMMMMX 'NMMMMMMMMMMM',WMMMMMMMMMMMMx  OMMMMMMMMMMN  dMMMMMMMMMMMMW. xMMMMMMMMMMW.,WMMMMMMMMMMMMx cWMMMMMMMMMM'X
:XM0  :lllllll    :lllllllllll' :lllllllllll: :lllllllllllll; 'oooooooooooo .llllllllllllll..oooooooooooo.:lllllllllllll;.llllllllllll.N
  '; oOOOOOOOOc  'OOOOOOOOko.       k000:     ;OOOOOOOOOOOOO,.OOOO;   d000l  xOOOOOOOOOOOOo kOOOc   c000x ;OOOOOOOOOOOOO'    .0000. 0WXM
     0MMMMMMMMX  .WMMMMMMMMMW;     ;MMMW.     KMMMMMMMMMMMNl lMMMW.  'MMMM' ;MMMMMMMMMMMM0.;MMMM'   NMMMc KMMMMMMMMMMMNl     oMMMK ;MMMM
     ,::::XMMMM'  .;;;;:XMMMMx     OMMMk     ,MMMMxlllkMMMx  XMMMx   xMMM0  0MMMKlllllc;.  0MMMO   lMMMN.;MMMMxlllkMMMd      NMMMl xMMMM
          lMMMMdclllllloNMMMMo    .WMMM;     OMMMK    xMMMk .MMMM:..;WMMW, 'MMMM;         .MMMMo..'NMMMc 0MMMK    OMMMx     cMMMW. XMMMM
          .WMMMWMMMMMMMMMMMMO     xMMMX     .WMMM;   .WMMM; .XMMMMMMMMMX,  xMMMK           KMMMMMMMMMWc ,MMMM;   'MMMM'     XMMMx .WNOo.
           o00000000000000x,      O000:     l000x    c000x   .lk0000Od;    O000;            ck0000Ox:   o000x    l000d     .0000.

ASTROPORT is a peer to peer friends of friends real life game based on IPFS.
Join the Astronaiuts Team. Learn and share how to live together on 'One Planet'

ASTROPORT est un jeu d'amis entre amis basé sur IPFS.
Rejoignez l'équipe des astronautes. Apprenez et partagez comment vivre ensemble sur 'une seule planète'.

NOW INSTALLING REQUIRED TOOLS & CRYPTO STUFF
MAINTENANT INSTALLATION DES OUTILS NÉCESSAIRES ET DU MATÉRIEL CRYPTOGRAPHIQUE
"
## VERIFY SOFTWARE DEPENDENCIES
[[ ! $(which ipfs) ]] && echo "EXIT. Vous devez avoir installé ipfs CLI sur votre ordinateur" && echo "https://dist.ipfs.io/#go-ipfs" && exit 1

[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

sudo apt-get update
for i in git fail2ban inotify-tools curl net-tools libsodium* python3-dev python3-pip python3-setuptools python3-wheel python3-dotenv mpack libssl-dev libffi-dev printer-driver-all cups figlet apt-transport-https ca-certificates protobuf-compiler; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt install -y $i
    fi
done

for i in build-essential parallel tree fim qrencode jq bc gawk ffmpeg sqlite dnsutils v4l-utils vlc mp3info musl-dev openssl* cargo detox nmap httrack html2text ssmtp imagemagick ttf-mscorefonts-installer libcurl4-openssl-dev; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        sudo apt install -y $i
    fi
done

## INSTALL PYTHON CRYPTO LAYER
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc && source ~/.bashrc
python3 -m pip install -U pip
python3 -m pip install -U setuptools wheel
python3 -m pip install -U cryptography Ed25519 base58 google protobuf duniterpy

## INSTALL QR CODE PRINTER
sudo pip3 install brother_ql
sudo cupsctl --remote-admin
sudo usermod -aG lpadmin pi

# GAME FILES DATA STRUCTURE
mkdir -p ~/.zen/tmp
mkdir -p ~/.zen/game/players
mkdir -p ~/.zen/game/worlds

########################################################################
echo "INITIALISATION STATION OASIS ASTROPORT"
########################################################################
salt="$(${MY_PATH}/tools/diceware.sh 3 | xargs)"
salto="$salt"
[[ $salt == "" ]] && echo "ERROR" && exit 1
pepper="$(${MY_PATH}/tools/diceware.sh 3 | xargs)"
XZUID=$(${MY_PATH}/tools/diceware.sh 1 | xargs)${RANDOM:0:2}$(${MY_PATH}/tools/diceware.sh 1 | xargs)

echo "Conservez ou modifiez ce identifiant (passphrase 1)? $salt" && read salty && [[ $salty ]] && salt="$salty"
echo "Conservez ou modifiez ce mot de passe (passphrase 2)? $pepper" && read peppery && [[ $peppery ]] && pepper="$peppery"
[[ "$salt" != "$salto" ]] && echo "Gardez ou modifiez ce Pseudo? $XZUID" && read XZUIDy && [[ $XZUIDy ]] && XZUID="$XZUIDy"

g1_salt="$salt"
g1_pepper="$pepper"

echo "Creation secret.june avec ($g1_salt) ($g1_pepper)"
echo "$g1_salt" > /tmp/secret.june
echo "$g1_pepper" >> /tmp/secret.june

########################################################################
########################################################################
echo "CREATION CLEF secret.dunikey (https://cesium.app WALLET)"
########################################################################
python3 ${MY_PATH}/tools/key_create_dunikey.py "$g1_salt" "$g1_pepper"
g1pub=$(cat /tmp/secret.dunikey | grep "pub" | cut -d ' ' -f 2)
g1sec=$(cat /tmp/secret.dunikey | grep "sec" | cut -d ' ' -f 2)

########################################################################
########################################################################
echo "PREPARATION config.ipfs"
########################################################################
ipfs_ID=$(python3 ${MY_PATH}/tools/create_ipfsnodeid_from_tmp_secret.dunikey.py)
echo $ipfs_ID > /tmp/secret.ipfs && source /tmp/secret.ipfs
[[ $PrivKEY == "" ]] && echo "ERROR CREATING IPFS IDENTITY" && exit 1
jq -r --arg PeerID "$PeerID" '.Identity.PeerID=$PeerID' ~/.ipfs/config > /tmp/config.tmp
jq -r --arg PrivKEY "$PrivKEY" '.Identity.PrivKey=$PrivKEY' /tmp/config.tmp > /tmp/config.ipfs
rm /tmp/config.tmp

# IPFSNODEID
IPFSNODEID=$PeerID
echo "IPFSNODEID=$IPFSNODEID"

## Declare directory transfered in IPFS
IPFS_sync_directory="$HOME/astroport"
mkdir -p $IPFS_sync_directory

########################################################################
# INSTALL KEYS
########################################################################
echo "STATION CRYPTO ID ~/.zen"

[[ -f ~/.zen/secret.june ]] && mv ~/.zen/secret.june ~/.zen/secret.june.old.$TS
mv /tmp/secret.june ~/.zen/secret.june
chmod 640 ~/.zen/secret.june

[[ -f ~/.zen/secret.dunikey ]] && mv ~/.zen/secret.dunikey ~/.zen/secret.dunikey.old.$TS
mv /tmp/secret.dunikey ~/.zen/secret.dunikey
chmod 640 ~/.zen/secret.dunikey

[[ -f ~/.zen/secret.ipfs ]] && mv ~/.zen/secret.ipfs ~/.zen/secret.ipfs.old.$TS
mv /tmp/secret.ipfs ~/.zen/secret.ipfs
chmod 640 ~/.zen/secret.ipfs

#[[ -f ~/.ipfs/config ]] && mv ~/.ipfs/config ~/.ipfs/config.old.$TS
mv /tmp/config.ipfs ~/.ipfs/config

########################################################################
echo "INIT ~/.zen/ipfs/.${IPFSNODEID} INDEX"
########################################################################
rm -Rf ~/.zen/ipfs
mkdir -p ~/.zen/ipfs/.${IPFSNODEID}/G1SSB

########################################################################
# Give $XZUID to your (gchange friends)
########################################################################
echo "SETTING ASTRXBIAN PROFILE NAME = $XZUID"
echo "$XZUID" > ~/.zen/ipfs/.${IPFSNODEID}/_xbian.zuid

## AJOUTER COORD GPS :!!!!!


echo "
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWNKkxllllllldk0NWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMXx:..';lokkxkkol;'..;d0WMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMXo' 'dKWMMMMMX.;WMMMMMXk;..c0WMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMKc .xNMMMMMMMMN.  :MMMMMMMMWO, ,OWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWl .kMMMMMMMMMMN.    :MMMMMMMMMMK; :XMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMX, lWMMMMMMMMMMW.      cMMMMMMMMMMMk .OMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMX' OMMMMMMMMMMMW,        lMMMMMMMMMMMX..OMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMW: xMMMMMMMMMMMM;          dMMMMMMMMMMMK .XMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMO 'MMMMMMMMMMMMc            xMMMMMMMMMMMl oMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWl xMMMMMMMMMMMl              kMMMMMMMMMMX 'WMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWc OMMMMMMMMMMl                kMMMMMMMMMM.'WMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWc xMMMMMMMMMd          .       OMMMMMMMMN 'WMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMk ,MMMMMMMMx      :WMMWWN;      0MMMMMMMo lWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMN; kMMMMMMO      ,WW,            KMMMMMX..KMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMK. KMMMM0      .NW,             .KMMMN. kMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMK. xMM0       XW,               .KM0..kMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMNc ,O;',,,,,0MK:::::::::ccclooodxl ;KMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMW0; ,OWMMMMMMMMMMMMMMMMMMMMMMK: 'kWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMKc..:kNMMMMMMMMMMMMMMMWOc..:kWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWKo,..,:odO0000xdc;..'lOWMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMWXOdo:::::::ldkKNMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM
MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM

ASTROPORT ONE.
"
########################################################################
echo "Activation Identité $XZUID + Optimisations IPFS"
########################################################################
# DHT gossip PUBSUB mode
ipfs config Pubsub.Router gossipsub
# MAXSTORAGE = 1/2 available
availableDiskSize=$(df -P ~/ | awk 'NR>1{sum+=$4}END{print sum}')
diskSize="$((availableDiskSize / 2))"
ipfs config Datastore.StorageMax $diskSize
# Activate Rapid "ipfs p2p"
ipfs config --json Experimental.Libp2pStreamMounting true
ipfs config --json Experimental.P2pHttpProxy true

ipfs config Addresses.Gateway "/ip4/0.0.0.0/tcp/8080"

# REMOVE IPFS BOOTSTRAP ###########
ipfs bootstrap rm --all

## ARIES COLLECT REGULARLY OASIS ADDRESS
# ARIES IPNS KEY /ip4/37.187.127.175/tcp/4001/p2p/12D3KooWSQYTxeoZZ39SNosEKxi7RUdGTtAQAqpKeZJxjzqqrZTx
for bootnode in $(ipfs cat /ipns/12D3KooWSQYTxeoZZ39SNosEKxi7RUdGTtAQAqpKeZJxjzqqrZTx/.12D3KooWSQYTxeoZZ39SNosEKxi7RUdGTtAQAqpKeZJxjzqqrZTx/bootstrap)
do
    ## ADD $bootnode TO BOOTSTRAP
    ipfs bootstrap add $bootnode
done

########################################################################
echo "Installation de youtube-dl - Copions le Web avant qu'il ne ferme" # Avoid provider restrictions
########################################################################
${MY_PATH}/tools/install.youtube-dl.sh
#TODO# SWITCH TO yt-dlp
sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
sudo chmod a+rx /usr/local/bin/yt-dlp


exit 0
