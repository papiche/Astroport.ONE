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

## Activate python env
. $HOME/.astro/bin/activate
. $HOME/.zen/Astroport.ONE/tools/my.sh

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
echo ">>> SWITCHING ASTROPORT ON <<<
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON"
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON

##########################################################
## ON BOARDING PLAYER
echo "MJ activation"
ipfs --timeout 30s cat /ipfs/QmVy7FKd1MGZqee4b7B5jmBKNgTJBvKKkoDhodnJWy23oN > ~/.zen/MJ_APIKEY
source ${HOME}/.zen/Astroport.ONE/tools/my.sh
GO=$(my_LatLon) ## FR 34.46 1.51 # (country lat lon) with 0.01° precision
GMARKMAIL="support+$(echo $(hostname) $GO | sed "s| |-|g")@qo-op.com" # ex: support+nexus-55-FR-34.46-1.51@qo-op.com

##########################################################
## AUTO-GENERATE .env FROM HOSTNAME (if not already present)
##########################################################
ENVFILE="${HOME}/.zen/Astroport.ONE/.env"
if [[ ! -s "${ENVFILE}" ]]; then
    echo "#############################################"
    echo "######### AUTO-GENERATING .env  #############"
    echo "#############################################"
    ## Detect domain: domainname > hostname -d > copylaradio.com
    SETUP_DOMAIN=$(domainname 2>/dev/null)
    [[ "$SETUP_DOMAIN" == "(none)" || -z "$SETUP_DOMAIN" ]] && SETUP_DOMAIN=$(hostname -d 2>/dev/null)
    [[ -z "$SETUP_DOMAIN" || "$SETUP_DOMAIN" == "(none)" || "$SETUP_DOMAIN" == "localhost" ]] && SETUP_DOMAIN="copylaradio.com"

    cat > "${ENVFILE}" <<DOTENV
#########################################
# ASTROPORT box - Auto-generated by setup.sh
# Domain: ${SETUP_DOMAIN}
# Date: $(date -Is)
# Customize and restart: sudo systemctl restart astroport
#########################################
myASTROPORT=https://astroport.${SETUP_DOMAIN}
myIPFS=https://ipfs.${SETUP_DOMAIN}
myRELAY=wss://relay.${SETUP_DOMAIN}
uSPOT=https://u.${SETUP_DOMAIN}

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
else
    echo ">>> .env already exists: ${ENVFILE}"
fi

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
    ~/.zen/Astroport.ONE/tools/make_NOSTRCARD.sh "${GMARKMAIL}" $GO

    ## ZEN CARD --->
    echo ">>> Create CAPTAIN ZENCARD <<<"
    ZSALT=$(${HOME}/.zen/Astroport.ONE/tools/diceware.sh $(( $(${HOME}/.zen/Astroport.ONE/tools/getcoins_from_gratitude_box.sh) + 3 )))
    ZPEPS=$(${HOME}/.zen/Astroport.ONE/tools/diceware.sh $(( $(${HOME}/.zen/Astroport.ONE/tools/getcoins_from_gratitude_box.sh) + 3 )))

    source ~/.zen/game/nostr/${GMARKMAIL}/.secret.nostr ## get NPUB & HEX
    ~/.zen/Astroport.ONE/RUNTIME/VISA.new.sh "$ZSALT" "$ZPEPS" "${GMARKMAIL}" "UPlanet" ${GO} "$NPUB" "$HEX"
else
    echo ">>> Captain already onboard: $(cat ~/.zen/game/players/.current/.player 2>/dev/null)"
fi

