#!/usr/bin/env python3
"""
planet_oracle.py — Synastrie planétaire (Soleil, Lune, Mercure, Vénus, Mars,
Jupiter, Saturne)
Référence : matching indépendant du Kin (Astroport.ONE/tools/kin_oracle.sh,
RUNTIME/KIN.news.sh) et enrichissement des paires Tzolkin. Voir plan
toasty-jingling-nebula.md (phase 2).

Moteur : astronomy-engine (VSOP87) — port Python officiel du même projet
cosinekitty/astronomy que earth/astronomy.browser.min.js (utilisé côté JS par
lunar-calendar.js). Longitudes écliptiques géocentriques, zodiaque TROPICAL
(distinct du zodiaque sidéral utilisé par lunar-calendar.js pour la biodynamie).

Uranus/Neptune/Pluton volontairement exclues : leur mouvement est si lent
qu'elles partagent le même signe pendant des années entières — un aspect avec
ces planètes ne distingue quasiment jamais deux personnes du même âge, ça
diluerait le score sans ajouter de signal utile pour du matching.

Volontairement hors scope : Ascendant / Maisons (nécessitent une heure de
naissance fiable, or elle est optionnelle dans atomic.html, défaut 12:00).

Sortie JSON (contrairement à phi2x.py qui imprime du texte) : ce module est
consommé en masse par `jq` depuis kin_oracle.sh pour de nombreuses paires,
même logique que maya_kin_json() dans kin.sh.

Usage standalone :
  python3 planet_oracle.py --natal 1985-07-23 14:30 48.86 2.35
  python3 planet_oracle.py --synastry '<json_a>' '<json_b>'
  python3 planet_oracle.py --synastry @a.json @b.json
"""
import sys
import json
import argparse

try:
    import astronomy
except ImportError:
    astronomy = None

BODIES = ("sun", "moon", "mercury", "venus", "mars", "jupiter", "saturn")

ZODIAC_SIGNS = [
    "Bélier", "Taureau", "Gémeaux", "Cancer", "Lion", "Vierge",
    "Balance", "Scorpion", "Sagittaire", "Capricorne", "Verseau", "Poissons",
]
ELEMENTS = ["feu", "terre", "air", "eau"]              # cycle de 4 depuis Bélier
MODALITIES = ["cardinal", "fixe", "mutable"]           # cycle de 3 depuis Bélier

# 5 aspects majeurs : (nom, angle exact, orbe tolérée en degrés)
ASPECTS = [
    ("conjonction", 0, 8),
    ("sextile", 60, 4),
    ("carre", 90, 6),
    ("trigone", 120, 6),
    ("opposition", 180, 8),
]

# Pondération du score de synastrie par type d'aspect — trigone/sextile
# valorisés (harmonie), carré/opposition comptés positivement mais moins
# (tension productive, même ton que l'Antipode dans kin_prefs.sh)
ASPECT_WEIGHT = {
    "conjonction": 10,
    "sextile": 12,
    "trigone": 15,
    "carre": 6,
    "opposition": 9,
}

SCORE_BASELINE = 30.0  # plancher du score global — évite un score brutal à 0%

# Regroupement des aspects par thème relationnel — plus interprétable qu'un
# seul chiffre. Chaque paire est (corps_a, corps_b), non ordonnée.
CATEGORY_PAIRS = {
    "attraction":     [("venus", "mars")],
    "emotion":        [("moon", "moon"), ("moon", "venus")],
    "communication":  [("mercury", "mercury"), ("mercury", "venus"), ("mercury", "moon")],
    "vision":         [("sun", "jupiter"), ("sun", "saturn"), ("saturn", "saturn")],
}


def _pair_key(a, b):
    return tuple(sorted((a, b)))


CATEGORY_KEYS = {
    cat: {_pair_key(a, b) for a, b in pairs} for cat, pairs in CATEGORY_PAIRS.items()
}


def _zodiac_sign(longitude):
    idx = int(longitude // 30) % 12
    degree = longitude % 30
    return idx, ZODIAC_SIGNS[idx], round(degree, 2)


def _body_longitude(body_key, t):
    """Longitude écliptique géocentrique (degrés, [0,360)) d'un corps."""
    if body_key == "sun":
        return astronomy.SunPosition(t).elon
    if body_key == "moon":
        return astronomy.EclipticGeoMoon(t).lon
    body = getattr(astronomy.Body, body_key.capitalize())
    vec = astronomy.GeoVector(body, t, True)
    return astronomy.Ecliptic(vec).elon


def natal_planets(birth_date, birth_time="12:00", lat=0.0, lon=0.0):
    """Positions écliptiques géocentriques (tropicales) pour les 7 planètes classiques.

    birth_date: "YYYY-MM-DD", birth_time: "HH:MM" — traités comme UTC (pas de
    fuseau fiable côté ATOM4LOVE, imprécision assumée). lat/lon ne sont pas
    utilisés ici (longitudes géocentriques indépendantes du lieu d'observation),
    conservés pour un usage topocentrique/maisons futur.
    """
    if astronomy is None:
        raise RuntimeError("astronomy-engine non installé (pip install astronomy-engine)")
    year, month, day = (int(x) for x in birth_date.split("-"))
    hour, minute = (int(x) for x in birth_time.split(":"))
    t = astronomy.Time.Make(year, month, day, hour, minute, 0)

    result = {}
    for key in BODIES:
        longitude = _body_longitude(key, t) % 360
        idx, sign, degree = _zodiac_sign(longitude)
        result[key] = {
            "longitude": round(longitude, 3), "sign": sign,
            "sign_index": idx, "degree": degree,
        }
    return result


def compute_aspects(planets_a, planets_b):
    """Aspects majeurs entre deux jeux de positions natales (49 paires max)."""
    aspects = []
    for key_a, data_a in planets_a.items():
        for key_b, data_b in planets_b.items():
            diff = abs(data_a["longitude"] - data_b["longitude"]) % 360
            angle = min(diff, 360 - diff)
            for name, exact, orb in ASPECTS:
                delta = abs(angle - exact)
                if delta <= orb:
                    aspects.append({
                        "body_a": key_a, "body_b": key_b,
                        "aspect": name, "angle": round(angle, 2), "orb": round(delta, 2),
                    })
                    break
    aspects.sort(key=lambda a: a["orb"])
    return aspects


def _weighted_sum(aspects):
    """Somme pondérée brute (sans plancher) — 0 si aucun aspect."""
    total = 0.0
    for a in aspects:
        weight = ASPECT_WEIGHT.get(a["aspect"], 0)
        tightness = max(0.3, 1 - (a["orb"] / 10))
        total += weight * tightness
    return round(min(100.0, total), 1)


_GLOBAL_SCORE_TOP_N = 5  # nombre d'aspects les plus exacts retenus pour le score global


def synastry_score(aspects):
    """Score global 0-100 : plancher + somme des _GLOBAL_SCORE_TOP_N aspects
    les plus exacts. Limite volontaire : avec 7 planètes (49 paires possibles),
    sommer TOUS les aspects trouvés sature quasi systématiquement le score à
    100 et perd tout pouvoir discriminant entre les paires — ne garder que les
    aspects les plus serrés (orbe la plus faible) préserve un score qui
    distingue vraiment une bonne synastrie d'une synastrie moyenne."""
    top_aspects = sorted(aspects, key=lambda a: a["orb"])[:_GLOBAL_SCORE_TOP_N]
    return round(min(100.0, SCORE_BASELINE + _weighted_sum(top_aspects)), 1)


def category_scores(aspects):
    """Score 0-100 par thème (attraction/émotion/communication/vision) — sans
    plancher : 0 signifie littéralement aucun aspect majeur dans ce thème."""
    scores = {}
    for cat, keys in CATEGORY_KEYS.items():
        cat_aspects = [a for a in aspects if _pair_key(a["body_a"], a["body_b"]) in keys]
        scores[cat] = _weighted_sum(cat_aspects)
    return scores


def element_modality_balance(planets):
    """Répartition Feu/Terre/Air/Eau et Cardinal/Fixe/Mutable sur les 7 planètes."""
    elements, modalities = {}, {}
    for data in planets.values():
        idx = data["sign_index"]
        e, m = ELEMENTS[idx % 4], MODALITIES[idx % 3]
        elements[e] = elements.get(e, 0) + 1
        modalities[m] = modalities.get(m, 0) + 1
    return {"elements": elements, "modalities": modalities}


def element_compatibility(balance_a, balance_b):
    """Indice 0-100 de similarité des répartitions élémentaires — heuristique
    de "vue d'ensemble", robuste à l'imprécision de l'heure de naissance
    (contrairement aux aspects exacts, qui dépendent de la position fine)."""
    ea, eb = balance_a["elements"], balance_b["elements"]
    total_a = sum(ea.values()) or 1
    total_b = sum(eb.values()) or 1
    overlap = sum(min(ea.get(e, 0) / total_a, eb.get(e, 0) / total_b) for e in ELEMENTS)
    return round(overlap * 100, 1)


def synastry(planets_a, planets_b):
    aspects = compute_aspects(planets_a, planets_b)
    return {
        "score": synastry_score(aspects),
        "category_scores": category_scores(aspects),
        "element_compat": element_compatibility(
            element_modality_balance(planets_a), element_modality_balance(planets_b)
        ),
        "aspects": aspects,
        "top_aspect": aspects[0] if aspects else None,
    }


def _load_natal_arg(value):
    """Accepte du JSON inline ou '@fichier' (convention type curl)."""
    if value.startswith("@"):
        with open(value[1:]) as f:
            return json.load(f)
    return json.loads(value)


def main():
    parser = argparse.ArgumentParser(description="Oracle planétaire — synastrie ATOM4LOVE")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--natal", nargs=4, metavar=("DATE", "TIME", "LAT", "LON"))
    group.add_argument("--synastry", nargs=2, metavar=("JSON_A", "JSON_B"))
    args = parser.parse_args()

    if args.natal:
        date, birth_time, lat, lon = args.natal
        print(json.dumps(natal_planets(date, birth_time, float(lat), float(lon)), ensure_ascii=False))
        return

    planets_a = _load_natal_arg(args.synastry[0])
    planets_b = _load_natal_arg(args.synastry[1])
    print(json.dumps(synastry(planets_a, planets_b), ensure_ascii=False))


if __name__ == "__main__":
    main()
