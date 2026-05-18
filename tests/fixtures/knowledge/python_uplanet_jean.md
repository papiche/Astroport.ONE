# Python pour l'écosystème UPlanet

**Auteur** : jean (support+jean@qo-op.com)  
**Skill** : python  
**Niveau** : X1 — Fondamentaux  

---

## Python dans UPlanet

UPassport (l'API centrale d'UPlanet) est entièrement en Python/FastAPI.
Les outils d'analyse, d'embedding et de cryptographie NOSTR sont aussi en Python.
Maîtriser Python, c'est pouvoir étendre et comprendre le cœur de l'écosystème.

---

## 1. L'environnement virtuel Astroport

```bash
# Activer le venv
source ~/.astro/bin/activate

# Ou appeler directement
~/.astro/bin/python3 script.py
~/.astro/bin/pip install <package>
```

Les packages déjà installés : `fastapi`, `requests`, `cryptography`,
`coincurve`, `bech32`, `websocket-client`, `PyNaCl`.

---

## 2. Appeler l'API UPassport (54321)

```python
import requests

BASE = "http://localhost:54321"

# Créer ou récupérer un MULTIPASS
r = requests.post(f"{BASE}/api/g1nostr", json={
    "salt": "jean",
    "pepper": "jean",
    "email": "support+jean@qo-op.com",
    "lat": "43.6",
    "lon": "1.4"
})
print(r.json())
```

---

## 3. Crypto NOSTR — clés et signatures

```python
# Depuis tools/keygen (subprocess)
import subprocess, json

def get_nostr_keys(salt: str, pepper: str) -> dict:
    """Dérive npub et nsec depuis salt/pepper (déterministe)."""
    npub = subprocess.run(
        ["./tools/keygen", "-t", "nostr", salt, pepper],
        capture_output=True, text=True
    ).stdout.strip()
    nsec = subprocess.run(
        ["./tools/keygen", "-t", "nostr", "-s", salt, pepper],
        capture_output=True, text=True
    ).stdout.strip()
    return {"npub": npub, "nsec": nsec}

keys = get_nostr_keys("jean", "jean")
print(keys)
```

---

## 4. Lire et écrire sur IPFS

```python
import requests

GATEWAY = "http://localhost:8080"
API = "http://localhost:5001"

def ipfs_add(content: bytes, filename: str = "data.json") -> str:
    """Ajoute du contenu sur IPFS, retourne le CID."""
    r = requests.post(
        f"{API}/api/v0/add",
        files={"file": (filename, content)},
        params={"pin": "true"}
    )
    return r.json()["Hash"]

def ipfs_get(cid: str) -> bytes:
    """Télécharge un CID depuis la gateway locale."""
    r = requests.get(f"{GATEWAY}/ipfs/{cid}", timeout=30)
    r.raise_for_status()
    return r.content

# Exemple
cid = ipfs_add(b"Bonjour UPlanet !", "hello.txt")
print(f"CID : {cid}")
data = ipfs_get(cid)
print(data.decode())
```

---

## 5. FastAPI — ajouter un endpoint à UPassport

```python
# Dans UPassport/routers/mon_router.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/api/mon_feature", tags=["mon_feature"])

class MonInput(BaseModel):
    skill: str
    level: int = 1

@router.post("/certifier")
async def certifier(data: MonInput):
    if data.level < 1 or data.level > 5:
        raise HTTPException(400, "level doit être entre 1 et 5")
    return {"skill": data.skill, "level": data.level, "status": "certified"}
```

Enregistrer dans `UPassport/54321.py` :
```python
from routers import mon_router
app.include_router(mon_router.router)
```

---

## 6. Exercice — Vérifier un Kind 30503

```python
import json, subprocess, sys

RELAY = "ws://localhost:7777"
INTERCOM = "tools/nostr_node_intercom.py"

def get_certs(author_hex: str, skill: str) -> list:
    """Retourne les Kind 30503 d'un auteur pour un skill donné."""
    filt = json.dumps({
        "kinds": [30503],
        "authors": [author_hex],
        "#t": [skill],
        "limit": 10
    })
    res = subprocess.run(
        [sys.executable, INTERCOM, "query",
         "--filter", filt, "--relays", RELAY],
        capture_output=True, text=True, timeout=15
    )
    if res.returncode == 0:
        return json.loads(res.stdout or "[]")
    return []

# Hexadécimal de jean (déterministe)
JEAN_HEX = "2188e823f9a2905af085af74fa8476b9a444830ffe46efd4a264b8798837b17e"
certs = get_certs(JEAN_HEX, "python")
print(f"jean a {len(certs)} certif(s) python sur le relay local")
```

---

## Ressources complémentaires

- `UPassport/54321.py` — API FastAPI principale
- `Astroport.ONE/tools/nostr_node_intercom.py` — communication NOSTR
- `Astroport.ONE/tools/natools.py` — crypto NaCl (chiffrement)
