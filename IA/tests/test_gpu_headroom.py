#!/usr/bin/env python3
"""gpu_headroom : décisions de VRAM avant un appel Ollama, sans GPU (sondes simulées).

    cd Astroport.ONE/IA && python3 -m unittest tests.test_gpu_headroom -v
"""
import os
os.environ.setdefault("OLLAMA_METRICS_OFF", "1")      # les tests ne polluent pas ~/.zen/log/ollama_calls_*.jsonl
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import gpu_headroom as g  # noqa: E402

GB = g.GB


class Sim:
    """Une carte simulée : VRAM libre, ComfyUI occupé ou non, modèles Ollama chargés."""
    def __init__(self, free_gb, busy=False, loaded=None, comfy_up=True, free_after_release=None, loaded_ctx=None):
        self.free, self.busy, self.loaded, self.up = free_gb * GB, busy, dict(loaded or {}), comfy_up
        self.loaded_ctx = loaded_ctx or {}
        self.release_to, self.freed_calls, self.now = free_after_release, 0, 0.0
        self.same = True

    def get(self, url, timeout=3):
        if url.endswith("/api/ps"):
            return {"models": [{"name": k, "size_vram": v * GB, **({"context_length": self.loaded_ctx[k]} if k in self.loaded_ctx else {})}
                               for k, v in self.loaded.items()]}
        if url.endswith("/api/tags"):
            return {"models": [{"name": "gemma3:12b", "size": int(8.1 * GB)}, {"name": "bge-m3:latest", "size": int(1.2 * GB)},
                               {"name": "qwen2.5-coder:14b", "size": int(9.0 * GB)}]}
        if not self.up:
            raise OSError("connexion refusée")
        if url.endswith("/system_stats"):
            return {"devices": [{"vram_total": 24 * GB, "vram_free": self.free}]}
        if url.endswith("/queue"):
            return {"queue_running": [1] if self.busy else [], "queue_pending": []}
        raise AssertionError(url)

    def post(self, url, body, timeout=10):
        if url.endswith("/api/show"):                         # qwen2.5-coder:14b : 48 couches, 8 têtes KV, 40 têtes, 5120 → 192 Ko/jeton
            return {"model_info": {"qwen2.block_count": 48, "qwen2.attention.head_count": 40,
                                   "qwen2.attention.head_count_kv": 8, "qwen2.embedding_length": 5120}}
        assert url.endswith("/free")
        self.freed_calls += 1
        if self.release_to is not None:
            self.free = self.release_to * GB
        return {}

    def sleep(self, s):
        self.now += s

    def clock(self):
        return self.now

    def patch(self):
        g._ps_cache.update(t=-100.0, v=None, ctx={}); g._kv_cache.clear()
        ps = [mock.patch.object(g, "_get", self.get), mock.patch.object(g, "_post", self.post),
              mock.patch.object(g, "_sleep", self.sleep), mock.patch.object(g, "_clock", self.clock),
              mock.patch.object(g, "_log", lambda m: None),
              mock.patch.object(g, "same_gpu", lambda: self.same)]
        for p in ps:
            p.start()
        self.ps = ps
        return self

    def stop(self):
        for p in self.ps:
            p.stop()


class HeadroomTests(unittest.TestCase):
    def sim(self, *a, **k):
        s = Sim(*a, **k).patch()
        self.addCleanup(s.stop)
        return s

    def test_modele_deja_charge_passe_sans_sonder_la_carte(self):
        s = self.sim(0.2, busy=True, loaded={"gemma3:12b": 8.6})
        g.ensure("gemma3:12b", wait=5)                        # carte pleine et ComfyUI occupé : peu importe
        self.assertEqual(s.freed_calls, 0)

    def test_assez_de_place(self):
        self.sim(15, busy=True)
        g.ensure("gemma3:12b", wait=5)

    def test_insuffisant_comfyui_inactif_on_le_fait_liberer(self):
        s = self.sim(2, busy=False, free_after_release=20)
        g.ensure("gemma3:12b", wait=5)
        self.assertEqual(s.freed_calls, 1)

    def test_insuffisant_comfyui_occupe_on_attend_puis_gpubusy(self):
        s = self.sim(2, busy=True)
        with self.assertRaises(g.GpuBusy) as cm:
            g.ensure("gemma3:12b", wait=10)
        self.assertEqual(s.freed_calls, 0)                    # jamais /free pendant un job ComfyUI
        self.assertIn("ComfyUI occupé", str(cm.exception))
        self.assertGreaterEqual(s.now, 9)                     # il a bien attendu

    def test_la_place_revient_pendant_l_attente(self):
        s = self.sim(2, busy=True)
        real = s.get
        calls = {"n": 0}
        def get(url, timeout=3):
            if url.endswith("/system_stats"):
                calls["n"] += 1
                if calls["n"] >= 3:
                    s.free = 20 * GB
            return real(url, timeout)
        with mock.patch.object(g, "_get", get):
            g.ensure("gemma3:12b", wait=30)
        self.assertLess(s.now, 30)

    def test_modeles_ollama_dechargeables_comptent(self):
        # 3 Go libres + un autre modèle de 9 Go que l'ordonnanceur d'Ollama peut décharger
        self.sim(3, busy=True, loaded={"qwen3:14b": 9.3})
        g.ensure("gemma3:12b", wait=2)

    def test_comfyui_injoignable_on_passe(self):
        self.sim(0, comfy_up=False)
        g.ensure("gemma3:12b", wait=2)

    def test_ollama_muet_on_passe(self):
        s = self.sim(0)
        with mock.patch.object(g, "_get", side_effect=OSError("tunnel coupé")):
            g.ensure("gemma3:12b", wait=2)

    def test_desactivable(self):
        self.sim(0, busy=True)
        with mock.patch.dict(os.environ, {"GPU_HEADROOM_OFF": "1"}):
            g.ensure("gemma3:12b", wait=1)

    def test_need_gb_explicite(self):
        self.sim(2, busy=True)
        with self.assertRaises(g.GpuBusy):
            g.ensure(need_gb=10, wait=2)


class ContextTests(unittest.TestCase):
    """Le cache KV du contexte demandé compte : commit.sh demande 32 768 jetons à un modèle de 14 Md."""
    def sim(self, *a, **k):
        s = Sim(*a, **k).patch(); self.addCleanup(s.stop); return s

    def test_estimation_du_cache_kv(self):
        self.sim(20)
        self.assertEqual(g.kv_bytes("qwen2.5-coder:14b", 1), 192 * 1024)             # 192 Ko par jeton
        self.assertAlmostEqual(g.kv_bytes("qwen2.5-coder:14b", 32768) / GB, 6.0, delta=0.1)

    def test_grand_contexte_exige_plus_de_place(self):
        self.sim(14, busy=True)                       # 14 Go libres : 9,9 + 1 + 1 + 0,8 (4k) passe, 32k (+6 Go) non
        g.ensure("qwen2.5-coder:14b", wait=2, ctx=4096)
        with self.assertRaises(g.GpuBusy):
            g.ensure("qwen2.5-coder:14b", wait=2, ctx=32768)

    def test_modele_charge_avec_petit_contexte_et_gros_contexte_demande(self):
        # chargé à 4096 (Ollama le dit), on en demande 32768 : rechargement, donc contrôle — et l'ancien chargement se libère
        # 9 Go libres + 10 Go de l'ancien chargement = 19 Go ≥ 17,9 Go requis (poids 9,9 + KV 6 + marge 1 + réserve 1)
        s = self.sim(9, busy=True, loaded={"qwen2.5-coder:14b": 10.0}, loaded_ctx={"qwen2.5-coder:14b": 4096})
        g.ensure("qwen2.5-coder:14b", wait=2, ctx=32768)


    def test_rechargement_impossible_si_carte_pleine(self):
        self.sim(0.5, busy=True, loaded={"qwen2.5-coder:14b": 10.0}, loaded_ctx={"qwen2.5-coder:14b": 4096})
        with self.assertRaises(g.GpuBusy):
            g.ensure("qwen2.5-coder:14b", wait=2, ctx=32768)

    def test_modele_charge_avec_assez_de_contexte_voie_rapide(self):
        s = self.sim(0.1, busy=True, loaded={"qwen2.5-coder:14b": 16.0}, loaded_ctx={"qwen2.5-coder:14b": 32768})
        g.ensure("qwen2.5-coder:14b", wait=2, ctx=16384)

    def test_dimensions_inconnues_repli(self):
        s = self.sim(20)
        with mock.patch.object(g, "_post", side_effect=OSError("show refusé")):
            self.assertEqual(g.kv_bytes("modele-inconnu", 1000), g.KV_FALLBACK_BYTES * 1000)


class ComfyRoomTests(unittest.TestCase):
    """Sens inverse : un job ComfyUI exige qu'Ollama lui laisse la place."""
    def run_sim(self, loaded, allow=True, release=True):
        s = Sim(2, busy=False, loaded=loaded).patch()
        self.addCleanup(s.stop)
        unloaded = []
        def post(url, body, timeout=10):
            unloaded.append(body["model"])
            if release:
                s.loaded.pop(body["model"], None)
            return {}
        p = mock.patch.object(g, "_post", post); p.start(); self.addCleanup(p.stop)
        q = mock.patch.object(g, "ALLOW_OLLAMA_UNLOAD", allow); q.start(); self.addCleanup(q.stop)
        return s, unloaded

    def test_assez_de_place_rien_n_est_decharge(self):
        s, un = self.run_sim({"bge-m3:latest": 0.7, "gemma3:12b": 8.6})        # 24 − 9,3 = 14,7 Go pour un job de 10
        g.make_room_for_comfy(10)
        self.assertEqual(un, [])

    def test_trop_peu_on_decharge_le_plus_gros_d_abord(self):
        s, un = self.run_sim({"bge-m3:latest": 0.7, "gemma3:12b": 8.6, "qwen3:14b": 9.3})   # 24 − 18,6 = 5,4 < 19
        g.make_room_for_comfy(18)
        self.assertEqual(un[0], "qwen3:14b")
        self.assertNotIn("bge-m3:latest", un)                                  # s'arrête dès que la place est faite

    def test_interdit_de_decharger(self):
        s, un = self.run_sim({"gemma3:12b": 8.6, "qwen3:14b": 9.3}, allow=False)
        with self.assertRaises(g.GpuBusy):
            g.make_room_for_comfy(18)
        self.assertEqual(un, [])

    def test_ollama_ne_libere_pas_gpubusy(self):
        s, un = self.run_sim({"gemma3:12b": 8.6, "qwen3:14b": 9.3}, release=False)
        with self.assertRaises(g.GpuBusy):
            g.make_room_for_comfy(18, wait=5)

    def test_comfyui_injoignable_rien_a_faire(self):
        s = Sim(0, comfy_up=False).patch(); self.addCleanup(s.stop)
        g.make_room_for_comfy(18)


class SameGpuTests(unittest.TestCase):
    """Ollama et ComfyUI ne se contrôlent que s'ils sont servis par la MÊME machine."""
    def setUp(self):
        g._host_cache.clear(); g._warned.clear()
        for k in ("GPU_SAME_HOST", "GPU_OLLAMA_HOST", "GPU_COMFYUI_HOST"):
            os.environ.pop(k, None)
        self.addCleanup(lambda: [os.environ.pop(k, None) for k in ("GPU_SAME_HOST", "GPU_OLLAMA_HOST", "GPU_COMFYUI_HOST")])
        for p in (mock.patch.object(g, "_log", lambda m: None), mock.patch.object(g, "_ssh_target", lambda port: None)):
            p.start(); self.addCleanup(p.stop)

    def peers(self, mapping):
        p = mock.patch.object(g, "_p2p_peer", lambda port: mapping.get(port)); p.start(); self.addCleanup(p.stop)

    def test_meme_pair_ipfs_meme_gpu(self):
        self.peers({11434: "12D3KooWAAA", 8188: "12D3KooWAAA"})
        self.assertTrue(g.same_gpu())

    def test_pairs_differents_gpu_distincts(self):
        self.peers({11434: "12D3KooWAAA", 8188: "12D3KooWBBB"})
        self.assertFalse(g.same_gpu())

    def test_ollama_distant_comfyui_local(self):
        self.peers({11434: "12D3KooWAAA"})
        self.assertFalse(g.same_gpu())

    def test_deux_services_locaux_meme_machine(self):
        self.peers({})
        self.assertTrue(g.same_gpu())

    def test_tunnel_ssh_compte_comme_machine(self):
        self.peers({})
        with mock.patch.object(g, "_ssh_target", lambda port: "gpu@10.0.0.9" if port == 8188 else None):
            self.assertFalse(g.same_gpu())            # Ollama local, ComfyUI derrière ssh : deux machines

    def test_url_distante_directe(self):
        self.peers({})
        with mock.patch.object(g, "OLLAMA_URL", "http://gpu.example:11434"):
            self.assertFalse(g.same_gpu())

    def test_declaration_explicite_prime(self):
        self.peers({11434: "12D3KooWAAA", 8188: "12D3KooWBBB"})
        os.environ["GPU_SAME_HOST"] = "1"
        self.assertTrue(g.same_gpu())

    def test_identite_inconnue_suppose_partage(self):
        with mock.patch.object(g, "host_id", side_effect=OSError("ipfs muet")):
            self.assertTrue(g.same_gpu())
            os.environ["GPU_ASSUME_SHARED"] = "0"
            try:
                self.assertFalse(g.same_gpu())
            finally:
                os.environ.pop("GPU_ASSUME_SHARED")

    def test_gpu_distincts_ensure_et_make_room_s_abstiennent(self):
        s = Sim(0, busy=True).patch(); self.addCleanup(s.stop)
        s.same = False                                 # carte de ComfyUI pleine et occupée : sans rapport avec Ollama
        g.ensure("gemma3:12b", wait=2)
        g.make_room_for_comfy(18)
        self.assertEqual(s.freed_calls, 0)

    def test_wait_idle_et_paced(self):
        s = Sim(20, busy=True).patch(); self.addCleanup(s.stop)
        with self.assertRaises(g.GpuBusy):
            g.wait_idle(wait=6)
        s.busy = False
        calls = []
        f = g.paced(lambda: calls.append(s.now), gap=5.0)
        f(); f()
        self.assertGreaterEqual(calls[1] - calls[0], 5.0)   # espacés d'au moins 5 s

    def test_wait_idle_ne_gene_pas_si_gpu_distincts(self):
        s = Sim(0, busy=True).patch(); self.addCleanup(s.stop)
        s.same = False
        g.wait_idle(wait=1)


if __name__ == "__main__":
    unittest.main()
