#!/bin/bash
###################################################################### setup.sh
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

### ADD USER TO ADM & DOCKER GROUP
sudo usermod -aG adm $USER
sudo usermod -aG docker $USER
echo

echo "#############################################"
echo "######### HOSTNAME SETUP  ###################"
echo "#############################################"
# Générer un mot aléatoire avec diceware.sh
WORD=$($HOME/.zen/Astroport.ONE/tools/diceware.sh 1)
# Générer un nombre aléatoire entre 01 et 99
NUMBER=$(printf "%02d" $((RANDOM % 99 + 1)))
# Construire le nouveau hostname
NEW_HOSTNAME="${WORD}-${NUMBER}"
# Afficher le nouveau hostname
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
# Mettre à jour le fichier /etc/hosts
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
echo "NOUVEAU Hostname :"
hostname

echo "#############################################"
echo "######### IPFS SETUP  #########################"
echo "#############################################"

echo "=== SETUP IPFS"
~/.zen/Astroport.ONE/ipfs_setup.sh
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
echo ">>>>>>>>>>> SYSTEM SETUP  "
echo "#############################################"
#### SETUP JAKLIS ###############################################################
echo "=== SETUP jaklis"
cd ~/.zen/Astroport.ONE/tools/jaklis
./setup.sh

## XBIAN fail2ban ERROR correction ##
#[....] Starting authentication failure monitor: fail2ban No file(s) found for glob /var/log/auth.log
[[ "$USER" == "xbian" ]] && sudo sed -i "s/auth.log/faillog/g" /etc/fail2ban/paths-common.conf

# PERSONNAL DEFCON LEVEL
# cp ~/.zen/Astroport.ONE/DEFCON ~/.zen/
mkdir -p ~/.zen/tmp

########################################################################
# open_with_linux.py install
#######################################################################
echo "#############################################"
## https://darktrojan.github.io/openwith/webextension.html"
~/.zen/Astroport.ONE/open_with_linux.py install
cat ~/.zen/Astroport.ONE/open_with_yt-dlp.txt | sed "s|_HOME_|$HOME|g" > ~/.zen/open_with_yt-dlp.txt
echo "#############################################
# INSTALLEZ L'EXTENSTION FIREFOX
# https://addons.mozilla.org/firefox/addon/open-with
#############################################
recopier le contenu de xed ~/.zen/open_with_yt-dlp.txt
#############################################"

########################################################################
# SUDO permissions
########################################################################
## Full sudo for captain (NOPASSWD:ALL)
echo "$USER ALL=(ALL) NOPASSWD:ALL" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/captain')
########################################################################
## Explicit NOPASSWD for services used by Astroport (ramdisk, systemctl, powerjoular, etc.)
for bin in fail2ban-client mount umount apt-get apt systemctl ufw docker hdparm powerjoular kill; do
  binpath=$(which $bin 2>/dev/null)
  if [[ -n "$binpath" ]] && [[ -x "$binpath" ]]; then
    echo "$USER ALL=(ALL) NOPASSWD:$binpath" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/'"$bin") \
      && echo "SUDOERS RIGHT SET FOR : $binpath" \
      || echo "ERROR setting sudoers for $bin"
  else
    echo "SKIP (not found or not executable): $bin"
  fi
done

echo "#############################################"
echo "# ADDING <<<Astroport & REC >>>  DESKTOP SHORTCUT"
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/astroport.desktop > ~/Bureau/astroport.desktop && chmod +x ~/Bureau/astroport.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/astroport.desktop > ~/Desktop/astroport.desktop && chmod +x ~/Desktop/astroport.desktop
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/rec.desktop > ~/Bureau/rec.desktop && chmod +x ~/Bureau/rec.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/rec.desktop > ~/Desktop/rec.desktop && chmod +x ~/Desktop/rec.desktop
#~ [[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/g1billet.desktop > ~/Bureau/g1billet.desktop && chmod +x ~/Bureau/g1billet.desktop
#~ [[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/g1billet.desktop > ~/Desktop/g1billet.desktop && chmod +x ~/Desktop/g1billet.desktop

######### SUPER PRATIQUE :: DOES NOT WORK WITH SPACE IN FILENAME
echo "# ADD NEMO 'Add To IPFS' ACTION"
~/.zen/Astroport.ONE/tools/install.nemo.add2ipfs.sh

echo "CREATE SYSTEMD astroport SERVICE >>>>>>>>>>>>>>>>>>"
cat > /tmp/astroport.service <<EOF
[Unit]
Description=ASTROPORT API
After=network.target
Requires=network.target

[Service]
Type=idle
User=_USER_
RestartSec=1
Restart=always
ExecStart=/home/_USER_/.zen/Astroport.ONE/12345.sh
StandardOutput=file:/home/_USER_/.zen/tmp/12345.log

[Install]
WantedBy=multi-user.target
EOF

sudo cp -f /tmp/astroport.service /etc/systemd/system/
sudo sed -i "s/_USER_/$USER/g" /etc/systemd/system/astroport.service

sudo systemctl daemon-reload
sudo systemctl enable astroport
sudo systemctl restart astroport

ACTUAL=$(cat /etc/resolv.conf | grep -w nameserver | head -n 1)

if [[ $(echo $ACTUAL | grep "1.1.1.1") == "" ]] ; then
########################################################################
echo "ADDING nameserver 1.1.1.1 TO /etc/resolv.conf TO BYPASS COUNTRY RESTRICTIONS" # Avoid provider restrictions
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

echo "... Optimizing security into /etc/ssh/sshd_config"
# Sauvegarde du fichier original
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# Securisation SSH
sudo sed -i 's/^.*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^.*PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/^.*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^.*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^.*X11Forwarding .*/X11Forwarding yes/' /etc/ssh/sshd_config
sudo sed -i 's/^.*ClientAliveInterval .*/ClientAliveInterval 60/' /etc/ssh/sshd_config
sudo sed -i 's/^.*ClientAliveCountMax .*/ClientAliveCountMax 3/' /etc/ssh/sshd_config

# Astroport Basic Tools Linking
ln -f -s ~/.zen/Astroport.ONE/tools/natools.py ~/.local/bin/natools
ln -f -s ~/.zen/Astroport.ONE/tools/jaklis/jaklis.py ~/.local/bin/jaklis
ln -f -s ~/.zen/Astroport.ONE/tools/keygen ~/.local/bin/keygen
ln -f -s ~/.zen/Astroport.ONE/command.sh ~/.local/bin/coeurbox

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
echo ">>> SWITHCIN ASTROPORT ON <<<
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON"
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON

##########################################################
## ON BOARDING PLAYER
ipfs --timeout 30s cat /ipfs/QmVy7FKd1MGZqee4b7B5jmBKNgTJBvKKkoDhodnJWy23oN > ~/.zen/MJ_APIKEY
source ${HOME}/.zen/Astroport.ONE/tools/my.sh
GO=$(my_LatLon) ## FR 34.46 1.51 # (country lat lon) with 0.01° precision
GMARKMAIL="support+$(echo $(hostname) $GO | sed "s| |-|g")@qo-op.com" # ex: support+nexus-55-FR-34.46-1.51@qo-op.com

##########################################################
echo "##### CAPTAIN ################## ON BOARDING ${GMARKMAIL}"
espeak "Welcome CAPTAIN" 2>/dev/null
echo "Adapt ~/.zen/Astroport.ONE/.env file to your needs"
echo "#####################################################"
################ COMPTE CAPTAINE AUTOMATIQUE
## MULTIPASS --->
echo ">>> Create CAPTAIN MULTIPASS <<<" 
~/.zen/Astroport.ONE/tools/make_NOSTRCARD.sh "${GMARKMAIL}" $GO

## ZEN CARD --->
echo ">>> Create CAPTAIN ZENCARD <<<"
ZSALT=$(${HOME}/.zen/Astroport.ONE/tools/diceware.sh $(( ${HOME}/.zen/Astroport.ONE/tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)
ZPEPS=$(${HOME}/.zen/Astroport.ONE/tools/diceware.sh $(( ${HOME}/.zen/Astroport.ONE/tools/getcoins_from_gratitude_box.sh) + 3 )) | xargs)

source ~/.zen/game/nostr/${GMARKMAIL}/.secret.nostr ## get NPUB & HEX
~/.zen/Astroport.ONE/RUNTIME/VISA.new.sh" "$ZSALT" "$ZPEPS" "${GMARKMAIL}" "UPlanet" ${GO} "$NPUB" "$HEX"

