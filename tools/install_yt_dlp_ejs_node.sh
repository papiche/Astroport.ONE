#!/bin/bash
########################################################################
# install_yt_dlp_ejs_node.sh
# Configure yt-dlp to use Node.js as JavaScript runtime for EJS
# (YouTube JavaScript challenge solver)
########################################################################

set -euo pipefail

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

echo "[install_yt_dlp_ejs_node][$(timestamp)] Configuring yt-dlp JavaScript runtime (Node + EJS)" >&2

# Ensure Node.js is available (Astroport.ONE/install.sh should have installed it already)
if ! command -v node >/dev/null 2>&1; then
    echo "[install_yt_dlp_ejs_node][$(timestamp)] ERROR: Node.js is not available in PATH. Please run Astroport.ONE/install.sh first." >&2
    exit 1
fi

# yt-dlp must be present to configure its runtime
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "[install_yt_dlp_ejs_node][$(timestamp)] WARNING: yt-dlp is not available in PATH. Skipping EJS configuration." >&2
    exit 0
fi

YT_DLP_CONFIG_DIR="$HOME/.config/yt-dlp"
YT_DLP_CONFIG_FILE="$YT_DLP_CONFIG_DIR/config"

mkdir -p "$YT_DLP_CONFIG_DIR"

# If a runtime is already configured, do not override it silently
if [[ -f "$YT_DLP_CONFIG_FILE" ]] && grep -q -- '--js-runtimes' "$YT_DLP_CONFIG_FILE"; then
    echo "[install_yt_dlp_ejs_node][$(timestamp)] yt-dlp config already defines --js-runtimes, leaving it unchanged." >&2
    exit 0
fi

{
    echo ""
    echo "# Enable Node.js as JavaScript runtime for yt-dlp EJS challenges"
    echo "--js-runtimes"
    echo "node"
} >> "$YT_DLP_CONFIG_FILE"

echo "[install_yt_dlp_ejs_node][$(timestamp)] yt-dlp EJS configuration completed (Node runtime enabled)." >&2

