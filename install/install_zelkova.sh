#!/bin/bash
############################################################ install_zelkova.sh
# TODO try & debug
# Déploie l'application Ẑelkova (PWA Flutter + page de landing)
# sur une station Astroport.ONE.
#
# Usage :
#   bash install_zelkova.sh [DOMAIN] [UPASSPORT_URL]
#
# Exemples :
#   bash install_zelkova.sh copylaradio.com https://u.copylaradio.com
#   bash install_zelkova.sh astroport.one   https://u.astroport.one
#
# Ce script :
#   1. Installe Flutter SDK si absent
#   2. Clone/pull le repo Zelkova
#   3. Configure .env depuis les variables de la station
#   4. Build la PWA Flutter (flutter build web --release)
#   5. Déploie dans ~/.zen/zelkova/web/
#   6. Configure le proxy NPM :  zelkova.DOMAIN → port local
#   7. Déploie la page de landing sur astroport.one (index.html)
#
# License: AGPL-3.0
################################################################################
set -euo pipefail

MY_PATH="$(dirname "$(realpath "$0")")"
ASTROPORT_PATH="${MY_PATH}/.."

# ─── Paramètres ──────────────────────────────────────────────
DOMAIN="${1:-${myDOMAIN:-copylaradio.com}}"
UPASSPORT_URL="${2:-https://u.${DOMAIN}}"
ZELKOVA_REPO="${ZELKOVA_REPO:-https://github.com/papiche/zelkova.git}"
ZELKOVA_DIR="${HOME}/.zen/zelkova"
ZELKOVA_WEB_PORT="${ZELKOVA_WEB_PORT:-8765}"

# ─── Couleurs ─────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${GREEN}✅ $*${NC}"; }
info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $*${NC}"; }
err()  { echo -e "${RED}❌ $*${NC}" >&2; }

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        🌳 INSTALLATION ẐELKOVA PWA                  ║${NC}"
echo -e "${CYAN}║        Portefeuille ẐEN MULTIPASS UPlanet            ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
info "Domaine cible     : ${DOMAIN}"
info "UPassport URL     : ${UPASSPORT_URL}"
info "Répertoire        : ${ZELKOVA_DIR}"
info "Port local        : ${ZELKOVA_WEB_PORT}"
echo ""

# ─── 1. Flutter SDK ──────────────────────────────────────────
if ! command -v flutter &>/dev/null; then
    info "Flutter SDK absent — installation..."
    if [[ -x "${ASTROPORT_PATH}/install/install_flutter.sh" ]]; then
        bash "${ASTROPORT_PATH}/install/install_flutter.sh"
        export PATH="${HOME}/.flutter/bin:${PATH}"
    else
        err "install_flutter.sh introuvable. Installez Flutter manuellement."
        err "  https://docs.flutter.dev/get-started/install/linux"
        exit 1
    fi
fi
log "Flutter $(flutter --version 2>/dev/null | head -1)"

# ─── 2. Clone / pull Zelkova ─────────────────────────────────
if [[ -d "${ZELKOVA_DIR}/.git" ]]; then
    info "Mise à jour du dépôt Zelkova..."
    git -C "${ZELKOVA_DIR}" pull --ff-only 2>/dev/null \
        && log "Zelkova mis à jour" \
        || warn "Mise à jour impossible (changements locaux ?)"
else
    info "Clonage de Zelkova..."
    git clone --depth 1 "${ZELKOVA_REPO}" "${ZELKOVA_DIR}" \
        && log "Zelkova cloné dans ${ZELKOVA_DIR}"
fi

# ─── 3. Configurer .env ──────────────────────────────────────
ZELKOVA_ENV="${ZELKOVA_DIR}/.env"
if [[ ! -f "${ZELKOVA_ENV}" ]]; then
    info "Création du fichier .env Zelkova..."
    cp "${ZELKOVA_DIR}/dot.env.sample" "${ZELKOVA_ENV}" 2>/dev/null \
        || cp "${ZELKOVA_DIR}/.env.sample" "${ZELKOVA_ENV}" 2>/dev/null \
        || true
fi

# Injecter les valeurs de la station courante
SOURCE_ENV="${ASTROPORT_PATH}/.env"
if [[ -f "${SOURCE_ENV}" ]]; then
    # Récupérer les variables Duniter/IPFS de la station
    for VAR in GENESIS_HASH ENDPOINTS DUNITER_INDEXER_NODES DATAPOD_ENDPOINTS IPFS_GATEWAYS CESIUM_PLUS_NODES; do
        VAL=$(grep "^${VAR}=" "${SOURCE_ENV}" 2>/dev/null | cut -d= -f2- | tr -d '"')
        if [[ -n "${VAL}" ]]; then
            sed -i "s|^${VAR}=.*|${VAR}=${VAL}|" "${ZELKOVA_ENV}" 2>/dev/null || true
        fi
    done
fi
# Mettre à jour l'URL UPassport et le relay NOSTR
sed -i "s|^UPASSPORT_URL=.*|UPASSPORT_URL=${UPASSPORT_URL}|" "${ZELKOVA_ENV}"
sed -i "s|^NOSTR_RELAY=.*|NOSTR_RELAY=wss://relay.${DOMAIN}|" "${ZELKOVA_ENV}"
log ".env Zelkova configuré"

# ─── 4. Build Flutter Web ───────────────────────────────────
info "Build Zelkova PWA (flutter build web --release)..."
cd "${ZELKOVA_DIR}"
flutter pub get 2>/dev/null
flutter build web --release --web-renderer html 2>/dev/null \
    && log "PWA Zelkova buildée avec succès" \
    || { err "Build Flutter échoué. Vérifiez les erreurs ci-dessus."; exit 1; }

# ─── 5. Déployer la PWA ─────────────────────────────────────
WWW_DIR="${ZELKOVA_DIR}/www"
mkdir -p "${WWW_DIR}"
cp -r "${ZELKOVA_DIR}/build/web/." "${WWW_DIR}/"
log "PWA déployée dans ${WWW_DIR}"

# Copier aussi la page de landing (si présente)
if [[ -f "${ZELKOVA_DIR}/landing/index.html" ]]; then
    mkdir -p "${WWW_DIR}/landing"
    cp "${ZELKOVA_DIR}/landing/"* "${WWW_DIR}/landing/" 2>/dev/null || true
    log "Page de landing copiée dans ${WWW_DIR}/landing/"
fi

# ─── 6. Serveur web simple (Python) ou Nginx statique ───────
WEB_SERVICE="${HOME}/.zen/zelkova/zelkova_web.service"

# Stopper le service précédent si existant
systemctl --user stop zelkova-web 2>/dev/null || true

# Créer un service systemd user pour servir la PWA
mkdir -p "${HOME}/.config/systemd/user"
cat > "${HOME}/.config/systemd/user/zelkova-web.service" << EOF
[Unit]
Description=Ẑelkova PWA Static Server
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${WWW_DIR}
ExecStart=$(which python3) -m http.server ${ZELKOVA_WEB_PORT} --bind 127.0.0.1
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable zelkova-web
systemctl --user restart zelkova-web
log "Service zelkova-web démarré sur http://127.0.0.1:${ZELKOVA_WEB_PORT}"

# ─── 7. Proxy NPM : zelkova.DOMAIN ──────────────────────────
NPM_SETUP="${ASTROPORT_PATH}/install/setup/setup_npm.sh"
if [[ -x "${NPM_SETUP}" ]]; then
    info "Configuration du proxy NPM : zelkova.${DOMAIN} → :${ZELKOVA_WEB_PORT}"
    ZELKOVA_VHOST="zelkova.${DOMAIN}" \
    ZELKOVA_PORT="${ZELKOVA_WEB_PORT}" \
    bash "${NPM_SETUP}" --zelkova 2>/dev/null \
        && log "Proxy NPM zelkova.${DOMAIN} configuré" \
        || warn "Proxy NPM non configuré — ajoutez manuellement dans NPM admin"
else
    warn "setup_npm.sh introuvable. Configurez manuellement dans NPM :"
    echo "    Forward Host : 127.0.0.1"
    echo "    Forward Port : ${ZELKOVA_WEB_PORT}"
    echo "    Domain       : zelkova.${DOMAIN}"
fi

# ─── Résumé ──────────────────────────────────────────────────
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              ẐELKOVA DÉPLOYÉ ✅                     ║${NC}"
echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  PWA        : https://zelkova.${DOMAIN}             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Landing    : https://${DOMAIN}                       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Local      : http://127.0.0.1:${ZELKOVA_WEB_PORT}              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  Install    : ${WWW_DIR}               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  🔑 Pour le feedback /api/feedback, configurez :    ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}     ~/.zen/UPassport/.env → GITLAB_TOKEN=glpat-... ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""
