#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

echo
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
# DEPRECATED

    #~ echo "#############################################"
    #~ ## https://darktrojan.github.io/openwith/webextension.html"
    #~ ~/.zen/Astroport.ONE/open_with_linux.py install

    #~ echo "#############################################
    #~ # NOURRISSEZ VOTRE BLOB depuis Firefox !!
    #~ # https://addons.mozilla.org/firefox/addon/open-with
    #~ #############################################
    #~ ##    $HOME/.zen/Astroport.ONE/ajouter_media.sh      ##
    #~ #############################################"

########################################################################
# SUDO permissions
########################################################################
## USED FOR RAMDISK (video live streaming)
## USED FOR SYSTEM UPGRADE
## USED FOR "systemctl restart ipfs"
## USED FOR "sudo youtube-dl -U"
for bin in fail2ban-client mount umount apt-get apt systemctl docker; do
binpath=$(which $bin)
[[ -x $binpath ]] \
    && echo "$USER ALL=(ALL) NOPASSWD:$binpath" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/'$bin) \
    && echo "SUDOERS RIGHT SET FOR : $binpath" \
    || echo "ERROR MISSING $bin"
done
### MODIFIYING /etc/sudoers ###
[[ "$USER" == "xbian" ]] && echo "xbian ALL=(ALL) NOPASSWD:ALL" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/astroport')

echo "#############################################"
echo "# ADDING <<<Astroport & REC >>>  DESKTOP SHORTCUT"
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/astroport.desktop > ~/Bureau/astroport.desktop && chmod +x ~/Bureau/astroport.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/astroport.desktop > ~/Desktop/astroport.desktop && chmod +x ~/Desktop/astroport.desktop
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/rec.desktop > ~/Bureau/rec.desktop && chmod +x ~/Bureau/rec.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/rec.desktop > ~/Desktop/rec.desktop && chmod +x ~/Desktop/rec.desktop
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/g1billet.desktop > ~/Bureau/g1billet.desktop && chmod +x ~/Bureau/g1billet.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/g1billet.desktop > ~/Desktop/g1billet.desktop && chmod +x ~/Desktop/g1billet.desktop

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

# Effectue les modifications en utilisant sed
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

echo "####################### YLEVEL ACTIVATION "
~/.zen/Astroport.ONE/tools/Ylevel.sh

# ACTIVATING ASTROPORT CRON
echo ">>> SWITHCIN ASTROPORT ON <<<
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON"
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON

echo "############################## ♥BOX READY ###"
##########################################################
## ON BOARDING PLAYER
echo "############################### ON BOARDING"
espeak "Welcome CAPTAIN" 2>/dev/null
echo ">>> Now Create CAPTAIN Account <<<"
cd ~/.zen/Astroport.ONE/
./command.sh
