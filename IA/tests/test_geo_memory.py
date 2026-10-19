"""Mémoire géolocalisée (uplanet_geo) : seuils 1/3/12 likes, cases UMAP/SECTOR/REGION, rafraîchissement depuis NOSTR."""
import argparse  # noqa: F401  (avant memory_manager)
import os
os.environ.setdefault("OLLAMA_METRICS_OFF", "1")      # les tests ne polluent pas ~/.zen/log/ollama_calls_*.jsonl
import sys
import time
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import memory_manager as mm  # noqa: E402
import geo_memory as gm      # noqa: E402

AUTH = "aa" * 32


def note(i, lat="43.605", lon="1.449", content="Marché bio place du Capitole le samedi", kind=1, tags=None, author=AUTH):
    ev = {"id": f"{i:064x}", "pubkey": author, "kind": kind, "content": content, "created_at": int(time.time()) - 3600,
          "tags": [["latitude", lat], ["longitude", lon]] if lat is not None else []}
    ev["tags"] += tags or []
    return ev


def like(target, who, content="🤙"):
    return {"id": f"r{who}{target}"[:64].ljust(64, "0"), "pubkey": f"{who:064x}", "kind": 7, "content": content,
            "created_at": int(time.time()), "tags": [["e", f"{target:064x}"]]}


class CellTests(unittest.TestCase):
    def test_seuils_1_3_12(self):
        self.assertEqual([mm.geo_level(n) for n in (0, 1, 2, 3, 11, 12, 99)],
                         [None, "umap", "umap", "sector", "sector", "region", "region"])

    def test_cases_sud_ouest(self):
        self.assertEqual(mm.geo_keys(43.605, 1.449), {"umap": "43.60_1.44", "sector": "43.6_1.4", "region": "43_1"})
        self.assertEqual(mm.geo_keys(43.60, 1.44)["umap"], "43.60_1.44")          # le coin lui-même
        k = mm.geo_keys(-0.005, -0.005)                                          # négatifs : on descend, jamais vers zéro
        self.assertEqual((k["umap"], k["region"]), ("-0.01_-0.01", "-1_-1"))

    def test_deux_points_d_une_meme_case(self):
        self.assertEqual(mm.geo_keys(43.601, 1.441)["umap"], mm.geo_keys(43.609, 1.449)["umap"])
        self.assertNotEqual(mm.geo_keys(43.609, 1.449)["umap"], mm.geo_keys(43.611, 1.449)["umap"])


class ParsingTests(unittest.TestCase):
    def test_coordonnees_tags_puis_g(self):
        self.assertEqual(gm.coords(note(1)), (43.605, 1.449))
        self.assertEqual(gm.coords(note(2, lat=None, tags=[["g", "43.6,1.44"]])), (43.6, 1.44))

    def test_pas_de_position_ou_position_invalide(self):
        self.assertIsNone(gm.coords(note(3, lat=None)))
        self.assertIsNone(gm.coords(note(4, lat="abc", lon="1")))
        self.assertIsNone(gm.coords(note(5, lat="95", lon="1")))
        self.assertIsNone(gm.coords(note(6, lat="0.0", lon="0.0")))             # (0,0) = UMAP globale des messages SANS position
        self.assertIsNone(gm.coords(note(7, lat=None, tags=[["g", "u09tvw0"]])))  # geohash : non pris en charge, pas deviné

    def test_exclusions(self):
        self.assertEqual(gm.reason(note(8, kind=1222, content="")), "sans texte")
        self.assertEqual(gm.reason(note(9, tags=[["encrypted", "true"]])), "chiffrée")
        self.assertEqual(gm.reason(note(10, content='clé : "key_hex": "ab12"')), "secret")
        self.assertEqual(gm.reason(note(11, kind=30023)), "genre")
        self.assertIsNone(gm.reason(note(12)))


class LikersTests(unittest.TestCase):
    def test_distincts_hors_auteur_et_seulement_les_approbations(self):
        reacts = [like(1, 5), like(1, 5), like(1, 6, "👍"), like(1, 7, "❤"), like(1, int(AUTH, 16)),
                  like(1, 8, "+10"), like(1, 9, "👀"), like(1, 10, "💯")]
        reacts[4]["pubkey"] = AUTH                                                # l'auteur se like lui-même
        with mock.patch.object(gm, "scan", return_value=reacts):
            self.assertEqual(len(gm.likers(f"{1:064x}", AUTH)), 3)                # 5, 6, 7 : ni auteur, ni « +10 » (paiement), ni 👀/💯


class RefreshTests(unittest.TestCase):
    def run_refresh(self, events, reactions, indexed=(), dry=False):
        """refresh() avec NOSTR et Qdrant simulés. → (stats, écritures, suppressions)."""
        writes, deletes = [], []
        by_id = {e["id"]: e for e in events}

        def fake_scan(flt):
            if flt.get("kinds") == [7] and "#e" in flt:
                return [r for r in reactions if r["tags"][0][1] == flt["#e"][0]]
            if flt.get("kinds") == [7]:
                return reactions
            if "ids" in flt:
                return [by_id[i] for i in flt["ids"] if i in by_id]
            return []
        idx = [{"event_id": e, "likes": n, "level": mm.geo_level(n), "id": int(e[:15], 16)} for e, n in indexed]
        with mock.patch.object(gm, "scan", fake_scan), mock.patch.object(mm, "geo_indexed", return_value=idx), \
             mock.patch.object(mm, "upsert_geo_event", side_effect=lambda ev, la, lo, n: writes.append((ev["id"], mm.geo_level(n), n)) or True), \
             mock.patch.object(mm, "delete_geo_events", side_effect=lambda ids: deletes.extend(ids) or True), \
             mock.patch("builtins.print"):
            return gm.refresh(days=3, recount_days=30, dry=dry), writes, deletes

    def test_niveau_selon_les_likes(self):
        ev = [note(1), note(2), note(3)]
        rx = [like(1, 100)] + [like(2, 100 + i) for i in range(3)] + [like(3, 100 + i) for i in range(12)]
        st, writes, _ = self.run_refresh(ev, rx)
        self.assertEqual(sorted((w[1], w[2]) for w in writes), [("region", 12), ("sector", 3), ("umap", 1)])
        self.assertEqual(st["levels"], {"umap": 1, "sector": 1, "region": 1})

    def test_publication_non_geolocalisee_ou_exclue_ignoree(self):
        ev = [note(1, lat=None), note(2, tags=[["encrypted", "true"]]), note(3, content="")]
        st, writes, _ = self.run_refresh(ev, [like(i, 100) for i in (1, 2, 3)])
        self.assertEqual(writes, [])
        self.assertEqual(st["geolocated"], 2)
        self.assertEqual(st["skipped"], {"chiffrée": 1, "sans texte": 1})

    def test_se_liker_soi_meme_ne_suffit_pas(self):
        own = like(1, 1)
        own["pubkey"] = AUTH
        _, writes, _ = self.run_refresh([note(1)], [own])
        self.assertEqual(writes, [])

    def test_le_niveau_monte_quand_les_likes_arrivent(self):
        rx = [like(1, 100 + i) for i in range(3)]
        _, writes, _ = self.run_refresh([note(1)], rx, indexed=[(f"{1:064x}", 1)])      # indexée à 1 like, en a 3
        self.assertEqual(writes, [(f"{1:064x}", "sector", 3)])

    def test_inchangee_n_est_pas_reecrite(self):
        st, writes, _ = self.run_refresh([note(1)], [like(1, 100)], indexed=[(f"{1:064x}", 1)])
        self.assertEqual((writes, st["unchanged"]), ([], 1))

    def test_plus_aucun_like_sort_de_l_index(self):
        st, writes, deletes = self.run_refresh([note(1)], [], indexed=[(f"{1:064x}", 2)])
        self.assertEqual((writes, deletes, st["removed"]), ([], [f"{1:064x}"], 1))

    def test_evenement_disparu_du_relais_sort_de_l_index(self):
        st, _, deletes = self.run_refresh([], [], indexed=[(f"{7:064x}", 3)])
        self.assertEqual((deletes, st["removed"]), ([f"{7:064x}"], 1))

    def test_a_blanc_n_ecrit_ni_ne_supprime(self):
        _, writes, deletes = self.run_refresh([note(1)], [like(1, 100)], indexed=[(f"{9:064x}", 1)], dry=True)
        self.assertEqual((writes, deletes), ([], []))


@unittest.skipUnless(mm._qdrant_available() and mm._embed("test"), "Qdrant + Ollama requis (test d'intégration)")
class IntegrationTests(unittest.TestCase):
    """Aller-retour RÉEL dans Qdrant, sur une collection de test jetable (jamais `uplanet_geo`)."""
    COL = "uplanet_geo_test"

    def setUp(self):
        self._p = mock.patch.object(mm, "GEO_COLLECTION", self.COL)
        self._p.start()
        mm._curl("DELETE", f"{mm.QDRANT_URL}/collections/{self.COL}")
        self.addCleanup(lambda: mm._curl("DELETE", f"{mm.QDRANT_URL}/collections/{self.COL}"))
        self.addCleanup(self._p.stop)

    @staticmethod
    def eid(i):
        # de vrais id NOSTR sont des empreintes aléatoires : le préfixe de l'identifiant Qdrant diffère d'une publication à l'autre
        return f"{i:x}".ljust(64, "0")

    def put(self, i, lat, lon, likes, text):
        ev = note(i, lat=str(lat), lon=str(lon), content=text)
        ev["id"] = self.eid(i)
        return mm.upsert_geo_event(ev, lat, lon, likes)

    def test_portee_selon_le_niveau(self):
        # trois publications sur le thème « marché », dans trois cases emboîtées autour de (43.605, 1.449)
        self.assertTrue(self.put(1, 43.605, 1.449, 1, "Marché bio du samedi matin, producteurs locaux"))        # UMAP 43.60_1.44
        self.assertTrue(self.put(2, 43.652, 1.481, 3, "Grand marché de producteurs et vente de légumes"))        # SECTOR 43.6_1.4
        self.assertTrue(self.put(3, 43.911, 1.093, 12, "Marché régional des producteurs, fruits et légumes"))    # REGION 43_1
        self.assertTrue(self.put(4, 48.857, 2.352, 12, "Marché aux fleurs de Paris, producteurs de fleurs"))     # autre région
        q = "marché de producteurs"
        ici = {p["payload"]["event_id"] for p in mm.search_geo(43.605, 1.449, q, limit=10)}
        self.assertEqual(ici, {self.eid(i) for i in (1, 2, 3)})          # ma case + mon secteur (≥3) + ma région (≥12)
        voisin = {p["payload"]["event_id"] for p in mm.search_geo(43.649, 1.419, q, limit=10)}   # autre UMAP, MÊME secteur 43.6_1.4
        self.assertEqual(voisin, {self.eid(i) for i in (2, 3)})          # pas la publication d'UMAP (1 like) d'une autre case
        loin = {p["payload"]["event_id"] for p in mm.search_geo(43.95, 1.05, q, limit=10)}       # même région 43_1, autre secteur
        self.assertEqual(loin, {self.eid(3)})                            # seule la publication de niveau région
        paris = {p["payload"]["event_id"] for p in mm.search_geo(48.857, 2.352, q, limit=10)}
        self.assertEqual(paris, {self.eid(4)})

    def test_mise_a_jour_sans_doublon_et_retrait(self):
        self.put(1, 43.605, 1.449, 1, "Marché bio du samedi matin")
        self.put(1, 43.605, 1.449, 12, "Marché bio du samedi matin")      # même évènement, plus de likes : mise à jour
        pts = mm.geo_indexed(0)
        self.assertEqual((len(pts), pts[0]["level"], pts[0]["likes"]), (1, "region", 12))
        self.assertTrue(mm.delete_geo_events([self.eid(1)]))
        self.assertEqual(mm.geo_indexed(0), [])

    def test_aucun_like_pas_d_entree_et_secret_refuse(self):
        self.assertFalse(self.put(1, 43.605, 1.449, 0, "Marché bio"))
        self.assertFalse(self.put(2, 43.605, 1.449, 5, 'mon mot de passe est Xk29!fjd8392'))
        self.assertEqual(mm.geo_indexed(0), [])


if __name__ == "__main__":
    unittest.main()
