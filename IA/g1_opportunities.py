#!/usr/bin/env python3
"""
ASTROBOT G1 value opportunities analyzer.

Fetches Ğchange offers and Leboncoin donations around GPS coordinates,
then uses question.py (Ollama) to identify value-creation opportunities
and synergies between paid G1 offers and free items.
Designed to be triggered at UMAP or SECTOR level in NOSTR.UMAP.refresh.sh.
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


def fetch_leboncoin_donations(lat: float, lon: float, distance_km: int, max_results: int, cookie_file: str) -> list:
    """Fetch Leboncoin donation ads via scraper_leboncoin.py if cookie exists."""
    if not cookie_file or not os.path.isfile(cookie_file):
        return []
    script_dir = os.path.dirname(os.path.abspath(__file__))
    scraper = os.path.join(script_dir, "scraper_leboncoin.py")
    if not os.path.isfile(scraper):
        return []
    radius_m = distance_km * 1000
    cmd = [
        sys.executable, scraper,
        cookie_file, "",
        str(lat), str(lon), str(radius_m),
        "--donation-only", "--owner-type", "private",
        "--json", "--limit", str(max_results),
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode != 0:
            print(f"Leboncoin scraper failed (exit {result.returncode})", file=sys.stderr)
            return []
        data = json.loads(result.stdout)
        ads = data.get("ads", [])
        donations = []
        for ad in ads:
            title = ad.get("subject", "").strip()
            if title:
                location = ad.get("location", {})
                city = location.get("city_label", "")
                donations.append({"title": title, "city": city})
        return donations
    except subprocess.TimeoutExpired:
        print("Leboncoin scraper timed out", file=sys.stderr)
        return []
    except (json.JSONDecodeError, Exception) as e:
        print(f"Leboncoin scraper error: {e}", file=sys.stderr)
        return []


def build_opportunities_prompt(g1_titles: list, lbc_titles: list = None) -> str:
    """Build prompt for value opportunities combining G1 offers and Leboncoin donations."""
    has_g1 = bool(g1_titles)
    has_lbc = bool(lbc_titles)

    sections = []
    if has_g1:
        g1_text = "\n".join(f"- [Ğ1] {t}" for t in g1_titles)
        sections.append(f"### Offres en monnaie libre Ğ1 (Ğchange)\n{g1_text}")
    if has_lbc:
        lbc_text = "\n".join(f"- [DON] {t}" for t in lbc_titles)
        sections.append(f"### Dons gratuits (Leboncoin)\n{lbc_text}")

    listings = "\n\n".join(sections)

    if has_g1 and has_lbc:
        source_intro = (
            "Voici deux sources d'annonces locales :\n"
            "1. **Offres Ğ1** — produits/services en monnaie libre (Ğchange)\n"
            "2. **Dons gratuits** — objets donnés sur Leboncoin\n\n"
        )
        synergy_rule = (
            "6. Identifie des **synergies** entre dons gratuits et offres Ğ1 "
            "(ex : un meuble donné + une peinture Ğ1 → meuble relooké à vendre en Ğ1)\n"
            "7. Indique la source [Ğ1] ou [DON] pour chaque ingrédient utilisé"
        )
    elif has_lbc:
        source_intro = (
            "Voici une liste d'objets donnés gratuitement sur Leboncoin dans le secteur :\n\n"
        )
        synergy_rule = (
            "6. Suggère comment ces dons pourraient être valorisés, transformés ou combinés "
            "pour créer de la valeur dans l'économie locale"
        )
    else:
        source_intro = (
            "Voici une liste de titres d'annonces de vente (offres) provenant "
            "d'une place de marché locale en monnaie libre (Ğ1) :\n\n"
        )
        synergy_rule = ""

    return f"""Tu es un expert en économie circulaire et en création de valeur locale.

{source_intro}{listings}

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
5. Réponds en français, de façon concise, avec des listes lisibles (pas de JSON obligatoire).
{synergy_rule}"""


def main():
    parser = argparse.ArgumentParser(
        description="G1 value opportunities: fetch Ğchange offers and Leboncoin donations, analyze with question.py (Ollama)."
    )
    parser.add_argument("--lat", type=float, required=True, help="Latitude (zone center).")
    parser.add_argument("--lon", type=float, required=True, help="Longitude (zone center).")
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
        help="Max offers to fetch per source (default: 200).",
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
    parser.add_argument(
        "--cookie",
        default=None,
        help="Path to Leboncoin cookie file (enables donation scraping).",
    )
    args = parser.parse_args()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    question_py = args.question_py or os.path.join(script_dir, "question.py")
    if not os.path.isfile(question_py):
        print(json.dumps({"error": "question.py not found", "path": question_py}) if args.json else f"Error: question.py not found at {question_py}", file=sys.stderr)
        sys.exit(1)

    # Fetch from both sources
    offers = fetch_offers(args.lat, args.lon, args.distance_km, args.max)
    g1_titles = list({o["title"] for o in offers if o.get("title")})

    donations = fetch_leboncoin_donations(args.lat, args.lon, args.distance_km, min(args.max, 50), args.cookie)
    lbc_titles = list({d["title"] for d in donations if d.get("title")})

    total_g1 = len(g1_titles)
    total_lbc = len(lbc_titles)

    if not g1_titles and not lbc_titles:
        out = json.dumps({"opportunities": [], "total_g1_offers": 0, "total_lbc_donations": 0}) if args.json else "No offers found in this zone."
        print(out)
        return

    if g1_titles or lbc_titles:
        print(f"Sources: {total_g1} Ğchange offers, {total_lbc} Leboncoin donations", file=sys.stderr)

    prompt = build_opportunities_prompt(g1_titles, lbc_titles or None)
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
                obj["total_g1_offers"] = total_g1
                obj["total_lbc_donations"] = total_lbc
                obj["unique_titles"] = total_g1 + total_lbc
                print(json.dumps(obj))
            except json.JSONDecodeError:
                print(json.dumps({"answer": answer, "total_g1_offers": total_g1, "total_lbc_donations": total_lbc, "unique_titles": total_g1 + total_lbc}))
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
