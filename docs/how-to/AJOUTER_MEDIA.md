<!-- SPDX-License-Identifier: AGPL-3.0 -->
# Ajouter un média sur UPlanet

`ajouter_media.sh` est le point d'entrée interactif pour publier du contenu sur UPlanet (IPFS + NOSTR).

**Prérequis :** IPFS daemon actif (port 5001), UPassport actif (port 54321), un MULTIPASS enregistré.

---

## Usage

```bash
./ajouter_media.sh [URL] [PLAYER_EMAIL] [CATEGORIE]
```

Sans arguments : mode interactif complet (zenity GUI).

| Argument | Description |
|----------|-------------|
| `URL` | Lien YouTube, URL PDF, ou vide pour sélection fichier |
| `PLAYER_EMAIL` | Email du joueur MULTIPASS (optionnel, sinon sélection GUI) |
| `CATEGORIE` | `Youtube`, `MP3`, `PDF`, `Film`, `Serie`, `Video`, `Vlog`, `IA`, `uDRIVE` |

---

## Catégories

### `Youtube` — Copie de vidéo YouTube
```bash
./ajouter_media.sh "https://youtube.com/watch?v=XXX" player@example.com Youtube
```
- Télécharge via `IA/scrapers/youtube/process_youtube.sh` (max 480p)
- Upload IPFS via `/api/fileupload`
- Publication NOSTR NIP-71 (kind 34235) via `tools/publish_nostr_video.sh`
- Authentification NIP-42 automatique
- En cas de blocage anti-bot : récupération cookie via page UPassport `/cookie`

### `MP3` — Audio depuis YouTube
```bash
./ajouter_media.sh "https://youtube.com/watch?v=XXX" player@example.com MP3
```
- Télécharge en MP3 via `process_youtube.sh`
- Upload IPFS + publication via endpoint `/vocals` (NIP-A0)

### `PDF` — Document ou page web
```bash
./ajouter_media.sh "https://example.com/doc" player@example.com PDF
./ajouter_media.sh "" player@example.com PDF   # sélection fichier local
```
- URL → conversion via chromium headless
- Fichier local → sélection zenity
- Upload IPFS + publication NOSTR kind 1

### `Film` / `Serie` — Vidéo locale avec métadonnées TMDB
```bash
./ajouter_media.sh "" player@example.com Film
./ajouter_media.sh "" player@example.com Serie
```
- Sélection du fichier local (GUI)
- Enrichissement optionnel via scraping TMDB (titre, genres, réalisateur, note)
- Conversion H264/AAC si nécessaire (ffmpeg)
- Upload + publication NIP-71 avec métadonnées structurées

### `Video` — Vidéo personnelle
```bash
./ajouter_media.sh "" player@example.com Video
```
- Sélection du fichier local
- Option d'enrichissement TMDB (Film, Série, ou aucun)
- Même pipeline que Film/Serie

### `Vlog` — Webcam
```bash
./ajouter_media.sh "" player@example.com Vlog
```
- Redirige vers l'interface webcam UPassport (`/webcam`)

### `IA` / `analyse` — Analyse et indexation IA
```bash
./ajouter_media.sh "Qm..." player@example.com IA "Permaculture"
./ajouter_media.sh "/path/to/file" player@example.com analyse
```
- Analyse via Ollama (si disponible) : description du contenu
- Publication NOSTR kind 30504 (MineLife/Grimoire knowledge)
- Indexation Qdrant via `admin/ia_db/knowledge_index.sh`
- `$4` = tag de compétence (ex: "Électronique", "Permaculture")

### `uDRIVE` — Ouvrir l'espace de stockage personnel
```bash
./ajouter_media.sh "" player@example.com uDRIVE
```
- Ouvre le lien IPNS uDRIVE du joueur dans le navigateur

---

## Workflow interne

```
ajouter_media.sh
    ├── Validation PLAYER (email + ~/.zen/game/nostr/)
    ├── Accord copie privée (une fois, stocké dans .legal)
    ├── NIP-42 auth (kind 22242 → relay local 7777)
    ├── Téléchargement / sélection fichier
    ├── upload2ipfs.sh → /api/fileupload
    │       → cidirect (CID fichier) + file_cid (CID wrapper)
    └── Publication NOSTR
            → Youtube/Video/Film/Serie : publish_nostr_video.sh (NIP-71)
            → MP3 : /vocals endpoint (NIP-A0)
            → PDF : nostr_send_note.py kind 1
            → IA  : nostr_send_note.py kind 30504
```

**Note CID :** `cidirect` = CID stable du fichier brut (URL propre `/ipfs/CID`). `file_cid` = CID du dossier wrapper. `new_cid` = CID uDRIVE complet — ne jamais utiliser comme URL média directe.

---

## Dépendances

| Outil | Usage |
|-------|-------|
| `zenity` | GUI interactif (obligatoire en mode interactif) |
| `ipfs` | IPFS daemon (port 5001) |
| `jq`, `curl` | Traitement JSON + API |
| `ffmpeg`, `ffprobe` | Conversion vidéo H264/AAC |
| `yt-dlp` | Téléchargement YouTube (via process_youtube.sh) |
| `chromium` | Conversion page web → PDF |

---

## Variables d'environnement

| Variable | Valeur par défaut | Usage |
|----------|-------------------|-------|
| `ENABLE_AUDIO_NOTIFICATIONS` | non définie | `yes` → activer espeak audio |
| `API_URL` | `http://127.0.0.1:54321` | Endpoint UPassport |

---

## Logs

`~/.zen/tmp/ajouter_media.log` — toutes les exécutions (stdout + stderr).

---

## Voir aussi

- [`docs/reference/UPlanet_FILE_CONTRACT.md`](../reference/UPlanet_FILE_CONTRACT.md) — contrat de fichier UPlanet
- [`docs/how-to/KNOWLEDGE_EMBEDDINGS.md`](KNOWLEDGE_EMBEDDINGS.md) — indexation IA kind 30504
- `UPassport/routers/media_upload.py` — endpoint `/api/fileupload`
