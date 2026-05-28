#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 2.0
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# Installation et configuration de Prometheus + exporters pour la heartbox
# Utilise le textfile collector de node_exporter (pas de services custom)
################################################################################

MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

TEXTFILE_DIR="/var/lib/prometheus/node-exporter"
COLLECTOR_SCRIPT="/usr/local/bin/astroport-metrics-collector.sh"

echo "######### PROMETHEUS EXPORTERS ##############"

########################################################################
# 1. Install prometheus + node_exporter
########################################################################
_PKG_MGR="apt"; command -v pacman >/dev/null 2>&1 && _PKG_MGR="pacman"
_prom_is_installed() {
    if [[ "$_PKG_MGR" == "pacman" ]]; then
        pacman -Qs "^${1}$" >/dev/null 2>&1
    else
        dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
    fi
}
_prom_install_pkg() {
    if [[ "$_PKG_MGR" == "pacman" ]]; then
        # prometheus et prometheus-node-exporter sont dans AUR sur Arch
        command -v yay >/dev/null 2>&1 \
            && yay -S --noconfirm --needed "$1" 2>/dev/null \
            || sudo pacman -S --noconfirm --needed "$1" 2>/dev/null \
            || echo "⚠️  $1 non disponible" >&2
    else
        sudo apt-get install -y "$1"
    fi
}
for pkg in prometheus prometheus-node-exporter; do
    if ! _prom_is_installed "$pkg"; then
        echo ">>> Installation $pkg <<<"
        _prom_install_pkg "$pkg"
    fi
done

########################################################################
# 2. Create textfile collector directory
########################################################################
sudo mkdir -p "${TEXTFILE_DIR}"
sudo chown prometheus:prometheus "${TEXTFILE_DIR}" 2>/dev/null \
    || sudo chown nobody:nogroup "${TEXTFILE_DIR}"

########################################################################
# 3. Enable textfile collector in node_exporter
#    Debian/Ubuntu : /etc/default/prometheus-node-exporter
#    Arch Linux    : systemd drop-in (pas de /etc/default/ idiomatique)
########################################################################
NODE_EXPORTER_DEFAULT="/etc/default/prometheus-node-exporter"
if [[ "$_PKG_MGR" == "pacman" ]]; then
    # Arch : injecter l'argument via un drop-in systemd
    _DROPIN_DIR="/etc/systemd/system/prometheus-node-exporter.service.d"
    _DROPIN="$_DROPIN_DIR/astroport-textfile.conf"
    if [[ ! -f "$_DROPIN" ]] || ! grep -q "textfile.directory" "$_DROPIN" 2>/dev/null; then
        echo "Activation du textfile collector (systemd drop-in Arch)..."
        sudo mkdir -p "$_DROPIN_DIR"
        printf '[Service]\nEnvironment="ARGS=--collector.textfile.directory=%s"\n' \
            "${TEXTFILE_DIR}" | sudo tee "$_DROPIN" > /dev/null
        sudo systemctl daemon-reload
    fi
elif [[ -f "$NODE_EXPORTER_DEFAULT" ]]; then
    if ! grep -q "textfile.directory" "$NODE_EXPORTER_DEFAULT" 2>/dev/null; then
        echo "Activation du textfile collector..."
        echo "ARGS=\"--collector.textfile.directory=${TEXTFILE_DIR}\"" \
            | sudo tee -a "$NODE_EXPORTER_DEFAULT" > /dev/null
    fi
else
    echo "ARGS=\"--collector.textfile.directory=${TEXTFILE_DIR}\"" \
        | sudo tee "$NODE_EXPORTER_DEFAULT" > /dev/null
fi

########################################################################
# 4. Create metrics collector script
#    Writes .prom files consumed by node_exporter textfile collector
########################################################################
cat << 'COLLECTOREOF' | sudo tee "${COLLECTOR_SCRIPT}" > /dev/null
#!/bin/bash
# Astroport heartbox metrics collector
# Writes Prometheus textfile metrics to /var/lib/prometheus/node-exporter/
TEXTFILE_DIR="/var/lib/prometheus/node-exporter"
PROM_FILE="${TEXTFILE_DIR}/astroport_heartbox.prom"
TMP_FILE="${PROM_FILE}.$$"

{
    ## IPFS metrics
    if command -v ipfs &>/dev/null && ipfs id &>/dev/null 2>&1; then
        PEERS=$(ipfs swarm peers 2>/dev/null | wc -l)
        REPO_SIZE=$(ipfs repo stat --size-only 2>/dev/null | grep -oP '\d+' | head -1)
        IPFS_UP=1
    else
        PEERS=0
        REPO_SIZE=0
        IPFS_UP=0
    fi
    echo "# HELP ipfs_up IPFS daemon status (1=running)"
    echo "# TYPE ipfs_up gauge"
    echo "ipfs_up $IPFS_UP"
    echo "# HELP ipfs_peers_total Number of connected IPFS peers"
    echo "# TYPE ipfs_peers_total gauge"
    echo "ipfs_peers_total $PEERS"
    echo "# HELP ipfs_repo_size_bytes IPFS repo size in bytes"
    echo "# TYPE ipfs_repo_size_bytes gauge"
    echo "ipfs_repo_size_bytes ${REPO_SIZE:-0}"

    ## Astroport metrics
    if pgrep -f "_12345.sh" > /dev/null 2>&1; then
        ASTROPORT_UP=1
    else
        ASTROPORT_UP=0
    fi
    echo "# HELP astroport_up Astroport station status (1=running)"
    echo "# TYPE astroport_up gauge"
    echo "astroport_up $ASTROPORT_UP"

    ## NextCloud metrics (Docker)
    if command -v docker &>/dev/null \
        && docker ps --filter "name=nextcloud" --format "{{.Names}}" 2>/dev/null | grep -q nextcloud; then
        NC_UP=1
        NC_USERS=$(docker exec nextcloud occ user:list 2>/dev/null | wc -l)
    else
        NC_UP=0
        NC_USERS=0
    fi
    echo "# HELP nextcloud_up NextCloud status (1=running)"
    echo "# TYPE nextcloud_up gauge"
    echo "nextcloud_up $NC_UP"
    echo "# HELP nextcloud_users_total Number of NextCloud users"
    echo "# TYPE nextcloud_users_total gauge"
    echo "nextcloud_users_total $NC_USERS"

    ## UPassport API (FastAPI on port 54321)
    if curl -sf -o /dev/null -m 3 http://localhost:54321/; then
        UPASSPORT_UP=1
    else
        UPASSPORT_UP=0
    fi
    echo "# HELP upassport_up UPassport API status (1=running)"
    echo "# TYPE upassport_up gauge"
    echo "upassport_up $UPASSPORT_UP"

    ## NOSTR strfry relay (websocket on port 7777)
    STRFRY_DIR="$HOME/.zen/strfry"
    if pgrep -x strfry > /dev/null 2>&1; then
        STRFRY_UP=1
    else
        STRFRY_UP=0
    fi
    ## DB size in bytes (fast, no scan needed)
    if [[ -f "${STRFRY_DIR}/strfry-db/data.mdb" ]]; then
        STRFRY_DB_BYTES=$(stat -c%s "${STRFRY_DIR}/strfry-db/data.mdb" 2>/dev/null || echo 0)
    else
        STRFRY_DB_BYTES=0
    fi
    echo "# HELP strfry_up strfry NOSTR relay status (1=running)"
    echo "# TYPE strfry_up gauge"
    echo "strfry_up $STRFRY_UP"
    echo "# HELP strfry_db_size_bytes strfry LMDB database size in bytes"
    echo "# TYPE strfry_db_size_bytes gauge"
    echo "strfry_db_size_bytes $STRFRY_DB_BYTES"

    ## Player count
    PLAYERS=$(ls -d "$HOME/.zen/game/players/"/*/QR.png 2>/dev/null | wc -l)
    echo "# HELP astroport_players_total Number of players on this station"
    echo "# TYPE astroport_players_total gauge"
    echo "astroport_players_total $PLAYERS"

} > "$TMP_FILE"

# Atomic rename to avoid partial reads
mv "$TMP_FILE" "$PROM_FILE"
COLLECTOREOF

sudo chmod +x "${COLLECTOR_SCRIPT}"

########################################################################
# 5. Create systemd timer (runs every 30s, cleaner than cron)
########################################################################
cat << EOF | sudo tee /etc/systemd/system/astroport-metrics.service > /dev/null
[Unit]
Description=Astroport heartbox metrics collector

[Service]
Type=oneshot
User=$USER
ExecStart=${COLLECTOR_SCRIPT}
EOF

cat << EOF | sudo tee /etc/systemd/system/astroport-metrics.timer > /dev/null
[Unit]
Description=Run Astroport metrics collector every 30s

[Timer]
OnBootSec=10s
OnUnitActiveSec=30s
AccuracySec=5s

[Install]
WantedBy=timers.target
EOF

########################################################################
# 6. Configure prometheus.yml
#    All custom metrics come through node_exporter (port 9100)
########################################################################
cat << EOF | sudo tee /etc/prometheus/prometheus.yml > /dev/null
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

########################################################################
# 7. Enable and start everything
########################################################################
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus-node-exporter
sudo systemctl restart prometheus-node-exporter
sudo systemctl enable --now astroport-metrics.timer
sudo systemctl restart prometheus

echo "Prometheus exporters installed"
echo "  node_exporter:  http://localhost:9100/metrics"
echo "  prometheus:     http://localhost:9090"
echo "  collector:      ${COLLECTOR_SCRIPT} (every 30s)"
echo "  textfile dir:   ${TEXTFILE_DIR}"
