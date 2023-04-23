#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

echo "#############################################"
echo ">>>>>>>>>>> SYSTEM SETUP  "
echo "#############################################"
#### SETUP JAKLIS ###############################################################
echo "=== SETUP jaklis"
cd ~/.zen/Astroport.ONE/tools/jaklis
sudo ./setup.sh

## XBIAN fail2ban ERROR correction ##
#[....] Starting authentication failure monitor: fail2ban No file(s) found for glob /var/log/auth.log
[[ "$USER" == "xbian" ]] && sudo sed -i "s/auth.log/faillog/g" /etc/fail2ban/paths-common.conf

# PERSONNAL DEFCON LEVEL
# cp ~/.zen/Astroport.ONE/DEFCON ~/.zen/
mkdir -p ~/.zen/tmp

########################################################################
# CREATE ~/astroport FILESYSTEM GATE
mkdir -p ~/Astroport/film
mkdir -p ~/Astroport/serie
mkdir -p ~/Astroport/anime
mkdir -p ~/Astroport/page
mkdir -p ~/Astroport/web
mkdir -p ~/Astroport/video
echo '${TYPE};${MEDIAID};${YEAR};${TITLE};${SAISON};${GENRES};_IPNSKEY_;${RES};/ipfs/_IPFSREPFILEID_/$URLENCODE_FILE_NAME' > ~/Astroport/ajouter_video.modele.txt


#######################################################################

    echo "#############################################"
    ## https://darktrojan.github.io/openwith/webextension.html"
    ~/.zen/Astroport.ONE/open_with_linux.py install

    echo "#############################################
    # NOURRISSEZ VOTRE BLOB depuis Firefox !!
    # https://addons.mozilla.org/firefox/addon/open-with
    #############################################
    ##    $HOME/.zen/Astroport.ONE/ajouter_media.sh      ##
    #############################################"

########################################################################
# SUDO permissions
########################################################################
## USED FOR RAMDISK (video live streaming)
## USED FOR SYSTEM UPGRADE
## USED FOR "systemctl restart ipfs"
## USED FOR "sudo youtube-dl -U"
for bin in fail2ban-client mount umount apt-get apt systemctl youtube-dl; do
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

echo "# ADD NEMO 'Add To IPFS' ACTION"
~/.zen/Astroport.ONE/tools/install.nemo.add2ipfs.sh

echo "CREATE SYSTEMD astroport SERVICE >>>>>>>>>>>>>>>>>>"
cat > /tmp/astroport.service <<EOF
[Unit]
Description=ASTROPORT API
After=network.target
Requires=network.target

[Service]
Type=simple
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
echo "ADDING nameserver 1.1.1.1 TO /etc/resolv.conf TO BYPASS LAN COUNTRY RESTRICTIONS" # Avoid provider restrictions
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
    echo "127.0.1.1    $(hostname) $(hostname).local astroport astroport.local" >> /tmp/hosts
    sudo cp /tmp/hosts /etc/hosts && rm /tmp/hosts
fi
### ADD 20h12.sh CRON ###############
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON


echo "#############################################"
## INSTALL yt-dlp & SYMLINK youtube-dl
~/.zen/Astroport.ONE/youtube-dl.sh

