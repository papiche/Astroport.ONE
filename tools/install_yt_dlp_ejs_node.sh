#!/bin/bash
########################################################################
# install_yt_dlp_ejs_node.sh
# Configure yt-dlp to use Node.js as JavaScript runtime for EJS
# (YouTube JavaScript challenge solver).
# Optionally install PO Token Provider plugin for YouTube 403 workaround.
# See https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide
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
else
    {
        echo ""
        echo "# Enable Node.js as JavaScript runtime for yt-dlp EJS challenges"
        echo "--js-runtimes node"
    } >> "$YT_DLP_CONFIG_FILE"
fi

# EJS challenge solver scripts: allow yt-dlp to fetch from GitHub (fixes "Signature solving failed")
if [[ -f "$YT_DLP_CONFIG_FILE" ]] && grep -q -- '--remote-components' "$YT_DLP_CONFIG_FILE"; then
    echo "[install_yt_dlp_ejs_node][$(timestamp)] yt-dlp config already defines --remote-components, leaving it unchanged." >&2
else
    {
        echo ""
        echo "# EJS scripts: download challenge solver from GitHub (required for YouTube)"
        echo "--remote-components ejs:github"
    } >> "$YT_DLP_CONFIG_FILE"
    echo "[install_yt_dlp_ejs_node][$(timestamp)] Added --remote-components ejs:github to config." >&2
fi

# Optional: install PO Token Provider plugin (recommended for YouTube 403 / GVS)
# https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide
# If installed, run provider: docker run -d -p 4416:4416 --name bgutil-provider brainicism/bgutil-ytdlp-pot-provider
# Or use manual PO token file: ~/.zen/game/nostr/<player>/.youtube.potoken (see IA scripts)
if command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
    pip_cmd=""
    command -v pip3 >/dev/null 2>&1 && pip_cmd="pip3" || pip_cmd="pip"
    if "$pip_cmd" show bgutil-ytdlp-pot-provider >/dev/null 2>&1; then
        echo "[install_yt_dlp_ejs_node][$(timestamp)] PO Token Provider plugin already installed." >&2
    else
        echo "[install_yt_dlp_ejs_node][$(timestamp)] Installing PO Token Provider plugin (optional, for YouTube 403)..." >&2
        if "$pip_cmd" install --user bgutil-ytdlp-pot-provider 2>/dev/null || "$pip_cmd" install bgutil-ytdlp-pot-provider 2>/dev/null; then
            echo "[install_yt_dlp_ejs_node][$(timestamp)] PO Token Provider installed. Run provider: docker run -d -p 4416:4416 brainicism/bgutil-ytdlp-pot-provider" >&2
        else
            echo "[install_yt_dlp_ejs_node][$(timestamp)] PO Token Provider install skipped (pip install failed). Manual PO token still supported." >&2
        fi
    fi
fi

# Append PO Token Guide reference to config if not already present
if [[ -f "$YT_DLP_CONFIG_FILE" ]] && ! grep -q "PO-Token-Guide" "$YT_DLP_CONFIG_FILE" 2>/dev/null; then
    {
        echo ""
        echo "# YouTube 403 workaround: PO Token Guide https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide"
        echo "# Manual PO token: put GVS token in ~/.zen/game/nostr/<player>/.youtube.potoken (one line, no spaces)"
    } >> "$YT_DLP_CONFIG_FILE"
fi

echo "[install_yt_dlp_ejs_node][$(timestamp)] yt-dlp EJS configuration completed (Node runtime enabled)." >&2

