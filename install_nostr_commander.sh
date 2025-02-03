#!/bin/bash
# install_nostr_commander.sh
# Couleurs pour la sortie
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m" # Pas de couleur

# Fonction pour vérifier la version de Rust
check_rust_version() {
    if command -v rustc &> /dev/null; then
        rustc_version=$(rustc --version | awk '{print $2}')
        required_version="1.70.0"
        cargo_version=$(cargo --version | sed -E 's/cargo ([0-9\.]+) .*/\1/')

        echo "Rust version: $rustc_version, Cargo version: $cargo_version"

        if [[ $(printf '%s\n' "$rustc_version" "$required_version" | sort -V | head -n 1) == "$required_version" ]]; then
            echo -e "${GREEN}Rust est installé et à la version $rustc_version (ou supérieure), Cargo est à la version $cargo_version.${NC}"
            if [[ $(printf '%s\n' "$cargo_version" "1.70.0" | sort -V | head -n 1) == "1.70.0" ]]; then
                return 0  # Rust et Cargo sont à jour
            else
                echo -e "${YELLOW}La version de Cargo est trop ancienne ($cargo_version), une mise à jour est nécessaire.${NC}"
                return 1
            fi
        else
            echo -e "${YELLOW}Rust est installé mais à la version $rustc_version, une mise à jour vers $required_version ou une version plus récente est nécessaire.${NC}"
            return 1  # Rust doit être mis à jour
        fi

    else
        echo -e "${RED}Rust n'est pas installé. Installation requise.${NC}"
        return 2 # Rust n'est pas installé
    fi
}


# Fonction pour mettre à jour rust
update_rust() {
  echo -e "${YELLOW}Mise à jour de Rust (incluant Cargo)...${NC}"
    if ! rustup update; then
        echo -e "${RED}La mise à jour de Rust a échoué. Veuillez vérifier votre connexion internet et réessayer.${NC}"
        exit 1
    fi

    source $HOME/.cargo/env

    # Vérification de la version après mise à jour
     new_rust_status=$(check_rust_version)
      if [ "$new_rust_status" -ne 0 ]; then
           echo -e "${RED}La mise à jour de Rust a échoué, veuillez réessayer manuellement.${NC}"
         exit 1
     fi
}

if command -v nostr-commander-rs &> /dev/null; then
    echo -e "${GREEN}nostr-commander-rs est déjà installé !${NC}"
    exit 0
fi

echo -e "${GREEN}Installation de nostr-commander-rs${NC}"

# Étape 0 : Vérifier que nostr-relay est installé
if command -v nostr-relay &> /dev/null; then
    echo -e "${GREEN}nostr-relay est déjà installé !${NC}"
else
    echo -e "${RED}Installation de nostr-relay ...${NC}"
    pip install nostr-relay pynostr bech32
fi


# Étape 1 : Vérifier et installer/mettre à jour Rust
rust_status=$(check_rust_version)
if [ "$rust_status" -eq 2 ]; then
  echo -e "${RED}Rust n'est pas installé. Installation de Rust...${NC}"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  source $HOME/.cargo/env
elif [ "$rust_status" -eq 1 ]; then
  update_rust
fi

# Étape 2 : Vérifier si Git est installé
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git n'est pas installé. Veuillez l'installer manuellement.${NC}"
    exit 1
fi

# Étape 3 : Cloner le dépôt nostr-commander-rs
REPO_URL="https://github.com/8go/nostr-commander-rs"
INSTALL_DIR="$HOME/.zen/workspace/nostr-commander-rs"

if [ -d "$INSTALL_DIR" ]; then
    echo -e "${GREEN}Le dépôt existe déjà dans ${INSTALL_DIR}. Mise à jour...${NC}"
    cd "$INSTALL_DIR" && git pull
else
    mkdir -p "$INSTALL_DIR"
    echo -e "${GREEN}Clonage du dépôt nostr-commander-rs...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi

# Étape 4 : Construire le projet
cd "$INSTALL_DIR"
echo -e "${GREEN}Construction de nostr-commander-rs...${NC}"
if ! cargo build --release; then
    echo -e "${RED}La construction de nostr-commander-rs a échoué. Vérifiez que Rust est à jour et que les dépendances sont correctes.${NC}"
    exit 1
fi

# Étape 5 : Ajouter l'exécutable au PATH
EXECUTABLE_PATH="$INSTALL_DIR/target/release/nostr-commander-rs"
if [ -f "$EXECUTABLE_PATH" ]; then
    echo -e "${GREEN}Le binaire nostr-commander a été construit avec succès.${NC}"
    echo -e "${GREEN}Installation dans ~/.local/bin ...${NC}"
    mv "$INSTALL_DIR/target/release/nostr-commander-rs" ~/.local/bin
else
    echo -e "${RED}Erreur : le binaire nostr-commander-rs n'a pas été construit correctement.${NC}"
    exit 1
fi

# Étape 6 : Création du fichier credentials.json
CREDENTIALS_DIR="$HOME/.local/share/nostr-commander-rs"
CREDENTIALS_FILE="$CREDENTIALS_DIR/credentials.json"

echo -e "${GREEN}Création du fichier credentials.json...${NC}"
mkdir -p "$CREDENTIALS_DIR"
cat > "$CREDENTIALS_FILE" <<EOL
{
  "secret_key_bech32": "nsec1hsmhy4d6ve325gxpgk0lzlmu4vymf49r4gq07sw5wjsezz74nrls8cryds",
  "public_key_bech32": "npub1eq0gkvwm43jc506neat4y8t4cyp4z2w846qtxexuc5syh9h5v47sptlfff",
  "relays": [
    {
      "url": "wss://relay.g1sms.fr/",
      "proxy": null
    },
    {
      "url": "wss://relay.copylaradio.com/",
      "proxy": null
    },
    {
      "url": "ws://127.0.0.1:7777/",
      "proxy": null
    }
  ],
  "metadata": {
    "name": "coucou",
    "display_name": "coucou",
    "about": "coucou",
    "picture": "http://127.0.0.1:8080/ipfs/QmbUAMgnTm4dFnH66kgmUXpBBqUMdTmfedvzuYTmgXd8s9",
    "nip05": "support@qo-op.com"
  },
  "contacts": [],
  "subscribed_pubkeys": [],
  "subscribed_authors": [],
  "subscribed_channels": []
}
EOL

echo -e "${GREEN}Fichier credentials.json créé avec succès dans ${CREDENTIALS_DIR}.${NC}"

# Étape 7 : Vérification de l'installation
if command -v nostr-commander-rs &> /dev/null; then
    echo -e "${GREEN}nostr-commander-rs a été installé avec succès !${NC}"
else
    echo -e "${RED}Vous devrez peut-être ajouter le chemin suivant manuellement à votre PATH :${NC}"
    echo "$INSTALL_DIR/target/release"
fi
