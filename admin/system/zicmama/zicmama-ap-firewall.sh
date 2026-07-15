#!/bin/bash
# ZICMAMA laptop — ouverture pare-feu (voir zicmama_ap_laptop.sh)
#
# Cette machine est administrée par ufw via ../firewall.sh, qui fait un
# `ufw --force reset` à chaque ré-exécution en mode ON. On n'ajoute donc AUCUNE règle
# iptables sur la table filter (qui serait incohérente avec cette gestion) :
# uniquement une règle `ufw` scopée à l'interface AP dédiée pour le
# DHCP/DNS (port 80 est déjà autorisé globalement par firewall.sh).
#
# Une règle nat (table nat, hors du périmètre d'ufw — comme les règles de
# Docker qui coexistent déjà sans être touchées par les reset ufw) redirige
# les ports 80 ET 443 entrant sur l'interface AP vers PORTAL_PORT : sur cette
# machine, docker-proxy (NPM) occupe déjà 0.0.0.0:80.
#
# Port 443 : sans cette règle, rien n'écoute côté ZICMAMA sur ce port → toute
# vérification de connectivité HTTPS (Android/iOS testent souvent HTTP *et*
# HTTPS en parallèle) reçoit un connection refused immédiat, un signal bien
# plus fort de "pas de réseau" que la détection de portail captif — le
# téléphone affiche alors "Aucune connexion à Internet" et n'ouvre pas la
# page de connexion. En redirigeant aussi ce port (même si notre serveur ne
# parle pas TLS et que la poignée de main échoue), le système reçoit une
# connexion TCP qui aboutit puis une coupure anormale — un signal de portail
# captif, pas d'absence de réseau — au lieu d'un refus immédiat.
#
# Limite connue : si `firewall.sh ON` est ré-exécuté (reset complet ufw)
# pendant que ZICMAMA tourne, la règle ufw est perdue jusqu'au prochain
# `systemctl restart zicmama-ap.target` (les règles nat, elles, ne sont pas affectées).
set -euo pipefail
source /etc/zicmama-ap/zicmama-ap.conf

case "${1:-}" in
    start)
        ufw allow in on "$AP_IFACE" comment 'ZICMAMA AP (hotspot laptop, walled-garden)'
        for port in 80 443; do
            iptables -t nat -C PREROUTING -i "$AP_IFACE" -p tcp --dport "$port" -j REDIRECT --to-port "$PORTAL_PORT" 2>/dev/null \
                || iptables -t nat -A PREROUTING -i "$AP_IFACE" -p tcp --dport "$port" -j REDIRECT --to-port "$PORTAL_PORT"
        done
        ;;
    stop)
        ufw delete allow in on "$AP_IFACE" 2>/dev/null || true
        for port in 80 443; do
            iptables -t nat -D PREROUTING -i "$AP_IFACE" -p tcp --dport "$port" -j REDIRECT --to-port "$PORTAL_PORT" 2>/dev/null || true
        done
        ;;
    *)
        echo "Usage: $0 {start|stop}" >&2
        exit 1
        ;;
esac
