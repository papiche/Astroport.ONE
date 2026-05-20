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
    echo "  INSTALL_AI_SERVICES      → Liste des services IA à installer (ex: open-webui,qdrant) (si profil ai-company)"
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

################################################################## PARAMÈTRES
## $1 = Email Capitaine (ou "" pour auto)
## $2 = Domaine Armateur/Nœud (ou "" pour copylaradio.com)
## $3 = Domaine Email Capitaine (ou "" pour qo-op.com)
## $4 = Profil d'installation  (ou "" pour standard)
########################################################################
export CUSTOM_CAPTAIN_EMAIL="${1:-${CAPTAIN_EMAIL:-}}"
export CUSTOM_NODE_DOMAIN="${2:-${NODE_DOMAIN:-}}"
export CUSTOM_EMAIL_DOMAIN="${3:-${CAPTAIN_EMAIL_DOMAIN:-}}"
export INSTALL_PROFILE="${4:-${INSTALL_PROFILE:-}}"
## Charger la configuration existante si elle est présente
[[ -f ~/.zen/Astroport.ONE/.env ]] && source ~/.zen/Astroport.ONE/.env
export CUSTOM_CAPTAIN_EMAIL="${CUSTOM_CAPTAIN_EMAIL:-${CAPTAIN_EMAIL:-}}"
export CUSTOM_NODE_DOMAIN="${CUSTOM_NODE_DOMAIN:-${NODE_DOMAIN:-}}"
export CUSTOM_EMAIL_DOMAIN="${CUSTOM_EMAIL_DOMAIN:-${CAPTAIN_EMAIL_DOMAIN:-}}"

########################################################################
echo "## HARDWARE CHECK (détection avant toute question) ##"
########################################################################
_CPU=$(grep -c "processor" /proc/cpuinfo 2>/dev/null || echo 1)
_RAM=$(awk '/MemTotal/ {printf "%.0f", $2/1048576}' /proc/meminfo 2>/dev/null || echo 0)
_VRAM=0; _GPU_VENDOR="none"; _GPU_NAME=""
if command -v nvidia-smi >/dev/null 2>&1; then
    _v=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null \
        | awk '{sum+=$1} END {printf "%.0f", sum/1024}')
    if [[ -n "$_v" && "$_v" -gt 0 ]]; then
        _VRAM=$_v; _GPU_VENDOR="nvidia"
        _GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1 | xargs)
    fi
fi
if [[ $_VRAM -eq 0 ]]; then
    for _sysf in /sys/class/drm/card*/device/mem_info_vram_total; do
        [[ -f "$_sysf" ]] || continue
        _v=$(( $(cat "$_sysf" 2>/dev/null || echo 0) / 1073741824 ))
        [[ "$_v" -gt 0 ]] || continue
        _VRAM=$(( _VRAM + _v ))
        case "$(cat "${_sysf%mem_info_vram_total}vendor" 2>/dev/null)" in
            "0x1002") _GPU_VENDOR="amd" ;;
            "0x8086") _GPU_VENDOR="intel" ;;
            *)        _GPU_VENDOR="unknown" ;;
        esac
    done
fi
if [[ -z "$_GPU_NAME" ]] && command -v lspci >/dev/null 2>&1; then
    _GPU_NAME=$(lspci 2>/dev/null | grep -iE 'VGA|3D|Display' | head -1 | sed 's/^.*: //' | xargs)
    if [[ "$_GPU_VENDOR" == "none" ]]; then
        echo "$_GPU_NAME" | grep -qi 'intel'       && _GPU_VENDOR="intel_integrated"
        echo "$_GPU_NAME" | grep -qi 'amd\|radeon' && _GPU_VENDOR="amd_integrated"
    fi
fi
_SCORE=$(( _VRAM * 4 + _CPU * 2 + _RAM / 2 ))
if   [[ $_SCORE -gt 40 ]]; then _TIER="🔥 Brain-Node"; _RANK="DRAGON COMPUTE"; _MVAL=$(( _SCORE * 12 )); _PAF_DEFAULT=28
elif [[ $_SCORE -gt 10 ]]; then _TIER="⚡ Standard";   _RANK="DRAGON ORIGIN";  _MVAL=$(( _SCORE * 6  )); _PAF_DEFAULT=14
else                             _TIER="🌿 Léger";      _RANK="Nœud Léger";     _MVAL=100;               _PAF_DEFAULT=7
fi

########################################################################
## EMBARQUEMENT INTERACTIF — affiché si aucun argument CLI fourni
########################################################################
if [[ -z "$CUSTOM_CAPTAIN_EMAIL" && -z "$CUSTOM_NODE_DOMAIN" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║            🚀 EMBARQUEMENT ASTROPORT.ONE                    ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  Matériel  : CPU=%sc  RAM=%sGo  VRAM=%sGo  Score=%s        \n" \
        "$_CPU" "$_RAM" "$_VRAM" "$_SCORE"
    printf "║  Tier      : %-48s ║\n" "$_TIER"
    [[ -n "$_GPU_NAME" ]] && printf "║  GPU       : %-48s ║\n" "${_GPU_NAME} (${_GPU_VENDOR})"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  Appuyez sur Entrée pour utiliser les valeurs automatiques. ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    read -r -p "Email Capitaine [auto: support+node...@qo-op.com] : " CUSTOM_CAPTAIN_EMAIL
    read -r -p "Domaine Nœud   [auto: copylaradio.com]            : " CUSTOM_NODE_DOMAIN
fi

[[ -n "$CUSTOM_CAPTAIN_EMAIL" ]] && echo ">>> Email Capitaine : $CUSTOM_CAPTAIN_EMAIL" || echo ">>> Email Capitaine : Automatique"
[[ -n "$CUSTOM_NODE_DOMAIN" ]]   && echo ">>> Domaine Nœud    : $CUSTOM_NODE_DOMAIN"   || echo ">>> Domaine Nœud    : Automatique (copylaradio.com)"
[[ -n "$CUSTOM_EMAIL_DOMAIN" ]]  && echo ">>> Domaine Email   : $CUSTOM_EMAIL_DOMAIN"  || echo ">>> Domaine Email   : Automatique (qo-op.com)"

## Sélection du profil si non fourni en argument ($4)
if [[ -z "$INSTALL_PROFILE" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  PROFIL D'INSTALLATION    (Tier : ${_TIER})                 "
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo "║  (vide)     Standard — IPFS + NOSTR + G1  (recommandé)     ║"
    echo "║  nextcloud  Standard + NextCloud AIO  (cloud privé 128Go)  ║"
    if [[ $_SCORE -gt 10 ]]; then
    echo "║  ai-company Standard + Stack IA  (Ollama, Open WebUI, Qdrant)║"
    else
    echo "║  ai-company ⚠️  Score faible — stack IA déconseillée         ║"
    fi
    echo "║  dev        Standard + rnostr  (relay NOSTR Rust — devs)   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    read -r -p "Profil [standard] : " INSTALL_PROFILE
fi
echo ">>> Profil : ${INSTALL_PROFILE:-standard}"
_env_upsert "INSTALL_PROFILE" "${INSTALL_PROFILE:-standard}" "${HOME}/.zen/Astroport.ONE/.env"

########################################################################
## FAIL-FAST ai-company — vérification GPU AVANT tout téléchargement
########################################################################
if [[ "${INSTALL_PROFILE}" == "ai-company" ]]; then
    if   [[ $_VRAM -ge 24 ]]; then _AI_TIER="🔥 Excellent (≥24 Go) — grands modèles 70B+"
    elif [[ $_VRAM -ge 8  ]]; then _AI_TIER="⚡ Bon (8-23 Go) — modèles 7B-13B"
    elif [[ $_VRAM -ge 4  ]]; then _AI_TIER="🟡 Limité (4-7 Go) — petits modèles 3B-7B"
    elif [[ $_VRAM -ge 1  ]]; then _AI_TIER="⚠️  Très limité (1-3 Go) — ≤ 3B seulement"
    else                            _AI_TIER="❌ Pas de VRAM dédiée"
    fi
    case "$_GPU_VENDOR" in
        nvidia)           _AI_COMPAT="✅ CUDA — Ollama + ComfyUI supportés" ;;
        amd)              _AI_COMPAT="⚠️  ROCm (expérimental) — GPU RX 5000+ requis" ;;
        intel)            _AI_COMPAT="⚠️  SYCL/XPU (expérimental) — Intel Arc requis" ;;
        intel_integrated) _AI_COMPAT="❌ GPU intégré — Ollama/ComfyUI non supportés" ;;
        amd_integrated)   _AI_COMPAT="❌ GPU intégré — Ollama/ComfyUI non supportés" ;;
        *)                _AI_COMPAT="❓ Compatibilité inconnue" ;;
    esac
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  🧠 PROFIL ai-company — vérification matériel               ║"
    printf "║  %-58s ║\n" "GPU    : ${_GPU_NAME:-inconnu}  (${_GPU_VENDOR})"
    printf "║  %-58s ║\n" "VRAM   : ${_VRAM} Go  →  ${_AI_TIER}"
    printf "║  %-58s ║\n" "Compat : ${_AI_COMPAT}"
    echo "╚══════════════════════════════════════════════════════════════╝"
    if [[ $_VRAM -lt 4 || "$_GPU_VENDOR" == *_integrated* ]]; then
        read -r -p "⚠️  Ce profil n'est pas recommandé sur cette machine. Continuer ? [y/N] " _cont
        [[ "${_cont}" != "y" && "${_cont}" != "Y" ]] && exit 1
    fi
fi

#### GIT CLONE ###############################################################
echo "#############################################"
echo "=== CODE CLONING TO '~/.zen/Astroport.ONE' ==="
echo "#############################################"
echo "UPDATING SYSTEM REPOSITORY"
sudo apt-get update
sudo apt install -y git
mkdir -p ~/.zen/workspace
cd ~/.zen/workspace
if [ -d UPlanet ]; then cd UPlanet && git pull && cd ..; else git clone --depth 1 https://github.com/papiche/UPlanet; fi
cd ~/.zen
if [ -d Astroport.ONE ]; then cd Astroport.ONE && git pull && cd ..; else git clone --depth 1 https://github.com/papiche/Astroport.ONE.git; fi
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
for i in zip ssss dos2unix make cmake hdparm iptables ufw fail2ban wireguard openssh-server sshfs parallel npm shellcheck multitail netcat-traditional socat ncdu chromium miller inotify-tools curl net-tools libsodium* miniupnpc libcurl4-openssl-dev libgpgme-dev libffi-dev; do
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
for i in pip python-dotenv scrypt setuptools wheel termcolor amzqr ollama requests geohash beautifulsoup4 cryptography jwcrypto secp256k1 gql base58 pybase64 google pynacl python-gnupg pynentry paho-mqtt aiohttp ipfshttpclient bitcoin monero ecdsa pynostr bech32 matplotlib readability-lxml duniterpy cachetools pydantic-settings robohash substrate-interface websocket; do
        echo ">>> Installation/Mise à jour $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        ~/.astro/bin/pip install -U $i 2>> ~/.zen/install.errors.log
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "python -m pip install -U $i FAILED." >> ~/.zen/install.errors.log && continue
done
## playwright remplace pyppeteer (abandonné 2022) pour tools/page_screenshot.py
echo ">>> playwright (remplaçant pyppeteer — tools/page_screenshot.py) <<<"
~/.astro/bin/pip install -U playwright 2>> ~/.zen/install.errors.log \
    && echo "✅ playwright installé" \
    || echo "⚠️  playwright install FAILED — voir ~/.zen/install.errors.log"
## Installe le binaire Chromium de playwright (utilise le Chromium système si présent)
~/.astro/bin/python -m playwright install chromium 2>> ~/.zen/install.errors.log \
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
    ~/.astro/bin/pip install brother_ql
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

###############################################################
echo "## INSTALL RTK (Rust Token Killer — optimiseur tokens Claude Code) ##"
###############################################################
## Standard : one-liner curl (rapide)
## Dev      : clone + build cargo (modifiable, rebuildable)
if [[ "${INSTALL_PROFILE}" == "dev" ]]; then
    mkdir -p ~/.zen/workspace
    if [[ ! -d ~/.zen/workspace/rtk ]]; then
        git clone --depth 1 https://github.com/rtk-ai/rtk.git ~/.zen/workspace/rtk \
            && echo "✅ RTK cloné dans ~/.zen/workspace/rtk" \
            || echo "⚠️  RTK clone échoué"
    else
        (cd ~/.zen/workspace/rtk && git pull --ff-only 2>/dev/null) && echo "✅ RTK à jour" || true
    fi
    if [[ -f ~/.zen/workspace/rtk/Cargo.toml ]]; then
        echo "⏳ Compilation RTK (cargo build --release)..."
        (cd ~/.zen/workspace/rtk && cargo build --release 2>/dev/null) \
            && cp ~/.zen/workspace/rtk/target/release/rtk ~/.local/bin/rtk \
            && echo "✅ RTK compilé : ~/.local/bin/rtk" \
            || echo "⚠️  RTK build échoué (cargo requis)"
    fi
    ## Sélection de l'éditeur à relier à RTK
    if command -v rtk >/dev/null 2>&1; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║  🔌 RTK — Relier à votre éditeur de code                    ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║  [1] Claude Code (VS Code extension)   rtk init             ║"
        echo "║  [2] Cursor                            rtk init             ║"
        echo "║  [3] Neovim / Vim                      rtk init --global    ║"
        echo "║  [4] Tous les projets (global)         rtk init --global    ║"
        echo "║  [0] Passer (configurer plus tard)                          ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        read -r -p "Choix [1-4, défaut: 4] : " _rtk_editor
        case "${_rtk_editor:-4}" in
            1|2) rtk init 2>/dev/null       && echo "✅ RTK hook activé (projet courant)" || true ;;
            3|4) rtk init --global 2>/dev/null && echo "✅ RTK hook global activé" || true ;;
            0)   echo "→ RTK installé, configurez avec : rtk init --global" ;;
        esac
    fi
else
    ## Mode standard — one-liner officiel
    if ! command -v rtk >/dev/null 2>&1; then
        echo "⏳ Installation RTK via curl..."
        curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh \
            && echo "✅ RTK installé" \
            || echo "⚠️  RTK install échoué (curl requis)"
        ## Hook global silencieux (pas d'éditeur à choisir en mode standard)
        command -v rtk >/dev/null 2>&1 && rtk init --global 2>/dev/null || true
    else
        echo "ℹ️  RTK déjà présent : $(rtk --version 2>/dev/null || echo 'version inconnue')"
    fi
fi

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

## _CPU/_RAM/_VRAM/_SCORE/_TIER/_MVAL/_PAF_DEFAULT déjà calculés en tête d'install

## Helper : lance le compose unifié avec le bon profil (+ overlay GPU si NVIDIA)
_dc_up() {
    local _profile="${1:-}"
    local _compose="$HOME/.zen/Astroport.ONE/docker/docker-compose.yml"
    local _gpu_overlay="$HOME/.zen/Astroport.ONE/docker/docker-compose.gpu.yml"
    local _cmd="sg docker -c 'docker compose -f \"$_compose\""
    [[ -n "$_profile" ]] && _cmd+=" --profile $_profile"
    [[ "${_GPU_VENDOR:-none}" == "nvidia" ]] && _cmd+=" -f \"$_gpu_overlay\""
    _cmd+=" up -d'"
    eval "$_cmd"
}

###############################################################
echo "## INSTALLATIONS CONDITIONNELLES SELON PROFIL ###########"
###############################################################
NEXTCLOUD_ACTIVE=false
AISTACK_ACTIVE=false
RNOSTR_ACTIVE=false

case "${INSTALL_PROFILE}" in
    nextcloud)
        bash "$HOME/.zen/Astroport.ONE/install/install_nextcloud.sh"
        ;;
    ai-company)
        echo "🧠 PROFIL ai-company — démarrage installation Stack IA..."
        ## Prometheus serveur complet : collecte les métriques heartbox + node_exporter
        ## Utile pour les Brain-Nodes (GPU) qui veulent monitorer leur charge IA
        echo "⏳ Installation Prometheus + exporters heartbox..."
        ~/.zen/Astroport.ONE/install/install_prometheus.sh \
            && echo "✅ Prometheus heartbox monitoring actif (:9090)" \
            || echo "⚠️  Prometheus — erreur (non bloquant)"
        
        AI_SVC_ARGS=""
        if [[ -n "${INSTALL_AI_SERVICES:-}" ]]; then
            AI_SVC_ARGS="${INSTALL_AI_SERVICES}"
        fi
        
        ~/.zen/Astroport.ONE/install/install-ai-company.docker.sh $AI_SVC_ARGS \
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
        ## strfry doit être arrêté avant rnostr (port 7777 partagé via NPM)
        echo "⏹️  Arrêt et désactivation de strfry..."
        sudo systemctl stop strfry 2>/dev/null || true
        sudo systemctl disable strfry 2>/dev/null || true
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
## _VRAM/_GPU_VENDOR déjà calculés en tête de section — on ne re-détecte pas
_SCORE=$(( _VRAM * 4 + _CPU * 2 + _RAM / 2 ))

if   [[ $_SCORE -gt 40 ]]; then _TIER="🔥 Brain-Node (GPU)"; _RANK="DRAGON COMPUTE"; _MVAL=$(( _SCORE * 12 )); _PAF_DEFAULT=28
elif [[ $_SCORE -gt 10 ]]; then _TIER="⚡ Standard";         _RANK="DRAGON ORIGIN";  _MVAL=$(( _SCORE * 6  )); _PAF_DEFAULT=14
else                             _TIER="🌿 Léger";            _RANK="Nœud Léger";     _MVAL=100;               _PAF_DEFAULT=7
fi

## ── Benchmark disque (une seule fois à l'install) ───────────────────────────
_DISK_CACHE="$HOME/.zen/game/disk_bench.cache"
mkdir -p "$HOME/.zen/game"
if [[ ! -s "$_DISK_CACHE" ]]; then
    echo "⏱️  Benchmark disque (256 Mo écriture + lecture)..."
    _tmp_bench="/tmp/astro_dd_$$"
    _disk_write=0; _disk_read=0
    _out=$(LANG=C dd if=/dev/zero of="$_tmp_bench" bs=1M count=256 conv=fdatasync 2>&1)
    _disk_write=$(echo "$_out" | grep -oE '[0-9.]+ MB/s' | tail -1 | grep -oE '^[0-9]+')
    _out=$(LANG=C dd if="$_tmp_bench" of=/dev/null bs=1M 2>&1)
    _disk_read=$(echo "$_out"  | grep -oE '[0-9.]+ MB/s' | tail -1 | grep -oE '^[0-9]+')
    rm -f "$_tmp_bench"
    echo "${_disk_write:-0} ${_disk_read:-0}" > "$_DISK_CACHE"
fi
read _disk_write _disk_read < "$_DISK_CACHE" 2>/dev/null
_disk_write="${_disk_write:-0}"; _disk_read="${_disk_read:-0}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  🏆 SCORE CARD — Rang dans la constellation                  ║"
echo "╠══════════════════════════════════════════════════════════════╣"
printf "║  %-58s ║\n" "CPU : ${_CPU} cœurs  RAM : ${_RAM} Go  VRAM : ${_VRAM} Go"
printf "║  %-58s ║\n" "GPU : ${_GPU_NAME:-aucun}  (${_GPU_VENDOR})"
printf "║  %-58s ║\n" "Disque écriture : ${_disk_write} Mo/s  lecture : ${_disk_read} Mo/s"
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
sg docker -c "docker ps --format '    {{.Names}}: {{.Status}}'" 2>/dev/null | head -30 || echo "    (aucun conteneur actif)"
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
echo "    rnostr     ws://localhost:8888  (relay NOSTR Rust — dev)"
fi
echo
echo "  DOCKER :"
echo "    docker ps"
echo "    docker compose -f ~/.zen/Astroport.ONE/docker/docker-compose.yml ps"
echo "    docker compose -f ~/.zen/Astroport.ONE/docker/docker-compose.yml logs -f"
echo
echo "  ESSAIM :"
echo "    IPFS       ${IPFS_DISPLAY}"
echo "    Relay      ${RELAY_DISPLAY}"
echo "    UPassport  ${USPOT_DISPLAY}"
echo
echo "  COMMANDES :"
echo "    astrosystemctl list          ← score local vs swarm"
echo "    astrosystemctl list-remote   ← Brain-Nodes disponibles"
echo "    station-info                 ← état station (terminal)"
echo "    station                      ~/.zen/Astroport.ONE/station.sh"
echo "    captain                      ~/.zen/Astroport.ONE/captain.sh"
echo "    start / stop                 ~/.zen/Astroport.ONE/start.sh | stop.sh"
if [[ "${AISTACK_ACTIVE}" == "true" ]]; then
echo ""
echo "  STACK IA :"
echo "    docker compose -f ~/.zen/Astroport.ONE/docker/docker-compose.yml --profile ai ps"
echo "    install/install-ai-company.docker.sh --check   ← compatibilité GPU"
fi
echo
echo "  EXTENSIONS NAVIGATEUR :"
echo "    Pour archiver YouTube directement dans votre uDRIVE :"
echo "    1. Installez l'extension 'Open With' sur Firefox :"
echo "       https://addons.mozilla.org/firefox/addon/open-with"
echo "    2. Importez la configuration dans l'extension :"
echo "       bash ~/.zen/open_with_yt-dlp.txt"
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
# Bootstrap WoTx2 — Compétences Capitaine Astroport
# Propose au capitaine de déclarer ses compétences techniques initiales
[[ -f ~/.zen/Astroport.ONE/tools/oracle_init_captain_wotx2.sh ]] && \
    ~/.zen/Astroport.ONE/tools/oracle_init_captain_wotx2.sh
##########################################################
~/.zen/Astroport.ONE/RUNTIME/DRAGON_p2p_ssh.sh ON

else

echo "============================================="
echo " MISES À JOUR (APT/PIP) EFFECTUÉES AVEC SUCCÈS"
echo "============================================="
echo " INSTALLATION COMPLÈTE IGNORÉE :"
echo " PLAYER already onboard..."
echo "============================================="
# cat ~/.zen/game/players/.current/secret.june
echo "============================================="
# MAIN #

fi
}