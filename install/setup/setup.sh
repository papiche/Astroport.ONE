#!/bin/bash
###################################################################### setup.sh
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

echo "#############################################"
echo "######### HOSTNAME SETUP  ###################"
echo "#############################################"
# Générer un mot aléatoire avec diceware.sh
WORD=$($HOME/.zen/Astroport.ONE/tools/diceware.sh 1)
# Générer un nombre aléatoire entre 01 et 99
NUMBER=$(printf "%02d" $((RANDOM % 99 + 1)))
# Construire le nouveau hostname
NEW_HOSTNAME="${WORD}-${NUMBER}"
# Mettre à jour le fichier /etc/hostname
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname > /dev/null
# Mettre à jour le fichier /etc/hosts
sudo sed -i "/127.0.1.1/c\127.0.1.1\t$NEW_HOSTNAME" /etc/hosts
# Changer le hostname avec hostnamectl
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
# Forcer la mise à jour du hostname actuel
sudo hostname -F /etc/hostname
# Afficher le nouveau hostname
echo "NOUVEAU Hostname :"
hostname

echo "#############################################"
echo "######### IPFS SETUP  #########################"
echo "#############################################"

echo "=== SETUP IPFS"
~/.zen/Astroport.ONE/install/setup/ipfs_setup.sh
echo "/ip4/127.0.0.1/tcp/5001" > ~/.ipfs/api

#####################
#### ~/.bashrc
echo "########################### Updating ♥BOX ~/.bashrc"
while IFS= read -r line
do
    echo "$line" >> ~/.bashrc
done < ~/.zen/Astroport.ONE/ASCI_ASTROPORT.txt

## EXTEND PATH
echo '#############################################################
export PATH=$HOME/.local/bin:/usr/games:$PATH

## Activer le venv Python si disponible (créé par install.sh avec python3)
[[ -s "$HOME/.astro/bin/activate" ]] && . "$HOME/.astro/bin/activate" \
    || { echo "⚠️  ~/.astro/bin/activate absent — venv non créé"; }
source $HOME/.zen/Astroport.ONE/tools/my.sh 2>/dev/null

## Affichage des clefs de la cooperative
echo ""
echo "UPLANETNAME_G1=$UPLANETNAME_G1"
echo ""
echo "UPLANETG1PUB=$UPLANETG1PUB"
echo "UPLANETNAME_SOCIETY=$UPLANETNAME_SOCIETY"
echo ""
echo "UPLANETNAME_CAPITAL=$UPLANETNAME_CAPITAL"
echo "UPLANETNAME_IMPOT=$UPLANETNAME_IMPOT"
echo ""
echo "UPLANETNAME_TREASURY=$UPLANETNAME_TREASURY"
echo "UPLANETNAME_RND=$UPLANETNAME_RND"
echo "UPLANETNAME_ASSETS=$UPLANETNAME_ASSETS"
echo ""
echo "UPLANETNAME_CAPTAIN=$UPLANETNAME_CAPTAIN"
echo "UPLANETNAME_NODE=$UPLANETNAME_NODE"
echo ""
echo ""
echo "IPFSNODEID=$IPFSNODEID"
cowsay $(hostname) on UPLANET ${UPLANETG1PUB:0:8}
echo "CAPTAIN: $CAPTAINEMAIL"' >> ~/.bashrc

source ~/.bashrc

echo "<<< UPDATED>>> PATH=$PATH"


echo "#############################################"
echo ">>>>>>>>>>> RUNTIME SETUP  "
echo "#############################################"
## XBIAN fail2ban ERROR correction ##
[[ "$USER" == "xbian" ]] && sudo sed -i "s/auth.log/faillog/g" /etc/fail2ban/paths-common.conf

mkdir -p ~/.zen/tmp
echo "################# FAIL2BAN _12345.sh -> JAIL unrecognized nodes"
echo "SETUP /etc/fail2ban/filter.d/astroport-intruder.conf"
echo '[Definition]
failregex = REJECTED: .* \(IP: <HOST>\) - Reason: No Astroport Metadata
ignoreregex =' > ~/.zen/tmp/fail2ban.rule 
sudo mv ~/.zen/tmp/fail2ban.rule /etc/fail2ban/filter.d/astroport-intruder.conf

echo "SETUP /etc/fail2ban/jail.d/astroport.conf"
echo '[astroport-intruder]
enabled = true
port = 4001,12345
filter = astroport-intruder
logpath = /home/*/.zen/tmp/swarm_intruders.log
maxretry = 3
bantime = 86400' > ~/.zen/tmp/fail2ban.jail
sudo mv ~/.zen/tmp/fail2ban.jail /etc/fail2ban/jail.d/astroport.conf

echo "#############################################"

########################################################################
# NETWORK CONFIGURATION (instance-specific)
########################################################################
sudo systemctl daemon-reload
sudo systemctl enable astroport
sudo systemctl restart astroport

ACTUAL=$(cat /etc/resolv.conf | grep -w nameserver | head -n 1)

if [[ $(echo $ACTUAL | grep "1.1.1.1") == "" ]] ; then
########################################################################
echo "ADDING nameserver 1.1.1.1 TO /etc/resolv.conf TO BYPASS COUNTRY RESTRICTIONS"
########################################################################
    sudo chattr -i /etc/resolv.conf

    sudo cat > /tmp/resolv.conf <<EOF
domain home
search home
nameserver 1.1.1.1
$ACTUAL
# ASTROPORT.ONE
EOF

    sudo cp /etc/resolv.conf /etc/resolv.conf.backup

    sudo mv /tmp/resolv.conf /etc/resolv.conf
    sudo chattr +i /etc/resolv.conf
fi
if [[ ! $(cat /etc/hosts | grep -w "astroport.local" | head -n 1) ]]; then
    cat /etc/hosts > /tmp/hosts
    echo "127.0.1.1    $(hostname) $(hostname).local astroport.$(hostname).local ipfs.$(hostname).local astroport.local duniter.localhost" >> /tmp/hosts
    sudo cp /tmp/hosts /etc/hosts && rm /tmp/hosts
fi

# NIP-101 strfry setup
if [[ -d ~/.zen/strfry && -d ~/.zen/workspace/NIP-101 ]]; then
    ~/.zen/workspace/NIP-101/setup.sh
    ~/.zen/workspace/NIP-101/systemd.setup.sh
fi

echo "#####################################################"
echo "#### UPLANET ORIGIN ############# ♥BOX X LEVEL ###"
echo "#### UPlanet ẐEN Activation needs Y LEVEL (SSH=IPFS)"
~/.zen/Astroport.ONE/tools/Ylevel.sh

# ACTIVATING ASTROPORT CRON
echo ">>> SWITCHING ASTROPORT ON <<<"
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON

##########################################################
## ON BOARDING PLAYER
source ${HOME}/.zen/Astroport.ONE/tools/my.sh

GO=$(my_LatLon) ## fr 43.60 1.45 # (lang lat lon) with 0.01° precision
## Force lowercase sur le code langue (my_LatLon peut retourner "FR" en majuscule)
## → cohérence des chemins : game/nostr/support+hostname_fr_... (jamais FR)
GO="$(echo $GO | awk '{print tolower($1), $2, $3}')"
echo ">>> GPS + Langue : $GO"
HOSTNAME_SHORT=$(hostname -s)

# =========================================================================
# 1. CONFIGURATION DU DOMAINE DE LA STATION (Armateur) -> SETUP_DOMAIN
# =========================================================================
CLEAN_NODE_DOMAIN="${CUSTOM_NODE_DOMAIN:-}"
if [[ -n "${CLEAN_NODE_DOMAIN}" && "${CLEAN_NODE_DOMAIN}" == "${HOSTNAME_SHORT}."* ]]; then
    CLEAN_NODE_DOMAIN="${CLEAN_NODE_DOMAIN#*.}"
fi

if [[ -n "${CLEAN_NODE_DOMAIN}" ]]; then
    SETUP_DOMAIN="${HOSTNAME_SHORT}.${CLEAN_NODE_DOMAIN}"
    echo ">>> Domaine Noeud configuré sur : ${SETUP_DOMAIN}"
else
    SETUP_DOMAIN=$(domainname 2>/dev/null)
    [[ "$SETUP_DOMAIN" == "(none)" || -z "$SETUP_DOMAIN" ]] && SETUP_DOMAIN=$(hostname -d 2>/dev/null)
    [[ -z "$SETUP_DOMAIN" || "$SETUP_DOMAIN" == "(none)" || "$SETUP_DOMAIN" == "localhost" ]] && SETUP_DOMAIN="${HOSTNAME_SHORT}.copylaradio.com"
    echo ">>> Domaine Noeud automatique : ${SETUP_DOMAIN}"
fi

# =========================================================================
# 2. CONFIGURATION DE L'EMAIL CAPITAINE -> GMARKMAIL
# =========================================================================
if [[ -n "${CUSTOM_CAPTAIN_EMAIL:-}" ]]; then
    GMARKMAIL="${CUSTOM_CAPTAIN_EMAIL}"
    echo ">>> Utilisation de l'email Capitaine personnalisé : ${GMARKMAIL}"
else
    BASE_EMAIL_DOMAIN="${CUSTOM_EMAIL_DOMAIN:-${CLEAN_NODE_DOMAIN:-qo-op.com}}"
    GMARKMAIL="support+$(echo ${HOSTNAME_SHORT} $GO | sed "s| |_|g")@${BASE_EMAIL_DOMAIN}"
    GMARKMAIL="${GMARKMAIL,,}"  ## Force minuscule — cohérence avec make_NOSTRCARD.sh
    echo ">>> Génération de l'email Capitaine automatique : ${GMARKMAIL}"
fi

# =========================================================================
# 3. SAUVEGARDE DE L'IP PUBLIQUE (seulement si nœud directement sur le WAN)
# =========================================================================
# Détection de l'IP LAN (interface de sortie par défaut)
_DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
LAN_IP=$(ip -4 addr show dev "$_DEFAULT_IFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)

PUBLIC_IP=""
PUBLIC_IP=$(${HOME}/.zen/Astroport.ONE/me.♥Box.sh 2>/dev/null | tail -n 1) \
    || PUBLIC_IP=$(curl -s --connect-timeout 5 https://ifconfig.me 2>/dev/null) \
    || PUBLIC_IP=$(curl -s --connect-timeout 5 https://icanhazip.com 2>/dev/null) \
    || PUBLIC_IP=$(curl -s --connect-timeout 5 ipecho.net/plain 2>/dev/null)

# Vérifier si l'IP LAN est une adresse RFC1918 privée (NAT détecté)
_IS_PRIVATE_LAN=false
if [[ "$LAN_IP" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.) ]]; then
    _IS_PRIVATE_LAN=true
fi

if [[ -n "$PUBLIC_IP" && "$_IS_PRIVATE_LAN" == "false" ]]; then
    # LAN = WAN : le nœud est directement exposé sur internet (pas de NAT)
    # ♥Box est renseigné → my.sh construira les URLs avec l'IP directe
    echo "$PUBLIC_IP" > $HOME/.zen/♥Box
    echo ">>> Nœud directement sur le WAN (LAN=$LAN_IP = WAN=$PUBLIC_IP)"
    echo ">>> IP stockée dans ~/.zen/♥Box: $PUBLIC_IP"
elif [[ -n "$PUBLIC_IP" && "$_IS_PRIVATE_LAN" == "true" ]]; then
    # NAT détecté : LAN (privé) ≠ WAN — ♥Box non peuplé
    # my.sh utilisera les URL basées sur le domaine DNS (HTTPS via NPM)
    echo ">>> Nœud derrière NAT (LAN=$LAN_IP ≠ WAN=$PUBLIC_IP)"
    echo ">>> ♥Box non renseigné — URLs via domaine DNS (HTTPS proxy)"
    echo "    Configurez le port-forwarding sur votre routeur si accès IP direct requis."
    [[ -f $HOME/.zen/♥Box ]] && rm -f $HOME/.zen/♥Box || true
else
    echo ">>> WARNING: Could not detect public IP"
fi

# =========================================================================
# 4. GÉNÉRATION DU FICHIER .env
# =========================================================================
cat > "${ENVFILE}" <<DOTENV
#########################################
# ASTROPORT box - Auto-generated by setup.sh
# Domain: ${SETUP_DOMAIN}
# Date: $(date -Is)
# Public IP: ${PUBLIC_IP:-unknown}
# Customize and restart: sudo systemctl restart astroport
#########################################
myASTROPORT=https://astroport.${SETUP_DOMAIN} # TCP:12345
myIPFS=https://ipfs.${SETUP_DOMAIN} # TCP:8080 UDP:4001 /12345:12345
myRELAY=wss://relay.${SETUP_DOMAIN} # TCP/WS:7777
uSPOT=https://u.${SETUP_DOMAIN} # TCP:54321

###################################
## COPYLARADIO UPLANET ZEN ECONOMY
###################################
MACHINE_VALUE_ZEN=500
PAF=14
NCARD=1
ZCARD=4
LOG_LEVEL=INFO
ENABLE_AUDIO_NOTIFICATIONS=yes
DOTENV

echo ">>> .env created for domain: ${SETUP_DOMAIN}"
echo ">>> ${ENVFILE}"
## Re-source my.sh to pick up new .env values
source ${HOME}/.zen/Astroport.ONE/tools/my.sh

##########################################################
## NGINX PROXY MANAGER: deploy + auto-configure SSL proxies
##########################################################
echo "######### NGINX PROXY MANAGER #############"
~/.zen/Astroport.ONE/install/setup/setup_npm.sh

##########################################################
## CAPTAIN ON BOARDING (only if no captain exists yet)
##########################################################
if [[ ! -d ~/.zen/game/players/.current ]]; then
    echo "##### CAPTAIN ################## ON BOARDING ${GMARKMAIL}"
    espeak "Welcome CAPTAIN" 2>/dev/null
    echo "#####################################################"
    ################ COMPTE CAPTAINE AUTOMATIQUE
    ## MULTIPASS --->
    echo ">>> Create CAPTAIN MULTIPASS <<<"
    # Bootstrap : exporter CAPTAINEMAIL dès maintenant pour que my.sh trouver l'email
    # lors de son rechargement dans make_NOSTRCARD.sh et VISA.new.sh (évite "Captain EMAIL is empty")
    export CAPTAINEMAIL="${GMARKMAIL}"
    ~/.zen/Astroport.ONE/tools/make_NOSTRCARD.sh "${GMARKMAIL}" $GO

    ## ZEN CARD --->
    echo ">>> Create CAPTAIN ZENCARD <<<"

    ## Attendre que le daemon IPFS soit prêt (VISA.new.sh line 12 : ! ipfs swarm peers && exit 1)
    ## repo.lock peut bloquer ipfs swarm peers si un autre processus IPFS est en cours
    _ipfs_ready=false
    for _i in $(seq 1 30); do
        if ipfs swarm peers >/dev/null 2>&1; then
            _ipfs_ready=true; break
        fi
        sleep 1; echo -n "."
    done
    echo ""
    [[ "$_ipfs_ready" == "true" ]] \
        && echo "✅ IPFS daemon prêt pour VISA.new.sh" \
        || echo "⚠️  IPFS swarm peers toujours indisponible après 30s — VISA.new.sh peut échouer"

    ZSALT=$(${HOME}/.zen/Astroport.ONE/tools/diceware.sh $(( $(${HOME}/.zen/Astroport.ONE/tools/getcoins_from_gratitude_box.sh) + 3 )))
    ZPEPS=$(${HOME}/.zen/Astroport.ONE/tools/diceware.sh $(( $(${HOME}/.zen/Astroport.ONE/tools/getcoins_from_gratitude_box.sh) + 3 )))

    # Récupérer CAPTAING1PUB depuis le MULTIPASS fraîchement créé (pour chiffrement SSSS middle share)
    export CAPTAING1PUB=$(cat ~/.zen/game/nostr/${GMARKMAIL}/G1PUBNOSTR 2>/dev/null)

    source ~/.zen/game/nostr/${GMARKMAIL}/.secret.nostr ## get NPUB & HEX
    ~/.zen/Astroport.ONE/RUNTIME/VISA.new.sh "$ZSALT" "$ZPEPS" "${GMARKMAIL}" "UPlanet" ${GO} "$NPUB" "$HEX"
else
    echo ">>> Captain already onboard: $(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
fi

echo "#############################################"
echo "📡 SYNCHRONISATION AVEC L'ESSAIM"
echo "#############################################"
chmod +x ~/.zen/Astroport.ONE/bootstrap_constellation.sh
bash ~/.zen/Astroport.ONE/bootstrap_constellation.sh

##########################################################
## ONBOARDING SUMMARY — UX GUIDE FOR NEW ARMATEUR
##########################################################
_NC='\033[0m'; _GRN='\033[0;32m'; _YLW='\033[1;33m'; _CYN='\033[0;36m'; _BLU='\033[0;34m'; _RED='\033[0;31m'

echo ""
echo -e "${_CYN}╔══════════════════════════════════════════════════════════════════════╗${_NC}"
echo -e "${_CYN}║        🌍  ASTROPORT.ONE — INSTALLATION TERMINÉE                   ║${_NC}"
echo -e "${_CYN}╚══════════════════════════════════════════════════════════════════════╝${_NC}"
echo ""
echo -e "${_GRN}✅ Votre station est reliée à la constellation ${_YLW}UPlanet ORIGIN${_NC}"
echo -e "${_BLU}   Hostname  :${_NC} ${_CYN}$(hostname)${_NC}"
echo -e "${_BLU}   IPFS Node :${_NC} ${_CYN}${IPFSNODEID:0:16}...${_NC}"
echo -e "${_BLU}   UPlanet   :${_NC} ${_CYN}${UPLANETG1PUB:0:8}... (ORIGIN)${_NC}"
echo ""
echo -e "${_YLW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_NC}"
echo -e "${_YLW}👤  COMPTE CAPITAINE TEMPORAIRE (auto-généré)${_NC}"
echo -e "${_YLW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_NC}"
echo ""
echo -e "   ${_BLU}Email temporaire :${_NC} ${_CYN}${GMARKMAIL}${_NC}"
echo ""
echo -e "   Ce compte identifie votre station sur la carte UPlanet ORIGIN."
echo -e "   ${_RED}⚠️  Contactez support@qo-op.com.${_NC} Créez votre propre compte :"
echo ""
echo -e "${_CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_NC}"
echo -e "${_GRN}🚀  ÉTAPE 1 — Créez votre MULTIPASS / ZEN Card personnelle${_NC}"
echo -e "${_CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_NC}"
echo ""
echo -e "   Visitez votre portail local pour créer votre identité souveraine :"
echo -e "   ${_CYN}${uSPOT/g1:-http://127.0.0.1:54321/g1}${_NC}"
echo ""
echo -e "   Inscrivez-vous sur Open Collective :"
echo -e "   ${_CYN}https://opencollective.com/monnaie-libre${_NC}"
echo ""
echo -e "${_CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_NC}"
echo -e "${_GRN}🏛️  ÉTAPE 2 — Candidature Armateur (rejoindre UPlanet ẐEN)${_NC}"
echo -e "${_CYN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_NC}"
echo ""
echo -e "   Pour transférer la gestion de votre machine au collectif G1FabLab"
echo -e "   et être remboursé de vos frais et prestations :"
echo ""
echo -e "   ${_GRN}👉  Soumettez une demande de subvention :${_NC}"
echo -e "   ${_CYN}https://opencollective.com/monnaie-libre/grants/new${_NC}"
echo ""
echo -e "   ${_BLU}Titre suggéré :${_NC} \"Armateur Nœud UPlanet — $(hostname) — ${GO}\""
echo -e "   ${_BLU}Description   :${_NC} Mise à disposition infrastructure + maintenance station Astroport.ONE"
echo -e "   ${_BLU}IPFS Node ID  :${_NC} ${IPFSNODEID:0:32}..."
echo ""
echo -e "   ${_YLW}ℹ️  Le collectif évalue chaque candidature.${_NC}"
echo -e "   Si retenue, vous pourrez facturer frais et prestations via :"
echo -e "   ${_CYN}https://opencollective.com/monnaie-libre/expenses/new${_NC}"
echo ""
echo -e "${_CYN}╔══════════════════════════════════════════════════════════════════════╗${_NC}"
echo -e "${_CYN}║  Rôles du collectif G1FabLab (AMAP Numérique) :                     ║${_NC}"
echo -e "${_CYN}║  • Armateur  — héberge la machine, reçoit une indemnité d'héberg.  ║${_NC}"
echo -e "${_CYN}║  • Capitaine — opère la station, perçoit une rétribution (2×PAF)   ║${_NC}"
echo -e "${_CYN}║  • MULTIPASS — usager des services (1 Ẑen/semaine)                 ║${_NC}"
echo -e "${_CYN}║  • ZEN Card  — contributeur infrastructure (4 Ẑen/semaine)         ║${_NC}"
echo -e "${_CYN}╚══════════════════════════════════════════════════════════════════════╝${_NC}"
echo ""
espeak "Setup complete. Welcome to UPlanet ORIGIN." 2>/dev/null || true

