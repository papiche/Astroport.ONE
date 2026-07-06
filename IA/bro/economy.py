#!/usr/bin/env python3
"""
bro.economy — Vérification du solde Ğ1 transférable (alerte proactive de solde bas).

Extrait de bro_watch_core.py (split du monolithe, aucune logique modifiée).
"""

import os
import re
import sys
import json
import time
import hashlib
import tempfile
import subprocess

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))  # IA/
from bro._shared import TOOLS_PATH, _owner_g1_pubkey

__all__ = ['LOW_G1_BALANCE_THRESHOLD_CENTIMES', '_check_low_g1_balance']



LOW_G1_BALANCE_THRESHOLD_CENTIMES = 100  # 1 G1 = 10 Ẑen (mode ORIGIN) ou 1€ (mode ZEN)

def _check_low_g1_balance(owner_email):
    """Détecteur : solde Ğ1 transférable sous LOW_G1_BALANCE_THRESHOLD_CENTIMES.
    Retourne un message d'alerte, ou None si le solde est correct ou la
    requête RPC/squid indisponible (dégradation gracieuse — jamais d'alerte
    sur une donnée non fiable)."""
    g1_pubkey = _owner_g1_pubkey(owner_email)
    if not g1_pubkey:
        return None
    script = os.path.join(TOOLS_PATH, "G1wallet_v2.sh")
    try:
        result = subprocess.run(
            ["bash", script, "balance", g1_pubkey, "--json"],
            capture_output=True, text=True, timeout=20,
        )
    except Exception:
        return None
    match = re.search(r"\{.*\}", result.stdout, re.DOTALL)
    if not match:
        return None
    try:
        data = json.loads(match.group(0))
    except Exception:
        return None
    if not data.get("rpc_ok"):
        return None  # source non fiable — ne jamais alerter sur une donnée douteuse
    transferable = data.get("rpc_transferable", 0)
    if transferable < LOW_G1_BALANCE_THRESHOLD_CENTIMES:
        return (f"Votre solde Ğ1 est bas : {transferable / 100:.2f} G1 restants "
                f"({transferable / 10:.1f} Ẑen). Pensez à réapprovisionner votre compte.")
    return None
