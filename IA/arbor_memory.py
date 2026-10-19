#!/usr/bin/env python3
"""
arbor_memory.py — la MÉMOIRE d'ARBOR (le codeur de la station) : ce qu'il sait du code, et de ce qu'il a déjà tenté.

Avant ce module, ARBOR repartait de zéro à chaque tâche : aucune connaissance du dépôt (la collection `codebase`
n'était lue que par BRO) et aucun souvenir de ses essais — il pouvait refaire, mot pour mot, une forge qui avait
déjà échoué pour une cause connue. Deux mémoires, une seule base Qdrant, un seul modèle d'embedding (embed_config) :

  CODE   collection `codebase` (admin/ia_db/codebase_index.py : un vecteur par FONCTION / classe / bloc, avec son
         numéro de ligne). search_code() / code_context() : « où le dépôt fait-il déjà ça, et comment ? ».
         Lecture seule : ARBOR n'écrit JAMAIS dans un fichier existant (doctrine d'arbor_chat.py).

  RUNS   collection `arbor_memory` : un point par tentative (forge, forge-scraper, explore, apply…) avec son
         résultat (ok / failed) et sa CAUSE. similar_runs() / runs_context() : « ai-je déjà essayé ça, et que s'est-il
         passé ? » — injecté dans le prompt pour ne pas répéter une approche qui a échoué.
         Contrairement à `codebase` (reconstructible en relançant l'index), cet historique est IRREMPLAÇABLE : un
         changement de modèle d'embedding lève une erreur au lieu de le recréer.

Jamais bloquant : les appelants entourent chaque appel d'un try/except qui DIT l'échec (jamais de repli muet) —
ARBOR doit pouvoir travailler même si Qdrant ou Ollama sont indisponibles, mais sans prétendre avoir consulté sa mémoire.
Aucun secret n'entre dans l'historique (memory_manager.unstorable_reason sur la cause et le but).
"""
import hashlib
import json
import os
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import embed_config as ec          # noqa: E402
import memory_manager as mm        # noqa: E402  (_curl : Qdrant avec clé d'API, échecs bruyants)

CODE_COLLECTION = "codebase"
RUNS_COLLECTION = "arbor_memory"
MAX_REASON = 600


def _qdrant(method, path, payload=None):
    return mm._curl(method, f"{mm.QDRANT_URL}{path}", payload)


def _scrub(text):
    """Texte sans secret ; remplacé en entier (et on le dit) s'il en contient un."""
    text = (text or "").strip()
    if mm.unstorable_reason(text):
        return "(détail masqué : un secret y a été détecté)"
    return text[:MAX_REASON]


# ── CODE ────────────────────────────────────────────────────────────────────
def search_code(query, limit=5, project=None, min_score=None):
    """Morceaux de code les plus proches du sens de `query`, au-dessus du seuil « doc » (0,50 pour bge-m3).
    → [{path, symbol, kind, start_line, end_line, score, text, project}]. Lève si Ollama/Qdrant échouent."""
    vec = ec.embed(query)
    body = {"vector": vec, "limit": limit * 2, "with_payload": True,
            "score_threshold": ec.threshold("doc") if min_score is None else min_score}
    if project:
        body["filter"] = {"must": [{"key": "project", "match": {"value": project}}]}
    res = _qdrant("POST", f"/collections/{CODE_COLLECTION}/points/search", body)
    if "result" not in res:
        raise RuntimeError(f"recherche dans `{CODE_COLLECTION}` impossible (Qdrant a répondu sans résultat)")
    out, seen = [], set()
    for h in res["result"]:
        p = h.get("payload", {})
        key = (p.get("path"), p.get("symbol"))
        if key in seen:
            continue
        seen.add(key)
        out.append({"path": p.get("path", ""), "symbol": p.get("symbol", ""), "kind": p.get("kind", ""),
                    "start_line": p.get("start_line"), "end_line": p.get("end_line"),
                    "score": round(h.get("score", 0.0), 3), "text": p.get("text") or p.get("preview", ""),
                    "project": p.get("project", "")})
        if len(out) >= limit:
            break
    return out


def code_context(query, limit=4, max_chars=3200, project=None):
    """Bloc de texte prêt à glisser dans un prompt (« '' » si rien de pertinent)."""
    hits = search_code(query, limit=limit, project=project)
    if not hits:
        return ""
    per = max(400, max_chars // max(1, len(hits)))
    parts = ["Code EXISTANT du dépôt, en LECTURE SEULE — pour t'aligner sur ses conventions et en réutiliser les "
             "idées. Ne le modifie pas et ne l'importe pas (ton résultat doit rester autonome) :"]
    for h in hits:
        lines = f"{h['start_line']}-{h['end_line']}" if h.get("start_line") else "?"
        parts.append(f"### {h['path']}:{lines} — {h['symbol']} (pertinence {h['score']})\n```\n{h['text'][:per]}\n```")
    return "\n\n".join(parts)


# ── RUNS (tentatives passées) ───────────────────────────────────────────────
def _ensure_runs_collection():
    info = _qdrant("GET", f"/collections/{RUNS_COLLECTION}")
    if info.get("result"):
        have = ((info["result"].get("config", {}).get("params", {}).get("vectors") or {}).get("size"))
        ec.check_collection_dim(have, RUNS_COLLECTION)      # lève : l'historique n'est PAS reconstructible
        return
    _qdrant("PUT", f"/collections/{RUNS_COLLECTION}", {"vectors": {"size": ec.DIM, "distance": "Cosine"}})


def record_run(kind, goal, outcome, reason="", files=None, branch="", attempts=None, extra=None):
    """Enregistre une tentative. outcome ∈ ok | failed. `reason` : la CAUSE (dernière erreur, raison du rejet…)."""
    if outcome not in ("ok", "failed"):
        raise ValueError("outcome doit valoir ok ou failed")
    goal = _scrub(goal) or "(sans but)"
    _ensure_runs_collection()
    at = datetime.now(timezone.utc).isoformat()
    payload = {"kind": kind, "goal": goal, "outcome": outcome, "reason": _scrub(reason), "files": list(files or [])[:20],
               "branch": branch, "attempts": attempts, "at": at, "embed_model": ec.MODEL}
    if extra:
        payload.update(extra)
    pid = int(hashlib.sha256(f"{kind}|{goal}|{at}".encode()).hexdigest()[:15], 16)
    r = _qdrant("PUT", f"/collections/{RUNS_COLLECTION}/points",
                {"points": [{"id": pid, "vector": ec.embed(f"{kind} : {goal}"), "payload": payload}]})
    if not r:
        raise RuntimeError("écriture dans l'historique d'ARBOR impossible")
    return pid


def similar_runs(goal, kind=None, limit=3):
    """Tentatives passées dont le BUT ressemble à `goal` (seuil « cluster » : même demande reformulée)."""
    _ensure_runs_collection()
    body = {"vector": ec.embed(f"{kind or ''} : {goal}".strip(" :")), "limit": limit, "with_payload": True,
            "score_threshold": ec.threshold("cluster")}
    if kind:
        body["filter"] = {"must": [{"key": "kind", "match": {"value": kind}}]}
    res = _qdrant("POST", f"/collections/{RUNS_COLLECTION}/points/search", body)
    if "result" not in res:
        raise RuntimeError(f"recherche dans `{RUNS_COLLECTION}` impossible")
    return [dict(h.get("payload", {}), score=round(h.get("score", 0.0), 3)) for h in res["result"]]


def runs_context(goal, kind=None, limit=3):
    """Bloc de prompt « tentatives passées similaires » ('' s'il n'y en a pas)."""
    runs = similar_runs(goal, kind=kind, limit=limit)
    if not runs:
        return ""
    lines = ["Tentatives PASSÉES d'ARBOR sur des buts voisins — tires-en les leçons, ne répète pas une approche "
             "qui a échoué :"]
    for r in sorted(runs, key=lambda r: r.get("at", ""), reverse=True):
        mark = "✅ réussi" if r.get("outcome") == "ok" else "❌ ÉCHEC"
        why = f" — cause : {r['reason']}" if r.get("reason") else ""
        tries = f", {r['attempts']} tentative(s)" if r.get("attempts") else ""
        lines.append(f"- [{mark}] {r.get('kind')} le {str(r.get('at', ''))[:10]}{tries} : « {r.get('goal')} »{why}")
    return "\n".join(lines)


def memory_context(goal, kind=None, code_limit=4, max_chars=3200):
    """Les DEUX mémoires pour un but donné, chacune isolée : l'échec de l'une n'empêche pas l'autre, et il est
    DIT (stderr) — on ne prétend jamais avoir consulté ce qu'on n'a pas pu lire. → (texte, [avertissements])."""
    blocks, warns = [], []
    for label, fn in (("historique", lambda: runs_context(goal, kind=kind)),
                      ("code", lambda: code_context(goal, limit=code_limit, max_chars=max_chars))):
        try:
            b = fn()
            if b:
                blocks.append(b)
        except Exception as e:
            w = f"mémoire d'ARBOR ({label}) indisponible : {e}"
            print(f"[arbor_memory] ⚠️ {w}", file=sys.stderr)
            warns.append(w)
    return "\n\n".join(blocks), warns


def safe_record(kind, goal, outcome, **kw):
    """record_run qui ne casse JAMAIS la tâche d'ARBOR, mais dit l'échec."""
    try:
        return record_run(kind, goal, outcome, **kw)
    except Exception as e:
        print(f"[arbor_memory] ⚠️ tentative non enregistrée ({kind}/{outcome}) : {e}", file=sys.stderr)
        return None


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser(description="Mémoire d'ARBOR")
    sub = p.add_subparsers(dest="cmd", required=True)
    a = sub.add_parser("code"); a.add_argument("query"); a.add_argument("--limit", type=int, default=5)
    b = sub.add_parser("runs"); b.add_argument("goal"); b.add_argument("--kind")
    c = sub.add_parser("record"); c.add_argument("kind"); c.add_argument("goal"); c.add_argument("outcome")
    c.add_argument("--reason", default="")
    sub.add_parser("stats")
    args = p.parse_args()
    if args.cmd == "code":
        for h in search_code(args.query, limit=args.limit):
            print(f"{h['score']:.3f}  {h['path']}:{h['start_line']}  {h['symbol']}")
    elif args.cmd == "runs":
        print(runs_context(args.goal, kind=args.kind) or "(aucune tentative voisine)")
    elif args.cmd == "record":
        print(record_run(args.kind, args.goal, args.outcome, reason=args.reason))
    elif args.cmd == "stats":
        for col in (CODE_COLLECTION, RUNS_COLLECTION):
            r = _qdrant("GET", f"/collections/{col}").get("result") or {}
            print(f"{col}: {r.get('points_count', 'absente')} points")
