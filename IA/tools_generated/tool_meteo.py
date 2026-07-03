"""
Outil météo autonome : récupère la météo actuelle d'une ville via l'API
publique wttr.in (aucune clé d'API requise).

Usage :
    from meteo_tool import run
    print(run("Quelle est la météo à Marseille en ce moment ?"))
"""

import json
import re
from urllib.parse import quote

import requests

_TIMEOUT = 10

# Mots/expressions parasites à retirer d'une requête en langage naturel
_STOPWORDS = [
    "quelle est la météo",
    "quelle est la meteo",
    "quel temps fait-il",
    "quel temps fait il",
    "quel temps fait",
    "météo actuelle",
    "meteo actuelle",
    "la météo",
    "la meteo",
    "météo",
    "meteo",
    "what's the weather",
    "what is the weather",
    "weather",
    "en ce moment",
    "maintenant",
    "aujourd'hui",
    "aujourdhui",
    "ce soir",
    "right now",
    "now",
]

# Motifs "préposition + ville" (FR/EN)
_PATTERNS = [
    r"\bà\s+([A-Za-zÀ-ÖØ-öø-ÿ'\-\s]+?)(?=\s+(?:en ce moment|maintenant|aujourd'hui|ce soir)\b|[?!.]|$)",
    r"\ba\s+([A-Za-zÀ-ÖØ-öø-ÿ'\-\s]+?)(?=\s+(?:en ce moment|maintenant|aujourd'hui|ce soir)\b|[?!.]|$)",
    r"\bin\s+([A-Za-z'\-\s]+?)(?=\s+(?:right now|now|today)\b|[?!.]|$)",
    r"\bfor\s+([A-Za-z'\-\s]+?)(?=[?!.]|$)",
]


def _extract_city(query: str) -> str:
    """Extrait un nom de ville depuis une requête en langage naturel."""
    q = query.strip()

    for pattern in _PATTERNS:
        match = re.search(pattern, q, flags=re.IGNORECASE)
        if match:
            city = match.group(1).strip(" ?!.,'\"")
            if city:
                return city

    # Repli : on nettoie la requête des mots parasites et on garde le reste
    cleaned = q
    for word in _STOPWORDS:
        cleaned = re.sub(re.escape(word), "", cleaned, flags=re.IGNORECASE)
    cleaned = cleaned.strip(" ?!.,'\"")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned


def run(query: str) -> str:
    """
    Récupère la météo actuelle d'une ville mentionnée dans `query`.

    Retourne toujours une chaîne :
      - en cas de succès : un JSON avec ville, temperature_c, condition,
        humidite_pct, vent_kmh
      - en cas d'échec : un message d'erreur texte incluant le détail
        technique réel (exception ou code HTTP)
    """
    ville = _extract_city(query)

    if not ville:
        return (
            "Erreur : impossible d'identifier une ville dans la requête "
            f"'{query}'."
        )

    url = f"https://wttr.in/{quote(ville)}"
    params = {"format": "j1", "lang": "fr"}

    try:
        response = requests.get(url, params=params, timeout=_TIMEOUT)
    except requests.exceptions.RequestException as e:
        return f"Erreur réseau lors de l'appel à wttr.in : {e}"

    if response.status_code != 200:
        return (
            f"Erreur API wttr.in : code HTTP {response.status_code} "
            f"- {response.text[:200]}"
        )

    try:
        data = response.json()
        current = data["current_condition"][0]

        temperature_c = int(current["temp_C"])
        humidite_pct = int(current["humidity"])
        vent_kmh = int(current["windspeedKmph"])

        condition_fr = current.get("lang_fr")
        if condition_fr:
            condition = condition_fr[0]["value"]
        else:
            condition = current["weatherDesc"][0]["value"]

    except (ValueError, KeyError, IndexError, TypeError) as e:
        return f"Erreur API : réponse wttr.in inattendue - {e}"

    resultat = {
        "ville": ville,
        "temperature_c": temperature_c,
        "condition": condition,
        "humidite_pct": humidite_pct,
        "vent_kmh": vent_kmh,
    }

    return json.dumps(resultat, ensure_ascii=False)


if __name__ == "__main__":
    print(run("Quelle est la météo à Marseille en ce moment ?"))