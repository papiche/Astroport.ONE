#!/bin/bash
########################################################################
# install_webtop.sh — Bureau distant via linuxserver/webtop (KasmVNC)
#
# Mode simple  : démarre un bureau partagé sur le port 3000
# Mode MULTIPASS: --user email@example.com
#                 → bureau dédié, réservé aux membres U.SOCIETY
#                 → données dans ~/.zen/webtop/$email/
#                 → port alloué automatiquement (3000, 3010, 3020…)
#
# Conteneur : lscr.io/linuxserver/webtop:ubuntu-xfce
# USER dans le conteneur : abc (UID 911), mais PUID/PGID surchargent
#   vers l'utilisateur courant. Home = /config (= DATA_DIR/config/).
#
# Usage:
#   install_webtop.sh                         # bureau partagé port 3000
#   install_webtop.sh --user email@ex.com     # bureau U.SOCIETY dédié
#   install_webtop.sh --purge [--user email]  # suppression
########################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

GREEN='\033[1;32m'; YELLOW='\033[1;33m'; RED='\033[1;31m'
BOLD='\033[1m'; NC='\033[0m'

IMAGE="lscr.io/linuxserver/webtop:ubuntu-xfce"
REGISTRY="$HOME/.zen/webtop/.registry"  # format: email=port

## ── Parsing arguments ────────────────────────────────────────────────────────
MULTIPASS_EMAIL=""
PURGE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)   shift; MULTIPASS_EMAIL="${1:-}" ;;
        --purge)  PURGE=true ;;
        *)        ;;
    esac
    shift
done

## ── Mode : MULTIPASS dédié ou bureau partagé ─────────────────────────────────
if [[ -n "$MULTIPASS_EMAIL" ]]; then
    # ── Vérification U.SOCIETY ────────────────────────────────────────────────
    USOCIETY="$HOME/.zen/game/players/$MULTIPASS_EMAIL/U.SOCIETY"
    if [[ ! -f "$USOCIETY" ]]; then
        echo -e "${RED}❌ $MULTIPASS_EMAIL n'est pas membre U.SOCIETY.${NC}"
        echo "   Seuls les sociétaires peuvent avoir un bureau webtop dédié."
        echo "   Membres actuels :"
        find "$HOME/.zen/game/players/" -maxdepth 2 -name "U.SOCIETY" 2>/dev/null \
            | sed 's|.*/players/||;s|/U.SOCIETY||' | sort | sed 's/^/     /'
        exit 1
    fi

    DATA_DIR="$HOME/.zen/webtop/$MULTIPASS_EMAIL"
    safe_name="${MULTIPASS_EMAIL//[@.]/-}"
    CONTAINER_NAME="webtop-${safe_name}"

    # ── Allocation de port ────────────────────────────────────────────────────
    mkdir -p "$(dirname "$REGISTRY")"
    PORT=$(grep "^${MULTIPASS_EMAIL}=" "$REGISTRY" 2>/dev/null | cut -d'=' -f2)
    if [[ -z "$PORT" ]]; then
        PORT=3000
        while ss -tln 2>/dev/null | grep -q ":${PORT} "; do
            PORT=$((PORT + 10))
        done
        echo "${MULTIPASS_EMAIL}=${PORT}" >> "$REGISTRY"
    fi
    LABEL="$MULTIPASS_EMAIL (U.SOCIETY)"
else
    DATA_DIR="$HOME/.zen/webtop/shared"
    CONTAINER_NAME="webtop-http"
    PORT=3000
    LABEL="bureau partagé"
fi

## ── Purge ────────────────────────────────────────────────────────────────────
if [[ "$PURGE" == "true" ]]; then
    echo "🗑️  Suppression webtop ${LABEL}..."
    docker stop "$CONTAINER_NAME" 2>/dev/null && docker rm "$CONTAINER_NAME" 2>/dev/null || true
    read -rp "Supprimer aussi les données ($DATA_DIR) ? [y/N] " ans
    if [[ "$ans" =~ ^[Yy]$ ]]; then
        rm -rf "$DATA_DIR"
        # Retirer du registre
        [[ -n "$MULTIPASS_EMAIL" ]] && \
            sed -i "/^${MULTIPASS_EMAIL}=/d" "$REGISTRY" 2>/dev/null || true
        echo "Données supprimées."
    fi
    exit 0
fi

## ── Prérequis ─────────────────────────────────────────────────────────────────
if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}❌ Docker non installé.${NC}"
    echo "   https://docs.docker.com/engine/install/"
    exit 1
fi

## ── Déjà en cours ? ──────────────────────────────────────────────────────────
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER_NAME}$"; then
    echo -e "${GREEN}✅ Webtop ${LABEL} tourne déjà.${NC}"
    echo "   → http://127.0.0.1:${PORT}"
    exit 0
fi

## ── Mot de passe (KasmVNC) ───────────────────────────────────────────────────
mkdir -p "$DATA_DIR/config"
PASS_FILE="$DATA_DIR/.webtop_password"
WEBTOP_PASSWORD="${WEBTOP_PASSWORD:-}"
if [[ -z "$WEBTOP_PASSWORD" ]]; then
    if [[ -f "$PASS_FILE" ]]; then
        WEBTOP_PASSWORD=$(cat "$PASS_FILE")
    else
        WEBTOP_PASSWORD=$(tr -dc 'A-Za-z0-9!@#' < /dev/urandom | head -c 16)
        echo "$WEBTOP_PASSWORD" > "$PASS_FILE"
        chmod 600 "$PASS_FILE"
        echo -e "${GREEN}🔑 Mot de passe généré → $PASS_FILE${NC}"
    fi
fi

## ── Lancement ─────────────────────────────────────────────────────────────────
PUID=$(id -u); PGID=$(id -g)

echo ""
echo -e "${BOLD}=== Démarrage Webtop KasmVNC — ${LABEL} ===${NC}"
echo "  Image      : $IMAGE"
echo "  Conteneur  : $CONTAINER_NAME"
echo "  Données    : $DATA_DIR/config/  (= /config dans le conteneur)"
echo "  Port       : $PORT (HTTP)"
echo "  USER hôte  : $(id -un) (PUID=$PUID/PGID=$PGID mappés dans le conteneur)"
echo ""

# Montages optionnels MULTIPASS (lecture seule pour l'IA locale)
EXTRA_MOUNTS=()
if [[ -n "$MULTIPASS_EMAIL" ]]; then
    NOSTR_DIR="$HOME/.zen/game/nostr/$MULTIPASS_EMAIL"
    [[ -d "$NOSTR_DIR" ]] && \
        EXTRA_MOUNTS+=(-v "${NOSTR_DIR}:/home/nostrcard:ro")
fi

docker run -d \
    --name="$CONTAINER_NAME" \
    --restart=unless-stopped \
    -e PUID="$PUID" \
    -e PGID="$PGID" \
    -e TZ="${TZ:-Europe/Paris}" \
    -e PASSWORD="$WEBTOP_PASSWORD" \
    -p "${PORT}:3000" \
    -v "$DATA_DIR/config:/config" \
    "${EXTRA_MOUNTS[@]}" \
    --shm-size="1gb" \
    "$IMAGE" 2>&1

if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✅ Webtop démarré — ${LABEL}${NC}"
    echo ""
    echo -e "${BOLD}Accès :${NC}"
    echo "  Local  : http://127.0.0.1:${PORT}"
    LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
    [[ -n "$LOCAL_IP" ]] && echo "  Réseau : http://${LOCAL_IP}:${PORT}"
    echo ""
    echo -e "${BOLD}Mot de passe KasmVNC :${NC} ${WEBTOP_PASSWORD}"
    echo "  (enregistré dans $PASS_FILE)"
    echo ""
    if [[ -n "$MULTIPASS_EMAIL" ]]; then
        echo -e "${YELLOW}ℹ️  NOSTR card montée en lecture seule dans /home/nostrcard/${NC}"
    fi
    echo -e "${YELLOW}ℹ️  Publié dans le swarm au prochain cycle DRAGON (~20h12).${NC}"
    echo "  Pour partager maintenant :"
    echo "    ~/.zen/Astroport.ONE/RUNTIME/DRAGON_p2p_ssh.sh"
    echo ""
    echo -e "${YELLOW}ℹ️  Pour accéder à distance via le swarm :${NC}"
    echo "    astrosystemctl connect webtop-http"
else
    echo -e "${RED}❌ Échec du démarrage webtop.${NC}"
    echo "   Vérifier : docker logs $CONTAINER_NAME"
    exit 1
fi
