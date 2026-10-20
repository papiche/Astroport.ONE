#!/usr/bin/env python3
"""
captain_digest.py — le briefing quotidien du Capitaine (remplace l'envoi du journal 20h12 brut dans le corps du mail).

    python3 captain_digest.py --log ~/.zen/log/20h12_AAAAMMJJ.log [--html out.html] [--json] [--hours 24]

Une seule question : « qu'est-ce que je dois regarder aujourd'hui ? ». Le message commence par un verdict (🟢 RAS /
🟠 à surveiller / 🔴 à traiter), puis la liste PRIORISÉE de ce qui demande une action (avec la commande ou l'écran
pour la traiter), puis des chiffres courts : station, BRO, ARBOR, nouveaux membres et boucle virale. Le journal
complet n'est plus le message : il est joint (compressé).

Sources (toutes locales, lecture seule) :
  - le journal 20h12 (erreurs regroupées et comptées, pas 800 lignes)
  - ~/.zen/tmp/<NODE>/observability/node-activity.jsonl  (échecs par script/catégorie)
  - ~/.zen/flashmem/*/observability/activity.jsonl        (BRO : actions et échecs par outil et par compte)
  - ~/.zen/flashmem/arbor_audit.jsonl + branches git arbor/* (ARBOR)
  - systemd, disque, mémoire, charge ; UPassport/services/facecloud_funnel (invitations, K)

Un collecteur qui plante n'est JAMAIS passé sous silence : il apparaît dans le message (« collecteur X en échec »).
"""
import argparse
import html as _html
import json
import os
import re
import shutil
import subprocess
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

HOME = Path.home()
ZEN = HOME / ".zen"
LEVELS = {"crit": 0, "warn": 1, "info": 2}
UNITS = ("astroport", "upassport", "ipfs", "strfry")

# seuils : un échec isolé n'est pas une alerte, une récurrence l'est
BRO_MIN_FAILS, BRO_MIN_RATE = 10, 30        # échecs sur la fenêtre et % d'échec d'un outil BRO
NODE_MIN_FAILS, NODE_MIN_RATE = 10, 50
DISK_WARN, DISK_CRIT = 80, 90


class Digest:
    def __init__(self, hours: int):
        self.hours = hours
        self.items = []             # (niveau, titre, détail, action)
        self.facts = defaultdict(list)   # section -> [(libellé, valeur)]

    def item(self, level, title, detail="", action=""):
        self.items.append((level, title, detail, action))

    def fact(self, section, label, value):
        self.facts[section].append((label, str(value)))

    def collect(self, name, fn, *a):
        try:
            fn(*a)
        except Exception as exc:             # noqa: BLE001 — jamais de panne silencieuse
            self.item("warn", f"Collecteur « {name} » en échec", f"{type(exc).__name__}: {exc}",
                      "tools/captain_digest.py — le reste du briefing est valable")


# ── journal 20h12 ─────────────────────────────────────────────────────────────
_ERR = re.compile(r"(\[ERROR\]|\bERROR\b|❌|\bFAILED\b|échec|Traceback)", re.I)
_WARN = re.compile(r"(\[WARN(ING)?\]|⚠️)", re.I)
_NOISE = re.compile(r"(0 failed|failed: 0|\| 0 failed|decrypt_fail=0|erreurs?\s*:\s*0|sans erreur|aucune erreur)", re.I)
_SECTION_ERR = re.compile(r"^===\s")


def normalize(line: str) -> str:
    """Même erreur, mêmes mots : horodatages, identifiants, nombres et clés disparaissent pour le regroupement."""
    s = re.sub(r"\[?\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}[^\]\s]*\]?", "", line)
    s = re.sub(r"\[\d{2}:\d{2}:\d{2}(\.\d+)?\]", "", s)
    s = re.sub(r"\[\d{3,}\]", "", s)
    s = re.sub(r"\b[0-9a-f]{12,}\b|\bg1[A-Za-z0-9]{40,}\b|\bk51[a-z0-9]{40,}\b|\b12D3Koo\w+", "<id>", s)
    s = re.sub(r"[\w.+-]+@[\w-]+\.[\w.-]+", "<email>", s)
    s = re.sub(r"\d+", "N", s)
    return re.sub(r"\s+", " ", s).strip(" -[]:")


def read_log(path: Path):
    if not path.is_file():
        raise FileNotFoundError(f"journal introuvable : {path}")
    opener = (lambda p: __import__("gzip").open(p, "rt", encoding="utf-8", errors="replace")) if path.suffix == ".gz" \
        else (lambda p: open(p, encoding="utf-8", errors="replace"))
    with opener(path) as f:
        return f.read().splitlines()


_LEAD_COUNT = re.compile(r"^\s*(\d+)x\s+")
_RETRY = re.compile(r"(retrying|attempt \d+/\d+\)|nouvelle tentative)", re.I)
_STAMP = re.compile(r"\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})\]")
_LEVEL = re.compile(r"^\s*(\[(ERROR|WARN(ING)?|INFO)\]|ERROR:?)\s*", re.I)


def clean(line: str) -> str:
    """La ligne sans horodatage ni niveau : ce que le Capitaine doit lire."""
    s = _STAMP.sub("", line)
    s = _LEAD_COUNT.sub("", s.strip())
    s = _LEVEL.sub("", s.strip())
    return re.sub(r"\s+", " ", s).strip(" -[]:")


def collect_log(d: Digest, path: Path):
    lines = read_log(path)
    errors, example = Counter(), {}
    retries = 0
    stamps = []
    for ln in lines:
        m = _STAMP.search(ln)
        if m:
            stamps.append(m.group(1))
        if _SECTION_ERR.match(ln) or _NOISE.search(ln):
            continue
        is_err = bool(_ERR.search(ln)) and not re.search(r"\[WARN", ln, re.I)       # « [WARN] ❌ … » reste un avertissement
        if not is_err and not _WARN.search(ln) and not _ERR.search(ln):
            continue
        if _RETRY.search(ln):          # une nouvelle tentative qui réussit n'est pas un problème : seul l'abandon l'est
            retries += int(_LEAD_COUNT.match(ln).group(1)) if _LEAD_COUNT.match(ln) else 1
            continue
        key = normalize(ln)
        if not key or len(key) < 6:
            continue
        n = int(_LEAD_COUNT.match(ln).group(1)) if _LEAD_COUNT.match(ln) else 1     # le journal agrège déjà (« 938x … »)
        errors[(key, "E" if is_err else "W")] += n
        example.setdefault((key, "E" if is_err else "W"), clean(ln)[:140])
    if len(stamps) > 1:
        t = sorted(time.mktime(time.strptime(x, "%Y-%m-%d %H:%M:%S")) for x in stamps)
        span = int((t[-1] - t[0]) // 60)
        if span:
            d.fact("Station", "Durée du traitement 20h12", f"{span} min")
    hard = sum(n for (k, lv), n in errors.items() if lv == "E")
    d.fact("Station", "Journal 20h12", f"{len(lines)} lignes · {hard} erreurs · {sum(n for (k, lv), n in errors.items() if lv == 'W')} avertissements · {retries} nouvelles tentatives")
    for (key, lvl), n in errors.most_common(6):
        if lvl == "W" and n < 50:
            continue                        # un avertissement isolé n'est pas un point d'attention
        d.item("crit" if (lvl == "E" and n >= 20) else "warn", f"{n}× {example[(key, lvl)]}",
               "Erreur répétée dans le journal 20h12" if lvl == "E" else "Avertissement très fréquent dans le journal 20h12",
               "zgrep -F '" + re.sub(r"[^\w .:/-]", "", example[(key, lvl)])[:40] + "' ~/.zen/log/20h12_*.log*")


# ── échecs par script (NODE) ───────────────────────────────────────────────────
def _since(hours):
    return time.strftime("%Y-%m-%dT%H:%M:%S%z", time.localtime(time.time() - hours * 3600))


def collect_node(d: Digest):
    files = list((ZEN / "tmp").glob("*/observability/node-activity.jsonl"))
    if not files:
        d.fact("Station", "Activité NODE", "pas encore de journal structuré")
        return
    cutoff = _since(d.hours)
    stats = defaultdict(lambda: [0, 0])
    for line in files[0].read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("timestamp", "") < cutoff:
            continue
        s = stats[(e.get("script", "?"), e.get("category", ""))]
        s[0] += 1
        s[1] += 0 if e.get("success") else 1
    for (script, cat), (total, fails) in sorted(stats.items(), key=lambda kv: -kv[1][1]):
        rate = 100 * fails / total if total else 0
        if fails >= NODE_MIN_FAILS and rate >= NODE_MIN_RATE:
            d.item("warn", f"{script}/{cat or '-'} : {fails} échecs sur {total} ({rate:.0f} %)",
                   f"sur {d.hours} h, journal d'activité NODE", f"jq 'select(.script==\"{script}\" and .success==false)' {files[0]}")
    d.fact("Station", "Événements NODE", f"{sum(v[0] for v in stats.values())} dont {sum(v[1] for v in stats.values())} échecs")


# ── BRO ───────────────────────────────────────────────────────────────────────
def collect_bro(d: Digest):
    cutoff = _since(d.hours)
    per_tool = defaultdict(lambda: [0, 0])
    bad_accounts = defaultdict(Counter)
    accounts = set()
    for f in (ZEN / "flashmem").glob("*/observability/activity.jsonl"):
        acct = f.parent.parent.name
        if re.search(r"@(example\.(com|org|net|invalid)|.*\.invalid|.*\.test)$", acct):
            continue                      # comptes de test : jamais des membres
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("timestamp", "") < cutoff:
                continue
            accounts.add(acct)
            t = per_tool[e.get("tool", "?")]
            t[0] += 1
            if not e.get("success"):
                t[1] += 1
                bad_accounts[e.get("tool", "?")][acct] += 1
    total = sum(v[0] for v in per_tool.values())
    fails = sum(v[1] for v in per_tool.values())
    d.fact("BRO", "Comptes actifs", len(accounts))
    d.fact("BRO", "Actions", f"{total} dont {fails} échecs")
    for tool, (n, bad) in sorted(per_tool.items(), key=lambda kv: -kv[1][1]):
        rate = 100 * bad / n if n else 0
        if bad >= BRO_MIN_FAILS and rate >= BRO_MIN_RATE:
            who = ", ".join(f"{a} ({c})" for a, c in bad_accounts[tool].most_common(3))
            d.item("warn", f"BRO · {tool} : {bad} échecs sur {n} ({rate:.0f} %)", f"Comptes les plus touchés : {who}",
                   f"jq 'select(.tool==\"{tool}\" and .success==false)' ~/.zen/flashmem/<compte>/observability/activity.jsonl")
    pid = subprocess.run(["pgrep", "-f", "bro_dm_daemon.sh"], capture_output=True, text=True).stdout.split()
    d.fact("BRO", "Démon DM", f"actif (PID {pid[0]})" if pid else "ARRÊTÉ")
    if not pid:
        d.item("crit", "Le démon BRO (messages privés) ne tourne pas", "Aucune réponse BRO tant qu'il est arrêté.",
               "~/.zen/Astroport.ONE/IA/bro/bro_dm_daemon.sh")


# ── ARBOR ─────────────────────────────────────────────────────────────────────
def collect_arbor(d: Digest):
    audit = ZEN / "flashmem" / "arbor_audit.jsonl"
    runs = []
    if audit.is_file():
        for line in audit.read_text(encoding="utf-8", errors="replace").splitlines()[-200:]:
            try:
                e = json.loads(line)
            except ValueError:
                continue
            if e.get("event") != "tunnel":
                runs.append(e)
    week = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - 7 * 86400))
    recent = [r for r in runs if str(r.get("at", "")) >= week]
    failed = [r for r in recent if r.get("rc") not in (0, None)]
    d.fact("ARBOR", "Runs sur 7 jours", f"{len(recent)} dont {len(failed)} en échec")
    if failed:
        last = failed[-1]
        d.item("warn", f"ARBOR : {len(failed)} run(s) en échec cette semaine", f"Dernier : {last.get('mode') or last.get('event')} (code {last.get('rc')}) le {last.get('at')}",
               "console du Capitaine → ARBOR (journal du dernier run)")
    repo = ZEN / "Astroport.ONE"
    if (repo / ".git").exists() or (repo / ".git").is_file():
        out = subprocess.run(["git", "for-each-ref", "--format=%(refname:short)", "refs/heads/arbor/"], cwd=repo,
                             capture_output=True, text=True, timeout=15).stdout.split()
        pending = []
        for b in out:
            merged = subprocess.run(["git", "merge-base", "--is-ancestor", b, "master"], cwd=repo, timeout=15).returncode == 0
            if not merged:
                pending.append(b)
        d.fact("ARBOR", "Branches à relire", len(pending))
        if pending:
            d.item("info", f"ARBOR a proposé {len(pending)} branche(s) à relire", ", ".join(pending[:4]),
                   f"cd {repo} && git diff master...{pending[0]}")
    base = ZEN / "tmp" / "arbor_baton_eligibility.json"
    if base.is_file():
        try:
            el = json.loads(base.read_text())
            d.fact("ARBOR", "Éligibilité au bâton", "oui" if el.get("eligible") else f"NON ({el.get('reason')})")
        except ValueError:
            pass


# ── IA / GPU partagé ──────────────────────────────────────────────────────────
def collect_ia(d: Digest):
    stats = ZEN / "Astroport.ONE" / "IA" / "ollama_stats.py"
    if not stats.is_file():
        raise FileNotFoundError(f"{stats} introuvable")
    r = subprocess.run([sys.executable, str(stats), "--days", "1", "--json"], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip()[-200:] or f"code {r.returncode}")
    j = json.loads(r.stdout)
    d.fact("IA / GPU", "Appels Ollama (24 h)", f"{j.get('calls', 0)} dont {j.get('errors', 0)} erreurs")
    for model, m in sorted((j.get("models") or {}).items(), key=lambda kv: -kv[1]["calls"])[:4]:
        d.fact("IA / GPU", model, f"{m['calls']} appels · médiane {m['p50_ms']} ms · p95 {m['p95_ms']} ms"
               + (f" · {m['tok_s_median']:.0f} jet/s" if m.get("tok_s_median") else ""))
        if m["calls"] >= 20 and m["cold_pct"] >= 20:
            d.item("warn", f"{model} : {m['cold_pct']:.0f} % de démarrages à froid", f"≈ {m['cold_load_ms_median'] / 1000:.1f} s perdues à chaque rechargement du modèle",
                   "mémoire VRAM disputée avec ComfyUI ? python3 ~/.zen/Astroport.ONE/IA/gpu_headroom.py status")
        if m["errors"]:
            d.item("warn", f"{model} : {m['errors']} appel(s) en erreur sur {m['calls']}", "", "python3 ~/.zen/Astroport.ONE/IA/ollama_stats.py --days 1")
    top = sorted((j.get("sources") or {}).items(), key=lambda kv: -kv[1])[:3]
    if top:
        d.fact("IA / GPU", "Qui consomme", ", ".join(f"{k} ({v})" for k, v in top))


# ── station ───────────────────────────────────────────────────────────────────
def collect_station(d: Digest):
    for u in UNITS:
        r = subprocess.run(["systemctl", "is-active", u], capture_output=True, text=True).stdout.strip()
        if r == "unknown" or r == "":
            continue
        d.fact("Station", f"Service {u}", r)
        if r != "active":
            d.item("crit", f"Le service {u} est « {r} »", "", f"sudo systemctl restart {u} && journalctl -u {u} -n 50")
    usage = shutil.disk_usage(HOME)
    pct = 100 * usage.used / usage.total
    d.fact("Station", "Disque", f"{pct:.0f} % ({usage.free // 2**30} Go libres)")
    if pct >= DISK_CRIT:
        d.item("crit", f"Disque plein à {pct:.0f} %", f"{usage.free // 2**30} Go libres", "ipfs repo gc ; du -sh ~/.zen/* | sort -h | tail")
    elif pct >= DISK_WARN:
        d.item("warn", f"Disque à {pct:.0f} %", f"{usage.free // 2**30} Go libres", "du -sh ~/.zen/* | sort -h | tail")
    load1 = os.getloadavg()[0]
    cores = os.cpu_count() or 1
    d.fact("Station", "Charge", f"{load1:.1f} sur {cores} cœurs")
    if load1 > 2 * cores:
        d.item("warn", f"Charge élevée : {load1:.1f} sur {cores} cœurs", "", "top -o %CPU")
    mem = {}
    for ln in Path("/proc/meminfo").read_text().splitlines():
        k, _, v = ln.partition(":")
        mem[k] = int(v.split()[0])
    avail = 100 * mem.get("MemAvailable", 0) / max(1, mem.get("MemTotal", 1))
    d.fact("Station", "Mémoire disponible", f"{avail:.0f} %")
    if avail < 10:
        d.item("warn", f"Mémoire disponible à {avail:.0f} %", "", "ps aux --sort=-%mem | head")


# ── membres et boucle virale ──────────────────────────────────────────────────
def collect_members(d: Digest):
    cutoff = time.time() - d.hours * 3600
    root = ZEN / "game" / "nostr"
    new = [p.parent.name for p in root.glob("*@*/HEX") if p.stat().st_mtime >= cutoff]
    total = len([p for p in root.glob("*@*/HEX")])
    d.fact("Membres", "MULTIPASS sur la station", total)
    d.fact("Membres", f"Nouveaux ({d.hours} h)", ", ".join(new) if new else "aucun")
    up = ZEN / "UPassport"
    sys.path.insert(0, str(up))
    from services import facecloud_funnel          # noqa: E402
    s = facecloud_funnel.stats(7)
    c = s["counts"]
    d.fact("Membres", "Invitations FaceCloud (7 j)", f"{c['created']} créées · {c['visit']} ouvertes · {c['claimed']} comptes créés")
    k = s["viral"]["k"]
    d.fact("Membres", "K viral mesuré", "pas encore de données" if k is None else f"{k}")
    if c["created"] >= 5 and c["visit"] == 0:
        d.item("warn", "Des invitations FaceCloud sont créées mais personne ne les ouvre",
               f"{c['created']} créées, 0 visite en 7 jours : lien /i/ inaccessible ?", "curl -I $uSPOT/i/test")


# ── rendu ─────────────────────────────────────────────────────────────────────
def verdict(items):
    crit = sum(1 for i in items if i[0] == "crit")
    warn = sum(1 for i in items if i[0] == "warn")
    if crit:
        return "🔴", f"{crit} point{'s' if crit > 1 else ''} à traiter" + (f", {warn} à surveiller" if warn else "")
    if warn:
        return "🟠", f"{warn} point{'s' if warn > 1 else ''} à surveiller"
    return "🟢", "RAS — tout est en ordre"


def subject(items, station):
    icon, text = verdict(items)
    top = [i[1] for i in sorted(items, key=lambda i: LEVELS[i[0]]) if i[0] != "info"][:2]
    return f"20H12 {station} — {icon} {text}" + (" : " + " · ".join(t[:60] for t in top) if top else "")


def render(d: Digest, station: str, log_name: str) -> str:
    e = _html.escape
    icon, text = verdict(d.items)
    colors = {"crit": "#c23a32", "warn": "#b86a0e", "info": "#5a6a73"}
    todo = ""
    for lvl, title, detail, action in sorted(d.items, key=lambda i: LEVELS[i[0]]):
        todo += (f'<div style="border-left:4px solid {colors[lvl]};padding:6px 12px;margin:0 0 10px;background:#fafafa">'
                 f'<b>{e(title)}</b>' + (f'<div style="color:#5a6a73;font-size:14px">{e(detail)}</div>' if detail else "")
                 + (f'<div style="font:12px monospace;color:#1f5fd1;margin-top:4px">{e(action)}</div>' if action else "") + '</div>')
    if not todo:
        todo = '<p style="color:#2b8a57">Rien à traiter aujourd\'hui.</p>'
    sections = ""
    for name in ("Station", "IA / GPU", "BRO", "ARBOR", "Membres"):
        if d.facts.get(name):
            rows = "".join(f'<tr><td style="color:#5a6a73;padding:2px 12px 2px 0">{e(k)}</td><td>{e(v)}</td></tr>' for k, v in d.facts[name])
            sections += f'<h3 style="font-size:15px;margin:18px 0 4px">{e(name)}</h3><table style="font-size:14px;border-collapse:collapse">{rows}</table>'
    return (
        '<div style="background:#f6f3ec;padding:16px 10px"><div style="max-width:620px;margin:0 auto;background:#fff;border-radius:12px;'
        'padding:22px;font:16px/1.45 system-ui,-apple-system,Segoe UI,sans-serif;color:#1d2a32">'
        f'<h2 style="margin:0 0 4px;font-size:22px">{icon} {e(text)}</h2>'
        f'<p style="margin:0 0 16px;color:#5a6a73;font-size:14px">{e(station)} · {time.strftime("%d/%m/%Y %H:%M")} · fenêtre {d.hours} h</p>'
        f'<h3 style="font-size:15px;margin:0 0 8px">À regarder</h3>{todo}{sections}'
        f'<p style="margin:20px 0 0;color:#8a949a;font-size:12px">Journal complet en pièce jointe ({e(log_name)}.gz).</p>'
        '</div></div>')


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--log", required=True)
    ap.add_argument("--html")
    ap.add_argument("--hours", type=int, default=24)
    ap.add_argument("--json", action="store_true", help="écrit le résumé JSON sur stdout")
    ap.add_argument("--subject", action="store_true", help="écrit seulement le sujet du message sur stdout")
    args = ap.parse_args()
    d = Digest(args.hours)
    station = os.uname().nodename
    d.collect("station", lambda: collect_station(d))
    d.collect("journal 20h12", lambda: collect_log(d, Path(args.log)))
    d.collect("activité NODE", lambda: collect_node(d))
    d.collect("BRO", lambda: collect_bro(d))
    d.collect("ARBOR", lambda: collect_arbor(d))
    d.collect("IA / GPU", lambda: collect_ia(d))
    d.collect("membres", lambda: collect_members(d))
    if args.html:
        Path(args.html).write_text(render(d, station, Path(args.log).name), encoding="utf-8")
    if args.subject:
        print(subject(d.items, station))
    elif args.json:
        print(json.dumps({"verdict": verdict(d.items), "items": d.items, "facts": d.facts}, ensure_ascii=False, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
