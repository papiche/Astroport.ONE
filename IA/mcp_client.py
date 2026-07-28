#!/usr/bin/env python3
"""
mcp_client — Client MCP (Model Context Protocol) en Streamable HTTP, pour que
BRO (bro/tools.py) et d'autres appelants Python de IA/ invoquent des outils
exposés par des serveurs MCP distants (ex: data.gouv.fr).

Le SDK `mcp` vit dans un venv ISOLÉ ($HOME/.astro-mcp, voir
install/install_mcp_venv.sh), séparé du venv principal $HOME/.astro partagé
avec UPassport (FastAPI) — un `pip install mcp` dans le venv principal fait
monter `starlette` au-delà de ce que fastapi==0.110.0 tolère (constaté :
"ERROR: pip's dependency resolver ... starlette<0.37.0, but you have
starlette 1.3.1"). call_mcp_tool() lance donc ce fichier en sous-processus
sous l'interpréteur isolé plutôt que d'importer `mcp` dans le process
appelant — aucune dépendance `mcp` requise côté venv principal.
"""

import json
import os
import subprocess
import sys

MCP_SERVERS = {
    "datagouv": "https://mcp.data.gouv.fr/mcp",
}

# Identification honnête plutôt que le user-agent générique "python-httpx/x.y"
# — observé empiriquement : les appels répétés avec l'UA par défaut se sont
# heurtés à des 503 intermittents depuis "sorry.data.gouv.fr" (page de garde
# anti-abus typique d'un WAF), un UA identifiable réduit le risque d'être
# traité comme trafic automatisé anonyme.
USER_AGENT = "UPlanetBRO/1.0 (+https://astroport.one; contact: support@qo-op.com)"

MCP_VENV_PYTHON = os.path.expanduser("~/.astro-mcp/bin/python3")
DEFAULT_TIMEOUT = 10

# Les 503 observés vers "sorry.data.gouv.fr" pendant les tests (2 échecs sur 3
# à 2s d'intervalle) sont transitoires côté serveur, jamais reproductibles à
# l'identique — une ré-essai avec backoff couvre la grande majorité des cas
# sans reporter la latence sur l'utilisateur final au-delà du raisonnable.
RETRY_ATTEMPTS = 3
RETRY_BACKOFF_BASE = 1.0  # secondes ; backoff linéaire 1s, 2s entre tentatives
SUBPROCESS_MARGIN = 5  # secondes, marge pour le spawn Python + imports mcp


def is_available():
    """Le venv isolé (install/install_mcp_venv.sh) a-t-il été installé ? À
    vérifier avant d'enregistrer/annoncer un outil BRO adossé à ce module —
    ne jamais publier une capacité qui échouerait systématiquement."""
    return os.path.isfile(MCP_VENV_PYTHON)


def call_mcp_tool(server_key, tool_name, arguments=None, timeout=DEFAULT_TIMEOUT):
    """Appelle un outil d'un serveur MCP enregistré dans MCP_SERVERS, dans le
    venv isolé (avec ré-essais internes, voir _run_worker). Retourne le texte
    de la réponse, ou None (serveur inconnu, venv absent, injoignable même
    après ré-essais, ou outil en échec) — jamais d'exception : même
    discipline de dégradation silencieuse que bro/tools.py::_call_tool, pour
    que l'appelant retombe sur la conversation normale plutôt que de planter
    le canal self-DM."""
    if server_key not in MCP_SERVERS:
        print(f"[mcp_client] Serveur MCP inconnu : '{server_key}'")
        return None
    if not os.path.isfile(MCP_VENV_PYTHON):
        print(f"[mcp_client] venv isolé absent : {MCP_VENV_PYTHON} "
              f"(voir install/install_mcp_venv.sh)")
        return None
    # Budget temps du sous-processus : couvre TOUTES les tentatives internes
    # (timeout par tentative + backoff cumulé), sans quoi le sous-processus
    # serait tué en pleine ré-essai avant d'avoir pu se rétablir.
    worst_case = (timeout * RETRY_ATTEMPTS
                  + RETRY_BACKOFF_BASE * sum(range(1, RETRY_ATTEMPTS))
                  + SUBPROCESS_MARGIN)
    try:
        proc = subprocess.run(
            [MCP_VENV_PYTHON, os.path.abspath(__file__), "--worker",
             server_key, tool_name, json.dumps(arguments or {}), str(timeout)],
            capture_output=True, text=True, timeout=worst_case,
        )
    except subprocess.TimeoutExpired:
        print(f"[mcp_client] {server_key}/{tool_name} : timeout")
        return None
    if proc.returncode != 0:
        print(f"[mcp_client] {server_key}/{tool_name} indisponible : {proc.stderr.strip()}")
        return None
    return proc.stdout.strip() or None


def _flatten_result(result):
    """Un CallToolResult mélange texte et éventuels blocs non-textuels — seul
    le texte est utilisable par les handlers BRO (contrat str | None)."""
    if result is None:
        return None
    parts = [block.text for block in getattr(result, "content", ())
             if getattr(block, "type", None) == "text"]
    return "\n".join(parts) if parts else None


async def _call_async(server_url, tool_name, arguments, timeout):
    from mcp import ClientSession
    from mcp.client.streamable_http import streamablehttp_client

    async with streamablehttp_client(server_url, headers={"User-Agent": USER_AGENT},
                                      timeout=timeout) as (read, write, _):
        async with ClientSession(read, write) as session:
            await session.initialize()
            return await session.call_tool(tool_name, arguments or {})


def _run_worker(server_key, tool_name, arguments, timeout):
    """Exécuté UNIQUEMENT sous l'interpréteur du venv isolé $HOME/.astro-mcp —
    seul chemin de ce fichier où `import mcp` est atteint.

    Ré-essaie la connexion COMPLÈTE (nouvelle session à chaque tentative)
    plutôt que de tenter de réutiliser une session après échec : l'échec
    observé en pratique (503 depuis sorry.data.gouv.fr) survient dans le
    groupe de tâches anyio du transport lui-même, pas dans call_tool() —
    rien ne garantit qu'une session ayant subi cette erreur reste utilisable."""
    import asyncio
    import time

    server_url = MCP_SERVERS.get(server_key)
    if not server_url:
        print(f"Serveur MCP inconnu : '{server_key}'", file=sys.stderr)
        sys.exit(1)
    last_error = None
    for attempt in range(1, RETRY_ATTEMPTS + 1):
        try:
            result = asyncio.run(_call_async(server_url, tool_name, arguments, timeout))
            print(_flatten_result(result) or "")
            return
        except Exception as e:
            last_error = e
            if attempt < RETRY_ATTEMPTS:
                time.sleep(RETRY_BACKOFF_BASE * attempt)
    print(f"échec après {RETRY_ATTEMPTS} tentatives : {last_error}", file=sys.stderr)
    sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--worker":
        _server, _tool = sys.argv[2], sys.argv[3]
        _args = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
        _timeout = float(sys.argv[5]) if len(sys.argv) > 5 else DEFAULT_TIMEOUT
        _run_worker(_server, _tool, _args, _timeout)
    else:
        if len(sys.argv) < 3:
            print(f"Usage: {sys.argv[0]} <server> <tool> [json_arguments]")
            sys.exit(1)
        _server, _tool = sys.argv[1], sys.argv[2]
        _args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        _out = call_mcp_tool(_server, _tool, _args)
        print(_out if _out else "(aucune réponse)")
