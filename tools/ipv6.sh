#!/bin/bash

# Récupérer le nom de l'interface réseau principale
MAIN_INTERFACE=$(ip -o link show | awk -F': ' '$0 !~ "lo|vir|wl|^[0-9]+: docker|^[0-9]+: tun|^[0-9]+: veth|DOWN" {print $2; exit}')

# Vérifier si une interface a été trouvée
if [ -z "$MAIN_INTERFACE" ]; then
    echo "Aucune interface réseau principale trouvée."
    exit 1
fi

# Récupérer l'adresse IPv6 globale de l'interface principale
IPV6_ADDR=$(ip -6 addr show dev $MAIN_INTERFACE | grep -w "inet6" | awk '{print $2}' | grep -v "fe80::")

# Afficher l'adresse IPv6
echo "$IPV6_ADDR"
exit 0