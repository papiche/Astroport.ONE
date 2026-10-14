#!/bin/bash
################################################################## ipfs_config.sh
# Version: 0.3 (Gestion intelligente ♥Box / WAN accessible)
################################################################################
MY_PATH="`dirname \"$0\"`"
source "$MY_PATH/../../tools/my.sh"

## Garde identique à ipfs_setup.sh:31-37 — si la session courante transite par
## le tunnel SSH-P2P de CETTE station (upgrade distant via IPFS), stopper le
## daemon ici coupe la session avant d'atteindre le "systemctl start" plus bas
## (script tué par SIGHUP), laissant IPFS mort indéfiniment (Restart=on-failure
## ne se déclenche pas sur un arrêt volontaire). Incident du 2026-10 (bulma-39).
if [[ "${_IPFS_TUNNEL_SSH:-false}" == "true" ]]; then
    echo "⏭️  IPFS stop/restart — ignoré (tunnel SSH-P2P actif). Config appliquée à chaud,"
    echo "   effective au prochain redémarrage manuel : sudo systemctl restart ipfs"
else
    sudo systemctl stop ipfs
fi

# 1. DÉTECTION DE L'ACCESSIBILITÉ
# Si ♥Box est présent, on récupère l'IP publique
MY_WAN_IP=$(zIp) 

echo ">>> Configuration IPFS pour $(hostname)..."

if [[ -n "$MY_WAN_IP" ]]; then
    echo "    [♥Box] IP Publique détectée : $MY_WAN_IP"
    echo "    Mode : DHT SERVER"
    ipfs config Routing.Type dhtserver
    ipfs config --json Addresses.Announce "[\"/ip4/$MY_WAN_IP/tcp/4001\", \"/ip4/$MY_WAN_IP/udp/4001/quic-v1\"]"
    # On autorise tout le trafic sur un serveur public
    ipfs config Swarm.AddrFilters --json "[]"
else
    if [[ -n "$isLAN" ]]; then
        echo "    Mode : DHT CLIENT (4G/Restreint)"
        ipfs config Routing.Type dhtclient
        # SYNTAXE CORRIGÉE : /ip6/::/ipcidr/0 pour bloquer l'IPv6 proprement
        ipfs config Swarm.AddrFilters --json '["/ip6/::/ipcidr/0"]'
        ipfs config --json Addresses.Announce "[]"
    else
        echo "    Mode : DHT SERVER (Fixe)"
        ipfs config Routing.Type dhtserver
        ipfs config Swarm.AddrFilters --json "[]"
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
ipfs config --json Swarm.ConnMgr.LowWater 40
ipfs config --json Swarm.ConnMgr.HighWater 200

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

if [[ "${_IPFS_TUNNEL_SSH:-false}" == "true" ]]; then
    echo "⏭️  IPFS start — ignoré (tunnel SSH-P2P actif, daemon jamais arrêté ci-dessus)."
else
    sudo systemctl start ipfs
fi
echo "✅ Configuration IPFS (v0.3) terminée."