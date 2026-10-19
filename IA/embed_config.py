#!/usr/bin/env python3
"""
embed_config.py — UNE source de vérité pour le modèle d'embedding de la plateforme IA
(mémoire de BRO, routage d'intention, rubriques de veille, regroupement des demandes d'ARBOR,
index des connaissances / du code). Stdlib seule : importable partout, y compris sans le venv.

Modèle : bge-m3 (1024 d, 1,2 Go, 100 langues, 8k tokens) — choisi le 2026-10-19 après mesure.
nomic-embed-text, utilisé jusque-là, ne séparait pas le pertinent du hors-sujet en français :
  • souvenirs personnels : 35 % de bonne réponse en 1er (bge-m3 : 98 %), score hors-sujet = score pertinent ;
  • routage d'intention au seuil historique : 13 commandes sur 30 reconnues et 9 phrases sur 30 prises à
    tort pour une commande (bge-m3 : 21 sur 30 et 3 sur 30) ;
  • rubriques de veille au seuil historique 0,70 : 4 posts pertinents sur 15 retrouvés (bge-m3 : 14 sur 15).

Changer de modèle = changer EMBED_MODEL / EMBED_DIM (variables d'environnement) ET ré-indexer :
chaque consommateur refuse (ou recrée, si la collection est reconstructible) une collection dont la
dimension diffère — jamais de mélange silencieux de deux espaces vectoriels.

Les SEUILS dépendent du modèle : ceux de bge-m3 ont été mesurés (jeux de test dans la session du
2026-10-19 : souvenirs FR, routage d'intention, rubriques, regroupement). Un autre modèle retombe sur
les valeurs de `_DEFAULT` : à re-mesurer avant usage.
"""
import json
import os
import urllib.request

MODEL = os.environ.get("EMBED_MODEL", "bge-m3")
DIM = int(os.environ.get("EMBED_DIM", "1024"))
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")

# Seuils par usage (cosinus, sauf intent_margin = meilleur positif − meilleur négatif).
#   recall        souvenir personnel pertinent pour une question (bons ≥ 0,56 ; hors-sujet ≤ 0,55)
#   topic         texte d'un post ↔ mots-clés d'une rubrique de veille (pertinents ≥ 0,41 ; hors-sujet ≤ 0,49)
#   intent_margin routage d'une phrase vers une commande (bon outil : médiane +0,23 ; hors-sujet : max +0,18)
#   cluster       deux formulations d'UNE même demande (même demande ≥ 0,63 ; demandes différentes ≤ 0,60)
#   doc           passage de document / de code ↔ une question (extrapolé du seuil de rappel)
THRESHOLDS = {
    "bge-m3": {"recall": 0.50, "topic": 0.46, "intent_margin": 0.13, "cluster": 0.61, "doc": 0.50},
    # ancien modèle, conservé pour mémoire / retour arrière ; seuils HISTORIQUES (peu fiables, cf. plus haut)
    "nomic-embed-text": {"recall": 0.72, "topic": 0.70, "intent_margin": 0.05, "cluster": 0.68, "doc": 0.65},
}
_DEFAULT = THRESHOLDS["bge-m3"]


def threshold(name):
    """Seuil `name` du modèle courant (variable d'environnement EMBED_T_<NAME> prioritaire)."""
    env = os.environ.get(f"EMBED_T_{name.upper()}")
    if env:
        return float(env)
    return THRESHOLDS.get(MODEL, _DEFAULT)[name]


def embed(text, model=None, timeout=60):
    """Vecteur de `text` via Ollama (/api/embed). Lève une erreur claire : jamais un [] silencieux
    qui deviendrait un point Qdrant vide ou une recherche sans résultat « normale »."""
    model = model or MODEL
    import gpu_headroom                       # GPU partagé avec ComfyUI : GpuBusy (RuntimeError) s'il n'y a pas la place
    gpu_headroom.ensure(model)
    body = json.dumps({"model": model, "input": text[:12000]}).encode()
    req = urllib.request.Request(f"{OLLAMA_URL}/api/embed", body, {"Content-Type": "application/json"})
    import ollama_metrics
    _t0 = ollama_metrics.start()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            data = json.load(r)
    except Exception as e:
        ollama_metrics.record("embed", model, _t0, ok=False, error=e, n_inputs=1)
        raise
    ollama_metrics.record("embed", model, _t0, resp=data, n_inputs=1)
    vecs = data.get("embeddings") or []
    if not vecs or not vecs[0]:
        raise RuntimeError(f"embedding vide renvoyé par {model}")
    vec = vecs[0]
    if model == MODEL and len(vec) != DIM:
        raise RuntimeError(f"{model} renvoie {len(vec)} dimensions, {DIM} attendues (EMBED_DIM)")
    return vec


def check_collection_dim(have, name=""):
    """Lève si une collection existante n'a pas la dimension du modèle courant."""
    if have and int(have) != DIM:
        raise RuntimeError(f"collection {name} : vecteurs de {have} dimensions, {DIM} attendues ({MODEL}) "
                           f"— ré-indexer, ne rien mélanger")


if __name__ == "__main__":
    print(json.dumps({"model": MODEL, "dim": DIM, "thresholds": THRESHOLDS.get(MODEL, _DEFAULT)}, indent=1))
