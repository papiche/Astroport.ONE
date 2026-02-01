#!/usr/bin/env python3
"""
ASTROBOT G1 value opportunities analyzer.

Fetches Ğchange offers around GPS coordinates, then uses question.py (Ollama)
to identify value-creation opportunities (finished products from local offers).
Designed to be triggered by SECTOR key in NOSTR.UMAP.refresh.sh.
"""

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.parse
import urllib.error

BASE_URL = "https://data.gchange.fr"
EXCLUDED_CATEGORY_IDS = ["cat27", "cat26", "cat25"]
EXCLUDED_CATEGORY_PARENTS = ["cat66", "cat8", "cat75", "cat71"]


def fetch_offers_elasticsearch(lat: float, lon: float, distance_km: int, max_results: int) -> list:
    """Fetch offers via Elasticsearch (same as gchange_service.dart, valid JSON)."""
    one_year_ago = int(time.time()) - 365 * 86400
    category_must_not = (
        [{"term": {"category.id": id}} for id in EXCLUDED_CATEGORY_IDS]
        + [{"term": {"category.parent": p}} for p in EXCLUDED_CATEGORY_PARENTS]
    )
    body = {
        "size": max_results,
        "_source": {"include": ["title", "category"]},
        "query": {
            "bool": {
                "filter": [
                    {"term": {"type": "offer"}},
                    {"range": {"creationTime": {"gte": str(one_year_ago)}}},
                    {"range": {"stock": {"gte": 1}}},
                    {
                        "geo_distance": {
                            "distance": f"{distance_km}km",
                            "geoPoint": {"lat": lat, "lon": lon},
                        }
                    },
                ],
                "must": [
                    {"exists": {"field": "geoPoint"}},
                    {"nested": {"path": "category", "query": {"bool": {"must_not": category_must_not}}}},
                ],
            }
        },
    }
    url = f"{BASE_URL}/market/record/_search"
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode())
    except (urllib.error.URLError, json.JSONDecodeError) as e:
        print(f"ES API error: {e}", file=sys.stderr)
        return []
    hits = (data or {}).get("hits", {}).get("hits") or []
    offers = []
    for hit in hits:
        src = (hit or {}).get("_source") or {}
        title = src.get("title") or ""
        if title:
            offers.append({"title": title})
    return offers


def fetch_offers_simple_api(lat: float, lon: float, distance_km: int, max_results: int) -> list:
    """Fetch offers via simplified _api (fallback; response may be invalid JSON)."""
    params = {
        "type": "offer",
        "size": str(max_results * 2),
        "lat": str(lat),
        "lon": str(lon),
        "distance": f"{distance_km}km",
    }
    url = f"{BASE_URL}/market/_api?{urllib.parse.urlencode(params)}"
    try:
        with urllib.request.urlopen(url, timeout=30) as resp:
            raw = resp.read().decode()
            data = json.loads(raw)
    except (urllib.error.URLError, json.JSONDecodeError):
        return []
    if not isinstance(data, list):
        return []
    offers = []
    for item in data:
        if not isinstance(item, dict):
            continue
        cat = item.get("category") or {}
        cat_id = cat.get("id") if isinstance(cat, dict) else None
        cat_parent = cat.get("parent") if isinstance(cat, dict) else None
        if cat_id in EXCLUDED_CATEGORY_IDS or cat_parent in EXCLUDED_CATEGORY_PARENTS:
            continue
        title = item.get("title") or ""
        if title:
            offers.append({"title": title})
        if len(offers) >= max_results:
            break
    return offers


def fetch_offers(lat: float, lon: float, distance_km: int, max_results: int) -> list:
    """Fetch Ğchange offers: try Elasticsearch first, then simple API."""
    offers = fetch_offers_elasticsearch(lat, lon, distance_km, max_results)
    if not offers:
        offers = fetch_offers_simple_api(lat, lon, distance_km, max_results)
    return offers


def build_opportunities_prompt(titles: list) -> str:
    """Build the same prompt as gemini_service for value opportunities (French)."""
    titles_text = "\n".join(f"- {t}" for t in titles)
    return f"""Tu es un expert en économie circulaire et en création de valeur locale.

Voici une liste de titres d'annonces de vente (offres) provenant d'une place de marché locale en monnaie libre (Ğ1) :

{titles_text}

À partir de cette liste, identifie des opportunités de création de valeur. C'est-à-dire des PRODUITS FINIS qui pourraient être fabriqués/réalisés en utilisant comme "consommations intermédiaires" (matières premières, ingrédients, composants) les produits/services proposés dans ces annonces.

Par exemple :
- Si tu vois "tomates bio", "poivrons", "oignons", "huile d'olive" → tu peux suggérer "Sauce provençale" ou "Ratatouille"
- Si tu vois "laine brute", "teinture naturelle" → tu peux suggérer "Écharpe tricotée artisanale"
- Si tu vois "cours de cuisine", "légumes bio", "épices" → tu peux suggérer "Atelier cuisine avec panier garni"

Règles importantes :
1. Ne suggère que des produits finis RÉALISTES et réalisables avec les annonces disponibles
2. Chaque produit fini doit utiliser AU MOINS 2 annonces différentes de la liste
3. Privilégie les combinaisons créatives et à forte valeur ajoutée
4. Indique clairement quels titres d'annonces correspondent à chaque ingrédient
5. Réponds en français, de façon concise, avec des listes lisibles (pas de JSON obligatoire)."""


def main():
    parser = argparse.ArgumentParser(
        description="G1 value opportunities: fetch Ğchange offers and analyze with question.py (Ollama)."
    )
    parser.add_argument("--lat", type=float, required=True, help="Latitude (sector center).")
    parser.add_argument("--lon", type=float, required=True, help="Longitude (sector center).")
    parser.add_argument(
        "--distance-km",
        type=int,
        default=50,
        help="Search radius in km (default: 50).",
    )
    parser.add_argument(
        "--max",
        type=int,
        default=200,
        help="Max offers to fetch (default: 200).",
    )
    parser.add_argument(
        "--model",
        default="gemma3:12b",
        help="Ollama model for question.py (default: gemma3:12b).",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output final answer in JSON format.",
    )
    parser.add_argument(
        "--question-py",
        default=None,
        help="Path to question.py (default: same dir as this script).",
    )
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    question_py = args.question_py or os.path.join(script_dir, "question.py")
    if not os.path.isfile(question_py):
        print(json.dumps({"error": "question.py not found", "path": question_py}) if args.json else f"Error: question.py not found at {question_py}", file=sys.stderr)
        sys.exit(1)

    offers = fetch_offers(args.lat, args.lon, args.distance_km, args.max)
    titles = list({o["title"] for o in offers if o.get("title")})

    if not titles:
        out = json.dumps({"opportunities": [], "total_offers": 0, "unique_titles": 0}) if args.json else "No offers found in this sector."
        print(out)
        return

    prompt = build_opportunities_prompt(titles)
    cmd = [
        sys.executable,
        question_py,
        prompt,
        "--lat", str(args.lat),
        "--lon", str(args.lon),
        "--model", args.model,
    ]
    if args.json:
        cmd.append("--json")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120,
            cwd=script_dir,
        )
        answer = (result.stdout or "").strip()
        if result.returncode != 0 and not answer:
            err = (result.stderr or "").strip()
            answer = err or "Failed to get answer from Ollama."
        if args.json:
            try:
                obj = json.loads(answer)
                obj["total_offers"] = len(offers)
                obj["unique_titles"] = len(titles)
                print(json.dumps(obj))
            except json.JSONDecodeError:
                print(json.dumps({"answer": answer, "total_offers": len(offers), "unique_titles": len(titles)}))
        else:
            print(answer)
    except subprocess.TimeoutExpired:
        msg = "question.py timed out."
        print(json.dumps({"error": msg}) if args.json else msg, file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        msg = str(e)
        print(json.dumps({"error": msg}) if args.json else msg, file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
