#!/bin/bash
# zicmama_ap_laptop.sh — Point d'accès WiFi ouvert "ZICMAMA" sur laptop Linux,
# avec portail captif walled-garden vers une URL configurable.
#
# Contrairement au mode RPi de sound-spot (uap0 partagé avec l'upstream),
# ce script dédie un dongle WiFi USB entier à l'AP : la carte WiFi interne
# du laptop garde sa connexion Internet intacte. Aucune route réseau n'est
# ouverte entre le réseau ZICMAMA et Internet — voir
# zicmama/zicmama_ap_portal.py (proxy applicatif) et
# zicmama/zicmama-ap-firewall.sh (règle ufw scopée à l'interface, cohérente
# avec firewall.sh qui administre ufw sur cette machine).
#
# Usage:
#   sudo ./zicmama_ap_laptop.sh install [--iface IFACE] [--ssid SSID] [--portal-url URL]
#   sudo ./zicmama_ap_laptop.sh uninstall
#   sudo ./zicmama_ap_laptop.sh start|stop|restart|status
#   sudo ./zicmama_ap_laptop.sh set-portal-url URL
set -euo pipefail

MY_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_DIR=/etc/zicmama-ap
CONF_FILE="${CONF_DIR}/zicmama-ap.conf"
OPT_DIR=/opt/zicmama-ap
UNIT_DIR=/etc/systemd/system

DEFAULT_SSID="ZICMAMA"
DEFAULT_CHANNEL=6
DEFAULT_GATEWAY_IP="10.42.90.1"
DEFAULT_DHCP_START="10.42.90.10"
DEFAULT_DHCP_END="10.42.90.100"
DEFAULT_PORTAL_PORT=8090
# Sert la variante locale/démo (compte ATOM4LOVE sans MULTIPASS) via l'UPassport
# de CETTE station (port 54321, mount /earth) — aucun accès Internet requis.
DEFAULT_PORTAL_URL="http://127.0.0.1:54321/earth/atomic_demo.html"

log()  { echo "[zicmama-ap] $*"; }
warn() { echo "[zicmama-ap] ⚠️  $*" >&2; }
err()  { echo "[zicmama-ap] ❌ $*" >&2; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || err "Ce script doit être lancé en root (sudo)."
}

detect_wan_iface() {
    ip route show default 2>/dev/null | awk '{print $5; exit}'
}

detect_ap_iface() {
    local wan="$1" iface
    for iface in /sys/class/net/wlx*; do
        [ -e "$iface" ] || continue
        iface="$(basename "$iface")"
        [ "$iface" = "$wan" ] && continue
        echo "$iface"
        return 0
    done
    return 1
}

check_ap_mode_support() {
    local iface="$1" phy
    command -v iw >/dev/null 2>&1 || return 0
    phy="$(basename "$(readlink -f "/sys/class/net/${iface}/phy80211" 2>/dev/null)")"
    [ -n "$phy" ] || return 0
    if iw phy "$phy" info 2>/dev/null | grep -A 20 "Supported interface modes" | grep -q '\* AP$'; then
        log "Mode AP supporté par ${iface} (${phy}) ✓"
    else
        warn "Impossible de confirmer le support du mode AP pour ${iface} (${phy}) — poursuite quand même."
    fi
}

install_deps() {
    local missing=()
    command -v hostapd >/dev/null 2>&1 || missing+=(hostapd)
    command -v iw >/dev/null 2>&1 || missing+=(iw)
    command -v dnsmasq >/dev/null 2>&1 || missing+=(dnsmasq-base)
    if [ "${#missing[@]}" -gt 0 ]; then
        log "Installation des paquets manquants : ${missing[*]}"
        apt-get update -q
        apt-get install -y "${missing[@]}"
    fi
    systemctl disable --now hostapd 2>/dev/null || true
    systemctl disable --now dnsmasq 2>/dev/null || true
}

cmd_install() {
    require_root
    local ap_iface="" ssid="$DEFAULT_SSID" channel="$DEFAULT_CHANNEL" portal_url="$DEFAULT_PORTAL_URL"
    while [ $# -gt 0 ]; do
        case "$1" in
            --iface) ap_iface="$2"; shift 2 ;;
            --ssid) ssid="$2"; shift 2 ;;
            --channel) channel="$2"; shift 2 ;;
            --portal-url) portal_url="$2"; shift 2 ;;
            *) err "Option inconnue : $1" ;;
        esac
    done

    local wan_iface
    wan_iface="$(detect_wan_iface)" || err "Impossible de détecter l'interface WAN (route par défaut)."
    log "Interface WAN (Internet) : ${wan_iface}"

    if [ -z "$ap_iface" ]; then
        ap_iface="$(detect_ap_iface "$wan_iface")" || err "Aucun dongle WiFi USB (wlx*) libre trouvé — précisez --iface."
    fi
    [ -e "/sys/class/net/${ap_iface}" ] || err "Interface ${ap_iface} introuvable."
    [ "$ap_iface" = "$wan_iface" ] && err "${ap_iface} est aussi l'interface WAN — un dongle dédié est requis."
    log "Interface AP (ZICMAMA)     : ${ap_iface}"

    install_deps
    check_ap_mode_support "$ap_iface"

    mkdir -p "$CONF_DIR" "$OPT_DIR"

    cat > "$CONF_FILE" <<EOF
AP_IFACE=${ap_iface}
WAN_IFACE=${wan_iface}
SSID=${ssid}
CHANNEL=${channel}
GATEWAY_IP=${DEFAULT_GATEWAY_IP}
DHCP_START=${DEFAULT_DHCP_START}
DHCP_END=${DEFAULT_DHCP_END}
PORTAL_PORT=${DEFAULT_PORTAL_PORT}
PORTAL_URL=${portal_url}
EOF
    log "Config écrite : ${CONF_FILE}"

    # shellcheck disable=SC1090
    source "$CONF_FILE"

    export AP_IFACE SSID CHANNEL GATEWAY_IP DHCP_START DHCP_END
    envsubst '${AP_IFACE} ${SSID} ${CHANNEL}' \
        < "${MY_PATH}/zicmama/network/zicmama-ap-hostapd.conf" > "${CONF_DIR}/hostapd.conf"
    envsubst '${AP_IFACE} ${GATEWAY_IP} ${DHCP_START} ${DHCP_END}' \
        < "${MY_PATH}/zicmama/network/zicmama-ap-dnsmasq.conf" > "${CONF_DIR}/dnsmasq.conf"

    install -m 644 "${MY_PATH}/zicmama/zicmama_ap_portal.py" "${OPT_DIR}/zicmama_ap_portal.py"
    install -m 755 "${MY_PATH}/zicmama/zicmama-ap-firewall.sh" "${OPT_DIR}/zicmama-ap-firewall.sh"

    local unit
    for unit in zicmama-ap-iface.service zicmama-ap-hostapd.service zicmama-ap-dnsmasq.service \
                zicmama-ap-firewall.service zicmama-ap-portal.service zicmama-ap.target; do
        envsubst '${AP_IFACE}' < "${MY_PATH}/zicmama/services/${unit}" > "${UNIT_DIR}/${unit}"
    done

    envsubst '${AP_IFACE}' < "${MY_PATH}/zicmama/network/99-zicmama-ap.rules" \
        > /etc/udev/rules.d/99-zicmama-ap.rules
    envsubst '${AP_IFACE}' < "${MY_PATH}/zicmama/network/99-zicmama-ap-unmanaged.conf" \
        > /etc/NetworkManager/conf.d/99-zicmama-ap-unmanaged.conf

    systemctl daemon-reload
    udevadm control --reload-rules
    nmcli general reload 2>/dev/null || systemctl reload NetworkManager 2>/dev/null || true

    log "Installation terminée. Démarrage immédiat (le dongle est déjà branché)…"
    udevadm trigger --action=add --subsystem-match=net "/sys/class/net/${ap_iface}" 2>/dev/null || true
    sleep 1
    systemctl start zicmama-ap.target

    log "SSID '${ssid}' actif sur ${ap_iface} → portail : ${portal_url}"
    log "Statut : $0 status"
}

cmd_uninstall() {
    require_root
    systemctl stop zicmama-ap.target 2>/dev/null || true
    systemctl disable zicmama-ap.target 2>/dev/null || true
    rm -f "${UNIT_DIR}"/zicmama-ap-*.service "${UNIT_DIR}/zicmama-ap.target"
    rm -f /etc/udev/rules.d/99-zicmama-ap.rules
    rm -f /etc/NetworkManager/conf.d/99-zicmama-ap-unmanaged.conf
    rm -rf "$CONF_DIR" "$OPT_DIR"
    systemctl daemon-reload
    udevadm control --reload-rules
    nmcli general reload 2>/dev/null || true
    log "ZICMAMA désinstallé."
}

cmd_set_portal_url() {
    require_root
    [ -f "$CONF_FILE" ] || err "Non installé — lancez d'abord 'install'."
    local url="${1:?Usage: $0 set-portal-url URL}"
    sed -i "s|^PORTAL_URL=.*|PORTAL_URL=${url}|" "$CONF_FILE"
    systemctl restart zicmama-ap-portal.service
    log "PORTAL_URL mis à jour : ${url}"
}

case "${1:-}" in
    install)   shift; cmd_install "$@" ;;
    uninstall) cmd_uninstall ;;
    start)     require_root; systemctl start zicmama-ap.target ;;
    stop)      require_root; systemctl stop zicmama-ap.target ;;
    restart)   require_root; systemctl restart zicmama-ap.target ;;
    status)    systemctl status zicmama-ap.target --no-pager 2>&1 || true ;;
    set-portal-url) shift; cmd_set_portal_url "$@" ;;
    *)
        echo "Usage: $0 {install|uninstall|start|stop|restart|status|set-portal-url}" >&2
        exit 1
        ;;
esac
