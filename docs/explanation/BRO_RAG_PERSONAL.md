# BRO — Assistant IA Personnel RAG

## Concept

Chaque station Astroport.ONE offre à ses MULTIPASS un assistant IA **personnalisé et souverain** — hébergé localement, sans aucune donnée envoyée à l'extérieur.

Lorsqu'un utilisateur pose une question à son NODE via un **DM NOSTR (kind 4)**, le NODE interroge deux sources de contexte avant de construire sa réponse :

1. **La base de connaissance globale** de la station (`nextcloud_kb`), alimentée par les documents NextCloud/Astroport ou — si NextCloud est absent — les fichiers `docs/*.md` locaux.
2. **La mémoire personnelle** de l'utilisateur (`memory_{hex}`), construite à partir de ses `#rec` (kind 1 public ou DM direct).

Le tout repose sur Ollama (LLM souverain) et Qdrant (base vectorielle locale). Aucun cloud, aucune API commerciale.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    CAPTURE DES SOUVENIRS                        │
│                                                                 │
│  Via kind 1 public  :  #rec Mon projet est une ferme bio        │
│  Via DM au NODE     :  #rec Mon projet est une ferme bio        │
│       │                                                         │
│       ▼                                                         │
│  short_memory.py <event_json> <lat> <lon> <slot> <user_id>      │
│       │                                                         │
│       ├──► ~/.zen/flashmem/{user_id}/slot{N}.json               │
│       └──► Qdrant : collection memory_{user_hex[:16]}           │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    RÉPONSE AUX QUESTIONS                        │
│                                                                 │
│  Utilisateur envoie DM kind 4 au NODE                           │
│       ▼                                                         │
│  NIP-101/filter/4.sh → bro_dm_queue/                            │
│       ▼                                                         │
│  bro_dm_daemon.sh (inotifywait)                                 │
│       ▼                                                         │
│  nextcloud_bro_sync.sh --query "$question" --user "$sender"     │
│       │                                                         │
│       ├──► Qdrant search nextcloud_kb (top 3)                   │
│       │    ↳ Fallback : grep docs/*.md si KB vide               │
│       ├──► Qdrant search memory_{sender[:16]} (top 3)           │
│       ▼                                                         │
│  Prompt combiné → Ollama → Réponse DM NIP-44 chiffrée           │
└─────────────────────────────────────────────────────────────────┘
```

---

## Utilisation pratique — DM au NODE

### Premier contact : message de bienvenue

À l'activation du daemon, le NODE envoie automatiquement un **DM de bienvenue** à chaque MULTIPASS hébergé sur la station (une seule fois, tracé dans `~/.zen/flashmem/bro_dm_welcomed.txt`). Ce message présente les commandes disponibles.

### Commandes disponibles par DM

Envoyez un DM chiffré (NIP-04) à la clé publique du NODE. Le NODE répond toujours par DM chiffré.

---

#### Question libre → réponse IA

```
Quels services sont disponibles sur cette station ?
Comment fonctionne le portefeuille ẐEN ?
Explique-moi le protocole UPlanet.
```

Le NODE interroge la base de connaissance + vos mémoires personnelles et répond avec Ollama.

---

#### Question libre → réponse IA (slot 0 par défaut)

```
Quels services sont disponibles sur cette station ?
```
→ Le NODE répond en utilisant la KB globale + **slot 0** (mémoire générale).

#### Sélectionner un ou plusieurs slots de mémoire pour la réponse

Ajoutez les tags `#N` dans votre message pour préciser quels slots utiliser comme contexte :

```
Quelles plantes couvre-sol recommandes-tu ? #1
```
→ Contexte : slot 1 uniquement.

```
Quel modèle Ollama me convient ? #1 #5
```
→ Contexte : slots 1 **et** 5 combinés (ferme + budget, par exemple).

```
Quels sont mes projets en cours ? #1 #2 #3
```
→ Contexte : slots 1, 2 et 3 combinés.

Sans aucun `#N`, le **slot 0** (contexte général) est utilisé par défaut.

---

#### `#rec` — Mémoriser du contexte personnel

```
#rec Mon projet est une ferme biologique en Bretagne.
```
→ Mémorisé dans le **slot 0** (accessible à tous).

```
#rec #2 Je préfère les réponses courtes avec des exemples.
```
→ Mémorisé dans le **slot 2** (sociétaires). Le numéro de slot est le tag `#N` séparé.

```
#rec #1 Sol argilo-limoneux, 3 ha. #bro Quelles cultures recommandes-tu ?
```
→ Mémorise dans slot 1 ET répond immédiatement avec ce contexte.

**Slots disponibles :**

| Slot | Accès | Usage recommandé |
|------|-------|-----------------|
| 0 | Tous les MULTIPASS hébergés | Contexte général, préférences |
| 1–12 | Sociétaires CopyLaRadio uniquement | Projets thématiques, notes, agenda |

---

#### `#mem` — Consulter les mémoires enregistrées

```
#mem
```
→ Liste tous vos slots non vides avec un aperçu du dernier message.

```
#mem #2
```
→ Affiche les 5 derniers messages du slot 2.

---

#### `#reset` — Effacer des mémoires

```
#reset
```
→ Efface tous vos slots (0–12).

```
#reset #2
```
→ Efface uniquement le slot 2.

---

### Exemples de sessions complètes

**Session 1 — Mémoriser et interroger avec sélection de slot :**

```
DM → NODE :  #rec #1 Ferme bio en Bretagne, cultures maraîchères, sol argilo-limoneux.
NODE → DM :  💾 Mémorisé dans slot 1 (71 caractères).

DM → NODE :  #rec #5 Budget infrastructure : 500 EUR/mois.
NODE → DM :  💾 Mémorisé dans slot 5 (38 caractères).

DM → NODE :  Quel équipement d'irrigation me recommandes-tu ? #1 #5
NODE → DM :  En tenant compte de votre ferme bio en Bretagne et d'un budget
             de 500 EUR/mois, je recommande un système goutte-à-goutte...
```

**Session 2 — Mémoriser ET interroger en une commande :**

```
DM → NODE :  #rec #3 Projet apiculture, 10 ruches. #bro Quels miels produire en Bretagne ?
NODE → DM :  💾 Mémorisé dans slot 3 (37 caractères).
             En Bretagne, avec 10 ruches, le miel de sarrasin...
```

**Session 3 — Gérer ses mémoires :**

```
DM → NODE :  #mem
NODE → DM :  🧠 Mémoires enregistrées :
               Slot 1 (3 msg) : Ferme bio en Bretagne, cultures maraîchères…
               Slot 3 (1 msg) : Projet apiculture, 10 ruches…
               Slot 5 (1 msg) : Budget infrastructure : 500 EUR/mois…

DM → NODE :  #reset #5
NODE → DM :  🗑️ Slot 5 effacé.
```

---

## Utilisation pratique — Base de connaissance NextCloud

### Alimenter la KB (administrateur)

```bash
# 1. Activer le profil IA Docker
cd docker/
docker compose --profile ai up -d
# → Qdrant, Open-WebUI (Ollama peut être local ou via tunnel IPFS P2P)

# 2. Vérifier les services
bash IA/nextcloud_bro_sync.sh --status

# 3. Indexer depuis NextCloud (si configuré)
bash IA/nextcloud_bro_sync.sh --full

# 4. Sans NextCloud — indexation des docs locaux
bash IA/nextcloud_bro_sync.sh --index-local docs/
# OU : le sync incrémental le fait automatiquement si NC_PASSWORD est absent

# 5. Tester une requête
bash IA/nextcloud_bro_sync.sh --query "Comment fonctionne UPlanet ?"
```

> **Ollama** peut être :
> - Installé en **systemd** sur la station locale (bare metal, GPU)
> - Fourni via un **tunnel IPFS P2P Dragon** vers un Brain Node de la constellation (Power-Score ≥ 41)
> - Accessible via `ollama.me.sh` (auto-détection swarm)
>
> `nextcloud_bro_sync.sh` tente la cascade automatiquement — pas de configuration manuelle requise.

### Fallback automatique si NextCloud est absent

Si `NC_PASSWORD` n'est pas configuré, `nextcloud_bro_sync.sh` **indexe automatiquement** les fichiers `docs/*.md` de la station lors de la sync. De plus, si la collection Qdrant est vide lors d'une question, une recherche textuelle (`grep`) dans `docs/` est utilisée comme contexte de secours avant d'interroger Ollama.

**Ordre de priorité pour le contexte global :**
1. Qdrant `nextcloud_kb` (si des documents sont indexés)
2. Grep dans `$MY_PATH/../docs/` (fallback si KB vide)

### Variables d'environnement

| Variable | Défaut | Description |
|----------|--------|-------------|
| `NC_WEBDAV_URL` | `http://127.0.0.1:8001/remote.php/dav/files` | URL WebDAV NextCloud |
| `NC_USERNAME` | `admin` | Utilisateur NextCloud |
| `NC_COLLECTION` | `Astroport` | Dossier NextCloud à indexer |
| `OLLAMA_URL` | `http://127.0.0.1:11434` | URL Ollama (local ou tunnel P2P) |
| `QDRANT_URL` | `http://127.0.0.1:6333` | URL Qdrant |
| `OLLAMA_MODEL` | `gemma3:latest` | Modèle LLM pour la synthèse (recommandé : `gemma3:12b`) |

---

## Dégradation gracieuse

| Situation | Comportement |
|-----------|-------------|
| Ollama absent (question) | Fallback : meilleur extrait Qdrant brut |
| Qdrant vide (question) | Fallback : grep dans `docs/*.md` |
| NextCloud absent (sync) | Fallback : indexation auto de `docs/*.md` |
| Ollama absent (embed `#rec`) | `_upsert_to_qdrant()` silencieux, flashmem écrit quand même |
| Collection `memory_{hex}` absente | Recherche ignorée, contexte global seul |
| Utilisateur non hébergé (`#rec` DM) | DM d'erreur explicite, mémoire non sauvegardée |

---

## Composants techniques

| Fichier | Rôle |
|---------|------|
| `IA/nextcloud_bro_sync.sh` | Sync NextCloud/docs → Qdrant + requête RAG combinée |
| `IA/bro_dm_daemon.sh` | Daemon DM kind 4 : `#rec`, `#mem`, `#reset`, BRO |
| `IA/short_memory.py` | Capture `#rec` → flashmem + Qdrant |
| `NIP-101/filter/1.sh` | Filtre strfry kind 1, détecte `#rec` public |
| `NIP-101/filter/4.sh` | Filtre strfry kind 4, enqueue DMs adressés au NODE |

### Collections Qdrant

| Collection | Portée | Source | Accès |
|------------|--------|--------|-------|
| `nextcloud_kb` | **Partagée** — une seule pour toute la station | NextCloud WebDAV ou `docs/*.md` | Tous les MULTIPASS |
| `memory_{user_hex[:16]}` | **Privée** — une par MULTIPASS hébergé | `short_memory.py` via `#rec` | NODE seul (DM chiffré) |

Chaque MULTIPASS a donc **sa propre collection Qdrant** nommée d'après les 16 premiers caractères de sa clé publique NOSTR hexadécimale. Ces collections sont créées à la demande lors du premier `#rec` et ne sont jamais partagées entre utilisateurs.

Exemple pour deux utilisateurs :
```
nextcloud_kb          ← KB commune de la station
memory_a1b2c3d4e5f6a7b8  ← mémoire de alice@example.com
memory_9f8e7d6c5b4a3210  ← mémoire de bob@example.com
```

### Modèle LLM et paramètres question.py

Les réponses BRO passent par `IA/question.py`. Les paramètres fixés par défaut :

| Cas d'usage | `--model` | `--ctx` | `--max-tokens` |
|-------------|-----------|---------|---------------|
| Conversation libre (question `#bro`) | `gemma3:latest` | 8192 | 1024 |
| Résumé URL (`#url`) | `gemma3:latest` | 8192 | 2048 |
| Skill pédagogique (`[ctx:<skill>]`) | `gemma3:latest` | 8192 | 2048 |

Paramètres supplémentaires disponibles : `--temperature`, `--top-p`, `--repeat-penalty`.

Sur **alienware** (GTX 1070, 8 Go VRAM) avec orpheus TTS actif (~5 Go), préférer
`llama3.2:latest` (2 Go) si la VRAM est saturée. Sur **sagittarius** (RTX 3090, 24 Go),
`gemma3:latest` tient confortablement à côté de comfyui.

### Cascade Ollama

Si Ollama local est absent, le daemon tente :
1. `ollama.me.sh` — tunnel P2P IPFS vers Ollama swarm (20s timeout)
2. `astrosystemctl connect ollama` — Brain Node de la constellation (Power-Score ≥ 41)

---

## Vie privée et souveraineté

- Les mémoires restent sur la station. Aucune donnée personnelle n'est envoyée à l'extérieur.
- L'embedding est généré localement par Ollama (`nomic-embed-text`).
- Qdrant tourne en local (Docker profil `ai`) ou bare-metal.
- Les souvenirs `#rec` kind 1 sont publiés volontairement sur NOSTR (public). Les `#rec` DM restent privés (chiffrés NIP-04).
