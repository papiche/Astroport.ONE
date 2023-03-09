#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
{
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
start=`date +%s`

##################################################################  SUDO
########################################################################
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. " && exit 1
[[ ! $(groups | grep -w sudo) ]] && echo "AUCUN GROUPE \"sudo\" : su -; usermod -aG sudo $USER" && exit 1
################################################################### IPFS
########################################################################
[[ ! $(which ipfs) ]] \
&& echo "bash <(wget -qO- https://git.p2p.legal/qo-op/Astroport.ONE/raw/branch/master/kubo_v0.16.0_linux.install.sh)" \
&& architecture=$(uname -m) && [[ $architecture == "x86_64" ||  $architecture == "aarch64" || "$architecture" == "armv7l" ]] \
&& bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/kubo_v0.16.0_linux.install.sh) \
|| echo "=== Installez IPFS KUBO puis relancez Install ==="

[[ ! $(which ipfs) ]] && echo "INSTALL IPFS PLEASE" && exit 1
#################################################################### TEST

# MAIN # SI AUCUNE CLEF DE STATION...
if [[ ! -d ~/.zen/game/players/ ]];
then


# Check requirements
echo "Installateur Astroport.ONE pour distributions DEBIAN et dérivées : LinuxMint (https://www.linuxmint.com/)"
# echo "$USER appuyez sur ENTRER."; read TEST;  [[ "$TEST" != "" ]] && echo "SORTIE" && exit 0 ## Ajouter confirmation à chaque nouvelle étape (+explications)
echo "#############################################"
echo "###### IPFS BIOS INSTALL ##############################"
echo "################  CRYPTO TW Ŋ1 PROTOCOL #############"
echo "tail -f /tmp/install.errors.log"
echo "##################################################"

echo ; echo "Mise à jour des dépots de votre distribution..."
#~ [[ $XDG_SESSION_TYPE == 'x11' ]] && sudo add-apt-repository ppa:obsproject/obs-studio
sudo apt-get update


 for i in x11-utils xclip zenity chromium kodi; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        [[ $XDG_SESSION_TYPE == 'x11' ]] && sudo apt install -y $i;
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> /tmp/install.errors.log && continue
    fi
done

echo "#############################################"
echo "######### PATIENCE ####"
echo "#############################################"

for i in git make cmake fail2ban npm netcat-traditional inotify-tools curl net-tools libsodium* libcurl4-openssl-dev python3-pip python3-setuptools python3-wheel python3-dotenv python3-gpg python3-jwcrypto python3-brotli mpack; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> /tmp/install.errors.log && continue

    fi
done
echo "#############################################"
echo "######### PATIENCE ######"
echo "#############################################"
# removed : sqlite
for i in qrencode pv gnupg ca-certificates basez jq bc file gawk yt-dlp ffmpeg dnsutils ntpdate v4l-utils espeak vlc mp3info musl-dev openssl* detox nmap httrack html2text ssmtp imagemagick; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> /tmp/install.errors.log && continue

    fi
done

#### GIT CLONE ###############################################################
echo "=== CLONAGE CODE  '~/.zen/Astroport.ONE' depuis https://github.com"
mkdir -p ~/.zen
cd ~/.zen
git clone --depth 1 https://github.com/papiche/Astroport.ONE.git
# TODO INSTALL FROM IPFS / IPNS

echo "#############################################"
echo "######### PATIENCE ############"
echo "#############################################"
##########################################################
echo "### INSTALL TW node.js"
sudo npm install -g tiddlywiki
[[ $? != 0 ]] && echo "INSTALL tiddlywikiFAILED." && echo "INSTALL tiddlywiki FAILED." >> /tmp/install.errors.log && continue

echo "#############################################"
echo "######### PATIENCE #################"
echo "#############################################
### PROPOSITION DE LOGICIELS COMPLEMETAIRES
#############################################
## OpenCV = 'Vision par Ordinateur en Intelligence Amie'
# sudo apt-get install python3-opencv -y
## CONVERT AUDIO TO MIDI
# pip install basic-pitch
## CACHER LES VISAGES
# python3 -m pip install 'git+https://github.com/ORB-HD/deface'
## ...
## DES SUGGESTIONS ?
## CONTACTER support@qo-op.com
#################################################"

## MAILJET SSMTP RELAYING : ADD YOUR CREDENTIALS
sudo cp ~/.zen/Astroport.ONE/templates/.ssmtprc /etc/ssmtp/ssmtp.conf
sudo ln -s /usr/sbin/ssmtp /usr/bin/ssmtp
sudo chmod 640 /etc/ssmtp/ssmtp.conf
sudo chgrp mail /etc/ssmtp/ssmtp.conf

echo "$USER:support@g1sms.fr:mail.asycn.io:587" | (sudo su -c 'tee -a /etc/ssmtp/revaliases')

## Correct PDF restrictions for imagemagick
echo "# Correction des droits export PDF imagemagick"
if [[ $(cat /etc/ImageMagick-6/policy.xml | grep PDF) ]]; then
    cat /etc/ImageMagick-6/policy.xml | grep -Ev PDF > /tmp/policy.xml
    sudo cp /tmp/policy.xml /etc/ImageMagick-6/policy.xml
fi

echo "###########################"
echo "## INSTALL PYTHON CRYPTO LAYER "
echo "###########################"
sudo ln -f -s  /usr/bin/python3 /usr/bin/python
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.bashrc && source ~/.bashrc; echo "<<< CHECK YOUR >>> PATH=$PATH"

# python3 -m pip install -U pip
# python3 -m pip install -U setuptools wheel
# python3 -m pip install -U cryptography Ed25519 base58 google duniterpy pynacl pgpy pynentry SecureBytes
# python3 -m pip install -U silkaj
# python3 -m pip install -U protobuf==3.19.0

for i in pip setuptools wheel cryptography==3.4.8 Ed25519 base58 google duniterpy pynacl pgpy pynentry SecureBytes amzqr; do
        echo ">>> Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo python3 -m pip install -U $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "python3 -m pip install -U $i FAILED." >> /tmp/install.errors.log && continue
done

cat /tmp/install.errors.log

echo "#############################################"
echo "######### PATIENCE ######################"
echo "#############################################"

########### PRINTER ##############
if [[ "$USER" == "pi" ]]; then ## PROPOSE QR_CODE PRINTER SUR RPI
    echo "ENTER TO INSTALL AMBASSADE PRINTER. Ajouter imprimante compatible 'brother_ql' pour imprimer vos QRCODE"
    read saisie
    if [[ $saisie != "" ]]; then
        sudo apt install ttf-mscorefonts-installer printer-driver-all cups -y
        sudo pip3 install brother_ql
        sudo cupsctl --remote-admin
        sudo usermod -aG lpadmin $USER
        sudo usermod -a -G tty $USER
        sudo usermod -a -G lp $USER

        ## brother_ql_print
        echo "$USER ALL=(ALL) NOPASSWD:/usr/local/bin/brother_ql_print" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/brother_ql_print')
    fi
fi

echo "#############################################"
echo "######### SETUP  #########################"
echo "#############################################"

echo "=== SETUP IPFS SYSTEM"
~/.zen/Astroport.ONE/tools/ipfs_setup.sh
echo "/ip4/127.0.0.1/tcp/5001" > ~/.ipfs/api


~/.zen/Astroport.ONE/setup.sh

if  [[ $(which kodi) && $XDG_SESSION_TYPE == 'x11' ]]; then
(
echo " ### EXPERIMENTAL ### FINISH ASTROPORT/KODI SETUP BY IPFS ## OUI ? ENTER sinon Ctrl+C"
    mkdir -p ~/.zen/tmp/kodi
    echo "PATIENTEZ..."
    ipfs get -o ~/.zen/tmp/kodi/ /ipfs/Qmc763hnsuTqSTDBNagmzca4fSzmcTp9kHoeosaPKC8QvK
    echo '## PLUGIN INSTALL FRANCETV + VSTREAM + FILMSFORACTION'

    mv ~/.kodi ~/.kodi.back 2>/dev/null
    mv ~/.zen/tmp/kodi ~/.kodi \
    && cp -Rf ~/.zen/Astroport.ONE/templates/.uqld /tmp && cd /tmp/.uqld \
    && g++ -o uqload_downloader uqload_downloader.cpp Downloader.cpp -lcurl \
    && [[ -f uqload_downloader ]] && sudo mv uqload_downloader /usr/local/bin/ \
    && sudo ln -s ~/.zen/Astroport.ONE/tools/download_from_kodi_log.sh /usr/local/bin/download_from_kodi_log \
    || echo "SOMETHING IS NOT WORKING WELL : PLEASE CREATE AN ISSSUE"
) &
fi

echo "#############################################"
echo "#############################################"
    echo "Astroport.ONE INSTALLATION"
    end=`date +%s`
echo Execution time was `expr $end - $start` seconds.
echo "#############################################"
echo "%%%%%%%%%%%%%%%%%%%%"
echo "IMPORTER VOTRE COMPTE GCHANGE"
echo "          "
echo "%%%%%%%%%%%%%%%%%%%%"
echo "#############################################"

##########################################################
    ## ON BOARDING PLAYER
    # ~/.zen/Astroport.ONE/start.sh
    ~/.zen/Astroport.ONE/tools/displaytimer.sh 3
    espeak "Please create a player"
    [[ $XDG_SESSION_TYPE == 'x11' ]] \
    && xdg-open "http://astroport.localhost:1234" \
    || ~/.zen/Astroport.ONE/comand.sh


else

echo "Installation existante !!
========================
Astroport/TW
========================
Connectez-vous sur https://gchange.fr avec vos identifiants

$(cat ~/.zen/game/players/.current/secret.june)

Powered by https://astroport.com
"
# MAIN #
fi
}
