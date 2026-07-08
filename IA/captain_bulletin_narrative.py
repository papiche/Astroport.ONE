#!/usr/bin/env python3
"""
captain_bulletin_narrative.py — Narration IA du bulletin hebdomadaire capitaine.

Remplace le texte générique du bulletin (templates/UPlanetZINE/day_/captain.html)
par un court paragraphe personnalisé, généré par Ollama à partir de :
  - LifeOS du capitaine : identity/.Core.md, .Style.md, .Preferences.md,
    .Objectifs.md (lus directement, PAS via question.py --user-id — ce
    mécanisme fait jouer à Ollama le rôle du capitaine lui-même, alors
    qu'on veut ici un message ÉCRIT AU capitaine, pas PAR lui — même
    distinction que N2.journal.sh::generate_ai_prompt "write TO the player,
    not about them").
  - Vrais chiffres économiques de la semaine : snapshot local
    ~/.zen/tmp/<IPFSNODEID>/economy_health.json (écrit par
    RUNTIME/ECONOMY.broadcast.sh, même JSON que le kind 30850 NOSTR).
  - Ce que BRO a fait pour ce capitaine cette semaine : IA/observability.py
    digest() sur ~/.zen/flashmem/<email>/observability/activity.jsonl.

Best-effort de bout en bout : toute source manquante est simplement omise
du prompt ; un échec Ollama fait sortir une chaîne vide (jamais d'exception
— l'appelant bash doit pouvoir faire `AI=$(... 2>/dev/null)` sans risque).

Usage :
    python3 captain_bulletin_narrative.py --email captain@example.com \
        [--ipfsnodeid <hex>] [--model gemma3:12b]
"""

import sys
import os
import re
import json
import argparse
from datetime import datetime, timedelta, timezone

MY_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, MY_DIR)

_HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)

HEALTH_LABELS = {
    "healthy":           "Niveau 0 — Abondance",
    "assets_solidarity":  "Niveau 1 — Solidarité Actifs",
    "rnd_solidarity":     "Niveau 2 — Solidarité R&D",
    "volunteer":          "Niveau 3 — Bénévolat Actif",
}


def _read_identity_file(email: str, filename: str) -> str:
    path = os.path.expanduser(f"~/.zen/game/nostr/{email}/identity/{filename}")
    try:
        with open(path, encoding="utf-8") as f:
            content = _HTML_COMMENT_RE.sub("", f.read()).strip()
    except Exception:
        return ""
    return content


def load_lifeos(email: str) -> str:
    """Concatène Core/Style/Préférences/Objectifs — Rules.md est un garde-fou
    de comportement pour BRO, sans valeur narrative pour ce bulletin."""
    parts = []
    for filename, label in (
        (".Core.md", "Qui il est"),
        (".Style.md", "Ton préféré"),
        (".Preferences.md", "Préférences"),
        (".Objectifs.md", "Objectifs en cours"),
    ):
        content = _read_identity_file(email, filename)
        if content:
            parts.append(f"{label} :\n{content}")
    return "\n\n".join(parts)


def load_economy_snapshot(ipfsnodeid: str) -> dict:
    if not ipfsnodeid:
        return {}
    path = os.path.expanduser(f"~/.zen/tmp/{ipfsnodeid}/economy_health.json")
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}


def format_economy_context(data: dict) -> str:
    if not data:
        return ""
    health = data.get("health", {})
    alloc = data.get("allocation", {})
    capacity = data.get("capacity", {})
    revenue = data.get("revenue", {})

    status_key = health.get("status", "")
    status_label = HEALTH_LABELS.get(status_key, status_key or "inconnu")
    runway = health.get("weeks_runway", "?")

    mp = capacity.get("multipass", {})
    zc = capacity.get("zencard", {})

    lines = [
        f"- Résilience : {status_label} (autonomie estimée : {runway} semaines)",
        f"- Revenus de la semaine : {revenue.get('total_ht', '?')} Ẑen "
        f"(MULTIPASS: {mp.get('used', '?')}/{mp.get('total', '?')} · "
        f"ZEN Card: {zc.get('renters', '?')}/{zc.get('total', '?')})",
        f"- Répartition du surplus : Trésorerie {alloc.get('treasury', '?')}Ẑ · "
        f"R&D {alloc.get('rnd', '?')}Ẑ · Actifs Communs {alloc.get('assets', '?')}Ẑ",
    ]
    return "\n".join(lines)


def load_bro_activity_digest(email: str) -> str:
    try:
        import observability
    except Exception:
        return ""
    since = (datetime.now(timezone.utc) - timedelta(days=7)).strftime("%Y-%m-%dT%H:%M:%S%z")
    try:
        return observability.digest(email, since_ts=since)
    except Exception:
        return ""


def build_prompt(email: str, lifeos: str, economy_ctx: str, activity_digest: str) -> str:
    sections = [
        f"Tu es BRO, l'assistant IA personnel du capitaine d'une station Astroport.ONE "
        f"({email}). Rédige-lui un court message pour son bulletin hebdomadaire — tu "
        f"lui ÉCRIS DIRECTEMENT (2e personne, \"tu\"), tu ne parles jamais à sa place."
    ]
    if lifeos:
        sections.append(f"PROFIL DU CAPITAINE (pour adapter le ton et le contenu) :\n{lifeos}")
    if economy_ctx:
        sections.append(f"CHIFFRES RÉELS DE LA SEMAINE :\n{economy_ctx}")
    if activity_digest:
        sections.append(f"CE QUE BRO A FAIT POUR LUI CETTE SEMAINE :\n{activity_digest}")

    sections.append(
        "CONSIGNES :\n"
        "- Un seul paragraphe de 3 à 5 phrases courtes, pas de saut de ligne.\n"
        "- Commente les chiffres réels en clair (pas de jargon), sans les répéter tous.\n"
        "- Si un objectif en cours est mentionné dans le profil, fais-y une allusion "
        "discrète et encourageante.\n"
        "- Ton chaleureux mais professionnel, adapté au style préféré du capitaine "
        "s'il est précisé.\n"
        "- Pas de markdown, pas de listes, 1-2 emojis maximum.\n"
        "- Commence directement par le contenu, sans salutation ni introduction."
    )
    return "\n\n".join(sections)


def generate(email: str, ipfsnodeid: str, model: str) -> str:
    lifeos = load_lifeos(email)
    economy_ctx = format_economy_context(load_economy_snapshot(ipfsnodeid))
    activity_digest = load_bro_activity_digest(email)

    if not economy_ctx and not lifeos:
        # Rien à raconter — l'appelant doit se replier sur le texte statique.
        return ""

    prompt = build_prompt(email, lifeos, economy_ctx, activity_digest)

    try:
        from question import get_ollama_answer
    except Exception:
        return ""

    try:
        answer = get_ollama_answer(
            prompt, model_name=model,
            system_prompt="Réponds en français uniquement, sans markdown.",
            temperature=0.5, num_predict=250,
        )
    except Exception:
        return ""

    if not answer:
        return ""

    # Un seul paragraphe : neutralise tout saut de ligne et les caractères
    # qui casseraient la substitution sed en aval (RUNTIME/PLAYER.refresh.sh
    # utilise `~` comme délimiteur, `&` a un sens spécial dans une replacement sed).
    answer = " ".join(answer.split())
    answer = answer.replace("~", "-").replace("&", "et")
    return answer.strip()


def main():
    parser = argparse.ArgumentParser(description="Narration IA du bulletin hebdomadaire capitaine.")
    parser.add_argument("--email", required=True)
    parser.add_argument("--ipfsnodeid", default="")
    parser.add_argument("--model", default="gemma3:12b")
    args = parser.parse_args()

    try:
        print(generate(args.email, args.ipfsnodeid, args.model))
    except Exception:
        # Dégradation totale silencieuse — l'appelant bash ne doit jamais
        # planter à cause de ce script.
        print("")


if __name__ == "__main__":
    main()
