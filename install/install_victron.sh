#!/bin/bash
########################################################################
# install_victron.sh
# Install Victron MPPT BLE Monitor (tools/victron/) as a systemd service
# Reads Victron "Instant Readout" BLE advertisements (SmartSolar, BMV, ...)
########################################################################

set -euo pipefail

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

echo "[install_victron][$(timestamp)] Starting Victron MPPT monitor installation" >&2

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ASTRO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VICTRON_DIR="${ASTRO_DIR}/tools/victron"

########################################################################
# 1. BlueZ (BLE stack) — requis par bleak sur Linux
########################################################################
if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo "[install_victron][$(timestamp)] Installing BlueZ..." >&2
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y bluez
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S --noconfirm --needed bluez bluez-utils
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y bluez
    else
        echo "[install_victron][$(timestamp)] WARNING: Unsupported package manager. Install BlueZ manually." >&2
    fi
else
    echo "[install_victron][$(timestamp)] BlueZ already present: $(command -v bluetoothctl)" >&2
fi

########################################################################
# 2. Dépendances Python dans le venv ~/.astro
########################################################################
if [[ ! -x "$HOME/.astro/bin/pip" ]]; then
    echo "[install_victron][$(timestamp)] ERROR: ~/.astro venv not found. Run install.sh first." >&2
    exit 1
fi

echo "[install_victron][$(timestamp)] Installing Python dependencies (bleak, victron-ble, pycryptodome)..." >&2
"$HOME/.astro/bin/pip" install -U -r "${VICTRON_DIR}/requirements.txt"

########################################################################
# 3. Config appareils (~/.zen/victron.json) — hors dépôt git, copie l'exemple
#    si absent. Emplacement volontairement en dehors de tools/victron/ car
#    ce fichier contient un secret (clé de déchiffrement BLE par appareil).
########################################################################
DEVICES_JSON="$HOME/.zen/victron.json"
mkdir -p "$HOME/.zen"
if [[ ! -f "$DEVICES_JSON" ]]; then
    cp "${VICTRON_DIR}/devices.example.json" "$DEVICES_JSON"
    echo "[install_victron][$(timestamp)] ⚠️  ${DEVICES_JSON} créé depuis l'exemple." >&2
    echo "[install_victron][$(timestamp)]     Éditez-le avec le MAC + la clé de votre régulateur" >&2
    echo "[install_victron][$(timestamp)]     (VictronConnect → Settings → Product info → Instant Readout → Show)." >&2
fi

########################################################################
# 4. Service systemd (tourne sous l'utilisateur courant — pas de root requis
#    pour le scan BLE via BlueZ/D-Bus)
########################################################################
CSV_DIR="$HOME/.zen/tmp/victron"
mkdir -p "$CSV_DIR"

echo "[install_victron][$(timestamp)] Installing systemd service..." >&2
cat << EOF | sudo tee /etc/systemd/system/victron-mppt-monitor.service > /dev/null
[Unit]
Description=Victron MPPT BLE monitor (Astroport.ONE)
After=bluetooth.target
Requires=bluetooth.target

[Service]
Type=simple
User=$USER
WorkingDirectory=${VICTRON_DIR}
ExecStart=$HOME/.astro/bin/python3 ${VICTRON_DIR}/victron_monitor.py monitor --config ${DEVICES_JSON} --csv ${CSV_DIR}/readings.csv
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable victron-mppt-monitor.service
sudo systemctl restart victron-mppt-monitor.service 2>/dev/null || sudo systemctl start victron-mppt-monitor.service

if systemctl is-active --quiet victron-mppt-monitor.service; then
    echo "[install_victron][$(timestamp)] ✅ victron-mppt-monitor.service actif (CSV: ${CSV_DIR}/readings.csv)" >&2
else
    echo "[install_victron][$(timestamp)] ⚠️  Le service n'a pas démarré — vérifiez : journalctl -u victron-mppt-monitor -f" >&2
fi

echo "[install_victron][$(timestamp)] Installation completed" >&2
