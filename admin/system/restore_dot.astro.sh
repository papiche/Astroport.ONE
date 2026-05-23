#!/bin/bash

# Script de restauration de l'environnement Python .astro pour Astroport.ONE
# Basé sur la configuration de install.sh

echo "#########################################################"
echo "🚀 RESTAURATION DE L'ENVIRONNEMENT PYTHON .astro"
echo "#########################################################"

# 1. Nettoyage de l'ancien environnement
if [ -d "$HOME/.astro" ]; then
    echo "⚠️ Suppression de l'ancien dossier ~/.astro..."
    rm -rf "$HOME/.astro"
fi

# 2. Création du venv
echo "⏳ Création du nouvel environnement virtuel dans ~/.astro..."
python3 -m venv "$HOME/.astro"

if [ ! -s "$HOME/.astro/bin/activate" ]; then
    echo "❌ Erreur : Échec de la création du venv (python3-venv est-il installé ?)"
    exit 1
fi

# 3. Mise à jour de pip dans le venv
echo "🆙 Mise à jour de pip..."
"$HOME/.astro/bin/pip" install -U pip

# 4. Installation des paquets pip listés dans install.sh
PACKAGES=(
    pip python-dotenv scrypt setuptools wheel termcolor amzqr ollama 
    requests geohash beautifulsoup4 cryptography jwcrypto secp256k1 
    gql base58 pybase64 google pynacl python-gnupg pynentry paho-mqtt 
    aiohttp ipfshttpclient bitcoin monero ecdsa pynostr bech32 
    matplotlib readability-lxml duniterpy cachetools pydantic-settings 
    robohash substrate-interface websocket websockets fastapi aiofiles jinja2 
    python-multipart python-magic uvicorn python-telegram-bot imap_tools
)

echo "📦 Installation des dépendances Python..."
for i in "${PACKAGES[@]}"; do
    echo ">>> Installation de $i..."
    "$HOME/.astro/bin/pip" install -U "$i"
done

# 5. Cas particulier : Playwright (pour les captures d'écran)
echo "🎬 Installation de Playwright et Chromium..."
"$HOME/.astro/bin/pip" install -U playwright
"$HOME/.astro/bin/python" -m playwright install chromium

# 6. Finalisation
echo "#########################################################"
echo "✅ RESTAURATION TERMINÉE"
echo "L'environnement ~/.astro est prêt."
echo "Pour l'activer manuellement : source ~/.astro/bin/activate"
echo "#########################################################"