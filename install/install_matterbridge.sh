#!/bin/bash
########################################################################
# install_matterbridge.sh
# Installe Matterbridge et le démon BRO Omni-Channel
########################################################################
set -e

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

echo "📥 Téléchargement de Matterbridge..."
VERSION="1.26.0"
ARCH=$(uname -m)
case $ARCH in
    x86_64) MB_ARCH="64bit" ;;
    aarch64) MB_ARCH="arm64" ;;
    armv*) MB_ARCH="armv6" ;;
    *) MB_ARCH="32bit" ;;
esac

mkdir -p ~/.local/bin
curl -L -o ~/.local/bin/matterbridge "https://github.com/42wim/matterbridge/releases/download/v${VERSION}/matterbridge-${VERSION}-linux-${MB_ARCH}"
chmod +x ~/.local/bin/matterbridge

echo "📁 Configuration des dossiers..."
mkdir -p ~/.zen/matterbridge
mkdir -p ~/.zen/Astroport.ONE/IA/connectors

# --- Fichier de configuration par défaut ---
if [ ! -f ~/.zen/matterbridge/matterbridge.toml ]; then
cat > ~/.zen/matterbridge/matterbridge.toml <<EOF
[api]
[api.local]
BindAddress="127.0.0.1:4242"
Buffer=1000
RemoteNickFormat="[{PROTOCOL}] <{NICK}> "

[api.local.out]
URL="http://127.0.0.1:4243/webhook"

# ====== EXEMPLE TELEGRAM ======
# [telegram.mon_bot]
# Token="TON_TOKEN_BOTFATHER_ICI"

[gateway]
[gateway.inout]
[[gateway.inout.inout]]
account="api.local"
channel="api"

# [[gateway.inout.inout]]
# account="telegram.mon_bot"
# channel="-100123456789" # ID du groupe, ou laisser vide pour les DMs
EOF
fi

# --- Service Matterbridge ---
cat > /tmp/matterbridge.service <<EOF
[Unit]
Description=Matterbridge
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=$HOME/.local/bin/matterbridge -conf $HOME/.zen/matterbridge/matterbridge.toml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# --- Service BRO Omni-Channel ---
cat > /tmp/bro_omni.service <<EOF
[Unit]
Description=BRO Omni-Channel Daemon (FastAPI)
After=matterbridge.service ollama.service

[Service]
Type=simple
User=$USER
Environment="PATH=$HOME/.astro/bin:$HOME/.local/bin:/usr/bin"
ExecStart=$HOME/.astro/bin/python3 $HOME/.zen/Astroport.ONE/IA/connectors/bro_matterbridge_daemon.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo mv /tmp/matterbridge.service /etc/systemd/system/
sudo mv /tmp/bro_omni.service /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable matterbridge bro_omni
# Démarrage non forcé car il nécessite de configurer les tokens (Telegram, etc.)

echo "✅ Matterbridge & BRO Omni-Channel installés !"
echo "👉 Configurez vos réseaux dans : ~/.zen/matterbridge/matterbridge.toml"
echo "   Puis lancez : sudo systemctl start matterbridge bro_omni"