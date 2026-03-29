#!/bin/bash
########################################################################
# webtop-init.sh — Astroport.ONE initialization for linuxserver webtop
#
# Placé dans /custom-cont-init.d/99-astroport-init.sh par docker-compose
# S'exécute à CHAQUE démarrage du conteneur (géré par s6-overlay)
#
# Convention linuxserver : script exécuté en ROOT avant le bureau
# L'utilisateur "abc" (UID=PUID) est le propriétaire du home /config
#
# NOTE : systemd n'est pas disponible dans Docker.
#        Les services Astroport sont démarrés via des scripts directs.
########################################################################

set -e

## ── Variables ────────────────────────────────────────────────────────
HOME_DIR="/config"                      # Home linuxserver webtop
ASTRO_DIR="${HOME_DIR}/.zen/Astroport.ONE"
INSTALL_FLAG="${HOME_DIR}/.astroport_installed"
LOG_INIT="${HOME_DIR}/.zen/webtop-init.log"
WEBTOP_USER="abc"                       # Utilisateur linuxserver par défaut

## Variables UPlanet transmises depuis l'environnement docker
INSTALL_PROFILE="${INSTALL_PROFILE:-}"
ASTRO_DOMAIN="${ASTRO_DOMAIN:-copylaradio.com}"
CAPTAIN_EMAIL="${CAPTAIN_EMAIL:-}"
IPFS_SWARM_KEY="${IPFS_SWARM_KEY:-}"

## ── Logging ──────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LOG_INIT")"
exec > >(tee -a "$LOG_INIT") 2>&1
echo "========================================"
echo "$(date -u) — Astroport.ONE webtop init"
echo "  USER      : $WEBTOP_USER (home: $HOME_DIR)"
echo "  DOMAIN    : $ASTRO_DOMAIN"
echo "  EMAIL     : ${CAPTAIN_EMAIL:-auto}"
echo "  PROFILE   : ${INSTALL_PROFILE:-standard}"
echo "  INSTALLED : $(test -f "$INSTALL_FLAG" && echo YES || echo NO)"
echo "========================================"

## ── Première installation ────────────────────────────────────────────
if [[ ! -f "$INSTALL_FLAG" ]]; then
    echo ">>> PREMIER DÉMARRAGE — Installation Astroport.ONE..."

    ## S'assurer que git est disponible (image ubuntu-xfce)
    apt-get update -qq && apt-get install -y git curl wget sudo 2>/dev/null

    ## Ajouter l'utilisateur abc au groupe sudo sans mot de passe
    echo "${WEBTOP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${WEBTOP_USER}
    chmod 440 /etc/sudoers.d/${WEBTOP_USER}
    usermod -aG docker ${WEBTOP_USER} 2>/dev/null || true  ## Docker socket access

    ## Cloner Astroport.ONE si absent
    mkdir -p "${HOME_DIR}/.zen/workspace"
    if [[ ! -d "$ASTRO_DIR" ]]; then
        echo ">>> Clonage Astroport.ONE..."
        su - "${WEBTOP_USER}" -c "
            cd ${HOME_DIR}/.zen
            git clone --depth 1 https://github.com/papiche/Astroport.ONE.git 2>&1
        "
    fi

    ## Cloner UPlanet workspace
    if [[ ! -d "${HOME_DIR}/.zen/workspace/UPlanet" ]]; then
        su - "${WEBTOP_USER}" -c "
            cd ${HOME_DIR}/.zen/workspace
            git clone --depth 1 https://github.com/papiche/UPlanet 2>&1
        "
    fi

    ## Exporter les variables pour install.sh
    export HOME="${HOME_DIR}"
    export USER="${WEBTOP_USER}"

    ## Lancer install.sh en mode non-interactif (en tant que abc)
    ## NOTE : dans webtop, on n'utilise PAS systemd — les services démarrent
    ## via start.sh après l'installation.
    su - "${WEBTOP_USER}" -c "
        export HOME=${HOME_DIR}
        export CAPTAIN_EMAIL='${CAPTAIN_EMAIL}'
        export NODE_DOMAIN='${ASTRO_DOMAIN}'
        export INSTALL_PROFILE='${INSTALL_PROFILE}'
        ## Lancer install.sh de manière non-interactive
        bash ${ASTRO_DIR}/install.sh \
            '${CAPTAIN_EMAIL}' \
            '${ASTRO_DOMAIN}' \
            '' \
            '${INSTALL_PROFILE}' 2>&1
    " || echo "⚠️  install.sh terminé avec des avertissements (voir $LOG_INIT)"

    ## Configurer swarm.key si fourni (mode ẐEN)
    if [[ -n "$IPFS_SWARM_KEY" ]]; then
        echo ">>> Configuration swarm.key (UPlanet ẐEN)..."
        SWARM_KEY_FILE="${HOME_DIR}/.ipfs/swarm.key"
        mkdir -p "${HOME_DIR}/.ipfs"
        echo "/key/swarm/psk/1.0.0/" > "$SWARM_KEY_FILE"
        echo "/base16/"              >> "$SWARM_KEY_FILE"
        echo "${IPFS_SWARM_KEY}"    >> "$SWARM_KEY_FILE"
        chown "${WEBTOP_USER}:${WEBTOP_USER}" "$SWARM_KEY_FILE"
        chmod 600 "$SWARM_KEY_FILE"
        echo "✅ swarm.key configuré → mode UPlanet ẐEN"
    else
        echo "ℹ️  Pas de swarm.key → mode UPlanet ORIGIN (sandbox)"
    fi

    ## Raccourcis Bureau (XFCE)
    _create_shortcut() {
        local name="$1" exec="$2" icon="$3"
        cat > "${HOME_DIR}/Desktop/${name}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${name}
Exec=${exec}
Icon=${icon:-utilities-terminal}
Terminal=false
EOF
        chmod +x "${HOME_DIR}/Desktop/${name}.desktop"
        chown "${WEBTOP_USER}:${WEBTOP_USER}" "${HOME_DIR}/Desktop/${name}.desktop"
    }

    mkdir -p "${HOME_DIR}/Desktop"
    _create_shortcut "Astroport Dashboard" \
        "xdg-open http://localhost:12345" "applications-internet"
    _create_shortcut "UPassport" \
        "xdg-open http://localhost:54321" "system-users"
    _create_shortcut "IPFS Gateway" \
        "xdg-open http://localhost:8080" "folder-remote"
    _create_shortcut "Terminal" \
        "xterm" "utilities-terminal"
    _create_shortcut "NPM Admin" \
        "xdg-open http://localhost:81" "network-server"
    if [[ "${INSTALL_PROFILE}" == "nextcloud" ]]; then
        _create_shortcut "NextCloud Setup" \
            "xdg-open https://localhost:8443" "folder-cloud"
    fi
    if [[ "${INSTALL_PROFILE}" == "ai-company" ]]; then
        _create_shortcut "Paperclip AI" \
            "xdg-open http://localhost:3100" "applications-science"
        _create_shortcut "OpenWebUI AI" \
            "xdg-open http://localhost:8000" "applications-science"
    fi

    ## Marquer l'installation comme terminée
    echo "$(date -u) INSTALL_PROFILE=${INSTALL_PROFILE}" > "${INSTALL_FLAG}"
    chown "${WEBTOP_USER}:${WEBTOP_USER}" "${INSTALL_FLAG}"
    echo "✅ Installation Astroport.ONE terminée"

else
    echo ">>> Install déjà effectuée ($(cat "$INSTALL_FLAG")) — démarrage rapide"
fi

## ── Démarrage des services Astroport (à CHAQUE start) ────────────────
## systemd n'étant pas disponible, on démarre directement via start.sh
## Note : les services s'arrêtent quand le conteneur s'arrête → clean.
if [[ -x "${ASTRO_DIR}/start.sh" ]]; then
    echo ">>> Démarrage des services Astroport.ONE..."
    chown -R "${WEBTOP_USER}:${WEBTOP_USER}" "${HOME_DIR}/.zen" 2>/dev/null || true
    su - "${WEBTOP_USER}" -c "
        export HOME=${HOME_DIR}
        nohup bash ${ASTRO_DIR}/start.sh > ${HOME_DIR}/.zen/start.log 2>&1 &
    " &
    echo "✅ Services démarrés en arrière-plan (logs: ${HOME_DIR}/.zen/start.log)"
else
    echo "⚠️  ${ASTRO_DIR}/start.sh non trouvé — démarrez manuellement depuis le bureau"
fi

## ── Droits finaux ────────────────────────────────────────────────────
chown -R "${WEBTOP_USER}:${WEBTOP_USER}" "${HOME_DIR}/.zen" 2>/dev/null || true
chown -R "${WEBTOP_USER}:${WEBTOP_USER}" "${HOME_DIR}/Desktop" 2>/dev/null || true

echo "========================================"
echo "$(date -u) — Init terminé"
echo "  Accès bureau : http://VOTRE_IP:3000"
echo "  Astroport    : http://VOTRE_IP:12345"
echo "  UPassport    : http://VOTRE_IP:54321"
echo "========================================"
