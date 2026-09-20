#!/usr/bin/env python3
"""
satellite_face_matcher.py — Appariement FaceID + partage NIP-17 (côté Satellite).

Dernier maillon du pipeline FaceID :

    Cloud chiffré /dav/ (PUT d'une image)
      → UPassport/services/cloud_storage.py::_commit_plaintext
      → tools/trigger_bro_vision_analysis.sh   ── vision_analysis_job ──▶ Brain GPU
      → IA/bro/bro_dm_daemon.sh::_handle_vision_analysis_job (InsightFace/ComfyUI)
      ◀── vision_analysis_result ──
      → IA/bro/bro_dm_daemon.sh::_handle_vision_analysis_result
      → CE SCRIPT

IMPORTANT (2026-09-20) : la SEULE source déclenchant ce pipeline est le cloud
chiffré — jamais le uDRIVE public (manifest.json, publié en clair sur IPNS aux
côtés des events kind 0/1). `ipfs_link` référence donc toujours un blob UENC
chiffré ; ce script relit lui-même la clé dans `.ucloud/keyring.json` du
propriétaire (même fichier que `cloud_storage.py`, même verrou flock) pour le
déchiffrer localement — le clair ne repart jamais tel quel.

Pour chaque visage détecté :
  • recherche du plus proche voisin dans la collection Qdrant `faces_{owner_hex}`
    (512 dims, distance Cosine) ;
  • visage NOMMÉ et associé à un pubkey (score ≥ SEUIL) → vérification de
    réciprocité N1 (chacun suit l'autre) puis partage de la photo, CHIFFRÉE
    avec une clé neuve par destinataire, via un message fichier NIP-17
    (rumor kind:15 gift-wrappé) ;
  • visage inconnu → création d'un point `Inconnu_{hash8}` STABLE (le même
    visage revu demain retombera sur ce même point au lieu d'en créer un
    nouveau) + notification BRO au propriétaire, rate-limitée à 1/24h.

La photo du propriétaire n'est JAMAIS déplacée ni dupliquée : seul un nouveau
blob chiffré (clé AES-256-GCM unique par (photo, destinataire)) est ajouté à
IPFS pour l'envoi, et l'entrée `.ucloud/index.json` du propriétaire est taguée
du nom de l'ami reconnu.

Usage :
    satellite_face_matcher.py <email> <owner_hex> <path> <ipfs_link>
    (le JSON vision_analysis_result complet est lu sur stdin)

Exit : 0 = traité (même si aucun visage), 1 = erreur bloquante.
"""

# Auto-reinvocation dans le venv ~/.astro/ (qdrant-client, cryptography) —
# même amorce que nostr_send_secure_dm.py. stdin est préservé par execv.
import sys as _sys
import os as _os
_venv_python = _os.path.expanduser("~/.astro/bin/python3")
if _os.path.exists(_venv_python) and _sys.executable != _venv_python:
    _os.execv(_venv_python, [_venv_python] + _sys.argv)
del _sys, _os

import contextlib
import fcntl
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path

ZEN = Path.home() / ".zen"
TOOLS = ZEN / "Astroport.ONE" / "tools"
sys.path.insert(0, str(TOOLS))
import uenc_codec  # noqa: E402  — codec UENC partagé (AES-256-GCM)

QDRANT_HOST = "localhost"
QDRANT_PORT = 6333
FACE_VECTOR_SIZE = 512          # InsightFace buffalo_l
MATCH_THRESHOLD = 0.82          # score Cosine minimal pour considérer un match
NOTIF_COOLDOWN = 24 * 3600      # 1 notification max par visage inconnu et par jour
RELAY = "wss://relay.copylaradio.com"
NOTIF_LOCK_DIR = ZEN / "tmp" / "faceid_notif_lock"


def _log(msg: str) -> None:
    """Journal sur stderr — jamais stdout, que l'appelant peut vouloir parser."""
    print(f"[faceid] {msg}", file=sys.stderr, flush=True)


# ── Qdrant ───────────────────────────────────────────────────────────────────

def _client():
    """Client Qdrant local — même amorce que IA/bro/rag.py::_qdrant_client()."""
    import warnings
    from qdrant_client import QdrantClient
    env_file = os.path.expanduser("~/.zen/ai-company/.env")
    api_key = None
    try:
        with open(env_file) as f:
            for line in f:
                if line.startswith("QDRANT_API_KEY="):
                    api_key = line.strip().split("=", 1)[1]
    except Exception:
        pass
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", UserWarning)
        return QdrantClient(url=f"http://{QDRANT_HOST}:{QDRANT_PORT}",
                            api_key=api_key, check_compatibility=False)


def _ensure_collection(client, name: str) -> None:
    from qdrant_client import models
    try:
        if client.collection_exists(name):
            return
    except Exception:
        pass
    try:
        client.create_collection(
            collection_name=name,
            vectors_config=models.VectorParams(size=FACE_VECTOR_SIZE,
                                               distance=models.Distance.COSINE),
        )
        _log(f"collection {name} créée (512 dims, Cosine)")
    except Exception as exc:
        # Course entre deux analyses concurrentes : la collection peut avoir été
        # créée entre-temps, ce n'est pas une erreur.
        if not client.collection_exists(name):
            raise RuntimeError(f"création de la collection {name} impossible : {exc}") from exc


def _embedding_id(embedding: list) -> tuple:
    """(point_id UUID déterministe, suffixe court lisible) dérivés de l'embedding.

    Déterministe pour que le MÊME vecteur ne crée jamais deux points ; le
    rattrapage des visages *similaires* (pas identiques) est fait par la
    recherche vectorielle en amont, pas par cet id."""
    digest = hashlib.sha256(
        json.dumps([round(float(v), 6) for v in embedding],
                   separators=(",", ":")).encode()
    ).hexdigest()
    return str(uuid.UUID(hex=digest[:32])), digest[:8]


# ── Notifications BRO (DM kind 4 classique, pas NIP-17) ──────────────────────

def _node_nsec() -> str:
    """NSEC du NODE (~/.zen/game/secret.nostr) — l'identité du bot BRO."""
    try:
        raw = (ZEN / "game" / "secret.nostr").read_text()
    except Exception:
        return ""
    m = re.search(r"NSEC=([^;\s]+)", raw)
    return m.group(1) if m else ""


def _user_nsec(email: str) -> str:
    """NSEC personnel du MULTIPASS — c'est LUI qui signe les partages NIP-17,
    jamais le NODE_NSEC : la photo est partagée par son propriétaire, pas par
    la station."""
    try:
        raw = (ZEN / "game" / "nostr" / email / ".secret.nostr").read_text()
    except Exception:
        return ""
    m = re.search(r"NSEC=([^;\s]+)", raw)
    return m.group(1) if m else ""


def _mailjet_url(email: str) -> str:
    """Lien vers la page de préférences, où les visages se nomment.
    Token = sha256(email:UPLANETNAME)[:16] — même algo que mailjet.sh et
    UPassport routers/mailjet.py::_token_for()."""
    try:
        uplanetname = (Path.home() / ".ipfs" / "swarm.key").read_text().strip().split("\n")[-1]
    except Exception:
        uplanetname = ""
    token = hashlib.sha256(f"{email}:{uplanetname}".encode()).hexdigest()[:16]
    uspot = os.environ.get("uSPOT", "http://127.0.0.1:54321")
    return f"{uspot}/mailjet?email={email}&token={token}#visages"


def _notify_owner(owner_hex: str, message: str) -> bool:
    """DM NIP-44 classique (kind 4) du bot BRO vers son propre propriétaire.
    Surtout PAS de NIP-17 ici : ce n'est pas une conversation entre humains,
    et le client doit pouvoir l'afficher dans le fil BRO habituel."""
    nsec = _node_nsec()
    if not nsec:
        _log("WARN: NODE_NSEC introuvable — notification non envoyée")
        return False
    try:
        proc = subprocess.run(
            [sys.executable, str(TOOLS / "nostr_send_secure_dm.py"),
             "--nsec-stdin", owner_hex, message, RELAY],
            input=nsec + "\n", text=True, capture_output=True, timeout=120,
        )
        return proc.returncode == 0
    except Exception as exc:
        _log(f"WARN: notification échouée : {exc}")
        return False


def _notify_unknown_face(email: str, owner_hex: str, short: str, path: str) -> None:
    """Notification « visage non reconnu », rate-limitée à 1/24h par visage.

    Le rate-limit est par `Inconnu_xxx` et non global : deux inconnus distincts
    sur la même photo méritent deux notifications, mais le même inconnu revu
    dix fois dans la journée n'en mérite qu'une."""
    NOTIF_LOCK_DIR.mkdir(parents=True, exist_ok=True)
    lock = NOTIF_LOCK_DIR / f"{owner_hex[:16]}_{short}"
    if lock.exists() and (time.time() - lock.stat().st_mtime) < NOTIF_COOLDOWN:
        _log(f"notification Inconnu_{short} supprimée (déjà envoyée < 24h)")
        return
    msg = (f"👤 Visage non reconnu détecté sur {path} — nommez-le dans vos "
           f"préférences pour partager automatiquement vos photos avec cette "
           f"personne :\n{_mailjet_url(email)}")
    if _notify_owner(owner_hex, msg):
        lock.touch()
        _log(f"notification Inconnu_{short} envoyée à {owner_hex[:12]}…")


# ── Réciprocité N1 ───────────────────────────────────────────────────────────

def _n1_follows(pubkey_hex: str) -> set:
    """Liste N1 (comptes suivis) via tools/nostr_get_N1.sh — même source de
    vérité que UPassport services/nostr.py::get_n1_follows(), réimplémentée en
    subprocess puisqu'on est hors du process FastAPI."""
    try:
        proc = subprocess.run(["bash", str(TOOLS / "nostr_get_N1.sh"), pubkey_hex],
                              capture_output=True, text=True, timeout=60)
        if proc.returncode != 0:
            return set()
        return {l.strip() for l in proc.stdout.splitlines() if l.strip()}
    except Exception as exc:
        _log(f"WARN: nostr_get_N1.sh({pubkey_hex[:12]}…) : {exc}")
        return set()


def _is_reciprocal(owner_hex: str, friend_hex: str) -> bool:
    """Amitié RÉCIPROQUE : chacun doit suivre l'autre. Un suivi unilatéral ne
    suffit pas — sans quoi n'importe qui pourrait, en suivant le propriétaire,
    se rendre destinataire de ses photos."""
    return friend_hex in _n1_follows(owner_hex) and owner_hex in _n1_follows(friend_hex)


# ── Chiffrement + envoi NIP-17 (§B6) ─────────────────────────────────────────

def _ipfs_get(ipfs_link: str, dest: str) -> bool:
    try:
        proc = subprocess.run(["ipfs", "get", f"/ipfs/{ipfs_link}", "-o", dest],
                              capture_output=True, timeout=180)
        return proc.returncode == 0 and os.path.getsize(dest) > 0
    except Exception as exc:
        _log(f"WARN: ipfs get {ipfs_link[:24]}… : {exc}")
        return False


def _ipfs_add(path: str) -> str:
    try:
        proc = subprocess.run(["ipfs", "add", "-q", path],
                              capture_output=True, text=True, timeout=180)
        if proc.returncode != 0:
            return ""
        return proc.stdout.strip().splitlines()[-1].strip()
    except Exception as exc:
        _log(f"WARN: ipfs add : {exc}")
        return ""


def _guess_mime(path: str) -> str:
    ext = os.path.splitext(path)[1].lower().lstrip(".")
    return {"jpg": "image/jpeg", "jpeg": "image/jpeg", "png": "image/png",
            "gif": "image/gif", "webp": "image/webp", "bmp": "image/bmp"}.get(ext, "image/jpeg")


# ── Cloud chiffré (.ucloud/) — mêmes fichiers, même verrou que ────────────────
# UPassport/services/cloud_storage.py (index.json/keyring.json/.lock en 0600,
# jamais publiés). Ce script relit ces fichiers en lecture seule (clé) et les
# patch (tag) directement — pas d'import cross-projet, juste la même
# convention de chemin et le même verrou flock (le commentaire de
# cloud_storage.py::index_lock l'anticipe explicitement : « protège aussi bien
# les threads du pool a2wsgi que d'éventuels scripts bash [ou Python] »).

def _ucloud_dir(email: str) -> Path:
    return ZEN / "game" / "nostr" / email / ".ucloud"


@contextlib.contextmanager
def _ucloud_lock(email: str, timeout: float = 10.0):
    d = _ucloud_dir(email)
    d.mkdir(parents=True, exist_ok=True)
    lock_file = d / ".lock"
    fd = os.open(str(lock_file), os.O_CREAT | os.O_RDWR, 0o600)
    deadline = time.time() + timeout
    try:
        while True:
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except OSError:
                if time.time() >= deadline:
                    raise TimeoutError(f"ucloud_lock timeout sur {lock_file}")
                time.sleep(0.05)
        yield
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        except OSError:
            pass
        os.close(fd)


def _ucloud_get_key(email: str, cid: str) -> str:
    """Clé AES-256 hex du blob `cid`, lue dans keyring.json. Chaîne vide si absente."""
    keyring_file = _ucloud_dir(email) / "keyring.json"
    try:
        keyring = json.loads(keyring_file.read_text())
    except Exception:
        return ""
    return (keyring.get(cid) or {}).get("key_hex") or ""


def _tag_ucloud_index(email: str, path: str, names: list) -> None:
    """Ajoute les noms reconnus au tableau `tags` de l'entrée `path` dans
    index.json du propriétaire — pas de republication (le cloud chiffré ne
    publie rien sur IPNS, il sert en local, cf. UPassport/CLAUDE.md)."""
    with _ucloud_lock(email):
        index_file = _ucloud_dir(email) / "index.json"
        try:
            idx = json.loads(index_file.read_text())
        except Exception as exc:
            _log(f"WARN: index.json illisible pour {email} : {exc}")
            return

        entry = idx.get("entries", {}).get(path)
        if entry is None:
            _log(f"WARN: entrée {path} absente de index.json — tags non appliqués")
            return

        tags = entry.get("tags") or []
        touched = False
        for name in names:
            if name not in tags:
                tags.append(name)
                touched = True
        if not touched:
            return
        entry["tags"] = tags

        tmp = index_file.with_name(f".{index_file.name}.tmp.{os.getpid()}")
        try:
            tmp.write_text(json.dumps(idx, ensure_ascii=False, indent=2))
            os.chmod(tmp, 0o600)
            os.replace(tmp, index_file)
            os.chmod(index_file, 0o600)
        except Exception as exc:
            _log(f"WARN: écriture index.json : {exc}")
            return
    _log(f"index.json tagué {names} sur {path} ({email})")


def _share_photo(email: str, owner_hex: str, path: str, ipfs_link: str,
                 friends: list) -> list:
    """Chiffre la photo et l'envoie en NIP-17 à chaque ami réciproque.

    Une clé AES-256 NEUVE par (photo, destinataire) : deux amis recevant la
    même photo reçoivent deux blobs distincts, donc ni le relay ni l'un des
    destinataires ne peut relier les deux envois.

    Retourne la liste des noms d'amis effectivement servis.
    """
    sender_nsec = _user_nsec(email)
    if not sender_nsec:
        _log(f"WARN: .secret.nostr illisible pour {email} — aucun partage possible")
        return []

    served = []
    with tempfile.TemporaryDirectory(prefix="faceid_") as tmpdir:
        # `ipfs_link` référence un blob UENC chiffré (source = cloud chiffré,
        # jamais le uDRIVE public) — on relit sa clé dans le keyring local du
        # propriétaire (même fichier que cloud_storage.py) pour le déchiffrer.
        enc_fetch_path = os.path.join(tmpdir, "source.uenc")
        if not _ipfs_get(ipfs_link, enc_fetch_path):
            _log(f"WARN: blob {ipfs_link[:24]}… non récupérable depuis IPFS")
            return []

        source_key = _ucloud_get_key(email, ipfs_link)
        if not source_key:
            _log(f"WARN: clé introuvable dans keyring.json pour {ipfs_link[:24]}… — partage annulé")
            return []
        try:
            clear_bytes = uenc_codec.decrypt_aes256gcm(
                Path(enc_fetch_path).read_bytes(), source_key)
        except Exception as exc:
            _log(f"WARN: déchiffrement source échoué pour {ipfs_link[:24]}… : {exc}")
            return []

        ox_hash = hashlib.sha256(clear_bytes).hexdigest()
        mime = _guess_mime(path)

        for friend in friends:
            name = friend.get("name") or "?"
            friend_hex = friend.get("pubkey") or ""
            if len(friend_hex) != 64:
                continue

            key_hex = os.urandom(32).hex()
            try:
                payload, iv_hex = uenc_codec.encrypt_aes256gcm(clear_bytes, key_hex)
            except Exception as exc:
                _log(f"WARN: chiffrement UENC échoué pour {name} : {exc}")
                continue

            enc_path = os.path.join(tmpdir, f"enc_{friend_hex[:12]}.uenc")
            Path(enc_path).write_bytes(payload)
            x_hash = hashlib.sha256(payload).hexdigest()

            cid = _ipfs_add(enc_path)
            if not cid:
                _log(f"WARN: ipfs add du blob chiffré échoué pour {name}")
                continue

            try:
                proc = subprocess.run(
                    [sys.executable, str(TOOLS / "nostr_send_secure_dm.py"),
                     "--nsec-stdin", friend_hex,
                     "--file-message",
                     "--relay", RELAY,
                     "--ipfs-url", f"/ipfs/{cid}",
                     "--file-type", mime,
                     "--decryption-key", key_hex,
                     "--decryption-nonce", iv_hex,
                     "--x-hash", x_hash,
                     "--ox-hash", ox_hash,
                     "--size", str(len(payload))],
                    input=sender_nsec + "\n", text=True, capture_output=True, timeout=180,
                )
            except Exception as exc:
                _log(f"WARN: envoi NIP-17 à {name} : {exc}")
                continue

            if proc.returncode == 0:
                _log(f"📸 {path} partagée avec {name} ({friend_hex[:12]}…) — CID {cid[:16]}…")
                served.append(name)
            else:
                _log(f"WARN: envoi NIP-17 à {name} refusé : {proc.stderr.strip()[:200]}")

    return served


# ── main ─────────────────────────────────────────────────────────────────────

def main() -> int:
    if len(sys.argv) != 5:
        print("Usage: satellite_face_matcher.py <email> <owner_hex> <path> <ipfs_link>",
              file=sys.stderr)
        return 1
    email, owner_hex, path, ipfs_link = sys.argv[1:5]

    if len(owner_hex) != 64:
        _log(f"ERROR: owner_hex invalide ({owner_hex[:16]}…)")
        return 1

    try:
        result = json.load(sys.stdin)
    except Exception as exc:
        _log(f"ERROR: JSON vision_analysis_result illisible sur stdin : {exc}")
        return 1

    faces = result.get("faces") or []
    if not faces:
        scene = result.get("scene_analysis")
        if isinstance(scene, dict):
            # Aucun visage : le Brain a enchaîné sur inventory_recognition.py
            # (faceid.sh §8.5) — on tague l'entrée avec ce qui a été identifié,
            # exactement comme un nom d'ami pour un visage reconnu.
            names = list(dict.fromkeys(
                [t for t in (scene.get("tags") or []) if t and t not in ("UPlanet", "inventory")]
                + ([scene["name"]] if scene.get("name") else [])
            ))
            if names:
                _tag_ucloud_index(email, path, names)
            _log(f"aucun visage sur {path} — scène : "
                 f"{scene.get('type')}/{scene.get('category')} ({scene.get('name') or '?'})")
        else:
            _log(f"aucun visage détecté sur {path}, pas d'analyse de scène disponible")
        return 0

    try:
        client = _client()
        collection = f"faces_{owner_hex}"
        _ensure_collection(client, collection)
    except Exception as exc:
        _log(f"ERROR: Qdrant indisponible : {exc}")
        return 1

    from qdrant_client import models

    recognized = {}   # friend_hex → {"name":…, "pubkey":…}
    for face in faces:
        embedding = face.get("embedding") or []
        if len(embedding) != FACE_VECTOR_SIZE:
            _log(f"WARN: embedding de dimension {len(embedding)} ≠ {FACE_VECTOR_SIZE} — visage ignoré")
            continue

        try:
            hits = client.query_points(collection_name=collection,
                                       query=embedding, limit=1).points
        except Exception as exc:
            _log(f"WARN: recherche Qdrant échouée : {exc}")
            continue

        best = hits[0] if hits else None
        if best is not None and best.score >= MATCH_THRESHOLD:
            payload = best.payload or {}
            pubkey = payload.get("pubkey")
            name = payload.get("name") or "?"
            if pubkey and len(pubkey) == 64:
                _log(f"visage reconnu : {name} (score {best.score:.3f})")
                recognized[pubkey] = {"name": name, "pubkey": pubkey}
            else:
                # Visage déjà catalogué mais pas encore nommé : on ne recrée
                # SURTOUT pas de point, on relance juste l'invitation à le nommer.
                short = str(name).replace("Inconnu_", "") or "unknown"
                _log(f"visage déjà connu mais anonyme : {name} (score {best.score:.3f})")
                _notify_unknown_face(email, owner_hex, short, path)
            continue

        # Aucun point assez proche (connu OU déjà-inconnu) → nouveau visage.
        point_id, short = _embedding_id(embedding)
        try:
            client.upsert(collection_name=collection, points=[
                models.PointStruct(id=point_id, vector=embedding, payload={
                    "name": f"Inconnu_{short}",
                    "pubkey": None,
                    "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
                }),
            ])
            _log(f"nouveau visage catalogué : Inconnu_{short}")
        except Exception as exc:
            _log(f"WARN: upsert Qdrant échoué : {exc}")
            continue
        _notify_unknown_face(email, owner_hex, short, path)

    if not recognized:
        return 0

    # Réciprocité N1 : chacun doit suivre l'autre.
    friends = []
    for friend_hex, info in recognized.items():
        if friend_hex == owner_hex:
            continue  # le propriétaire sur sa propre photo
        if _is_reciprocal(owner_hex, friend_hex):
            friends.append(info)
        else:
            _log(f"{info['name']} reconnu mais suivi NON réciproque — pas de partage")

    if not friends:
        return 0

    served = _share_photo(email, owner_hex, path, ipfs_link, friends)
    if served:
        _tag_ucloud_index(email, path, served)
    return 0


if __name__ == "__main__":
    sys.exit(main())
