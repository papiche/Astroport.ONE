"""Mémoire d'ARBOR : découpeur de code + recherche dans le code + historique des tentatives (Qdrant/Ollama simulés)."""
import io
import os
os.environ.setdefault("OLLAMA_METRICS_OFF", "1")      # les tests ne polluent pas ~/.zen/log/ollama_calls_*.jsonl
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import code_chunker as cc  # noqa: E402
import arbor_memory as am  # noqa: E402

PY = '''"""Module d'exemple : utilitaires de test pour le découpeur."""
import os

LIMITE = 10


def petite(a, b):
    """Additionne deux nombres."""
    return a + b


@decorateur
async def asynchrone(x):
    resultat = await quelque_chose(x)
    return resultat


class Service:
    """Un service."""

    def demarrer(self):
        return "ok"

    def arreter(self):
        return "stop"


if __name__ == "__main__":
    print(petite(1, 2))
    print(LIMITE)
    print("fin")
    print("encore")
    print("et encore")
    print("dernier")
'''


def by_symbol(chunks):
    return {c["symbol"]: c for c in chunks}


class ChunkerTests(unittest.TestCase):
    def test_python_fonctions_classes_et_lignes(self):
        ch = by_symbol(cc.chunk_file(PY, "py"))
        self.assertIn("petite", ch)
        self.assertIn("asynchrone", ch)
        self.assertIn("Service", ch)
        self.assertIn("en-tête", ch)
        lines = PY.split("\n")
        p = ch["petite"]
        self.assertTrue(lines[p["start_line"] - 1].startswith("def petite"))
        self.assertIn("return a + b", p["text"])

    def test_decorateur_inclus_dans_la_fonction(self):
        a = by_symbol(cc.chunk_file(PY, "py"))["asynchrone"]
        self.assertIn("@decorateur", a["text"])

    def test_en_tete_contient_docstring_et_imports(self):
        h = by_symbol(cc.chunk_file(PY, "py"))["en-tête"]
        self.assertIn("utilitaires de test", h["text"])
        self.assertIn("import os", h["text"])
        self.assertNotIn("def petite", h["text"])

    def test_aucun_recouvrement_entre_morceaux_python(self):
        ch = sorted(cc.chunk_file(PY, "py"), key=lambda c: c["start_line"])
        for a, b in zip(ch, ch[1:]):
            self.assertLess(a["end_line"], b["start_line"], (a["symbol"], b["symbol"]))

    def test_code_de_module_hors_definitions_conserve(self):
        ch = cc.chunk_file(PY, "py")
        mod = [c for c in ch if c["symbol"] == "code du module"]
        self.assertTrue(any("dernier" in c["text"] for c in mod))        # le point d'entrée n'est pas perdu
        self.assertFalse(any("def petite" in c["text"] for c in mod))    # et ne recouvre pas les fonctions

    def test_gros_fichier_python_syntaxe_invalide_replie_sur_fenetres(self):
        bad = "def casse(:\n" + "\n".join(f"ligne {i} avec du contenu suffisant" for i in range(150))
        ch = cc.chunk_file(bad, "py")
        self.assertTrue(ch and all(c["kind"] == "block" for c in ch))

    def test_fonction_geante_coupee_en_morceaux_bornes(self):
        corps = "\n".join(f"    x{i} = {i} * 2  # une ligne assez longue pour grossir" for i in range(400))
        ch = cc.chunk_file("def enorme():\n" + corps + "\n", "py")
        self.assertGreater(len(ch), 1)
        self.assertTrue(all(len(c["text"]) <= cc.MAX_CHARS for c in ch))
        self.assertEqual(ch[0]["symbol"], "enorme")
        self.assertTrue(any(c["symbol"].startswith("enorme#") for c in ch))

    def test_shell_fonctions_avec_commentaires_precedents(self):
        sh = ('#!/bin/bash\n## en-tête du script, assez long pour compter comme contenu\nX=1\n\n'
              '## Envoie un message au propriétaire\n_send_dm() {\n    echo "$1"\n    echo "$2"\n}\n\n'
              'function _autre() {\n    echo "autre fonction de test"\n    return 0\n}\n')
        ch = by_symbol(cc.chunk_file(sh, "sh"))
        self.assertIn("_send_dm", ch)
        self.assertIn("_autre", ch)
        self.assertIn("Envoie un message", ch["_send_dm"]["text"])        # le commentaire dit à quoi sert la fonction
        self.assertNotIn("_autre", ch["_send_dm"]["text"])

    def test_html_scripts_numeros_de_ligne_absolus(self):
        html = ("<!doctype html>\n<html>\n<body>\n<p>du balisage d'exemple assez long pour exister ici et là</p>\n"
                "<script>\nfunction ouvrir(x) {\n    return x + 1; // corps de la fonction ouvrir\n}\n\n"
                "async function fermer(y) {\n    return y - 1; // corps de la fonction fermer\n}\n</script>\n</body>\n</html>\n")
        ch = by_symbol(cc.chunk_file(html, "html"))
        self.assertIn("ouvrir", ch)
        self.assertIn("fermer", ch)
        lines = html.split("\n")
        self.assertIn("function ouvrir", lines[ch["ouvrir"]["start_line"] - 1])
        self.assertIn("function fermer", lines[ch["fermer"]["start_line"] - 1])

    def test_js_fonctions_fleches(self):
        js = ("const calculer = (a, b) => {\n    return a * b; // multiplication de deux nombres\n};\n\n"
              "function afficher(texte) {\n    console.log(texte); // affiche le texte donné\n}\n")
        ch = by_symbol(cc.chunk_file(js, "js"))
        self.assertIn("calculer", ch)
        self.assertIn("afficher", ch)

    def test_fichier_trivial_sans_morceau(self):
        self.assertEqual(cc.chunk_file("", "py"), [])
        self.assertEqual(cc.chunk_file("# vide\n", "py"), [])


def fake_qdrant(responses):
    """Simule Qdrant : `responses` = {(méthode, début de chemin): réponse}."""
    calls = []

    def f(method, path, payload=None):
        calls.append((method, path, payload))
        for (m, prefix), r in responses.items():
            if m == method and path.startswith(prefix):
                return r(payload) if callable(r) else r
        return {}
    f.calls = calls
    return f


HIT = lambda path, sym, score, text="def f(): pass": {"score": score, "payload": {
    "path": path, "symbol": sym, "kind": "function", "start_line": 10, "end_line": 20, "text": text, "project": "UPassport"}}


class ArborMemoryTests(unittest.TestCase):
    def setUp(self):
        self._e = mock.patch.object(am.ec, "embed", return_value=[0.1] * am.ec.DIM)
        self._e.start()
        self.addCleanup(self._e.stop)

    def test_search_code_dedoublonne_et_applique_le_seuil_doc(self):
        q = fake_qdrant({("POST", "/collections/codebase/points/search"): {"result": [
            HIT("a.py", "f", 0.7), HIT("a.py", "f", 0.69), HIT("b.py", "g", 0.6)]}})
        with mock.patch.object(am, "_qdrant", q):
            out = am.search_code("question", limit=5)
        self.assertEqual([(h["path"], h["symbol"]) for h in out], [("a.py", "f"), ("b.py", "g")])
        self.assertEqual(q.calls[0][2]["score_threshold"], am.ec.threshold("doc"))

    def test_search_code_leve_si_qdrant_ne_repond_pas(self):
        with mock.patch.object(am, "_qdrant", fake_qdrant({})):
            with self.assertRaises(RuntimeError):
                am.search_code("question")        # « aucun résultat » ≠ « Qdrant en panne »

    def test_code_context_formate_et_borne(self):
        q = fake_qdrant({("POST", "/collections/codebase/points/search"): {"result": [
            HIT("a.py", "f", 0.7, "x" * 5000), HIT("b.py", "g", 0.6, "y" * 5000)]}})
        with mock.patch.object(am, "_qdrant", q):
            ctx = am.code_context("q", limit=2, max_chars=1000)
        self.assertIn("LECTURE SEULE", ctx)
        self.assertIn("a.py:10-20", ctx)
        self.assertLess(len(ctx), 1800)
        with mock.patch.object(am, "_qdrant", fake_qdrant({("POST", "/collections/codebase/points/search"): {"result": []}})):
            self.assertEqual(am.code_context("q"), "")

    def test_record_run_refuse_un_resultat_inconnu(self):
        with self.assertRaises(ValueError):
            am.record_run("forge", "but", "peut-être")

    def test_record_run_masque_les_secrets_de_la_cause(self):
        q = fake_qdrant({("GET", "/collections/arbor_memory"): {"result": {"config": {"params": {"vectors": {"size": am.ec.DIM}}}}},
                         ("PUT", "/collections/arbor_memory/points"): {"result": True}})
        with mock.patch.object(am, "_qdrant", q):
            am.record_run("forge", "un but", "failed", reason="mon mot de passe est Xk29!fjd8392")
        pl = q.calls[-1][2]["points"][0]["payload"]
        self.assertNotIn("Xk29", pl["reason"])
        self.assertIn("masqué", pl["reason"])

    def test_historique_irremplacable_jamais_recree_si_dimension_differente(self):
        q = fake_qdrant({("GET", "/collections/arbor_memory"): {"result": {"config": {"params": {"vectors": {"size": 768}}}}}})
        with mock.patch.object(am, "_qdrant", q):
            with self.assertRaises(RuntimeError):
                am.record_run("forge", "but", "ok")
        self.assertFalse(any(c[0] == "DELETE" for c in q.calls))          # on ne détruit JAMAIS l'historique

    def test_runs_context_marque_les_echecs_avec_leur_cause_recents_d_abord(self):
        runs = [{"payload": {"kind": "forge", "goal": "météo", "outcome": "failed", "reason": "clé d'API exigée",
                             "at": "2026-10-01T10:00:00Z", "attempts": 3}, "score": 0.8},
                {"payload": {"kind": "forge", "goal": "météo bis", "outcome": "ok", "at": "2026-10-10T10:00:00Z",
                             "attempts": 1}, "score": 0.7}]
        q = fake_qdrant({("GET", "/collections/arbor_memory"): {"result": {"config": {"params": {"vectors": {"size": am.ec.DIM}}}}},
                         ("POST", "/collections/arbor_memory/points/search"): {"result": runs}})
        with mock.patch.object(am, "_qdrant", q):
            ctx = am.runs_context("outil météo")
        self.assertIn("❌ ÉCHEC", ctx)
        self.assertIn("clé d'API exigée", ctx)
        self.assertLess(ctx.index("météo bis"), ctx.index("« météo »"))     # le plus récent d'abord
        self.assertEqual(q.calls[-1][2]["score_threshold"], am.ec.threshold("cluster"))

    def test_memory_context_une_source_en_panne_n_empeche_pas_l_autre_et_le_dit(self):
        with mock.patch.object(am, "runs_context", side_effect=RuntimeError("Qdrant muet")), \
             mock.patch.object(am, "code_context", return_value="BLOC CODE"), \
             mock.patch("sys.stderr", new_callable=io.StringIO) as err:
            text, warns = am.memory_context("but")
        self.assertEqual(text, "BLOC CODE")
        self.assertEqual(len(warns), 1)
        self.assertIn("historique", warns[0])
        self.assertIn("Qdrant muet", err.getvalue())                         # jamais un échec silencieux

    def test_safe_record_ne_casse_jamais_la_tache(self):
        with mock.patch.object(am, "record_run", side_effect=RuntimeError("panne")), \
             mock.patch("sys.stderr", new_callable=io.StringIO) as err:
            self.assertIsNone(am.safe_record("forge", "but", "ok"))
        self.assertIn("non enregistrée", err.getvalue())


if __name__ == "__main__":
    unittest.main()
