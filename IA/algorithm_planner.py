#!/usr/bin/env python3
"""
algorithm_planner.py — Plans multi-étapes résilients pour BRO ("mode ALGORITHM").

Contexte : la quasi-totalité des requêtes BRO sont traitées en un seul appel
Ollama zero-shot (question.py), y compris des demandes qui mériteraient d'être
découpées ("cherche X, résume, puis réponds"). Ce module ajoute un second mode,
réservé aux requêtes identifiées comme complexes par bro_watch_core.py::
classify_request_complexity() — PAS un moteur d'orchestration séparé, juste un
fichier d'état persistant par requête, pour deux raisons concrètes :

  1. Traçabilité : le capitaine peut relire ~/.zen/flashmem/<email>/plans/*.json
     pour voir ce que BRO a tenté, dans quel ordre, avec quel résultat.
  2. Résilience : si le sous-processus détaché qui exécute le plan est tué
     (OOM, redémarrage, timeout Ollama non rattrapé), le fichier reste sur
     disque avec ses étapes encore "pending". Le prochain passage de
     process_incoming_commands() (appelé régulièrement par bro_dm_daemon.sh/
     cron, indépendamment de ce module) retrouve le plan et reprend exactement
     où il s'était arrêté — jamais de perte de travail silencieuse.

Ce module ne sait PAS exécuter une étape (aucune dépendance à Ollama, Qdrant,
ou au registre bro_tools) — c'est le rôle de l'appelant (bro_watch_core.py),
qui lui fournit un `step_executor` (callable). Séparation volontaire, dans le
même esprit que bro_tools.py : ce module reste testable sans dépendance
réseau/disque autre que le fichier JSON lui-même.
"""

import os
import json
import time
import hashlib

PLANS_SUBDIR = "plans"
MAX_STEPS_PER_RUN = 6  # borne de sécurité : un seul appel ne boucle jamais indéfiniment


def _plans_dir(owner_email: str) -> str:
    return os.path.expanduser(f"~/.zen/flashmem/{owner_email}/{PLANS_SUBDIR}")


def _now_iso() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S%z")


def new_plan(owner_email: str, text: str, step_descriptions: list) -> dict:
    """Crée et persiste un nouveau plan — un fichier par requête, jamais
    modifié rétroactivement dans son texte d'origine (audit fiable)."""
    plan_id = f"{time.strftime('%Y%m%d-%H%M%S')}_{hashlib.md5(text.encode()).hexdigest()[:6]}"
    plan = {
        "id": plan_id,
        "owner_email": owner_email,
        "text": text,
        "status": "in_progress",
        "created_at": _now_iso(),
        "updated_at": _now_iso(),
        "steps": [
            {"n": i + 1, "description": desc, "status": "pending",
             "result": None, "started_at": None, "finished_at": None}
            for i, desc in enumerate(step_descriptions)
        ],
        "final_answer": None,
    }
    path = os.path.join(_plans_dir(owner_email), f"{plan_id}.json")
    save_plan(plan, path)
    plan["_path"] = path
    return plan


def save_plan(plan: dict, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    to_write = {k: v for k, v in plan.items() if k != "_path"}
    tmp = f"{path}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(to_write, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)  # écriture atomique — jamais de fichier tronqué lu par un lecteur concurrent


def load_plan(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        plan = json.load(f)
    plan["_path"] = path
    return plan


def find_incomplete_plan(owner_email: str) -> dict:
    """Le plus ancien plan encore "in_progress" pour cet utilisateur, ou None.
    Un seul plan actif à la fois suffit pour l'usage réel (un utilisateur ne
    lance pas 10 requêtes ALGORITHM en parallèle) — pas de file d'attente."""
    plans_dir = _plans_dir(owner_email)
    if not os.path.isdir(plans_dir):
        return None
    candidates = []
    for filename in os.listdir(plans_dir):
        if not filename.endswith(".json"):
            continue
        path = os.path.join(plans_dir, filename)
        try:
            plan = load_plan(path)
        except Exception:
            continue
        if plan.get("status") == "in_progress":
            candidates.append(plan)
    if not candidates:
        return None
    candidates.sort(key=lambda p: p.get("created_at", ""))
    return candidates[0]


def next_pending_step(plan: dict) -> dict:
    for step in plan["steps"]:
        if step["status"] == "pending":
            return step
    return None


def mark_step(plan: dict, step_n: int, status: str, result: str = None) -> None:
    """Mute le step en mémoire — l'appelant doit persister via save_plan()
    juste après, pour que la reprise voie l'état à jour même si le process
    est tué immédiatement après cet appel."""
    for step in plan["steps"]:
        if step["n"] == step_n:
            if step["status"] == "pending":
                step["started_at"] = _now_iso()
            step["status"] = status
            step["result"] = result
            step["finished_at"] = _now_iso()
            break
    plan["updated_at"] = _now_iso()


def is_complete(plan: dict) -> bool:
    return all(s["status"] != "pending" for s in plan["steps"])


def run_plan(plan: dict, step_executor, max_steps: int = MAX_STEPS_PER_RUN) -> bool:
    """Exécute jusqu'à `max_steps` étapes en attente, sauvegardant le plan
    après CHAQUE étape (pas seulement à la fin) — c'est ce qui rend la reprise
    possible : même tué au milieu, le disque reflète toujours la dernière
    étape réellement terminée.

    step_executor(step, plan) -> (success: bool, result: str)

    Retourne True si le plan est complet après cet appel (toutes les étapes
    ont un statut final), False s'il reste des étapes "pending" (plafond
    max_steps atteint — reprise au prochain passage)."""
    executed = 0
    while executed < max_steps:
        step = next_pending_step(plan)
        if not step:
            break
        try:
            success, result = step_executor(step, plan)
        except Exception as e:
            success, result = False, f"Erreur d'exécution : {e}"
        mark_step(plan, step["n"], "done" if success else "failed", result=result)
        save_plan(plan, plan["_path"])
        executed += 1
    return is_complete(plan)


def finalize_plan(plan: dict, final_answer: str) -> None:
    plan["final_answer"] = final_answer
    plan["status"] = "done"
    save_plan(plan, plan["_path"])
