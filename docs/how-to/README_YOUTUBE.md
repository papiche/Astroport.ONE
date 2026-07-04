# YouTube & Video Management System - Documentation

## 🎯 Overview

The UPlanet video management system provides **three modes** for creating and managing videos:

1. **Manual Download** (`#youtube` tag) - On-demand YouTube video downloads
2. **Automatic Sync** - Daily synchronization of liked videos via NOSTR refresh cycle
3. **Webcam Recording** (`/webcam` route) - Direct video recording and upload with geolocation

## 🔧 How It Works

### Webcam Recording Process Flow (NEW)

1. **User accesses** `/webcam` route with NOSTR authentication
2. **Records video** via browser webcam or uploads local video file (.mp4, .webm, .mov)
3. **Geolocation capture** - User can specify coordinates or use current location (defaults to 0.00, 0.00)
4. **IPFS Upload** - Video uploaded via `/api/fileupload` endpoint
5. **NOSTR Publication** - NIP-71 event (kind 21/22) with geographic tags:
   * `g` tag: Geohash format (lat,lon) for UMAP anchoring
   * `location` tag: Human-readable coordinates
   * `latitude` and `longitude` tags: Individual coordinate tags
6. **uDRIVE Storage** - Video saved to `uDRIVE/Videos/` directory
7. **Geographic Discovery** - Videos searchable by location via `/youtube` route

### Manual Download Process Flow

1. **User sends message** with `#youtube` tag + YouTube URL
2. **UPlanet\_IA\_Responder.sh** detects the tag and calls `process_youtube.sh`
3. **process\_youtube.sh** tries multiple cookie strategies:
   * **User-uploaded cookies** (`.cookie.txt` from astro\_base interface)
   * **Browser cookies** (from Chrome, Firefox, Brave, Edge)
   * **Generated cookies** (basic fallback)
4. **yt-dlp** downloads the video/audio
5. **IPFS** uploads the media
6. **NOSTR Events** published (kind: 1 + NIP-71 kind: 21/22)
7. **Response** sent back to user with IPFS link

### Automatic Sync Process Flow

1. **NOSTRCARD.refresh.sh** runs daily for each MULTIPASS user
2. **Cookie Detection** - Checks for `.cookie.txt` in user's NOSTR directory
3. **YouTube Sync Trigger** - If cookies exist, launches `youtube.com.sh`
4. **Liked Videos Fetch** - Retrieves up to 2 new liked videos from YouTube
5. **Video Processing** - Calls `process_youtube.sh` for each video
6. **NOSTR Publication** - Publishes NIP-71 events for each downloaded video
7. **uDRIVE Organization** - Videos stored in `uDRIVE/Videos/` and `uDRIVE/Music/`
8. **Email Notification** - User receives sync summary via email

### Cookie Strategies (Priority Order)

```bash
1. User cookies:     ~/.zen/game/nostr/<email>/.cookie.txt
2. Browser cookies:  --cookies-from-browser <browser>
3. Generated cookies: ~/.zen/tmp/youtube_cookies.txt (fallback)
```

### Channel Watch — Suivi automatique de chaînes (optionnel)

En plus des vidéos likées, le cycle quotidien peut surveiller des chaînes YouTube et copier leurs nouvelles vidéos. Créez le fichier de configuration (une URL de chaîne par ligne, `#` pour commenter) :

```bash
# ~/.zen/game/nostr/<email>/.youtube.com.channels
https://www.youtube.com/@ARTEfr
# https://www.youtube.com/@Blender     <- ligne ignorée (commentaire)
```

Fonctionnement (`sync_youtube_channels` dans `youtube.com.sh`, exécuté juste après la sync des likes) :

* Interroge l'onglet public `/videos` de chaque chaîne (pas besoin de cookie pour cette étape — la playlist est publique)
* Télécharge **au maximum 1 nouvelle vidéo par chaîne et par jour** (léger, adapté Raspberry Pi)
* Réutilise le même pipeline que les likes : téléchargement `process_youtube.sh`, upload `/api/fileupload`, publication NOSTR NIP-71 (kind 21/22), rangement dans `uDRIVE/Videos/`
* Dédoublonnage global par `video_id` dans `.processed_youtube_videos` (une vidéo likée ET publiée par une chaîne suivie n'est copiée qu'une fois)
* Best-effort : un échec sur une chaîne n'interrompt ni les autres chaînes ni la synchronisation des likes
* Les vidéos de plus de 90 minutes sont ignorées (même règle que les likes)

Sans fichier `.youtube.com.channels`, rien ne change : seule la sync des likes s'exécute.

## 📼 Mode 4 — Voeu TW `CopierYoutube` (chaîne complète, dans le TiddlyWiki)

Ce mode est le plus puissant : il permet d'archiver une **chaîne YouTube entière** (ou une playlist) en formulant un voeu directement dans le TiddlyWiki personnel. L'ASTROBOT traite le voeu à chaque cycle `PLAYER.refresh.sh`.

### Principe

1. **Créer le voeu** dans le TW (un tiddler avec les tags `voeu` + `CopierYoutube`)
2. **Créer un ou plusieurs tiddlers de contenu** (tags : `CopierYoutube`) contenant les URLs à archiver
3. Le système détecte le voeu et **appelle `ASTROBOT/Z/G1CopierYoutube.sh`** automatiquement
4. Chaque vidéo téléchargée devient un **tiddler dans le TW** avec lecteur vidéo/audio embarqué

### Étapes dans le TiddlyWiki

**Étape 1 — Formuler le voeu**

Créer un tiddler avec :

```
Titre : CopierYoutube
Tags  : voeu CopierYoutube
Texte : (description facultative de l'intention)
```

**Étape 2 — Lister les URLs à archiver**

Créer un tiddler par source avec :

```
Titre : MaChaineYoutube  (ou tout autre nom)
Tags  : CopierYoutube
Texte : https://www.youtube.com/@nom-de-la-chaine
```

Pour une playlist :

```
Texte : https://www.youtube.com/playlist?list=PLxxxxxx
```

Pour plusieurs sources, mettre une URL par ligne dans le texte, ou créer plusieurs tiddlers tagués `CopierYoutube`.

**Étape 3 — Pour archiver en audio seulement (MP3)**

Ajouter le tag `MP3` au tiddler de contenu :

```
Tags : CopierYoutube MP3
```

### Ce que fait l'ASTROBOT

```
TW player.index.html
  └─ tiddlers [tag[CopierYoutube]]
       └─ URLs extraites
            └─ yt-dlp télécharge chaque vidéo
                 └─ IPFS add → /ipfs/QmHash
                      ├─ ajouter_media.sh :
                      │    ├─ uDRIVE/Videos/ (copie fichier réel)
                      │    ├─ info.json v2.0 (métadonnées)
                      │    └─ NIP-94 kind 1063 (NOSTR file event)
                      ├─ Tiddler créé dans le TW :
                      │    title: nom_du_fichier.mp4
                      │    tags:  CopierYoutube NomDeLaChaine
                      │    text:  <video> ou <audio> embarqué
                      │    ipfs:  /ipfs/QmHash
                      └─ NIP-71 kind 21/22 (NOSTR video event)
```

Les vidéos apparaissent dans le TW sous le tag `CopierYoutube` avec lecteur intégré. Elles sont simultanément :

* publiées comme **événements NIP-71** (kind 21/22) visibles sur `/youtube`
* sauvegardées dans le **uDRIVE** du joueur (`Videos/` ou `Music/` pour MP3)
* indexées comme **fichiers NIP-94** (kind 1063) dans la constellation

### Cookies YouTube

Le script utilise les cookies du navigateur par défaut (détection automatique). Pour les stations sans interface graphique (serveur), uploader les cookies via :

```
https://u.domain.tld/astro  →  cookie upload
```

### Suivi des archives

```bash
# Voir les archives en cours pour un joueur
ls ~/.zen/game/players/<email>/G1CopierYoutube/

# Voir le log de traitement
tail -f ~/.zen/tmp/IA.log | grep "G1CopierYoutube"

# Voir les tiddlers importés dans le TW
cat ~/.zen/game/players/<email>/G1CopierYoutube/CopierYoutube.json | jq '.[].title'
```

### Déclenchement manuel

```bash
# Déclencher manuellement pour un joueur (email = PLAYER)
./ASTROBOT/Z/G1CopierYoutube.sh \
    ~/.zen/game/players/<email>/ipfs/moa/index.html \
    <email>
```

### Extension IA — MineLife et Grimoire

> **Vision (non implémentée, RFC)** : relier le contenu archivé à la toile de compétences WoTx2.

Le titre du voeu (`CopierYoutube`) peut porter le nom d'une compétence cible. Après le téléchargement, un script d'analyse IA pourrait :

1. **Analyser la vidéo** — Ollama (`question.py`) pour transcrire ou décrire le contenu
2. **Extraire les concepts** liés à la compétence du voeu
3. **Publier kind 30504** (knowledge content) avec la vidéo comme source, indexé par `knowledge_index.sh` dans Qdrant
4. **Alimenter MineLife** — la compétence devient cherchable dans le catalogue Qdrant
5. **Déclencher Grimoire** — après validation WoTx2 (craft success), générer un kind 22 vidéo résumé

```
voeu CopierYoutube "Permaculture"
  └─ G1CopierYoutube.sh télécharge la chaîne
       └─ [futur] analyser_media.sh :
            ├─ Ollama analyse contenu → mots-clefs
            ├─ NIP kind 30504 (knowledge) → Qdrant
            └─ MineLife : skill "Permaculture" enrichi
                 └─ craft validé → Grimoire kind 22
```

→ Voir [MINELIFE.md](MINELIFE.md), [GRIMOIRE\_LIVE.md](GRIMOIRE_LIVE.md), [KNOWLEDGE\_EMBEDDINGS.md](KNOWLEDGE_EMBEDDINGS.md)

***

## 🍪 Cookie Management

### Why Cookies Are Needed

YouTube blocks bot requests. Fresh browser cookies allow ASTROBOT to download videos as if a real user is accessing them.

### How to Upload Cookies

1.  **Export cookies** from your browser using the guide:

    ```
    https://ipfs.copylaradio.com/ipns/copylaradio.com/cookie.html
    ```
2.  **Upload the file** via the ASTROBOT interface:

    ```
    https://u.copylaradio.com/astro
    ```
3.  **System automatically detects** the Netscape format and saves to:

    ```
    ~/.zen/game/nostr/<your-email>/.cookie.txt
    ```

### Automatic Sync Activation

Once you upload cookies, the system automatically:

* **Detects your cookies** during daily NOSTR refresh cycle
* **Launches YouTube sync** for your liked videos
* **Downloads up to 3 new videos** per day
* **Organizes videos** in your uDRIVE
* **Publishes NOSTR events** for each video
* **Sends email notifications** with sync results

### Cookie File Format

The system expects **Netscape cookie format**. Cookies are automatically detected and stored as `.youtube.com.cookie` in your MULTIPASS directory.

> **📖 For complete cookie management documentation, see** [**COOKIE\_SYSTEM.md**](https://github.com/papiche/Astroport.ONE/blob/master/docs/how-to/COOKIE_SYSTEM.md)

Example format:

```
# Netscape HTTP Cookie File
.youtube.com	TRUE	/	TRUE	2147483647	CONSENT	YES+cb...
.youtube.com	TRUE	/	TRUE	2147483647	VISITOR_INFO1_LIVE	abc123...
```

**Note**: The system now uses domain-specific cookie files (`.youtube.com.cookie`) instead of the generic `.cookie.txt` format. Upload your cookies via the `/cookie` interface for automatic detection and storage.

## 📋 Logs and Debugging

### Log File Location

All YouTube processing logs are written to:

```bash
~/.zen/tmp/IA.log
```

### Manual Log Commands

```bash
# Follow logs in real-time
tail -f ~/.zen/tmp/IA.log | grep "process_youtube\|yt-dlp"

# Show recent YouTube errors
grep -E "WARNING|ERROR|Failed" ~/.zen/tmp/IA.log | grep "yt-dlp\|YouTube" | tail -20

# Show complete YouTube processing logs
grep "process_youtube" ~/.zen/tmp/IA.log | tail -100
```

## 🐛 Common Issues

### Issue 1: "YouTube authentication failed"

**Cause:** Cookies are missing, expired, or invalid.

**Solution:**

1. Export fresh cookies from your browser (see cookie guide)
2. Upload via astro\_base interface
3. Try again

### Issue 2: "Download or IPFS upload failed"

**Causes:**

* YouTube bot detection
* Network issues
* IPFS daemon not running
* Video too long (>3h limit)

**Solution:**

1. Check logs
2. Verify IPFS is running: `ipfs id`
3. Try with fresh cookies
4. Check video duration

### Issue 3: Empty response (no Title, Duration, etc.)

**Cause:** All cookie strategies failed.

**Debug:**

```bash
# Check if user cookie file exists
ls -la ~/.zen/game/nostr/*/. cookie.txt

# Check cookie age
stat ~/.zen/game/nostr/<email>/.cookie.txt

```

### Issue 4: HTTP 403 Forbidden / fragment not found (DASH)

**Cause:** YouTube requires a Proof of Origin (PO) token for some clients. See [yt-dlp PO Token Guide](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide).

**Solutions (in order):**

1. **Update yt-dlp** – Already done daily by `install_yt_dlp_ejs_node.sh`.
2. **PO Token Provider plugin** – Installed optionally by the same script. Run the provider:\
   `docker run -d -p 4416:4416 --name bgutil-provider brainicism/bgutil-ytdlp-pot-provider`
3. **Manual PO token (GVS)** – Put the token in one line (no spaces) in:\
   `~/.zen/game/nostr/<your-email>/.youtube.potoken`\
   How to get it: [PO Token Guide – PO Token for GVS](https://github.com/yt-dlp/yt-dlp/wiki/PO-Token-Guide#po-token-for-gvs) (YouTube Music → Network → v1/player → `serviceIntegrityDimensions.poToken`).

The scripts prefer clients that do not require a PO token (`tv_embedded`, `tv`) and retry with them on 403.

## 📊 Debug Mode

Debug mode is **automatically enabled** in `UPlanet_IA_Responder.sh` for all YouTube downloads.

To manually enable debug mode:

```bash
# Debug enabled (verbose)
./process_youtube.sh --debug "https://youtube.com/watch?v=ABC123" mp4

# Debug disabled (quiet)
./process_youtube.sh "https://youtube.com/watch?v=ABC123" mp4
```

**JSON Output Options**:

For reliable JSON parsing (recommended), use `--json-file`:

```bash
# Write JSON to separate file (prevents mixing with logs)
./process_youtube.sh --json-file /tmp/output.json --debug "https://youtube.com/watch?v=ABC123" mp4

# Output pure JSON to stdout
./process_youtube.sh --json --debug "https://youtube.com/watch?v=ABC123" mp4
```

**Custom Output Directory**:

```bash
# Download to specific directory
./process_youtube.sh --output-dir /tmp/my_videos "https://youtube.com/watch?v=ABC123" mp4
```

## 🎬 NIP-71 Video Events

### Event Types Published

The system publishes **two types** of NOSTR events for each video:

1. **Kind 1** - Text message (compatibility with older clients)
2. **Kind 21/22** - NIP-71 video events (modern standard)

### NIP-71 Classification (implémentation réelle)

* **Kind 21** — long-form : durée > 60 secondes
* **Kind 22** — short-form : durée ≤ 60 secondes

### NIP-71 Tags Structure

Tags générés par `publish_nip71_video()` dans `G1CopierYoutube.sh` :

```json
[
  ["title",        "Titre de la vidéo"],
  ["url",          "http://127.0.0.1:8080/ipfs/QmHash..."],
  ["m",            "video/mp4"],
  ["published_at", "1640995200"],
  ["duration",     "1200"],
  ["dim",          "1280x720"],
  ["thumb",        "http://127.0.0.1:8080/ipfs/QmThumb..."],
  ["gifanim_url",  "http://127.0.0.1:8080/ipfs/QmGif..."],
  ["x",            "sha256_du_fichier"],
  ["t",            "Channel-NomChaine"],
  ["t",            "CopierYoutube"],
  ["t",            "YouTube"],
  ["t",            "Astroport"],
  ["r",            "https://youtube.com/watch?v=..."]
]
```

Le tag `thumb` est une URL complète (format NIP-71 standard). `gifanim_url` est un tag custom Astroport pour la prévisualisation animée.

#### Pipeline complet par vidéo

1. **yt-dlp** → télécharge mp4/mp3 dans `~/.zen/tmp/yt-dlp/`
2. **IPFS add** → obtient le CID
3. **`ajouter_media.sh`** → copie dans `uDRIVE/Videos/` + `info.json` + NIP-94 kind 1063
4. **TW import** → tiddler `<video>` dans le wiki personnel
5. **NIP-71 kind 21/22** → événement vidéo NOSTR via clef MULTIPASS

### Example NIP-71 Event

```json
{
  "kind": 21,
  "content": "🎬 How to Build a Blockchain\n\n📺 Channel: TechChannel\n🔗 IPFS: http://127.0.0.1:8080/ipfs/QmHash...\n🌐 Source: https://youtube.com/watch?v=...\n\n#CopierYoutube #YouTube #Astroport #IPFS",
  "tags": [
    ["title",        "How to Build a Blockchain"],
    ["url",          "http://127.0.0.1:8080/ipfs/QmHash..."],
    ["m",            "video/mp4"],
    ["published_at", "1640995200"],
    ["duration",     "1200"],
    ["dim",          "1280x720"],
    ["thumb",        "http://127.0.0.1:8080/ipfs/QmThumb..."],
    ["x",            "abc123..."],
    ["t",            "Channel-TechChannel"],
    ["t",            "CopierYoutube"],
    ["t",            "YouTube"],
    ["t",            "Astroport"],
    ["r",            "https://youtube.com/watch?v=..."]
  ]
}
```

## 📺 Video Interfaces

### YouTube Channel Interface (`/youtube`)

Access your videos and browse community content:

```
https://u.copylaradio.com/youtube
```

#### Features

* **Video Gallery** - Browse all downloaded and recorded videos
* **NOSTR Integration** - Like videos, view author profiles
* **Geographic Filtering** - Search videos by location (lat, lon, radius)
* **Responsive Design** - Works on PC and mobile
* **IPFS Streaming** - Direct video playback from IPFS
* **Metadata Display** - Duration, file size, dimensions, keywords, location
* **Channel Organization** - Videos grouped by uploader/creator

#### Geographic Search

Filter videos by location using URL parameters:

```
https://u.copylaradio.com/youtube?lat=48.86&lon=2.35&radius=10&html=1
```

Parameters:

* `lat`: Latitude (decimal degrees)
* `lon`: Longitude (decimal degrees)
* `radius`: Search radius in kilometers
* `html=1`: Return HTML view (required for web browser)

The system uses the Haversine formula to calculate geographic distances and filter videos within the specified radius.

### Webcam Recording Interface (`/webcam`)

Record or upload videos with geolocation:

```
https://u.copylaradio.com/webcam
```

#### Features

* **NOSTR Authentication** - Connect via browser extension or nsec key
* **Webcam Recording** - Direct browser recording (3-60 seconds)
* **File Upload** - Upload local video files (.mp4, .webm, .mov, max 500MB)
* **Geolocation** - Interactive map for location selection
* **Preview & Edit** - Review video before publishing
* **IPFS Upload** - Automatic upload via `/api/fileupload`
* **NIP-71 Publishing** - Creates proper video events with geographic tags
* **uDRIVE Storage** - Saves to personal `uDRIVE/Videos/` directory

#### Recording Workflow

1. **Connect NOSTR** - Authenticate with your NOSTR identity
2. **Choose Source**:
   * Record via webcam (adjustable duration)
   * Upload video file from device
3. **Preview** - Review video in modal
4. **Edit Metadata**:
   * Title (required)
   * Description (optional)
   * Geographic location (interactive map or manual input)
5. **Publish** - Video uploaded to IPFS and published to NOSTR
6. **View** - Access via `/youtube` interface with geographic filtering

## 🔗 Related Files

```
Astroport.ONE/IA/
├── process_youtube.sh           # Main YouTube download script
├── youtube.com.sh       # Automatic sync of liked videos
├── create_video_channel.py     # NIP-71 channel creation with geolocation support
├── UPlanet_IA_Responder.sh     # Calls process_youtube.sh when #youtube tag detected
└── README_YOUTUBE.md           # This file

Astroport.ONE/RUNTIME/
└── NOSTRCARD.refresh.sh        # Daily refresh cycle (triggers YouTube sync)

UPlanet/earth/
├── cookie.html                 # User guide for cookie export
└── common.js                   # Shared NOSTR/IPFS functions for webcam integration

UPassport/
├── templates/
│   ├── astro_base.html         # File upload interface (detects Netscape cookies)
│   ├── webcam.html             # Webcam recording interface with geolocation
│   └── youtube.html            # YouTube channel interface with geographic filtering
└── 54321.py                    # API endpoints:
                                #   - /youtube (with lat/lon/radius filtering)
                                #   - /webcam (video publishing with geolocation)
                                #   - /api/fileupload (IPFS upload for webcam videos)

~/.zen/
├── tmp/
│   ├── IA.log                  # Main log file
│   └── youtube_*/              # Temporary download directories
└── game/nostr/<email>/
    ├── .cookie.txt             # User-uploaded cookies (Netscape format)
    ├── .last_youtube_sync      # Last sync date tracking
    ├── .processed_youtube_videos # Processed videos database
    └── APP/uDRIVE/
        ├── Videos/             # User's video storage (webcam + YouTube)
        └── Music/              # User's audio storage (YouTube MP3)
```

## 💡 Tips

1. **Cookie lifespan**: YouTube cookies typically last 1-3 months. Re-export when downloads start failing.
2. **Multiple users**: Each user can upload their own cookies. The system automatically uses cookies for the requesting user.
3. **Privacy**: Cookies are stored locally and only used for YouTube downloads. They're not shared or transmitted.
4. **Format detection**: `#youtube` defaults to MP4. Add `#mp3` for audio-only: `#youtube #mp3`
5. **Duration limit**: Videos longer than 3 hours are rejected to prevent resource exhaustion.
6. **Automatic sync**: Upload cookies once and your liked videos will sync automatically every day (up to 2 new videos per day).
7. **NIP-71 compatibility**: All videos are published as fully compliant NIP-71 events with proper `imeta` tags, `title`, `published_at`, `alt`, and accessibility features.
8. **uDRIVE organization**: Videos are automatically organized in your personal uDRIVE storage (`uDRIVE/Videos/` and `uDRIVE/Music/`).
9. **Email notifications**: You'll receive daily summaries of your YouTube sync results.
10. **Channel interface**: Access all your videos via the `/youtube` route with full NOSTR integration and geographic filtering.
11. **Webcam recording**: Record videos directly in browser with adjustable duration (3-60 seconds, optimized for mobile).
12. **Video upload**: Upload local video files (.mp4, .webm, .mov) up to 500MB via `/webcam` interface.
13. **Geolocation**: Add location data to videos for geographic discovery and UMAP anchoring (defaults to 0.00, 0.00 if not specified).
14. **Geographic search**: Filter videos by location using `lat`, `lon`, and `radius` URL parameters on `/youtube` route.
15. **IPFS streaming**: All videos accessible via IPFS gateway for decentralized, censorship-resistant playback.

## 🔄 System Architecture

### Complete Video Management Flow

#### YouTube Download Flow

```
User Uploads Cookies
        ↓
NOSTRCARD.refresh.sh (Daily)
        ↓
youtube.com.sh (Auto-triggered)
        ↓
process_youtube.sh (Video download)
        ↓
IPFS Upload + uDRIVE Storage
        ↓
NOSTR Events (kind: 1 + NIP-71)
        ↓
create_video_channel.py (Channel parsing)
        ↓
/youtube Interface (User access + geographic filtering)
```

#### Webcam Recording Flow

```
User Accesses /webcam
        ↓
NOSTR Authentication (extension or nsec)
        ↓
Video Recording/Upload + Geolocation
        ↓
/api/fileupload (IPFS upload to uDRIVE)
        ↓
/webcam (NIP-71 event creation with geographic tags)
        ↓
NOSTR Publication (kind: 21/22 with g, location, lat, lon tags)
        ↓
/youtube Interface (Access with geographic filtering)
```

### Key Components

* **Cookie Upload**: `cookie.html` → `astro_base.html` → `.cookie.txt`
* **Daily Sync**: `NOSTRCARD.refresh.sh` → `youtube.com.sh` → `process_youtube.sh`
* **Webcam Recording**: `/webcam` → NOSTR auth → video capture → `/api/fileupload`
* **IPFS Upload**: `/api/fileupload` → `uDRIVE/Videos/` → IPFS CID
* **NOSTR Publishing**: `/webcam` route → NIP-71 event with geographic tags
* **Video Processing**: `process_youtube.sh` → IPFS → NOSTR → uDRIVE
* **Channel Parsing**: `create_video_channel.py` → Extract NIP-71 events with geolocation
* **User Interface**: `/youtube` route → `youtube.html` with geographic filtering
* **Geographic Discovery**: Haversine formula → filter videos by lat/lon/radius

## 🆘 Support

If you encounter issues:

### YouTube Download Issues

1. Check logs: `tail -f ~/.zen/tmp/IA.log | grep "process_youtube"`
2. Verify cookie file exists and is recent: `ls -la ~/.zen/game/nostr/*/. cookie.txt`
3. Test with a different YouTube URL
4. Update yt-dlp: `pip install --upgrade yt-dlp`

### Webcam Recording Issues

1. Verify NOSTR connection: Check browser console for connection errors
2. Check IPFS upload: Verify `/api/fileupload` endpoint is accessible
3. Browser permissions: Ensure webcam/microphone access is granted
4. File size: Maximum 500MB for uploaded videos
5. Supported formats: .mp4, .webm, .mov

### General System Checks

1. Check IPFS daemon: `ipfs id`
2. Check NOSTR relay: `ws://127.0.0.1:7777` or `wss://relay.copylaradio.com`
3. Verify uDRIVE directory: `~/.zen/game/nostr/<email>/APP/uDRIVE/Videos/`
4. Check video storage: `ls -lh ~/.zen/game/nostr/<email>/APP/uDRIVE/Videos/`

### Geographic Filtering Issues

1. Verify coordinates format: Use decimal degrees (e.g., 48.86, not 48°51'N)
2. Check radius parameter: Value in kilometers (default: 10.0)
3. Test without filters: Access `/youtube?html=1` first
4. Browser console: Check for JavaScript errors in geographic calculations

For more help, contact: support@qo-op.com
