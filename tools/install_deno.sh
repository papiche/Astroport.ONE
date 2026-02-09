#!/bin/bash
########################################################################
# install_deno.sh
# Install Deno to $HOME/.deno for yt-dlp EJS (YouTube JS challenge solver).
# Does not replace or conflict with Node (e.g. Node 18 for TiddlyWiki).
# See https://deno.com/ and https://github.com/yt-dlp/yt-dlp/wiki/EJS
########################################################################

set -euo pipefail

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

echo "[install_deno][$(timestamp)] Installing Deno for yt-dlp EJS (to \$HOME/.deno)" >&2

DENO_INSTALL="${DENO_INSTALL:-$HOME/.deno}"
export DENO_INSTALL

if [[ -x "$DENO_INSTALL/bin/deno" ]]; then
    echo "[install_deno][$(timestamp)] Deno already installed at $DENO_INSTALL/bin/deno" >&2
    "$DENO_INSTALL/bin/deno" --version
    echo "[install_deno][$(timestamp)] To configure yt-dlp to use it, run: ~/.zen/Astroport.ONE/tools/install_yt_dlp_ejs_node.sh" >&2
    exit 0
fi

# Official install script (installs to $HOME/.deno by default when DENO_INSTALL not set)
# CI=1 skips interactive shell setup (no .bashrc prompt); -y skips any remaining prompts
export CI=1
if ! curl -fsSL https://deno.land/install.sh | sh -s -- -y; then
    echo "[install_deno][$(timestamp)] ERROR: Deno install failed. Check network and https://deno.com/" >&2
    exit 1
fi

# Ensure PATH hint for current shell and future logins
if [[ -x "$DENO_INSTALL/bin/deno" ]]; then
    echo "[install_deno][$(timestamp)] Deno installed at $DENO_INSTALL/bin/deno" >&2
    "$DENO_INSTALL/bin/deno" --version
    echo "" >&2
    echo "Add to your shell profile (~/.bashrc or ~/.profile) if not already present:" >&2
    echo "  export DENO_INSTALL=\"\$HOME/.deno\"" >&2
    echo "  export PATH=\"\$DENO_INSTALL/bin:\$PATH\"" >&2
    echo "" >&2
    echo "[install_deno][$(timestamp)] Configure yt-dlp to use Deno: ~/.zen/Astroport.ONE/tools/install_yt_dlp_ejs_node.sh" >&2
else
    echo "[install_deno][$(timestamp)] ERROR: Deno binary not found after install." >&2
    exit 1
fi
