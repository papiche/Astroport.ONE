#!/bin/bash
############################################################ install.sh
# Version: 0.5 (Modifié pour forcer MAJ apt/pip)
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
{
## Détection emplacement script et initialisation "MY_PATH"
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
start=`date +%s`
################################################################## HELP
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "================================================================="
    echo "                 🚀 ASTROPORT.ONE INSTALLER 🚀                 "
    echo "================================================================="
    echo "Usage :"
    echo "  bash install.sh [EMAIL] [NODE_DOMAIN] [EMAIL_DOMAIN] [PROFILE]"
    echo ""
    echo "Options :"
    echo "  --help, -h       Affiche cette aide et quitte."
    echo ""
    echo "Paramètres positionnels (optionnels) :"
    echo "  1. EMAIL         Email du Capitaine (ex: alice@mail.com)."
    echo "                   Laissez vide (\"\") pour un email automatique."
    echo "  2. NODE_DOMAIN   Domaine du Nœud/Armateur (ex: ma-base.org)."
    echo "                   Laissez vide (\"\") pour copylaradio.com."
    echo "  3. EMAIL_DOMAIN  Domaine pour l'email captainerie (ex: mon-asso.org)."
    echo "                   Laissez vide (\"\") pour qo-op.com."
    echo "  4. PROFILE       Profil d'installation (voir ci-dessous)."
    echo "                   Laissez vide pour l'installation standard."
    echo ""
    echo "Profils disponibles :"
    echo "  (vide)         Standard : IPFS + Nostr strfry + UPassport + Astroport"
    echo "  nextcloud      Standard + NextCloud AIO (cloud privé 128Go pour ZEN Card)"
    echo "  ai-company  Standard + Stack IA (Ollama + Dify.ai + Open WebUI + Qdrant)"
    echo "                 → install-ai-company.docker.sh + code_assistant"
    echo "  dev            Standard + rnostr (remplace strfry, sémantique Qdrant)"
    echo ""
    echo "Variables d'environnement supportées :"
    echo "  CAPTAIN_EMAIL, NODE_DOMAIN, CAPTAIN_EMAIL_DOMAIN, INSTALL_PROFILE"
    echo "  INSTALL_OLLAMA=yes|no    → Ollama (si GPU détecté)"
    echo "  INSTALL_COMFYUI=yes|no   → ComfyUI Docker (si GPU détecté)"
    echo ""
    echo "Exemples d'installation silencieuse :"
    echo "  bash install.sh \"\" \"ma-base.org\"                    -> Standard sur ma-base.org"
    echo "  bash install.sh \"\" \"\" \"\" nextcloud               -> Standard + NextCloud"
    echo "  bash install.sh \"\" \"\" \"\" ai-company           -> Standard + Stack IA"
    echo "  bash install.sh \"contact@me.com\" \"\" \"\" dev       -> Dev (rnostr)"
    echo "================================================================="
    exit 0
fi
########################################################################
##################################################################  SUDO
##  Lancement "root" interdit...
########################################################################
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. " && exit 1
[[ ! $(groups | grep -w sudo) ]] \
    && echo "AUCUN GROUPE \"sudo\" : su -; usermod -aG sudo $USER" \
    && su - && apt-get install sudo -y \
    && echo "Run Install Again..." && exit 0

################################################################## EMAIL & DOMAINE CAPITAINE
## Paramètres :
## $1 = Email personnalisé (ou "" pour auto)
## $2 = Domaine Armateur/Noeud (ou "" pour copylaradio.com)
## $3 = Domaine Email Capitaine (ou "" pour qo-op.com, si email auto)
########################################################################
export CUSTOM_CAPTAIN_EMAIL="${1:-${CAPTAIN_EMAIL:-}}"
export CUSTOM_NODE_DOMAIN="${2:-${NODE_DOMAIN:-}}"
export CUSTOM_EMAIL_DOMAIN="${3:-${CAPTAIN_EMAIL_DOMAIN:-}}"
export INSTALL_PROFILE="${4:-${INSTALL_PROFILE:-}}"

if [[ -z "$CUSTOM_CAPTAIN_EMAIL" && -z "$CUSTOM_NODE_DOMAIN" ]]; then
    echo "========================================================="
    echo "  EMBARQUEMENT CAPITAINE & ARMATEUR"
    echo "========================================================="
    echo "Appuyez sur Entrée pour utiliser les valeurs automatiques."
    read -p "Email Capitaine [auto: support+node...@qo-op.com] : " CUSTOM_CAPTAIN_EMAIL
    read -p "Domaine Noeud   [auto: copylaradio.com]           : " CUSTOM_NODE_DOMAIN
    echo ""
    echo "Profil d'installation :"
    echo "  (vide)         Standard (recommandé)"
    echo "  nextcloud      + NextCloud AIO cloud privé 128Go"
    echo "  ai-company  + Stack IA Swarm (Ollama, Dify.ai, Open WebUI)"
    echo "  dev            + rnostr (remplace strfry — expérimental)"
    read -p "Profil         [standard]                         : " INSTALL_PROFILE
fi

[[ -n "$CUSTOM_CAPTAIN_EMAIL" ]] && echo ">>> Email Capitaine : $CUSTOM_CAPTAIN_EMAIL" || echo ">>> Email Capitaine : Automatique"
[[ -n "$CUSTOM_NODE_DOMAIN" ]]   && echo ">>> Domaine Noeud   : $CUSTOM_NODE_DOMAIN"   || echo ">>> Domaine Noeud   : Automatique (copylaradio.com)"
[[ -n "$CUSTOM_EMAIL_DOMAIN" ]]  && echo ">>> Domaine Email   : $CUSTOM_EMAIL_DOMAIN"  || echo ">>> Domaine Email   : Automatique (qo-op.com)"

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

## S'assurer que tous les scripts principaux sont exécutables après le clone
chmod +x ~/.zen/Astroport.ONE/*.sh \
         ~/.zen/Astroport.ONE/tools/*.sh \
         ~/.zen/Astroport.ONE/RUNTIME/*.sh 2>/dev/null || true
echo "✅ Scripts rendus exécutables"

## Créer .env depuis template si absent (évite "Aucun fichier" au démarrage des services)
[[ ! -f ~/.zen/Astroport.ONE/.env ]] \
    && cp ~/.zen/Astroport.ONE/.env.template ~/.zen/Astroport.ONE/.env \
    && echo "✅ ~/.zen/Astroport.ONE/.env créé depuis .env.template" \
    || echo "ℹ️  ~/.zen/Astroport.ONE/.env déjà présent"

################################################################### IPFS
## installation de ipfs
########################################################################
[[ ! $(which ipfs) ]] \
&& ~/.zen/Astroport.ONE/install/install.kubo_v0.40.0_linux.sh \
|| echo "=== IPFS FOUND === OK"

[[ ! $(which ipfs) ]] && echo "INSTALL IPFS PLEASE" && exit 1


####################################################################
# MISES À JOUR GLOBALES (APT & PIP) 
# -> S'exécute TOUJOURS, même si une installation est déjà présente
####################################################################
echo "#############################################"
echo "###### MISE A JOUR DU SYSTEME (APT/PIP) #####"
echo "#############################################"

# Mise à jour générale des paquets existants
sudo apt-get update -y
# sudo apt-get upgrade -y ## run at the beginning could need reboot !!

echo "#############################################"
echo "######### INSTALL PRECIOUS FREE SOFTWARE ####"
echo "#############################################"
for i in zip ssss make cmake hdparm iptables ufw fail2ban wireguard openssh-server sshfs parallel npm shellcheck multitail netcat-traditional socat ncdu chromium miller inotify-tools curl net-tools libsodium* miniupnpc libcurl4-openssl-dev libgpgme-dev libffi-dev; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue
    fi
done

echo "#############################################"
echo "####### INSTALL PYTHON3 SYSTEM LIBRARIES ####"
echo "#############################################"
for i in pipx python3-pip python3-setuptools python3-base58 python3-wheel python3-dotenv python3-gpg python3-jwcrypto python3-brotli python3-aiohttp python3-prometheus-client python3-tk; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>><<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> ~/.zen/install.errors.log && continue
    fi
done

echo "#############################################"
echo "##### INSTALL MULTIMEDIA & DATA TOOLS  ######"
echo "#############################################"
for i in qrencode pv gnupg pandoc cargo btop sox ocrmypdf ca-certificates basez markdown jq bc file gawk ffmpeg geoip-bin bind9-dnsutils ntpsec-ntpdate v4l-utils espeak vlc mp3info musl-dev openssl detox nmap httrack html2text imagemagick; do
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

echo "################################## ~/.astro/bin PYTHON ENV"
cd $HOME
## Ubuntu 22.04 : 'python' n'existe pas → utiliser python3
if [[ ! -s ~/.astro/bin/activate ]]; then
    python3 -m venv .astro \
        && echo "✅ Python venv créé : ~/.astro" \
        || echo "⚠️  Création venv échouée (python3 absent ?)"
fi
[[ -s ~/.astro/bin/activate ]] && . ~/.astro/bin/activate || echo "⚠️  ~/.astro/bin/activate absent — pip install sans venv"
cd -

echo "#####################################"
echo "## PYTHON TOOLS & CRYPTO LIB ##"
echo "#####################################"
export PATH=$HOME/.local/bin:$PATH
pipx install duniterpy --include-deps ## keeps old v1 dep (soon deprecated)
## add monero & bitcoin compatible keys
for i in pip python-dotenv scrypt setuptools wheel termcolor amzqr ollama requests geohash beautifulsoup4 cryptography jwcrypto secp256k1 gql base58 pybase64 google pynacl python-gnupg pynentry paho-mqtt aiohttp ipfshttpclient bitcoin monero ecdsa pynostr bech32 matplotlib readability-lxml duniterpy cachetools pydantic-settings robohash substrate-interface; do
        echo ">>> Installation/Mise à jour $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        pip install -U $i 2>> ~/.zen/install.errors.log
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "python -m pip install -U $i FAILED." >> ~/.zen/install.errors.log && continue
done
## playwright remplace pyppeteer (abandonné 2022) pour tools/page_screenshot.py
echo ">>> playwright (remplaçant pyppeteer — tools/page_screenshot.py) <<<"
pip install -U playwright 2>> ~/.zen/install.errors.log \
    && echo "✅ playwright installé" \
    || echo "⚠️  playwright install FAILED — voir ~/.zen/install.errors.log"
## Installe le binaire Chromium de playwright (utilise le Chromium système si présent)
python -m playwright install chromium 2>> ~/.zen/install.errors.log \
    && echo "✅ playwright chromium prêt" \
    || echo "⚠️  playwright chromium install FAILED (page_screenshot.py utilisera /usr/bin/chromium)"


####################################################################
# MAIN # VÉRIFICATION CLÉ PLAYER POUR SUITE INSTALLATION COMPLETE
if [[ ! -d ~/.zen/game/players/ ]];
then

echo "#############################################"
echo "###### ASTROPORT.ONE ZEN STATION ############"
echo "#############################################"
echo "######### INSTALL DOCKER ........ ###########"
echo "#############################################"
~/.zen/Astroport.ONE/install/install.docker.sh

echo "#############################################"
echo "######### INSTALL TIDDLYWIKI ############"
echo "#############################################"
##########################################################
sudo npm install -g tiddlywiki@5.2.3
[[ $? != 0 ]] \
    && echo "INSTALL tiddlywiki FAILED." \
    && echo "INSTALL tiddlywiki FAILED." >> ~/.zen/install.errors.log

## ── Vérification Docker, Node.js, NPM, TiddlyWiki ───────────────────────────
echo "#############################################"
echo "######### VERIFICATION DOCKER & NODE   ######"
echo "#############################################"
DOCKER_OK=false; NPM_OK=false; TW_OK=false; DOCKER_COMPOSE_OK=false; DENO_OK=false
## Utiliser sg docker pour éviter de nécessiter newgrp (groupe activé sans nouveau shell interactif)
sg docker -c "docker --version" 2>/dev/null && DOCKER_OK=true || echo "⚠️  Docker non disponible"
sg docker -c "docker compose version" 2>/dev/null && DOCKER_COMPOSE_OK=true || echo "⚠️  Docker Compose non disponible"
node --version 2>/dev/null && NPM_OK=true || echo "⚠️  Node.js non disponible"
npm --version 2>/dev/null || echo "⚠️  NPM non disponible"
tiddlywiki --version 2>/dev/null && TW_OK=true || echo "⚠️  TiddlyWiki non accessible (PATH?)"
## Deno : moteur JS alternatif pour yt-dlp EJS quand Node < v20
## Permet aussi d'exécuter des scripts navigateur dans un conteneur Docker (youtube-dl via EJS)
deno --version 2>/dev/null | head -1 && DENO_OK=true || echo "⚠️  Deno non disponible (yt-dlp EJS peut être affecté)"
echo ""
echo "  Docker    : $($DOCKER_OK && echo '✅' || echo '❌')  | Compose : $($DOCKER_COMPOSE_OK && echo '✅' || echo '❌')"
echo "  Node.js   : $($NPM_OK && echo '✅' || echo '❌')  | TW      : $($TW_OK && echo '✅' || echo '❌')  | Deno : $($DENO_OK && echo '✅' || echo '❌')"
echo ""
echo "  DOCKER STATUS:"
sg docker -c "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null | head -10 || echo "  (aucun conteneur)"
echo "#############################################"

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

## g1cli (gcli) — Duniter v2s CLI client (compiled from source, branche nostr)
echo "######### g1cli Duniter v2 Client ##############"
~/.zen/Astroport.ONE/install/install_gcli.sh

## G1BILLET -- needs reviewing --- code used for .print.sh scipt
echo "######### G1BILLET ##############"
echo "INSTALL G1BILLET : http://g1billet.localhost:33101"
cd ~/.zen
git clone https://github.com/papiche/G1BILLET.git
# cd G1BILLET && ./setup_systemd.sh ## NETWORK SERVICE NOT USED
cd -

echo

###############################################################
echo "##  ADDING lazydocker ================"
~/.zen/Astroport.ONE/install/install.lazydocker.sh

###############################################################
echo "## INSTALL yt-dlp (youtube copier, sans anti-bot) ##############"
# Anti-bot optionnel : astrosystemctl local install youtube-antibot
~/.zen/Astroport.ONE/install/youtube-dl.sh

###############################################################
echo "## INSTALL PowerJoular (Power consumption monitoring) ##########"
~/.zen/Astroport.ONE/install/install_powerjoular.sh

###############################################################
## prometheus-node-exporter seul : léger, expose /metrics sur :9100
## Prometheus serveur complet : installé uniquement avec le profil ai-company
echo "## INSTALL prometheus-node-exporter (heartbox metrics export) ##########"
sudo apt-get install -y prometheus-node-exporter 2>/dev/null \
    && echo "✅ prometheus-node-exporter actif sur :9100" \
    || echo "⚠️  prometheus-node-exporter non disponible"

if [[ $INSTALL_PROFILE == "dev" ]]; then
    ###############################################################
    echo "## INSTALL Flutter SDK (web builds for Ginkgo app) ##########"
    ~/.zen/Astroport.ONE/install/install_flutter.sh
    ## Add Flutter to PATH for the rest of install
    export PATH="$HOME/.flutter/bin:$PATH"
fi 

echo "=== INSTALL SYSTEM (sudoers, systemd, SSH, symlinks)"
~/.zen/Astroport.ONE/install/install_system.sh

echo "=== SETUP ASTROPORT (runtime config)"
~/.zen/Astroport.ONE/install/setup/setup.sh

###############################################################
echo "## ACTIVER LE PARE-FEU UFW ################################"
~/.zen/Astroport.ONE/tools/firewall.sh ON

###############################################################
echo "## INSTALLATIONS CONDITIONNELLES SELON PROFIL ###########"
###############################################################
NEXTCLOUD_ACTIVE=false
AISTACK_ACTIVE=false
RNOSTR_ACTIVE=false

case "${INSTALL_PROFILE}" in
    nextcloud)
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ☁️  PROFIL nextcloud — NextCloud AIO (cloud privé 128Go)    ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        ## NextCloud AIO utilise son propre docker-compose dans _DOCKER/nextcloud/
        ## Ports : 8443 (AIO admin setup), 8001 (Apache nextcloud app), 8002 (AIO dashboard)

        ## ── Vérification et conseil disque BTRFS ────────────────────────────────
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  💾 STOCKAGE — /nextcloud-data                              ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        if [[ -d /nextcloud-data ]]; then
            _NC_FS=$(stat -f -c %T /nextcloud-data 2>/dev/null || findmnt -no FSTYPE /nextcloud-data 2>/dev/null)
            _NC_SIZE=$(df -h /nextcloud-data | tail -1 | awk '{print $2" total, "$4" libre"}' 2>/dev/null)
            echo "║  ✅ /nextcloud-data existe (${_NC_FS:-?} — ${_NC_SIZE:-taille inconnue})  ║"
            if [[ "${_NC_FS}" != "btrfs" ]]; then
                echo "║  ⚡ Conseil: formater en BTRFS pour les avantages suivants :  ║"
                echo "║     • CoW + dédup IPFS (blocs identiques économisés)        ║"
                echo "║     • Snapshots instantanés (sauvegardes NextCloud)         ║"
                echo "║     • compression zstd transparente (~25% espace)           ║"
            else
                echo "║  🌿 Excellent : BTRFS détecté — CoW + compression actifs ✅  ║"
            fi
        else
            echo "║  ⚠️  /nextcloud-data n'existe pas — création en cours...        ║"
            sudo mkdir -p /nextcloud-data
            sudo chown $USER:$USER /nextcloud-data 2>/dev/null || sudo chmod 777 /nextcloud-data
            echo "║  ✅ /nextcloud-data créé                                        ║"
            echo "║                                                               ║"
            echo "║  💡 RECOMMANDATION BTRFS (disque dédié) :                    ║"
            echo "║  Formatez un disque en BTRFS et montez-le sur /nextcloud-data ║"
            echo "║  pour y héberger NextCloud, ~/.zen et ~/.ipfs :               ║"
            echo "║                                                               ║"
            echo "║  sudo mkfs.btrfs -L astrodata /dev/sdX                       ║"
            echo "║  sudo mount -o compress=zstd,noatime /dev/sdX /nextcloud-data ║"
            echo "║  # Dans /etc/fstab :                                          ║"
            echo "║  # UUID=xxx /nextcloud-data btrfs compress=zstd,noatime 0 0  ║"
            echo "║                                                               ║"
            echo "║  Puis migrer les données (voir day3/captain ZINE) :          ║"
            echo "║  sudo mv ~/.zen /nextcloud-data/zen                          ║"
            echo "║  ln -s /nextcloud-data/zen ~/.zen                            ║"
            echo "║  sudo mv ~/.ipfs /nextcloud-data/ipfs                        ║"
            echo "║  ln -s /nextcloud-data/ipfs ~/.ipfs                          ║"
        fi
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""

        _NC_COMPOSE="$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/docker-compose.yml"
        if [[ ! -f "$_NC_COMPOSE" ]]; then
            echo "⚠️  Fichier introuvable : $_NC_COMPOSE"
            echo "   → Vérifiez que Astroport.ONE est bien cloné"
        else
            echo "⏳ Démarrage NextCloud AIO (peut prendre 2-3 minutes)..."
            sg docker -c "docker compose -f '$_NC_COMPOSE' up -d" 2>&1
            _nc_exit=$?
            if [[ $_nc_exit -eq 0 ]]; then
                NEXTCLOUD_ACTIVE=true
                echo "✅ Conteneur nextcloud-aio-mastercontainer démarré"
                ## Attendre que le conteneur soit prêt avant de relancer NPM
                echo "⏳ Attente NextCloud (30s pour initialisation)..."
                sleep 30
                ## Re-lancer setup_npm.sh pour créer le proxy cloud.DOMAIN → :8001
                echo "🔧 Création proxy cloud.${DOMAIN_DISPLAY:-DOMAIN} via NPM..."
                bash "$HOME/.zen/Astroport.ONE/install/setup/setup_npm.sh" 2>/dev/null \
                    && echo "✅ Proxy cloud.$DOMAIN créé dans NPM" \
                    || echo "⚠️  NPM proxy non créé — relancez manuellement : setup_npm.sh"
            else
                echo "⚠️  Erreur démarrage NextCloud (code: $_nc_exit)"
                echo "   → Logs : docker compose -f $_NC_COMPOSE logs"
            fi
        fi
        cd - >/dev/null 2>/dev/null
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  📋 CONFIGURATION NEXTCLOUD AIO — 3 étapes                  ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║                                                               ║"
        echo "║  Ports NextCloud AIO :                                        ║"
        echo "║    8443 = Interface admin AIO (setup initial, HTTPS)         ║"
        echo "║    8001 = Apache NextCloud (app, après config AIO)           ║"
        echo "║    8002 = Dashboard AIO (surveillance, HTTP)                 ║"
        echo "║                                                               ║"
        echo "║  1. SETUP INITIAL — interface AIO (première fois seul.) :   ║"
        echo "║     https://127.0.0.1:8443                                   ║"
        echo "║     → Acceptez le certificat auto-signé                      ║"
        echo "║     → Entrez : cloud.${DOMAIN_DISPLAY:-VOTRE_DOMAINE}       ║"
        echo "║     → AIO télécharge et installe automatiquement NextCloud   ║"
        echo "║     → Activez les apps : Calendar, Contacts, Talk            ║"
        echo "║                                                               ║"
        echo "║  2. PROXY NPM cloud.${DOMAIN_DISPLAY:-DOMAINE} → :8001 :   ║"
        if [[ "${NEXTCLOUD_ACTIVE}" == "true" ]]; then
        echo "║     ✅ CRÉÉ AUTOMATIQUEMENT (setup_npm.sh relancé)           ║"
        echo "║     Vérification : https://cloud.${DOMAIN_DISPLAY:-DOMAINE} ║"
        else
        echo "║     ⚠️  À créer manuellement (NextCloud non démarré) :       ║"
        echo "║     sudo ~/.zen/Astroport.ONE/install/setup/setup_npm.sh    ║"
        fi
        echo "║     NPM admin : http://127.0.0.1:81                         ║"
        echo "║     Mot de passe : cat ~/.zen/nginx-proxy-manager/data/.admin_pass ║"
        echo "║                                                               ║"
        echo "║  3. COMPTES ZEN CARD (1 compte = 1 abonné 128Go) :         ║"
        echo "║     Interface web NextCloud : Utilisateurs → Nouveau         ║"
        echo "║     CLI : docker exec -it nextcloud-aio-mastercontainer \   ║"
        echo "║       bash                                                   ║"
        echo "║     # puis : su -s /bin/bash www-data -c                    ║"
        echo "║     # 'php /var/www/html/occ user:add --display-name U E'   ║"
        echo "║                                                               ║"
        echo "║  📖 Guide : pad.p2p.legal/Smartphone2NextCloud               ║"
        echo "║  📖 Blog  : copylaradio.com — Le pas-à-pas du grand cloud   ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        ;;
    ai-company)
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  🧠 PROFIL ai-company — Stack IA Swarm (EXPÉRIMENTAL)     ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        ## Prometheus serveur complet : collecte les métriques heartbox + node_exporter
        ## Utile pour les Brain-Nodes (GPU) qui veulent monitorer leur charge IA
        echo "⏳ Installation Prometheus + exporters heartbox..."
        ~/.zen/Astroport.ONE/install/install_prometheus.sh \
            && echo "✅ Prometheus heartbox monitoring actif (:9090)" \
            || echo "⚠️  Prometheus — erreur (non bloquant)"
        ~/.zen/Astroport.ONE/install/install-ai-company.docker.sh \
            && AISTACK_ACTIVE=true \
            && echo "✅ AI Company Stack démarrée" \
            || echo "⚠️  AI Stack — erreur (voir ~/.zen/ai-company/)"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ⚠️  AVERTISSEMENT — Stack en cours d'intégration            ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║                                                               ║"
        echo "║  Les services IA démarrés (Dify.ai, Open WebUI, LiteLLM) ║"
        echo "║  ne sont PAS encore intégrés nativement à Astroport.ONE.   ║"
        echo "║  Ils fonctionnent en parallèle mais nécessitent :           ║"
        echo "║                                                               ║"
        echo "║  • Connexion Open WebUI → créer compte admin à 1ère ouvert. ║"
        echo "║  • Connexion Ollama ↔ LiteLLM à valider                    ║"
        echo "║  • Intégration #BRO (NOSTR → Open WebUI OpenAI API)         ║"
        echo "║                                                               ║"
        echo "║  🐉 APPEL AUX DRAGONS U.SOCIETY :                           ║"
        echo "║  Cette stack est votre terrain d'expérimentation.            ║"
        echo "║  Participez à son intégration dans la constellation :        ║"
        echo "║  → support@qo-op.com — Objet : 'DRAGON ai-company'       ║"
        echo "║  → Salon Nostr U.SOCIETY : #BRO develop                     ║"
        echo "║                                                               ║"
        echo "║  Services (si démarrés) :                                    ║"
        echo "║    Open WebUI : http://localhost:8000  ← interface IA        ║"
        echo "║    Dify.ai  :   http://localhost:8010  (agents)              ║"
        echo "║    Qdrant     : http://localhost:6333/dashboard              ║"
        echo "║    Ollama     : http://localhost:11434                       ║"
        echo "║    code_assistant : ~/.zen/Astroport.ONE/code_assistant      ║"
        echo "║                                                               ║"
        echo "║  DOC : ~/.zen/ai-company/install-ai-company.md              ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        ;;
    dev)
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  ⚙️  PROFIL dev — Migration strfry → rnostr (Rust)           ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        ## rnostr = relai Nostr en Rust, plus performant, support Qdrant sémantique
        if [[ -f ~/.zen/Astroport.ONE/install/install_rnostr_semantic.sh ]]; then
            ~/.zen/Astroport.ONE/install/install_rnostr_semantic.sh \
                && RNOSTR_ACTIVE=true \
                && echo "✅ rnostr installé (remplace strfry)" \
                || echo "⚠️  rnostr — erreur d'installation"
        else
            echo "⚠️  install_rnostr_semantic.sh introuvable — rnostr non installé"
            echo "   → compilez depuis : https://github.com/rnostr/rnostr"
        fi
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  📋 CHANTIER DEV — Migration des plugins writePolicy         ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║                                                               ║"
        echo "║  SITUATION ACTUELLE (strfry bash) :                         ║"
        echo "║  Les plugins de filtrage Nostr sont des scripts bash :       ║"
        echo "║  • all_but_blacklist.sh  (filtre principal)                 ║"
        echo "║  • filter/1.sh  7.sh  9735.sh  30023.sh ...                 ║"
        echo "║  Ils reçoivent les événements Nostr via stdin/stdout JSON,   ║"
        echo "║  filtrent par kind, classifient (nobody/player/uplanet),    ║"
        echo "║  gèrent la blacklist et la liste amisOfAmis.txt.            ║"
        echo "║                                                               ║"
        echo "║  OBJECTIF (rnostr Rust) :                                   ║"
        echo "║  Réécrire ces filtres comme des règles rnostr en Rust ou    ║"
        echo "║  comme plugins WASM compatibles rnostr. Avantages :         ║"
        echo "║  • Performance × 10-100 vs bash                             ║"
        echo "║  • Intégration Qdrant sémantique native                     ║"
        echo "║  • Classification IA des messages (LLM local Ollama)        ║"
        echo "║                                                               ║"
        echo "║  FICHIERS À MIGRER :                                        ║"
        echo "║  NIP-101/relay.writePolicy.plugin/all_but_blacklist.sh      ║"
        echo "║  NIP-101/relay.writePolicy.plugin/filter/*.sh               ║"
        echo "║  → Logique cible : rnostr/config.toml rules + Rust plugin   ║"
        echo "║                                                               ║"
        echo "║  🐉 APPEL AUX DRAGONS dev/Rust :                            ║"
        echo "║  → support@qo-op.com — Objet : 'DRAGON rnostr migration'    ║"
        echo "║  → Repo rnostr : https://github.com/rnostr/rnostr           ║"
        echo "║  → Repo NIP-101 : https://github.com/papiche/NIP-101        ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        ;;
    ""|standard)
        echo "   Profil standard — pas d'installation supplémentaire."
        ;;
    *)
        echo "⚠️  Profil inconnu '${INSTALL_PROFILE}' — installation standard uniquement."
        ;;
esac

###############################################################
echo "## DÉTECTION GPU — Installation IA optionnelle ###########"
###############################################################
## Variables optionnelles pour mode silencieux :
##   INSTALL_OLLAMA=yes    → Ollama installé sans confirmation
##   INSTALL_COMFYUI=yes   → ComfyUI installé sans confirmation
##   INSTALL_OLLAMA=no     → Ignoré même si GPU présent
~/.zen/Astroport.ONE/install/install_gpu_ai.sh

###############################################################
echo "## SCORE CARD DU NŒUD ################################"
###############################################################
## Calcul inline — pas de dépendance à IPFS au moment de l'install
_CPU=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo 1)
_RAM=$(awk '/MemTotal/ {printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0)
_VRAM=0
command -v nvidia-smi >/dev/null 2>&1 && \
    _VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
        | awk '{sum+=$1} END {printf "%.0f", sum/1024}')
[[ -z "$_VRAM" || "$_VRAM" == "0" ]] && _VRAM=0
_SCORE=$(( _VRAM * 4 + _CPU * 2 + _RAM / 2 ))

if   [[ $_SCORE -gt 40 ]]; then _TIER="🔥 Brain-Node (GPU)"; _RANK="DRAGON COMPUTE"; _MVAL=$(( _SCORE * 12 )); _PAF_DEFAULT=28
elif [[ $_SCORE -gt 10 ]]; then _TIER="⚡ Standard";         _RANK="DRAGON ORIGIN";  _MVAL=$(( _SCORE * 6  )); _PAF_DEFAULT=14
else                             _TIER="🌿 Léger";            _RANK="Nœud Léger";     _MVAL=100;               _PAF_DEFAULT=7
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🏆 SCORE CARD — Rang dans la constellation                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-58s ║\n" "CPU : ${_CPU} cœurs  RAM : ${_RAM} Go  VRAM : ${_VRAM} Go"
printf "║  %-58s ║\n" "Power-Score : ${_SCORE}  →  ${_TIER}"
printf "║  %-58s ║\n" "Rang DRAGON : ${_RANK}"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-58s ║\n" "Valeur matériel estimée  : ${_MVAL} ẐEN"
printf "║  %-58s ║\n" "PAF hebdomadaire suggérée : ${_PAF_DEFAULT} ẐEN"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "║  Participez au concours DRAGON UPlanet :                    ║"
echo "║  Publiez votre score → kind:30850 (ECONOMY.broadcast.sh)    ║"
echo "║  Faites évaluer votre nœud → support@qo-op.com              ║"
echo "║  → Devenez DRAGON ORIGIN, DRAGON COMPUTE ou DRAGON ẐEN      ║"
echo "╚══════════════════════════════════════════════════════════════╝"

## Initialiser MACHINE_VALUE, PAF, CAPITAL_DATE dans game/.env si absents
_GAME_ENV="$HOME/.zen/game/.env"
mkdir -p "$HOME/.zen/game"
if ! grep -q "^MACHINE_VALUE=" "$_GAME_ENV" 2>/dev/null; then
    echo "MACHINE_VALUE=${_MVAL}"                        >> "$_GAME_ENV"
    echo "PAF=${_PAF_DEFAULT}"                           >> "$_GAME_ENV"
    echo "CAPITAL_DATE=$(date +%Y%m%d)000000000"        >> "$_GAME_ENV"
    echo "DEPRECIATION_WEEKS=156"                        >> "$_GAME_ENV"
    echo "  ✅ Valeurs initiales sauvegardées → ${_GAME_ENV}"
    echo "     MACHINE_VALUE=${_MVAL} ẐEN | PAF=${_PAF_DEFAULT} ẐEN/sem"
fi

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

# echo "######### rnostr + nomic + Qdrant ##############"
# ~/.zen/Astroport.ONE/install/install_rnostr_semantic.sh ## NEED MORE WORK ---TODO migrate strfry plugin to rnsotr rules 
echo "######### Enterprise Swarm AI Stack Manager ##############
TRY IT UPGRADE IT : ~/.zen/Astroport.ONE/install/install-ai-company.docker.sh"

echo
echo "#############################################"
echo "  INSTALLATION TERMINEE (${MINUTES}min ${SECONDS_REM}s)"
echo "#############################################"
echo
echo "  Station:  ${HOSTNAME_DISPLAY}"
echo "  Reseau:   ${NETWORK_DISPLAY}"
echo "  Capitaine: $(cat ~/.zen/game/players/.current/.player 2>/dev/null || echo 'embarquement en cours...')"
echo
echo "  PROFIL INSTALLÉ: ${INSTALL_PROFILE:-standard}"
echo
echo "  INFRASTRUCTURE (Docker) :"
sg docker -c "docker ps --format '    {{.Names}}: {{.Status}}'" 2>/dev/null | head -12 || echo "    (aucun conteneur actif)"
echo
echo "  NODE.JS / NPM / DENO :"
echo "    Node.js    $(node --version 2>/dev/null || echo '⚠️ non disponible')"
echo "    NPM        v$(npm --version 2>/dev/null || echo '⚠️ non disponible')"
echo "    TiddlyWiki $(tiddlywiki --version 2>/dev/null || echo '⚠️ — relancez: sudo npm install -g tiddlywiki@5.2.3')"
echo "    Deno       $(deno --version 2>/dev/null | head -1 || echo '⚠️ non disponible (yt-dlp EJS)')"
echo "    (Deno sert de runtime JS pour yt-dlp EJS : extraction YouTube via navigateur)"
echo
echo "  SERVICES ASTROPORT :"
echo "    Astroport  http://localhost:12345"
echo "    UPassport  http://localhost:54321"
echo "    IPFS       http://localhost:8080"
echo "    NOSTR      ws://localhost:7777"
echo "    G1Billet   http://localhost:33101"
if [[ "${NEXTCLOUD_ACTIVE}" == "true" ]]; then
echo "    NextCloud  http://127.0.0.1:8443  (admin initial)"
echo "               https://cloud.${DOMAIN_DISPLAY}  (via NPM)"
fi
if command -v ollama >/dev/null 2>&1; then
echo "    Ollama     http://localhost:11434  ← LLM GPU local"
fi
if systemctl is-active --quiet comfyui 2>/dev/null; then
echo "    ComfyUI    http://localhost:8188   ← Génération d'images GPU"
fi
if [[ "${AISTACK_ACTIVE}" == "true" ]]; then
echo "    Open WebUI http://localhost:8000  ← portail IA pour les membres"
echo "    Dify.ai    http://localhost:8010  ← création d'agents/workflows"
echo "    Qdrant     http://localhost:6333"
echo "    Ollama     http://localhost:11434"
fi
if [[ "${RNOSTR_ACTIVE}" == "true" ]]; then
echo "    rnostr     ws://localhost:7777  (remplace strfry)"
fi
echo
echo "  VÉRIFICATION DOCKER :"
echo "    docker ps                              # conteneurs actifs"
echo "    docker compose -f ~/.zen/Astroport.ONE/docker-compose.yml ps  # stack principale"
echo "    docker compose logs -f                 # logs en direct"
echo
echo "  ESSAIM (ipfs.domain = round-robin DNS vers toutes les stations):"
echo "    IPFS       ${IPFS_DISPLAY}"
echo "  STATION D'ATTACHE (celle ou votre MULTIPASS est enregistre):"
echo "    Relay      ${RELAY_DISPLAY}"
echo "    UPassport  ${USPOT_DISPLAY}"
echo
echo "  COMMANDES :"
echo "    station      ~/.zen/Astroport.ONE/station.sh          ← INTERFACE PRINCIPALE"
echo "    captain      ~/.zen/Astroport.ONE/captain.sh           (dashboard économique)"
echo "    media        ~/.zen/Astroport.ONE/ajouter_media.sh"
echo "    test         ~/.zen/Astroport.ONE/test.sh"
echo "    start/stop   ~/.zen/Astroport.ONE/start.sh | stop.sh"
if [[ "${AISTACK_ACTIVE}" == "true" ]]; then
echo "    code IA      ~/.zen/Astroport.ONE/code_assistant <fichier>"
echo "    ai stack     docker compose -p ai-company-swarm ps"
fi
echo
echo "  ERREURS: ~/.zen/install.errors.log"
echo "#############################################"
echo
## ─── Message final conditionné par le mode réseau ───────────────────────────
if [[ "${UPLANETNAME}" == "0000000000000000000000000000000000000000000000000000000000000000" || -z "${UPLANETNAME}" ]]; then
## ══════════════════════  MODE ACADÉMIE / UPLANET ORIGIN  ══════════════════════
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║             🎮 ACADÉMIE UPLANET ORIGIN — ÉTAPE 1 / 4                       ║"
echo "╠══════════════════════════════════════════════════════════════════════════════╣"
echo "║                                                                              ║"
echo "║  Cette station fonctionne en mode BACS À SABLE (swarm.key = zéro).          ║"
echo "║  Elle est hébergée par vous (ARMATEUR) mais opérée par le collectif         ║"
echo "║  G1FabLab en attendant votre certification comme CAPITAINE.                 ║"
echo "║                                                                              ║"
echo "║  💰 En tant qu'Armateur, vous pouvez percevoir : 14 Ẑen / semaine          ║"
echo "║     → Souscrivez sur : https://opencollective.com/monnaie-libre             ║"
echo "║                                                                              ║"
echo "║  👉 VOTRE MISSION POUR DEVENIR CAPITAINE :                                  ║"
echo "║                                                                              ║"
echo "║  1. Ouvrez votre navigateur :  http://127.0.0.1:54321/g1                   ║"
echo "║  2. Créez votre MULTIPASS avec votre VÉRITABLE adresse email.               ║"
echo "║  3. Lisez les ZINEs quotidiens que le système va vous envoyer.              ║"
echo "║  4. Contactez support@qo-op.com pour valider votre formation DRAGON.        ║"
echo "║                                                                              ║"
echo "║  🐉 Formation DRAGON → swarm.key privé → UPlanet ẐEN → 28 Ẑen/semaine     ║"
echo "║                                                                              ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
else
## ══════════════════════  MODE PRODUCTION / UPLANET ẐEN  ══════════════════════
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
echo "║  🌐 Notre Système d'Information Décentralisé : https://qo-op.com            ║"
echo "║  📚 Documentation : https://astroport.com                                   ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
fi
echo
. ~/.bashrc
##########################################################
~/.zen/Astroport.ONE/RUNTIME/DRAGON_p2p_ssh.sh ON

else

echo "============================================="
echo " MISES À JOUR (APT/PIP) EFFECTUÉES AVEC SUCCÈS"
echo "============================================="
echo " INSTALLATION COMPLÈTE IGNORÉE :"
echo " PLAYER already onboard..."
echo "============================================="
$(cat ~/.zen/game/players/.current/secret.june)
echo "============================================="
# MAIN #

fi
}