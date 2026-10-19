#!/usr/bin/env python3
"""
memory_sources.py — sources de la mémoire de BRO qui ne sont pas des échanges directs.

  AUTOMATIQUE (lancé chaque jour par NOSTRCARD.refresh.sh, ou « Apprendre maintenant » dans Mon compte),
  seulement si la personne a coché la source (NOSTR kind 31903 d=memory_sources) :
    nostr_public  — VOS notes (kind 1) et articles de blog (kind 30023), déjà publics, lus sur le relais
                    local. Ignore les posts automatiques de la station, les réponses à autrui et les posts
                    trop courts. Reprend là où il s'était arrêté (filigrane created_at).

    agenda        — vos rendez-vous des 30 derniers jours et des 120 prochains (UPassport/services/calendar_store.py :
                    titre, date/heure, lieu, début de la description). Texte construit SANS modèle (un événement est
                    déjà structuré : un LLM n'y ajouterait que des erreurs). Un événement modifié REMPLACE son ancien
                    souvenir, un événement supprimé retire le sien.
    contact       — nom, organisation, anniversaire (jour et mois) et note de vos contacts (contacts_store.py). JAMAIS
                    les téléphones, e-mails, adresses ni clés NOSTR : ce sont des coordonnées, pas de la mémoire.

  PAR UN GESTE, jamais automatique :
    photo         — les photos que la personne CHOISIT, une à une, dans FaceCloud (ucloud.html : bouton
                    « 🧠 Mémoriser pour BRO » dans la visionneuse et dans la sélection). Les photos choisies sont
                    regroupées par moment (6 h) : un souvenir par moment, jamais 20 pour un même dîner. Jamais
                    les images : date, lieu approximatif, personnes reconnues, descriptions.
                    memory_sources.py remember-photos EMAIL < ["/Photos/2025/07/a.jpg", …]

Déjà pilotées par évènement, ailleurs : « chat » (réponses de BRO, tous canaux), « love_dm » (messages au
canal LOVE, bro_dm_daemon.sh) et « mastodon » (scraper quotidien / bouton Régénérer).

  memory_sources.py {nostr_public|agenda|contact|all} EMAIL [--dry-run]
  memory_sources.py remember-photos EMAIL [--dry-run]      (chemins JSON sur stdin)
"""
import argparse   # AVANT memory_writer : le venv ~/.astro embarque un vieux argparse.py
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import memory_writer as mw
import memory_manager as mm

STRFRY_DIR = os.path.expanduser("~/.zen/strfry")
NOSTR_MAX_PER_RUN = 40
NOSTR_MIN_CHARS = 60
PHOTO_MAX_DESCS = 6


def _log(msg):
    print(f"[memory_sources] {msg}", file=sys.stderr)


def _state_path(email):
    return os.path.join(mw._state_dir(email), ".memory_sources_state.json")


def _load_state(email):
    try:
        with open(_state_path(email), encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except Exception as e:
        _log(f"⚠️ état illisible ({e}) — repart de zéro")
        return {}


def _save_state(email, st):
    path = _state_path(email)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f)
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def _hex(email):
    try:
        with open(os.path.expanduser(f"~/.zen/game/nostr/{email}/HEX"), encoding="utf-8") as f:
            return f.read().strip()
    except FileNotFoundError:
        raise RuntimeError(f"{email} : pas de HEX sur cette station")


# ── NOSTR public : kinds 1 et 30023 ─────────────────────────────────────────
def _tag(ev, name):
    return next((t[1] for t in ev.get("tags", []) if len(t) > 1 and t[0] == name), "")


# Posts publiés AVEC la clé du MULTIPASS mais écrits par la station (reconnaissance de plantes, descriptions
# d'images, partages de vidéos NostrTube, commandes #BRO…) : ce n'est pas la voix de la personne, en tirer des
# souvenirs serait faux. Constaté sur un vrai compte : 29 « publications » sur 94, quasi toutes automatiques.
_BOT_TAGS = {"aquoicasert", "identification", "plantnet", "botanique", "nature", "nostrtube", "video",
             "bro", "inventory", "inventaire", "ore", "umap", "journal"}
_BOT_HEADS = ("🎬", "🌿", "🔍", "📦", "👁", "🤖", "📊", "🌍")
_BOT_MARKERS = ("Ce que c'est", "Confiance PlantNet", "Identification réussie", "/theater?video=")


def _is_bot_post(ev, content):
    tags = {t[1].lower() for t in ev.get("tags", []) if len(t) > 1 and t[0] == "t"}
    if tags & _BOT_TAGS or any(t and t[0] == "imeta" for t in ev.get("tags", [])):
        return True
    return content.startswith(_BOT_HEADS) or any(m in content for m in _BOT_MARKERS)


def nostr_texts(events):
    """[(created_at, texte)] — notes racines assez longues et articles. Les réponses (tag e),
    les commandes (#BRO…) et les messages quasi vides sont écartés."""
    out = []
    for ev in events:
        content = (ev.get("content") or "").strip()
        if _is_bot_post(ev, content):
            continue
        if ev.get("kind") == 1:
            if any(t and t[0] == "e" for t in ev.get("tags", [])):
                continue                                   # réponse à quelqu'un : pas ses propres idées
            text = mw.clean_text(content)
            if len(text) < NOSTR_MIN_CHARS or text.startswith("nostr:"):
                continue
            out.append((ev["created_at"], text[:1500]))
        elif ev.get("kind") == 30023:
            title, summary = _tag(ev, "title"), _tag(ev, "summary")
            head = f"Article « {title} » : " if title else "Article : "
            body = summary + "\n" + content if summary else content
            out.append((ev["created_at"], (head + body)[:2500]))
    return out


def run_nostr_public(email, dry=False):
    h = _hex(email)
    st = _load_state(email)
    since = int(st.get("nostr_public", {}).get("since", 0))
    flt = {"kinds": [1, 30023], "authors": [h], "since": since + 1 if since else 0}
    if not os.path.isfile(os.path.join(STRFRY_DIR, "strfry")):
        raise RuntimeError(f"strfry introuvable dans {STRFRY_DIR}")
    r = subprocess.run(["./strfry", "scan", json.dumps(flt)], cwd=STRFRY_DIR,
                       capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        raise RuntimeError(f"strfry scan : {r.stderr.strip()[-200:]}")
    events = []
    for line in r.stdout.splitlines():
        try:
            events.append(json.loads(line))
        except ValueError:
            continue
    texts = sorted(nostr_texts(events))[-NOSTR_MAX_PER_RUN:]          # les plus récents
    newest = max([e["created_at"] for e in events] + [since])
    _log(f"nostr_public : {len(events)} évènement(s) lu(s), {len(texts)} retenu(s)")
    if dry:
        for ts, t in texts:
            print(f"  [{datetime.fromtimestamp(ts, timezone.utc):%Y-%m-%d}] {t[:110].replace(chr(10), ' ')}")
        return len(texts)
    n = mw.ingest(email, [t for _ts, t in texts], source="nostr_public") if texts else 0
    st["nostr_public"] = {"since": newest, "last_run": int(time.time()), "queued": n}
    _save_state(email, st)
    return n


# ── Photos : un souvenir par événement ──────────────────────────────────────
def _ucloud_db():
    sys.path.insert(0, os.path.expanduser("~/.zen/UPassport/services"))
    import ucloud_db
    return ucloud_db


def _named_faces(h):
    """{chemin de photo: [noms]} depuis la collection Qdrant faces_<hex> (visages NOMMÉS seulement)."""
    cname = f"faces_{h}"
    out, offset = {}, None
    while True:
        body = {"limit": 500, "with_payload": ["name", "source_path"], "with_vector": False}
        if offset:
            body["offset"] = offset
        res = mm._curl("POST", f"{mm.QDRANT_URL}/collections/{cname}/points/scroll", body).get("result", {})
        for p in res.get("points", []):
            pl = p.get("payload", {})
            name, path = (pl.get("name") or "").strip(), pl.get("source_path")
            if path and name and not name.lower().startswith("inconnu"):
                out.setdefault(path, set()).add(name)
        offset = res.get("next_page_offset")
        if not offset:
            return out


def _day(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime("%Y-%m-%d")


def selection_texts(db, conn, paths, faces, gap=6 * 3600):
    """Textes de souvenir pour les photos CHOISIES : regroupées par moment (≤ `gap` entre deux prises),
    un texte par moment, construit UNIQUEMENT à partir des photos choisies (leurs descriptions, les personnes
    reconnues sur elles). Date = prise de vue (EXIF) ; à défaut date du fichier, et on le dit."""
    if not paths:
        return []
    marks = ",".join("?" * len(paths))
    rows = conn.execute(
        f"SELECT path, COALESCE(taken_at, mtime), taken_at, lat, lon, json_extract(data,'$.desc.text') "
        f"FROM entries WHERE {db._IMG} AND path IN ({marks}) ORDER BY COALESCE(taken_at, mtime)", list(paths)).fetchall()
    groups = []
    for r in rows:
        if r[1] is None:
            continue
        if groups and r[1] - groups[-1][-1][1] <= gap:
            groups[-1].append(r)
        else:
            groups.append([r])
    out = []
    for g in groups:
        d0, d1 = _day(g[0][1]), _day(g[-1][1])
        when = f"le {d0}" if d0 == d1 else f"du {d0} au {d1}"
        exif = all(r[2] for r in g)
        places = {}
        for r in g:
            if r[3] is not None:
                places[(r[3], r[4])] = places.get((r[3], r[4]), 0) + 1
        best = max(places, key=places.get) if places else None
        people = sorted({n for r in g for n in faces.get(r[0], ())
                         if n.lower() not in ("anonymous", "anonyme")})
        descs = [r[5].strip()[:170] for r in g if r[5] and r[5].strip()]
        n = len(g)
        parts = [f"Moment choisi {when} : {n} photo{'s' if n > 1 else ''}"
                 + (f", autour de {best[0]:.2f}°N {best[1]:.2f}°E" if best else "")
                 + ("" if exif else " (date du fichier, pas de prise de vue)") + "."]
        if people:
            parts.append("Personnes reconnues : " + ", ".join(people) + ".")
        if descs:
            step = max(1, len(descs) // PHOTO_MAX_DESCS)
            parts.append("Scènes : " + " ; ".join(descs[::step][:PHOTO_MAX_DESCS]))
        if people or descs:                  # rien à en dire (photo ni décrite ni reconnue) : pas de souvenir vide
            out.append(" ".join(parts))
    return out


def remember_photos(email, paths, dry=False):
    """Geste explicite de la personne : met en mémoire les photos choisies (force = pas de case à cocher)."""
    from pathlib import Path
    db = _ucloud_db()
    udir = Path(os.path.expanduser(f"~/.zen/game/nostr/{email}/.ucloud"))
    if not db.exists(udir):
        raise RuntimeError("pas de cloud pour ce compte")
    paths = [p for p in dict.fromkeys(paths) if isinstance(p, str)][:200]
    faces = {}
    try:
        faces = _named_faces(_hex(email))
    except Exception as e:
        _log(f"⚠️ visages nommés indisponibles ({e}) — souvenirs sans les personnes")
    texts = selection_texts(db, db.connect(udir), paths, faces)
    result = {"photos": len(paths), "moments": len(texts), "queued": 0}
    if dry:
        for t in texts:
            print("  " + t[:260])
        return result
    if texts:
        result["queued"] = mw.ingest(email, texts, source="photo", force=True)
    return result


# ── Sources externes structurées (agenda, contacts) : texte déterministe + synchronisation ──────────────────
AGENDA_PAST_DAYS = 30
AGENDA_FUTURE_DAYS = 120
AGENDA_MAX = 80
MASS_REMOVAL_GUARD = 0.5       # une synchro ne retire jamais plus de la moitié d'une source (au-delà de 10 éléments)
_MOIS = ("janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre",
         "novembre", "décembre")


def _services():
    """UPassport/services (calendar_store, contacts_store) — importés depuis le dépôt de la station."""
    for root in (os.path.expanduser("~/.zen/UPassport"), os.path.expanduser("~/workspace/AAA/UPassport")):
        if os.path.isdir(os.path.join(root, "services")):
            if root not in sys.path:
                sys.path.insert(0, root)
            from services import calendar_store, contacts_store
            return calendar_store, contacts_store
    raise RuntimeError("UPassport/services introuvable")


def agenda_text(it):
    """Texte d'un événement d'agenda (résumé calendar_store) → (clé externe, texte) ou None si hors fenêtre."""
    start = (it.get("start") or "")[:16]
    if not start[:10].count("-") == 2:
        return None
    day = start[:10]
    when = f"{day} {start[11:16]}" if "T" in start and not it.get("all_day") else f"{day} (journée entière)"
    summary = (it.get("summary") or "").strip()
    if not summary:
        return None
    parts = [f"Agenda {when} : {summary}"]
    if (it.get("location") or "").strip():
        parts.append(f"lieu : {it['location'].strip()[:120]}")
    desc = " ".join((it.get("description") or "").split())
    if desc:
        parts.append(desc[:200])
    if it.get("rrule"):
        parts.append("(événement récurrent)")
    return " — ".join(parts)


def _within_window(it, now):
    from datetime import timedelta
    try:
        d = datetime.strptime((it.get("start") or "")[:10], "%Y-%m-%d").replace(tzinfo=timezone.utc)
    except ValueError:
        return False
    if it.get("rrule"):
        return True                              # un rendez-vous récurrent reste d'actualité
    return now - timedelta(days=AGENDA_PAST_DAYS) <= d <= now + timedelta(days=AGENDA_FUTURE_DAYS)


def _birthday(raw):
    """« 1985-03-12 », « --03-12 », « 19850312 » → « 12 mars » (jour et mois seulement : l'année donne l'âge)."""
    import re as _re
    m = _re.search(r"(\d{2})-?(\d{2})$", (raw or "").strip())      # …MM-JJ, …MMJJ (l'année éventuelle précède)
    if not m:
        return ""
    mo, d = int(m.group(1)), int(m.group(2))
    return f"{d} {_MOIS[mo - 1]}" if 1 <= mo <= 12 and 1 <= d <= 31 else ""


def contact_text(c):
    """Texte d'une fiche contact (résumé contacts_store) — nom, organisation, anniversaire, note. Jamais de coordonnées."""
    name = (c.get("fn") or "").strip()
    if not name:
        return None
    parts = [f"Contact : {name}"]
    if (c.get("org") or "").strip():
        parts.append(f"organisation : {c['org'].strip()[:80]}")
    bd = _birthday(c.get("bday"))
    if bd:
        parts.append(f"anniversaire le {bd}")
    note = " ".join((c.get("note") or "").split())
    if note:
        parts.append(f"note : {note[:160]}")
    if len(parts) == 1:
        return None       # un nom SEUL n'est pas un souvenir (constaté : 1 543 fiches sur 2 456 n'ont rien d'autre) :
                          # il noierait la mémoire de BRO ; la fiche reste dans le carnet de FaceCloud
    return " — ".join(parts)


def sync_external(email, source, wanted, kind, dry=False):
    """Aligne les souvenirs `source` sur `wanted` ({clé externe: texte}) : ajoute le nouveau, REMPLACE ce qui a
    changé (l'ancien passe en `superseded`), retire ce qui a disparu de la source. → (ajoutés, remplacés, retirés)."""
    existing = {}
    for pt in mm.list_memories(email, source=source, limit=100000):
        pl = pt.get("payload", {})
        existing.setdefault(pl.get("ext_key"), []).append((pt["id"], pl))
    wanted_hash = {k: mm._content_hash(t) for k, t in wanted.items()}
    to_retire, to_write, replaced = [], [], 0
    for key, olds in existing.items():
        if key not in wanted:
            to_retire += [pid for pid, _ in olds]
        else:
            same = any(pl.get("content_hash") == wanted_hash[key] for _, pl in olds)
            if not same:
                to_retire += [pid for pid, _ in olds]
                replaced += 1
    for key, text in wanted.items():
        olds = existing.get(key, [])
        if not any(pl.get("content_hash") == wanted_hash[key] for _, pl in olds):
            to_write.append((key, text))
    vanished = [k for k in existing if k not in wanted]
    if len(existing) > 10 and len(vanished) > MASS_REMOVAL_GUARD * len(existing):
        _log(f"⚠️ {source} : {len(vanished)} élément(s) sur {len(existing)} auraient disparu d'un coup — "
             f"suppression REFUSÉE (disque monté absent ? magasin illisible ?). Rien n'est retiré.")
        to_retire = [pid for k, olds in existing.items() if k in wanted for pid, pl in olds
                     if pl.get("content_hash") != wanted_hash[k]]
    added = len(to_write) - replaced
    if dry:
        for k, t in to_write[:30]:
            print("  + " + t[:200])
        return added, replaced, len(set(to_retire)) - replaced
    if to_retire:
        mm.set_memory_fields(email, list(set(to_retire)), {"status": "superseded"})
    for key, text in to_write:
        if not mm.upsert_memory(email, text, kind=kind, source=source, visibility="private",
                                confidence=0.9, extra={"ext_key": key}):
            _log(f"⚠️ souvenir non écrit ({source}) : {text[:80]}")
    return added, replaced, max(0, len(set(to_retire)) - replaced)


def run_agenda(email, dry=False):
    cs, _ = _services()
    now = datetime.now(timezone.utc)
    data = cs.load(email)
    wanted = {}
    cands = [it for it in data.get("items", {}).values() if it.get("kind") == "VEVENT" and _within_window(it, now)]
    cands.sort(key=lambda it: abs((datetime.strptime(it["start"][:10], "%Y-%m-%d").replace(tzinfo=timezone.utc) - now).days))
    for it in cands[:AGENDA_MAX]:
        text = agenda_text(it)
        if text:
            wanted[f"{it.get('cal', 'personal')}/{it.get('uid') or it.get('name')}"] = text
    a, r, d = sync_external(email, "agenda", wanted, "episode", dry=dry)
    _log(f"agenda : {len(wanted)} événement(s) dans la fenêtre → +{a} ~{r} −{d}")
    return {"events": len(wanted), "added": a, "replaced": r, "removed": d}


def run_contacts(email, dry=False):
    _, ct = _services()
    data = ct.load(email)
    wanted = {}
    for name, c in data.get("cards", {}).items():
        text = contact_text(c)
        if text:
            wanted[c.get("uid") or name] = text
    a, r, d = sync_external(email, "contact", wanted, "person", dry=dry)
    _log(f"contacts : {len(wanted)} fiche(s) → +{a} ~{r} −{d}")
    return {"contacts": len(wanted), "added": a, "replaced": r, "removed": d}


SOURCES = {"nostr_public": run_nostr_public, "agenda": run_agenda, "contact": run_contacts}   # automatiques (si cochées) ; les photos passent par remember_photos


def run_all(email, dry=False):
    """Toutes les sources passives COCHÉES ; un échec n'arrête pas les suivantes."""
    consent = mw.consent(email, fresh=True)
    report = {}
    for name, fn in SOURCES.items():
        if not consent.get(name):
            report[name] = "non cochée"
            continue
        try:
            report[name] = fn(email, dry=dry)
        except Exception as e:
            _log(f"❌ {name} : {e}")
            report[name] = f"erreur : {e}"
    return report


def main():
    p = argparse.ArgumentParser(description="Sources de la mémoire de BRO")
    p.add_argument("source", choices=[*SOURCES, "all", "remember-photos"])
    p.add_argument("email")
    p.add_argument("--dry-run", action="store_true", help="montre ce qui serait appris, sans rien mettre en file")
    a = p.parse_args()
    if a.source == "remember-photos":
        try:
            paths = json.loads(sys.stdin.read() or "[]")
        except ValueError:
            sys.exit("ERROR: les chemins doivent être un tableau JSON sur stdin")
        print(json.dumps(remember_photos(a.email, paths, dry=a.dry_run), ensure_ascii=False))
        return
    if a.source == "all":
        print(json.dumps(run_all(a.email, dry=a.dry_run), ensure_ascii=False))
        return
    if not mw.consent(a.email, fresh=True).get(a.source) and not a.dry_run:
        print(json.dumps({a.source: "non cochée"}, ensure_ascii=False))
        return
    print(json.dumps({a.source: SOURCES[a.source](a.email, dry=a.dry_run)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
