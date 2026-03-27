#!/bin/bash
## me.♥Box.sh 
## Analyse Astroport Networks & Cache 
## $HOME/.zen/♥Box ??? $FINAL_IP

# 1. Identifier l'interface de sortie default
DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)

# 2. Récupérer l'IP LAN de cette interface
LAN_IP=$(ip -4 addr show dev "$DEFAULT_IFACE" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1 | head -n1)

# --- FONCTION FALLBACK WAN ---
get_wan_fallback() {
    local ip=""
    local timeout=3

    # Tentative 1: Service HTTP (ipify, forcé en IPv4)
    ip=$(curl -s -4 --connect-timeout 2 --max-time "$timeout" https://api.ipify.org 2>/dev/null)

    if [[ ! "$ip" =~ ^[0-9.]+ && ! "$ip" =~ ^[a-fA-F0-9:]+ ]]; then
        # Tentative 2: Google DNS (très rapide, utilise dig installé via dnsutils)
        ip=$(dig +short txt o-o.myaddr.l.google.com @ns1.google.com 2>/dev/null | tr -d '"')
    fi
    
    if [[ ! "$ip" =~ ^[0-9.]+ && ! "$ip" =~ ^[a-fA-F0-9:]+ ]]; then
        # Tentative 3: OpenDNS
        ip=$(dig +short myip.opendns.com @resolver2.opendns.com 2>/dev/null | tr -d '"')
    fi
    echo "$ip"
}

# 3. Tentative WAN via IPFS (Priorité à l'essaim)
IPFS_DATA=$(ipfs id 2>/dev/null)
WAN_IP=$(echo "$IPFS_DATA" | jq -r '.Addresses[]?' | \
    grep -vE "::1|fe80:|fc00:|fd00:|p2p-circuit|127.0.0.1" | \
    grep -vE "^/ip4/(192\.168|10\.|172\.(1[6-9]|2[0-9]|3[01]))" | \
    awk -F/ '{print $3}' | sort -u | head -n1)

MODE="WAN (IPFS)"

# 4. Fallback si IPFS est muet (relais/NAT)
if [ -z "$WAN_IP" ]; then
    WAN_IP=$(get_wan_fallback)
    if [ -n "$WAN_IP" ]; then
        MODE="WAN (External Resolver)"
    else
        MODE="LAN (Masqué / Offline)"
    fi
fi

# 5. Filtrage final de sécurité (au cas où un résolveur renverrait une IP de loopback ou privée)
if [[ "$WAN_IP" =~ ^(127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])|fe80:|::1) ]]; then
    WAN_IP=""
fi

# 6. Sélection finale pour ♥Box
FINAL_IP="${WAN_IP:-$LAN_IP}"

# # 7. Mise à jour de ♥Box
# if [ -n "$FINAL_IP" ]; then
#     FINAL_IP=$(echo "$FINAL_IP" | xargs)
#     echo "$FINAL_IP" > "$HOME/.zen/♥Box"
# fi
IPFSNODEID=$(echo "$IPFS_DATA" | jq -r .ID)
echo "--- ipfs swarm peers"
ipfs swarm peers; 
echo; 
echo "--- BALISE STATION $IPFSNODEID"
ipfs ls /ipns/$IPFSNODEID; 
echo; 
echo "--- BALISE MySwarm"
ipfs ls /ipns/$(ipfs key list -l | grep -w "MySwarm_${IPFSNODEID}" | cut -d ' ' -f 1); 
echo; 
echo '--- CACHE tmp/swarm'; 
ls ~/.zen/tmp/swarm/
echo
# 8. RÉSULTAT
echo "--- CONFIGURATION $HOME/.zen/♥Box ??? $FINAL_IP"
echo "INTERFACE : $DEFAULT_IFACE"
echo "LAN       : ${LAN_IP:-Inconnu}"
echo "WAN       : ${WAN_IP:-Non détecté}"
echo "♥Box      : ($MODE)"
echo "--------------------------------------"
echo "$FINAL_IP"