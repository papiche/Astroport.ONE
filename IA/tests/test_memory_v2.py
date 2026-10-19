#!/usr/bin/env python3
"""Tests de la mémoire v2 (memory_manager + memory_writer) — sans Qdrant ni Ollama.

    cd Astroport.ONE/IA && python3 -m unittest tests.test_memory_v2 -v
"""
import argparse  # noqa: F401  (avant memory_manager : cf. memory_writer.py)
import io
import json
import os
os.environ.setdefault("OLLAMA_METRICS_OFF", "1")      # les tests ne polluent pas ~/.zen/log/ollama_calls_*.jsonl
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import memory_manager as mm  # noqa: E402


class UnstorableTests(unittest.TestCase):
    """Régression 2026-10-19 : des STORY_KEY_BACKUP (clé AES en clair) avaient été mémorisés."""

    def test_story_key_backup_refuse(self):
        self.assertTrue(mm.unstorable_reason('STORY_KEY_BACKUP:{"key_hex": "ab12"}'))
        self.assertTrue(mm.unstorable_reason('  STORY_KEY_BACKUP:{}'))

    def test_secrets_declares_refuses(self):
        self.assertTrue(mm.unstorable_reason("mon mot de passe est Xk29!fjd8392"))
        self.assertTrue(mm.unstorable_reason("nsec1" + "q" * 40))
        self.assertTrue(mm.unstorable_reason('{"key_hex": "00"}'))

    def test_phrases_normales_acceptees(self):
        for t in ("Je suis allergique aux noix.", "Ma fille a 8 ans.",
                  "Il faut changer le mot de passe du wifi bientôt.",
                  "Je prépare une conférence sur la monnaie libre."):
            self.assertEqual(mm.unstorable_reason(t), "", t)


class SchemaTests(unittest.TestCase):
    def test_slots_traduits(self):
        self.assertEqual(mm.SLOT_SCHEMA[15]["visibility"], "love")
        for slot in (0, 13, 14):
            self.assertEqual(mm.SLOT_SCHEMA[slot]["visibility"], "private")

    def test_identifiant_deterministe_et_insensible_a_la_casse(self):
        a = mm._stable_id("u", mm._content_hash("Ma fille a 8 ans"))
        b = mm._stable_id("u", mm._content_hash("  ma  FILLE a 8 ans "))
        self.assertEqual(a, b)
        self.assertNotEqual(a, mm._stable_id("autre", mm._content_hash("Ma fille a 8 ans")))

    def test_upsert_est_idempotent_et_ecrit_le_schema_v2(self):
        sent = []
        def fake_curl(method, url, payload=None, quiet=()):
            if method == "PUT" and url.endswith("/points"):
                sent.append(payload["points"][0])
            return {"result": {"config": {"params": {"vectors": {"size": mm.VECTOR_SIZE}}}}}
        with mock.patch.object(mm, "_curl", fake_curl), \
             mock.patch.object(mm, "_embed", lambda t: [0.0] * mm.VECTOR_SIZE):
            self.assertTrue(mm.upsert_memory("u@x", "Ma fille a 8 ans", kind="person", source="chat"))
            self.assertTrue(mm.upsert_memory("u@x", "ma fille a 8 ans", kind="person", source="chat"))
        self.assertEqual(sent[0]["id"], sent[1]["id"])
        pl = sent[0]["payload"]
        for key in ("kind", "source", "visibility", "confidence", "status", "embed_model", "schema"):
            self.assertIn(key, pl)
        self.assertEqual((pl["visibility"], pl["status"], pl["embed_model"]),
                         ("private", "active", mm.EMBED_MODEL))

    def test_secret_jamais_envoye_a_qdrant(self):
        with mock.patch.object(mm, "_curl", side_effect=AssertionError("ne doit pas être appelé")), \
             mock.patch.object(mm, "_embed", side_effect=AssertionError("ne doit pas être appelé")):
            self.assertFalse(mm.upsert_user_slot("u@x", 13, 'STORY_KEY_BACKUP:{"key_hex":"ab"}'))

    def test_dimension_differente_refusee(self):
        resp = {"result": {"config": {"params": {"vectors": {"size": 768}}}}}
        with mock.patch.object(mm, "_curl", lambda *a, **k: resp):
            with self.assertRaises(RuntimeError):
                mm.ensure_collection("memory_x")

    def test_embedding_de_mauvaise_dimension_refuse(self):
        with mock.patch.object(mm, "_curl", lambda *a, **k: {"embeddings": [[0.1] * 768]}):
            self.assertEqual(mm._embed("texte"), [])

    def test_recherche_exclut_les_souvenirs_inactifs_et_utilise_le_seuil_du_modele(self):
        bodies = []
        def fake_curl(method, url, payload=None, quiet=()):
            bodies.append(payload)
            return {"result": []}
        with mock.patch.object(mm, "_curl", fake_curl), \
             mock.patch.object(mm, "_embed", lambda t: [0.0] * mm.VECTOR_SIZE):
            mm.search_user_slot("u@x", "question")
        body = bodies[-1]
        self.assertEqual(body["score_threshold"], mm.RECALL_THRESHOLD)
        self.assertIn("must_not", body["filter"])

    def test_resonance_love_ne_lit_que_la_visibilite_love(self):
        calls = []
        def fake_curl(method, url, payload=None, quiet=()):
            calls.append((url, payload))
            return {"result": {"points": []}}
        with mock.patch.object(mm, "_curl", fake_curl):
            mm.love_resonance("a@x", "b@x")
        filt = calls[0][1]["filter"]
        self.assertEqual(filt["must"], [{"key": "visibility", "match": {"value": "love"}}])
        self.assertIn("must_not", filt)


class WriterTests(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self._env = mock.patch.dict(os.environ, {"HOME": self.home.name})
        self._env.start()
        os.makedirs(os.path.join(self.home.name, ".zen/game/nostr/u@x"))
        import memory_writer as w
        self.w = w
        w._consent_cache.clear()

    def tearDown(self):
        self._env.stop()
        self.home.cleanup()

    def _prefs(self, sources=None, raises=None):
        """Simule NOSTR : un MULTIPASS dont l'événement 31903 d=memory_sources contient `sources`."""
        self.w._consent_cache.clear()
        self._p1 = mock.patch.object(self.w, "_keys", return_value=object())
        if raises:
            self._p2 = mock.patch.object(self.w, "_fetch_prefs", side_effect=raises)
        else:
            self._p2 = mock.patch.object(self.w, "_fetch_prefs",
                                         return_value={"sources": sources, "updated_at": 1} if sources is not None else None)
        self._p1.start(); self._p2.start()
        self.addCleanup(self._p1.stop); self.addCleanup(self._p2.stop)

    def test_consentement_par_defaut_sans_choix_ni_multipass(self):
        self.w._consent_cache.clear()
        c = self.w.consent("u@x")          # pas de .secret.nostr : jamais d'élargissement
        self.assertTrue(c["chat"])
        for s in ("love_dm", "nostr_public", "mastodon", "photo", "agenda", "contact"):
            self.assertFalse(c[s], s)

    def test_choix_lus_dans_nostr(self):
        self._prefs({"mastodon": True, "chat": False, "inconnue": True})
        c = self.w.consent("u@x", fresh=True)
        self.assertTrue(c["mastodon"])
        self.assertFalse(c["chat"])
        self.assertNotIn("inconnue", c)

    def test_nostr_muet_donne_les_defauts_jamais_plus_ouvert(self):
        self._prefs(raises=RuntimeError("aucun relais NOSTR n'a répondu"))
        c = self.w.consent("u@x", fresh=True)
        self.assertEqual(c, self.w._defaults())

    def test_ecriture_refusee_si_nostr_muet(self):
        """Retomber sur les défauts puis publier effacerait les autres choix de la personne."""
        self._prefs(raises=RuntimeError("aucun relais NOSTR n'a répondu"))
        with self.assertRaises(RuntimeError):
            self.w.set_consent("u@x", "mastodon", True)

    def test_set_consent_refuse_une_source_inconnue(self):
        with self.assertRaises(ValueError):
            self.w.set_consent("u@x", "n_importe_quoi", True)

    def test_source_non_cochee_refusee_puis_acceptee(self):
        txt = "Un long post public à propos de mon jardin et de mes tomates"
        self._prefs({})
        self.assertFalse(self.w.enqueue("u@x", txt, "mastodon"))
        self.w._consent_cache.clear()
        self._p2.stop()
        with mock.patch.object(self.w, "_fetch_prefs", return_value={"sources": {"mastodon": True}, "updated_at": 1}):
            self.assertTrue(self.w.enqueue("u@x", txt, "mastodon"))

    def test_love_dm_en_pause_meme_force_meme_coche(self):
        """Décision de Fred (2026-10-19) : l'apprentissage des messages à LOVE est suspendu."""
        self.assertIn("love_dm", self.w.paused_sources())
        self._prefs({"love_dm": True})                                    # coché…
        txt = "J'aimerais rencontrer quelqu'un qui aime la randonnée et le jazz"
        self.assertFalse(self.w.enqueue("u@x", txt, "love_dm"))          # …mais refusé
        self.assertFalse(self.w.enqueue("u@x", txt, "love_dm", force=True))   # …même forcé
        self.assertFalse(os.path.exists(self.w._queue_path("u@x")))      # rien n'a été mis en file

    def test_love_dm_reactivable_par_l_environnement(self):
        with mock.patch.dict(os.environ, {"MEMORY_ENABLE_LOVE_DM": "1"}):
            self.assertNotIn("love_dm", self.w.paused_sources())

    def test_le_vidage_ignore_une_source_en_pause_deja_en_file(self):
        item = {"t": "2026-10-19T10:00:00Z", "source": "love_dm", "text": "Un message déjà en file avant la pause"}
        with open(self.w._queue_path("u@x"), "w", encoding="utf-8") as f:
            f.write(json.dumps(item) + "\n")
        self._prefs({"love_dm": True})
        with mock.patch.object(self.w, "process_batch", side_effect=AssertionError("ne doit rien traiter")):
            self.assertEqual(self.w.drain("u@x"), {})

    def test_etat_des_sources_signale_la_pause(self):
        with mock.patch.object(self.w.mm, "memory_overview", return_value={"by_source": {}}):
            rows = {r["source"]: r for r in self.w.sources_status("u@x")["sources"]}
        self.assertTrue(rows["love_dm"]["paused"])
        self.assertFalse(rows["love_dm"]["enabled"])
        self.assertFalse(rows["chat"]["paused"])

    def test_force_survit_au_vidage(self):
        """Le bouton « Régénérer » (force) ne doit pas être jeté faute de case cochée."""
        self.assertTrue(self.w.enqueue("u@x", "Un post long qui parle de mes projets de jardin", "mastodon", force=True))
        with open(self.w._queue_path("u@x"), encoding="utf-8") as f:
            self.assertTrue(json.loads(f.readline())["force"])

    def test_messages_inutiles_ou_secrets_non_mis_en_file(self):
        self.assertFalse(self.w.enqueue("u@x", "ok", "chat"))
        self.assertFalse(self.w.enqueue("u@x", "#BRO", "chat"))
        self.assertFalse(self.w.enqueue("u@x", 'STORY_KEY_BACKUP:{"key_hex":"ab"}', "chat"))
        self.assertFalse(self.w.enqueue("u@x", '{"story_key_backup": 1}', "chat"))
        self.assertTrue(self.w.enqueue("u@x", "#BRO je suis allergique aux noix depuis toujours", "chat"))

    def test_balises_commande_retirees(self):
        self.assertEqual(self.w.clean_text("#BRO #rec Je pars en Bretagne"), "Je pars en Bretagne")

    def test_calendrier_jours_de_semaine_calcules(self):
        cal = self.w._calendar("2026-10-19")
        self.assertIn("lundi 2026-10-19 (aujourd'hui)", cal)
        self.assertIn("jeudi 2026-10-22", cal)   # « jeudi prochain » un lundi 19 octobre 2026

    def test_extraction_ecarte_les_commentaires_du_modele_et_les_secrets(self):
        fake = {"facts": [{"text": "Est allergique aux noix", "kind": "fact", "confidence": 0.9},
                          {"text": "L'information est déjà connue.", "kind": "fact"},
                          {"text": "Son mot de passe est Xk29!fjd8392", "kind": "fact"},
                          {"text": "x", "kind": "fact"}],
                "forget": ["sa fille"]}
        with mock.patch.object(self.w, "_ask", return_value=fake):
            facts, forget = self.w.extract_facts(["peu importe"], "chat", now="2026-10-19")
        self.assertEqual([f["text"] for f in facts], ["Est allergique aux noix"])
        self.assertEqual(forget, ["sa fille"])

    def test_decision_sans_voisin_ajoute_sans_appeler_ia(self):
        with mock.patch.object(self.w.mm, "search_user_slot", return_value=[]), \
             mock.patch.object(self.w, "_ask", side_effect=AssertionError("pas d'appel IA")):
            d = self.w.decide("u@x", {"text": "Aime le jazz", "kind": "trait", "confidence": 1})
        self.assertEqual(d["op"], "ADD")

    def test_decision_quasi_doublon_ignore_sans_appeler_ia(self):
        near = [{"id": 7, "score": 0.97, "payload": {"content": "Aime le jazz"}}]
        with mock.patch.object(self.w.mm, "search_user_slot", return_value=near), \
             mock.patch.object(self.w, "_ask", side_effect=AssertionError("pas d'appel IA")):
            d = self.w.decide("u@x", {"text": "Aime le jazz", "kind": "trait", "confidence": 1})
        self.assertEqual(d["op"], "NOOP")

    def test_decision_remplacement_cible_le_bon_souvenir(self):
        near = [{"id": 41, "score": 0.7, "payload": {"content": "Est végétarien"}}]
        with mock.patch.object(self.w.mm, "search_user_slot", return_value=near), \
             mock.patch.object(self.w, "_ask", return_value={"op": "UPDATE", "target": 0, "text": "Mange de la viande"}):
            d = self.w.decide("u@x", {"text": "Mange du poulet", "kind": "fact", "confidence": 1})
        self.assertEqual((d["op"], d["target"], d["text"]), ("UPDATE", 41, "Mange de la viande"))

    def test_decision_cible_invalide_retombe_sur_ajout(self):
        near = [{"id": 41, "score": 0.7, "payload": {"content": "Est végétarien"}}]
        with mock.patch.object(self.w.mm, "search_user_slot", return_value=near), \
             mock.patch.object(self.w, "_ask", return_value={"op": "DELETE", "target": 9, "text": "x"}):
            d = self.w.decide("u@x", {"text": "Mange du poulet", "kind": "fact", "confidence": 1})
        self.assertEqual(d["op"], "ADD")


class DerivedSourcesTests(unittest.TestCase):
    """Sources passives : memory_sources.py + prompts dédiés de memory_writer."""

    @classmethod
    def setUpClass(cls):
        import memory_writer as w
        import memory_sources as ms
        cls.w, cls.ms = w, ms

    def test_posts_automatiques_ecartes_les_vrais_gardes(self):
        ev = lambda kind, content, tags=(): {"kind": kind, "created_at": 10, "content": content, "tags": [list(t) for t in tags]}
        bots = [
            ev(1, "🌿 Reconnaissance de plante ✅ Identification réussie ! " + "x" * 80),
            ev(1, "🎬 Dark.Matter.S01E01 🎥 https://u.copylaradio.com/theater?video=abc " + "y" * 60),
            ev(1, "Une description d'image assez longue pour passer le seuil minimal de caractères du filtre", [("t", "aquoicasert")]),
            ev(1, "Texte long avec une image jointe par le robot de la station, assez long pour passer le seuil", [("imeta", "url x")]),
            ev(1, "Creer une note que voulez-vous dire ? " + "z" * 60, [("t", "bro")]),
        ]
        reponse = ev(1, "Une réponse assez longue à quelqu'un d'autre dans une conversation publique, mon avis", [("e", "abc")])
        court = ev(1, "ok merci")
        humain = ev(1, "Aujourd'hui j'ai planté des tomates cerises et du basilic sur mon balcon, quel bonheur !")
        article = ev(30023, "Le corps de l'article " + "w" * 40, [("title", "Semences paysannes"), ("summary", "Un résumé")])
        out = self.ms.nostr_texts(bots + [reponse, court, humain, article])
        textes = [t for _ts, t in out]
        self.assertEqual(len(textes), 2, textes)
        self.assertTrue(any("tomates cerises" in t for t in textes))
        self.assertTrue(any(t.startswith("Article « Semences paysannes »") for t in textes))

    def _db(self, rows):
        import sqlite3
        from types import SimpleNamespace
        conn = sqlite3.connect(":memory:")
        conn.execute("CREATE TABLE entries (type TEXT, cid TEXT, mime TEXT, taken_at INT, mtime INT, path TEXT, lat REAL, lon REAL, data TEXT)")
        conn.executemany("INSERT INTO entries VALUES ('file','Qm','image/jpeg',?,?,?,?,?,?)", rows)
        return SimpleNamespace(_IMG="type='file' AND cid IS NOT NULL AND mime LIKE 'image/%'"), conn

    def _paths(self, rows):
        return [r[2] for r in rows]

    def test_photos_choisies_regroupees_par_moment(self):
        """Le geste de la personne décide quelles photos ; le serveur en fait UN souvenir par moment (6 h)."""
        H = 3600
        rows = [(1000 + i * 600, 1000, f"/a{i}.jpg", 43.6, 1.44, json.dumps({"desc": {"text": f"Scène {i}"}})) for i in range(5)]
        rows += [(1000 + 100 * H, 1, "/b0.jpg", None, None, json.dumps({"desc": {"text": "Autre jour"}}))]
        rows += [(1000 + 50 * H, 1, "/pas_choisie.jpg", None, None, json.dumps({"desc": {"text": "Non choisie"}}))]
        db, conn = self._db(rows)
        chosen = ["/a0.jpg", "/a1.jpg", "/a2.jpg", "/b0.jpg"]
        texts = self.ms.selection_texts(db, conn, chosen, {})
        self.assertEqual(len(texts), 2)                                  # deux moments, pas quatre photos
        self.assertIn("3 photos", texts[0])
        self.assertIn("1 photo", texts[1])
        joined = " ".join(texts)
        self.assertNotIn("Non choisie", joined)                          # jamais une photo non choisie
        self.assertNotIn("Scène 4", joined)

    def test_photo_choisie_sans_description_ni_personne_pas_de_souvenir_vide(self):
        db, conn = self._db([(1000 + i * 60, 1, f"/a{i}.jpg", None, None, None) for i in range(5)])
        self.assertEqual(self.ms.selection_texts(db, conn, ["/a0.jpg", "/a1.jpg"], {}), [])

    def test_texte_avec_personnes_scenes_et_lieu(self):
        db, conn = self._db([(1000 + i * 60, 1, f"/a{i}.jpg", 43.6, 1.44, json.dumps({"desc": {"text": f"Scène {i}"}})) for i in range(5)])
        t = self.ms.selection_texts(db, conn, [f"/a{i}.jpg" for i in range(5)],
                                    {"/a0.jpg": {"Emma", "Anonymous"}, "/a1.jpg": {"Tim"}})[0]
        self.assertIn("5 photos", t)
        self.assertIn("Emma, Tim", t)
        self.assertNotIn("Anonymous", t)
        self.assertIn("43.60°N", t)

    def test_date_du_fichier_signalee_quand_pas_de_prise_de_vue(self):
        db, conn = self._db([(None, 5000, "/x.jpg", None, None, json.dumps({"desc": {"text": "Une scène"}}))])
        t = self.ms.selection_texts(db, conn, ["/x.jpg"], {})[0]
        self.assertIn("date du fichier", t)

    def test_photo_sortie_non_datee_ou_genree_ecartee(self):
        fake = {"facts": [{"text": "2025-07-02 : repas avec Emma et Tim", "kind": "fact", "confidence": 0.95},
                          {"text": "Elle a pris des photos avec Fred", "kind": "episode"},
                          {"text": "Fred est une personne reconnue", "kind": "person"},
                          {"text": "Photos prises autour de 43.6°N 1.4°E", "kind": "fact"}]}
        with mock.patch.object(self.w, "_ask", return_value=fake):
            facts, _ = self.w.extract_facts(["x"], "photo", now="2026-10-19")
        self.assertEqual([f["text"] for f in facts], ["2025-07-02 : repas avec Emma et Tim"])
        self.assertEqual((facts[0]["kind"], facts[0]["confidence"]), ("episode", 0.7))

    def test_evenements_photo_jamais_fusionnes(self):
        near = [{"id": 5, "score": 0.7, "payload": {"content": "2025-07-01 : repas avec Emma"}}]
        with mock.patch.object(self.w.mm, "search_user_slot", return_value=near), \
             mock.patch.object(self.w, "_ask", side_effect=AssertionError("pas d'appel IA")):
            d = self.w.decide("u@x", {"text": "2025-07-02 : repas avec Emma", "kind": "episode", "confidence": 0.7}, "photo")
        self.assertEqual(d["op"], "ADD")                      # deux sorties voisines = deux événements

    def test_prompt_messages_sans_genre_devine(self):
        p = self.w._messages_prompt("2026-10-19", "chat", "- bonjour")
        self.assertIn("sans « il » ni « elle »", p)


class ExternalSourcesTests(unittest.TestCase):
    """Agenda et contacts : texte déterministe (sans modèle) et synchronisation."""

    @classmethod
    def setUpClass(cls):
        import memory_sources as ms
        cls.ms = ms

    def test_texte_agenda(self):
        t = self.ms.agenda_text({"summary": "Dentiste", "start": "2026-10-22T14:30:00", "location": "Toulouse",
                                 "description": "Détartrage\n  prévu", "all_day": False})
        self.assertEqual(t, "Agenda 2026-10-22 14:30 : Dentiste — lieu : Toulouse — Détartrage prévu")
        j = self.ms.agenda_text({"summary": "Randonnée", "start": "2026-10-25", "all_day": True})
        self.assertIn("(journée entière)", j)
        self.assertIn("récurrent", self.ms.agenda_text({"summary": "Réunion", "start": "2026-10-25", "rrule": "FREQ=WEEKLY"}))

    def test_agenda_sans_titre_ou_sans_date_ignore(self):
        self.assertIsNone(self.ms.agenda_text({"summary": "", "start": "2026-10-22"}))
        self.assertIsNone(self.ms.agenda_text({"summary": "x", "start": ""}))

    def test_fenetre_temporelle(self):
        from datetime import datetime, timezone
        now = datetime(2026, 10, 19, tzinfo=timezone.utc)
        self.assertTrue(self.ms._within_window({"start": "2026-10-10"}, now))          # il y a 9 jours
        self.assertFalse(self.ms._within_window({"start": "2026-08-01"}, now))         # trop ancien
        self.assertTrue(self.ms._within_window({"start": "2026-12-01"}, now))          # à venir
        self.assertFalse(self.ms._within_window({"start": "2027-06-01"}, now))         # trop lointain
        self.assertTrue(self.ms._within_window({"start": "2024-01-01", "rrule": "FREQ=YEARLY"}, now))   # récurrent
        self.assertFalse(self.ms._within_window({"start": "n'importe quoi"}, now))

    def test_anniversaire_jour_et_mois_seulement(self):
        for raw in ("1985-03-12", "--03-12", "19850312"):
            self.assertEqual(self.ms._birthday(raw), "12 mars", raw)
        self.assertEqual(self.ms._birthday(""), "")
        self.assertEqual(self.ms._birthday("pas une date"), "")

    def test_contact_jamais_de_coordonnees(self):
        t = self.ms.contact_text({"fn": "Antoine Dupont", "org": "Orange", "bday": "1985-03-12",
                                  "note": "Frère de Josiane", "emails": [{"value": "a@b.fr"}],
                                  "tels": [{"value": "+33612345678"}], "nostr": "npub1xyz"})
        self.assertEqual(t, "Contact : Antoine Dupont — organisation : Orange — anniversaire le 12 mars — note : Frère de Josiane")
        for secret in ("a@b.fr", "0612345678", "+33612345678", "npub1xyz", "1985"):
            self.assertNotIn(secret, t)
        self.assertIsNone(self.ms.contact_text({"fn": ""}))
        self.assertIsNone(self.ms.contact_text({"fn": "Emma"}))            # un nom seul n'est pas un souvenir
        self.assertIsNotNone(self.ms.contact_text({"fn": "Emma", "org": "G1"}))

    def _run_sync(self, existing, wanted, dry=False):
        """sync_external avec une mémoire simulée : retourne (résultat, ids retirés, textes écrits)."""
        retired, written = [], []
        pts = [{"id": i, "payload": {"ext_key": k, "content_hash": self.ms.mm._content_hash(t)}} for i, (k, t) in existing]
        with mock.patch.object(self.ms.mm, "list_memories", return_value=pts), \
             mock.patch.object(self.ms.mm, "set_memory_fields", side_effect=lambda e, ids, f: retired.extend(ids) or True), \
             mock.patch.object(self.ms.mm, "upsert_memory", side_effect=lambda e, t, **kw: written.append((t, kw["extra"]["ext_key"])) or True):
            res = self.ms.sync_external("u@x", "agenda", wanted, "episode", dry=dry)
        return res, retired, written

    def test_sync_ajout_modification_suppression(self):
        existing = [(1, ("a", "Agenda A v1")), (2, ("b", "Agenda B")), (3, ("c", "Agenda C"))]
        res, retired, written = self._run_sync(existing, {"a": "Agenda A v2", "b": "Agenda B", "d": "Agenda D"})
        self.assertEqual(res, (1, 1, 1))                                 # +D, ~A, −C
        self.assertEqual(sorted(retired), [1, 3])                        # A v1 remplacé, C disparu ; B intact
        self.assertEqual(sorted(w[0] for w in written), ["Agenda A v2", "Agenda D"])

    def test_sync_identique_ne_fait_rien(self):
        res, retired, written = self._run_sync([(1, ("a", "Agenda A"))], {"a": "Agenda A"})
        self.assertEqual((res, retired, written), ((0, 0, 0), [], []))

    def test_sync_refuse_une_disparition_massive(self):
        existing = [(i, (f"k{i}", f"Agenda {i}")) for i in range(14)]
        with mock.patch("sys.stderr", new_callable=io.StringIO) as err:
            res, retired, written = self._run_sync(existing, {})
        self.assertEqual(retired, [])                                    # disque monté absent : on ne vide pas la mémoire
        self.assertIn("REFUSÉE", err.getvalue())

    def test_sync_a_blanc_n_ecrit_rien(self):
        with mock.patch("builtins.print"):
            res, retired, written = self._run_sync([(1, ("a", "Agenda A"))], {"b": "Agenda B"}, dry=True)
        self.assertEqual((retired, written), ([], []))


if __name__ == "__main__":
    unittest.main()
