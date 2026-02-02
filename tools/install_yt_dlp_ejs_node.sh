#!/bin/bash
########################################################################
# install_yt_dlp_ejs_node.sh
# Configure yt-dlp to use Deno (preferred) or Node.js as JavaScript runtime for EJS
# (YouTube JavaScript challenge solver). Deno is recommended by yt-dlp; Node >= 20 required.
# Optionally install PO Token Provider plugin for YouTube 403 workaround.
# See https://github.com/yt-dlp/yt-dlp/wiki/EJS and PO-Token-Guide
########################################################################

set -euo pipefail

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

echo "[install_yt_dlp_ejs_node][$(timestamp)] Configuring yt-dlp JavaScript runtime (Deno preferred, else Node + EJS)" >&2

# Resolve JS runtime: prefer Deno (yt-dlp recommended, works with Node 18 kept for TiddlyWiki); else Node >= 20
JS_RUNTIME=""
DENO_BIN=""
if command -v deno >/dev/null 2>&1; then
    DENO_BIN="$(command -v deno)"
elif [[ -x "$HOME/.deno/bin/deno" ]]; then
    DENO_BIN="$HOME/.deno/bin/deno"
fi
if [[ -n "$DENO_BIN" ]]; then
    JS_RUNTIME="deno:$DENO_BIN"
    DENO_VER=$("$DENO_BIN" --version 2>/dev/null | head -1 || true)
    echo "[install_yt_dlp_ejs_node][$(timestamp)] Using Deno: $JS_RUNTIME ($DENO_VER)" >&2
else
    # Fallback to Node: yt-dlp EJS requires Node >= 20 (Node 18 is unsupported)
    NODE_BIN=""
    if command -v node >/dev/null 2>&1; then
        NODE_BIN="$(command -v node)"
    elif command -v nodejs >/dev/null 2>&1; then
        NODE_BIN="$(command -v nodejs)"
    fi
    if [[ -n "$NODE_BIN" ]]; then
        NODE_VER=$("$NODE_BIN" --version 2>/dev/null || true)
        NODE_MAJOR="${NODE_VER#v}"; NODE_MAJOR="${NODE_MAJOR%%.*}"
        if [[ -n "$NODE_MAJOR" ]] && [[ "$NODE_MAJOR" -ge 20 ]] 2>/dev/null; then
            JS_RUNTIME="node:$NODE_BIN"
            echo "[install_yt_dlp_ejs_node][$(timestamp)] Using Node: $JS_RUNTIME ($NODE_VER)" >&2
        else
            echo "[install_yt_dlp_ejs_node][$(timestamp)] Node $NODE_VER is unsupported by yt-dlp EJS (need >= 20). Install Deno: ~/.zen/Astroport.ONE/tools/install_deno.sh" >&2
            echo "[install_yt_dlp_ejs_node][$(timestamp)] Then re-run this script. Node 18 is kept for TiddlyWiki; Deno is used only for yt-dlp." >&2
            exit 1
        fi
    else
        echo "[install_yt_dlp_ejs_node][$(timestamp)] ERROR: No Deno and no Node. Install Deno: ~/.zen/Astroport.ONE/tools/install_deno.sh" >&2
        exit 1
    fi
fi

# yt-dlp must be present to configure its runtime
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "[install_yt_dlp_ejs_node][$(timestamp)] WARNING: yt-dlp is not available in PATH. Skipping EJS configuration." >&2
    exit 0
fi

YT_DLP_CONFIG_DIR="$HOME/.config/yt-dlp"
YT_DLP_CONFIG_FILE="$YT_DLP_CONFIG_DIR/config"

mkdir -p "$YT_DLP_CONFIG_DIR"

# Write or update --js-runtimes with explicit path (Deno or Node)
if [[ -f "$YT_DLP_CONFIG_FILE" ]] && grep -q -- '--js-runtimes' "$YT_DLP_CONFIG_FILE"; then
    sed -i "s|^--js-runtimes .*|--js-runtimes $JS_RUNTIME|" "$YT_DLP_CONFIG_FILE"
    echo "[install_yt_dlp_ejs_node][$(timestamp)] Updated --js-runtimes to: $JS_RUNTIME" >&2
else
    {
        echo ""
        echo "# JavaScript runtime for yt-dlp EJS (Deno preferred, or Node >= 20)"
        echo "--js-runtimes $JS_RUNTIME"
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

# Default YouTube player_client: android_vr first (no JS runtime needed, gets full format list), then tv/tv_embedded (no PO token)
PLAYER_CLIENTS="android_vr,tv_embedded,tv,android,web"
if [[ -f "$YT_DLP_CONFIG_FILE" ]] && grep -q -- 'player_client=' "$YT_DLP_CONFIG_FILE" 2>/dev/null; then
    # Update to include android_vr first if missing (fixes "Only images" when Node/EJS fails)
    if ! grep -q -- 'player_client=android_vr' "$YT_DLP_CONFIG_FILE" 2>/dev/null; then
        sed -i "s|youtube:player_client=[^ ]*|youtube:player_client=$PLAYER_CLIENTS|" "$YT_DLP_CONFIG_FILE"
        echo "[install_yt_dlp_ejs_node][$(timestamp)] Updated player_client to $PLAYER_CLIENTS (android_vr first, no JS needed)." >&2
    else
        echo "[install_yt_dlp_ejs_node][$(timestamp)] yt-dlp config already has android_vr player_client." >&2
    fi
else
    {
        echo ""
        echo "# YouTube: android_vr first (no JS runtime), then tv/tv_embedded (no PO token)"
        echo "# With --cookies-from-browser, android_vr/android are skipped; if EJS fails, run without cookies for public videos"
        echo "--extractor-args youtube:player_client=$PLAYER_CLIENTS"
    } >> "$YT_DLP_CONFIG_FILE"
    echo "[install_yt_dlp_ejs_node][$(timestamp)] Added default player_client=$PLAYER_CLIENTS." >&2
fi

# Append PO Token Guide reference to config if not already present
if [[ -f "$YT_DLP_CONFIG_FILE" ]] && ! grep -q "PO-Token-Guide" "$YT_DLP_CONFIG_FILE" 2>/dev/null; then
    {
        echo ""
        echo "# YouTube 403 workaround: PO Token Guide https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide"
        echo "# Manual PO token: put GVS token in ~/.zen/game/nostr/<player>/.youtube.potoken (one line, no spaces)"
    } >> "$YT_DLP_CONFIG_FILE"
fi

echo "[install_yt_dlp_ejs_node][$(timestamp)] yt-dlp EJS configuration completed (runtime: $JS_RUNTIME)." >&2
echo "[install_yt_dlp_ejs_node][$(timestamp)] If downloads fail with cookies (only images): try without --cookies-from-browser for public videos (android_vr will be used)." >&2
echo "[install_yt_dlp_ejs_node][$(timestamp)] If EJS fails (Signature/n challenge solving failed): see docs/YT_DLP_EJS.md (Node version, Deno, debug)." >&2

