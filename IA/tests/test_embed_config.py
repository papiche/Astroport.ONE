"""embed_config.py — modèle et seuils uniques de la plateforme IA (sans Ollama : réseau simulé)."""
import io
import json
import os
os.environ.setdefault("OLLAMA_METRICS_OFF", "1")      # les tests ne polluent pas ~/.zen/log/ollama_calls_*.jsonl
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import embed_config as ec  # noqa: E402


class FakeResp(io.BytesIO):
    def __enter__(self): return self
    def __exit__(self, *a): return False


def resp(vec):
    return FakeResp(json.dumps({"embeddings": [vec]}).encode())


class EmbedConfigTests(unittest.TestCase):
    def test_modele_par_defaut_et_dimension(self):
        self.assertEqual((ec.MODEL, ec.DIM), ("bge-m3", 1024))

    def test_seuils_mesures_de_bge_m3(self):
        # valeurs mesurées le 2026-10-19 (cf. docstring) : les changer exige de re-mesurer
        self.assertEqual(ec.THRESHOLDS["bge-m3"], {"recall": 0.50, "topic": 0.46, "intent_margin": 0.13,
                                                   "cluster": 0.61, "doc": 0.50})

    def test_surcharge_par_environnement(self):
        with mock.patch.dict(os.environ, {"EMBED_T_TOPIC": "0.55"}):
            self.assertEqual(ec.threshold("topic"), 0.55)
        self.assertEqual(ec.threshold("topic"), 0.46)

    def test_modele_inconnu_retombe_sur_les_seuils_par_defaut(self):
        with mock.patch.object(ec, "MODEL", "modele-inconnu"):
            self.assertEqual(ec.threshold("recall"), ec._DEFAULT["recall"])

    def test_embed_valide_la_dimension(self):
        with mock.patch("urllib.request.urlopen", return_value=resp([0.1] * 1024)):
            self.assertEqual(len(ec.embed("bonjour")), 1024)
        with mock.patch("urllib.request.urlopen", return_value=resp([0.1] * 768)):
            with self.assertRaises(RuntimeError):          # jamais un vecteur nomic dans une collection bge-m3
                ec.embed("bonjour")

    def test_embed_vide_est_une_erreur_pas_un_silence(self):
        with mock.patch("urllib.request.urlopen", return_value=FakeResp(b'{"embeddings": []}')):
            with self.assertRaises(RuntimeError):
                ec.embed("bonjour")

    def test_controle_de_dimension_de_collection(self):
        ec.check_collection_dim(1024, "ok")
        ec.check_collection_dim(None, "inconnue")
        with self.assertRaises(RuntimeError):
            ec.check_collection_dim(768, "ancienne")


if __name__ == "__main__":
    unittest.main()
