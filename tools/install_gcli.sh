#!/bin/bash
################################################################################
# install_gcli.sh — Install/upgrade gcli from source (Astroport fork)
# Called by 20h12.process.sh for auto-migration of existing stations
# Can also be run standalone: ~/.zen/Astroport.ONE/tools/install_gcli.sh
#
# Compile depuis ~/workspace/AAA/gcli-v2s (branche nostr) si disponible,
# sinon fallback sur le .deb officiel depuis GitLab CI.
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

mkdir -p "$HOME/.local/bin"

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
    log "Clonage de gcli-v2s (branche nostr)..."
    git clone -b nostr --depth 1 https://git.duniter.org/clients/rust/gcli-v2s.git "$GCLI_SRC" 2>&1 | tail -3
fi

if [[ -d "$GCLI_SRC" && -f "$GCLI_SRC/Cargo.toml" ]]; then
    log "Sources gcli trouvées dans $GCLI_SRC"

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
        RUST_VER=$(rustc --version 2>/dev/null)
        log "Rust: $RUST_VER"

        # Compiler en release
        log "Compilation gcli (release) depuis branche nostr..."
        cargo build --release 2>&1 | tail -5
        RC=$?

        if [[ $RC -eq 0 && -x "$GCLI_SRC/target/release/gcli" ]]; then
            cp "$GCLI_SRC/target/release/gcli" "$GCLI_BIN"
            chmod +x "$GCLI_BIN"
            log "gcli compilé et installé: $($GCLI_BIN --version 2>/dev/null)"
        else
            loge "Compilation échouée (exit $RC)"
        fi
    else
        loge "cargo introuvable après tentative d'installation rustup"
    fi
else
    loge "Impossible de trouver ou cloner les sources gcli"
    exit 1
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
