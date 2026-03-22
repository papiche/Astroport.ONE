#!/bin/bash
############################################################ install.sh
# Version: 0.4
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

#### GIT CLONE ###############################################################
echo "#############################################"
echo "=== CODE CLONING TO '~/.zen/Astroport.ONE' ==="
echo "#############################################"
echo "UPDATING SYSTEM REPOSITORY"
sudo apt-get update
sudo apt install -y git
mkdir -p ~/.zen/workspace
cd ~/.zen/workspace
git clone --depth 1 https://github.com/papiche/UPlanet
cd ~/.zen
git clone --depth 1 https://github.com/papiche/Astroport.ONE.git
# TODO INSTALL FROM IPFS / IPNS

################################################################### IPFS
## installation de ipfs
########################################################################
[[ ! $(which ipfs) ]] \
&& ~/.zen/Astroport.ONE/install/install.kubo_v0.40.0_linux.sh \
|| echo "=== IPFS FOUND === OK"

[[ ! $(which ipfs) ]] && echo "INSTALL IPFS PLEASE" && exit 1

####################################################################
# MAIN # AUCUNE CLEF PLAYER...
if [[ ! -d ~/.zen/game/players/ ]];
then
echo "#############################################"
echo "###### ASTROPORT.ONE ZEN STATION ############"
echo "#############################################"
echo "######### INSTALL PRECIOUS FREE SOFTWARE ####"
echo "#############################################"
for i in zip ssss make cmake docker.io docker-compose hdparm iptables ufw fail2ban wireguard openssh-server sshfs parallel npm shellcheck multitail netcat-traditional socat ncdu chromium miller inotify-tools curl net-tools mosquitto libsodium* libcurl4-openssl-dev libgpgme-dev libffi-dev; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

echo "#############################################"
echo "####### INSTALL PYTHON3 SYSTEM LIBRARIES ####"
echo "#############################################"
for i in pipx python3-pip python3-setuptools python3-wheel python3-dotenv python3-gpg python3-jwcrypto python3-brotli python3-aiohttp python3-prometheus-client python3-tk ssss; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

echo "#############################################"
echo "##### INSTALL MULTIMEDIA & DATA TOOLS  ######"
echo "#############################################"
for i in qrencode pv gnupg gpa pandoc cargo btop sox prometheus ocrmypdf ca-certificates basez markdown jq bc file gawk ffmpeg geoip-bin dnsutils ntpdate v4l-utils espeak vlc mp3info musl-dev openssl* detox nmap httrack html2text imagemagick; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

echo "#############################################"
echo "######### INSTALL ASCII ART TOOLS ###########"
echo "#############################################"
for i in figlet cmatrix cowsay fonts-hack-ttf; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue

    fi
done

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
    ## Backup AVANT modification (pour restauration par uninstall.sh)
    [[ ! -f /etc/ImageMagick-6/policy.xml.backup ]] \
        && sudo cp /etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/policy.xml.backup \
        && echo "Backup ImageMagick policy.xml → policy.xml.backup"
    cat /etc/ImageMagick-6/policy.xml | grep -Ev PDF > /tmp/policy.xml
    sudo cp /tmp/policy.xml /etc/ImageMagick-6/policy.xml
fi


echo "################################## ~/.astro/bin PYTHON ENV"
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
for i in pip python-dotenv setuptools wheel termcolor amzqr ollama requests geohash beautifulsoup4 pyppeteer cryptography jwcrypto secp256k1 gql base58 pybase64 google pynacl python-gnupg pynentry paho-mqtt aiohttp ipfshttpclient bitcoin monero ecdsa pynostr bech32 nostpy-cli matplotlib readability-lxml duniterpy robohash; do
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
~/.zen/Astroport.ONE/install/install_upassport.sh

## NIP-101 strfry NOSTR relay
echo "######### NIP-101 strfry NOSTR relay ##############"
echo "INSTALL NOSTR RELAY : wss://localhost:7777"
bash <(wget -qO- https://github.com/papiche/NIP-101/raw/refs/heads/main/install_strfry.sh)

echo "######### rnostr + nomic + Qdrant ##############"
~/.zen/Astroport.ONE/install/install_rnostr_semantic.sh

## g1cli (gcli) — Duniter v2s CLI client (compiled from source, branche nostr)
echo "######### g1cli Duniter v2 Client ##############"
~/.zen/Astroport.ONE/install/install_gcli.sh

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
~/.zen/Astroport.ONE/install/install.lazydocker.sh

###############################################################
echo "##INSTALL yt-dlp & SYMLINK youtube-dl ##########################"
~/.zen/Astroport.ONE/install/youtube-dl.sh

###############################################################
echo "## INSTALL Deno (for yt-dlp EJS when Node < 20) ##################"
~/.zen/Astroport.ONE/install/install_deno.sh

###############################################################
echo "## CONFIGURE yt-dlp JavaScript runtime (Deno or Node + EJS) ######"
~/.zen/Astroport.ONE/install/install_yt_dlp_ejs_node.sh

###############################################################
echo "## INSTALL PowerJoular (Power consumption monitoring) ##########"
~/.zen/Astroport.ONE/install/install_powerjoular.sh

###############################################################
echo "## INSTALL Prometheus exporters (heartbox monitoring) ##########"
~/.zen/Astroport.ONE/install/install_prometheus.sh

###############################################################
echo "## INSTALL Flutter SDK (web builds for Ginkgo app) ##########"
~/.zen/Astroport.ONE/install/install_flutter.sh
## Add Flutter to PATH for the rest of install
export PATH="$HOME/.flutter/bin:$PATH"

echo "=== INSTALL SYSTEM (sudoers, systemd, SSH, symlinks)"
~/.zen/Astroport.ONE/install/install_system.sh

echo "=== SETUP ASTROPORT (runtime config)"
~/.zen/Astroport.ONE/install/setup/setup.sh

###############################################################
echo "## ACTIVER LE PARE-FEU UFW ################################"
~/.zen/Astroport.ONE/tools/firewall.sh ON

end=`date +%s`
DURATION=$((end - start))
MINUTES=$((DURATION / 60))
SECONDS_REM=$((DURATION % 60))

## Source my.sh for display variables (domain, hostname, network type)
. ~/.zen/Astroport.ONE/tools/my.sh 2>/dev/null
HOSTNAME_DISPLAY=$(hostname)
DOMAIN_DISPLAY="${myDOMAIN:-copylaradio.com}"
IPFS_DISPLAY="${myIPFS:-https://ipfs.${DOMAIN_DISPLAY}}"
RELAY_DISPLAY="${myRELAY:-wss://relay.${DOMAIN_DISPLAY}}"
USPOT_DISPLAY="${uSPOT:-https://u.${DOMAIN_DISPLAY}}"

if [[ "${UPLANETNAME}" == "0000000000000000000000000000000000000000000000000000000000000000" ]]; then
    NETWORK_DISPLAY="UPlanet ORIGIN (sandbox)"
else
    NETWORK_DISPLAY="UPlanet ZEN (${DOMAIN_DISPLAY})"
fi

echo
echo "#############################################"
echo "  INSTALLATION TERMINEE (${MINUTES}min ${SECONDS_REM}s)"
echo "#############################################"
echo
echo "  Station:  ${HOSTNAME_DISPLAY}"
echo "  Reseau:   ${NETWORK_DISPLAY}"
echo "  Capitaine: $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'embarquement en cours...')"
echo
echo "  SERVICES:"
echo "    Astroport  http://localhost:12345"
echo "    UPassport  http://localhost:54321"
echo "    IPFS       http://localhost:8080"
echo "    NOSTR      ws://localhost:7777"
echo "    G1Billet   http://localhost:33101"
echo
echo "  ESSAIM (ipfs.domain = round-robin DNS vers toutes les stations):"
echo "    IPFS       ${IPFS_DISPLAY}"
echo "  STATION D'ATTACHE (celle ou votre MULTIPASS est enregistre):"
echo "    Relay      ${RELAY_DISPLAY}"
echo "    UPassport  ${USPOT_DISPLAY}"
echo
echo "  COMMANDES:"
echo "    dashboard    ~/.zen/Astroport.ONE/tools/dashboard.sh"
echo "    media        ~/.zen/Astroport.ONE/ajouter_media.sh"
echo "    test         ~/.zen/Astroport.ONE/test.sh"
echo "    start/stop   ~/.zen/Astroport.ONE/start.sh | stop.sh"
echo
echo "  ERREURS: ~/.zen/install.errors.log"
echo "#############################################"
echo
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    🚀 PROCHAINE ÉTAPE — ACTIVATION CAPITAINE               ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                              ║"
echo "║  Votre station est installée et votre compte GMARKMAIL créé.                ║"
echo "║                                                                              ║"
echo "║  ⚠️  IMPORTANT : Pour activer votre statut de Capitaine, un autre           ║"
echo "║  Capitaine de la constellation doit valider votre recrutement en            ║"
echo "║  envoyant la Primo-Transaction Ğ1 vers votre ZEN Card.                     ║"
echo "║                                                                              ║"
echo "║  Sans cette validation, votre compte sera progressivement supprimé         ║"
echo "║  (DESTROY) et la station réinitialisée.                                    ║"
echo "║                                                                              ║"
echo "║  📧 Contactez-nous pour rejoindre la constellation :                        ║"
echo "║     support@qo-op.com                                                       ║"
echo "║                                                                              ║"
echo "║  Indiquez dans votre email :                                                ║"
echo "║    • Votre email GMARKMAIL : $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'voir ci-dessus')  ║"
echo "║    • Votre hostname : $(hostname)                                           ║"
echo "║    • Votre position GPS : $(cat ~/.zen/GPS 2>/dev/null || echo 'non détectée')         ║"
echo "║                                                                              ║"
echo "║  🌐 Notre Sytème d'Information Décentralisé : https://qo-op.com                                        ║"
echo "║  📚 Documentation : https://astroport.com                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo
. ~/.bashrc
##########################################################
~/.zen/Astroport.ONE/RUNTIME/DRAGON_p2p_ssh.sh ON

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
