#!/usr/bin/env python3
"""
ollama_stats.py — lit les journaux `~/.zen/log/ollama_calls_*.jsonl[.gz]` (écrits par ollama_metrics.py) et dit ce que
le GPU partagé vit : démarrages à froid, latences, sources qui le chargent, heures de pointe, attentes de VRAM.

  python3 ollama_stats.py                 # 7 derniers jours
  python3 ollama_stats.py --days 1 --json
  python3 ollama_stats.py --include-tests # compte aussi eval_memory / bench_memory (exclus par défaut)

Rendu pour status.html (appelé par 20h12.process.sh et _12345.sh, même recette que les cartes Solaire et Consommation) :
  python3 ollama_stats.py record-daily    # agrège les 3 derniers jours des journaux dans l'historique PERMANENT
                                          #   ~/.zen/game/gpu/gpu_history.json  {since, days:{AAAA-MM-JJ:{...}}} (idempotent)
  python3 ollama_stats.py gpu-stats       # instantané léger (jour, 7 jours, heures de pointe) pour le 12345.json
  python3 ollama_stats.py publish-cid     # épingle l'historique sur IPFS, écrit SEULEMENT le CID dans
                                          #   ~/.zen/tmp/$IPFSNODEID/GPU/gpu_history.json.ipfs (pointeur léger)

Chaque station n'y voit que SES appels au GPU partagé : la carte est mutualisée entre stations, pas son journal.
Lecture seule côté GPU : aucun appel au GPU.
"""
import argparse
import glob
import gzip
import json
import os
import statistics
import sys
import time
from collections import Counter, defaultdict

LOG_DIR = os.path.expanduser("~/.zen/log")
HISTORY_FILE = os.environ.get("GPU_HISTORY_FILE", os.path.expanduser("~/.zen/game/gpu/gpu_history.json"))
CID_POINTER = os.environ.get("GPU_CID_POINTER",
                             os.path.expanduser(f"~/.zen/tmp/{os.environ.get('IPFSNODEID', 'unknown')}/GPU/gpu_history.json.ipfs"))
TESTS = {"eval_memory", "bench_memory"}
COLD_MS = 500          # un chargement de modèle de plus de 0,5 s = démarrage à froid (un modèle déjà en VRAM : ~0-50 ms)


def load(days):
    rows, since = [], time.strftime("%Y%m%d", time.localtime(time.time() - (days - 1) * 86400))
    for path in sorted(glob.glob(os.path.join(LOG_DIR, "ollama_calls_*.jsonl*"))):
        day = os.path.basename(path).split("_")[2][:8]
        if day < since:
            continue
        op = gzip.open if path.endswith(".gz") else open
        with op(path, "rt", encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                try:
                    rows.append(json.loads(line))
                except ValueError:
                    print(f"⚠️ {os.path.basename(path)} ligne {n} illisible, ignorée", file=sys.stderr)
    return rows


def pct(vals, q):
    vals = sorted(vals)
    return vals[min(len(vals) - 1, int(len(vals) * q))] if vals else None


def summarize(rows):
    calls = [r for r in rows if r["kind"] in ("chat", "generate", "embed", "vision")]
    out = {"calls": len(calls), "errors": sum(1 for r in calls if not r.get("ok", True)),
           "gpu_wait": [r for r in rows if r["kind"] == "gpu_wait"], "gpu_busy": [r for r in rows if r["kind"] == "gpu_busy"],
           "comfy_room": [r for r in rows if r["kind"] == "comfy_room"], "models": {}, "sources": {}, "hours": {}, "stations": {}}
    by_model = defaultdict(list)
    for r in calls:
        by_model[r["model"]].append(r)
    for m, rs in by_model.items():
        wall = [r["wall_ms"] for r in rs if r.get("wall_ms") is not None]
        loads = [r["load_ms"] for r in rs if r.get("load_ms") is not None]
        cold = [r for r in rs if (r.get("load_ms") or 0) > COLD_MS]
        toks = [r["tok_s"] for r in rs if r.get("tok_s")]
        out["models"][m] = {"calls": len(rs), "p50_ms": round(statistics.median(wall)) if wall else None, "p95_ms": round(pct(wall, .95)) if wall else None,
                            "cold_starts": len(cold), "cold_pct": round(100 * len(cold) / len(rs), 1),
                            "cold_load_ms_median": round(statistics.median([r["load_ms"] for r in cold])) if cold else None,
                            "tok_s_median": round(statistics.median(toks), 1) if toks else None,
                            "errors": sum(1 for r in rs if not r.get("ok", True))}
    out["comfy"] = day_entry([r for r in rows if r["kind"] == "comfy"])["comfy"]
    out["sources"] = dict(Counter(r["source"] for r in calls).most_common())
    out["hours"] = dict(sorted(Counter(r["ts"][11:13] for r in calls).items()))
    out["stations"] = dict(Counter(r["station"][:16] for r in calls).most_common())
    return out


# ── historique quotidien (rendu status.html) ────────────────────────────────────────────────────────────
def day_entry(rows):
    """Agrégat d'UNE journée d'appels (hors tests). Petit (≈ 1 Ko) : l'historique complet est publié sur IPFS."""
    calls = [r for r in rows if r["kind"] in ("chat", "generate", "embed", "vision")]
    slow = [r["wall_ms"] for r in calls if r["kind"] != "embed" and r.get("wall_ms") is not None]
    by_model = defaultdict(list)
    for r in calls:
        by_model[r["model"]].append(r)
    waits = [r for r in rows if r["kind"] == "gpu_wait"]
    jobs = [r for r in rows if r["kind"] == "comfy"]
    ex, qu = [r["exec_ms"] for r in jobs if r.get("exec_ms") is not None], [r["queue_ms"] for r in jobs if r.get("queue_ms") is not None]
    comfy = {"jobs": len(jobs), "errors": sum(1 for r in jobs if not r.get("ok", True)), "oom": sum(1 for r in jobs if r.get("oom")),
             "exec_p50_ms": round(statistics.median(ex)) if ex else None, "exec_p95_ms": round(pct(ex, .95)) if ex else None,
             "queue_p50_ms": round(statistics.median(qu)) if qu else None, "queue_p95_ms": round(pct(qu, .95)) if qu else None,
             "by_label": dict(Counter(r["model"] for r in jobs).most_common(8)),
             "hours": [sum(1 for r in jobs if int(r["ts"][11:13]) == h) for h in range(24)]}
    return {
        "comfy": comfy,
        "calls": len(calls), "errors": sum(1 for r in calls if not r.get("ok", True)),
        "cold_starts": sum(1 for r in calls if (r.get("load_ms") or 0) > COLD_MS),
        "gen_tokens": sum(r.get("gen_tokens") or 0 for r in calls),
        "p50_ms": round(statistics.median(slow)) if slow else None, "p95_ms": round(pct(slow, .95)) if slow else None,
        "by_model": {m: {"calls": len(rs), "cold": sum(1 for r in rs if (r.get("load_ms") or 0) > COLD_MS)} for m, rs in by_model.items()},
        "by_source": dict(Counter(r["source"] for r in calls).most_common(8)),
        "hours": [sum(1 for r in calls if int(r["ts"][11:13]) == h) for h in range(24)],
        "waits": len(waits), "wait_s": round(sum(r.get("wall_ms", 0) for r in waits) / 1000, 1),
        "busy": sum(1 for r in rows if r["kind"] == "gpu_busy"),
        "comfy_room": sum(1 for r in rows if r["kind"] == "comfy_room"),
        "unloaded": dict(Counter(m for r in rows if r["kind"] == "comfy_room" for m in (r.get("unloaded") or "").split(",") if m)),
    }


def read_history():
    try:
        with open(HISTORY_FILE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"since": None, "days": {}}


def record_daily(days=3):
    """Réécrit l'entrée de chacun des `days` derniers jours présents dans les journaux (idempotent : pas de double compte).
    Un jour sans aucun appel n'est pas écrit (une station sans IA ne crée pas de bruit)."""
    rows = [r for r in load(days) if r.get("source") not in TESTS]
    by_day = defaultdict(list)
    for r in rows:
        by_day[r["ts"][:10]].append(r)
    if not by_day:
        print("record-daily : aucun appel enregistré sur la période — historique inchangé", file=sys.stderr)
        return 0
    h = read_history()
    for day, rs in by_day.items():
        h["days"][day] = day_entry(rs)
    h["since"] = min([h.get("since") or "9999"] + list(by_day))
    os.makedirs(os.path.dirname(HISTORY_FILE), exist_ok=True)
    tmp = HISTORY_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(h, f, ensure_ascii=False)
    os.replace(tmp, HISTORY_FILE)
    print(f"record-daily : {len(by_day)} jour(s) écrit(s) → {HISTORY_FILE} ({len(h['days'])} jours au total)")
    return len(by_day)


def gpu_stats():
    """Instantané LÉGER pour le 12345.json : le jour, les 7 derniers jours, les heures de pointe. Jamais l'historique entier."""
    h = read_history()
    if not h["days"]:
        return None
    today = time.strftime("%Y-%m-%d")
    last7 = [h["days"][d] for d in sorted(h["days"]) if d >= time.strftime("%Y-%m-%d", time.localtime(time.time() - 6 * 86400))]

    def agg(entries):
        calls = sum(e["calls"] for e in entries)
        meds = [(e["p50_ms"], e["calls"]) for e in entries if e.get("p50_ms") is not None]
        models, sources, unloaded = Counter(), Counter(), Counter()
        for e in entries:
            for m, v in e["by_model"].items():
                models[m] += v["calls"]
            sources.update(e["by_source"])
            unloaded.update(e.get("unloaded", {}))
        cj = [e.get("comfy") or {} for e in entries]
        jobs = sum(c.get("jobs", 0) for c in cj)
        def wmed(key):                                   # médiane des médianes journalières, pondérée par le nombre de jobs
            pairs = [(c[key], c["jobs"]) for c in cj if c.get(key) is not None and c.get("jobs")]
            return round(sum(v * n for v, n in pairs) / sum(n for _, n in pairs)) if pairs else None
        labels = Counter()
        for c in cj:
            labels.update(c.get("by_label", {}))
        comfy = {"jobs": jobs, "errors": sum(c.get("errors", 0) for c in cj), "oom": sum(c.get("oom", 0) for c in cj),
                 "exec_p50_ms": wmed("exec_p50_ms"), "queue_p50_ms": wmed("queue_p50_ms"),
                 "queue_p95_ms_max": max([c.get("queue_p95_ms") or 0 for c in cj] or [0]) or None,
                 "top_label": labels.most_common(1)[0][0] if labels else None}
        return {"comfy": comfy, "calls": calls, "errors": sum(e["errors"] for e in entries), "cold_starts": sum(e["cold_starts"] for e in entries),
                "cold_pct": round(100 * sum(e["cold_starts"] for e in entries) / calls, 1) if calls else 0,
                "p50_ms": round(sum(m * n for m, n in meds) / sum(n for _, n in meds)) if meds else None,
                "p95_ms": max([e["p95_ms"] for e in entries if e.get("p95_ms")] or [0]) or None,
                "gen_tokens": sum(e["gen_tokens"] for e in entries), "waits": sum(e["waits"] for e in entries),
                "wait_s": round(sum(e["wait_s"] for e in entries), 1), "busy": sum(e["busy"] for e in entries),
                "comfy_room": sum(e["comfy_room"] for e in entries),
                "top_model": models.most_common(1)[0][0] if models else None,
                "top_source": sources.most_common(1)[0][0] if sources else None, "unloaded": dict(unloaded)}
    hours = [sum(e["hours"][i] for e in last7) for i in range(24)]
    hours_comfy = [sum((e.get("comfy") or {}).get("hours", [0] * 24)[i] for e in last7) for i in range(24)]
    return {"hours_comfy_7d": hours_comfy, "since": h.get("since"), "days_recorded": len(h["days"]), "today": agg([h["days"][today]] if today in h["days"] else []),
            "week": agg(last7), "hours_7d": hours}


def publish_cid():
    """Épingle l'historique complet sur IPFS et n'écrit que son CID (quelques octets) sous ~/.zen/tmp/$IPFSNODEID/ :
    le fichier qui grossit lui-même n'alourdit jamais la balise IPNS (même principe que power_monitor.sh publish-cid)."""
    import subprocess
    if not os.path.exists(HISTORY_FILE) or os.path.getsize(HISTORY_FILE) == 0:
        print(f"publish-cid : historique introuvable ou vide : {HISTORY_FILE}", file=sys.stderr)
        return 1
    if not os.environ.get("IPFSNODEID"):
        print("publish-cid : IPFSNODEID absent de l'environnement — pointeur non écrit", file=sys.stderr)
        return 1
    try:
        cid = subprocess.run(["ipfs", "add", "-q", HISTORY_FILE], capture_output=True, text=True, timeout=30,
                             check=True).stdout.strip().splitlines()[-1]
    except (subprocess.SubprocessError, OSError, IndexError) as e:
        print(f"publish-cid : échec de l'ajout IPFS ({e})", file=sys.stderr)
        return 1
    old = ""
    if os.path.exists(CID_POINTER):
        old = open(CID_POINTER, encoding="utf-8").read().strip()
    os.makedirs(os.path.dirname(CID_POINTER), exist_ok=True)
    with open(CID_POINTER, "w", encoding="utf-8") as f:
        f.write(cid)
    print(f"publish-cid : historique GPU épinglé {cid} → {CID_POINTER}")
    if old and old != cid:
        r = subprocess.run(["ipfs", "pin", "rm", old], capture_output=True, text=True)
        if r.returncode != 0:
            print(f"publish-cid : désépinglage de {old} échoué (non bloquant)", file=sys.stderr)
    return 0


def main():
    if len(sys.argv) > 1 and sys.argv[1] in ("record-daily", "gpu-stats", "publish-cid"):
        cmd = sys.argv[1]
        if cmd == "record-daily":
            n = int(sys.argv[2]) if len(sys.argv) > 2 else 3
            sys.exit(0 if record_daily(n) >= 0 else 1)
        if cmd == "gpu-stats":
            st = gpu_stats()
            if st is None:
                sys.exit("gpu-stats : aucun historique (record-daily pas encore exécuté ou aucun appel au GPU)")
            print(json.dumps(st, ensure_ascii=False, separators=(",", ":")))
            return
        sys.exit(publish_cid())
    ap = argparse.ArgumentParser(description="Statistiques des appels au GPU partagé")
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--include-tests", action="store_true")
    a = ap.parse_args()
    rows = load(a.days)
    if not a.include_tests:
        rows = [r for r in rows if r.get("source") not in TESTS]
    if not rows:
        print(f"Aucun appel enregistré sur {a.days} jour(s) dans {LOG_DIR}/ollama_calls_*.jsonl (instrumentation récente ?)")
        return
    s = summarize(rows)
    if a.json:
        print(json.dumps({k: v for k, v in s.items() if k not in ("gpu_wait", "gpu_busy", "comfy_room")} |
                         {"gpu_wait": len(s["gpu_wait"]), "gpu_busy": len(s["gpu_busy"]), "comfy_room": len(s["comfy_room"])},
                         ensure_ascii=False, indent=1))
        return
    print(f"Appels au GPU partagé — {a.days} jour(s) : {s['calls']} appels, {s['errors']} en erreur\n")
    print(f"  {'modèle':28} {'appels':>7} {'médiane':>9} {'p95':>9} {'à froid':>12} {'charg. froid':>13} {'jet/s':>7}")
    for m, v in sorted(s["models"].items(), key=lambda kv: -kv[1]["calls"]):
        print(f"  {m:28} {v['calls']:>7} {v['p50_ms']:>7} ms {v['p95_ms']:>7} ms {v['cold_starts']:>5} ({v['cold_pct']:>4}%) "
              f"{(str(v['cold_load_ms_median']) + ' ms') if v['cold_load_ms_median'] else '—':>13} {v['tok_s_median'] or '—':>7}")
    c = s["comfy"]
    if c["jobs"]:
        print(f"\n  Jobs ComfyUI : {c['jobs']} ({c['errors']} en échec dont {c['oom']} mémoire saturée) · exécution médiane "
              f"{c['exec_p50_ms']} ms (p95 {c['exec_p95_ms']} ms) · attente en file médiane {c['queue_p50_ms']} ms (p95 {c['queue_p95_ms']} ms)")
        print("    par job :", ", ".join(f"{k} {n}" for k, n in c["by_label"].items()))
    print("\n  Sources :", ", ".join(f"{k} {n}" for k, n in s["sources"].items()))
    print("  Stations :", ", ".join(f"{k} {n}" for k, n in s["stations"].items()))
    if s["hours"]:
        peak = max(s["hours"], key=s["hours"].get)
        print("  Heures (appels) :", " ".join(f"{h}h:{n}" for h, n in s["hours"].items()), f"  → pointe {peak}h")
    print(f"\n  Attentes de VRAM : {len(s['gpu_wait'])} (durée médiane "
          f"{round(statistics.median([r['wall_ms'] for r in s['gpu_wait']]) / 1000, 1) if s['gpu_wait'] else '—'} s), "
          f"refus GPU occupé : {len(s['gpu_busy'])}, places faites pour ComfyUI : {len(s['comfy_room'])}")
    for r in s["gpu_busy"][-5:]:
        print(f"    ⛔ {r['ts']} {r.get('source', '?')} {r['model']} : {r.get('avail_gb')} Go dispo / {r.get('need_gb')} requis (ComfyUI occupé : {r.get('comfy_busy')})")
    if s["comfy_room"]:
        un = Counter(m for r in s["comfy_room"] for m in (r.get("unloaded") or "").split(",") if m)
        print("    modèles Ollama déchargés pour ComfyUI :", ", ".join(f"{k} ×{n}" for k, n in un.most_common()) or "aucun")


if __name__ == "__main__":
    main()
