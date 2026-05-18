# Mémoire vectorielle des connaissances WoTx2

## Objectif

Indexer les **documents de formation** (`.md`, `.pdf`) liés aux skills WoTx2
dans Qdrant pour permettre :

- **BRO `#rec <skill>`** — le daemon répond avec des références IPFS classées par pertinence sémantique
- **MineLife Formation** — recherche contextuelle depuis l'onglet Formation
- **Attribution d'auteur** — chaque résultat retourne le CID IPFS + pubkey NOSTR de l'auteur

La collection `knowledge` coexiste avec `codebase` dans le même Qdrant.

---

## Architecture générale

```
┌─────────────────────────────────────────────────────────────────────┐
│                       SOURCES DE DOCUMENTS                          │
│                                                                     │
│  Kind 30504 (NOSTR)   uDRIVE local          Nextcloud / dossier     │
│  r tags → IPFS CID    ~/.zen/game/players/  ~/nextcloud/Astroport/  │
│  + author pubkey       G1PUB/Documents/      (--index-dir)          │
└──────────┬────────────────────┬──────────────────────┬─────────────┘
           │                    │                      │
           ▼                    ▼                      ▼
    IPFS Gateway          Lecture directe          Lecture directe
    /ipfs/<CID>                                   
           │                    │                      │
           └──────────────────────────────────────────┘
                                │
                                ▼
                    knowledge_index.py
                    ┌───────────────────┐
                    │  extract_text()   │  .md → utf-8
                    │  (pdfplumber)     │  .pdf → plumber/PyPDF2
                    │  get_embedding()  │  → nomic-embed-text (Ollama)
                    └───────────────────┘
                                │
                                ▼
                    ┌───────────────────────────────────────┐
                    │        Qdrant collection "knowledge"  │
                    │                                       │
                    │  payload : {                          │
                    │    cid        : "QmXxx..."            │
                    │    title      : "Intro Docker"        │
                    │    type       : "document"            │
                    │    skill      : "docker"              │
                    │    skills     : ["docker","devops"]   │
                    │    author_hex : "abc123..."           │
                    │    event_id   : "def456..."           │
                    │    kind       : 30504                 │
                    │    relay      : "wss://..."           │
                    │    created_at : 1748000000            │
                    │  }                                    │
                    └───────────────────────────────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                    ▼                       ▼
            BRO #rec devops         MineLife Formation
            → /ipfs/QmXxx...        → score + CID + auteur
              (auteur: npub1...)
```

---

## Prérequis

Identiques à [CODEBASE_EMBEDDINGS.md](CODEBASE_EMBEDDINGS.md) :

| Service | Port | Stack |
|---------|------|-------|
| **Qdrant** | 6333 | `docker compose --profile ai up -d` |
| **Ollama** | 11434 | idem |
| **nomic-embed-text** | — | `ollama pull nomic-embed-text` |
| **IPFS** | 8080 | `ipfs daemon` (pour les sources Kind 30504) |

PDF optionnel :
```bash
~/.astro/bin/pip install pdfplumber   # recommandé
# ou
~/.astro/bin/pip install PyPDF2       # fallback
```

---

## Indexation NOSTR (Kind 30504 + Kind 30500 r-tags)

### Comment ça marche

Le relay local accumule les événements NOSTR de toute la constellation via
`backfill_constellation.sh`. Parmi eux, les Kind 30504 (ressources formation)
et les Kind 30500 (définitions de permit avec `r` tags) pointent vers des
fichiers IPFS via le tag `["r", "/ipfs/QmCID...", "document"]`.

`knowledge_index.py --index-nostr` :
1. Interroge le relay (Kind 30504 + 30500, `limit=500`)
2. Pour chaque event, extrait les `r` tags avec un chemin IPFS
3. Télécharge le fichier depuis la gateway locale (`/ipfs/<CID>`)
4. Extrait le texte (`.md` natif, `.pdf` via pdfplumber)
5. Embed avec `nomic-embed-text`, stocke dans Qdrant

Le payload Qdrant contient `author_hex` (pubkey NOSTR de l'auteur de l'event)
et `event_id` — permettant de remonter à l'auteur original.

### Commandes

```bash
# Indexer depuis le relay local (strfry port 7777)
./tools/knowledge_index.sh --index-nostr

# Relay distant
NOSTR_RELAY=wss://relay.copylaradio.com ./tools/knowledge_index.sh --index-nostr

# Vérifier
./tools/knowledge_index.sh --stats
```

### Publier une ressource de formation (Kind 30504)

Depuis MineLife (onglet Formation, bouton "Mes médias") ou en CLI :

```bash
python3 tools/nostr_node_intercom.py publish \
    --nsec  "$NSEC" \
    --kind  30504 \
    --tags  '[["d","training_docker_intro"],["t","docker"],["t","formation"],
              ["r","/ipfs/QmXxx.../intro-docker.pdf","document"],
              ["title","Introduction à Docker"]]' \
    --content '{"skill":"docker","resource_type":"document"}' \
    --relays "ws://localhost:7777"
```

Une fois publié, `knowledge_index.sh --index-nostr` indexera automatiquement
le fichier lors de la prochaine exécution.

---

## Indexation uDRIVE

Le uDRIVE de chaque MULTIPASS contient des documents personnels. Structure
attendue (créée automatiquement à l'installation) :

```
~/.zen/game/players/<G1PUB>/
├── Documents/         ← .md, .pdf personnels
├── Astroport/         ← guides de station
├── Formation/         ← ressources d'apprentissage
└── Skills/            ← notes par skill
    ├── docker/
    │   ├── notes.md
    │   └── tuto.pdf
    └── python/
        └── cheatsheet.md
```

Le skill est déduit du **nom du sous-répertoire** (`Skills/docker/` → skill=`docker`).

```bash
./tools/knowledge_index.sh --index-udrive
```

---

## Indexation d'un répertoire libre (Nextcloud, dossier admin)

```bash
# Dossier Nextcloud admin (compétences partagées de la station)
./tools/knowledge_index.sh --index-dir ~/nextcloud/Astroport \
    --skill astroport

# Répertoire de formations organisées par sous-dossier skill
./tools/knowledge_index.sh --index-dir ~/formations

# Avec attribution d'auteur explicite (pubkey hex du capitaine)
./tools/knowledge_index.sh --index-dir ~/formations \
    --author "$(cat ~/.zen/game/players/.captain/G1PUBKEY/nostr.pub)"
```

L'arborescence recommandée pour un dossier Nextcloud partagé :

```
~/nextcloud/Astroport/
├── linux/
│   ├── debian-install.md
│   └── systemd-guide.pdf
├── docker/
│   └── compose-advanced.md
└── ipfs/
    ├── kubo-config.md
    └── pinning-strategies.pdf
```

---

## Indexation complète (toutes sources)

```bash
# All-in-one
./tools/knowledge_index.sh --all

# Avec reset (recréer la collection)
./tools/knowledge_index.sh --reset
```

---

## Recherche sémantique

```bash
# Recherche libre
./tools/knowledge_index.sh --search "introduction conteneurs docker compose"

# Filtrée par skill
./tools/knowledge_index.sh --search "gestion services" --skill linux

# Output (score<TAB>ref<TAB>auteur<TAB>titre<TAB>skill) :
0.8412  /ipfs/QmXxx...  abc123def456...  Introduction à Docker  docker
0.7643  /ipfs/QmYyy...  9da638f3ff87...  Docker Compose avancé  devops
0.7201  /home/fred/...  (local)          Systemd services       linux
```

### Intégration BRO (`#rec <skill>`)

Le daemon `bro_dm_daemon.sh` intercepte les commandes `#rec <skill>` dans les
DM Kind 4 et interroge Qdrant :

```bash
# Dans bro_dm_daemon.sh (extrait)
_hits=$(./tools/knowledge_index.sh --search "$_skill" --skill "$_skill" \
    2>/dev/null | head -5)

# Formater la réponse
while IFS=$'\t' read -r _score _ref _author _title _skill; do
    _resp+="📚 **${_title}** (${_skill})\n"
    _resp+="   ${_ref}\n"
    [[ -n "$_author" ]] && _resp+="   *(auteur: ${_author:0:16}...)*\n"
done <<< "$_hits"
```

Voir [BRO_RAG_PERSONAL.md](../explanation/BRO_RAG_PERSONAL.md) pour l'architecture
complète du RAG BRO.

### Intégration MineLife (onglet Formation)

`minelife.js` peut appeler la recherche via l'API UPassport (54321) :

```javascript
// Dans minelife.js — chargement des ressources sémantiques
async function searchKnowledge(skill, query) {
    const r = await fetch(`/api/knowledge/search?skill=${skill}&q=${encodeURIComponent(query)}`);
    return r.json();  // [{score, cid, author_hex, title, skill}]
}
```

L'endpoint UPassport `/api/knowledge/search` wrape `knowledge_index.sh --search`.

---

## Format de sortie — Attribution auteur

Chaque résultat de recherche contient :

| Champ | Description | Exemple |
|-------|-------------|---------|
| `score` | Score cosinus [0–1] | `0.8412` |
| `cid` | CID IPFS du document | `QmXxx...` |
| `author_hex` | Pubkey NOSTR hex de l'auteur | `abc123def456...` |
| `title` | Titre du document | `Introduction Docker` |
| `skill` | Skill associé | `docker` |
| `event_id` | Event NOSTR source | `def789...` |
| `kind` | Kind NOSTR source | `30504` |
| `created_at` | Timestamp de publication | `1748000000` |

Pour afficher le profil de l'auteur :
```bash
# Depuis l'event_id, retrouver le profil (Kind 0) de l'auteur
python3 tools/nostr_node_intercom.py query \
    --filter '{"kinds":[0],"authors":["<author_hex>"]}' \
    --relays "ws://localhost:7777" | jq '.[0].content | fromjson | .name'
```

---

## Mise à jour incrémentale

Les Kind 30504 étant des **Replaceable Events** (NIP-33), une mise à jour du
document publie un nouvel event avec le même `d` tag. `knowledge_index.py`
génère un UUID stable basé sur `sha256(event_id:cid)` — le point Qdrant est
donc mis à jour sans doublon à chaque réindexation.

```bash
# Cron quotidien ou hook post-backfill
# Après backfill_constellation.sh, réindexer les nouvelles ressources
./tools/knowledge_index.sh --index-nostr
```

Exemple de hook post-backfill (dans `backfill_constellation.sh`) :
```bash
# En fin de script, si Qdrant disponible :
if curl -sf --max-time 1 "${QDRANT_URL:-http://127.0.0.1:6333}/healthz" &>/dev/null; then
    ~/workspace/AAA/Astroport.ONE/tools/knowledge_index.sh --index-nostr &
fi
```

---

## Différences avec `codebase_index`

| | `codebase` | `knowledge` |
|--|--|--|
| **Collection Qdrant** | `codebase` | `knowledge` |
| **Sources** | Fichiers code du workspace | Kind 30504/30500, uDRIVE, Nextcloud |
| **Format** | `.sh`, `.py`, `.html`, `.js` | `.md`, `.pdf` |
| **Payload** | `path`, `project` | `cid`, `author_hex`, `skill`, `event_id` |
| **Résultat** | `score\tpath` | `score\t/ipfs/CID\tauthor\ttitle\tskill` |
| **Usage** | `issue.sh analyze` | BRO `#rec`, MineLife Formation |
| **Script** | `tools/codebase_index.sh` | `tools/knowledge_index.sh` |

Les deux collections coexistent dans la même instance Qdrant et utilisent
le même modèle `nomic-embed-text`.

---

## Snapshot IPFS (partage constellation)

L'index `knowledge` peut être snapshotté comme `codebase` (via l'API Qdrant
`/collections/knowledge/snapshots`) et partagé entre nœuds. Cela évite à
chaque station de retélécharger et ré-embedder tous les documents IPFS.

```bash
# Snapshot manuel (adapté de codebase_index.sh --snapshot)
curl -sf -H "api-key: $QDRANT_API_KEY" \
    -X POST http://127.0.0.1:6333/collections/knowledge/snapshots \
    | jq -r '.result.name'

# Publier sur IPFS
ipfs add -q /tmp/qdrant_knowledge.snapshot
```

Un `--snapshot` / `--restore` dédié sera ajouté à `knowledge_index.sh` dans
une prochaine version.

---

## Variables d'environnement

| Variable | Défaut | Usage |
|----------|--------|-------|
| `QDRANT_URL` | `http://127.0.0.1:6333` | URL Qdrant |
| `QDRANT_API_KEY` | (depuis `~/.zen/ai-company/.env`) | Authentification |
| `OLLAMA_URL` | `http://localhost:11434` | Ollama |
| `EMBED_MODEL` | `nomic-embed-text` | Modèle d'embedding |
| `IPFS_GATEWAY` | `http://localhost:8080` | Gateway pour télécharger les CIDs |
| `NOSTR_RELAY` | `ws://localhost:7777` | Relay pour Kind 30504/30500 |

---

## Extension — skills non-techniques

Le système est **domain-agnostic** : tout document lié à un skill via Kind 30504
est indexé, quelle que soit la nature du skill :

```bash
# Formation menuiserie (skill = menuiserie)
python3 tools/nostr_node_intercom.py publish \
    --nsec "$NSEC" --kind 30504 \
    --tags '[["t","menuiserie"],["r","/ipfs/QmZzz.../assemblage-tenon.pdf","document"],
             ["title","Assemblage tenon-mortaise"]]' \
    --content '{"skill":"menuiserie"}' \
    --relays "ws://localhost:7777"

# Recherche
./tools/knowledge_index.sh --search "assemblage bois joint" --skill menuiserie
```

Chaque communauté UPlanet contribue ses propres ressources — elles restent
attributées à leur auteur NOSTR et stockées sur IPFS, accessibles à toute
la constellation.
