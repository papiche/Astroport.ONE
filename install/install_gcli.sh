#!/bin/bash
################################################################################
# install_gcli.sh — Install/upgrade g1cli (gcli) for Astroport.ONE
# Logic: Install ONLY if target version > current version
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

LOG_TAG="[install_gcli]"
log()  { echo "$LOG_TAG $*"; }
loge() { echo "$LOG_TAG ERROR: $*" >&2; }

GCLI_SRC="${GCLI_SRC:-$HOME/workspace/AAA/gcli-v2s}"
GCLI_BIN="$HOME/.local/bin/gcli"

# Version de référence pour le fallback binaire
GCLI_VERSION="0.8.0-g1-RC3"
GCLI_URL_AMD64="https://git.duniter.org/-/project/604/uploads/62278fb4b3c3b8191f31cd7c79d8bc56/g1cli-v0.8.0-g1-RC3-linux-amd64.tar.gz"
GCLI_URL_ARM64="https://git.duniter.org/-/project/604/uploads/72c2f4d6d0d8aa07bf019b74db3b64f4/g1cli-v0.8.0-g1-RC3-linux-arm64.tar.gz"

mkdir -p "$HOME/.local/bin"

########################################################################
## Outils de comparaison de version
########################################################################

# Extrait la version (ex: 0.8.0-g1-RC3) du binaire installé
get_current_installed_version() {
    if [[ -x "$GCLI_BIN" ]]; then
        "$GCLI_BIN" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+[^ ]*' || echo "0.0.0"
    else
        echo "0.0.0"
    fi
}

# Retourne 0 (true) si $1 est strictement supérieur à $2
version_gt() {
    [[ "$1" == "$2" ]] && return 1
    # sort -V gère les RC (ex: 0.8.0-RC2 < 0.8.0-RC3)
    [[ "$(printf '%s\n%s' "$1" "$2" | sort -V | head -n1)" == "$2" ]]
}

########################################################################
## Detect architecture
########################################################################
detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *)       echo "" ;;
    esac
}

########################################################################
## Download pre-built binary
########################################################################
download_prebuilt_binary() {
    local ARCH=$(detect_arch)
    local INSTALLED=$(get_current_installed_version)

    if ! version_gt "$GCLI_VERSION" "$INSTALLED"; then
        log "Version binaire ($GCLI_VERSION) n'est pas plus récente que l'installée ($INSTALLED). Saut."
        return 0
    fi

    if [[ -z "$ARCH" ]]; then
        loge "Architecture $(uname -m) non supportée"
        return 1
    fi

    local DOWNLOAD_URL
    [[ "$ARCH" == "amd64" ]] && DOWNLOAD_URL="$GCLI_URL_AMD64"
    [[ "$ARCH" == "arm64" ]] && DOWNLOAD_URL="$GCLI_URL_ARM64"

    local FILENAME="g1cli-v${GCLI_VERSION}-linux-${ARCH}.tar.gz"
    local TMP_DIR=$(mktemp -d)

    log "Téléchargement de g1cli $GCLI_VERSION ($ARCH)..."
    if curl -fSL --connect-timeout 30 -o "${TMP_DIR}/${FILENAME}" "${DOWNLOAD_URL}" 2>&1; then
        tar xzf "${TMP_DIR}/${FILENAME}" -C "${TMP_DIR}"
        if [[ -x "${TMP_DIR}/g1cli" ]]; then
            cp "${TMP_DIR}/g1cli" "$GCLI_BIN"
            chmod +x "$GCLI_BIN"
            log "g1cli installé via binaire: $($GCLI_BIN --version 2>/dev/null)"
        fi
    else
        loge "Échec du téléchargement."
        rm -rf "$TMP_DIR"
        return 1
    fi
    rm -rf "$TMP_DIR"
}

########################################################################
## MAIN
########################################################################

CURRENT_INSTALLED=$(get_current_installed_version)
log "Version actuelle installée : $CURRENT_INSTALLED"

# 1. Nettoyage .deb (si présent, on le vire car on passe en local bin)
if dpkg -l g1cli 2>/dev/null | grep -q "^ii"; then
    log "Migration : Suppression de l'ancien paquet .deb..."
    sudo apt remove g1cli 2>/dev/null
    [[ -L "$GCLI_BIN" ]] && rm -f "$GCLI_BIN"
fi

# 2. Gestion des sources
G1CLI_HTTPS="https://git.duniter.org/clients/rust/g1cli.git"
if [[ ! -d "$GCLI_SRC" ]]; then
    log "Clonage de g1cli (branche nostr)..."
    git clone -b nostr --depth 1 "$G1CLI_HTTPS" "$GCLI_SRC" 2>&1 | tail -3
fi

if [[ -d "$GCLI_SRC" && -f "$GCLI_SRC/Cargo.toml" ]]; then
    # Analyse de la version dans les sources
    SRC_VER=$(grep '^version' "$GCLI_SRC/Cargo.toml" | head -1 | grep -oP '(?<=")[^"]+(?=")' || true)
    
    # Si les sources sont trop vieilles (ex: RC2 alors qu'on veut RC3 ou +)
    if [[ "$SRC_VER" == *"RC2"* ]]; then
        log "Sources obsolètes ($SRC_VER), mise à jour du dépôt..."
        rm -rf "$GCLI_SRC"
        git clone -b nostr --depth 1 "$G1CLI_HTTPS" "$GCLI_SRC"
        SRC_VER=$(grep '^version' "$GCLI_SRC/Cargo.toml" | head -1 | grep -oP '(?<=")[^"]+(?=")' || true)
    fi

    # --- LE CHECK CRUCIAL ---
    if ! version_gt "$SRC_VER" "$CURRENT_INSTALLED"; then
        log "Version des sources ($SRC_VER) <= version installée ($CURRENT_INSTALLED). Pas de compilation nécessaire."
    else
        log "Mise à jour détectée : $CURRENT_INSTALLED -> $SRC_VER. Lancement de la compilation..."
        
        # S'assurer d'être sur la bonne branche
        cd "$GCLI_SRC"
        git fetch origin nostr 2>/dev/null
        git checkout nostr 2>/dev/null || git checkout -b nostr origin/nostr 2>/dev/null
        git pull origin nostr 2>/dev/null

        # Rustup check
        if ! command -v cargo &>/dev/null; then
            [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
        fi
        if ! command -v cargo &>/dev/null; then
            log "Installation de Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
        fi

        # Compilation
        log "Cargo build en cours..."
        if cargo build --release --features g1; then
            cp "$GCLI_SRC/target/release/g1cli" "$GCLI_BIN"
            chmod +x "$GCLI_BIN"
            log "Succès : gcli mis à jour en version $(get_current_installed_version)"
            exit 0
        else
            loge "Échec compilation. Tentative fallback binaire."
            download_prebuilt_binary
        fi
    fi
else
    log "Pas de sources. Tentative fallback binaire."
    download_prebuilt_binary
fi

log "Fin de traitement. Version finale : $(get_current_installed_version)"
exit 0