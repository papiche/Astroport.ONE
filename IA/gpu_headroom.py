#!/usr/bin/env python3
"""
gpu_headroom.py — « y a-t-il assez de VRAM avant que je demande ce modèle à Ollama ? »

La RTX 3090 de la constellation est PARTAGÉE (Ollama et ComfyUI, tous deux joints par ipfs p2p). Quand Ollama charge un
modèle de 8 Go alors que ComfyUI occupe la carte, l'un des deux tombe en « out of memory » — et un job ComfyUI peut faire
planter le GPU. Chaque appel qui PEUT charger un modèle appelle donc `ensure(modèle)` avant de poser sa question.

Voie rapide (la quasi-totalité des appels) : le modèle est DÉJÀ chargé dans Ollama (`/api/ps`) → rien à charger, on passe
(un seul GET de quelques ms, mis en cache 3 s). Sinon (chargement à venir) :
  1. mémoire nécessaire = poids du modèle (`/api/tags`) × 1,1 + marge de calcul/contexte + réserve laissée à ComfyUI ;
  2. mémoire disponible = VRAM libre de la CARTE (`/system_stats` de ComfyUI : `vram_free`, toutes applications
     confondues) + les modèles Ollama déjà chargés que son ordonnanceur peut décharger (autres que celui demandé) ;
  3. insuffisant et ComfyUI INACTIF (rien en cours ni en attente) → on lui demande de libérer ses modèles (`/free`, comme
     les générateurs le font déjà) puis on recompte ;
  4. insuffisant et ComfyUI OCCUPÉ → on ATTEND (retraits croissants) jusqu'à `wait` secondes ; passé ce délai :
     `GpuBusy` — le message dit combien manque, jamais un repli silencieux. L'appelant le traite comme une panne d'IA
     (l'apprentissage reporte son lot, BRO répond qu'il est occupé).
Ollama et ComfyUI sur des machines DIFFÉRENTES (stations distinctes de l'essaim, GPU distincts) : aucun contrôle croisé
(la VRAM de l'un ne dit rien de l'autre) — l'identité de la machine vient du pair `ipfs p2p` derrière chaque tunnel.
Si ComfyUI est injoignable on ne peut RIEN mesurer : on passe et on l'écrit dans le journal (pas de concurrent connu).

Journal permanent (rotation par 20h12.process.sh) : ~/.zen/log/gpu_headroom_AAAAMMJJ.log — seulement les évènements
(attente, libération de ComfyUI, refus, sonde en échec), pas les passages de la voie rapide.

  gpu_headroom.py check [--model gemma3:12b [--ctx 32768] | --need-gb 10] [--wait 30]   # code 0 = place, 3 = GPU occupé (utilisable en bash)
  gpu_headroom.py comfy-room --need-gb 10 [--label X]   # SENS INVERSE, avant un job ComfyUI : Ollama libère-t-il la place ?
  gpu_headroom.py status                                                    # VRAM, ComfyUI, modèles Ollama chargés
Réglages (env) : OLLAMA_URL, COMFYUI_URL, GPU_HEADROOM_WAIT (30 s), GPU_RESERVE_GB (1.0), GPU_MARGIN_GB (1.0),
GPU_ALLOW_COMFY_FREE (1), GPU_ALLOW_OLLAMA_UNLOAD (1), GPU_COUNT_OLLAMA_EVICTABLE (1),
GPU_SAME_HOST (1|0 : déclare si Ollama et ComfyUI partagent la carte), GPU_OLLAMA_HOST / GPU_COMFYUI_HOST (identité imposée), GPU_ASSUME_SHARED (1), GPU_HEADROOM_OFF (1 = désactivé).
"""
import json
import os
import sys
import time
import urllib.request

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
COMFYUI_URL = os.environ.get("COMFYUI_URL", "http://127.0.0.1:8188")
GB = 1024 ** 3
DEFAULT_WAIT = float(os.environ.get("GPU_HEADROOM_WAIT", "30"))
RESERVE_GB = float(os.environ.get("GPU_RESERVE_GB", "1.0"))     # laissé libre pour les pointes de ComfyUI
MARGIN_GB = float(os.environ.get("GPU_MARGIN_GB", "1.0"))       # cache KV + calcul d'Ollama au-delà des poids
ALLOW_COMFY_FREE = os.environ.get("GPU_ALLOW_COMFY_FREE", "1") == "1"
COUNT_EVICTABLE = os.environ.get("GPU_COUNT_OLLAMA_EVICTABLE", "1") == "1"
PS_TTL = 3.0
DEFAULT_CTX = int(os.environ.get("GPU_DEFAULT_CTX", "4096"))     # contexte que prend Ollama quand l'appelant n'en demande pas
KV_FALLBACK_BYTES = 160 * 1024                                   # octets de cache KV par jeton si le modèle ne le dit pas


class GpuBusy(RuntimeError):
    """La carte n'a pas la place de charger le modèle demandé dans le délai accordé."""


# ── entrées/sorties isolées (remplaçables dans les tests) ───────────────────
def _get(url, timeout=3):
    with urllib.request.urlopen(url, timeout=timeout) as r:
        return json.loads(r.read())


def _post(url, body, timeout=10):
    req = urllib.request.Request(url, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        raw = r.read()
        return json.loads(raw) if raw.strip().startswith((b"{", b"[")) else {}


_sleep = time.sleep
_clock = time.monotonic
_ps_cache = {"t": 0.0, "v": None, "ctx": {}}
_kv_cache = {}


def _metric(kind, model, t0, ok=True, **extra):
    """Évènement structuré (attente de VRAM, refus, libération) dans ~/.zen/log/ollama_calls_*.jsonl."""
    try:
        import ollama_metrics
        ollama_metrics.record(kind, model, ok=ok, wall_ms=round((_clock() - t0) * 1000, 1), extra=extra or None)
    except Exception as e:
        print(f"[gpu_headroom] ⚠️ mesure non enregistrée ({e})", file=sys.stderr)


def _log(msg):
    try:
        d = os.path.expanduser("~/.zen/log")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, f"gpu_headroom_{time.strftime('%Y%m%d')}.log"), "a", encoding="utf-8") as f:
            f.write(f"{time.strftime('%H:%M:%S')} pid={os.getpid()} {msg}\n")
    except OSError:
        pass
    print(f"[gpu_headroom] {msg}", file=sys.stderr)


# ── sondes ──────────────────────────────────────────────────────────────────
def ollama_loaded(fresh=False):
    """{nom_du_modèle: octets de VRAM} des modèles chargés dans Ollama (mis en cache 3 s). Lève si Ollama ne répond pas."""
    if not fresh and _ps_cache["v"] is not None and _clock() - _ps_cache["t"] < PS_TTL:
        return _ps_cache["v"]
    models = _get(f"{OLLAMA_URL}/api/ps").get("models", [])
    v = {m["name"]: m.get("size_vram") or m.get("size") or 0 for m in models}
    _ps_cache.update(t=_clock(), v=v, ctx={m["name"]: m.get("context_length") for m in models})   # context_length : Ollama récent
    return v


def model_bytes(model):
    for m in _get(f"{OLLAMA_URL}/api/tags").get("models", []):
        if m["name"] == model or m["name"] == f"{model}:latest" or m.get("model") == model:
            return m["size"]
    return 0


def kv_bytes(model, ctx):
    """Cache KV (fp16) d'Ollama pour `ctx` jetons : 2 × couches × têtes KV × dimension de tête × 2 octets × ctx. Les
    dimensions viennent de /api/show (métadonnées, aucun chargement) ; sans elles, 160 Ko/jeton. C'est une estimation
    PAR EXCÈS pour les modèles à fenêtre glissante. Exemple : qwen2.5-coder:14b (48 couches, 8 têtes KV de 128) =
    192 Ko/jeton → 32 768 jetons ≈ 6,3 Go, soit plus des deux tiers des poids."""
    if model not in _kv_cache:
        per = KV_FALLBACK_BYTES
        try:
            info = _post(f"{OLLAMA_URL}/api/show", {"model": model}).get("model_info") or {}
            def pick(suffix):
                for k, v in info.items():
                    if k.endswith(suffix):
                        return max(v) if isinstance(v, list) else v
            layers, kvh, heads = pick(".block_count"), pick(".attention.head_count_kv"), pick(".attention.head_count")
            emb, hd = pick(".embedding_length"), pick(".attention.key_length")
            hd = hd or (emb // heads if emb and heads else None)
            if layers and kvh and hd:
                per = 2 * layers * kvh * hd * 2
        except Exception as e:
            _log(f"⚠️ dimensions de {model} inconnues ({e}) : cache KV estimé à {KV_FALLBACK_BYTES // 1024} Ko/jeton")
        _kv_cache[model] = per
    return _kv_cache[model] * ctx


def comfy_state():
    """{free, total, busy} ou None si ComfyUI est injoignable. `free` = VRAM libre de TOUTE la carte (torch.mem_get_info)."""
    try:
        st = _get(f"{COMFYUI_URL}/system_stats")
        dev = (st.get("devices") or [{}])[0]
        if not dev.get("vram_total"):
            return None                                   # ComfyUI sur CPU : pas de GPU à protéger par ici
        q = _get(f"{COMFYUI_URL}/queue")
        return {"free": dev.get("vram_free", 0), "total": dev["vram_total"],
                "busy": bool(q.get("queue_running") or q.get("queue_pending"))}
    except Exception:
        return None


def comfy_free_models():
    _post(f"{COMFYUI_URL}/free", {"unload_models": True, "free_memory": True})


# ── même GPU ? Ollama et ComfyUI ne se gênent que s'ils sont servis par la MÊME machine ───────────────────────
# Pour la plupart des stations le GPU est distant (tunnel `ipfs p2p`), et dans l'essaim chaque service peut être
# servi par une station différente. Le contrôle croisé n'a de sens que si les deux sont sur la même carte ; sinon
# la VRAM libre lue chez ComfyUI ne dit RIEN d'Ollama (et inversement) : on s'abstient (aucune attente à tort).
# Identité de la machine qui sert une URL : le pair ipfs p2p derrière le port local (le nom de protocole
# `/x/ollama-<pair>` / `/x/comfyui-<pair>` le porte), sinon la cible d'un tunnel ssh, sinon « local » (service réellement
# local), sinon l'hôte de l'URL. Déclaration explicite possible : GPU_SAME_HOST=1|0, GPU_OLLAMA_HOST, GPU_COMFYUI_HOST.
IPFS_API = os.environ.get("IPFS_API", "http://127.0.0.1:5001")
_host_cache = {}
_LOOPBACK = ("127.0.0.1", "localhost", "::1", "0.0.0.0")


def _p2p_peer(port):
    """Pair ipfs p2p vers lequel ce nœud redirige le port local `port`, ou None."""
    import re
    d = _post(f"{IPFS_API}/api/v0/p2p/ls", {}, timeout=3)
    for l in d.get("Listeners") or []:
        if f"/tcp/{port}" in (l.get("ListenAddress") or ""):
            m = re.search(r"12D3Koo\w+|Qm\w{44}", (l.get("TargetAddress") or "") + " " + (l.get("Protocol") or ""))
            if m:
                return m.group(0)
    return None


def _ssh_target(port):
    """Cible d'un tunnel ssh qui écoute sur le port local `port`, ou None."""
    import re
    import subprocess
    out = subprocess.run(["ss", "-ltnpH", f"sport = :{port}"], capture_output=True, text=True, timeout=3).stdout
    m = re.search(r'\("ssh",pid=(\d+)', out)
    if not m:
        return None
    with open(f"/proc/{m.group(1)}/cmdline", "rb") as f:
        args = [a.decode("utf-8", "replace") for a in f.read().split(b"\0") if a]
    return next((a for a in reversed(args[1:]) if not a.startswith("-") and ("@" in a or "." in a)), None)


def host_id(url, override_env):
    ov = os.environ.get(override_env)
    if ov:
        return ov
    hit = _host_cache.get(url)
    if hit and _clock() - hit[0] < 60:
        return hit[1]
    from urllib.parse import urlparse
    u = urlparse(url)
    port = u.port or (443 if u.scheme == "https" else 80)
    if u.hostname not in _LOOPBACK:
        ident = f"host:{u.hostname}"                       # joint directement : l'hôte de l'URL EST la machine
    else:
        ident = None
        for probe, tag in ((_p2p_peer, "p2p"), (_ssh_target, "ssh")):
            try:
                v = probe(port)
            except Exception:
                v = None
            if v:
                ident = f"{tag}:{v}"
                break
        ident = ident or "local"                           # rien ne redirige ce port : le service tourne ici
    _host_cache[url] = (_clock(), ident)
    return ident


_warned = set()


def same_gpu():
    """True si Ollama et ComfyUI sont servis par la même machine (donc la même carte). Machine non identifiable →
    GPU_ASSUME_SHARED (1 par défaut : mieux vaut attendre à tort que charger un modèle sur une carte pleine)."""
    forced = os.environ.get("GPU_SAME_HOST")
    if forced in ("0", "1"):
        return forced == "1"
    try:
        a, b = host_id(OLLAMA_URL, "GPU_OLLAMA_HOST"), host_id(COMFYUI_URL, "GPU_COMFYUI_HOST")
    except Exception as e:
        if "id" not in _warned:
            _warned.add("id")
            _log(f"⚠️ machines non identifiables ({e}) : GPU supposé partagé (GPU_ASSUME_SHARED)")
        return os.environ.get("GPU_ASSUME_SHARED", "1") == "1"
    if a != b and "diff" not in _warned:
        _warned.add("diff")
        _log(f"ℹ️ Ollama ({a}) et ComfyUI ({b}) sont sur des machines DIFFÉRENTES : pas de contrôle croisé de la VRAM")
    return a == b


# ── décision ────────────────────────────────────────────────────────────────
def needed_bytes(model=None, need_gb=None, ctx=None):
    if need_gb is not None:
        return int((need_gb + RESERVE_GB) * GB)
    return int(model_bytes(model) * 1.1 + kv_bytes(model, ctx or DEFAULT_CTX) + (MARGIN_GB + RESERVE_GB) * GB)


def ensure(model=None, need_gb=None, wait=None, ctx=None):
    """Retourne quand la carte peut accueillir `model` (avec `ctx` jetons de contexte) ; lève GpuBusy sinon. Jamais
    bloquant plus de `wait` secondes. Un modèle déjà chargé avec un contexte PLUS PETIT que `ctx` sera rechargé par
    Ollama (poids + cache KV agrandi) : ce n'est pas la voie rapide."""
    if os.environ.get("GPU_HEADROOM_OFF") == "1":
        return
    wait = DEFAULT_WAIT if wait is None else wait
    reload = False
    if model:
        try:
            loaded = ollama_loaded()
        except Exception as e:
            _log(f"⚠️ Ollama ne répond pas à /api/ps ({e}) — pas de contrôle, l'appel dira lui-même s'il échoue")
            return
        name = model if model in loaded else (f"{model}:latest" if f"{model}:latest" in loaded else None)
        if name:
            have = _ps_cache["ctx"].get(name) or DEFAULT_CTX     # contexte du chargement actuel (Ollama ancien : défaut supposé)
            reload = bool(ctx and ctx > have)
            if not reload:
                return                                     # voie rapide : déjà en VRAM avec assez de contexte, rien à charger
    if not same_gpu():
        return                                             # chacun sa carte : Ollama gère seul la sienne
    try:
        need = needed_bytes(model, need_gb, ctx)
    except Exception as e:
        _log(f"⚠️ taille de {model} inconnue ({e}) — pas de contrôle")
        return

    t_slow = _clock()
    deadline = t_slow + wait
    delay, freed, announced = 1.0, False, False
    while True:
        st = comfy_state()
        if st is None:
            _log(f"ℹ️ ComfyUI injoignable : VRAM non mesurable pour {model or need_gb} — appel autorisé")
            return
        evictable = 0
        if COUNT_EVICTABLE:
            try:
                evictable = sum(v for k, v in ollama_loaded(fresh=True).items()
                                if reload or (k != model and k != f"{model}:latest"))   # un rechargement libère l'ancien chargement
            except Exception:
                pass
        avail = st["free"] + evictable
        if avail >= need:
            if announced or freed:
                _log(f"✅ place faite pour {model or need_gb} ({avail / GB:.1f} Go dispo ≥ {need / GB:.1f} Go)")
                _metric("gpu_wait", model, t_slow, need_gb=round(need / GB, 1), avail_gb=round(avail / GB, 1),
                        freed_comfy=freed, reload=reload, ctx=ctx)
            return
        if not st["busy"] and ALLOW_COMFY_FREE and not freed:
            _log(f"⚠️ {avail / GB:.1f} Go dispo < {need / GB:.1f} Go requis pour {model or need_gb}, ComfyUI inactif : "
                 "libération de ses modèles")
            try:
                comfy_free_models()
            except Exception as e:
                _log(f"⚠️ /free refusé par ComfyUI : {e}")
            freed = True
            _sleep(1.5)
            continue
        if _clock() >= deadline:
            msg = (f"VRAM insuffisante pour {model or f'{need_gb} Go'} : {avail / GB:.1f} Go disponibles, "
                   f"{need / GB:.1f} Go requis ({'ComfyUI occupé' if st['busy'] else 'ComfyUI inactif'}), délai de {wait:.0f} s dépassé")
            _log("⛔ " + msg)
            _metric("gpu_busy", model, t_slow, ok=False, need_gb=round(need / GB, 1), avail_gb=round(avail / GB, 1),
                    comfy_busy=st["busy"], ctx=ctx)
            raise GpuBusy(msg)
        if not announced:
            _log(f"⏳ {model or need_gb} attend la VRAM : {avail / GB:.1f} Go dispo < {need / GB:.1f} Go requis "
                 f"({'ComfyUI occupé' if st['busy'] else 'ComfyUI inactif'})")
            announced = True
        _sleep(min(delay, max(0.1, deadline - _clock())))
        delay = min(delay * 2, 8.0)


# ── sens inverse : un job ComfyUI s'assure qu'OLLAMA lui laisse la place ───────────────────────────────────
# ComfyUI gère seul ses propres modèles (il en évince pour charger les siens) et met ses jobs en file : ce qui peut
# l'étouffer, c'est la VRAM que garde OLLAMA (jusqu'à `keep_alive`, 5 à 30 min après le dernier appel). Condition :
# VRAM totale − VRAM résidente d'Ollama ≥ besoin du job + réserve. Sinon on décharge des modèles Ollama, du plus gros au
# plus petit (`keep_alive: 0` : Ollama termine d'abord les requêtes en cours, puis libère) ; le prochain appel Ollama
# rechargera le sien — un coût de quelques secondes, contre un GPU qui plante.
ALLOW_OLLAMA_UNLOAD = os.environ.get("GPU_ALLOW_OLLAMA_UNLOAD", "1") == "1"


def ollama_unload(model):
    _post(f"{OLLAMA_URL}/api/generate", {"model": model, "keep_alive": 0}, timeout=30)


def make_room_for_comfy(need_gb, label="job ComfyUI", wait=30):
    """À appeler AVANT de soumettre un job à ComfyUI (`need_gb` = estimation de sa VRAM de pointe).
    Retourne quand Ollama ne gêne plus ; lève GpuBusy si la place ne peut pas être faite."""
    if os.environ.get("GPU_HEADROOM_OFF") == "1":
        return
    if not same_gpu():
        return                                  # Ollama est sur une autre machine : il ne peut pas gêner ce job
    st = comfy_state()
    if st is None:
        return                                  # ComfyUI injoignable : le job le dira lui-même ; rien à protéger ici
    try:
        loaded = dict(ollama_loaded(fresh=True))
    except Exception as e:
        _log(f"⚠️ Ollama ne répond pas à /api/ps ({e}) — on suppose qu'il n'occupe rien pour {label}")
        return
    need = int((need_gb + RESERVE_GB) * GB)
    room = st["total"] - sum(loaded.values())
    if room >= need:
        return
    if not ALLOW_OLLAMA_UNLOAD:
        msg = (f"{label} : {room / GB:.1f} Go laissés par Ollama < {need / GB:.1f} Go requis, "
               "déchargement d'Ollama interdit (GPU_ALLOW_OLLAMA_UNLOAD=0)")
        _log("⛔ " + msg)
        raise GpuBusy(msg)
    t_room, unloaded = _clock(), []
    _log(f"⚠️ {label} a besoin de {need / GB:.1f} Go, Ollama en garde {sum(loaded.values()) / GB:.1f} Go "
         f"({', '.join(f'{k} {v / GB:.1f}' for k, v in loaded.items())}) : déchargement du plus gros au plus petit")
    for name, size in sorted(loaded.items(), key=lambda kv: -kv[1]):
        if room >= need:
            break
        try:
            ollama_unload(name)
            unloaded.append(name)
            room += size
            _log(f"↘ {name} déchargé ({size / GB:.1f} Go)")
        except Exception as e:
            _log(f"⚠️ déchargement de {name} refusé : {e}")
    deadline = _clock() + wait                   # Ollama termine ses requêtes en cours avant de libérer : on constate
    while True:
        try:
            left = sum(ollama_loaded(fresh=True).values())
        except Exception:
            left = 0
        if st["total"] - left >= need:
            _metric("comfy_room", label, t_room, need_gb=round(need / GB, 1), unloaded=",".join(unloaded))
            return
        if _clock() >= deadline:
            msg = (f"{label} : Ollama garde encore {left / GB:.1f} Go après {wait:.0f} s (requêtes en cours ?), "
                   f"{need / GB:.1f} Go requis")
            _log("⛔ " + msg)
            _metric("comfy_room", label, t_room, ok=False, need_gb=round(need / GB, 1), unloaded=",".join(unloaded))
            raise GpuBusy(msg)
        _sleep(1.0)


# ── tests et mesures : jamais de rafale sur le GPU partagé ──────────────────────────────────────────────────
def wait_idle(wait=120):
    """Avant une requête de TEST au LLM : si ComfyUI partage la carte, attend qu'il n'ait ni job en cours ni en attente.
    Lève GpuBusy au bout de `wait` secondes : un test peut attendre, il ne passe jamais devant le travail des autres."""
    if os.environ.get("GPU_HEADROOM_OFF") == "1" or not same_gpu():
        return
    deadline = _clock() + wait
    while True:
        st = comfy_state()
        if st is None or not st["busy"]:
            return
        if _clock() >= deadline:
            msg = f"ComfyUI occupé depuis {wait:.0f} s : test reporté pour ne pas surcharger le GPU partagé"
            _log("⛔ " + msg)
            raise GpuBusy(msg)
        _sleep(3.0)


def paced(fn, gap=3.0):
    """Enveloppe `fn` (un appel au LLM) pour les tests : un seul à la fois, au moins `gap` secondes entre deux appels,
    et seulement quand ComfyUI est au repos (wait_idle)."""
    last = [None]

    def wrapper(*a, **k):
        if last[0] is not None:
            wait = gap - (_clock() - last[0])
            if wait > 0:
                _sleep(wait)
        wait_idle()
        try:
            return fn(*a, **k)
        finally:
            last[0] = _clock()
    return wrapper


def status():
    out = {"comfyui": comfy_state()}
    try:
        out["hotes"] = {"ollama": host_id(OLLAMA_URL, "GPU_OLLAMA_HOST"), "comfyui": host_id(COMFYUI_URL, "GPU_COMFYUI_HOST"),
                        "meme_gpu": same_gpu()}
    except Exception as e:
        out["hotes"] = f"ERROR: {e}"
    try:
        out["ollama_loaded_go"] = {k: round(v / GB, 1) for k, v in ollama_loaded(fresh=True).items()}
    except Exception as e:
        out["ollama_loaded_go"] = f"ERROR: {e}"
    return out


def main():
    import argparse
    ap = argparse.ArgumentParser(description="VRAM disponible avant un appel Ollama")
    sub = ap.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("check")
    c.add_argument("--model"); c.add_argument("--need-gb", type=float); c.add_argument("--wait", type=float)
    c.add_argument("--ctx", type=int, help="contexte demandé (jetons) : le cache KV compte dans la place nécessaire")
    r = sub.add_parser("comfy-room", help="avant un job ComfyUI : Ollama libère-t-il assez de VRAM ?")
    r.add_argument("--need-gb", type=float, required=True); r.add_argument("--label", default="job ComfyUI")
    r.add_argument("--wait", type=float, default=30)
    sub.add_parser("status")
    a = ap.parse_args()
    if a.cmd == "comfy-room":
        try:
            make_room_for_comfy(a.need_gb, a.label, a.wait)
            print("OK")
        except GpuBusy as e:
            print(f"ERROR:gpu_busy: {e}")
            sys.exit(3)
        return
    if a.cmd == "status":
        s = status()
        if s["comfyui"]:
            s["comfyui"] = {**s["comfyui"], "free_go": round(s["comfyui"]["free"] / GB, 1), "total_go": round(s["comfyui"]["total"] / GB, 1)}
        print(json.dumps(s, ensure_ascii=False, indent=1))
        return
    if not (a.model or a.need_gb):
        sys.exit("ERROR: --model ou --need-gb requis")
    try:
        ensure(a.model, a.need_gb, a.wait, a.ctx)
        print("OK")
    except GpuBusy as e:
        print(f"ERROR:gpu_busy: {e}")
        sys.exit(3)


if __name__ == "__main__":
    main()
