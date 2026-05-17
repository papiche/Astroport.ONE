# Plan de Migration : rnostr + Recherche Sémantique (Qdrant)

Ce document détaille le plan d'intégration pour remplacer `strfry` par `rnostr` et ajouter des capacités de recherche sémantique via `Qdrant` et un modèle d'embedding local.

## Objectifs
- **Performance** : Remplacer l'exécution de scripts bash par événement de `strfry` par des extensions Rust natives dans `rnostr`.
- **Recherche Sémantique** : Permettre des requêtes NIP-50 intelligentes (UMAP) basées sur le sens et la géolocalisation.
- **Déploiement Local** : Faire tourner l'inférence d'embedding (Nomic) sur du matériel modeste (CPU, Raspberry Pi 4) via `candle`.

---

## Phase 1 — Remplacement de strfry par rnostr

Le fork `papiche/rnostr` (branche zen) sera utilisé pour conserver l'interface `write_policy` tout en bénéficiant de la rapidité de Rust.

### Actions :
1. **Configuration de rnostr** :
   Créer le fichier de configuration `rnostr.toml` pour définir les limites et pointer vers l'extension de politique d'écriture.
   ```toml
   [extensions]
   write_policy = "~/.zen/rnostr/extensions/uplanet_policy"

   [limits]
   max_conn = 1000
   max_event_size = 65536
   ```

2. **Migration des Filtres (Hot-path)** :
   - Réécrire la logique d'autorisation principale (`amisOfAmis.txt` et `KEY_DIR/*/HEX`) en Rust natif (struct `WotChecker`).
   - Utiliser `inotify` pour surveiller les changements du fichier `amisOfAmis.txt` en mémoire.
   - *Note* : Conserver temporairement l'exécution bash pour les kinds complexes (kind 1 BRO/BOT, kind 7 paiements G1) via un `plugin_runner`.

---

## Phase 2 — Création du Worker d'Embedding (`embed-worker`)

Un binaire sidecar en Rust (`embed-worker`) sera chargé de générer les embeddings et de les stocker dans Qdrant.

### Actions :
1. **Développement du Worker** :
   - Utiliser `candle-transformers` pour charger le modèle `nomic-embed-text-v1` (GGUF quantifié Q4).
   - Écouter les événements via un channel MPSC (trait `EventExtension` de rnostr).
   - Formater le texte avec le préfixe obligatoire : `search_document: {content} {tags}`.

2. **Intégration Qdrant** :
   - Upserter les vecteurs (768 dimensions) dans la collection `nostr_events`.
   - Inclure les métadonnées utiles dans le payload : `pubkey`, `kind`, `created_at`, `geo` (tag "g"), et `is_uplanet`.


3. **Initialisation de la Base Vectorielle** :
   Créer la collection Qdrant au démarrage :
   ```bash
   curl -X PUT http://localhost:6333/collections/nostr_events \
     -H 'Content-Type: application/json' \
     -d '{
       "vectors": {"size": 768, "distance": "Cosine"},
       "hnsw_config": {"m": 16, "ef_construct": 64},
       "optimizers_config": {"indexing_threshold": 1000}
     }'
   ```

Pour éviter les mauvaises surprises, je te conseille de vérifier :

    Que le script Rust/candle configure bien la dimension 768 dans Qdrant, et que tu n’appliques pas de “Matryoshka truncation” (ex. couper à 512) sans adapter size côté Qdrant.​

    Que tu respectes strictement les préfixes (search_document: pour index, search_query: pour requêtes), sinon les embeddings seront de moins bonne qualité pour tes recherches.

---

## Phase 3 — Recherche NIP-50 et Requêtes Sémantiques UMAP

Permettre à rnostr d'intercepter les requêtes de recherche et de les enrichir avec les résultats de Qdrant.

### Actions :
1. **Extension NIP-50 pour rnostr** :
   - Intercepter les messages `REQ` contenant le champ `search`.
   - Envoyer la requête à `embed-worker` avec le préfixe `search_query:`.
   - Interroger Qdrant avec le vecteur résultant (seuil de similarité cosinus ~0.78).

2. **Filtrage Hybride** :
   - Appliquer les filtres Qdrant (ex: rayon géographique via `Condition::geo_radius`, statut `is_uplanet`).
   - Joindre les résultats vectoriels aux filtres REQ classiques de Nostr (`since`, `until`, `kinds`, auteurs).
   - Retourner les événements combinés au client.

---

## Phase 4 — Intégration Docker et Scripts d'Installation

Mettre à jour l'infrastructure de déploiement pour inclure les nouveaux services.

### Actions :
1. **Mise à jour de `docker-compose.yml`** :
   Ajouter les services `rnostr`, `embed-worker`, et `qdrant`.
   ```yaml
   services:
     rnostr:
       build: ~/.zen/rnostr
       ports: ["8888:7777"]
       volumes:
         - ~/.zen/game/nostr:/data/nostr:ro
         - ~/.zen/strfry/amisOfAmis.txt:/data/amisOfAmis.txt:ro
         - ./rnostr.toml:/etc/rnostr/rnostr.toml:ro

     embed-worker:
       build: ~/.zen/embed-worker
       environment:
         - QDRANT_URL=http://qdrant:6333
         - MODEL_PATH=/models/nomic-embed-text-v1.Q4_K_M.gguf
       volumes:
         - ./models:/models:ro
       depends_on: [qdrant]

     qdrant:
       image: qdrant/qdrant:latest
       ports: ["6333:6333"]
       volumes:
         - qdrant-data:/qdrant/storage
   ```

2. **Script d'Installation (`install_rnostr_semantic.sh`)** :
   - Créer un script pour télécharger le modèle GGUF via IPFS (swarm UPlanet).
   - Initialiser la collection Qdrant.
   - Lancer le `docker-compose`.
   - Intégrer l'appel à ce script dans le `install.sh` principal, après l'installation de strfry.

---

## Phase 5 — Rétro-indexation et Points de Vigilance

### Actions :
1. **Script de Backfill (`backfill.sh`)** :
   - Créer un script pour lire le dump des événements existants de strfry.
   - Injecter ces événements en batch (par fenêtres de 500) dans Qdrant via `embed-worker` pour indexer l'historique.

2. **Points de Vigilance (Sécurité & Synchronicité)** :
   - **Validation Ğ1 (`squid_metadata`)** : Ce champ doit impérativement rester **synchrone** dans le hook rnostr. Ne pas le déporter en asynchrone pour garantir qu'aucun événement non validé ne soit accepté par le relais.
