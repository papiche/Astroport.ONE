# Transformer sa station en Centre d'Apprentissage IA avec Nextcloud

**Public :** Capitaine ayant installé Astroport.ONE avec les profils `nextcloud` et `ai-company`.
**Résultat :** Les documents déposés dans Nextcloud sont interrogeables par `#BRO #rec <skill>` depuis n'importe quel client NOSTR de la constellation.

**Durée estimée :** 30–60 minutes (hors temps de téléchargement des modèles IA).

---

## Prérequis

### Services requis

```bash
# Vérifier que Nextcloud, Qdrant et Ollama tournent
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "nextcloud|qdrant|ollama|open-webui"
```

Si des services manquent, relancer avec les profils complets :

```bash
cd docker/
docker compose --profile cloud --profile ai up -d
```

### Modèle d'embedding

```bash
# Télécharger le modèle d'embedding (274 Mo — une seule fois)
docker exec -it open-webui ollama pull nomic-embed-text

# Vérifier
docker exec -it open-webui ollama list | grep nomic
```

---

## Étape 1 — Créer la structure de dossiers dans Nextcloud

Connectez-vous à votre Nextcloud local (`https://cloud.VOTRE_DOMAINE`) avec le compte admin.

Créez la structure suivante (un sous-dossier = un skill) :

```
Astroport/
├── linux/
│   ├── debian-install.md
│   └── systemd-guide.pdf
├── docker/
│   └── compose-advanced.md
├── ipfs/
│   ├── kubo-config.md
│   └── pinning-strategies.pdf
└── astroport/
    └── guide-capitaine.md
```

**Règle :** le nom du sous-dossier devient automatiquement le `skill` dans Qdrant.
Utilisez des noms en minuscules sans espaces ni accents (`menuiserie`, `permaculture`, `mediation`).

Via l'interface Nextcloud ou en ligne de commande :

```bash
# Depuis le serveur, via le chemin Nextcloud de l'admin
NEXTCLOUD_DATA="$HOME/nextcloud/admin/files"   # adapter selon l'installation
mkdir -p "$NEXTCLOUD_DATA/Astroport/linux"
mkdir -p "$NEXTCLOUD_DATA/Astroport/docker"
mkdir -p "$NEXTCLOUD_DATA/Astroport/ipfs"
```

---

## Étape 2 — Déposer vos documents de formation

Copiez vos fichiers `.md` ou `.pdf` dans les sous-dossiers correspondants.

```bash
# Exemples
cp ~/mes-notes/intro-linux.md     "$NEXTCLOUD_DATA/Astroport/linux/"
cp ~/mes-docs/guide-docker.pdf    "$NEXTCLOUD_DATA/Astroport/docker/"
```

**Formats supportés :** `.md` (Markdown), `.pdf` (via pdfplumber).

---

## Étape 3 — Lancer l'indexation

```bash
cd ~/.zen/Astroport.ONE

# Indexer le dossier Nextcloud de l'admin
./tools/knowledge_index.sh --index-dir ~/nextcloud/admin/files/Astroport

# Vérifier le résultat
./tools/knowledge_index.sh --stats
```

Vous devriez voir :
```
{ "collection": "knowledge", "points_count": N, "status": "green" }
```

où `N` est le nombre de chunks de documents indexés.

---

## Étape 4 — Tester avec #BRO

Depuis n'importe quel client NOSTR connecté à votre relay (Coracle, Damus, Amethyst…), envoyez un DM à votre station :

```
#rec linux
```

BRO devrait répondre avec les références de vos documents :

```
📚 debian-install.md (linux)
   /ipfs/QmXxx...
   *(auteur: votre_npub16...)*

📚 systemd-guide.pdf (linux)
   /ipfs/QmYyy...
   *(auteur: votre_npub16...)*
```

---

## Étape 5 (optionnel) — Indexer les ressources NOSTR de la constellation

```bash
# Indexer aussi les Kind 30504 publiés par les membres de la constellation
./tools/knowledge_index.sh --index-nostr

# Tout en une fois (Nextcloud + NOSTR + uDRIVE)
./tools/knowledge_index.sh --all
```

---

## Mise à jour automatique (cron)

Pour que la mémoire reste fraîche après chaque backfill :

```bash
# Ajouter à la crontab
crontab -e

# Réindexation quotidienne à 3h du matin
0 3 * * * cd ~/.zen/Astroport.ONE && ./tools/knowledge_index.sh --index-nostr >> ~/.zen/logs/knowledge_index.log 2>&1
```

---

## Résultat attendu

Votre station est maintenant un **hub de savoir souverain** :
- Les documents Nextcloud sont interrogeables sémantiquement par tous vos utilisateurs via BRO
- Les ressources de formation de la constellation N² sont intégrées à votre index local
- Chaque résultat de recherche retourne le CID IPFS + l'auteur NOSTR original

---

## Étapes suivantes

- [Comprendre la philosophie MineLife](../explanation/minelife_wikipedia_wot.md)
- [Publier des ressources Kind 30504 pour la constellation](../how-to/KNOWLEDGE_EMBEDDINGS.md)
- [Utiliser l'interface MineLife pour certifier des compétences](../how-to/MINELIFE.md)
