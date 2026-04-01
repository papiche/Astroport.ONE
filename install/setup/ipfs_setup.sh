#!/bin/bash
################################################################### ipfs_setup.sh
# Version: 1.1
# License: AGPL-3.0
################################################################################
{ 
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized

ASTRO="${HOME}/.zen/Astroport.ONE"

# 1. CHARGEMENT DES VARIABLES SYSTEME
# On active le venv pour que keygen/python soient dispos
[[ -s "$HOME/.astro/bin/activate" ]] && . "$HOME/.astro/bin/activate"
# Source my.sh pour avoir $isLAN, $UPLANETNAME, $IPFSNODEID, etc.
if [[ -f "$ASTRO/tools/my.sh" ]]; then
    source "$ASTRO/tools/my.sh"
else
    echo "ERREUR: my.sh introuvable" && exit 1
fi

# Sécurité root
if [ "$EUID" -eq 0 ]; then 
    echo -e "NE PAS EXECUTER EN root. Utilisez l'utilisateur de la station (ex: pi ou fred)"
    exit 1
fi

# 2. GESTION DU DAEMON
YOU=$(pgrep -au $USER -f "ipfs daemon" > /dev/null && echo "$USER")
if [[ $YOU ]]; then
    echo "IPFS est déjà lancé par $YOU. Arrêt pour configuration..."
    sudo systemctl stop ipfs 2>/dev/null || killall ipfs
fi

# 3. INITIALISATION (si nécessaire)
if [[ ! -s ~/.ipfs/config ]]; then
    echo ">>> Initialisation de IPFS..."
    # On utilise $isLAN détecté par my.sh
    if [[ -n "$isLAN" ]]; then
        echo "Mode : LOWPOWER (LAN détecté)"
        ipfs init -p lowpower
    else
        echo "Mode : SERVER (WAN détecté)"
        ipfs init -p server
    fi
    # Reset des secrets pour forcer la régénération propre au premier boot
    rm -f ~/.zen/game/secret.* 2>/dev/null
else
    echo ">>> IPFS déjà initialisé. Sauvegarde config existante."
    cp ~/.ipfs/config ~/.ipfs/config.bak
fi

# 4. CONFIGURATION DE BASE (Utilisant les outils IPFS)
echo ">>> Optimisation de la couche IPFS..."
ipfs config --json Plugins.Plugins.telemetry.Config '{"Mode": "off"}'
ipfs config --json AutoConf.Enabled false
ipfs config --json DNS.Resolvers '{}'
ipfs config --json Routing.AcceleratedDHTClient true
ipfs config --json Ipns.UsePubsub true
ipfs config --json Swarm.RelayClient.Enabled true
ipfs config --json Swarm.RelayService.Enabled true

# 5. GENERATION DU SERVICE SYSTEMD
echo ">>> Installation du service systemd..."
cat <<EOF | sudo tee /etc/systemd/system/ipfs.service > /dev/null
[Unit]
Description=IPFS daemon (Astroport.ONE)
After=network.target
Requires=network.target

[Service]
Type=simple
User=$USER
RestartSec=3
Restart=always
Environment=IPFS_FD_MAX=100000
# Utilisation de PubSub pour la constellation
ExecStart=$(which ipfs) daemon --migrate --enable-pubsub-experiment --enable-namesys-pubsub
CPUAccounting=true
CPUQuota=60%

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable ipfs

# 6. CONFIGURATION AVANCÉE (via ipfs_config.sh)
# On délègue le peering dynamique et le réglage DHT à ipfs_config.sh
if [[ -x "$MY_PATH/ipfs_config.sh" ]]; then
    bash "$MY_PATH/ipfs_config.sh"
else
    echo "⚠️  ATTENTION: ipfs_config.sh absent. La constellation ne sera pas raccordée."
fi

# 7. OPTIMISATION DES LIMITES SYSTEME
if ! grep -q "$USER.*nofile.*100000" /etc/security/limits.conf; then
    echo ">>> Augmentation des limites de fichiers ouverts..."
    echo "$USER soft nofile 100000" | sudo tee -a /etc/security/limits.conf
    echo "$USER hard nofile 100000" | sudo tee -a /etc/security/limits.conf
fi

echo "✅ IPFS Setup terminé."

}