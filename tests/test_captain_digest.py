"""Briefing du Capitaine (tools/captain_digest.py) : ce qui compte remonte, le bruit disparaît, aucune panne n'est muette.
    python3 -m unittest tests.test_captain_digest   (depuis Astroport.ONE)"""
import json
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))
import captain_digest as cd  # noqa: E402

LOG = """[2026-10-16 18:00:00] début
[2026-10-16 18:01:00] [ERROR] ❌ WebSocket backfill failed after 2 attempts
[2026-10-16 18:02:00] [ERROR] ❌ WebSocket backfill failed after 2 attempts
[2026-10-16 18:03:00] [ERROR] ❌ WebSocket backfill failed after 2 attempts
  29x  [WARN] ❌ Batch 2 failed (attempt 1/3), retrying...
  938x  [WARN]   ❌ abcdef0123456789abcdef... NO PROFILE FOUND - scheduling full sync
[2026-10-16 18:04:00] 💰 Payments: 0 processed | 0 failed | 0 already done
=== NOSTR / CONSTELLATION ERRORS (résumé 24h) ====
[2026-10-16 19:30:00] fin
"""


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        p = mock.patch.object(cd, "ZEN", self.root / ".zen")
        p.start()
        self.addCleanup(p.stop)
        (self.root / ".zen").mkdir()
        self.log = self.root / "20h12.log"
        self.log.write_text(LOG, encoding="utf-8")
        self.d = cd.Digest(24)


class TestLog(Base):
    def test_erreurs_regroupees_et_comptees(self):
        cd.collect_log(self.d, self.log)
        titles = [i[1] for i in self.d.items]
        self.assertTrue(any(t.startswith("3× ") and "WebSocket backfill failed" in t for t in titles), titles)

    def test_compteur_agrege_du_journal_est_respecte(self):
        cd.collect_log(self.d, self.log)
        self.assertTrue(any(i[1].startswith("938× ") for i in self.d.items))

    def test_les_nouvelles_tentatives_ne_sont_pas_des_problemes(self):
        cd.collect_log(self.d, self.log)
        self.assertFalse(any("Batch 2" in i[1] for i in self.d.items))
        self.assertIn("29 nouvelles tentatives", dict(self.d.facts["Station"])["Journal 20h12"])

    def test_zero_failed_n_est_pas_une_erreur(self):
        cd.collect_log(self.d, self.log)
        self.assertFalse(any("Payments" in i[1] for i in self.d.items))

    def test_horodatage_et_niveau_absents_des_titres(self):
        cd.collect_log(self.d, self.log)
        for _lvl, title, _d, _a in self.d.items:
            self.assertNotIn("2026-10-16", title)
            self.assertNotIn("[ERROR]", title)

    def test_duree_du_traitement(self):
        cd.collect_log(self.d, self.log)
        self.assertEqual(dict(self.d.facts["Station"])["Durée du traitement 20h12"], "90 min")

    def test_une_erreur_isolee_est_a_surveiller_pas_critique(self):
        self.log.write_text("[2026-10-16 18:01:00] [ERROR] boom unique\n", encoding="utf-8")
        cd.collect_log(self.d, self.log)
        self.assertEqual(self.d.items[0][0], "warn")

    def test_journal_absent_est_signale_pas_ignore(self):
        self.d.collect("journal", lambda: cd.collect_log(self.d, self.root / "absent.log"))
        self.assertIn("Collecteur « journal » en échec", self.d.items[0][1])


class TestBro(Base):
    def _write(self, acct, rows):
        f = self.root / ".zen" / "flashmem" / acct / "observability" / "activity.jsonl"
        f.parent.mkdir(parents=True)
        now = time.strftime("%Y-%m-%dT%H:%M:%S%z")
        f.write_text("\n".join(json.dumps({"timestamp": now, **r}) for r in rows), encoding="utf-8")

    def test_echecs_recurrents_remontent_avec_les_comptes(self):
        self._write("alice@vrai.org", [{"tool": "multipass", "success": False}] * 12 + [{"tool": "multipass", "success": True}] * 8)
        with mock.patch.object(cd.subprocess, "run", return_value=mock.Mock(stdout="123")):
            cd.collect_bro(self.d)
        item = next(i for i in self.d.items if "multipass" in i[1])
        self.assertIn("12 échecs sur 20", item[1])
        self.assertIn("alice@vrai.org", item[2])

    def test_comptes_de_test_exclus(self):
        self._write("c1792-inconnue@example.com", [{"tool": "multipass", "success": False}] * 30)
        with mock.patch.object(cd.subprocess, "run", return_value=mock.Mock(stdout="123")):
            cd.collect_bro(self.d)
        self.assertEqual([i for i in self.d.items if "multipass" in i[1]], [])
        self.assertEqual(dict(self.d.facts["BRO"])["Comptes actifs"], "0")

    def test_demon_arrete_est_critique(self):
        with mock.patch.object(cd.subprocess, "run", return_value=mock.Mock(stdout="")):
            cd.collect_bro(self.d)
        self.assertEqual(self.d.items[0][0], "crit")

    def test_quelques_echecs_ne_declenchent_rien(self):
        self._write("a@vrai.org", [{"tool": "x", "success": False}] * 3 + [{"tool": "x", "success": True}])
        with mock.patch.object(cd.subprocess, "run", return_value=mock.Mock(stdout="1")):
            cd.collect_bro(self.d)
        self.assertEqual(self.d.items, [])


class TestVerdict(unittest.TestCase):
    def test_verdict_et_sujet(self):
        self.assertEqual(cd.verdict([])[0], "🟢")
        self.assertEqual(cd.verdict([("warn", "a", "", "")])[0], "🟠")
        items = [("warn", "bro en échec", "", ""), ("crit", "disque plein", "", ""), ("info", "bruit", "", "")]
        self.assertEqual(cd.verdict(items)[0], "🔴")
        subj = cd.subject(items, "nexus")
        self.assertTrue(subj.startswith("20H12 nexus — 🔴"))
        self.assertLess(subj.index("disque plein"), subj.index("bro en échec"), "le critique d'abord")
        self.assertNotIn("bruit", subj)

    def test_html_echappe_et_actions_visibles(self):
        d = cd.Digest(24)
        d.item("crit", "<script>x</script>", "détail", "systemctl restart ipfs")
        out = cd.render(d, "nexus", "20h12.log")
        self.assertNotIn("<script>x", out)
        self.assertIn("systemctl restart ipfs", out)


if __name__ == "__main__":
    unittest.main()
