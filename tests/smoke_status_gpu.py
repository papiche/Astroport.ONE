#!/usr/bin/env python3
"""Test de fumée de la carte « 🎮 Usage du GPU partagé » de templates/status.html (aucun contact avec le GPU) :
sert le gabarit, simule 12345.json (avec/sans gpu_usage), le pointeur CID et l'historique, et relève les erreurs JS.
Usage : ~/.astro/bin/python3 Astroport.ONE/tests/smoke_status_gpu.py"""
import json, os, subprocess, sys, tempfile, time, shutil
from datetime import date, timedelta
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
tmp = tempfile.mkdtemp()
shutil.copy(os.path.join(ROOT, "templates", "status.html"), os.path.join(tmp, "status.html"))
PORT = 8767
srv = subprocess.Popen([sys.executable, "-m", "http.server", str(PORT), "--bind", "127.0.0.1"], cwd=tmp,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1.0)
today = date.today()
days = {}
for i in range(12):
    d = (today - timedelta(days=i)).isoformat()
    days[d] = {"calls": 40 + i * 3, "errors": 0, "cold_starts": i % 4, "gen_tokens": 900, "p50_ms": 800 + i * 50, "p95_ms": 4000,
               "by_model": {"gemma3:12b": {"calls": 30, "cold": 1}}, "by_source": {"question.py": 30}, "hours": [i % 5] * 24,
               "waits": i % 3, "wait_s": 2.0, "busy": 1 if i == 3 else 0, "comfy_room": 0, "unloaded": {},
               "comfy": {"jobs": 5 + i, "errors": 1 if i == 2 else 0, "oom": 0, "exec_p50_ms": 12000 + i * 300, "queue_p50_ms": 800,
                         "by_label": {"generate_video": 3}, "hours": [0] * 24}}
GPU = {"available": True, "since": min(days), "days_recorded": len(days),
       "today": {"calls": 42, "cold_starts": 1}, "week": {"calls": 300, "cold_starts": 9, "cold_pct": 3.0, "p50_ms": 1234, "waits": 4, "busy": 1,
       "errors": 0, "top_model": "gemma3:12b", "top_source": "question.py", "comfy_room": 2, "unloaded": {"qwen3:14b": 2},
       "comfy": {"jobs": 52, "errors": 1, "oom": 1, "exec_p50_ms": 12500, "queue_p50_ms": 900, "top_label": "generate_video"}},
       "hours_comfy_7d": [0, 0, 0, 0, 0, 0, 0, 2, 6, 9, 7, 3, 1, 4, 8, 7, 3, 2, 0, 0, 0, 0, 0, 0],
       "hours_7d": [0, 0, 0, 0, 0, 0, 1, 5, 12, 20, 18, 9, 6, 8, 14, 17, 11, 7, 3, 2, 1, 0, 0, 0]}
BASE = {"hostname": "test", "captain": "c", "IPCity": "x", "created": str(int(time.time())), "version": "12345.0.2", "economy": {}}

def run(gpu_usage, label):
    errs = []
    with sync_playwright() as p:
        b = p.chromium.launch(args=["--no-sandbox"]); page = b.new_page()
        page.on("pageerror", lambda e: errs.append(str(e)))
        def route(r):
            u = r.request.url
            if u.endswith("/12345.json"):
                return r.fulfill(status=200, content_type="application/json", body=json.dumps({**BASE, "gpu_usage": gpu_usage}))
            if u.endswith("/GPU/gpu_history.json.ipfs"):
                return r.fulfill(status=200, content_type="text/plain", body="bafyTESTCID")
            if u.endswith("/ipfs/bafyTESTCID"):
                return r.fulfill(status=200, content_type="application/json", body=json.dumps({"since": GPU["since"], "days": days}))
            if f"127.0.0.1:{PORT}" in u:
                return r.continue_()
            return r.fulfill(status=200, content_type="application/json", body="{}")
        page.route("**/*", route)
        page.goto(f"http://127.0.0.1:{PORT}/status.html", wait_until="load"); page.wait_for_timeout(2000)
        vis = page.evaluate("() => getComputedStyle(document.getElementById('card-gpu')).display")
        out = {"carte": "visible" if vis != "none" else "masquée"}
        if vis != "none":
            out["boîtes"] = page.evaluate("() => ['gpu-today','gpu-cold','gpu-p50','gpu-wait','gpu-comfy','gpu-comfy-t'].map(i => document.getElementById(i).textContent)")
            out["barres"] = page.eval_on_selector_all("#gpu-chart rect.chart-bar", "e => e.length")
            out["barres_heures"] = page.eval_on_selector_all("#gpu-hours rect.chart-bar", "e => e.length")
            out["barres_heures_comfy"] = page.eval_on_selector_all("#gpu-hours-comfy rect.chart-bar", "e => e.length")
            out["détail"] = page.inner_text("#gpu-detail")[:140]
            for m in ("cold", "p50", "waits", "comfy", "cexec", "cqueue"):
                page.click(f"button[onclick*=\"setGpuMetric('{m}'\"]"); page.wait_for_timeout(150)
                out[f"résumé_{m}"] = page.inner_text("#gpu-hist-summary")[:70]
            page.click("button[onclick*=\"setGpuDuration(7\"]"); page.wait_for_timeout(150)
            out["barres_7j"] = page.eval_on_selector_all("#gpu-chart rect.chart-bar", "e => e.length")
            out["autre carte intacte (énergie masquée)"] = page.evaluate("() => getComputedStyle(document.getElementById('card-energy')).display")
        b.close()
    print(f"── {label}"); [print(f"   {k}: {v}") for k, v in out.items()]
    print(f"   erreurs JS : {sorted(set(errs)) or 'aucune'}")
run(GPU, "avec gpu_usage")
run({"available": False}, "sans gpu_usage")
srv.terminate(); shutil.rmtree(tmp, ignore_errors=True)
