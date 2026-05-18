# Mémoire vectorielle des connaissances WoTx2 — Recettes

> Pour la vision d'ensemble, voir [explanation/minelife_wikipedia_wot.md](../explanation/minelife_wikipedia_wot.md).
> Pour configurer une station hub de A à Z, voir [tutorials/setup_learning_hub.md](../tutorials/setup_learning_hub.md).
> Pour le schéma Qdrant et la spec Kind 30504, voir [reference/NOSTR_EVENTS_REFERENCE.md](../reference/NOSTR_EVENTS_REFERENCE.md).

---

## Prérequis

| Service | Port | Commande |
|---------|------|----------|
| Qdrant | 6333 | `docker compose --profile ai up -d` |
| Ollama + nomic-embed-text | 11434 | `ollama pull nomic-embed-text` |
| IPFS | 8080 | `ipfs daemon` |

```bash
# PDF (optionnel mais recommandé)
~/.astro/bin/pip install pdfplumber
```

---

## Comment indexer les documents Nextcloud

```bash
# Répertoire Nextcloud par skill (sous-dossier = skill)
./tools/knowledge_index.sh --index-dir ~/nextcloud/admin/files/Astroport

# Avec skill explicite (pour un dossier plat)
./tools/knowledge_index.sh --index-dir ~/formations --skill linux

# Avec attribution d'auteur explicite (pubkey hex du capitaine)
./tools/knowledge_index.sh --index-dir ~/formations \
    --author "$(cat ~/.zen/game/players/.captain/G1PUBKEY/nostr.pub)"
```

**Structure recommandée :**
```
~/nextcloud/Astroport/
├── linux/       ← skill="linux"
├── docker/      ← skill="docker"
└── ipfs/        ← skill="ipfs"
```

---

## Comment indexer les ressources NOSTR (Kind 30504)

```bash
# Depuis le relay local strfry (port 7777)
./tools/knowledge_index.sh --index-nostr

# Depuis un relay distant
NOSTR_RELAY=wss://relay.copylaradio.com ./tools/knowledge_index.sh --index-nostr
```

---

## Comment indexer le uDRIVE personnel

```bash
./tools/knowledge_index.sh --index-udrive
```

Le skill est déduit du sous-répertoire : `~/.zen/game/players/<G1PUB>/Skills/docker/` → skill=`docker`.

---

## Comment tout indexer en une fois

```bash
./tools/knowledge_index.sh --all
```

---

## Comment forcer la réindexation complète

```bash
# Vide la collection et réindexe tout
./tools/knowledge_index.sh --reset
./tools/knowledge_index.sh --all
```

---

## Comment attribuer un auteur spécifique à un dossier

```bash
./tools/knowledge_index.sh --index-dir ~/formations \
    --author "<pubkey_hex_64_chars>"
```

Sans `--author`, l'auteur est déduit :
- Du champ `pubkey` de l'event NOSTR (si source Kind 30504)
- De la clé NOSTR du capitaine (si source Nextcloud/uDRIVE)

---

## Comment publier une ressource (Kind 30504) en CLI

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

Après publication, relancer `--index-nostr` pour intégrer la ressource dans Qdrant.

---

## Comment tester la recherche sémantique

```bash
# Recherche libre
./tools/knowledge_index.sh --search "introduction conteneurs docker compose"

# Filtrée par skill
./tools/knowledge_index.sh --search "gestion services" --skill linux

# Sortie : score<TAB>ref<TAB>auteur<TAB>titre<TAB>skill
0.8412  /ipfs/QmXxx...  abc123def456...  Introduction Docker  docker
```

---

## Comment vérifier l'état de la collection

```bash
./tools/knowledge_index.sh --stats
# → { "collection": "knowledge", "points_count": N, "status": "green" }
```

---

## Variables d'environnement

| Variable | Défaut | Usage |
|----------|--------|-------|
| `QDRANT_URL` | `http://127.0.0.1:6333` | URL Qdrant |
| `QDRANT_API_KEY` | (depuis `~/.zen/ai-company/.env`) | Auth |
| `OLLAMA_URL` | `http://localhost:11434` | Ollama |
| `EMBED_MODEL` | `nomic-embed-text` | Modèle d'embedding |
| `IPFS_GATEWAY` | `http://localhost:8080` | Gateway pour les CIDs |
| `NOSTR_RELAY` | `ws://localhost:7777` | Relay strfry local |
