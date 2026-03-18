#!/bin/bash
########################################################################
# firewall.sh — Gestion UFW pour Astroport.ONE
# Version: 1.0
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
#  │ 4001    │ tcp+udp  │ IPFS Swarm P2P (pairs directs)        │
#  └─────────┴──────────┴────────────────────────────────────────┘
#
#  PORTS LOCALHOST UNIQUEMENT (bloqués depuis l'extérieur)
#  ┌─────────┬──────────┬────────────────────────────────────────┐
#  │ 5001    │ tcp      │ IPFS API (⚠️ dangereux si exposé)      │
#  │ 7777    │ tcp      │ NOSTR strfry (via NPM uniquement)     │
#  │ 8080    │ tcp      │ IPFS Gateway (via NPM uniquement)     │
#  │ 12345   │ tcp      │ Astroport API (via NPM uniquement)    │
#  │ 54321   │ tcp      │ UPassport API (via NPM uniquement)    │
#  │ 33101   │ tcp      │ G1BILLET (via NPM uniquement)         │
#  │ 81      │ tcp      │ NPM Admin UI (localhost uniquement)   │
#  │ 1883    │ tcp      │ MQTT Mosquitto (localhost uniquement)  │
#  │ 9090    │ tcp      │ Prometheus scrape (localhost)         │
#  │ 9615    │ tcp      │ IPFS exporter (localhost)             │
#  └─────────┴──────────┴────────────────────────────────────────┘
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

    echo "
── PORTS LOCALHOST UNIQUEMENT (bloqués depuis Internet) ───────────"

    ## Bloquer explicitement les ports de service depuis l'extérieur
    ## (ils sont accessibles via le proxy NPM uniquement)
    for port_comment in \
        "5001:IPFS API (dangereux si exposé)" \
        "7777:NOSTR rnostr/strfry (via NPM)" \
        "8080:IPFS Gateway (via NPM)" \
        "12345:Astroport API (via NPM)" \
        "54321:UPassport API (via NPM)" \
        "33101:G1BILLET (via NPM)" \
        "81:NPM Admin UI" \
        "1883:MQTT Mosquitto" \
        "6333:Qdrant REST (localhost seulement)" \
        "6334:Qdrant gRPC (localhost seulement)" \
        "8888:rnostr interne (localhost seulement)" \
        "9090:Prometheus" \
        "9615:IPFS exporter"
    do
        port="${port_comment%%:*}"
        comment="${port_comment#*:}"
        sudo ufw deny in "${port}/tcp" comment "${comment}" > /dev/null 2>&1
        printf "  🔒 %5s/tcp  %s\n" "$port" "$comment"
    done

    ## LAN : autoriser le réseau local à accéder aux services internes
    ## (utile pour debug depuis un autre PC du LAN)
    for LAN_RANGE in 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12; do
        sudo ufw allow from "${LAN_RANGE}" to any port 12345 proto tcp comment "LAN→Astroport" > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 8080  proto tcp comment "LAN→IPFS GW"  > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 54321 proto tcp comment "LAN→UPassport" > /dev/null 2>&1
        sudo ufw allow from "${LAN_RANGE}" to any port 7777  proto tcp comment "LAN→NOSTR"    > /dev/null 2>&1
    done
    echo ""
    echo "  🏠 LAN (192.168/10./172.16-31.) : accès autorisé aux services internes"

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
    ss -tlnup 2>/dev/null | grep -E ":(22|80|443|4001|5001|7777|8080|12345|54321|33101|81|1883) " \
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
