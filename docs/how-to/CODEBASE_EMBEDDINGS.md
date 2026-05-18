# Mémoire vectorielle du codebase (Qdrant + nomic-embed-text)

## Objectif

Indexer le code source d'UPlanet/Astroport dans une base vectorielle locale (Qdrant)
pour permettre une **découverte sémantique** des fichiers pertinents lors de l'analyse
d'une issue — sans dépendre de la correspondance exacte de mots-clés (grep).

La recherche sémantique comprend : *"carré blanc leaflet"* → trouve `initMap()`, `tileLayer`, les CSS de layout.

L'index peut être **snapshotté sur IPFS** et partagé dans la constellation : un seul nœud indexe, les autres restaurent.

---

## Prérequis

| Service | Port | Stack |
|---------|------|-------|
| **Qdrant** | 6333 | `docker compose --profile ai up -d` |
| **Ollama** | 11434 | idem, ou `ollama serve` |
| **nomic-embed-text** | — | `ollama pull nomic-embed-text` |
| **IPFS** | 8080 / 5001 | `ipfs daemon` (optionnel, pour snapshot) |

---

## Première indexation

```bash
# 1. Démarrer la stack IA
docker compose --profile ai up -d

# 2. Indexer tout le codebase (~5-15 min selon taille)
./tools/codebase_index.sh --index

# 3. Vérifier
./tools/codebase_index.sh --stats
```

Output attendu :
```json
{
  "collection": "codebase",
  "points_count": 699,
  "vectors_count": 0,
  "status": "green",
  "vector_size": 768,
  "embed_model": "nomic-embed-text"
}
```

> `vectors_count` reste à 0 : Qdrant construit l'index HNSW en différé (normal).
> La recherche fonctionne dès que `points_count > 0`.

---

## Mise à jour incrémentale

Après modification de fichiers, réindexer uniquement les fichiers dont le `mtime` a changé :

```bash
./tools/codebase_index.sh --incremental
```

À automatiser via cron ou hook git post-commit :
```bash
# .git/hooks/post-commit
#!/bin/bash
~/workspace/AAA/Astroport.ONE/tools/codebase_index.sh --incremental &
```

---

## Recherche sémantique

```bash
# Recherche directe
./tools/codebase_index.sh --search "carte leaflet carré blanc tuiles manquantes"

# Output : score<TAB>path (trié par pertinence)
0.8821  UPlanet/earth/g1.html
0.7643  UPlanet/earth/common.js
0.7201  Astroport.ONE/tools/make_NOSTRCARD.sh
```

Dans `issue.sh analyze`, Qdrant est interrogé en priorité. Si indisponible, fallback sur le grep par fréquence de mots-clés.

---

## Snapshot IPFS (partage constellation)

Le nœud maître publie l'index sur IPFS :

```bash
./tools/codebase_index.sh --snapshot
# → Snapshot IPFS : QmXxxxx...
# → CID mémorisé dans .codebase_index.cid
```

Les nœuds secondaires restaurent depuis le CID :

```bash
./tools/codebase_index.sh --restore QmXxxxx...
# Qdrant récupère le snapshot directement via la gateway IPFS locale
```

Le CID peut être publié dans un kind NOSTR ou dans `12345.json` (`capacities.codebase_index`).

---

## Répertoires indexés

| Répertoire | Extensions |
|------------|------------|
| `Astroport.ONE/` | `.sh` `.py` `.html` `.js` |
| `UPlanet/earth/` | `.html` `.js` `.css` |
| `UPassport/` | `.py` |
| `NIP-101/relay.writePolicy.plugin/` | `.sh` |

Exclus automatiquement : `dist/`, `build/`, `node_modules/`, `__pycache__/`, `.git/`, `_DOCKER/`.

---

## Variables d'environnement

| Variable | Défaut | Usage |
|----------|--------|-------|
| `QDRANT_URL` | `http://localhost:6333` | URL de l'API Qdrant |
| `OLLAMA_URL` | `http://localhost:11434` | URL d'Ollama |
| `EMBED_MODEL` | `nomic-embed-text` | Modèle d'embedding |
| `IPFS_GATEWAY` | `http://localhost:8080` | Gateway IPFS pour restore |
| `CODEBASE_ROOT` | `~/workspace/AAA` | Racine du workspace |

---

## Intégration install (mode dev / --profile ai)

Ajouter dans `install/install-ai-company.docker.sh` ou `install/setup/setup.sh` :

```bash
# Indexation initiale du codebase (mode dev uniquement)
if [[ "${INSTALL_MODE:-}" == "dev" ]] && \
   curl -sf http://localhost:6333/health &>/dev/null; then
    echo "[setup] Indexation vectorielle du codebase..."
    "${MY_PATH}/tools/codebase_index.sh" --incremental &
fi
```

---

## Utilisation dans MINELIFE

La recherche sémantique peut être utilisée pour le crafting de compétences WoTx2 :
chercher les fichiers liés à une compétence donnée (e.g. *"authentification NOSTR NIP-42"*)
pour contextualiser les quêtes et proposer les modules de code à explorer.

Voir : [MINELIFE.md](MINELIFE.md)
