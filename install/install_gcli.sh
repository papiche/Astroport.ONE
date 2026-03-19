#!/bin/bash
################################################################################
# install_gcli.sh — Install/upgrade g1cli (gcli) for Astroport.ONE
# Called by 20h12.process.sh for auto-migration of existing stations
# Can also be run standalone: ~/.zen/Astroport.ONE/install/install_gcli.sh
#
# Strategy:
#   1. Compile from source (branche nostr) — preferred
#   2. Download pre-built binary from GitLab release — fallback
#
# Author: Fred (support@qo-op.com)
# License: AGPL-3.0
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

LOG_TAG="[install_gcli]"
log()  { echo "$LOG_TAG $*"; }
loge() { echo "$LOG_TAG ERROR: $*" >&2; }

GCLI_SRC="${GCLI_SRC:-$HOME/workspace/AAA/gcli-v2s}"
GCLI_BIN="$HOME/.local/bin/gcli"
# Fallback binaire pré-compilé : RC2 (RC3 pas encore uploadé — compilation source préférée)
# Mettre à jour ces URLs dès que les binaires RC3 seront disponibles sur GitLab.
GCLI_VERSION="0.8.0-g1-RC2"
GCLI_URL_AMD64="https://git.duniter.org/-/project/604/uploads/bb4d3ee2030db6d09d954c469870e1ef/g1cli-v0.8.0-g1-RC2-linux-amd64.tar.gz"
GCLI_URL_ARM64="https://git.duniter.org/-/project/604/uploads/3d2ea125ba58e71cf5919a33c8329f24/g1cli-v0.8.0-g1-RC2-linux-arm64.tar.gz"

mkdir -p "$HOME/.local/bin"

########################################################################
## Detect architecture for binary download
########################################################################
detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *)       echo "" ;;
    esac
}

########################################################################
## Download pre-built binary from GitLab release
########################################################################
download_prebuilt_binary() {
    local ARCH
    ARCH=$(detect_arch)
    if [[ -z "$ARCH" ]]; then
        loge "Architecture $(uname -m) non supportée pour le téléchargement"
        return 1
    fi

    local DOWNLOAD_URL
    case "$ARCH" in
        amd64) DOWNLOAD_URL="$GCLI_URL_AMD64" ;;
        arm64) DOWNLOAD_URL="$GCLI_URL_ARM64" ;;
    esac
    local FILENAME="g1cli-v${GCLI_VERSION}-linux-${ARCH}.tar.gz"
    local TMP_DIR
    TMP_DIR=$(mktemp -d)

    log "Téléchargement de g1cli ${TAG} (${ARCH})..."
    log "URL: ${DOWNLOAD_URL}"

    if curl -fSL --connect-timeout 30 -o "${TMP_DIR}/${FILENAME}" "${DOWNLOAD_URL}" 2>&1; then
        tar xzf "${TMP_DIR}/${FILENAME}" -C "${TMP_DIR}"
        if [[ -x "${TMP_DIR}/g1cli" ]]; then
            # Vérifier que le binaire fonctionne (compatibilité glibc)
            if ! "${TMP_DIR}/g1cli" --version &>/dev/null; then
                loge "Binaire incompatible (glibc trop ancien ?): $(ldd "${TMP_DIR}/g1cli" 2>&1 | grep 'not found' | head -3)"
                rm -rf "$TMP_DIR"
                return 1
            fi
            cp "${TMP_DIR}/g1cli" "$GCLI_BIN"
            chmod +x "$GCLI_BIN"
            log "g1cli téléchargé et installé: $($GCLI_BIN --version 2>/dev/null)"
        else
            loge "Binaire g1cli introuvable dans l'archive"
            rm -rf "$TMP_DIR"
            return 1
        fi
    else
        loge "Échec du téléchargement depuis ${DOWNLOAD_URL}"
        rm -rf "$TMP_DIR"
        return 1
    fi

    rm -rf "$TMP_DIR"
    return 0
}

########################################################################
## 1. Supprimer l'ancien .deb s'il est installé
########################################################################
if dpkg -l g1cli 2>/dev/null | grep -q "^ii"; then
    log "Suppression de l'ancien paquet g1cli (.deb)..."
    sudo dpkg -r g1cli 2>/dev/null && log "g1cli .deb supprimé"
    # Supprimer le lien symbolique vers /usr/bin/g1cli
    [[ -L "$GCLI_BIN" ]] && rm -f "$GCLI_BIN"
fi

########################################################################
## 2. COMPILATION depuis les sources (méthode préférée)
########################################################################
########################################################################
## 2a. CLONE si pas de sources locales
########################################################################
if [[ ! -d "$GCLI_SRC" ]]; then
    log "Clonage de g1cli (branche nostr)..."
    git clone -b nostr --depth 1 https://git.duniter.org/clients/rust/g1cli.git "$GCLI_SRC" 2>&1 | tail -3
fi

if [[ -d "$GCLI_SRC" && -f "$GCLI_SRC/Cargo.toml" ]]; then
    log "Sources gcli trouvées dans $GCLI_SRC"

    # Migration: si le clone vient de gcli-v2s.git (ancien repo), le supprimer et recloner
    # depuis g1cli.git pour avoir un historique propre (évite les commits RC2 fantômes)
    G1CLI_URL="https://git.duniter.org/clients/rust/g1cli.git"
    CURRENT_ORIGIN=$(git -C "$GCLI_SRC" remote get-url origin 2>/dev/null || true)
    if [[ "$CURRENT_ORIGIN" == *"gcli-v2s"* ]]; then
        log "Ancien clone gcli-v2s détecté → suppression et reclonage depuis g1cli.git"
        rm -rf "$GCLI_SRC"
        git clone -b nostr --depth 1 "$G1CLI_URL" "$GCLI_SRC" 2>&1 | tail -3
    fi

    # S'assurer qu'on est sur la branche nostr
    cd "$GCLI_SRC"

    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
    if [[ "$CURRENT_BRANCH" != "nostr" ]]; then
        log "Checkout branche nostr..."
        git fetch origin nostr 2>/dev/null
        git checkout nostr 2>/dev/null || git checkout -b nostr origin/nostr 2>/dev/null
    fi
    git pull origin nostr 2>/dev/null

    # Vérifier/installer rustup + cargo
    if ! command -v cargo &>/dev/null; then
        if [[ -f "$HOME/.cargo/env" ]]; then
            source "$HOME/.cargo/env"
        fi
    fi
    if ! command -v cargo &>/dev/null; then
        log "Installation de rustup (toolchain stable)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --default-toolchain stable 2>&1 | tail -3
        source "$HOME/.cargo/env"
    fi

    if command -v cargo &>/dev/null; then
        RUST_VER=$(rustc --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
        RUST_MIN="1.94.0"
        log "Rust: $RUST_VER (minimum requis: $RUST_MIN)"

        # Vérifier la version minimale de Rust
        if printf '%s\n' "$RUST_MIN" "$RUST_VER" | sort -V | head -1 | grep -qv "$RUST_MIN"; then
            log "Rust $RUST_VER trop ancien, mise à jour vers stable..."
            # S'assurer que rustup est dans le PATH
            [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
            if ! command -v rustup &>/dev/null; then
                log "rustup introuvable, installation..."
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
                    | sh -s -- -y --default-toolchain stable 2>&1 | tail -3
                source "$HOME/.cargo/env"
            else
                rustup update stable 2>&1 | tail -3
            fi
            # Utiliser le cargo/rustc de rustup (pas celui du système)
            [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
            export PATH="$HOME/.cargo/bin:$PATH"
            RUST_VER=$(rustc --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+')
            log "Rust mis à jour: $RUST_VER"
        fi

        # Vérifier si le binaire en cache correspond à la version dans Cargo.toml
        # grep -oP extrait uniquement la valeur entre guillemets (ex: 0.8.0-g1-RC3)
        CARGO_VER=$(grep '^version' "$GCLI_SRC/Cargo.toml" | head -1 | grep -oP '(?<=")[^"]+(?=")' || true)
        BIN_CACHED="$GCLI_SRC/target/release/g1cli"
        if [[ -x "$BIN_CACHED" ]]; then
            BIN_VER=$("$BIN_CACHED" --version 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+-[a-zA-Z0-9-]+' || true)
            log "Binaire en cache: $BIN_VER | Cargo.toml: $CARGO_VER"
            if [[ -n "$CARGO_VER" && -n "$BIN_VER" && "$CARGO_VER" != "$BIN_VER" ]]; then
                log "Version différente → cargo clean -p g1cli pour forcer recompilation"
                cargo clean -p g1cli 2>/dev/null || true
            fi
        fi

        # Compiler en release avec la feature g1 (réseau Ğ1 mainnet)
        # La feature g1 est déjà la default dans Cargo.toml [features] default=["g1"]
        # mais on la spécifie explicitement pour garantir la robustesse si le défaut change
        log "Compilation gcli (release, --features g1) depuis branche nostr..."
        cargo build --release --features g1 2>&1 | tail -5
        RC=$?

        if [[ $RC -eq 0 && -x "$GCLI_SRC/target/release/g1cli" ]]; then
            cp "$GCLI_SRC/target/release/g1cli" "$GCLI_BIN"
            chmod +x "$GCLI_BIN"
            log "gcli compilé et installé: $($GCLI_BIN --version 2>/dev/null)"
        else
            loge "Compilation échouée (exit $RC)"
            log "Tentative de téléchargement du binaire pré-compilé..."
            download_prebuilt_binary
        fi
    else
        loge "cargo introuvable après tentative d'installation rustup"
        log "Tentative de téléchargement du binaire pré-compilé..."
        download_prebuilt_binary
    fi
else
    log "Sources non disponibles, téléchargement du binaire pré-compilé..."
    download_prebuilt_binary
fi

########################################################################
## 4. CLEANUP legacy jaklis
########################################################################
if [[ -f ~/.local/bin/jaklis ]] || command -v jaklis &>/dev/null; then
    log "Suppression de jaklis (legacy)..."
    rm -f ~/.local/bin/jaklis
    sudo rm -f /usr/local/bin/jaklis
fi

########################################################################
## 5. CLEANUP legacy silkaj
########################################################################
if [[ -f ~/.local/bin/silkaj ]] || command -v silkaj &>/dev/null; then
    log "Suppression de silkaj (legacy)..."
    rm -f ~/.local/bin/silkaj
    pip3 uninstall -y silkaj 2>/dev/null
    [[ -d ~/.zen/workspace/silkaj ]] && rm -rf ~/.zen/workspace/silkaj \
        && log "Supprimé ~/.zen/workspace/silkaj"
fi

log "Installation terminée: gcli $(gcli --version 2>/dev/null | head -1)"
exit 0
