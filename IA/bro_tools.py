#!/usr/bin/env python3
"""
bro_tools — Registre déclaratif des capacités que BRO peut invoquer.

Contexte : avant ce module, une même commande système (#mem, #reset, #rec…)
existait en DEUX endroits divergents — un dispatch #hashtag codé en dur dans
bro_watch_core.py (self-DM) et un texte d'aide statique séparé — sans lien
structurel entre les deux. Un tag ajouté d'un côté et oublié de l'autre a déjà
causé un incident réel (2026-07-03) : le LLM inventait des commandes qui
n'existaient nulle part. Ce module fournit UNE seule source de vérité par
outil : nom, description (utilisée à la fois pour le routage sémantique ET
injectée telle quelle dans le prompt de BRO, donc impossible à faire diverger
de ce qui est réellement exécuté), tags déclencheurs, exemples pour le corpus
de routage sémantique, niveau d'accès requis, et gestionnaire.

Ce module reste volontairement sans dépendance vers bro_watch_core (pas de
Qdrant, pas d'accès disque) pour éviter tout import circulaire : c'est
l'appelant (bro_watch_core.py, à terme d'autres connecteurs BRO/NODE) qui
enregistre ses propres fonctions comme handlers via register().

Niveaux d'accès (ACCESS_*) : reflètent uniquement ce qui est VÉRIFIABLE
aujourd'hui sur le canal considéré. Ne pas inventer de palier non contrôlé —
un outil dont l'accès réel n'est pas vérifiable doit répondre honnêtement
plutôt que de prétendre appliquer un contrôle qui n'existe pas (cf. craft/badge
sur le canal self-DM).
"""

import re
from dataclasses import dataclass, field

# Même échelle 0-5 que IA/bro_user_level.py::get_user_level (anonyme … locataire
# … atome … satellite … constellation … capitaine) — un SEUL barème d'accès
# dans tout le registre, qu'un outil vérifie son niveau via bro_user_level.py
# (craft/badge/rec:<skill>/mem:<skill>) ou via une vérification plus simple
# (ex: _is_captain() pour #arbor). Les paliers intermédiaires (atome=2,
# satellite=3, constellation=4) sont définis côté bro_watch_core.py
# (ACCESS_LEVEL_ATOME, ACCESS_LEVEL_SATELLITE) — seuls les deux bornes sont
# nécessaires ici, pour le filtre générique d'affichage de l'aide.
ACCESS_ANY = 0
ACCESS_CAPTAIN = 5


@dataclass
class Tool:
    name: str
    description: str
    handler: callable  # (owner_email: str, text: str) -> str | None
    tags: tuple = ()  # ex: ("mem",) -> déclenché par "#mem" n'importe où dans le texte
    examples: tuple = ()  # phrases positives pour le corpus de routage sémantique
    min_access: int = ACCESS_ANY
    source: str = "static"  # "static" (ce module) | "arbor" (outil forgé dynamiquement)
    advertise: bool = True  # inclus dans le texte d'aide/prompt LLM (False : dispo pour le
    # routage/l'exécution, mais pas mis en avant — ex. craft/badge, dont l'accès réel n'est
    # pas vérifiable sur ce canal, ne doivent pas être présentés comme disponibles)


TOOLS: dict[str, Tool] = {}


def register(tool: Tool) -> None:
    TOOLS[tool.name] = tool


def unregister(name: str) -> None:
    TOOLS.pop(name, None)


def get(name: str):
    return TOOLS.get(name)


def all_tools():
    return list(TOOLS.values())


def find_by_tag(text: str):
    """Match déterministe par #hashtag — toujours tenté AVANT tout scoring
    sémantique (un score de similarité peut se tromper, un #tag explicite
    jamais)."""
    for tool in TOOLS.values():
        for tag in tool.tags:
            if re.search(rf"#{re.escape(tag)}\b", text, re.IGNORECASE):
                return tool
    return None


def iter_examples():
    """(nom_outil, phrase) pour chaque exemple positif enregistré — alimente
    le corpus de routage sémantique côté appelant (Qdrant, embeddings...)."""
    for tool in TOOLS.values():
        for ex in tool.examples:
            yield tool.name, ex
