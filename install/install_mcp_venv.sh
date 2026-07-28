#!/bin/bash
########################################################################
# install_mcp_venv.sh
# Crée un venv Python ISOLÉ ($HOME/.astro-mcp) pour le SDK `mcp` (client
# Model Context Protocol), utilisé par IA/mcp_client.py.
#
# Pourquoi un venv séparé de $HOME/.astro : `mcp` tire `starlette` vers une
# version incompatible avec fastapi==0.110.0 (UPassport, même venv .astro).
# Constaté : "ERROR: pip's dependency resolver ... starlette<0.37.0, but you
# have starlette 1.3.1". Isoler évite qu'un futur `pip install -U` sur le
# venv principal ne casse UPassport en amont d'un changement non demandé.
########################################################################

set -euo pipefail

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

MCP_VENV="${MCP_VENV:-$HOME/.astro-mcp}"

if [[ -d "$MCP_VENV" ]] && ! "$MCP_VENV/bin/python3" -c "print('ok')" &>/dev/null; then
    echo "[install_mcp_venv][$(timestamp)] Venv corrompu — recréation de $MCP_VENV" >&2
    rm -rf "$MCP_VENV"
fi

if [[ ! -s "$MCP_VENV/bin/activate" ]]; then
    python3 -m venv "$MCP_VENV" \
        && echo "[install_mcp_venv][$(timestamp)] Venv créé : $MCP_VENV" >&2 \
        || { echo "[install_mcp_venv][$(timestamp)] ERROR: création venv échouée — python3-venv installé ?" >&2
             exit 1; }
fi

if "$MCP_VENV/bin/pip" install -U mcp 2>&1 | tail -5; then
    echo "[install_mcp_venv][$(timestamp)] SDK mcp installé/à jour dans $MCP_VENV" >&2
else
    echo "[install_mcp_venv][$(timestamp)] ERROR: échec d'installation du SDK mcp" >&2
    exit 1
fi

"$MCP_VENV/bin/python3" -c "import mcp" \
    && echo "[install_mcp_venv][$(timestamp)] Vérification OK" >&2
