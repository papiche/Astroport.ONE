#!/usr/bin/env python3
"""
arbor_config.py — Lecture paresseuse des seuils ARBOR depuis la configuration
coopérative (cooperative_config.sh, Kind 30800 NOSTR), avec repli sur les
valeurs codées en dur d'arbor_self_improve.py/arbor_tool_forge.py si la clé
n'est pas définie — jamais de régression de comportement pour un usage CLI
qui n'est jamais passé par le panneau web NODE/ARBOR.

stdlib seule (pas d'import bro.* / bwc) : arbor_tool_forge.py importe
arbor_self_improve.py, qui importera ce module — un chargement au niveau
module coûterait un subprocess bash à chaque import, donc chaque appelant
lit à la demande (get_int/get_float/...), avec un cache par process.

Le clamp lo/hi est appliqué ICI, pas seulement côté validation HTTP
(services/coop_config.py::validate_value) : l'event Kind 30800 est partagé
par TOUTES les stations de la constellation (propagé par
backfill_constellation.sh) et n'est donc pas garanti d'avoir été écrit par
CETTE station en passant par la validation web.
"""

import os
import subprocess

TOOLS_PATH = os.path.expanduser("~/.zen/Astroport.ONE/tools")
_COOP_SCRIPT = os.path.join(TOOLS_PATH, "cooperative_config.sh")

_cache = None


def _load_all() -> dict:
    """Un seul subprocess par process, résultat mis en cache. Best-effort :
    {} silencieux sur n'importe quel échec (bash absent, jq absent, réseau
    NOSTR inaccessible sans cache local...) — jamais une exception qui
    casserait un run CLI/cron qui n'a jamais eu besoin de cette config."""
    global _cache
    if _cache is not None:
        return _cache
    _cache = {}
    if not os.path.isfile(_COOP_SCRIPT):
        return _cache
    try:
        import json
        proc = subprocess.run(
            ["bash", "-c", 'source "$1" >/dev/null 2>&1 && coop_load_config 2>/dev/null',
             "--", _COOP_SCRIPT],
            capture_output=True, text=True, timeout=20,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            _cache = json.loads(proc.stdout.strip())
    except Exception:
        pass
    return _cache


def _raw(key):
    config = _load_all()
    value = config.get(key)
    if not value or (isinstance(value, str) and value.strip() == ""):
        return None
    # Valeurs sensibles (nom de clé contenant TOKEN/SECRET/KEY/PASSWORD/API/
    # PRIVATE) sont chiffrées au repos — aucune clé ARBOR_* n'en fait partie
    # actuellement, donc jamais déchiffrées ici (pas de coop_decrypt).
    return value


def get_int(key, default, lo=None, hi=None) -> int:
    raw = _raw(key)
    if raw is None:
        return default
    try:
        val = int(float(str(raw).replace(",", ".")))
    except (ValueError, TypeError):
        return default
    if lo is not None:
        val = max(lo, val)
    if hi is not None:
        val = min(hi, val)
    return val


def get_float(key, default, lo=None, hi=None) -> float:
    raw = _raw(key)
    if raw is None:
        return default
    try:
        val = float(str(raw).replace(",", "."))
    except (ValueError, TypeError):
        return default
    if lo is not None:
        val = max(lo, val)
    if hi is not None:
        val = min(hi, val)
    return val


def get_bool(key, default) -> bool:
    raw = _raw(key)
    if raw is None:
        return default
    return str(raw).strip().lower() == "true"


def get_list(key, default) -> list:
    raw = _raw(key)
    if raw is None:
        return list(default)
    items = [s.strip() for s in str(raw).split(",") if s.strip()]
    return items or list(default)


def candidate_models(default_candidates):
    """Reconstruit la liste {id, model} attendue par arbor_self_improve.CANDIDATES
    depuis ARBOR_CANDIDATE_MODELS (CSV de noms de modèles Ollama), ou retourne
    les candidats par défaut codés en dur si la clé est absente."""
    import re as _re
    models = get_list("ARBOR_CANDIDATE_MODELS", [])
    if not models:
        return list(default_candidates)
    out = []
    for m in models:
        slug = _re.sub(r"[^a-z0-9]+", "-", m.lower()).strip("-")[:40] or "model"
        out.append({"id": f"model-{slug}", "model": m})
    return out
