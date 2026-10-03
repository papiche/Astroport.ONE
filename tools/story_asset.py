#!/usr/bin/env python3
"""
story_asset.py — Personnages et scènes de vidéos IA partagés par événements NOSTR,
selon la méthode uCloud (UPassport/services/cloud_storage.py).

  paquet (tar.gz) → AES-256-GCM (uenc_codec) → ipfs add → CID
  événement public Kind 30510 : titre, type, résumé, CID, historique des versions, rendus.
  JAMAIS de clé dans l'événement.

Deux portées (« scope ») :
  private  clé AES aléatoire par version, gardée dans le keyring local (0600) et envoyée aux amis
           par message fichier NIP-17 (nostr_send_secure_dm.py --file-message).
  coop     clé COOPÉRATIVE = sha256("uplanet-story-assets:v1:" + $UPLANETNAME), la même sur toutes
           les stations de la coopérative (comme cooperative_config.sh) : tous les Capitaines
           lisent le paquet sans échange de clé. Tag ["t","coop"], propagé par la synchro
           constellation (NIP-101/backfill_constellation.sh, kind 30510). Chaque Capitaine ne modifie
           que ses propres paquets ; pour changer celui d'un autre : `fork` (copie à son nom).

Versions : chaque modification crée un NOUVEAU paquet (nouvelle clé en private, nouveau CID) publié
sous le même d-tag (événement remplaçable). L'événement garde `history` (CID, version, date) et les
anciens CID restent épinglés : on peut tous les rouvrir, les comparer, les restaurer.
Rendus : `renders` (vidéo finale par version, CID IPFS) est ajouté à l'événement pour les paquets coop.

Commandes (python3 story_asset.py CMD -h) :
  create character|scene NOM [--scope coop|private]    nouveau paquet de départ
  publish character NOM | scene NOM STORYBOARD.json    depuis des fichiers de $SCENES_DIR
  update REF --set CHEMIN=FICHIER --delete CHEMIN      nouvelle version
  versions REF · restore REF · fork REF [--name N]
  list [--coop] · get REF · share REF AMI · import CID --key HEX
  export REF -o FICHIER.tar.gz                         sauvegarde/transfert manuel (tar.gz EN CLAIR)
  importpkg FICHIER.tar.gz [--scope] [--name]           installe un paquet exporté dans la bibliothèque
  delete REF                                            retire un paquet (toute sa lignée) de la bibliothèque locale
  resolve-character NOM --dest DOSSIER                  pont CLI/Web : installe un personnage de la bibliothèque
  rebuild [--force]                                     reconstruit le trousseau depuis NOSTR (secours $SCENES_DIR supprimé)

Contenu d'un paquet : manifest.json + fichiers relatifs à $SCENES_DIR (~/.zen/workspace/scenes).
N'utiliser le visage ou la voix d'une personne réelle qu'avec son consentement.
Signataire : MULTIPASS du Capitaine. License: AGPL-3.0
"""
import os
import sys

_venv = os.path.expanduser("~/.astro/bin/python3")
if __name__ == "__main__" and os.path.exists(_venv) and sys.executable != _venv:
    os.execv(_venv, [_venv] + sys.argv)  # importé (UPassport), on ne remplace pas le process

import argparse
import contextlib
import fcntl
import hashlib
import io
import json
import pathlib
import re
import subprocess
import tarfile
import time

TOOLS = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(TOOLS))
from uenc_codec import decrypt_aes256gcm, encrypt_aes256gcm  # noqa: E402

KIND = 30510
SCENES = pathlib.Path(os.environ.get("SCENES_DIR", os.path.expanduser("~/.zen/workspace/scenes")))
# INDÉPENDANT de SCENES_DIR : un rendu du Studio web (services/story_render.py::_launch) surcharge
# SCENES_DIR pour isoler le bac à sable du paquet en cours (résolution des chemins $SCENES_DIR/...
# À L'INTÉRIEUR d'un storyboard), mais le trousseau (quels paquets sont « à moi », avec quelle clé)
# est une ressource globale de la station — jamais propre à un rendu. Sans ce découplage, tout appel
# à story_asset.py lancé en sous-processus d'un rendu (ex. generate_scene.sh → resolve-character)
# verrait une bibliothèque vide, le dossier isolé n'ayant pas de library/keyring.json.
LIBRARY = pathlib.Path(os.environ.get("STORY_LIBRARY_DIR", os.path.expanduser("~/.zen/workspace/scenes/library")))
KEYRING = LIBRARY / "keyring.json"
RENDERS = LIBRARY / "renders.json"
RELAY = os.environ.get("NOSTR_RELAY_WS", "ws://127.0.0.1:7777")
MAX_BYTES = 2 * 1024 ** 3
COOP_SALT = "uplanet-story-assets:v1:"
SCOPES = ("private", "coop")


class AssetError(Exception):
    """Erreur métier : en CLI message + exit 1, en import (UPassport) réponse 4xx."""


def die(msg):
    raise AssetError(msg)


# ═══ Identité du Capitaine et clé coopérative ═══════════════════════════════
_cache = {}


def _bash_env(var):
    """Variable d'environnement Astroport (my.sh) : CAPTAINEMAIL, UPLANETNAME."""
    if os.environ.get(var):
        return os.environ[var]
    if var not in _cache:
        _cache[var] = subprocess.run(["bash", "-c", f". {TOOLS}/my.sh >/dev/null 2>&1; echo \"${var}\""],
                                     capture_output=True, text=True).stdout.strip()
    return _cache[var]


def _captain_secret_file():
    email = _bash_env("CAPTAINEMAIL")
    f = pathlib.Path.home() / ".zen/game/nostr" / email / ".secret.nostr"
    if not email or not f.exists():
        die(f"MULTIPASS du Capitaine introuvable ({f})")
    return f.read_text()


def captain_secret():
    m = re.search(r"NSEC=([^;\s]+)", _captain_secret_file())
    if not m:
        die("NSEC absent de .secret.nostr")
    return m.group(1)


def captain_hex():
    m = re.search(r"HEX=([0-9a-f]{64})", _captain_secret_file())
    return m.group(1) if m else None


def coop_key():
    name = _bash_env("UPLANETNAME")
    if not name:
        die("UPLANETNAME introuvable : clé coopérative indisponible sur cette station")
    return hashlib.sha256((COOP_SALT + name).encode()).hexdigest()


def friend_hex(who):
    who = who.strip()
    if re.fullmatch(r"[0-9a-f]{64}", who):
        return who
    f = pathlib.Path.home() / ".zen/game/nostr" / who / ".secret.nostr"
    if f.exists():
        m = re.search(r"HEX=([0-9a-f]{64})", f.read_text())
        if m:
            return m.group(1)
    die(f"ami inconnu « {who} » : donner sa clé HEX (64 caractères) ou un EMAIL local")


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-") or "asset"


def rel_to_scenes(p):
    try:
        return pathlib.Path(p).resolve().relative_to(SCENES.resolve())
    except ValueError:
        return None


# ═══ Paquet tar.gz, keyring, rendus ═════════════════════════════════════════
def build_tar(manifest, files):
    """files : [(chemin_relatif_dans_le_paquet, chemin_réel | bytes)]"""
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode="w:gz") as tar:
        data = json.dumps(manifest, ensure_ascii=False, indent=1).encode()
        ti = tarfile.TarInfo("manifest.json")
        ti.size, ti.mtime = len(data), int(time.time())
        tar.addfile(ti, io.BytesIO(data))
        for arc, real in files:
            if isinstance(real, (bytes, bytearray)):
                ti = tarfile.TarInfo(str(arc))
                ti.size, ti.mtime = len(real), int(time.time())
                tar.addfile(ti, io.BytesIO(bytes(real)))
            else:
                tar.add(real, arcname=str(arc), recursive=False)
    return buf.getvalue()


@contextlib.contextmanager
def keyring_lock():
    LIBRARY.mkdir(parents=True, exist_ok=True)
    with open(LIBRARY / ".lock", "a") as lk:
        fcntl.flock(lk, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lk, fcntl.LOCK_UN)


def _load(path):
    return json.loads(path.read_text()) if path.exists() else {}


def _save(path, data):
    LIBRARY.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    tmp.write_text(json.dumps(data, indent=1, ensure_ascii=False))
    os.chmod(tmp, 0o600)
    tmp.replace(path)  # écriture atomique, comme index.json d'uCloud


def load_keyring():
    return _load(KEYRING)


def save_keyring(k):
    _save(KEYRING, k)


def ipfs_add(payload, name):
    p = subprocess.run(["ipfs", "add", "-q", "--stdin-name", name], input=payload, capture_output=True)
    if p.returncode or not p.stdout.strip():
        die("ipfs add a échoué : " + p.stderr.decode()[:200])
    return p.stdout.decode().strip().splitlines()[-1]


def ipfs_cat(cid):
    p = subprocess.run(["ipfs", "cat", cid], capture_output=True, timeout=600)
    if p.returncode:
        die("ipfs cat a échoué : " + p.stderr.decode()[:200])
    return p.stdout


def ipfs_pin(cid):
    subprocess.run(["ipfs", "pin", "add", "-q", cid], capture_output=True, timeout=120)


def publish_event(nsec, tags, content):
    p = subprocess.run([sys.executable, str(TOOLS / "nostr_node_intercom.py"), "publish", "--nsec-stdin",
                        "--kind", str(KIND), "--tags", json.dumps(tags), "--content", json.dumps(content, ensure_ascii=False),
                        "--relays", RELAY], input=nsec + "\n", text=True, capture_output=True)
    if p.returncode or not p.stdout.strip():
        die("publication Kind %d échouée : %s" % (KIND, p.stderr.strip()[:200]))
    return p.stdout.strip().splitlines()[-1]


def send_key(nsec, hexpub, entry):
    """Message fichier NIP-17 : CID + clé + IV + hash, dans deux couches de chiffrement."""
    p = subprocess.run([sys.executable, str(TOOLS / "nostr_send_secure_dm.py"), "--nsec-stdin", hexpub,
                        "--file-message", "--relay", RELAY, "--ipfs-url", f"/ipfs/{entry['cid']}",
                        "--file-type", "application/gzip", "--decryption-key", entry["key_hex"],
                        "--decryption-nonce", entry["iv_hex"], "--x-hash", entry["x_hash"],
                        "--ox-hash", entry["ox_hash"], "--size", str(entry["size"])],
                       input=nsec + "\n", text=True, capture_output=True, timeout=180)
    return p.returncode == 0


# ═══ Événements du relais (paquets coopératifs des autres stations) ═════════
def relay_events(**flt):
    """Événements Kind 30510 du relais local (strfry), un JSON par ligne."""
    cmd = [str(TOOLS / "nostr_get_events.sh"), "--kind", str(KIND), "--limit", str(flt.get("limit", 500))]
    if flt.get("tag_t"):
        cmd += ["--tag-t", flt["tag_t"]]
    if flt.get("author"):
        cmd += ["--author", flt["author"]]
    p = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
    out = []
    for line in p.stdout.splitlines():
        try:
            ev = json.loads(line)
            if ev.get("kind") == KIND:
                out.append(ev)
        except ValueError:
            pass
    return out


def _tag(ev, name):
    return next((t[1] for t in ev.get("tags", []) if len(t) > 1 and t[0] == name), None)


def coop_assets():
    """Dernière version de chaque paquet coopératif publié par n'importe quelle station."""
    latest = {}
    for ev in relay_events(tag_t="coop"):
        key = (ev["pubkey"], _tag(ev, "d"))
        if key not in latest or ev["created_at"] > latest[key]["created_at"]:
            latest[key] = ev
    me = captain_hex()
    out = []
    for ev in latest.values():
        try:
            c = json.loads(ev["content"])
        except ValueError:
            continue
        out.append({"cid": c.get("cid"), "type": c.get("type"), "name": c.get("title"),
                    "description": c.get("description", ""), "created": ev["created_at"],
                    "version": c.get("version", 1), "event_id": ev["id"], "d": _tag(ev, "d"),
                    "scope": "coop", "author": ev["pubkey"], "mine": ev["pubkey"] == me,
                    "x_hash": _tag(ev, "x"), "size": int(_tag(ev, "size") or 0),
                    "summary": c.get("summary", {}), "history": c.get("history", []),
                    "renders": c.get("renders", []), "shared": 0})
    return out


# ═══ Création de versions ═══════════════════════════════════════════════════
def _entry_key(entry):
    return coop_key() if entry.get("scope") == "coop" else entry["key_hex"]


def history_for(entry):
    """Versions antérieures de la plus récente à la plus ancienne (chaîne `previous` du keyring)."""
    k, out, cur = load_keyring(), [], entry
    while cur.get("previous") and cur["previous"] in k:
        cur = k[cur["previous"]]
        out.append({"cid": cur["cid"], "version": cur.get("version", 1), "created": cur["created"], "x_hash": cur["x_hash"]})
    return out


def renders_index():
    return _load(RENDERS)


def renders_for_chain(entry):
    idx = renders_index()
    cids = [entry["cid"]] + [h["cid"] for h in history_for(entry)]
    return [{k: v for k, v in r.items() if k != "dir"} | {"version_cid": c}  # jamais le chemin local
            for c in cids for r in idx.get(c, []) if r.get("public")]


def _event_for(entry):
    typ, name = entry["type"], entry["name"]
    tags = [["d", entry["d"]], ["title", name], ["t", typ], ["t", "uenc-aes256gcm"],
            ["x", entry["x_hash"]], ["r", f"ipfs://{entry['cid']}", "bundle"], ["size", str(entry["size"])]]
    if entry["scope"] == "coop":
        tags.append(["t", "coop"])
    if entry.get("origin"):
        tags.append(["a", f"{KIND}:{entry['origin']['author']}:{entry['origin']['d']}", "", "fork"])
    content = {"title": name, "type": typ, "description": entry.get("description", ""), "cid": entry["cid"],
               "encryption": "uenc-aes256gcm", "scope": entry["scope"], "summary": entry.get("summary", {}),
               "files": entry.get("nfiles", 0), "version": entry.get("version", 1),
               "history": history_for(entry)}
    if entry["scope"] == "coop":
        content["renders"] = renders_for_chain(entry)
    return tags, content


def announce(entry, dry_run=False):
    """(Re)publie l'événement courant d'un paquet : nouvelle version, ou nouveau rendu disponible."""
    tags, content = _event_for(entry)
    eid = "dry-run" if dry_run else publish_event(captain_secret(), tags, content)
    with keyring_lock():
        k = load_keyring()
        k[entry["cid"]]["event_id"] = eid
        save_keyring(k)
    entry["event_id"] = eid
    return eid


def seal(manifest, files, scope="private", dry_run=False, previous=None, origin=None):
    """Chiffre le paquet, l'ajoute à IPFS, publie le Kind 30510 (remplaçable : même d-tag qu'une version
    précédente) et enregistre l'entrée dans le keyring. Les anciens CID restent épinglés."""
    if scope not in SCOPES:
        die(f"scope inconnu : {scope}")
    name, typ = manifest["name"], manifest["type"]
    plain = build_tar(manifest, files)
    if len(plain) > MAX_BYTES:
        die("paquet trop gros")
    key_hex = coop_key() if scope == "coop" else os.urandom(32).hex()
    blob, iv_hex = encrypt_aes256gcm(plain, key_hex)
    cid = ipfs_add(blob, f"{slug(name)}.uenc")
    entry = {"cid": cid, "scope": scope, "iv_hex": iv_hex, "type": typ, "name": name, "size": len(blob),
             "x_hash": hashlib.sha256(blob).hexdigest(), "ox_hash": hashlib.sha256(plain).hexdigest(),
             "created": int(time.time()), "event_id": None, "d": f"{typ}-{slug(name)}",
             "shared_with": list((previous or {}).get("shared_with", [])), "description": manifest.get("description", ""),
             "summary": manifest.get("scene") or manifest.get("character") or {}, "nfiles": len(files),
             "version": (previous or {}).get("version", 0) + 1}
    if scope == "private":
        entry["key_hex"] = key_hex  # la clé coopérative se recalcule, elle n'est jamais stockée
    if previous:
        entry["previous"] = previous["cid"]
        entry["d"] = previous["d"]
    if origin:
        entry["origin"] = origin
    with keyring_lock():
        k = load_keyring()
        if previous and previous["cid"] in k:
            k[previous["cid"]]["superseded_by"] = cid
        k[cid] = entry
        save_keyring(k)
    announce(entry, dry_run=dry_run)
    if scope == "private" and not dry_run:
        _backup_key_by_dm(entry)
    print(f"✅ {scope} {typ} « {name} » v{entry['version']} → Kind {KIND} d={entry['d']} event_id={entry['event_id']}\n"
          f"   CID {cid} ({len(blob) // 1024} Ko chiffrés)", file=sys.stderr)
    return entry


def _backup_key_by_dm(entry):
    """Sauvegarde best-effort de la clé AES d'une version PRIVATE par DM NOSTR « à soi-même »
    (kind 4, même mécanisme que `bro.nostr.send_dm_to_owner`) : seul moyen de redéchiffrer ce
    paquet si `library/keyring.json` est perdu (ex. suppression de $SCENES_DIR) — le relais
    garde le DM, déchiffrable avec le seul MULTIPASS du Capitaine (donc hors de $SCENES_DIR).
    Échec silencieux (relais injoignable) : n'empêche jamais la publication elle-même."""
    hexpub = captain_hex()
    if not hexpub:
        return
    # Préfixe non-JSON : nostr_node_intercom.py decrypt traite tout contenu qui PARSE comme
    # JSON comme une « enveloppe » {channel,payload} (repli "plain" sinon) — un payload JSON
    # brut s'y ferait vider (payload devient {} faute de clé "payload" dans nos propres
    # données). Le marqueur fait échouer volontairement ce json.loads côté decrypt.
    payload = "STORY_KEY_BACKUP:" + json.dumps({"story_key_backup": 1, "cid": entry["cid"], "d": entry["d"],
                                                "type": entry["type"], "name": entry["name"], "key_hex": entry["key_hex"]},
                                               ensure_ascii=False)
    try:
        subprocess.run([sys.executable, str(TOOLS / "nostr_send_secure_dm.py"), "--nsec-stdin", hexpub, payload, RELAY,
                        "--extra-tags", json.dumps([["t", "story-key-backup"]])],
                       input=captain_secret() + "\n", text=True, capture_output=True, timeout=30)
    except Exception:
        pass


def _fetch_private_key_backups():
    """Sauvegardes de clé envoyées par `_backup_key_by_dm` (kind 4, self-DM), déchiffrées —
    {cid: key_hex}. Échec gracieux (liste vide) si le relais ou le déchiffrement est indisponible."""
    hexpub = captain_hex()
    if not hexpub:
        return {}
    p = subprocess.run([str(TOOLS / "nostr_get_events.sh"), "--kind", "4", "--author", hexpub,
                        "--tag-p", hexpub, "--tag-t", "story-key-backup", "--limit", "1000"],
                       capture_output=True, text=True, timeout=60)
    nsec = captain_secret()
    out = {}
    for line in p.stdout.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("kind") != 4:
            continue
        dp = subprocess.run([sys.executable, str(TOOLS / "nostr_node_intercom.py"), "decrypt"],
                            input=json.dumps(ev), capture_output=True, text=True, timeout=15,
                            env={**os.environ, "NOSTR_NSEC": nsec})
        if dp.returncode != 0 or not dp.stdout.strip():
            continue
        try:
            text = json.loads(dp.stdout).get("payload", {}).get("text") or ""
            backup = json.loads(text[len("STORY_KEY_BACKUP:"):]) if text.startswith("STORY_KEY_BACKUP:") else None
        except ValueError:
            continue
        if backup and backup.get("story_key_backup") and backup.get("cid") and backup.get("key_hex"):
            out[backup["cid"]] = backup["key_hex"]
    return out


def rebuild(force=False):
    """Reconstruit `library/keyring.json` depuis le relais NOSTR (mes propres Kind 30510) et
    les sauvegardes de clé privée (self-DM) — pour quand $SCENES_DIR a été supprimé. Les
    paquets `coop` sont TOUJOURS entièrement récupérables (clé dérivée de $UPLANETNAME, jamais
    stockée nulle part) ; un paquet `private` ne l'est que si sa clé a été sauvegardée par DM
    (voir `_backup_key_by_dm`, actif depuis l'ajout de cette fonction) — sinon il reste listé
    (titre, type, historique) mais non déchiffrable ici. Ne fait rien sur un trousseau déjà
    rempli, sauf `--force` (évite d'écraser par mégarde un trousseau sain)."""
    if not force and load_keyring():
        die("library/keyring.json existe déjà et n'est pas vide : --force pour écraser quand même")
    me = captain_hex()
    if not me:
        die("MULTIPASS du Capitaine introuvable : impossible de savoir qui je suis")
    events = relay_events(author=me, limit=1000)
    latest = {}
    for ev in events:
        d = _tag(ev, "d")
        if d and (d not in latest or ev["created_at"] > latest[d]["created_at"]):
            latest[d] = ev
    key_backups = _fetch_private_key_backups()
    k, lineages, found, recovered = {}, 0, 0, 0
    for ev in latest.values():
        try:
            c = json.loads(ev["content"])
        except ValueError:
            continue
        cid = c.get("cid")
        if not cid:
            continue
        lineages += 1
        scope = c.get("scope", "private")
        chain = [{"cid": cid, "version": c.get("version", 1), "created": ev["created_at"], "x_hash": _tag(ev, "x")}] \
                + list(c.get("history", []))
        for i, v in enumerate(chain):
            found += 1
            entry = {"cid": v["cid"], "scope": scope, "type": c.get("type"), "name": c.get("title"),
                     "x_hash": v.get("x_hash"), "size": int(_tag(ev, "size") or 0) if i == 0 else 0,
                     "created": v.get("created", ev["created_at"]), "event_id": ev["id"] if i == 0 else None,
                     "d": _tag(ev, "d"), "shared_with": [],
                     "description": c.get("description", "") if i == 0 else "",
                     "summary": (c.get("summary", {}) if i == 0 else {}), "nfiles": c.get("files", 0),
                     "version": v.get("version", 1)}
            if i + 1 < len(chain):
                entry["previous"] = chain[i + 1]["cid"]
            if i > 0:
                entry["superseded_by"] = chain[i - 1]["cid"]
            if scope == "coop":
                recovered += 1
            elif v["cid"] in key_backups:
                entry["key_hex"] = key_backups[v["cid"]]
                recovered += 1
            k[v["cid"]] = entry
    with keyring_lock():
        save_keyring(k)
    return {"lineages": lineages, "versions": found, "recovered": recovered, "unrecoverable": found - recovered}


def share(nsec, entry, friends):
    if entry["scope"] == "coop":
        die("paquet coopératif : tous les Capitaines le lisent déjà, rien à envoyer")
    sent = []
    for who in friends.split(","):
        if not who.strip():
            continue
        hx = friend_hex(who)
        ok = send_key(nsec, hx, entry)
        print(f"{'🎁' if ok else '❌'} clé envoyée à {who.strip()} ({hx[:12]}…) par message fichier NIP-17", file=sys.stderr)
        if ok:
            sent.append(hx)
    if sent:
        with keyring_lock():
            k = load_keyring()
            cur = k.get(entry["cid"], entry)
            cur["shared_with"] = sorted(set(cur.get("shared_with", [])) | set(sent))
            k[entry["cid"]] = cur
            save_keyring(k)
        entry["shared_with"] = cur["shared_with"]
    return sent


def find_entry(ref):
    """Entrée du keyring (mes paquets) ou, à défaut, paquet coopératif d'une autre station."""
    k = load_keyring()
    if ref in k:
        return k[ref]
    for e in k.values():
        if e.get("event_id") == ref:
            return e
    for a in coop_assets():
        versions = [{"cid": a["cid"], "version": a["version"], "x_hash": a["x_hash"]}] + a["history"]
        for v in versions:
            if ref in (v["cid"], a["event_id"]):
                return {"cid": v["cid"], "scope": "coop", "foreign": not a["mine"], "type": a["type"], "name": a["name"],
                        "x_hash": v.get("x_hash"), "version": v.get("version", 1), "d": a["d"], "author": a["author"],
                        "created": v.get("created", a["created"]), "description": a["description"], "event_id": a["event_id"],
                        "summary": a["summary"], "history": a["history"], "renders": a["renders"], "size": a["size"]}
    die(f"« {ref} » introuvable (ni dans le keyring de cette station, ni parmi les paquets coopératifs du relais)")


def latest_of(entry):
    k = load_keyring()
    while entry.get("superseded_by") and entry["superseded_by"] in k:
        entry = k[entry["superseded_by"]]
    return entry


def list_assets():
    """Mes paquets (dernières versions seulement) + paquets coopératifs des autres stations."""
    out = []
    for cid, e in load_keyring().items():
        if e.get("superseded_by"):
            continue
        out.append({k: e.get(k) for k in ("cid", "type", "name", "description", "created", "version", "event_id", "d", "scope")}
                   | {"size": e.get("size"), "shared": len(e.get("shared_with", [])), "mine": True,
                      "summary": e.get("summary", {}), "forked": bool(e.get("origin"))})
    try:
        for a in coop_assets():
            if not a["mine"]:
                out.append({k: a[k] for k in ("cid", "type", "name", "description", "created", "version", "event_id", "d",
                                              "scope", "size", "shared", "mine", "summary", "author")} | {"forked": False})
    except Exception:  # relais indisponible : on garde au moins ses propres paquets
        pass
    return sorted(out, key=lambda x: x["created"] or 0, reverse=True)


def open_bundle(ref):
    """(entrée, manifest, {chemin: bytes}) ; fonctionne pour toute version, même ancienne, et pour les paquets
    coopératifs des autres stations (clé dérivée de UPLANETNAME)."""
    e = find_entry(ref)
    blob = ipfs_cat(e["cid"])
    if e.get("x_hash") and hashlib.sha256(blob).hexdigest() != e["x_hash"]:
        die("le blob IPFS ne correspond plus à son hash (corrompu)")
    try:
        plain = decrypt_aes256gcm(blob, _entry_key(e))
    except Exception as exc:
        die(f"déchiffrement impossible : {exc}")
    if e.get("foreign"):
        ipfs_pin(e["cid"])  # chaque station qui consulte un paquet de la coopérative le conserve
    files = {}
    with tarfile.open(fileobj=io.BytesIO(plain), mode="r:gz") as tar:
        for m in tar.getmembers():
            if m.isfile():
                files[m.name] = tar.extractfile(m).read()
    manifest = json.loads(files.pop("manifest.json"))
    return e, manifest, files


def check_path(path):
    dest = (SCENES.resolve() / path).resolve()
    if path.startswith("/") or ".." in pathlib.PurePosixPath(path).parts or SCENES.resolve() not in dest.parents:
        die(f"chemin refusé : {path}")


def validate_storyboard(data):
    """Mêmes règles que generate_scene.sh."""
    try:
        sb = json.loads(data)
    except ValueError as exc:
        die(f"storyboard.json invalide : {exc}")
    shots = sb.get("shots")
    if not isinstance(shots, list) or not shots:
        die("storyboard : « shots » doit être une liste non vide")
    for i, sh in enumerate(shots, 1):
        if not (isinstance(sh.get("prompt"), str) or (sh.get("screen") and not sh.get("presenter")) or sh.get("card")):
            die(f"storyboard : plan {i} sans prompt (ou screen sans présentateur, ou card)")
    if shots[0].get("continue"):
        die("storyboard : le premier plan ne peut pas être « continue »")
    cast = sb.get("cast") or {}
    missing = sorted({n for sh in shots for n in (sh.get("cast") or []) + ([sh["presenter"]] if sh.get("presenter") else [])
                      if n not in cast})
    if missing:
        die("storyboard : acteur(s) absent(s) de « cast » : " + ", ".join(missing))
    return sb


def attach_cast(files, storyboard_bytes, char_ref, name=None):
    """Copie un personnage (portrait, voix, fiche) dans une scène et l'ajoute à son « cast »."""
    _e, cman, cfiles = open_bundle(char_ref)
    if cman["type"] != "character":
        die("seul un personnage peut être ajouté au casting")
    cname = name or cman["name"]
    sb = json.loads(storyboard_bytes)
    cast = sb.setdefault("cast", {})
    meta = json.loads(next((v for p, v in cfiles.items() if p.endswith("character.json")), b"{}"))
    entry = {}
    for p, v in cfiles.items():
        files[f"cast/{cname}/{pathlib.PurePosixPath(p).name}"] = v
    if f"cast/{cname}/portrait.png" in files:
        entry["image"] = f"$SCENES_DIR/cast/{cname}/portrait.png"
    elif meta.get("look"):
        entry["image_prompt"] = meta["look"]
    if f"cast/{cname}/voice.wav" in files:
        entry["voice"] = f"$SCENES_DIR/cast/{cname}/voice.wav"
    elif meta.get("voice_design"):
        entry["voice_design"] = meta["voice_design"]
        entry["voice_line"] = meta.get("voice_line", "Bonjour, je suis là pour vous présenter la suite.")
    cast[cname] = entry
    return json.dumps(sb, ensure_ascii=False, indent=1).encode()


def new_version(ref, changes, description=None, reshare=True, dry_run=False, attach=None):
    """Applique `changes` ({chemin: bytes | None pour supprimer}) et republie. Seulement sur mes paquets."""
    e, manifest, files = open_bundle(ref)
    if e.get("foreign"):
        die("paquet d'un autre Capitaine : faites-en d'abord une copie (fork) dans votre bibliothèque")
    e = latest_of(e)
    for path, data in changes.items():
        if path == "manifest.json":
            die("manifest.json n'est pas modifiable")
        check_path(path)
        if data is None:
            files.pop(path, None)
        else:
            files[path] = data
    for att in attach or []:
        if "storyboard.json" not in files:
            die("ajout de personnage : ce paquet n'est pas une scène")
        files["storyboard.json"] = attach_cast(files, files["storyboard.json"], att["cid"], att.get("name"))
        changes = dict(changes, **{"storyboard.json": files["storyboard.json"]})
    if changes.get("storyboard.json") is not None:
        sb = validate_storyboard(changes["storyboard.json"])
        manifest["scene"] = {"shots": len(sb["shots"]), "ratio": sb.get("ratio", "16:9"),
                             "cast": sorted((sb.get("cast") or {}).keys())}
    if description is not None:
        manifest["description"] = description
    manifest["files"] = sorted(files)
    manifest["modified"] = int(time.time())
    entry = seal(manifest, sorted(files.items()), scope=e.get("scope", "private"), dry_run=dry_run, previous=e,
                 origin=e.get("origin"))
    if reshare and entry["scope"] == "private" and entry["shared_with"] and not dry_run:
        nsec = captain_secret()
        for hx in entry["shared_with"]:
            ok = send_key(nsec, hx, entry)
            print(f"{'🎁' if ok else '❌'} nouvelle clé → {hx[:12]}…", file=sys.stderr)
    return entry


def restore(ref, dry_run=False):
    """Nouvelle version identique à une version ancienne (l'historique n'est jamais réécrit)."""
    old, manifest, files = open_bundle(ref)
    if old.get("foreign"):
        die("paquet d'un autre Capitaine : faites-en une copie (fork)")
    cur = latest_of(old)
    if cur["cid"] == old["cid"]:
        die("c'est déjà la version courante")
    manifest["restored_from"] = old["cid"]
    manifest["modified"] = int(time.time())
    return seal(manifest, sorted(files.items()), scope=cur.get("scope", "private"), dry_run=dry_run, previous=cur,
                origin=cur.get("origin"))


def fork(ref, name=None, scope="private", dry_run=False):
    """Copie à mon nom d'un paquet (le mien ou celui d'un autre Capitaine) : nouvelle lignée, d-tag propre."""
    e, manifest, files = open_bundle(ref)
    new_name = name or manifest["name"]
    old_name = manifest["name"]
    manifest = dict(manifest, name=new_name, forked_from={"cid": e["cid"], "author": e.get("author") or captain_hex()},
                    modified=int(time.time()))
    if manifest["type"] == "character" and new_name != old_name:  # le dossier cast/<nom>/ suit le nom
        files = {re.sub(r"^cast/" + re.escape(old_name) + "/", f"cast/{new_name}/", p): v for p, v in files.items()}
    manifest["files"] = sorted(files)
    origin = {"author": e.get("author") or captain_hex(), "d": e["d"], "cid": e["cid"]}
    return seal(manifest, sorted(files.items()), scope=scope, dry_run=dry_run, origin=origin)


def delete(ref):
    """Retire un paquet (toute sa lignée de versions) de la bibliothèque LOCALE et demande sa
    suppression (NIP-09, kind 5) pour son événement courant. Les blobs IPFS restent épinglés
    (comme pour toute ancienne version : rien n'est jamais réécrit) ; un paquet coop peut
    rester visible chez d'autres Capitaines tant qu'ils n'ont pas fait de même."""
    e = find_entry(ref)
    if e.get("foreign"):
        die("paquet d'un autre Capitaine : on ne peut retirer que les siens")
    cur = latest_of(e)
    if cur.get("event_id"):
        subprocess.run([sys.executable, str(TOOLS / "nostr_node_intercom.py"), "publish", "--nsec-stdin",
                        "--kind", "5", "--tags", json.dumps([["e", cur["event_id"]]]),
                        "--content", "", "--relays", RELAY],
                       input=captain_secret() + "\n", text=True, capture_output=True, timeout=30)
    chain_cids = [cur["cid"]] + [h["cid"] for h in history_for(cur)]
    with keyring_lock():
        k = load_keyring()
        for cid in chain_cids:
            k.pop(cid, None)
        save_keyring(k)
    return {"removed": chain_cids, "name": cur.get("name"), "type": cur.get("type")}


def export_bytes(ref):
    """Tar.gz EN CLAIR (manifest + fichiers) d'un paquet : portable, hors chiffrement/IPFS/NOSTR
    de cette station — pour sauvegarde locale ou transfert manuel vers une autre machine."""
    _e, manifest, files = open_bundle(ref)
    return build_tar(manifest, sorted(files.items()))


def _unique_name(typ, name):
    """Évite qu'un import retombe sur le même d-tag (typ-slug(nom)) qu'un asset déjà en
    bibliothèque : un Kind 30510 est remplaçable par (pubkey, kind, d) — une collision
    écraserait l'annonce de l'autre asset sans toucher à son contenu chiffré."""
    k = load_keyring()
    taken = {e["name"] for e in k.values() if not e.get("superseded_by") and e.get("type") == typ}
    if name not in taken:
        return name
    i = 2
    while f"{name} ({i})" in taken:
        i += 1
    return f"{name} ({i})"


def import_file(blob, scope="private", name=None, description=None, dry_run=False):
    """Installe un paquet exporté (tar.gz EN CLAIR, cf. export_bytes) comme nouvel asset de
    CETTE bibliothèque : nouvelle clé, nouveau CID, nouvelle lignée (comme `fork`, mais depuis
    un fichier local plutôt qu'une référence déjà présente sur ce swarm)."""
    try:
        with tarfile.open(fileobj=io.BytesIO(blob), mode="r:gz") as tar:
            if "manifest.json" not in tar.getnames():
                die("paquet invalide : manifest.json absent")
            manifest = json.loads(tar.extractfile("manifest.json").read())
            files = {m.name: tar.extractfile(m).read() for m in tar.getmembers() if m.isfile() and m.name != "manifest.json"}
    except tarfile.TarError as exc:
        die(f"paquet illisible (tar.gz invalide) : {exc}")
    if manifest.get("type") not in ("character", "scene"):
        die("type de paquet inconnu : " + str(manifest.get("type")))
    old_name = manifest["name"]
    new_name = _unique_name(manifest["type"], (name or old_name).strip() or old_name)
    if manifest["type"] == "character" and new_name != old_name:
        files = {re.sub(r"^cast/" + re.escape(old_name) + "/", f"cast/{new_name}/", p): v for p, v in files.items()}
    manifest = dict(manifest, name=new_name, imported=int(time.time()))
    if description is not None:
        manifest["description"] = description
    manifest["files"] = sorted(files)
    return seal(manifest, sorted(files.items()), scope=scope, dry_run=dry_run)


STARTER_SCENE = {
    "ratio": "16:9", "style": "clean", "height": 720, "cast": {},
    "shots": [{"prompt": "A calm establishing shot of a sunny village square, gentle ambient music.", "duration": 5}],
}


def create(typ, name, scope="private", description="", dry_run=False):
    """Paquet de départ : une scène d'un plan, ou un personnage (fiche seule, portrait et voix se génèrent ensuite)."""
    manifest = {"version": 1, "type": typ, "name": name, "description": description, "created": int(time.time())}
    if typ == "scene":
        files = [("storyboard.json", json.dumps(STARTER_SCENE, indent=1).encode())]
        manifest["scene"] = {"shots": 1, "ratio": "16:9", "cast": []}
    elif typ == "character":
        meta = {"name": name, "look": "", "voice_design": "", "voice_line": "Bonjour, je m'appelle %s." % name}
        files = [(f"cast/{name}/character.json", json.dumps(meta, ensure_ascii=False, indent=1).encode())]
        manifest["character"] = {"has_voice": False}
    else:
        die("type inconnu : character ou scene")
    manifest["files"] = [f[0] for f in files]
    return seal(manifest, files, scope=scope, dry_run=dry_run)


def versions(ref):
    """Toutes les versions, de la plus récente à la plus ancienne, avec leurs rendus."""
    e = find_entry(ref)
    idx = renders_index()
    if e.get("foreign") or e["cid"] not in load_keyring():
        chain = [{"cid": e["cid"], "version": e.get("version", 1), "created": e.get("created")}] + list(e.get("history", []))
        pub = {}
        for r in e.get("renders", []):
            pub.setdefault(r["version_cid"], []).append(r)
        return [dict(c, renders=pub.get(c["cid"], []), latest=(i == 0)) for i, c in enumerate(chain)]
    cur = latest_of(e)
    k = load_keyring()
    chain = [{"cid": cur["cid"], "version": cur.get("version", 1), "created": cur["created"],
              "description": cur.get("description", "")}]
    chain += [{**h, "description": k.get(h["cid"], {}).get("description", "")} for h in history_for(cur)]
    return [dict(c, renders=idx.get(c["cid"], []), latest=(i == 0)) for i, c in enumerate(chain)]


def add_render(version_cid, record):
    with keyring_lock():
        idx = renders_index()
        idx.setdefault(version_cid, []).append(record)
        _save(RENDERS, idx)


def resolve_character(name, dest_dir):
    """Pont CLI ↔ Studio web : cherche un personnage nommé ainsi dans la bibliothèque (le
    mien, sinon celui d'un Capitaine de la coopérative) et installe portrait/voix/fiche dans
    dest_dir — un personnage créé d'un côté (web ou `generate_character.sh` publié) devient
    utilisable de l'autre (CLI, `generate_scene.sh`) sans rien exporter/réimporter à la main.
    True si trouvé et installé, False sinon (non fatal : l'appelant garde son propre message
    d'erreur si le personnage reste introuvable)."""
    match = next((a for a in list_assets() if a["type"] == "character" and a["name"].lower() == name.lower()), None)
    if not match:
        return False
    _e, _m, files = open_bundle(match["cid"])
    dest = pathlib.Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)
    prefix = f"cast/{match['name']}/"
    n = 0
    for p, data in files.items():
        if p.startswith(prefix):
            (dest / pathlib.Path(p).name).write_bytes(data)
            n += 1
    return n > 0


# ═══ Import d'un paquet reçu par DM ═════════════════════════════════════════
def import_bundle(cid, key, sha256=None, force=False):
    cid = cid.replace("/ipfs/", "").replace("ipfs://", "")
    blob = ipfs_cat(cid)
    if sha256 and hashlib.sha256(blob).hexdigest() != sha256:
        die("sha256 du blob différent de l'attendu (CID substitué ou corrompu)")
    try:
        plain = decrypt_aes256gcm(blob, key)
    except Exception as exc:
        die(f"déchiffrement impossible : {exc}")
    root = SCENES.resolve()
    with tarfile.open(fileobj=io.BytesIO(plain), mode="r:gz") as tar:
        for m in tar.getmembers():
            dest = (root / m.name).resolve()
            if not m.isfile() or m.name.startswith("/") or root not in dest.parents and dest != root:
                die(f"entrée refusée dans le paquet : {m.name}")
        manifest = json.loads(tar.extractfile("manifest.json").read())
        SCENES.mkdir(parents=True, exist_ok=True)
        n = 0
        for m in tar.getmembers():
            if m.name == "manifest.json":
                continue
            dest = root / m.name
            if dest.exists() and not force:
                print(f"   existe déjà, conservé : {m.name} (--force pour écraser)", file=sys.stderr)
                continue
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(tar.extractfile(m).read())
            n += 1
    return manifest, n


# ═══ CLI ════════════════════════════════════════════════════════════════════
def _files_from_publish(a):
    manifest = {"version": 1, "type": a.type, "name": a.name, "description": a.description or "", "created": int(time.time())}
    files = []
    if a.type == "character":
        d = pathlib.Path(a.dir) if a.dir else SCENES / "cast" / a.name
        if not (d / "portrait.png").is_file():
            die(f"{d}/portrait.png absent")
        for f in sorted(d.iterdir()):
            if f.is_file():
                files.append((pathlib.Path("cast") / a.name / f.name, f))
        manifest["character"] = {"has_voice": (d / "voice.wav").is_file()}
    else:
        sb_path = pathlib.Path(a.source)
        sb = json.loads(sb_path.read_text())
        refs = set()
        home = str(pathlib.Path.home())

        def walk(o):
            if isinstance(o, dict):
                for v in o.values():
                    walk(v)
            elif isinstance(o, list):
                for v in o:
                    walk(v)
            elif isinstance(o, str):
                s = o.replace("$SCENES_DIR", str(SCENES)).replace("${SCENES_DIR}", str(SCENES)).replace("$HOME", home).replace("${HOME}", home)
                if s.startswith("/") and os.path.isfile(s):
                    refs.add(s)
        walk(sb)
        files.append((pathlib.Path("storyboard.json"), sb_path))
        for r in sorted(refs):
            rel = rel_to_scenes(r)
            if rel is None:
                print(f"Attention : {r} est hors de {SCENES}, non inclus", file=sys.stderr)
            else:
                files.append((rel, pathlib.Path(r)))
        if a.video:
            files.append((pathlib.Path("scene.mp4"), pathlib.Path(a.video)))
        manifest["scene"] = {"shots": len(sb.get("shots", [])), "ratio": sb.get("ratio", "16:9"),
                             "cast": sorted((sb.get("cast") or {}).keys())}
    manifest["files"] = [str(f[0]) for f in files]
    return manifest, files


def cmd_publish(a):
    manifest, files = _files_from_publish(a)
    entry = seal(manifest, files, scope=a.scope, dry_run=a.dry_run)
    if a.share and not a.dry_run:
        share(captain_secret(), entry, a.share)
    print(entry["event_id"])


def cmd_create(a):
    print(create(a.type, a.name, a.scope, a.description or "", a.dry_run)["cid"])


def cmd_update(a):
    changes = {}
    for spec in a.set or []:
        path, _, local = spec.partition("=")
        changes[path] = pathlib.Path(local).read_bytes()
    for path in a.delete or []:
        changes[path] = None
    e = new_version(a.ref, changes, a.description, reshare=not a.no_reshare, dry_run=a.dry_run)
    print(e["event_id"])


def cmd_get(a):
    e, manifest, files = open_bundle(a.ref)
    print(json.dumps({"manifest": manifest, "files": {k: len(v) for k, v in files.items()}}, ensure_ascii=False, indent=1))


def cmd_share(a):
    share(captain_secret(), find_entry(a.ref), a.friends)


def cmd_import(a):
    manifest, n = import_bundle(a.cid, a.key, a.sha256, a.force)
    print(f"✅ {manifest.get('type')} « {manifest.get('name')} » installé dans {SCENES} ({n} fichier(s))", file=sys.stderr)


def cmd_export(a):
    blob = export_bytes(a.ref)
    pathlib.Path(a.out).write_bytes(blob)
    print(f"✅ exporté : {a.out} ({len(blob) // 1024} Ko, en clair)", file=sys.stderr)


def cmd_importpkg(a):
    entry = import_file(pathlib.Path(a.file).read_bytes(), a.scope, a.name, a.description, a.dry_run)
    print(entry["event_id"])


def cmd_list(a):
    for e in list_assets():
        if a.coop and e["scope"] != "coop":
            continue
        who = "moi" if e["mine"] else "autre"
        print(f"{e['type']:<9} {e['name']:<28} v{e['version']} {e['scope']:<7} {who:<5} {e['cid']}")


def cmd_versions(a):
    for v in versions(a.ref):
        print(f"v{v['version']:<3} {v['cid']}  {time.strftime('%Y-%m-%d %H:%M', time.localtime(v['created'] or 0))}  rendus={len(v['renders'])}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    pp = sub.add_parser("publish")
    pp.add_argument("type", choices=["character", "scene"])
    pp.add_argument("name")
    pp.add_argument("source", nargs="?", help="scene : storyboard.json")
    pp.add_argument("--dir")
    pp.add_argument("--video")
    pp.add_argument("--share")
    pp.add_argument("--description")
    pp.add_argument("--scope", choices=SCOPES, default="private")
    pp.add_argument("--dry-run", action="store_true", help="chiffre et ajoute à IPFS local, sans publier d'événement ni de DM")
    pp.set_defaults(fn=cmd_publish)
    pc = sub.add_parser("create")
    pc.add_argument("type", choices=["character", "scene"])
    pc.add_argument("name")
    pc.add_argument("--scope", choices=SCOPES, default="private")
    pc.add_argument("--description")
    pc.add_argument("--dry-run", action="store_true")
    pc.set_defaults(fn=cmd_create)
    pu = sub.add_parser("update", help="nouvelle version d'un paquet")
    pu.add_argument("ref", help="CID ou event_id")
    pu.add_argument("--set", action="append", metavar="CHEMIN=FICHIER")
    pu.add_argument("--delete", action="append", metavar="CHEMIN")
    pu.add_argument("--description")
    pu.add_argument("--no-reshare", action="store_true")
    pu.add_argument("--dry-run", action="store_true")
    pu.set_defaults(fn=cmd_update)
    pg = sub.add_parser("get")
    pg.add_argument("ref")
    pg.set_defaults(fn=cmd_get)
    ps = sub.add_parser("share")
    ps.add_argument("ref")
    ps.add_argument("friends")
    ps.set_defaults(fn=cmd_share)
    pi = sub.add_parser("import")
    pi.add_argument("cid")
    pi.add_argument("--key", required=True)
    pi.add_argument("--iv")
    pi.add_argument("--sha256")
    pi.add_argument("--force", action="store_true")
    pi.set_defaults(fn=cmd_import)
    pl = sub.add_parser("list")
    pl.add_argument("--coop", action="store_true")
    pl.set_defaults(fn=cmd_list)
    pv = sub.add_parser("versions")
    pv.add_argument("ref")
    pv.set_defaults(fn=cmd_versions)
    pr = sub.add_parser("restore")
    pr.add_argument("ref")
    pr.add_argument("--dry-run", action="store_true")
    pr.set_defaults(fn=lambda a: print(restore(a.ref, a.dry_run)["cid"]))
    pf = sub.add_parser("fork")
    pf.add_argument("ref")
    pf.add_argument("--name")
    pf.add_argument("--scope", choices=SCOPES, default="private")
    pf.add_argument("--dry-run", action="store_true")
    pf.set_defaults(fn=lambda a: print(fork(a.ref, a.name, a.scope, a.dry_run)["cid"]))
    pdel = sub.add_parser("delete", help="retire un paquet (toute sa lignée) de la bibliothèque locale")
    pdel.add_argument("ref")
    pdel.set_defaults(fn=lambda a: print(json.dumps(delete(a.ref), ensure_ascii=False)))
    prc = sub.add_parser("resolve-character", help="installe un personnage de la bibliothèque dans un dossier — pont CLI/Web")
    prc.add_argument("name")
    prc.add_argument("--dest", required=True)
    prc.set_defaults(fn=lambda a: sys.exit(0 if resolve_character(a.name, a.dest) else 1))
    prb = sub.add_parser("rebuild", help="reconstruit library/keyring.json depuis NOSTR (coop entier ; private si sauvegardé par DM à soi-même)")
    prb.add_argument("--force", action="store_true", help="écrase un trousseau déjà non vide")
    prb.set_defaults(fn=lambda a: print(json.dumps(rebuild(a.force), ensure_ascii=False)))
    pe = sub.add_parser("export", help="tar.gz EN CLAIR d'un paquet (sauvegarde / transfert manuel hors IPFS/NOSTR)")
    pe.add_argument("ref")
    pe.add_argument("-o", "--out", required=True)
    pe.set_defaults(fn=cmd_export)
    pk = sub.add_parser("importpkg", help="installe un paquet exporté (tar.gz) comme nouvel asset de CETTE bibliothèque")
    pk.add_argument("file")
    pk.add_argument("--scope", choices=SCOPES, default="private")
    pk.add_argument("--name")
    pk.add_argument("--description")
    pk.add_argument("--dry-run", action="store_true")
    pk.set_defaults(fn=cmd_importpkg)
    a = p.parse_args()
    if a.cmd == "publish" and a.type == "scene" and not a.source:
        p.error("scene demande STORYBOARD.json")
    try:
        a.fn(a)
    except AssetError as exc:
        print(f"ERREUR : {exc}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
