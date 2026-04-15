#!/bin/bash
########################################################################
# firewall.sh — Gestion UFW pour Astroport.ONE
# Version: 1.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
#
# USAGE: firewall.sh [ON|OFF|STATUS]
#
# Architecture des ports Astroport.ONE :
# ───────────────────────────────────────────────────────────────────
#  PORTS PUBLICS (accessibles depuis Internet)
#  ┌─────────┬──────────┬────────────────────────────────────────┐
#  │ Port    │ Proto    │ Service                                │
#  ├─────────┼──────────┼────────────────────────────────────────┤
#  │ 22      │ tcp      │ SSH (accès administration)            │
#  │ 80      │ tcp      │ HTTP → redirect HTTPS par NPM         │
#  │ 443     │ tcp      │ HTTPS (NPM SSL termination)           │
#  │         │          │   → astroport.DOMAIN :12345           │
#  │         │          │   → u.DOMAIN        :54321            │
#  │         │          │   → ipfs.DOMAIN     :8080             │
#  │         │          │   → relay.DOMAIN    :7777 (WSS)       │
#  │         │          │   → cloud.DOMAIN    :8001 (NextCloud) │
#  │ 4001    │ tcp+udp  │ IPFS Swarm P2P (pairs directs)        │
#  │ 51820   │ udp      │ WireGuard HUB (VPN Constellation)    │
#  │ 4002-4100│ tcp+udp │ IPFS Satellites (Redirection VPN)    │
#  └─────────┴──────────┴────────────────────────────────────────┘
#
#  PORTS LOCALHOST UNIQUEMENT (bloqués depuis l'extérieur)
#  ┌─────────┬──────────┬────────────────────────────────────────┐
#  │ 5001    │ tcp      │ IPFS API (⚠️ dangereux si exposé)      │
#  │ 7777    │ tcp      │ NOSTR strfry/rnostr (via NPM)         │
#  │ 8080    │ tcp      │ IPFS Gateway (via NPM)                │
#  │ 12345   │ tcp      │ Astroport API (via NPM)               │
#  │ 54321   │ tcp      │ UPassport API (via NPM)               │
#  │ 33101   │ tcp      │ G1BILLET (via NPM)                    │
#  │ 81      │ tcp      │ NPM Admin UI (localhost)              │
#  │ 1883    │ tcp      │ MQTT Mosquitto (localhost)            │
#  │ 8111    │ tcp      │ Icecast2 Live Broadcasting (SoundSpot) │
#  │── NextCloud AIO ──────────────────────────────────────────── │
#  │ 8001    │ tcp      │ Apache NextCloud (via NPM → cloud.D)  │
#  │ 8002    │ tcp      │ NextCloud AIO Dashboard (localhost)   │
#  │ 8443    │ tcp      │ NextCloud AIO Admin Setup (localhost) │
#  │── ai-company IA Stack ──────────────────────────────────── │
#  │ 8010    │ tcp      │ Dify AI Web (localhost)               │
#  │ 8000    │ tcp      │ Open WebUI interface IA (localhost)   │
#  │ 11434   │ tcp      │ Ollama LLM API (localhost)            │
#  │── Webtop VDI (KasmVNC) ───────────────────────────────────── │
#  │ 3000    │ tcp      │ KasmVNC HTTP (localhost — SSH tunnel) │
#  │ 3001    │ tcp      │ KasmVNC HTTPS (localhost — SSH tunnel)│
#  │── Monitoring ─────────────────────────────────────────────── │
#  │ 9090    │ tcp      │ Prometheus scrape (localhost)         │
#  │ 9615    │ tcp      │ IPFS exporter (localhost)             │
#  └─────────┴──────────┴────────────────────────────────────────┘
#
#  ACCÈS WEBTOP À DISTANCE : utiliser SSH tunnel
#    ssh -L 3000:localhost:3000 user@VOTRE_IP
#    puis ouvrir http://localhost:3000
#
########################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Normaliser l'argument
MODE=$(echo "${1:-STATUS}" | tr '[:lower:]' '[:upper:]')

########################################################################
# Vérification des prérequis
########################################################################
if ! which ufw &>/dev/null; then
    echo "❌ UFW non installé. Installez-le : sudo apt-get install ufw"
    exit 1
fi

########################################################################
fire_on() {
########################################################################
    echo "
########################################################################
🔥 ASTROPORT FIREWALL — ACTIVATION UFW
########################################################################"

    ## Activation IPv6 dans la configuration UFW si nécessaire
    if [ -f /etc/default/ufw ]; then
        sudo sed -i 's/^IPV6=no/IPV6=yes/' /etc/default/ufw
        ## Autoriser le Forwarding (Routage) pour le rôle HUB VPN WireGuard
        sudo sed -i 's/^DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
    fi

    ## Réinitialisation propre (évite les doublons)
    sudo ufw --force reset > /dev/null 2>&1

    ## Politique par défaut : tout bloquer en entrée, tout autoriser en sortie
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    echo "
── PORTS PUBLICS ──────────────────────────────────────────────────"

    ## SSH (avant tout le reste pour éviter le lockout)
    sudo ufw allow 22/tcp comment 'SSH'
    echo "  ✅ 22/tcp   SSH"

    ## HTTP/HTTPS — NPM gère le SSL termination et le proxy vers les services
    sudo ufw allow 80/tcp  comment 'HTTP → NPM redirect'
    sudo ufw allow 443/tcp comment 'HTTPS NPM (astroport/u/ipfs/relay)'
    echo "  ✅ 80/tcp   HTTP  → NPM redirect vers HTTPS"
    echo "  ✅ 443/tcp  HTTPS → NPM proxy : astroport/u/ipfs/relay"

    ## IPFS Swarm P2P (connexions directes entre nœuds)
    sudo ufw allow 4001/tcp comment 'IPFS Swarm TCP'
    sudo ufw allow 4001/udp comment 'IPFS Swarm UDP (QUIC)'
    echo "  ✅ 4001/tcp IPFS Swarm P2P"
    echo "  ✅ 4001/udp IPFS Swarm QUIC"

    ## WireGuard HUB (Le tunnel pour la constellation)
    sudo ufw allow 51820/udp comment 'WireGuard HUB'
    echo "  ✅ 51820/udp WireGuard HUB"

    ## Plage IPFS pour Satellites (Redirection dynamique 4000 + octet)
    # On autorise de 4002 à 4100 pour couvrir une centaine de satellites
    sudo ufw allow 4002:4100/tcp comment 'IPFS Satellites TCP'
    sudo ufw allow 4002:4100/udp comment 'IPFS Satellites UDP'
    echo "  ✅ 4002-4100 IPFS Satellites (TCP/UDP)"

    echo "
── PRIORITÉ 1 : ALLOWS (avant les DENY pour éviter le masquage) ───"

    ## ⚠️  ORDRE CRITIQUE : les règles ALLOW doivent être ajoutées AVANT les DENY.
    ## Dans UFW/iptables, la première règle correspondante gagne.

    ## Docker : accès complet depuis TOUS les réseaux bridge Docker (172.16.x.x à 172.31.x.x)
    ## Cela permet à Dify de communiquer correctement avec Ollama et Qdrant.
    echo "  🐳 Docker networks 172.16.0.0/12 → tous ports autorisés"
    sudo ufw allow from 172.16.0.0/12 comment "Docker networks internes" > /dev/null 2>&1

    ## LAN & VPN : accès aux services internes depuis le réseau local et le VPN WireGuard
    ## Ajout IPv6 : fe80::/10 (Link-Local), fc00::/7 (Unique Local)
    ## Ajout VPN : 10.99.99.0/24 (réseau WireGuard Constellation)
    for LAN_RANGE in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 10.99.99.0/24 fe80::/10 fc00::/7; do
        sudo ufw allow from "${LAN_RANGE}" to any port 12345 proto tcp comment "LAN→Astroport" > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 8080  proto tcp comment "LAN→IPFS GW"   > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 54321 proto tcp comment "LAN→UPassport"  > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 7777  proto tcp comment "LAN→NOSTR"     > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 81    proto tcp comment "LAN→NPM Admin" > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 11434 proto tcp comment "LAN/Docker→Ollama" > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 8111  proto tcp comment "LAN→Icecast"   > /dev/null 2>&1
    done
    echo "  🏠 LAN & 🔐 VPN (10.99.99.0/24) : accès autorisé aux services internes (dont Ollama)"
    echo ""

    echo "
── PRIORITÉ 2 : DENY explicites (bloqués depuis Internet) ─────────"
    ## Les deny explicites confirment le blocage (REJECT vs DROP par défaut).
    ## Ils s'appliquent uniquement au trafic non matché par les ALLOW ci-dessus.
    for port_comment in \
        "5001:IPFS API (dangereux si exposé)" \
        "7777:NOSTR strfry/rnostr (via NPM uniquement)" \
        "8080:IPFS Gateway (via NPM uniquement)" \
        "12345:Astroport API (via NPM uniquement)" \
        "54321:UPassport API (via NPM uniquement)" \
        "33101:G1BILLET (via NPM uniquement)" \
        "81:NPM Admin UI (LAN autorisé, Internet bloqué)" \
        "1883:MQTT Mosquitto" \
        "4416:bgutil PO token provider (Docker)" \
        "6333:Qdrant REST (IA Stack)" \
        "6334:Qdrant gRPC (IA Stack)" \
        "8888:rnostr interne" \
        "8001:NextCloud Apache (via NPM cloud.DOMAIN)" \
        "8002:NextCloud AIO Dashboard" \
        "8443:NextCloud AIO Admin Setup" \
        "8000:Open WebUI interface IA (ai-company)" \
        "8010:Dify AI (ai-company)" \
        "11434:Ollama LLM API (ai-company)" \
        "3000:KasmVNC HTTP (webtop — SSH tunnel requis)" \
        "3001:KasmVNC HTTPS (webtop — SSH tunnel requis)" \
        "9090:Prometheus" \
        "9615:IPFS exporter" \
        "8111:Icecast Live Broadcasting (SoundSpot)"
    do
        port="${port_comment%%:*}"
        comment="${port_comment#*:}"
        sudo ufw deny in "${port}/tcp" comment "${comment}" > /dev/null 2>&1
        printf "  🔒 %5s/tcp  %s\n" "$port" "$comment"
    done

    ## Activer UFW
    sudo ufw --force enable
    echo "
✅ UFW ACTIVÉ
$(sudo ufw status verbose)
########################################################################"
}

########################################################################
fire_off() {
########################################################################
    echo "
########################################################################
🚿 ASTROPORT FIREWALL — DÉSACTIVATION UFW
########################################################################"
    sudo ufw --force disable
    echo "✅ UFW DÉSACTIVÉ — tous les ports accessibles"
    echo "########################################################################"
}

########################################################################
fire_status() {
########################################################################
    echo "
########################################################################
📊 ASTROPORT FIREWALL — STATUT UFW
########################################################################"
    sudo ufw status verbose
    echo ""
    echo "Ports d'écoute actifs :"
    ss -tlnup 2>/dev/null | grep -E ":(22|80|443|4001|4002|4003|5001|51820|7777|8080|8001|8002|8443|8010|8000|11434|3000|3001|3100|12345|54321|33101|81|1883|9090|8111) " \
        | awk '{print "  " $1 " " $4 " " $5}' | sort -t: -k2 -n
    echo "########################################################################"
}

########################################################################
# DISPATCH
########################################################################
case "$MODE" in
    "ON")  fire_on     ;;
    "OFF") fire_off    ;;
    "STATUS"|*) fire_status ;;
esac

exit 0