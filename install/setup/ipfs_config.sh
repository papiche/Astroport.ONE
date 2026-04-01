#!/bin/bash
################################################################## ipfs_config.sh
# Version: 0.3 (Gestion intelligente ♥Box / WAN accessible)
################################################################################
MY_PATH="`dirname \"$0\"`"
source "$MY_PATH/../../tools/my.sh"

sudo systemctl stop ipfs

# 1. DÉTECTION DE L'ACCESSIBILITÉ
# Si ♥Box est présent, on récupère l'IP publique
MY_WAN_IP=$(zIp) 

echo ">>> Configuration IPFS pour $(hostname)..."

if [[ -n "$MY_WAN_IP" ]]; then
    echo "    [♥Box] IP Publique détectée : $MY_WAN_IP"
    echo "    Mode : DHT SERVER (Nœud accessible de l'extérieur)"
    ipfs config Routing.Type dhtserver
    
    # On force IPFS à annoncer l'IP publique de la ♥Box
    # Cela permet aux autres de te trouver sans passer par un relais
    ipfs config --json Addresses.Announce "[\"/ip4/$MY_WAN_IP/tcp/4001\", \"/ip4/$MY_WAN_IP/udp/4001/quic-v1\"]"
    echo "    Annonce WAN configurée sur le port 4001"
else
    if [[ -n "$isLAN" ]]; then
        echo "    Mode : DHT CLIENT (Nœud caché / LAN)"
        ipfs config Routing.Type dhtclient
        ipfs config --json Swarm.AddrFilters '["/ip6/::/0"]'
        ipfs config --json Addresses.Announce "[]"
    else
        echo "    Mode : DHT SERVER (Serveur Fixe)"
        ipfs config Routing.Type dhtserver
        ipfs config --json Addresses.Announce "[]"
    fi
fi

# 2. PEERING PERMANENT (Inchangé, reste le ciment du réseau)
BOOTSTRAP_FILE="$HOME/.zen/Astroport.ONE/A_boostrap_nodes.txt"
if [[ -s "$BOOTSTRAP_FILE" ]]; then
    PEER_JSON="["
    FIRST=true
    while read -r line; do
        [[ "$line" =~ ^# ]] || [[ -z "$line" ]] && continue
        PEER_ID="${line##*/}"
        ADDR="${line%/p2p/*}"
        if [ "$FIRST" = false ]; then PEER_JSON+=","; fi
        PEER_JSON+="{\"ID\": \"$PEER_ID\", \"Addrs\": [\"$ADDR\"]}"
        FIRST=false
    done < <(grep -Ev "^#" "$BOOTSTRAP_FILE")
    PEER_JSON+="]"
    ipfs config Peering.Peers --json "$PEER_JSON"
fi

# 3. OPTIONS D'ACCÉLÉRATION & RÉSEAU
ipfs config --json Ipns.UsePubsub true
ipfs config --json Experimental.Libp2pStreamMounting true
ipfs config --json Experimental.P2pHttpProxy true
ipfs config --json Swarm.ConnMgr.LowWater 20
ipfs config --json Swarm.ConnMgr.HighWater 60

# 4. CORS & API
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Origin '["*"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Methods '["PUT", "GET", "POST"]'
ipfs config --json API.HTTPHeaders.Access-Control-Allow-Credentials '["true"]'

# 5. RE-BOOTSTRAP & START
ipfs bootstrap rm --all
while read -r bootnode; do
    [[ "$bootnode" =~ ^# ]] || [[ -z "$bootnode" ]] && continue
    ipfs bootstrap add "$bootnode"
done < <(grep -Ev "^#" "$BOOTSTRAP_FILE")

sudo systemctl start ipfs
echo "✅ Configuration IPFS (v0.3) terminée."