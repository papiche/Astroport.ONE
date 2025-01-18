#!/bin/bash

# Couleurs pour la sortie
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # Pas de couleur

if command -v nostr-commander-rs &> /dev/null; then
    echo -e "${GREEN}nostr-commander-rs est déjà installé !${NC}"
    exit 0
fi
echo -e "${GREEN}Installation de nostr-commander-rs${NC}"

# Étape 1 : Vérifier que Rust est installé
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Rust n'est pas installé. Installation de Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
else
    echo -e "${GREEN}Rust est déjà installé.${NC}"
fi

# Étape 2 : Vérifier si Git est installé
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git n'est pas installé. Veuillez l'installer manuellement.${NC}"
    exit 1
fi

# Étape 3 : Cloner le dépôt nostr-commander-rs
REPO_URL="https://github.com/8go/nostr-commander-rs"
INSTALL_DIR="$HOME/.zen/nostr-commander-rs"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}Le dépôt existe déjà dans ${INSTALL_DIR}. Mise à jour...${NC}"
    cd "$INSTALL_DIR" && git pull
else
    echo -e "${GREEN}Clonage du dépôt nostr-commander-rs...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Étape 4 : Construire le projet
cd "$INSTALL_DIR"
echo -e "${GREEN}Construction de nostr-commander-rs...${NC}"
cargo build --release

# Étape 5 : Ajouter l'exécutable au PATH
EXECUTABLE_PATH="$INSTALL_DIR/target/release/nostr-commander-rs"
if [ -f "$EXECUTABLE_PATH" ]; then
    echo -e "${GREEN}Le binaire nostr-commander a été construit avec succès.${NC}"
    echo -e "${GREEN}Ajout au PATH (via ~/.bashrc)...${NC}"
    if ! grep -q "$INSTALL_DIR/target/release" "$HOME/.bashrc"; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR/target/release\"" >> "$HOME/.bashrc"
        echo -e "${GREEN}Redémarrez votre terminal ou exécutez 'source ~/.bashrc' pour activer.${NC}"
    else
        echo -e "${GREEN}Le chemin est déjà dans ~/.bashrc.${NC}"
    fi
else
    echo -e "${RED}Erreur : le binaire nostr-commander-rs n'a pas été construit correctement.${NC}"
    exit 1
fi

# Étape 6 : Vérification de l'installation
if command -v nostr-commander-rs &> /dev/null; then
    echo -e "${GREEN}nostr-commander-rs a été installé avec succès !${NC}"
else
    echo -e "${RED}Vous devrez peut-être ajouter le chemin suivant manuellement à votre PATH :${NC}"
    echo "$INSTALL_DIR/target/release"
fi
