#!/usr/bin/env python3
"""
bro.identity — Biographie/identité durable du propriétaire (templates + mise à jour synthétisée de .Preferences.md, jamais un append pur).

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
import observability
from prompt_safety import wrap_untrusted
from bro._shared import BRO_IA_PATH, BRO_WATCH_CORE_PATH, COMMAND_INTERPRETATION_MODEL, PYTHON_BIN, _now_iso, _owner_dir

__all__ = ['_dispatch_identity_update_check', '_check_and_update_identity', 'MAX_PREFERENCES_LINES', '_synthesize_preferences', '_IDENTITY_TEMPLATES', '_ensure_identity_templates', 'PREFERENCES_HISTORY_MAX_ENTRIES', 'list_preferences_history', 'rollback_preferences']



def _dispatch_identity_update_check(owner_email, content):
    """Lance _check_and_update_identity en tâche détachée — évaluation LLM
    non bloquante déclenchée par #rec (qui doit rester une réponse rapide et
    déterministe). Échec silencieux : un problème ici ne doit jamais affecter
    la confirmation de mémorisation déjà renvoyée à l'utilisateur."""
    try:
        subprocess.Popen(
            ["python3", BRO_WATCH_CORE_PATH, "run-identity-check-background", owner_email, content],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True,
        )
    except Exception as e:
        print(f"[BRO_WATCH] Échec du lancement de l'évaluation identité : {e}")

def _check_and_update_identity(owner_email, content):
    """Évalue si un souvenir #rec révèle une préférence/contrainte durable
    (santé, alimentation, habitude de vie...) et, si oui, l'ajoute
    silencieusement à identity/.Preferences.md — la différence entre une IA
    qui prend des notes et une IA qui met à jour son jumeau numérique. Jamais
    de réponse à l'utilisateur ici (silencieux par design, cf. nom) : seule
    une entrée d'observabilité trace la mise à jour pour l'audit du capitaine.
    Dégradation sûre : toute erreur ou classification "false" ne fait rien —
    dans le doute, ne pas polluer le profil vaut mieux qu'une fausse maj."""
    prompt = (
        "Un utilisateur a confié cette information à son assistant IA personnel :\n"
        f"{wrap_untrusted('user_note', content)}\n\n"
        "Est-ce une préférence ou contrainte PERSONNELLE DURABLE (santé, "
        "allergie, alimentation, habitude de vie...) qui mérite d'être retenue "
        "dans son profil, au-delà d'un simple souvenir ponctuel ?\n\n"
        "Réponds UNIQUEMENT en JSON, sans texte autour : "
        '{"update": true|false, "line": "reformulation courte à la 2e personne"}\n'
        "Si update=false, line doit être une chaîne vide. Dans le doute, réponds "
        "false — mieux vaut rater une mise à jour que polluer le profil avec du bruit."
    )
    try:
        result = subprocess.run([
            PYTHON_BIN, f"{BRO_IA_PATH}/question.py", prompt,
            "--temperature", "0.1", "--model", COMMAND_INTERPRETATION_MODEL,
            "--format-json",
        ], capture_output=True, text=True, timeout=30)
        data = json.loads(result.stdout.strip())
        should_update = bool(data.get("update"))
        line = (data.get("line") or "").strip()
    except Exception as e:
        print(f"[BRO_WATCH] Évaluation identité échouée pour {owner_email} : {e}")
        return
    if not should_update or not line:
        return
    _ensure_identity_templates(owner_email)
    path = os.path.join(_owner_dir(owner_email), "identity", ".Preferences.md")
    try:
        existing = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    except Exception:
        existing = ""
    lines = _synthesize_preferences(existing, line)
    if lines is None:
        observability.log_event(owner_email, "identity_auto_update", "preferences", success=False)
        print(f"[BRO_WATCH] Échec synthèse Preferences.md pour {owner_email} — document inchangé.")
        return
    # Journal AVANT la réécriture : si le LLM hallucine ou tronque une
    # information dans _synthesize_preferences (ex: "allergique aux noix"
    # disparaît), rien n'est irrémédiablement perdu — #pref rollback restaure
    # l'état d'avant. Best-effort, ne bloque jamais la mise à jour elle-même.
    _append_preferences_history(owner_email, existing, line, lines)
    try:
        with open(path, "w", encoding="utf-8") as f:
            f.write("\n".join(f"- {l}" for l in lines) + "\n")
        observability.log_event(owner_email, "identity_auto_update", "preferences",
                                 success=True, extra={"line": line})
        print(f"[BRO_WATCH] Profil synthétisé pour {owner_email} : +{line!r}")
    except Exception as e:
        observability.log_event(owner_email, "identity_auto_update", "preferences", success=False)
        print(f"[BRO_WATCH] Échec écriture Preferences.md pour {owner_email} : {e}")

MAX_PREFERENCES_LINES = 40  # même esprit que skill_flashmem.MAX_LINES = 100

def _synthesize_preferences(existing_content, new_line):
    """Réécrit .Preferences.md en fusionnant new_line — dédup + résolution des
    contradictions par le LLM (la plus récente l'emporte), plutôt qu'un append
    qui ferait grossir le fichier indéfiniment (question.py::load_identity le
    charge intégralement dans le system prompt). Retourne la liste de lignes
    (sans le préfixe "- "), ou None si l'appel échoue — dégradation sûre : ne
    rien écrire plutôt qu'un document tronqué ou corrompu."""
    prompt = (
        "Voici le document actuel des préférences durables d'un utilisateur "
        "(une ligne = une préférence) :\n"
        f"{wrap_untrusted('current_preferences', existing_content or '(vide)')}\n\n"
        "Nouvelle information à intégrer :\n"
        f"{wrap_untrusted('new_preference', new_line)}\n\n"
        "Réécris le document COMPLET en intégrant cette nouvelle information : "
        "déduplique les redondances, et en cas de contradiction entre une ancienne "
        "et une nouvelle préférence, garde la plus récente (la nouvelle information "
        "l'emporte). Réponds UNIQUEMENT en JSON, sans texte autour : "
        '{"lines": ["préférence 1", "préférence 2", ...]}\n'
        f"Maximum {MAX_PREFERENCES_LINES} lignes — si le total dépasse, garde les "
        "plus importantes/récentes."
    )
    try:
        result = subprocess.run([
            PYTHON_BIN, f"{BRO_IA_PATH}/question.py", prompt,
            "--temperature", "0.1", "--model", COMMAND_INTERPRETATION_MODEL,
            "--format-json",
        ], capture_output=True, text=True, timeout=30)
        data = json.loads(result.stdout.strip())
        lines = data.get("lines")
        if not isinstance(lines, list):
            return None
        return [str(l).strip() for l in lines if str(l).strip()][:MAX_PREFERENCES_LINES]
    except Exception:
        return None

PREFERENCES_HISTORY_MAX_ENTRIES = 100  # fenêtre glissante, même esprit que skill_flashmem.MAX_LINES

def _preferences_history_path(owner_email):
    return os.path.join(_owner_dir(owner_email), "identity", ".Preferences.history.jsonl")

def _append_preferences_history(owner_email, before_content, trigger_line, after_lines):
    """Journal append-only d'audit/rollback — un JSON par réécriture de
    .Preferences.md, AVANT que celle-ci ne soit appliquée. `before_content`
    est le contenu COMPLET précédent (jamais perdu, contrairement au fichier
    vivant qui lui est écrasé) — voir rollback_preferences()."""
    entry = {
        "timestamp": _now_iso(),
        "before": before_content,
        "trigger_line": trigger_line,
        "after": "\n".join(f"- {l}" for l in after_lines) + "\n",
    }
    path = _preferences_history_path(owner_email)
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        _trim_preferences_history(path)
    except Exception as e:
        print(f"[BRO_WATCH] Échec journalisation historique Preferences pour {owner_email} : {e}")

def _trim_preferences_history(path):
    """Fenêtre glissante — écriture atomique (tmp+os.replace), même pattern
    que short_memory.py/save_plan (jamais de fichier tronqué sur crash)."""
    try:
        with open(path, encoding="utf-8") as f:
            lines = f.readlines()
        if len(lines) <= PREFERENCES_HISTORY_MAX_ENTRIES:
            return
        lines = lines[-PREFERENCES_HISTORY_MAX_ENTRIES:]
        tmp = f"{path}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.writelines(lines)
        os.replace(tmp, path)
    except Exception:
        pass

def list_preferences_history(owner_email, limit=10):
    """Retourne les `limit` dernières entrées d'historique (ordre
    chronologique croissant : la dernière de la liste est la plus récente)."""
    path = _preferences_history_path(owner_email)
    if not os.path.isfile(path):
        return []
    entries = []
    try:
        with open(path, encoding="utf-8") as f:
            for raw_line in f:
                raw_line = raw_line.strip()
                if not raw_line:
                    continue
                try:
                    entries.append(json.loads(raw_line))
                except Exception:
                    continue
    except Exception:
        return []
    return entries[-limit:]

def rollback_preferences(owner_email, steps_back=1):
    """Restaure .Preferences.md à l'état d'AVANT la Nième réécriture la plus
    récente (steps_back=1 -> annule la dernière mise à jour, 2 -> annule les
    deux dernières, etc.). Écriture atomique. Retourne (ok: bool, message)."""
    entries = list_preferences_history(owner_email, limit=steps_back)
    if steps_back < 1 or len(entries) < steps_back:
        return False, f"Pas assez d'historique pour remonter de {steps_back} étape(s)."
    target = entries[-steps_back]
    path = os.path.join(_owner_dir(owner_email), "identity", ".Preferences.md")
    try:
        tmp = f"{path}.tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(target["before"])
        os.replace(tmp, path)
        return True, f"Restauré à l'état d'avant : « {target.get('trigger_line', '?')} »"
    except Exception as e:
        return False, f"Échec de la restauration : {e}"

_IDENTITY_TEMPLATES = {
    ".Core.md": (
        "<!--\n"
        "  Qui es-tu ? Ton métier, ta mission, ce qui te définit.\n"
        "  Écris librement en dessous de ce commentaire — BRO le lira à chaque réponse.\n"
        "-->\n"
    ),
    ".Style.md": (
        "<!--\n"
        "  Ton ton : tutoiement ou vouvoiement, concis ou verbeux, emojis préférés,\n"
        "  expressions à éviter ou à privilégier.\n"
        "-->\n"
    ),
    ".Rules.md": (
        "<!--\n"
        "  Ce que BRO ne doit jamais faire ou dire en ton nom.\n"
        "-->\n"
    ),
    ".Preferences.md": (
        "<!--\n"
        "  Tes préférences et contraintes personnelles (santé, alimentation,\n"
        "  centres d'intérêt...). BRO peut proposer d'y ajouter une ligne quand\n"
        "  tu lui confies une information durable via #rec.\n"
        "-->\n"
    ),
    ".Objectifs.md": (
        "<!--\n"
        "  Tes objectifs en cours, un par ligne, au format checkbox :\n"
        "    - [ ] Avancer sur DevOps\n"
        "    - [x] Objectif déjà atteint (ignoré par BRO)\n"
        "  BRO relance ponctuellement sur un objectif non coché resté sans lien\n"
        "  avec la conversation récente (détecteur proactif 'goal_drift').\n"
        "-->\n"
    ),
}

def _ensure_identity_templates(owner_email):
    """Crée ~/.zen/game/nostr/<email>/identity/ avec les templates par défaut
    s'ils n'existent pas déjà — idempotent, n'écrase jamais un fichier
    existant (les corrections du capitaine sont définitives). Fichiers
    préfixés par un point : exclus de la publication IPNS de
    ~/.zen/game/nostr/<email>/ (ipfs add ignore les chemins cachés par
    défaut), l'identité reste privée à la station du capitaine."""
    identity_dir = os.path.expanduser(f"~/.zen/game/nostr/{owner_email}/identity")
    try:
        os.makedirs(identity_dir, exist_ok=True)
        for filename, default_content in _IDENTITY_TEMPLATES.items():
            path = os.path.join(identity_dir, filename)
            if not os.path.isfile(path):
                with open(path, "w", encoding="utf-8") as f:
                    f.write(default_content)
    except Exception as e:
        print(f"[BRO_WATCH] _ensure_identity_templates a échoué pour {owner_email} : {e}")
