#!/usr/bin/env python3
"""Garde-fous de l'apprentissage (oubli durable, souvenirs de la personne, confiance, secrets) — sans Qdrant ni Ollama.
La mesure de QUALITÉ sur de vraies données est dans eval_memory.py.

    cd Astroport.ONE/IA && python3 -m unittest tests.test_memory_guards -v
"""
import argparse  # noqa: F401  (avant memory_manager : cf. memory_writer.py)
import os
os.environ.setdefault("OLLAMA_METRICS_OFF", "1")      # les tests ne polluent pas ~/.zen/log/ollama_calls_*.jsonl
import sys
import unittest
from datetime import datetime, timedelta
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import memory_manager as mm  # noqa: E402
import memory_writer as w  # noqa: E402


def _cur(payload):
    return {"id": 1, "payload": payload}


class UpsertAutoTests(unittest.TestCase):
    def _run(self, prev, source="mastodon", auto=True):
        sent = []
        def fake_curl(method, url, body=None, quiet=()):
            if method == "PUT" and url.endswith("/points"):
                sent.append(body["points"][0])
            return {"result": {"config": {"params": {"vectors": {"size": mm.VECTOR_SIZE}}}}}
        with mock.patch.object(mm, "_curl", fake_curl), \
             mock.patch.object(mm, "_embed", lambda t: [0.0] * mm.VECTOR_SIZE), \
             mock.patch.object(mm, "get_memory", lambda u, i: _cur(prev) if prev else {}):
            ok = mm.upsert_memory("u@x", "Aime le thé", source=source, visibility="private", auto=auto)
        return ok, sent

    def test_oubli_non_ressuscite_par_une_source_passive(self):
        ok, sent = self._run({"status": "deleted", "deleted_by": "user"})
        self.assertFalse(ok); self.assertEqual(sent, [])

    def test_le_chat_peut_revenir_sur_un_oubli(self):
        ok, sent = self._run({"status": "deleted", "deleted_by": "user"}, source="chat")
        self.assertTrue(ok); self.assertEqual(sent[0]["payload"]["status"], "active")

    def test_souvenir_de_la_personne_intact(self):
        ok, sent = self._run({"status": "active", "origin": "user", "visibility": "love"})
        self.assertTrue(ok); self.assertEqual(sent, [])

    def test_visibilite_choisie_conservee(self):
        ok, sent = self._run({"status": "active", "origin": "auto", "visibility": "love"})
        self.assertEqual(sent[0]["payload"]["visibility"], "love")

    def test_ecriture_manuelle_marque_l_origine_user(self):
        ok, sent = self._run({}, source="manual", auto=False)
        self.assertEqual(sent[0]["payload"]["origin"], "user")

    def test_epingle(self):
        self.assertTrue(mm.is_pinned({"edited": True}))
        self.assertTrue(mm.is_pinned({"source": "rec"}))
        self.assertFalse(mm.is_pinned({"origin": "auto", "source": "chat"}))


class DecayAndSecretsTests(unittest.TestCase):
    def test_episode_ancien_classe_apres_un_fait_proche(self):
        old = (datetime.utcnow() - timedelta(days=700)).isoformat() + "Z"
        hits = [{"score": .70, "payload": {"kind": "episode", "source": "chat", "timestamp": old}},
                {"score": .66, "payload": {"kind": "fact", "source": "chat", "timestamp": old}}]
        self.assertEqual([h["payload"]["kind"] for h in mm._age_rank(hits)], ["fact", "episode"])

    def test_secrets_francais_et_bancaires(self):
        for s in ("Mon mot de passe wifi est Kiwi-2026-xyz", "Le code PIN de ma carte est 4821", "mdp : azerty123456",
                  "IBAN FR76 3000 6000 0112 3456 7890 189", "carte 4532 0151 1283 0366", "clé sk-abcdefghijklmnopqrstuvwx"):
            self.assertTrue(mm.unstorable_reason(s), s)
        for s in ("Aime les secrets de famille", "Déteste les mots de passe compliqués", "A couru 21 km en 1 h 50"):
            self.assertFalse(mm.unstorable_reason(s), s)


class WriterGuardTests(unittest.TestCase):
    def test_confiance_minimale_selon_la_source(self):
        facts = {"facts": [{"text": "Aime la plongée sous-marine", "kind": "trait", "confidence": 0.65}]}
        with mock.patch.object(w, "_ask", return_value=facts):
            self.assertEqual(len(w.extract_facts(["x"], "chat")[0]), 1)
            self.assertEqual(len(w.extract_facts(["x"], "mastodon")[0]), 0)

    def test_remplissage_ecarte(self):
        facts = {"facts": [{"text": "Utilise l'expression « que la force soit avec vous ! ».", "kind": "trait", "confidence": 0.9}]}
        with mock.patch.object(w, "_ask", return_value=facts):
            self.assertEqual(w.extract_facts(["gm"], "mastodon")[0], [])

    def test_allegation_de_tiers_ecartee_mais_pas_un_proche_qui_informe(self):
        facts = {"facts": [{"text": "Son voisin affirme que le maire est corrompu.", "kind": "fact", "confidence": 0.9},
                           {"text": "Son médecin dit qu'il doit éviter le sel.", "kind": "fact", "confidence": 0.9}]}
        with mock.patch.object(w, "_ask", return_value=facts):
            out = [f["text"] for f in w.extract_facts(["x"], "chat")[0]]
        self.assertEqual(out, ["Son médecin dit qu'il doit éviter le sel."])

    def test_decide_noop_si_sujet_oublie_hors_chat(self):
        with mock.patch.object(mm, "forgotten_match", return_value={"score": .9}):
            self.assertEqual(w.decide("u@x", {"text": "t", "kind": "fact", "confidence": .9}, "mastodon")["op"], "NOOP")

    def test_oubli_trop_large_refuse(self):
        near = [{"id": i, "score": .7, "payload": {"content": f"s{i}"}} for i in range(4)]
        with mock.patch.object(mm, "search_user_slot", return_value=near), \
             mock.patch.object(w, "_ask", return_value={"delete": [0, 1, 2, 3]}), \
             mock.patch.object(mm, "forget_points") as fp:
            self.assertEqual(w.forget("u@x", "tout"), 0)
            fp.assert_not_called()

    def test_demande_d_oubli_ignoree_hors_chat(self):
        with mock.patch.object(w, "extract_facts", return_value=([], ["quelque chose"])), \
             mock.patch.object(w, "forget") as fg:
            w.process_batch("u@x", [{"source": "mastodon", "t": "2026-10-19T00:00:00Z", "text": "x"}])
            fg.assert_not_called()


if __name__ == "__main__":
    unittest.main()
