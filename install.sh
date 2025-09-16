#!/bin/bash
########################################################################
# Version: 0.3
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
{
## Détection emplacement script et initialisation "MY_PATH"
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
start=`date +%s`

##################################################################  SUDO
##  Lancement "root" interdit...
########################################################################
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. " && exit 1
[[ ! $(groups | grep -w sudo) ]] \
    && echo "AUCUN GROUPE \"sudo\" : su -; usermod -aG sudo $USER" \
    && su - && apt-get install sudo -y \
    && echo "Run Install Again..." && exit 0

################################################################### IPFS
## installation de ipfs
########################################################################
[[ ! $(which ipfs) ]] \
&& echo "bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.kubo_v0.30.0_linux.sh)" \
&& architecture=$(uname -m) && [[ $architecture == "x86_64" ||  $architecture == "aarch64" || "$architecture" == "armv7l" ]] \
&& bash <(wget -qO- https://raw.githubusercontent.com/papiche/Astroport.ONE/master/install.kubo_v0.30.0_linux.sh) \
|| echo "=== IPFS FOUND === OK"

[[ ! $(which ipfs) ]] && echo "INSTALL IPFS PLEASE" && exit 1

####################################################################
# MAIN # AUCUNE CLEF PLAYER...
if [[ ! -d ~/.zen/game/players/ ]];
then
echo "#############################################"
echo "###### ASTROPORT.ONE ZEN STATION ##############"
echo "############# TW HOSTING & Ŋ1 SERVICES #############"
echo "##################################################"
mkdir -p ~/.zen

echo ; echo "UPDATING SYSTEM REPOSITORY"
#~ [[ $XDG_SESSION_TYPE == 'x11' || $XDG_SESSION_TYPE == 'wayland' ]] && sudo add-apt-repository ppa:obsproject/obs-studio
sudo apt-get update

echo "#############################################"
echo "######### INSTALL PRECIOUS FREE SOFTWARE ####"
echo "#############################################"
for i in git tldr ssss make cmake docker.io docker-compose hdparm iptables fail2ban openssh-server parallel npm shellcheck multitail netcat-traditional ncdu chromium miller inotify-tools curl net-tools mosquitto libsodium* libcurl4-openssl-dev libgpgme-dev libffi-dev; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

echo "#############################################"
echo "######### INSTALL PYTHON3 SYSTEM LIBRARIES ####"
echo "#############################################"
for i in pipx python3-pip python3-setuptools python3-wheel python3-dotenv python3-gpg python3-jwcrypto python3-brotli python3-aiohttp python3-prometheus-client python3-tk ssss; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

echo "#############################################"
echo "######### INSTALL MULTIMEDIA & DATA TOOLS  ######"
echo "#############################################"
for i in qrencode pv gnupg gpa pandoc cargo btop prometheus ocrmypdf ca-certificates basez markdown jq bc file gawk ffmpeg geoip-bin dnsutils ntpdate v4l-utils espeak vlc mp3info musl-dev openssl* detox nmap httrack html2text imagemagick; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

echo "#############################################"
echo "######### INSTALL ASCII ART TOOLS ######"
echo "#############################################"
for i in figlet cmatrix cowsay fonts-hack-ttf; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

#### GIT CLONE ###############################################################
echo "#############################################"
echo "=== CODE CLONING TO '~/.zen/Astroport.ONE' ==="
echo "#############################################"
mkdir -p ~/.zen/workspace
cd ~/.zen/workspace
git clone --depth 1 https://github.com/papiche/UPlanet
cd ~/.zen
git clone --depth 1 https://github.com/papiche/Astroport.ONE.git
# TODO INSTALL FROM IPFS / IPNS

echo "#############################################"
echo "######### INSTALL TIDDLYWIKI ############"
echo "#############################################"
##########################################################
sudo npm install -g tiddlywiki@5.2.3
[[ $? != 0 ]] \
    && echo "INSTALL tiddlywiki FAILED." \
    && echo "INSTALL tiddlywiki FAILED." >> ~/.zen/install.errors.log

## Correct PDF restrictions for imagemagick
echo "######### IMAGEMAGICK PDF ############"
if [[ $(cat /etc/ImageMagick-6/policy.xml | grep PDF) ]]; then
    cat /etc/ImageMagick-6/policy.xml | grep -Ev PDF > /tmp/policy.xml
    sudo cp /tmp/policy.xml /etc/ImageMagick-6/policy.xml
fi

### PYTHON ENV
sudo ln -f -s /usr/bin/python3 /usr/bin/python
cd $HOME
[[ ! -s ~/.astro/bin/activate ]] && python -m venv .astro
. ~/.astro/bin/activate
cd -

echo "#####################################"
echo "## PYTHON TOOLS & CRYPTO LIB ##"
echo "#####################################"
export PATH=$HOME/.local/bin:$PATH
pipx install duniterpy --include-deps ## keeps own dep
## add monero & bitcoin compatible keys
for i in pip python-dotenv setuptools wheel termcolor amzqr ollama requests beautifulsoup4 pyppeteer cryptography jwcrypto secp256k1 Ed25519 gql base58 pybase64 google silkaj pynacl python-gnupg pgpy pynentry paho-mqtt aiohttp ipfshttpclient bitcoin monero ecdsa pynostr bech32 nostpy-cli; do
        echo ">>> Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        pip install -U $i 2>> ~/.zen/install.errors.log
        # [[ $? != 0 ]] && pipx install $i 2>> ~/.zen/install.errors.log
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "python -m pip install -U $i FAILED." >> ~/.zen/install.errors.log && continue
done

if [[ $(which X 2>/dev/null) ]]; then
    echo "#############################################"
    echo "######### INSTALL DESKTOP TOOLS  ######"
    echo "#############################################"
    for i in x11-utils xclip zenity; do
        if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
            echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
            sudo apt install -y $i;
            [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue
        fi
    done
fi

echo "#############################################"
echo "#############################################"
LP=$(ls /dev/usb/lp* 2>/dev/null)
if [[ ! -z $LP ]]; then
echo "######### $LP PRINTER ##############"
########### QRCODE : ZENCARD / G1BILLET : PRINTER ##############
    ## PRINT & FONTS
    sudo apt install ttf-mscorefonts-installer printer-driver-all cups -y
    pip install brother_ql
    # pipx install brother_ql
    sudo cupsctl --remote-admin
    sudo usermod -aG lpadmin $USER
    sudo usermod -a -G tty $USER
    sudo usermod -a -G lp $USER
    ## brother_ql_print
    echo "$USER ALL=(ALL) NOPASSWD:/usr/local/bin/brother_ql_print" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/brother_ql_print')
fi

## UPASSPORT API
echo "######### UPASSPORT ##############"
echo "INSTALL UPASSPORT : http://localhost:54321"
~/.zen/Astroport.ONE/install_upassport.sh

## NIP-101 strfry NOSTR relay
echo "######### NIP-101 strfry NOSTR relay ##############"
echo "INSTALL NOSTR RELAY : wss://localhost:7777"
bash <(wget -qO- https://github.com/papiche/NIP-101/raw/refs/heads/main/install_strfry.sh)

## G1BILLET
echo "######### G1BILLET ##############"
echo "INSTALL G1BILLET : http://g1billet.localhost:33101"
cd ~/.zen
git clone https://github.com/papiche/G1BILLET.git
cd G1BILLET && ./setup_systemd.sh
cd -

echo

###############################################################
echo "##  ADDING lazydocker ================"
# INSTALL lazydocker GUI
${MY_PATH}/install.lazydocker.sh

###############################################################
echo "##INSTALL yt-dlp & SYMLINK youtube-dl ##########################"
~/.zen/Astroport.ONE/youtube-dl.sh

echo "=== SETUP ASTROPORT"
~/.zen/Astroport.ONE/setup.sh

end=`date +%s`
echo Installation time was `expr $end - $start` seconds.

echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "xXX LOG ERRORS XXx"
cat ~/.zen/install.errors.log
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "xXX please report any errors encountered during install  XXx"
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
echo "RUN TEST : ~/.zen/Astroport.ONE/test.sh"
echo
echo "#########################################################"
echo "Astroport.ONE - Web3 Information System over IPFS - "
echo "#############################################"
echo "### ASK FOR SUPPORT #########################"
echo "### support@qo-op.com"
echo "#############################################"

echo
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    🏴‍☠️ INSTALLATION TERMINÉE 🏴‍☠️                            ║"
echo "║                                                                              ║"
echo "║  Félicitations ! Astroport.ONE est maintenant installé sur votre machine.   ║"
echo "║                                                                              ║"
echo "║  🎯 PROCHAINES ÉTAPES:                                                       ║"
echo "║                                                                              ║"
echo "║  1. 🚀 EMBARQUEMENT UPLANET ẐEN (Recommandé)                                ║"
echo "║     Rejoignez la coopérative des autohébergeurs                             ║"
echo "║     → ~/.zen/Astroport.ONE/uplanet_onboarding.sh                            ║"
echo "║                                                                              ║"
echo "║  2. 🏴‍☠️ EMBARQUEMENT CAPITAINE SIMPLE                                        ║"
echo "║     Configuration basique pour commencer                                    ║"
echo "║     → ~/.zen/Astroport.ONE/captain.sh                                       ║"
echo "║                                                                              ║"
echo "║  3. 📊 TABLEAU DE BORD                                                       ║"
echo "║     Interface principale de gestion                                         ║"
echo "║     → ~/.zen/Astroport.ONE/tools/dashboard.sh                               ║"
echo "║                                                                              ║"
echo "║  4. 🌐 INTERFACE WEB                                                         ║"
echo "║     → http://astroport.localhost/ipns/copylaradio.com                       ║"
echo "║                                                                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

# Proposer l'embarquement UPlanet ẐEN
echo "🎯 VOULEZ-VOUS REJOINDRE LA COOPÉRATIVE UPLANET ẐEN ?"
echo
echo "La coopérative UPlanet ẐEN vous permet de:"
echo "• 💰 Monétiser votre infrastructure (hébergement, stockage, calcul)"
echo "• 🤝 Participer à une économie décentralisée et équitable"
echo "• 🏛️  Devenir sociétaire d'une coopérative technologique"
echo "• 🌍 Contribuer à un internet libre et décentralisé"
echo
echo "L'assistant d'embarquement vous guidera pour:"
echo "• Configurer vos paramètres économiques (PAF, tarifs)"
echo "• Valoriser votre machine comme capital social"
echo "• Rejoindre le réseau swarm UPlanet"
echo "• Initialiser votre infrastructure économique"
echo "• Passer au niveau Y (autonome)"
echo

read -p "🚀 Lancer l'assistant d'embarquement UPlanet ẐEN maintenant ? (O/n): " launch_onboarding

if [[ "$launch_onboarding" != "n" && "$launch_onboarding" != "N" ]]; then
    echo
    echo "🏴‍☠️ Lancement de l'assistant d'embarquement UPlanet ẐEN..."
    echo
    ~/.zen/Astroport.ONE/uplanet_onboarding.sh
else
    echo
    echo "📋 MÉMO POUR PLUS TARD:"
    echo "• Embarquement UPlanet ẐEN: ~/.zen/Astroport.ONE/uplanet_onboarding.sh"
    echo "• Embarquement simple: ~/.zen/Astroport.ONE/captain.sh"
    echo "• Tableau de bord: ~/.zen/Astroport.ONE/tools/dashboard.sh"
    echo
fi

echo "#############################################"
. ~/.bashrc


else

echo "ABORTING INSTALL
===============================
PLAYER already onboard...
===============================
$(cat ~/.zen/game/players/.current/secret.june)
==============================="
# MAIN #

fi
}
