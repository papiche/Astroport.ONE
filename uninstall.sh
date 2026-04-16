#!/bin/bash
########################################################################
# Astroport.ONE Complete Uninstaller
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
{
[ $(id -u) -eq 0 ] && echo "LANCEMENT root INTERDIT. Utilisez un simple utilisateur du groupe \"sudo\" SVP" && exit 1

echo "========================================"
echo "ASTROPORT.ONE COMPLETE UNINSTALLER"
echo "========================================"
echo "This will remove all Astroport.ONE components, services, and configurations."
echo "This action cannot be undone!"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ $confirm != "yes" ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo "Starting complete uninstall process..."

########################################################################
echo "STOPPING AND DISABLING ALL ASTROPORT SERVICES"
########################################################################

# Stop and disable all systemd services
for service in astroport ipfs g1billet upassport strfry ollama comfyui; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "Stopping $service..."
        sudo systemctl stop $service 2>/dev/null
    fi
    if systemctl is-enabled --quiet $service 2>/dev/null; then
        echo "Disabling $service..."
        sudo systemctl disable $service 2>/dev/null
    fi
done

# ── NextCloud AIO ────────────────────────────────────────────────────
_NC_COMPOSE="$HOME/.zen/Astroport.ONE/_DOCKER/nextcloud/docker-compose.yml"
if [[ -f "$_NC_COMPOSE" ]]; then
    echo "Stopping NextCloud AIO..."
    docker compose -f "$_NC_COMPOSE" down 2>/dev/null || true
fi
# Supprimer le volume NextCloud AIO (données utilisateurs)
read -p "Supprimer les volumes NextCloud AIO (données utilisateurs !) ? (y/n): " remove_nc_vols
if [[ $remove_nc_vols == "y" ]]; then
    docker compose -f "$_NC_COMPOSE" down -v 2>/dev/null || true
    docker volume rm nextcloud_aio_mastercontainer 2>/dev/null || true
    echo "✅ Volumes NextCloud supprimés"
fi

# ── AI Stack ai-company (Dify AI, OpenWebUI, LiteLLM, Qdrant) ────
if [[ -d "$HOME/.zen/ai-company" ]]; then
    echo "Stopping AI Company Stack (ai-company)..."
    docker compose -p ai-company-swarm down 2>/dev/null || true
    read -p "Supprimer les volumes AI Stack (données Qdrant, PostgreSQL) ? (y/n): " remove_ai_vols
    if [[ $remove_ai_vols == "y" ]]; then
        docker compose -p ai-company-swarm down -v 2>/dev/null || true
        docker volume rm ai-company-swarm_postgres_data ai-company-swarm_qdrant_storage 2>/dev/null || true
        echo "✅ Volumes AI Stack supprimés"
    fi
fi

# ── Webtop VDI (KasmVNC) ─────────────────────────────────────────────
_WEBTOP_COMPOSE="$HOME/.zen/Astroport.ONE/docker/docker-compose.webtop.yml"
if docker ps --format '{{.Image}}' | grep -q 'linuxserver/webtop' 2>/dev/null; then
    echo "Stopping linuxserver Webtop container..."
    docker compose -f "$_WEBTOP_COMPOSE" down 2>/dev/null || true
fi

# ── Stacks Docker historiques (rnostr, qdrant, embed-worker) ─────────
if [[ -f ~/.zen/rnostr/docker-compose.yml ]]; then
    echo "Stopping rnostr/qdrant docker stack..."
    docker compose -f ~/.zen/rnostr/docker-compose.yml down 2>/dev/null || true
fi
# Retirer les containers individuels résiduels
for container in qdrant embed-worker rnostr bgutil-provider; do
    docker stop  "$container" 2>/dev/null
    docker rm    "$container" 2>/dev/null
done

# Kill any remaining processes
echo "Killing remaining processes..."
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) > /dev/null 2>&1
killall nc 12345.sh > /dev/null 2>&1
pkill -f "20h12.process.sh" > /dev/null 2>&1
pkill -f "python.*54321.py" > /dev/null 2>&1
pkill -f "strfry" > /dev/null 2>&1

########################################################################
echo "REMOVING SYSTEMD SERVICE FILES"
########################################################################

# Remove systemd service files
sudo rm -f /etc/systemd/system/astroport.service
sudo rm -f /etc/systemd/system/ipfs.service
sudo rm -f /etc/systemd/system/g1billet.service
sudo rm -f /etc/systemd/system/upassport.service
sudo rm -f /etc/systemd/system/strfry.service
sudo rm -f /etc/systemd/system/process-stream.service
sudo rm -f /etc/systemd/system/ipfs-exporter.service
sudo rm -f /etc/systemd/system/nextcloud-exporter.service
sudo rm -f /etc/systemd/system/astroport-exporter.service
sudo rm -f /etc/systemd/system/comfyui.service
sudo rm -f /etc/systemd/system/powerjoular.service
# Prometheus metrics collector timer+service (install_prometheus.sh)
sudo systemctl stop    astroport-metrics.timer  2>/dev/null || true
sudo systemctl disable astroport-metrics.timer  2>/dev/null || true
sudo rm -f /etc/systemd/system/astroport-metrics.service
sudo rm -f /etc/systemd/system/astroport-metrics.timer

sudo systemctl daemon-reload

########################################################################
echo "REMOVING CRON JOBS"
########################################################################

echo "Removing cron jobs from crontab..."
crontab -l > /tmp/mycron 2>/dev/null || touch /tmp/mycron
# Remove any lines containing these patterns
awk -i inplace -v rmv="20h12.process.sh" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="cron_MINUTE" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="ipfs repo gc" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="ASTROPORT" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="Astroport" '!index($0,rmv)' /tmp/mycron
# Supprimer les lignes d'environnement injectées par cron_VRFY.sh (SHELL=, USER=, PATH= astro)
awk -i inplace -v rmv="SHELL=/bin/bash" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv="USER=$USER" '!index($0,rmv)' /tmp/mycron
awk -i inplace -v rmv=".astro/bin:" '!index($0,rmv)' /tmp/mycron
crontab /tmp/mycron
rm -f /tmp/mycron

########################################################################
echo "REMOVING /etc/sudoers EXTRA PERMISSIONS"
########################################################################

# Remove custom sudoers files
[[ "$USER" == "xbian" ]] && sudo rm -f /etc/sudoers.d/astroport
sudo rm -f /etc/sudoers.d/captain          # NOPASSWD:ALL — créé par install_system.sh
sudo rm -f /etc/sudoers.d/fail2ban-client
sudo rm -f /etc/sudoers.d/mount
sudo rm -f /etc/sudoers.d/umount
sudo rm -f /etc/sudoers.d/apt-get
sudo rm -f /etc/sudoers.d/apt
sudo rm -f /etc/sudoers.d/systemctl
sudo rm -f /etc/sudoers.d/ufw
sudo rm -f /etc/sudoers.d/docker
sudo rm -f /etc/sudoers.d/hdparm
sudo rm -f /etc/sudoers.d/kill
sudo rm -f /etc/sudoers.d/brother_ql_print
sudo rm -f /etc/sudoers.d/powerjoular
sudo rm -f /etc/sudoers.d/sudo

########################################################################
echo "REMOVING LOCAL BINARIES AND SYMLINKS"
########################################################################

# Remove symlinks and binaries in ~/.local/bin
rm -f ~/.local/bin/code_assistant
rm -f ~/.local/bin/cpcode
rm -f ~/.local/bin/cpscript
rm -f ~/.local/bin/natools
rm -f ~/.local/bin/keygen
rm -f ~/.local/bin/coeurbox
rm -f ~/.local/bin/gcli
rm -f ~/.local/bin/youtube-dl
rm -f ~/.local/bin/yt-dlp
rm -f ~/.local/bin/lazydocker
rm -f ~/.local/bin/espeak

# Supprimer le symlink /usr/bin/python créé par install.sh
if [[ -L /usr/bin/python ]]; then
    echo "Removing /usr/bin/python symlink..."
    sudo rm -f /usr/bin/python
fi

# Supprimer powerjoular (compilé depuis source, installé dans /usr/bin)
if [[ -f /usr/bin/powerjoular ]]; then
    echo "Removing powerjoular binary..."
    sudo rm -f /usr/bin/powerjoular
fi
# Données PowerJoular
sudo rm -rf /var/lib/powerjoular 2>/dev/null || true

# Supprimer le collector Prometheus créé par install_prometheus.sh
sudo rm -f /usr/local/bin/astroport-metrics-collector.sh

# Supprimer l'action Nemo "Add to IPFS"
rm -f ~/.local/share/nemo/actions/add2ipfs.nemo_action

# Désinstaller open_with_linux.py (helper Firefox)
if [[ -x ~/.zen/Astroport.ONE/open_with_linux.py ]]; then
    ~/.zen/Astroport.ONE/open_with_linux.py uninstall 2>/dev/null || true
fi

# Restaurer youtube-dl original si sauvegardé lors du remplacement par yt-dlp
for ytdl_old in /usr/bin/youtube-dl.old /usr/local/bin/youtube-dl.old; do
    if [[ -f "$ytdl_old" ]]; then
        echo "Restoring original youtube-dl from $ytdl_old..."
        sudo mv "$ytdl_old" "${ytdl_old%.old}"
        break
    fi
done

########################################################################
echo "RESTORING SYSTEM CONFIGURATION FILES"
########################################################################

# DISABLE ipfs
if [[ "$USER" == "xbian" ]]; then
    mv /etc/rc2.d/S02ipfs /etc/rc2.d/K01ipfs 2>/dev/null
    mv /etc/rc3.d/S02ipfs /etc/rc3.d/K01ipfs 2>/dev/null
    mv /etc/rc4.d/S02ipfs /etc/rc4.d/K01ipfs 2>/dev/null
    mv /etc/rc5.d/S02ipfs /etc/rc5.d/K01ipfs 2>/dev/null
fi

# RESTORE OLD KODI
[[ -e ~/.kodi.old ]] && echo "RESTORE KODI" && rm -Rf ~/.kodi && mv ~/.kodi.old ~/.kodi

# RESTORE resolv.conf
[[ -s /etc/resolv.conf.backup ]] && echo "RESTORE resolv.conf" \
    && sudo chattr -i /etc/resolv.conf \
    && sudo cp /etc/resolv.conf.backup /etc/resolv.conf

# RESTORE SSH config
[[ -s /etc/ssh/sshd_config.bak ]] && echo "RESTORE SSH config" \
    && sudo cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config \
    && sudo systemctl restart ssh

# Remove custom hosts entries (ajoutées par setup.sh)
if [[ $(cat /etc/hosts | grep -w "astroport.local" | head -n 1) ]]; then
    echo "Removing custom hosts entries..."
    sudo sed -i '/astroport\.local/d' /etc/hosts
    sudo sed -i '/astroport\..*\.local/d' /etc/hosts
    sudo sed -i '/ipfs\..*\.local/d' /etc/hosts
    sudo sed -i '/duniter\.localhost/d' /etc/hosts
fi

# Restore ImageMagick policy if it was modified
if [[ -f /etc/ImageMagick-6/policy.xml.backup ]]; then
    echo "Restoring ImageMagick policy..."
    sudo cp /etc/ImageMagick-6/policy.xml.backup /etc/ImageMagick-6/policy.xml
elif [[ -f /etc/ImageMagick-6/policy.xml ]]; then
    # Fallback : re-insérer la restriction PDF si le backup n'existe pas
    echo "Re-adding ImageMagick PDF restriction (no backup found)..."
    sudo sed -i 's|<policymap>|<policymap>\n  <policy domain="coder" rights="none" pattern="PDF"/>|' \
        /etc/ImageMagick-6/policy.xml 2>/dev/null || true
fi

# Nettoyer la configuration custom de prometheus-node-exporter
if [[ -f /etc/default/prometheus-node-exporter ]]; then
    echo "Cleaning prometheus-node-exporter ARGS..."
    sudo sed -i '/astroport.*textfile\|textfile.*astroport\|^ARGS=.*textfile/d' \
        /etc/default/prometheus-node-exporter 2>/dev/null || true
fi
# Supprimer le fichier .prom créé par le collector
sudo rm -f /var/lib/prometheus/node-exporter/astroport_heartbox.prom 2>/dev/null || true

# Revert cups remote admin (activé par install.sh pour les imprimantes)
if which cupsctl &>/dev/null; then
    echo "Disabling CUPS remote admin..."
    sudo cupsctl --no-remote-admin 2>/dev/null || true
fi

# Revert git global config (submodule.recurse = true positionné par install.sh)
git config --global --unset submodule.recurse 2>/dev/null || true

########################################################################
echo "REMOVING DESKTOP SHORTCUTS"
########################################################################

# Remove desktop shortcuts
rm -f ~/Bureau/astroport.desktop ~/Desktop/astroport.desktop
rm -f ~/Bureau/rec.desktop ~/Desktop/rec.desktop  
rm -f ~/Bureau/g1billet.desktop ~/Desktop/g1billet.desktop

########################################################################
echo "REMOVING USER GROUP MEMBERSHIPS"
########################################################################

# Remove user from docker and other groups (optional)
read -p "Remove user from docker, lpadmin, tty, lp groups? (y/n): " remove_groups
if [[ $remove_groups == "y" ]]; then
    sudo deluser $USER docker 2>/dev/null
    sudo deluser $USER lpadmin 2>/dev/null
    sudo deluser $USER tty 2>/dev/null
    sudo deluser $USER lp 2>/dev/null
    sudo deluser $USER adm 2>/dev/null
fi

########################################################################
echo "REMOVING PYTHON VIRTUAL ENVIRONMENT AND PACKAGES"
########################################################################

# Remove Python virtual environment
if [[ -d ~/.astro ]]; then
    echo "Removing Python virtual environment..."
    rm -rf ~/.astro
fi

# Offer to remove Python packages (optional since they might be used by other apps)
read -p "Remove Python packages installed by Astroport? (y/n): " remove_python
if [[ $remove_python == "y" ]]; then
    echo "Removing Python packages..."
    pip3 uninstall -y duniterpy python-dotenv termcolor amzqr ollama requests beautifulsoup4 pyppeteer cryptography jwcrypto secp256k1 Ed25519 gql base58 pybase64 google pynacl python-gnupg pgpy pynentry paho-mqtt aiohttp ipfshttpclient bitcoin monero ecdsa pynostr bech32 brother_ql 2>/dev/null
    pipx uninstall duniterpy 2>/dev/null
fi

########################################################################
echo "REMOVING NODEJS PACKAGES"
########################################################################

# Remove global npm packages
read -p "Remove TiddlyWiki and other global npm packages? (y/n): " remove_npm
if [[ $remove_npm == "y" ]]; then
    echo "Removing global npm packages..."
    sudo npm uninstall -g tiddlywiki 2>/dev/null
fi

########################################################################
echo "REMOVING APT PACKAGES"
########################################################################

# Offer to remove apt packages (be very careful here)
read -p "Remove APT packages installed by Astroport? This may affect other software! (y/n): " remove_apt
if [[ $remove_apt == "y" ]]; then
    echo "WARNING: This will remove many packages that might be used by other software!"
    read -p "Are you absolutely sure? Type 'REMOVE' to confirm: " final_confirm
    
    if [[ $final_confirm == "REMOVE" ]]; then
        echo "Removing APT packages..."
        # Core Astroport packages that are likely safe to remove
        sudo apt-get remove -y tldr ssss multitail netcat-traditional ncdu miller inotify-tools mosquitto fail2ban brother_ql 2>/dev/null
        
        # ASCII art tools
        sudo apt-get remove -y figlet cmatrix cowsay fonts-hack-ttf 2>/dev/null
        
        # Printer related (if no printer)
        read -p "Remove printer drivers? (y/n): " remove_printer
        if [[ $remove_printer == "y" ]]; then
            sudo apt-get remove -y ttf-mscorefonts-installer printer-driver-all cups 2>/dev/null
        fi
        
        # Optional: Docker (be very careful)
        read -p "Remove Docker? This will affect ALL containers! (y/n): " remove_docker
        if [[ $remove_docker == "y" ]]; then
            sudo apt-get remove -y docker.io docker-compose 2>/dev/null
        fi
        
        sudo apt-get autoremove -y
    fi
fi

########################################################################
echo "REMOVING IPFS"
########################################################################

read -p "Remove IPFS completely? (y/n): " remove_ipfs
if [[ $remove_ipfs == "y" ]]; then
    echo "Removing IPFS..."
    sudo rm -f /usr/local/bin/ipfs
    rm -rf ~/.ipfs
fi

########################################################################
echo "CLEANING BASHRC"
########################################################################

# Clean up bashrc modifications
if [[ -f ~/.bashrc.bak ]]; then
    echo "Restoring original bashrc..."
    cp ~/.bashrc.bak ~/.bashrc
else
    echo "Cleaning bashrc manually..."
    # Remove Astroport-specific lines (ajoutées par setup.sh / install_flutter.sh)
    sed -i '/ASTROPORT/d' ~/.bashrc
    sed -i '/astro\/bin\/activate/d' ~/.bashrc
    sed -i '/\.zen\/Astroport\.ONE/d' ~/.bashrc
    sed -i '/IPFSNODEID/d' ~/.bashrc
    sed -i '/UPLANET/d' ~/.bashrc
    sed -i '/CAPTAIN/d' ~/.bashrc
    sed -i '/cowsay.*hostname/d' ~/.bashrc
    # Flutter SDK (ajouté par install_flutter.sh)
    sed -i '/Flutter SDK/d' ~/.bashrc
    sed -i '/\.flutter\/bin/d' ~/.bashrc
    # Deno (si ajouté manuellement)
    sed -i '/DENO_INSTALL/d' ~/.bashrc
    sed -i '/\.deno\/bin/d' ~/.bashrc
    # Ligne PATH ~/.local/bin (ajoutée par setup.sh)
    sed -i '/export PATH=\$HOME\/.local\/bin/d' ~/.bashrc
fi

########################################################################
echo "DISABLING FIREWALL RULES"
########################################################################

# Désactiver UFW (révoque toutes les règles posées par firewall.sh ON)
if which ufw &>/dev/null && sudo ufw status | grep -q "Status: active"; then
    echo "Disabling UFW firewall..."
    ~/.zen/Astroport.ONE/tools/firewall.sh OFF 2>/dev/null \
        || sudo ufw --force disable 2>/dev/null
fi

########################################################################
echo "REMOVING OPTIONAL TOOLS (Deno, Flutter)"
########################################################################

read -p "Remove Deno (~/.deno)? (y/n): " remove_deno
if [[ $remove_deno == "y" ]]; then
    echo "Removing Deno..."
    rm -rf ~/.deno
fi

read -p "Remove Flutter SDK (~/.flutter)? (y/n): " remove_flutter
if [[ $remove_flutter == "y" ]]; then
    echo "Removing Flutter SDK..."
    rm -rf ~/.flutter ~/.flutter_tool_state
fi

########################################################################
echo "FINAL CLEANUP"
########################################################################

# ── Symlinks BTRFS (/nextcloud-data) ────────────────────────────────
# Si ~/.zen et/ou ~/.ipfs sont des liens symboliques vers /nextcloud-data
# créés lors de la migration BTRFS, les supprimer proprement
if [[ -L "$HOME/.zen" ]]; then
    echo "Lien symbolique ~/.zen → $(readlink $HOME/.zen) détecté"
    read -p "Supprimer le symlink ~/.zen (les données restent dans /nextcloud-data) ? (y/n): " rm_zen_lnk
    if [[ $rm_zen_lnk == "y" ]]; then
        rm -f "$HOME/.zen"
        echo "✅ Symlink ~/.zen supprimé (données conservées dans $(readlink -f $HOME/.zen 2>/dev/null || echo '/nextcloud-data/zen'))"
    fi
else
    mv ~/.zen ~/.zen.todelete 2>/dev/null
fi

if [[ -L "$HOME/.ipfs" ]]; then
    echo "Lien symbolique ~/.ipfs → $(readlink $HOME/.ipfs) détecté"
    read -p "Supprimer aussi le symlink ~/.ipfs ? (y/n): " rm_ipfs_lnk
    [[ $rm_ipfs_lnk == "y" ]] && rm -f "$HOME/.ipfs" && echo "✅ Symlink ~/.ipfs supprimé"
fi

read -p "Supprimer /nextcloud-data (volumes NextCloud + données BTRFS) ? (⚠️ IRRÉCUPÉRABLE) (y/n): " rm_nc_data
if [[ $rm_nc_data == "y" ]]; then
    echo "❌ Suppression de /nextcloud-data... (sudo requis)"
    sudo rm -rf /nextcloud-data
    echo "✅ /nextcloud-data supprimé"
fi

# Clean temporary files
rm -rf /tmp/20h12.log /tmp/20h12_power_report.html \
    /tmp/astroport.* /tmp/ipfs.* /tmp/strfry.* \
    /tmp/g1billet.* /tmp/upassport.* \
    "$HOME/.zen/log/20h12"*.log 2>/dev/null

echo ""
echo "========================================"
echo "ASTROPORT UNINSTALL COMPLETED"
echo "========================================"
echo ""
echo "The following has been removed/disabled:"
echo "✓ All systemd services stopped and disabled"
echo "✓ Service configuration files removed"
echo "✓ Cron jobs removed"
echo "✓ Sudo permissions revoked"
echo "✓ Local binaries and symlinks removed"
echo "✓ System configuration restored"
echo "✓ Desktop shortcuts removed"
echo ""
echo "MANUAL CLEANUP REQUIRED:"
echo "- ~/.zen directory renamed to ~/.zen.todelete"
echo "- Run: rm -rf ~/.zen.todelete (after backing up any important data)"
echo ""
echo "OPTIONAL CLEANUP:"
if [[ $remove_groups != "y" ]]; then
    echo "- Remove user from groups: sudo deluser $USER docker"
fi
if [[ $remove_python != "y" ]]; then
    echo "- Remove Python packages manually if no longer needed"
fi
if [[ $remove_npm != "y" ]]; then
    echo "- Remove global npm packages: sudo npm uninstall -g tiddlywiki"
fi
if [[ $remove_apt != "y" ]]; then
    echo "- Remove APT packages manually if no longer needed"
fi
if [[ $remove_ipfs != "y" ]]; then
    echo "- Remove IPFS: sudo rm -f /usr/local/bin/ipfs && rm -rf ~/.ipfs"
fi
if [[ $remove_deno != "y" ]]; then
    echo "- Remove Deno: rm -rf ~/.deno"
fi
if [[ $remove_flutter != "y" ]]; then
    echo "- Remove Flutter: rm -rf ~/.flutter"
fi
echo ""
echo "REBOOT RECOMMENDED to ensure all changes take effect."
echo ""
echo "To completely finish removal, run:"
echo "rm -rf ~/.zen.todelete"

}
