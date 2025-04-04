#!/bin/bash
# Convert SSH Ed25519 keys to WireGuard config with IPs ordered by public key fingerprint

CONFIG_DIR="$HOME/.zen/game"
mkdir -p "$CONFIG_DIR"

# Fonction pour extraire la clé WireGuard depuis une clé SSH
ssh_to_wg() {
    echo "$1" | base64 -d | tail -c +12 | head -c 32 | base64 | tr -d '\n'
}

# Convert private key
awk '/BEGIN OPENSSH PRIVATE KEY/{flag=1; next} /END OPENSSH PRIVATE KEY/{flag=0} flag' ~/.ssh/id_ed25519 \
    | base64 -d | tail -c +16 | head -c 32 | base64 | tr -d '\n' > "$CONFIG_DIR/wireguard.priv"

# Convert public key
ssh_to_wg "$(awk '{print $2}' ~/.ssh/id_ed25519.pub)" > "$CONFIG_DIR/wireguard.pub"

# Generate WireGuard config from authorized_keys with ordered IPs
generate_wireguard_config() {
    local WG_CONF="$1"
    local SSH_KEYS="$2"
    local NETWORK_BASE="$3"
    local START_IP="$4"

    echo "[Interface]
Address = ${NETWORK_BASE}1/24
ListenPort = 51820
PrivateKey = $(cat "$CONFIG_DIR/wireguard.priv")
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
" > "$WG_CONF"

    # Temporary file to store sorted keys
    local TEMP_FILE=$(mktemp)

    # Process each key and create sorting key (SHA1 of public key)
    while read -r line; do
        if [[ "$line" == ssh-ed25519* ]]; then
            local PUB_KEY=$(echo "$line" | awk '{print $2}')
            local WG_KEY=$(ssh_to_wg "$PUB_KEY")
            local FINGERPRINT=$(echo "$PUB_KEY" | base64 -d | sha256sum | cut -d' ' -f1)
            echo "$FINGERPRINT $WG_KEY $line" >> "$TEMP_FILE"
        fi
    done < "$SSH_KEYS"

    # Sort by fingerprint (hexadecimal)
    sort "$TEMP_FILE" > "${TEMP_FILE}.sorted"

    # Count peers and process
    local PEER_COUNT=0
    while read -r fingerprint wg_key line; do
        local COMMENT=$(echo "$line" | awk '{$1=$2=""; print $0}' | sed 's/^  *//')
        local CURRENT_IP=$((START_IP + PEER_COUNT))

        echo "[Peer]
# $COMMENT (fingerprint: ${fingerprint:0:12}...)
PublicKey = $wg_key
AllowedIPs = ${NETWORK_BASE}${CURRENT_IP}/32, ${NETWORK_BASE}${CURRENT_IP}/24
" >> "$WG_CONF"

        ((PEER_COUNT++))
    done < "${TEMP_FILE}.sorted"

    rm "$TEMP_FILE" "${TEMP_FILE}.sorted"
    echo "Configuration WireGuard générée dans $WG_CONF"
    echo "Dernière IP attribuée: ${NETWORK_BASE}$((START_IP + PEER_COUNT - 1))"
    echo "Nombre de pairs configurés: $PEER_COUNT"
}

# Gestion des arguments
if [[ $# -eq 0 ]]; then
    echo -n "Chemin du fichier de configuration [/etc/wireguard/wg0.conf]: "
    read OUT
    [[ -z "$OUT" ]] && OUT="/etc/wireguard/wg0.conf"
else
    OUT="$1"
fi

generate_wireguard_config "$OUT" "$HOME/.ssh/authorized_keys" "10.0.0." 2
