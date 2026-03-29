#!/bin/bash
## me.♥Box.sh
## Dashboard terminal du nœud Astroport — équivalent CLI de status.html
## Affiche : réseau (LAN/WAN/NAT/♥Box), IPFS, essaim, capitaine,
##           services Docker, économie (12345.json), capacités, ressources système.
##
## Usage : ~/.zen/Astroport.ONE/me.♥Box.sh
## Retourne en dernière ligne : l'IP finale détectée (WAN ou LAN)

# ─── Couleurs ANSI ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; PURPLE='\033[0;35m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

section() { echo -e "\n${CYAN}${BOLD}══════════════════ $1 ══════════════════${NC}"; }
kv()      { printf "  ${DIM}%-24s${NC} ${BOLD}%s${NC}\n" "$1" "$2"; }
ok()      { echo -e "  ${GREEN}✓${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
err()     { echo -e "  ${RED}✗${NC} $1"; }

MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "\n${BOLD}${PURPLE}╔══════════════════════════════════════════════════╗"
echo -e   "║      🌌  ASTROPORT NODE — DIAGNOSTIC COMPLET     ║"
echo -e   "╚══════════════════════════════════════════════════╝${NC}"
echo -e "  ${DIM}$(date '+%Y-%m-%d %H:%M:%S')  —  $(hostname)${NC}"

# ─── 1. RÉSEAU & ♥BOX ────────────────────────────────────────────────────────
section "🌐 RÉSEAU & ♥BOX"

DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
LAN_IP=$(ip -4 addr show dev "$DEFAULT_IFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)
LAN_IP6=$(ip -6 addr show dev "$DEFAULT_IFACE" scope global 2>/dev/null | awk '/inet6 / {print $2}' | cut -d/ -f1 | head -n1)

kv "Interface"    "${DEFAULT_IFACE:-inconnu}"
kv "IP LAN (v4)"  "${LAN_IP:-non détecté}"
[[ -n "$LAN_IP6" ]] && kv "IP LAN (v6)" "$LAN_IP6"

# Détection WAN via IPFS puis fallbacks
IPFS_DATA=$(ipfs id 2>/dev/null)
IPFSNODEID=$(echo "$IPFS_DATA" | jq -r '.ID // empty' 2>/dev/null)

WAN_IP=$(echo "$IPFS_DATA" | jq -r '.Addresses[]?' 2>/dev/null | \
    grep -vE "::1|fe80:|fc00:|fd00:|p2p-circuit|127.0.0.1" | \
    grep -vE "^/ip4/(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01]))" | \
    awk -F/ '{print $3}' | grep -v '^$' | sort -u | head -n1)
WMODE="WAN (IPFS)"

if [[ -z "$WAN_IP" ]]; then
    WAN_IP=$(curl -s -4 --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null)
    WMODE="WAN (ipify)"
fi
if [[ -z "$WAN_IP" || ! "$WAN_IP" =~ ^[0-9a-fA-F.:]+$ ]]; then
    WAN_IP=$(dig +short txt o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | tr -d '"')
    WMODE="WAN (Google DNS)"
fi
if [[ -z "$WAN_IP" || ! "$WAN_IP" =~ ^[0-9a-fA-F.:]+$ ]]; then
    WAN_IP=$(dig +short myip.opendns.com @resolver2.opendns.com 2>/dev/null | tr -d '"')
    WMODE="WAN (OpenDNS)"
fi
# Filtrage sécurité
[[ "$WAN_IP" =~ ^(127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|fe80:|::1) ]] && WAN_IP=""

kv "IP WAN"       "${WAN_IP:-non détecté}  ($WMODE)"

# Détection NAT (LAN=WAN ?)
IS_PRIVATE_LAN=false
[[ "$LAN_IP" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.) ]] && IS_PRIVATE_LAN=true

if [[ "$IS_PRIVATE_LAN" == "false" && -n "$WAN_IP" ]]; then
    FINAL_IP="$WAN_IP"
    NAT_STATUS="${GREEN}DIRECT (LAN=WAN) — nœud directement exposé${NC}"
    ok "Mode réseau : DIRECT (pas de NAT) → ♥Box renseignable"
elif [[ "$IS_PRIVATE_LAN" == "true" && -n "$WAN_IP" ]]; then
    FINAL_IP="$WAN_IP"
    NAT_STATUS="${YELLOW}NAT (LAN≠WAN) — nœud derrière routeur${NC}"
    warn "Mode réseau : NAT → ♥Box non peuplé — URLs via domaine DNS (HTTPS)"
    warn "Forwarding requis sur routeur pour accès direct IP:port"
else
    FINAL_IP="${LAN_IP:-127.0.0.1}"
    NAT_STATUS="${RED}LAN seul (WAN non détecté — hors ligne ?)${NC}"
    err "Pas d'accès WAN détecté"
fi

echo -e "  Mode :  $NAT_STATUS"

HEARTBOX=$(cat "$HOME/.zen/♥Box" 2>/dev/null | head -n1)

# ── Correction automatique de ♥Box si WAN ≠ LAN (NAT) ──────────────────────
# Règle : ♥Box doit contenir une IP UNIQUEMENT si le nœud est directement
# exposé sur internet (LAN IPv4 = WAN IPv4, sans NAT).
# Derrière un NAT, même avec une IPv6 publique sur l'interface, ♥Box est vidé :
# les services sont adressés via le domaine DNS + Nginx Proxy Manager (HTTPS).
if [[ "$IS_PRIVATE_LAN" == "true" && -n "$HEARTBOX" ]]; then
    warn "♥Box contient '$HEARTBOX' mais le nœud est derrière NAT (LAN $LAN_IP ≠ WAN $WAN_IP)"
    warn "→ Correction : suppression de ~/.zen/♥Box"
    rm -f "$HOME/.zen/♥Box"
    HEARTBOX=""
    ok "♥Box   : vidé (URLs basculent vers domaine DNS)"
elif [[ -n "$HEARTBOX" ]]; then
    ok "♥Box   : $HEARTBOX (nœud directement sur le WAN)"
else
    ok "♥Box   : vide (mode DNS/HTTPS via Nginx Proxy Manager)"
fi

# ─── 2. IPFS ─────────────────────────────────────────────────────────────────
section "📡 IPFS"

if [[ -n "$IPFSNODEID" ]]; then
    ok "Daemon IPFS : actif"
    kv "Node ID"    "$IPFSNODEID"
    AGENT=$(echo "$IPFS_DATA" | jq -r '.AgentVersion // "?"' 2>/dev/null)
    kv "Version"    "$AGENT"

    PEER_COUNT=$(ipfs swarm peers 2>/dev/null | wc -l)
    if [[ "$PEER_COUNT" -gt 20 ]]; then
        ok "Pairs connectés : $PEER_COUNT"
    elif [[ "$PEER_COUNT" -gt 0 ]]; then
        warn "Pairs connectés : $PEER_COUNT (faible)"
    else
        err "Aucun pair IPFS connecté"
    fi

    # Adresses multiaddr publiques annoncées
    PUBLIC_ADDRS=$(echo "$IPFS_DATA" | jq -r '.Addresses[]?' 2>/dev/null | \
        grep -vE "127.0.0.1|::1|fe80:|p2p-circuit|/ip4/(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01]))" | \
        head -n3)
    if [[ -n "$PUBLIC_ADDRS" ]]; then
        echo "  Adresses publiques annoncées :"
        echo "$PUBLIC_ADDRS" | while read line; do echo -e "    ${DIM}$line${NC}"; done
    fi

    # Balise IPNS station
    echo ""
    echo -e "  ${DIM}--- Balise IPNS station ---${NC}"
    ipfs --timeout 10s ls /ipns/$IPFSNODEID 2>/dev/null | awk '{print "    "$0}' || warn "Balise IPNS non résolue (daemon trop récent ?)"

    # Balise MySwarm
    SWARM_KEY=$(ipfs key list -l 2>/dev/null | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1)
    if [[ -n "$SWARM_KEY" ]]; then
        echo ""
        echo -e "  ${DIM}--- Balise MySwarm ---${NC}"
        ipfs --timeout 10s ls /ipns/$SWARM_KEY 2>/dev/null | awk '{print "    "$0}' || warn "Balise MySwarm non résolue"
    fi
else
    err "IPFS daemon non disponible (ipfs id échoue)"
fi

# ─── 3. ESSAIM ASTROPORT ──────────────────────────────────────────────────────
section "🔭 ESSAIM ASTROPORT"

SWARM_DIR="$HOME/.zen/tmp/swarm"
if [[ -d "$SWARM_DIR" ]]; then
    SWARM_COUNT=$(ls "$SWARM_DIR" 2>/dev/null | wc -l)
    if [[ "$SWARM_COUNT" -gt 0 ]]; then
        ok "Stations connues dans l'essaim : $SWARM_COUNT"
        ls "$SWARM_DIR" 2>/dev/null | while read station; do
            STATION_JSON="$SWARM_DIR/$station/12345.json"
            if [[ -f "$STATION_JSON" ]]; then
                S_HOST=$(jq -r '.hostname // "?"' "$STATION_JSON" 2>/dev/null)
                S_CAPT=$(jq -r '.captain // "?"' "$STATION_JSON" 2>/dev/null)
                S_CITY=$(jq -r '.IPCity // "?"' "$STATION_JSON" 2>/dev/null)
                S_PEERS=$(jq -r '.services.ipfs.peers_connected // "?"' "$STATION_JSON" 2>/dev/null)
                printf "    ${GREEN}⬡${NC} %-30s  %-35s  %-20s  pairs=%s\n" "$S_HOST" "$S_CAPT" "$S_CITY" "$S_PEERS"
            else
                echo -e "    ${DIM}⬡ $station${NC}"
            fi
        done
    else
        warn "Aucune station dans l'essaim local (cache vide)"
    fi
else
    warn "Dossier essaim absent : $SWARM_DIR"
fi

# ─── 4. IDENTITÉ CAPITAINE ───────────────────────────────────────────────────
section "🪪 IDENTITÉ CAPITAINE"

PLAYER_FILE="$HOME/.zen/game/players/.current/.player"
GPS_FILE="$HOME/.zen/GPS"
G1PUB_FILE="$HOME/.zen/game/players/.current/secret.june"

if [[ -f "$PLAYER_FILE" ]]; then
    CAPTAIN=$(cat "$PLAYER_FILE" 2>/dev/null)
    ok "Capitaine : $CAPTAIN"
else
    warn "Aucun capitaine embarqué (créez votre MULTIPASS : http://localhost:54321/g1)"
fi

if [[ -f "$GPS_FILE" ]]; then
    GPS=$(cat "$GPS_FILE" 2>/dev/null)
    kv "GPS" "$GPS"
fi

if [[ -f "$G1PUB_FILE" ]]; then
    G1PUB=$(grep 'pub=' "$G1PUB_FILE" 2>/dev/null | cut -d= -f2 | head -n1)
    [[ -n "$G1PUB" ]] && kv "G1PUB" "${G1PUB:0:20}…"
fi

# Clef IPFS du nœud ↔ G1
if [[ -n "$IPFSNODEID" && -f "$MY_PATH/tools/ipfs_to_g1.py" ]]; then
    NODEG1=$(python3 "$MY_PATH/tools/ipfs_to_g1.py" "$IPFSNODEID" 2>/dev/null)
    [[ -n "$NODEG1" ]] && kv "Nœud G1PUB" "${NODEG1:0:20}…"
fi

# ─── 5. SERVICES DOCKER ──────────────────────────────────────────────────────
section "🐳 SERVICES DOCKER"

if command -v docker &>/dev/null; then
    DOCKER_INFO=$(sg docker -c "docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null \
                 || sudo docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null)
    if [[ -n "$DOCKER_INFO" ]]; then
        echo "$DOCKER_INFO" | while IFS=$'\t' read name status ports; do
            if echo "$status" | grep -qi "up"; then
                printf "  ${GREEN}✓${NC} %-35s ${DIM}%s${NC}\n" "$name" "$ports"
            else
                printf "  ${RED}✗${NC} %-35s ${YELLOW}%s${NC}\n" "$name" "$status"
            fi
        done
    else
        warn "Aucun conteneur actif"
    fi
else
    warn "Docker non disponible"
fi

# ─── 6. ÉCONOMIE & CAPACITÉS (12345.json) ────────────────────────────────────
section "💰 ÉCONOMIE & CAPACITÉS (12345.json)"

JSON12345=""
# Chercher d'abord le JSON local publié (dans le cache IPNS)
NODEID_DIR="$HOME/.zen/tmp/${IPFSNODEID}"
[[ -f "$NODEID_DIR/12345.json" ]] && JSON12345=$(cat "$NODEID_DIR/12345.json" 2>/dev/null)

# Fallback: chercher dans le répertoire de travail habituel
if [[ -z "$JSON12345" ]]; then
    for f in "$HOME/.zen/tmp/"*/12345.json; do
        [[ -f "$f" ]] && JSON12345=$(cat "$f" 2>/dev/null) && break
    done
fi

if [[ -n "$JSON12345" ]] && echo "$JSON12345" | jq . &>/dev/null; then
    ECO=$(echo "$JSON12345" | jq '.economy // {}' 2>/dev/null)
    CAP=$(echo "$JSON12345" | jq '.capacities // {}' 2>/dev/null)
    SVC=$(echo "$JSON12345" | jq '.services // {}' 2>/dev/null)
    DRAGON=$(echo "$JSON12345" | jq -r '.dragon_services // ""' 2>/dev/null)
    DATE_J=$(echo "$JSON12345" | jq -r '.date // ""' 2>/dev/null)
    RISK=$(echo "$JSON12345" | jq -r '.economy.risk_level // "N/A"' 2>/dev/null)

    [[ -n "$DATE_J" ]] && kv "Dernière publication" "$DATE_J"

    case "$RISK" in
        GREEN)  echo -e "  Niveau risque : ${GREEN}🟢 $RISK${NC}" ;;
        YELLOW) echo -e "  Niveau risque : ${YELLOW}🟡 $RISK${NC}" ;;
        ORANGE) echo -e "  Niveau risque : ${YELLOW}🟠 $RISK${NC}" ;;
        RED)    echo -e "  Niveau risque : ${RED}🔴 $RISK${NC}" ;;
        *)      kv "Niveau risque" "$RISK" ;;
    esac

    MP=$(echo "$ECO" | jq -r '.multipass_count // "?"')
    ZC=$(echo "$ECO" | jq -r '.zencard_count // "?"')
    REV=$(echo "$ECO" | jq -r '.weekly_revenue // 0')
    BAL=$(echo "$ECO" | jq -r '.weekly_balance // 0')
    PAF=$(echo "$ECO" | jq -r '.weekly_costs // 0')
    CAP_R=$(echo "$ECO" | jq -r '.captain_remuneration // 0')

    echo ""
    printf "  ${BOLD}%-20s %-20s %-20s %-20s${NC}\n" \
        "Multipass: $MP" "ZenCard: $ZC" "Revenus: ${REV} Ẑ" "Bilan: ${BAL} Ẑ"
    printf "  ${DIM}%-20s %-20s${NC}\n" "PAF node: ${PAF} Ẑ" "Rémun. captn: ${CAP_R} Ẑ/sem"

    # Capacités
    echo ""
    ZC_SLOTS=$(echo "$CAP" | jq -r '.zencard_slots // "?"')
    NS_SLOTS=$(echo "$CAP" | jq -r '.nostr_slots // "?"')
    DISK_GB=$(echo "$CAP" | jq -r '.available_space_gb // "?"')
    printf "  ${DIM}%-30s %-30s %-20s${NC}\n" \
        "Slots ZenCard: $ZC_SLOTS" "Slots NOSTR: $NS_SLOTS" "Disque libre: ${DISK_GB} Go"

    # Services système
    if [[ "$SVC" != "{}" && -n "$SVC" ]]; then
        echo ""
        echo -e "  ${DIM}Services système :${NC}"
        echo "$SVC" | jq -r 'to_entries[] | "\(.key)=\(.value.active)"' 2>/dev/null | while IFS='=' read sname sactive; do
            if [[ "$sactive" == "true" ]]; then
                printf "    ${GREEN}✓${NC} %s\n" "$sname"
            else
                printf "    ${DIM}○${NC} %s\n" "$sname"
            fi
        done
    fi

    # Services DRAGON
    if [[ -n "$DRAGON" ]]; then
        echo ""
        echo -e "  ${PURPLE}🐉 Services DRAGON :${NC}"
        echo "$DRAGON" | tr ',' '\n' | sed 's/^ *//' | while read svc; do
            [[ -n "$svc" ]] && echo -e "    ${GREEN}⬡${NC} $svc"
        done
    fi
else
    warn "12345.json non disponible (station non encore publiée ou IPFS hors ligne)"
fi

# ─── 7. RESSOURCES SYSTÈME ───────────────────────────────────────────────────
section "📊 RESSOURCES SYSTÈME"

# Disque ~/.zen et ~/.ipfs
ZEN_DISK=$(du -sh "$HOME/.zen" 2>/dev/null | cut -f1)
IPFS_DISK=$(du -sh "$HOME/.ipfs" 2>/dev/null | cut -f1)
ROOT_FREE=$(df -h / | tail -1 | awk '{print $4}')
kv "~/.zen"        "${ZEN_DISK:-?}"
kv "~/.ipfs"       "${IPFS_DISK:-?}"
kv "/ libre"       "${ROOT_FREE:-?}"

# RAM
FREE_MB=$(free -m | awk '/^Mem:/ {print $7}')
TOTAL_MB=$(free -m | awk '/^Mem:/ {print $2}')
kv "RAM libre"     "${FREE_MB:-?} Mo / ${TOTAL_MB:-?} Mo"

# Uptime
UPTIME=$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | cut -d, -f1-2)
kv "Uptime"        "$UPTIME"

# Load average
LOAD=$(cat /proc/loadavg | cut -d' ' -f1-3)
kv "Load avg"      "$LOAD ($(nproc) CPU)"

# ─── 8. RÉCAPITULATIF ♥BOX & URLS ────────────────────────────────────────────
section "🔗 RÉCAPITULATIF URLS & ♥BOX"

# Charger my.sh pour récupérer les variables de configuration
if [[ -f "$MY_PATH/tools/my.sh" ]]; then
    source "$MY_PATH/tools/my.sh" 2>/dev/null
fi

kv "myASTROPORT"   "${myASTROPORT:-http://localhost:12345}"
kv "myIPFS"        "${myIPFS:-http://localhost:8080}"
kv "myRELAY"       "${myRELAY:-ws://localhost:7777}"
kv "uSPOT"         "${uSPOT:-http://localhost:54321}"
kv "myDOMAIN"      "${myDOMAIN:-localhost}"

echo ""
if [[ -n "$HEARTBOX" ]]; then
    ok "♥Box = $HEARTBOX  (URLs basées sur IP directe)"
    echo -e "  ${DIM}→ Forward de ports requis : 8080 4001 12345 54321 7777${NC}"
else
    warn "♥Box vide  (URLs basées sur domaine DNS — mode proxy HTTPS)"
    echo -e "  ${DIM}→ Nginx Proxy Manager gère le reverse proxy${NC}"
fi

echo ""
echo -e "${BOLD}${PURPLE}══════════════════════════════════════════════════${NC}"
echo -e "  ${DIM}Erreurs install : cat ~/.zen/install.errors.log${NC}"
echo -e "  ${DIM}Station :  ~/.zen/Astroport.ONE/station.sh${NC}"
echo -e "  ${DIM}Test     : ~/.zen/Astroport.ONE/test.sh${NC}"
echo -e "${BOLD}${PURPLE}══════════════════════════════════════════════════${NC}"
echo ""

# ─── Valeur de sortie (pour setup.sh) ────────────────────────────────────────
echo "$FINAL_IP"
