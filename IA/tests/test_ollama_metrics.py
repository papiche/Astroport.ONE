#!/usr/bin/env python3
"""ollama_metrics + ollama_stats + évènements de gpu_headroom — sans GPU.

    cd Astroport.ONE/IA && python3 -m unittest tests.test_ollama_metrics -v
"""
import glob
import json
import os
os.environ.setdefault("OLLAMA_METRICS_OFF", "1")      # les tests ne polluent pas ~/.zen/log/ollama_calls_*.jsonl
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import ollama_metrics as om  # noqa: E402
import ollama_stats as st  # noqa: E402
import gpu_headroom as g  # noqa: E402


class MetricsTests(unittest.TestCase):
    def setUp(self):
        self.d = tempfile.TemporaryDirectory()
        for mod in (om, st):
            p = mock.patch.object(mod, "LOG_DIR", self.d.name); p.start(); self.addCleanup(p.stop)
        self.addCleanup(self.d.cleanup)

    def rows(self):
        out = []
        for f in glob.glob(os.path.join(self.d.name, "ollama_calls_*.jsonl")):
            out += [json.loads(l) for l in open(f, encoding="utf-8")]
        return out

    def test_reponse_http_dict(self):
        om.record("chat", "gemma3:12b", wall_ms=900, resp={"load_duration": 2_500_000_000, "total_duration": 3_000_000_000,
                  "prompt_eval_count": 40, "eval_count": 150, "eval_duration": 2_000_000_000}, ctx=4096)
        r = self.rows()[0]
        self.assertEqual((r["load_ms"], r["gen_tokens"], r["tok_s"], r["ctx"], r["ok"]), (2500.0, 150, 75.0, 4096, True))

    def test_reponse_objet_bibliotheque(self):
        class R:
            load_duration = 1_000_000; eval_count = 10; eval_duration = 1_000_000_000
            def __getitem__(self, k): raise KeyError(k)
        om.record("chat", "m", wall_ms=5, resp=R())
        self.assertEqual(self.rows()[0]["tok_s"], 10.0)

    def test_echec_et_source(self):
        with om.source("memory_writer"):
            om.record("chat", "m", wall_ms=5, ok=False, error=RuntimeError("tunnel coupé"))
        r = self.rows()[0]
        self.assertEqual((r["ok"], r["source"], r["error"]), (False, "memory_writer", "tunnel coupé"))
        with mock.patch.dict(os.environ, {"OLLAMA_SOURCE": "commit.sh"}):
            om.record("chat", "m", wall_ms=5)
        self.assertEqual(self.rows()[-1]["source"], "commit.sh")

    def test_jamais_de_contenu(self):
        om.record("chat", "m", wall_ms=5, resp={"message": {"content": "secret"}, "response": "secret"})
        self.assertNotIn("secret", open(glob.glob(os.path.join(self.d.name, "*.jsonl"))[0]).read())

    def test_panne_d_ecriture_ne_casse_pas_l_appel(self):
        with mock.patch.object(om, "LOG_DIR", "/proc/interdit/x"):
            om.record("chat", "m", wall_ms=5)                 # ne lève pas
        om._warned[0] = False

    def test_stats_demarrages_a_froid(self):
        for ms in (0, 0, 0, 4000):
            om.record("chat", "gemma3:12b", wall_ms=1000 + ms, resp={"load_duration": ms * 1_000_000})
        om.record("chat", "gemma3:12b", wall_ms=1, extra={"source": "eval_memory"})
        s = st.summarize([r for r in st.load(1) if r["source"] not in st.TESTS])
        m = s["models"]["gemma3:12b"]
        self.assertEqual((m["calls"], m["cold_starts"], m["cold_pct"]), (4, 1, 25.0))

    def test_gpu_headroom_enregistre_attente_et_refus(self):
        from tests import test_gpu_headroom as tg
        with mock.patch.object(g, "_metric") as met:
            s = tg.Sim(2, busy=True).patch(); self.addCleanup(s.stop)
            with self.assertRaises(g.GpuBusy):
                g.ensure("gemma3:12b", wait=3)
            kinds = [c.args[0] for c in met.call_args_list]
            self.assertEqual(kinds, ["gpu_busy"])
            self.assertFalse(met.call_args.kwargs["ok"])
            self.assertTrue(met.call_args.kwargs["comfy_busy"])


def _entry(status="success", create=1000, start=1500, end=4500, err=None):
    msgs = [["execution_start", {"prompt_id": "p", "timestamp": str(start)}],
            ["execution_cached", {"nodes": ["2"], "prompt_id": "p", "timestamp": str(start + 100)}]]
    msgs.append(["execution_error", {"prompt_id": "p", "timestamp": str(end), **err}] if err
                else ["execution_success", {"prompt_id": "p", "timestamp": str(end)}])
    return {"prompt": [7, "p", {"1": {}, "2": {}, "3": {}}, {"client_id": "c", "create_time": create}, ["3"]],
            "outputs": {}, "status": {"status_str": status, "completed": status == "success", "messages": msgs}}


class ComfyTests(MetricsTests):
    def test_ligne_d_un_job_reussi(self):
        r = om.comfy_job_row("p", _entry())
        self.assertEqual((r["ok"], r["exec_ms"], r["queue_ms"], r["wall_ms"], r["nodes"]), (True, 3000, 500, 3500, 3))

    def test_job_en_erreur_oom(self):
        r = om.comfy_job_row("p", _entry("error", err={"exception_type": "torch.OutOfMemoryError",
                                                       "exception_message": "CUDA out of memory. Tried to allocate 2 GiB"}))
        self.assertFalse(r["ok"]); self.assertTrue(r["oom"]); self.assertIn("OutOfMemoryError", r["error"])

    def test_entree_incomplete_ne_plante_pas(self):
        r = om.comfy_job_row("p", {"status": {"status_str": "success", "messages": []}})
        self.assertEqual((r["ok"], r["exec_ms"], r["queue_ms"]), (True, None, None))

    def fetcher(self, entry, appear_after=0):
        calls = {"n": 0}
        def fetch(url, timeout=5):
            if url.endswith("/queue"):
                return {"queue_running": [1], "queue_pending": [2, 3]}
            if url.endswith("/system_stats"):
                return {"devices": [{"vram_free": 6 * 1024 ** 3}]}
            calls["n"] += 1
            return {"p": entry} if calls["n"] > appear_after else {}
        return fetch

    def test_observateur_enregistre_le_job(self):
        om.comfy_wait_and_record("generate_image", "p", fetch=self.fetcher(_entry(), appear_after=2), sleep=lambda s: None)
        r = self.rows()[0]
        self.assertEqual((r["kind"], r["model"], r["ok"], r["exec_ms"], r["queue_ms"], r["queue_ahead"], r["vram_free_gb"]),
                         ("comfy", "generate_image", True, 3000, 500, 2, 6.0))      # la file (3) contient le job lui-même : 2 devant lui

    def test_job_jamais_termine_est_un_echec_enregistre(self):
        clock = {"t": 0.0}
        def sleep(s): clock["t"] += s
        with mock.patch.object(om.time, "monotonic", lambda: clock["t"]):
            om.comfy_wait_and_record("x", "p", timeout=30, fetch=self.fetcher(_entry(), appear_after=10 ** 9), sleep=sleep)
        r = self.rows()[0]
        self.assertFalse(r["ok"]); self.assertIn("jamais terminé", r["error"])

    def test_bash_inline_jq(self):
        import subprocess
        lib = os.path.join(os.path.dirname(HERE), "generators", "lib", "gpu_room.sh")
        home = tempfile.mkdtemp(); self.addCleanup(lambda: __import__("shutil").rmtree(home, True))
        hist = json.dumps({"p": _entry(create=1000, start=1500, end=2300)})
        subprocess.run(["bash", "-c", f'. "{lib}"; gpu_comfy_record_inline faceid p \'{hist}\''],
                       env={**os.environ, "HOME": home, "OLLAMA_METRICS_OFF": "0", "IPFSNODEID": "n"}, check=True)
        row = json.loads(open(glob.glob(os.path.join(home, ".zen/log/ollama_calls_*.jsonl"))[0]).read())
        self.assertEqual((row["kind"], row["model"], row["ok"], row["exec_ms"], row["queue_ms"], row["wall_ms"], row["nodes"]),
                         ("comfy", "faceid", True, 800, 500, 1300, 3))


if __name__ == "__main__":
    unittest.main()
