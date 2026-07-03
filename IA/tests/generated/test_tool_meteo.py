"""
Tests pytest pour le module tool_meteo.

Le module expose : def run(query: str) -> str
Ces tests utilisent des assertions souples car la réponse dépend d'une API
météo externe (température, condition du jour, etc. varient dans le temps).
"""

import pytest

from tool_meteo import run


REQUETE_MARSEILLE = "Quelle est la météo à Marseille en ce moment ?"

# Mots-clés dont la présence (insensible à la casse) dans la réponse est
# attendue si l'appel à l'API a réussi.
MOTS_CLES_MARSEILLE = ["marseille"]
MOTS_CLES_METEO = [
    "temperature", "température", "condition", "humidite", "humidité",
    "vent", "°c", "celsius", "%",
]


def _appel_reseau_disponible(exc: Exception) -> bool:
    """Heuristique pour distinguer une erreur réseau (à ignorer en CI sans
    accès Internet) d'un vrai bug du module."""
    message = str(exc).lower()
    indices_reseau = [
        "connection", "timeout", "network", "resolve", "dns",
        "unreachable", "temporarily", "ssl",
    ]
    return any(indice in message for indice in indices_reseau)


class TestRunMeteoMarseille:
    """Vérifie le scénario nominal décrit dans la fiche de l'outil."""

    def test_run_retourne_une_chaine_non_vide(self):
        try:
            resultat = run(REQUETE_MARSEILLE)
        except Exception as exc:  # pragma: no cover - dépend du réseau
            if _appel_reseau_disponible(exc):
                pytest.skip(f"API météo indisponible dans cet environnement : {exc}")
            raise

        assert isinstance(resultat, str), "run() doit retourner une chaîne de caractères"
        assert resultat.strip() != "", "la réponse ne doit pas être vide"
        # Longueur minimale : une réponse météo digne de ce nom contient
        # plus qu'un simple mot ("ok", "erreur", etc.)
        assert len(resultat.strip()) >= 10

    def test_run_mentionne_la_ville_demandee(self):
        try:
            resultat = run(REQUETE_MARSEILLE)
        except Exception as exc:  # pragma: no cover - dépend du réseau
            if _appel_reseau_disponible(exc):
                pytest.skip(f"API météo indisponible dans cet environnement : {exc}")
            raise

        resultat_normalise = resultat.lower()
        assert any(mot in resultat_normalise for mot in MOTS_CLES_MARSEILLE), (
            f"la réponse devrait mentionner 'Marseille', reçu : {resultat!r}"
        )

    def test_run_contient_des_informations_meteo_pertinentes(self):
        try:
            resultat = run(REQUETE_MARSEILLE)
        except Exception as exc:  # pragma: no cover - dépend du réseau
            if _appel_reseau_disponible(exc):
                pytest.skip(f"API météo indisponible dans cet environnement : {exc}")
            raise

        resultat_normalise = resultat.lower()
        assert any(mot in resultat_normalise for mot in MOTS_CLES_METEO), (
            "la réponse devrait contenir au moins un indice météo "
            f"(température, condition, humidité, vent...), reçu : {resultat!r}"
        )


class TestRunMeteoGestionErreurs:
    """Vérifie que les cas d'échec restent silencieux côté appelant :
    pas d'exception non gérée, mais un message d'erreur exploitable."""

    def test_run_avec_ville_inexistante_ne_leve_pas_dexception(self):
        requete_invalide = "Quelle est la météo à Xyzzyvilledebrouille999 en ce moment ?"

        try:
            resultat = run(requete_invalide)
        except Exception as exc:
            if _appel_reseau_disponible(exc):
                pytest.skip(f"API météo indisponible dans cet environnement : {exc}")
            pytest.fail(
                "run() ne devrait pas lever d'exception pour une ville "
                f"inconnue, mais retourner un message d'erreur. Exception : {exc!r}"
            )
            return

        assert isinstance(resultat, str)
        assert resultat.strip() != "", (
            "en cas d'échec (ville inconnue), run() doit retourner un "
            "message d'erreur non vide plutôt qu'une chaîne vide"
        )

    def test_run_avec_requete_vide_reste_robuste(self):
        try:
            resultat = run("")
        except Exception as exc:
            if _appel_reseau_disponible(exc):
                pytest.skip(f"API météo indisponible dans cet environnement : {exc}")
            pytest.fail(
                "run() ne devrait pas lever d'exception sur une requête "
                f"vide, mais retourner un message d'erreur. Exception : {exc!r}"
            )
            return

        assert isinstance(resultat, str)
        assert resultat.strip() != ""