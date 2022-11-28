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

[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

########################################################################
[[ ! $(which ipfs) ]] \
&& echo "=== Installez IPFS KUBO puis relancez Install ===" \
&& echo "bash <(wget -qO- https://git.p2p.legal/qo-op/Astroport.ONE/raw/branch/master/kubo_v0.16.0_linux-amd64.install.sh)" \
&& [[ $(uname -p) == "x86_64" ]] \
&& bash <(wget -qO- https://git.p2p.legal/qo-op/Astroport.ONE/raw/branch/master/kubo_v0.16.0_linux-amd64.install.sh)


#### GIT CLONE ###############################################################
[[ ! $(which git) ]] && sudo apt install -y git
echo "=== CLONAGE  '~/.zen/Astroport.ONE' depuis https://git.p2p.legal"
mkdir -p ~/.zen
cd ~/.zen

export GIT_SSL_NO_VERIFY=true
git clone --depth 1 https://git.p2p.legal/qo-op/Astroport.ONE.git
# TODO INSTALL FROM IPFS / IPNS

# MAIN # SI AUCUNE CLEF DE STATION...
if [[ ! -d ~/.zen/game/players/ ]];
then


# Check requirements
echo "Installateur Astroport.ONE pour distributions DEBIAN et dérivées : LinuxMint (https://www.linuxmint.com/)"
echo "$USER appuyez sur ENTRER."; read TEST;  [[ "$TEST" != "" ]] && echo "SORTIE" && exit 0 ## Ajouter confirmation à chaque nouvelle étape (+explications)
echo "#############################################"
echo "###### IPFS BIOS INSTALL ##############################"
echo "################  CRYPTO TW Ŋ1 PROTOCOL #############"
echo "tail -f /tmp/install.errors.log"
echo "##################################################"

echo ; echo "Mise à jour des dépots de votre distribution..."
sudo apt-get update


 for i in x11-utils xclip zenity; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>> Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        [[ $XDG_SESSION_TYPE == 'x11' ]] && sudo apt install -y $i;
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> /tmp/install.errors.log && continue
    fi
done

echo "#############################################"
echo "######### PATIENCE ####"
echo "#############################################"

for i in git fail2ban npm netcat-traditional inotify-tools curl net-tools libsodium* python3-pip python3-setuptools python3-wheel python3-dotenv python3-gpg python3-jwcrypto python3-brotli mpack; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>> Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> /tmp/install.errors.log && continue

    fi
done
echo "#############################################"
echo "######### PATIENCE ######"
echo "#############################################"
# removed : sqlite
for i in qrencode basez jq bc file gawk yt-dlp ffmpeg dnsutils ntpdate v4l-utils espeak vlc mp3info musl-dev openssl* detox nmap httrack html2text ssmtp imagemagick; do
    if [ $(dpkg-query -W -f='${Status}' $i 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo ">>> Installation $i <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        sudo apt install -y $i
        [[ $? != 0 ]] && echo "INSTALL $i FAILED." && echo "INSTALL $i FAILED." >> /tmp/install.errors.log && continue

    fi
done

echo "#############################################"
echo "######### PATIENCE ############"
echo "#############################################"
##########################################################
echo "### INSTALL TW node.js"
sudo npm install -g tiddlywiki sjcl-cli
[[ $? != 0 ]] && echo "INSTALL tiddlywikiFAILED." && echo "INSTALL tiddlywiki FAILED." >> /tmp/install.errors.log && continue

echo "#############################################"
echo "######### PATIENCE #################"
echo "#############################################"

##########################################################
echo "## INSTALLATION AstroGEEK OpenCV = 'Intelligence Amie' - DEV - "
# sudo apt-get install python3-opencv -y

## MAILJET SSMTP RELAYING : ADD YOUR CREDENTIALS
sudo cp ~/.zen/Astroport.ONE/templates/.ssmtprc /etc/ssmtp/ssmtp.conf
sudo chmod 600 /etc/ssmtp/ssmtp.conf

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

for i in pip setuptools wheel cryptography==3.4.8 Ed25519 base58 google duniterpy pynacl pgpy pynentry SecureBytes; do
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
    echo "Ambassade? Ajouter imprimante 'brother_ql'? Saisissez OUI, sinon laissez vide et tapez sur ENTRER"
    read saisie
    if [[ $saisie != "" ]]; then
        sudo apt install ttf-mscorefonts-installer printer-driver-all cups -y
        sudo pip3 install brother_ql
        sudo cupsctl --remote-admin
        sudo usermod -aG lpadmin pi
        sudo usermod -a -G tty pi
        sudo usermod -a -G lp pi

    fi
fi

echo "#############################################"
echo "######### PATIENCE #########################"
echo "#############################################"

## Scripts pour systemd ou InitV (xbian)
echo "=== SETUP IPFS SYSTEM"
~/.zen/Astroport.ONE/tools/ipfs_setup.sh

#### SETUP JAKLIS ###############################################################
echo "=== SETUP jaklis"
cd ~/.zen/Astroport.ONE/tools/jaklis
sudo ./setup.sh

## XBIAN fail2ban ERROR correction ##
#[....] Starting authentication failure monitor: fail2ban No file(s) found for glob /var/log/auth.log
[[ "$USER" == "xbian" ]] && sudo sed -i "s/auth.log/faillog/g" /etc/fail2ban/paths-common.conf

### MODIFIYING /etc/sudoers ###
[[ "$USER" == "xbian" ]] && echo "xbian ALL=(ALL) NOPASSWD:ALL" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/astroport')

# PERSONNAL DEFCON LEVEL
# cp ~/.zen/Astroport.ONE/DEFCON ~/.zen/

if [[ "$USER" == "xbian" ]]
then
    echo "enabling ipfs initV service autostart"
    cd /etc/rc2.d && sudo ln -s ../init.d/ipfs S02ipfs
    cd /etc/rc3.d && sudo ln -s ../init.d/ipfs S02ipfs
    cd /etc/rc4.d && sudo ln -s ../init.d/ipfs S02ipfs
    cd /etc/rc5.d && sudo ln -s ../init.d/ipfs S02ipfs

    cd /etc/rc0.d && sudo ln -s ../init.d/ipfs K01ipfs
    cd /etc/rc1.d && sudo ln -s ../init.d/ipfs K01ipfs
    cd /etc/rc6.d && sudo ln -s ../init.d/ipfs K01ipfs

    # Disable xbian-config auto launch
    echo 0 > ~/.xbian-config-start

fi

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
    [[ $XDG_SESSION_TYPE == 'x11' ]] && ~/.zen/Astroport.ONE/open_with_linux.py install; \
    echo "#############################################" \
    echo "# NOURRIR SON BLOB" \
    echo "# avec 'OpenWith' depuis votre navigateur !!" \
    echo "# https://addons.mozilla.org/firefox/addon/open-with/
# https://chrome.google.com/webstore/detail/open-with/cogjlncmljjnjpbgppagklanlcbchlno" \
    echo "#############################################" \
    echo \
    echo "   ##    $HOME/.zen/Astroport.ONE/ajouter_media.sh      ##" \
    echo \
    echo "#############################################"

### ADD 20h12.sh CRON ###############
~/.zen/Astroport.ONE/tools/cron_VRFY.sh ON

########################################################################
# SUDO permissions
########################################################################
## USED FOR fail2ban-client (DEFCON)
echo "$USER ALL=(ALL) NOPASSWD:/usr/bin/fail2ban-client" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/fail2ban-client')
## USED FOR RAMDISK (video live streaming)
echo "$USER ALL=(ALL) NOPASSWD:/bin/mount" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/mount')
echo "$USER ALL=(ALL) NOPASSWD:/bin/umount" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/umount')
## USED FOR SYSTEM UPGRADE
echo "$USER ALL=(ALL) NOPASSWD:/usr/bin/apt-get" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/apt-get')
echo "$USER ALL=(ALL) NOPASSWD:/usr/bin/apt" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/apt')
## USED FOR "systemctl restart ipfs"
echo "$USER ALL=(ALL) NOPASSWD:/bin/systemctl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/systemctl')
## USED FOR "systemctl restart ipfs"
echo "$USER ALL=(ALL) NOPASSWD:/usr/local/bin/youtube-dl" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/youtube-dl')

## brother_ql_print
echo "$USER ALL=(ALL) NOPASSWD:/usr/local/bin/brother_ql_print" | (sudo su -c 'EDITOR="tee" visudo -f /etc/sudoers.d/brother_ql_print')

echo "#############################################"
echo "# ADDING <<<Astroport>>>  DESKTOP SHORTCUT"
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/astroport.desktop > ~/Bureau/astroport.desktop && chmod +x ~/Bureau/astroport.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ~/.zen/Astroport.ONE/astroport.desktop > ~/Desktop/astroport.desktop && chmod +x ~/Desktop/astroport.desktop

mkdir -p ~/.zen/tmp

echo "#############################################"

## SYMLINK youtube-dl TO yt-dlp
sudo ln -s /usr/local/bin/yt-dlp /usr/local/bin/youtube-dl
which youtube-dl
echo "#############################################"
echo "#############################################"
    ## Desktop install
    echo "Astroport.ONE INSTALL"
    end=`date +%s`
echo Execution time was `expr $end - $start` seconds.
    echo "#############################################"
    echo "# START VISA ENGINE : ~/.zen/Astroport.ONE/start.sh"
    echo "#############################################"
    echo
    echo "Démarrer en mode Aventure. Tapez ENTRER."
    read ADVENTURE
    [[ $ADVENTURE ]] && ~/.zen/Astroport.ONE/start.sh \
                                        || ~/.zen/Astroport.ONE/adventure/adventure.sh

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
