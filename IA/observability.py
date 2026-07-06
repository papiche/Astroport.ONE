#!/usr/bin/env python3
"""
observability.py — Journal d'activité structuré (JSONL) pour BRO.

Contexte : IA.log (~/.zen/tmp/IA.log) est un log texte libre multi-écrivains,
utile pour le débogage humain (tail -f) mais pas exploitable par du code — pas
de schéma, pas de champ tool/success/latence. Ce module ajoute une source
structurée EN PLUS de IA.log (ne le remplace pas), par utilisateur, pour deux
usages :
  1. Un futur résumé d'activité exposé dans 12345.json (tableau de bord).
  2. Enrichir le cycle RÊVE (memory_manager.reve_compress_slot) avec les
     actions techniques de la période compressée, pas seulement les messages —
     BRO peut alors se souvenir de CE QU'IL A FAIT, pas seulement de ce qui a
     été dit.

Format : ~/.zen/flashmem/<user_id>/observability/activity.jsonl, une ligne
JSON par évènement, ring buffer des ACTIVITY_RING_LIMIT dernières lignes
(cohérent avec les limites documentées dans SLOT_MEMORY_README.md).
"""

import os
import json
import time

ACTIVITY_RING_LIMIT = 200


def _activity_path(user_id: str) -> str:
    return os.path.expanduser(f"~/.zen/flashmem/{user_id}/observability/activity.jsonl")


def _ipfs_node_id() -> str:
    """Même convention que NIP-101/relay.writePolicy.plugin/filter/common.sh :
    lire le PeerID directement depuis ~/.ipfs/config plutôt que dépendre d'une
    variable d'environnement IPFSNODEID pas toujours exportée (ex: outils
    lancés hors du cycle RUNTIME, comme code_assistant)."""
    try:
        with open(os.path.expanduser("~/.ipfs/config"), encoding="utf-8") as f:
            return json.load(f).get("Identity", {}).get("PeerID", "") or "_local"
    except Exception:
        return "_local"


def _node_activity_path() -> str:
    return os.path.expanduser(f"~/.zen/tmp/{_ipfs_node_id()}/observability/node-activity.jsonl")


def log_node_event(script: str, action: str, success: bool, category: str = None,
                    latency_ms: float = None, extra: dict = None) -> None:
    """Pendant STATION/NODE de log_event() — même fichier que
    IA/bro/bro_common_lib.sh::bro_log_event() et NIP-101's nip101_log_event()
    (~/.zen/tmp/$IPFSNODEID/observability/node-activity.jsonl), même schéma
    (script/category/action/success/latency_ms). Pour les outils qui ne sont
    PAS rattachés à un utilisateur MULTIPASS précis (ex: code_assistant, un
    outil dev partagé par la station) — log_event()/user_id ne conviendrait
    pas ici. Échoue toujours silencieusement."""
    if not script:
        return
    path = _node_activity_path()
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        event = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "script": script,
            "action": action,
            "success": bool(success),
        }
        if category:
            event["category"] = category
        if latency_ms is not None:
            event["latency_ms"] = round(latency_ms, 1)
        if extra:
            event.update(extra)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")
        _trim_ring_buffer(path, ACTIVITY_RING_LIMIT)
    except Exception:
        pass


def log_event(user_id: str, tool: str, action: str, success: bool,
              latency_ms: float = None, extra: dict = None) -> None:
    """Append un évènement structuré. Échoue toujours silencieusement — un
    problème d'observabilité ne doit jamais faire planter le canal self-DM."""
    if not user_id or not tool:
        return
    path = _activity_path(user_id)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        event = {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "tool": tool,
            "action": action,
            "success": bool(success),
        }
        if latency_ms is not None:
            event["latency_ms"] = round(latency_ms, 1)
        if extra:
            event.update(extra)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")
        _trim_ring_buffer(path, ACTIVITY_RING_LIMIT)
    except Exception:
        pass


def _trim_ring_buffer(path: str, limit: int) -> None:
    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = f.readlines()
        if len(lines) > limit:
            with open(path, "w", encoding="utf-8") as f:
                f.writelines(lines[-limit:])
    except Exception:
        pass


def recent_events(user_id: str, limit: int = ACTIVITY_RING_LIMIT) -> list:
    """Derniers évènements structurés — utilisé par memory_manager.reve_compress_slot
    et par un futur résumé côté 12345.json."""
    path = _activity_path(user_id)
    if not os.path.isfile(path):
        return []
    try:
        with open(path, "r", encoding="utf-8") as f:
            lines = f.readlines()[-limit:]
    except Exception:
        return []
    events = []
    for line in lines:
        try:
            events.append(json.loads(line))
        except Exception:
            continue
    return events


def digest(user_id: str, since_ts: str = None, until_ts: str = None,
           limit: int = ACTIVITY_RING_LIMIT) -> str:
    """Résumé compact « outil : Nx (réussi/échoué) » des évènements de la
    période [since_ts, until_ts] (comparaison lexicographique ISO-8601, donc
    triable directement) — alimente le prompt de compression RÊVE sans le
    noyer sous des lignes JSON brutes."""
    events = recent_events(user_id, limit=limit)
    if since_ts:
        events = [e for e in events if e.get("timestamp", "") >= since_ts]
    if until_ts:
        events = [e for e in events if e.get("timestamp", "") <= until_ts]
    if not events:
        return ""
    counts = {}
    for e in events:
        key = (e.get("tool", "?"), bool(e.get("success")))
        counts[key] = counts.get(key, 0) + 1
    lines = [
        f"- {tool} : {n}x ({'réussi' if success else 'échoué'})"
        for (tool, success), n in sorted(counts.items(), key=lambda kv: -kv[1])
    ]
    return "\n".join(lines)
