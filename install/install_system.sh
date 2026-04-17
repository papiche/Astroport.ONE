#!/bin/bash
######################################################################## install_system.sh
# System-level install operations (build-time for Docker)
# Extracted from setup.sh — these do not depend on instance identity
# Called by install.sh before setup.sh
# License: AGPL-3.0
########################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"
ASTRO="${HOME}/.zen/Astroport.ONE"

echo "#############################################"
echo "######### SYSTEM INSTALL (build-time) #######"
echo "#############################################"

### ADD USER TO ADM & DOCKER GROUP
sudo usermod -aG adm $USER
sudo usermod -aG docker $USER

########################################################################
# open_with_linux.py install
########################################################################
echo "# OPEN WITH LINUX (Firefox extension helper)"
${ASTRO}/open_with_linux.py install
cat ${ASTRO}/open_with_yt-dlp.txt | sed "s|_HOME_|$HOME|g" > ~/.zen/open_with_yt-dlp.txt
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

########################################################################
# DESKTOP SHORTCUTS
########################################################################
echo "# ADDING <<<Astroport & REC >>>  DESKTOP SHORTCUT"
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ${ASTRO}/astroport.desktop > ~/Bureau/astroport.desktop && chmod +x ~/Bureau/astroport.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ${ASTRO}/astroport.desktop > ~/Desktop/astroport.desktop && chmod +x ~/Desktop/astroport.desktop
[[ -d ~/Bureau ]] && sed "s/_USER_/$USER/g" ${ASTRO}/rec.desktop > ~/Bureau/rec.desktop && chmod +x ~/Bureau/rec.desktop
[[ -d ~/Desktop ]] && sed "s/_USER_/$USER/g" ${ASTRO}/rec.desktop > ~/Desktop/rec.desktop && chmod +x ~/Desktop/rec.desktop

########################################################################
# DESKTOP SHORTCUTS (Mint, Ubuntu, Debian)
########################################################################
echo "######### INSTALLATION DES RACCOURCIS BUREAU #######"

ASTRO="${HOME}/.zen/Astroport.ONE"
DESKTOPS=("$HOME/Bureau" "$HOME/Desktop")

for DESK in "${DESKTOPS[@]}"; do
    if [[ -d "$DESK" ]]; then
        echo "Configuration du bureau dans : $DESK"

        # 1. Raccourci REC (Ajouter Média)
        # On utilise le fichier existant en s'assurant que le chemin est correct
        sed "s|/home/fred|$HOME|g" "${ASTRO}/rec.desktop" > "$DESK/rec.desktop"

        # 2. Raccourci TOGGLE ON/OFF
        sed "s|_ASTRO_PATH_|$ASTRO|g" "${ASTRO}/astroport_toggle.desktop" > "$DESK/astroport_toggle.desktop"

        # 2. Raccourci UPLANET
        sed "s|_ASTRO_PATH_|$ASTRO|g" "${ASTRO}/uplanet.desktop" > "$DESK/uplanet.desktop"

        # Permissions
        chmod +x "$DESK/rec.desktop"
        chmod +x "$DESK/astroport_toggle.desktop"
        chmod +x "$DESK/uplanet.desktop"

        # Confiance GNOME/Cinnamon (évite le message "Lanceur non fiable")
        gio set "$DESK/rec.desktop" metadata::trusted true 2>/dev/null || true
        gio set "$DESK/astroport_toggle.desktop" metadata::trusted true 2>/dev/null || true
        gio set "$DESK/uplanet.desktop" metadata::trusted true 2>/dev/null || true
    fi
done

# Initialisation de l'icône de toggle selon l'état actuel
bash "${ASTRO}/tools/astroport_toggle.sh" status_only 2>/dev/null || true

######### SUPER PRATIQUE :: DOES NOT WORK WITH SPACE IN FILENAME
echo "# ADD NEMO 'Add To IPFS' ACTION"
${ASTRO}/install/install.nemo.add2ipfs.sh

########################################################################
# SYSTEMD astroport SERVICE
########################################################################
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

########################################################################
# SSH HARDENING
########################################################################
echo "... Optimizing security into /etc/ssh/sshd_config"
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sudo sed -i 's/^.*PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^.*PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/^.*ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^.*PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^.*X11Forwarding .*/X11Forwarding yes/' /etc/ssh/sshd_config
sudo sed -i 's/^.*ClientAliveInterval .*/ClientAliveInterval 60/' /etc/ssh/sshd_config
sudo sed -i 's/^.*ClientAliveCountMax .*/ClientAliveCountMax 3/' /etc/ssh/sshd_config

########################################################################
# SYMLINKS (Astroport tools in PATH)
########################################################################
mkdir -p ~/.local/bin
ln -f -s ${ASTRO}/tunnel.sh ~/.local/bin/tunnel.sh
ln -f -s ${ASTRO}/cpcode ~/.local/bin/cpcode
ln -f -s ${ASTRO}/cpscript ~/.local/bin/cpscript
ln -f -s ${ASTRO}/tools/natools.py ~/.local/bin/natools
ln -f -s ${ASTRO}/tools/keygen ~/.local/bin/keygen
ln -f -s ${ASTRO}/captain.sh ~/.local/bin/captain
ln -f -s ${ASTRO}/tools/astrosystemctl.sh ~/.local/bin/astrosystemctl
## gcli symlink (g1cli Duniter v2s client)
[[ $(which gcli 2>/dev/null) ]] && ln -f -s $(which gcli) ~/.local/bin/gcli
## Créer le répertoire pour les tunnels persistants
mkdir -p "$HOME/.zen/tunnels/enabled"

echo "######### SYSTEM INSTALL COMPLETE #############"
