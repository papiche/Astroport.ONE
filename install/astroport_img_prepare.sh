#!/bin/bash
########################################################################
# SYSPREP ASTROPORT.ONE - Préparation d'une Golden Image
# Ce script efface toutes les identités, clés crypto et logs.
# À LANCER JUSTE AVANT D'ÉTEINDRE ET CLONER LA CARTE SD !
########################################################################

echo "⚠️ ATTENTION : Ce script va DÉTRUIRE l'identité de ce nœud."
echo "Il est conçu uniquement pour préparer une image (ISO/IMG) distribuable."
read -p "Es-tu sûr de vouloir continuer ? (écris 'OUI' pour confirmer) : " CONFIRM
if[ "$CONFIRM" != "OUI" ]; then
    echo "Annulation."
    exit 1
fi

echo "🛑 1. Arrêt des services..."
sudo systemctl stop astroport ipfs upassport prometheus-node-exporter astroport-metrics.timer 2>/dev/null
# Arrêt de tous les conteneurs Docker (NPM, Nextcloud, Dify, etc.)
docker stop $(docker ps -aq) 2>/dev/null
# Suppression des conteneurs (On GARDE les images pour que les prochains utilisateurs n'aient pas à les retélécharger)
docker rm $(docker ps -aq) 2>/dev/null

echo "🧹 2. Nettoyage des clés cryptographiques Astroport (G1, NOSTR, ZEN)..."
rm -rf ~/.zen/game/*
rm -rf ~/.zen/tmp/*
rm -f ~/.zen/*.log ~/.zen/♥Box ~/.zen/IPCity ~/.zen/GPS

echo "🔄 3. Réinitialisation de la configuration Astroport (.env)..."
# On remet le template à neuf pour forcer le setup au prochain boot
cp ~/.zen/Astroport.ONE/.env.template ~/.zen/Astroport.ONE/.env

echo "🕸️ 4. Nettoyage de l'identité IPFS (Génération d'un nouveau PeerID)..."
rm -rf ~/.ipfs
# On réinitialise un IPFS vierge
ipfs init
# On replace la clé publique UPlanet ORIGIN par défaut (Bac à sable)
cat > ~/.ipfs/swarm.key <<EOF
/key/swarm/psk/1.0.0/
/base16/
0000000000000000000000000000000000000000000000000000000000000000
EOF
chmod 600 ~/.ipfs/swarm.key

echo "🗑️ 5. Nettoyage des bases de données locales (Nginx Proxy, NOSTR Strfry)..."
sudo rm -rf ~/.zen/nginx-proxy-manager/data/*
sudo rm -rf ~/.zen/nginx-proxy-manager/letsencrypt/*
sudo rm -rf ~/.zen/nginx-proxy-manager/self-signed/*
rm -rf ~/.zen/strfry/strfry-db/*

echo "🔑 6. Nettoyage des clés SSH et de l'identité système Linux..."
# Le système regénérera ces clés automatiquement au prochain boot
sudo rm -f /etc/ssh/ssh_host_*
rm -rf ~/.ssh/*

# On vide le machine-id (identifiant unique de l'OS)
sudo truncate -s 0 /etc/machine-id
if[ -f /var/lib/dbus/machine-id ]; then
    sudo rm -f /var/lib/dbus/machine-id
    sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
fi

echo "📦 7. Nettoyage des caches APT et des logs système..."
sudo apt-get clean
sudo apt-get autoremove -y
sudo journalctl --vacuum-time=1s
sudo rm -rf /var/log/*.gz /var/log/*.[0-9] /var/log/*-????????

echo "📜 8. Nettoyage de l'historique Bash..."
cat /dev/null > ~/.bash_history
history -c

echo ""
echo "========================================================================"
echo "🎉 PRÉPARATION TERMINÉE ! LE RASPBERRY PI EST PRÊT À ÊTRE CLONÉ."
echo "========================================================================"
echo "La suite des opérations se passera sur votre PC Linux :"
echo ""
echo "1. Éteignez le Pi, retirez la carte SD et insérez-la dans votre PC."
echo "2. Identifiez la carte (ex: /dev/sdb ou /dev/mmcblk0) avec 'lsblk'."
echo "3. Créez l'image brute (remplacez sdX par votre carte) :"
echo -e "\033[1;33m   sudo dd if=/dev/sdX of=astroport_trixie.img bs=4M status=progress\033[0m"
echo "4. Téléchargez l'outil PiShrink sur votre PC :"
echo -e "\033[1;33m   wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh\033[0m"
echo -e "\033[1;33m   chmod +x pishrink.sh\033[0m"
echo "5. Réduisez et compressez l'image (l'option -a permet l'auto-expansion) :"
echo -e "\033[1;33m   sudo ./pishrink.sh -z -a astroport_trixie.img astroport_distrib.img.gz\033