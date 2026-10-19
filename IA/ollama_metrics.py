#!/usr/bin/env python3
"""
ollama_metrics.py — journal STRUCTURÉ des appels au GPU partagé (Ollama) : de quoi savoir, avec des chiffres, à quelle
fréquence un modèle est rechargé à froid, à quelles heures la file s'allonge, quelle source charge la carte, combien
de temps on attend la VRAM.

Une ligne JSON par appel, dans le dossier PERMANENT `~/.zen/log/ollama_calls_AAAAMMJJ.jsonl` (gzip après 2 jours,
purge après 30, par `20h12.process.sh`). Écriture en ajout d'une seule ligne : sûre entre processus concurrents.
JAMAIS de contenu (ni prompt, ni réponse, ni texte à vectoriser) : seulement des durées, des tailles et des noms.

Jobs ComfyUI (kind « comfy ») : un observateur DÉTACHÉ (`comfy_watch`, lancé juste après la soumission) interroge
`/history/<id>` jusqu'à la fin du job, puis enregistre exec_ms (début → fin d'exécution), queue_ms (création → début :
l'attente derrière les autres jobs de la carte partagée), wall_ms (création → fin), nodes, erreur (OOM compris),
queue_ahead et vram_free_gb au départ. Les trois durées viennent des horodatages du SERVEUR ComfyUI : aucun écart d'horloge
avec la station. `model` porte l'étiquette du job (script ou workflow). Aucune boucle d'attente existante n'est modifiée.

Champs : ts, station, source, kind (chat|generate|embed|vision|comfy|gpu_wait|gpu_busy|comfy_room), model, ok, error, wall_ms,
load_ms (chargement du modèle en VRAM : > 0 = démarrage à froid), total_ms, prompt_tokens, gen_tokens, tok_s, ctx, n_inputs.

  from ollama_metrics import start, record
  t = start(); r = ollama.chat(...); record("chat", model, t, resp=r, ctx=num_ctx)

`source` = OLLAMA_SOURCE (ex. « commit.sh »), sinon le contexte posé par `with source("memory_writer")`, sinon le nom du
script lancé. OLLAMA_METRICS_OFF=1 (posé par les tests unitaires) coupe l'écriture dans le vrai journal. Une panne d'écriture du journal est DITE sur stderr (une fois) mais ne casse jamais l'appel qu'elle mesure.
Analyse : `python3 ollama_stats.py [--days 7]`.
"""
import json
import os
import socket
import sys
import time
from contextlib import contextmanager

LOG_DIR = os.path.expanduser("~/.zen/log")
_DEFAULT_LOG_DIR = LOG_DIR
_source_stack = []
_warned = [False]


def start():
    return time.perf_counter()


@contextmanager
def source(name):
    """`with source("memory_writer"):` — étiquette les appels faits dans le bloc."""
    _source_stack.append(name)
    try:
        yield
    finally:
        _source_stack.pop()


def _src():
    return (os.environ.get("OLLAMA_SOURCE") or (_source_stack[-1] if _source_stack else "")
            or os.path.basename(sys.argv[0] or "") or "?")


def _f(resp, name):
    """Champ d'une réponse Ollama, qu'elle soit un dict (HTTP) ou un objet (bibliothèque ollama)."""
    if resp is None:
        return None
    if isinstance(resp, dict):
        return resp.get(name)
    try:
        return resp[name]
    except Exception:
        return getattr(resp, name, None)


def _ms(ns):
    return round(ns / 1e6, 1) if isinstance(ns, (int, float)) else None


def record(kind, model, t0=None, resp=None, ok=True, error=None, ctx=None, n_inputs=None, wall_ms=None, extra=None):
    if os.environ.get("OLLAMA_METRICS_OFF") == "1" and LOG_DIR == _DEFAULT_LOG_DIR:
        return                       # tests unitaires : ne JAMAIS écrire dans le vrai journal (les cartes y sont simulées)
    try:
        wall = wall_ms if wall_ms is not None else (round((time.perf_counter() - t0) * 1000, 1) if t0 is not None else None)
        ev, ed = _f(resp, "eval_count"), _f(resp, "eval_duration")
        row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "station": os.environ.get("IPFSNODEID") or socket.gethostname(),
               "source": _src(), "kind": kind, "model": model, "ok": bool(ok), "wall_ms": wall,
               "load_ms": _ms(_f(resp, "load_duration")), "total_ms": _ms(_f(resp, "total_duration")),
               "prompt_tokens": _f(resp, "prompt_eval_count"), "gen_tokens": ev,
               "tok_s": round(ev / (ed / 1e9), 1) if ev and ed else None, "ctx": ctx, "n_inputs": n_inputs, "pid": os.getpid()}
        if error:
            row["error"] = str(error)[:200]
        if extra:
            row.update(extra)
        row = {k: v for k, v in row.items() if v is not None}
        os.makedirs(LOG_DIR, exist_ok=True)
        with open(os.path.join(LOG_DIR, f"ollama_calls_{time.strftime('%Y%m%d')}.jsonl"), "a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
    except Exception as e:                                   # mesurer ne doit jamais casser l'appel mesuré
        if not _warned[0]:
            _warned[0] = True
            print(f"[ollama_metrics] ⚠️ journal des appels illisible/inscriptible ({e}) — mesures perdues", file=sys.stderr)


# ── jobs ComfyUI ────────────────────────────────────────────────────────────────────────────────────────────
COMFYUI_URL = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188")


def _http_json(url, timeout=5):
    import urllib.request
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.loads(r.read())


def comfy_job_row(prompt_id, entry):
    """Champs mesurés d'un job terminé, d'après son entrée /history (statuts et horodatages du serveur, en ms)."""
    st = entry.get("status") or {}
    msgs = st.get("messages") or []
    ts = {}
    for m in msgs:
        try:
            ts[m[0]] = int(m[1]["timestamp"])
        except (KeyError, ValueError, TypeError, IndexError):
            continue
    start = ts.get("execution_start")
    end = ts.get("execution_success") or ts.get("execution_error") or ts.get("execution_interrupted")
    prompt = entry.get("prompt") or []
    try:
        create = int(prompt[3]["create_time"])
    except (IndexError, KeyError, ValueError, TypeError):
        create = None
    err = next((m[1] for m in reversed(msgs) if m and m[0] == "execution_error"), None)
    row = {"ok": st.get("status_str") == "success",
           "exec_ms": end - start if start and end else None,
           "queue_ms": max(0, start - create) if start and create else None,
           "wall_ms": end - create if end and create else None,
           "nodes": len(prompt[2]) if len(prompt) > 2 and isinstance(prompt[2], dict) else None}
    if err:
        row["error"] = f"{err.get('exception_type', '')}: {err.get('exception_message', '')}".strip(": ")[:160]
        if "out of memory" in row["error"].lower():
            row["oom"] = True
    return row


def comfy_watch(label, prompt_id, timeout=3600):
    """Lance, DÉTACHÉ, l'observateur du job `prompt_id` (à appeler juste après la soumission à /prompt). Ne bloque pas,
    ne change rien à l'attente de l'appelant ; erreurs de l'observateur : ~/.zen/log/comfy_watch.log."""
    if os.environ.get("OLLAMA_METRICS_OFF") == "1" or not prompt_id or prompt_id == "null":
        return
    import subprocess
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(os.path.join(LOG_DIR, "comfy_watch.log"), "a", encoding="utf-8") as log:
        subprocess.Popen([sys.executable, os.path.abspath(__file__), "comfy", "--label", label, "--prompt-id", prompt_id,
                          "--timeout", str(timeout)], stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)


def comfy_wait_and_record(label, prompt_id, timeout=3600, fetch=None, sleep=None):
    """Corps de l'observateur : attend la fin du job sur /history/<id> (pas de 2 s, puis 5 s, puis 15 s : des vidéos durent
    des minutes) puis l'enregistre. `fetch`/`sleep` sont injectables (tests). Un job qui n'apparaît jamais est un ÉCHEC enregistré."""
    fetch = fetch or _http_json
    sleep = sleep or time.sleep
    t0 = time.monotonic()
    extra, first = {}, True
    entry, last_err = None, None
    while time.monotonic() - t0 < timeout:
        try:
            hist = fetch(f"{COMFYUI_URL}/history/{prompt_id}")
            if first:                                          # un seul coup d'œil à la file et à la VRAM, juste après la soumission
                first = False
                try:
                    q = fetch(f"{COMFYUI_URL}/queue")
                    extra["queue_ahead"] = max(0, len(q.get("queue_running") or []) + len(q.get("queue_pending") or [])
                                               - (0 if prompt_id in hist else 1))
                    dev = (fetch(f"{COMFYUI_URL}/system_stats").get("devices") or [{}])[0]
                    if dev.get("vram_free") is not None:
                        extra["vram_free_gb"] = round(dev["vram_free"] / 1024 ** 3, 1)
                except Exception:
                    pass
            if prompt_id in hist and (hist[prompt_id].get("status") or {}).get("status_str") in ("success", "error"):
                entry = hist[prompt_id]
                break
            last_err = None
        except Exception as e:
            last_err = e
        el = time.monotonic() - t0
        sleep(2 if el < 60 else 5 if el < 600 else 15)
    if entry is None:
        record("comfy", label, ok=False, wall_ms=round((time.monotonic() - t0) * 1000), extra={
            **extra, "error": f"job jamais terminé après {timeout}s ({last_err or 'absent de /history : ComfyUI redémarré ?'})"[:160]})
        return
    row = comfy_job_row(prompt_id, entry)
    ok = row.pop("ok")
    err = row.pop("error", None)
    record("comfy", label, ok=ok, error=err, wall_ms=row.pop("wall_ms", None), extra={**{k: v for k, v in row.items() if v is not None}, **extra})


def chat(**kwargs):
    """`ollama.chat(**kwargs)` AVEC le garde-fou VRAM (gpu_headroom.ensure, contexte compris) et la mesure. À utiliser par les
    appelants qui n'ont pas besoin d'autre chose que la réponse brute. GpuBusy et les erreurs d'Ollama sont relancées après
    avoir été journalisées."""
    import ollama
    import gpu_headroom
    model = kwargs["model"]
    ctx = (kwargs.get("options") or {}).get("num_ctx")
    gpu_headroom.ensure(model, ctx=ctx)
    kind = "vision" if any(m.get("images") for m in kwargs.get("messages") or [] if isinstance(m, dict)) else "chat"
    t0 = start()
    try:
        r = ollama.chat(**kwargs)
    except Exception as e:
        record(kind, model, t0, ok=False, error=e, ctx=ctx)
        raise
    record(kind, model, t0, resp=r, ctx=ctx)
    return r


def _main():
    """CLI pour les scripts bash : la réponse JSON d'Ollama sur stdin, la durée mesurée par l'appelant.
      ollama_metrics.py record --kind chat --model M --wall-ms 1234 --source generate_storyboard.sh <<< "$reponse"
    Une réponse vide ou illisible est enregistrée comme un échec (jamais ignorée)."""
    import argparse
    ap = argparse.ArgumentParser(description=_main.__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("record")
    r.add_argument("--kind", required=True); r.add_argument("--model", required=True)
    r.add_argument("--wall-ms", type=float, required=True); r.add_argument("--source"); r.add_argument("--ctx", type=int)
    c = sub.add_parser("comfy", help="observateur d'un job ComfyUI (lancé détaché par comfy_watch / gpu_comfy_watch)")
    c.add_argument("--label", required=True); c.add_argument("--prompt-id", required=True)
    c.add_argument("--timeout", type=int, default=3600)
    a = ap.parse_args()
    if a.cmd == "comfy":
        comfy_wait_and_record(a.label, a.prompt_id, a.timeout)
        return
    raw = sys.stdin.read().strip()
    try:
        resp = json.loads(raw)
        ok, err = isinstance(resp, dict) and not resp.get("error"), (resp.get("error") if isinstance(resp, dict) else None)
    except ValueError:
        resp, ok, err = None, False, "réponse vide ou illisible"
    if a.source:
        os.environ["OLLAMA_SOURCE"] = a.source
    record(a.kind, a.model, resp=resp, ok=ok, error=err, ctx=a.ctx, wall_ms=a.wall_ms)


if __name__ == "__main__":
    _main()
