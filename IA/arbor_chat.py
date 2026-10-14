#!/usr/bin/env python3
"""
arbor_chat.py — Dialogue conversationnel avec ARBOR pour le capitaine : pas un
formulaire (mode/need/slug), une discussion libre où le capitaine décrit ce
qu'il aimerait voir amélioré et Arbor propose, quand c'est pertinent, une
action concrète à valider (jamais exécutée depuis ce module — la proposition
est relue, approuvée et lancée via le même chemin que le bouton ▶ existant,
cf. node_admin.py::post_arbor_trigger).

Backend volontairement identique à arbor_tool_forge.py (Claude CLI, jamais
Ollama) — même doctrine : le conversationnel UTILISATEUR de BRO passe par
question.py/Ollama, le dialogue de GOUVERNANCE/FORGE avec Arbor passe par
Claude (jugé insuffisant par Ollama local pour un raisonnement de ce niveau,
cf. constat 2026-07-03 dans arbor_tool_forge.py).

Pas de mémoire persistée ici : l'historique de la conversation vit côté
client (navigateur) pour cette v1 — l'état qui compte réellement (bâton,
branches, audit) est déjà ré-interrogé à chaque tour depuis la source de
vérité (coop_config, git, arbor_run.sh), jamais depuis la conversation elle-
même.
"""

import sys
import os

_venv_python = os.path.expanduser("~/.astro/bin/python3")
if os.path.exists(_venv_python) and sys.executable != _venv_python:
    os.execv(_venv_python, [_venv_python] + sys.argv)

import re
import json

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from arbor_tool_forge import _ask_claude, claude_available  # noqa: E402

_TRAILING_JSON_RE = re.compile(r"```json\s*\n(.*?)```\s*$", re.DOTALL)

_SYSTEM_PROMPT = """Tu es Arbor, le système d'auto-amélioration de BRO (l'assistant IA personnel \
de la station Astroport.ONE). Tu dialogues avec le Capitaine de cette station pour définir \
ensemble les tâches que tu dois réaliser.

Tes capacités réelles (jamais plus) :
- mine-requests : détecte des patterns de besoins récurrents chez les utilisateurs (lecture seule)
- explore / apply : teste différents modèles Ollama candidats sur des cas réels, applique le meilleur
- forge : génère un NOUVEL outil Python autonome à partir d'un besoin décrit en langage naturel
- forge-scraper : génère un scraper pour un site web où un cookie a été déposé sans scraper associé

Règles absolues, à rappeler si le Capitaine les remet en cause :
- Tu ne modifies JAMAIS un fichier existant du dépôt — uniquement des fichiers neufs, dans une \
branche git isolée (worktree), jamais mergée automatiquement.
- Toute génération de code passe par une revue humaine avant merge — tu ne pousses jamais rien seul.
- Le cycle automatique quotidien (mine-requests) est soumis au "bâton de parole" entre stations de \
la constellation — une seule station à la fois le fait tourner automatiquement, pour éviter les \
doublons. Le déclenchement MANUEL de tes autres capacités reste toujours possible sur cette station.

Contexte actuel de CETTE station (JSON) :
{context}

Réponds en français, de façon concise et directe (3-5 phrases maximum sauf si le Capitaine demande \
plus de détail). Pose des questions si le besoin décrit est ambigu plutôt que de proposer une action \
hasardeuse. Quand — et SEULEMENT quand — une action concrète et bien définie se dégage de l'échange, \
termine ta réponse par EXACTEMENT un bloc de ce format (rien d'autre après) :

```json
{{"proposed_action": {{"mode": "forge|forge-scraper|mine-requests|explore|apply", "need": "...", "slug": "..."}}}}
```

"need"/"slug" uniquement pertinents pour mode=forge (slug optionnel, minuscules/tirets). Omets \
totalement ce bloc tant qu'aucune action n'est prête à être proposée — ne force jamais une proposition."""


def _build_prompt(message: str, history: list, context: dict) -> str:
    parts = [_SYSTEM_PROMPT.format(context=json.dumps(context, ensure_ascii=False, indent=2))]
    for turn in history[-12:]:  # borne large mais finie — un historique de session reste court en pratique
        role = "Capitaine" if turn.get("role") == "user" else "Arbor"
        content = str(turn.get("content", ""))[:2000]
        parts.append(f"{role} : {content}")
    parts.append(f"Capitaine : {message}")
    parts.append("Arbor :")
    return "\n\n".join(parts)


def _extract_proposed_action(reply: str):
    match = _TRAILING_JSON_RE.search(reply.strip())
    if not match:
        return reply.strip(), None
    clean_reply = reply[: match.start()].strip()
    try:
        data = json.loads(match.group(1))
    except Exception:
        return reply.strip(), None
    action = data.get("proposed_action") if isinstance(data, dict) else None
    if not isinstance(action, dict) or not action.get("mode"):
        return clean_reply, None
    return clean_reply, action


def chat_turn(message: str, history: list, context: dict) -> dict:
    """Un tour de dialogue. Retourne {reply, proposed_action: dict|None, error: str|None}."""
    if not claude_available():
        return {
            "reply": "Le CLI Claude n'est pas disponible sur cette station — je ne peux pas dialoguer "
                      "pour le moment. Installez/authentifiez-le (claude.vscodium.setup.sh) puis réessayez.",
            "proposed_action": None,
            "error": "claude_cli_unavailable",
        }
    prompt = _build_prompt(message, history or [], context or {})
    raw = _ask_claude(prompt, timeout=90)
    if not raw:
        return {
            "reply": "Je n'ai pas pu répondre (le CLI Claude n'a rien renvoyé — voir les logs du service "
                      "pour le détail de l'erreur).",
            "proposed_action": None,
            "error": "empty_response",
        }
    reply, proposed_action = _extract_proposed_action(raw)
    return {"reply": reply, "proposed_action": proposed_action, "error": None}


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description="Dialogue CLI avec Arbor (debug)")
    parser.add_argument("message")
    parser.add_argument("--context", default="{}", help="JSON de contexte")
    args = parser.parse_args()
    result = chat_turn(args.message, [], json.loads(args.context))
    print(json.dumps(result, ensure_ascii=False, indent=2))
