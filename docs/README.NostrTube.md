# Nostr Tube - Web3 Video Platform

> **🚀 Built in 1 week**. Like CSS separated presentation from data, UPlanet separates events from processing chains.

## 🎯 The Revolution

- **No API to build**: NOSTR events handle distribution
- **No auth to implement**: NIP-42 cryptographic authentication  
- **No servers to manage**: IPFS + NOSTR network
- **Interoperable by design**: Any NOSTR client can interact

**Result**: Focus on your features, not infrastructure.

**[▶️ See live demo](https://u.copylaradio.com/youtube?html=1)**

---

## Overview

**Nostr Tube** is a fully decentralized YouTube alternative built on **NOSTR**, **IPFS**, and **MULTIPASS**. It enables users to upload, share, like, and comment on videos without relying on centralized platforms.

### Architecture

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐     ┌─────────────┐
│  YouTube Sync   │────▶│  IPFS Upload │────▶│  NOSTR Pub  │────▶│  Web UI     │
│  (liked videos) │     │  (storage)   │     │  (kind 21/22)│     │  (display)  │
└─────────────────┘     └──────────────┘     └─────────────┘     └─────────────┘
        │                       │                     │                   │
        │                       │                     │                   │
        ▼                       ▼                     ▼                   ▼
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐     ┌─────────────┐
│  Webcam Record  │────▶│  uDRIVE      │     │  Relay      │     │  Channel    │
│  (user videos)  │     │  (local)     │     │  (ws://...) │     │  Groups     │
└─────────────────┘     └──────────────┘     └─────────────┘     └─────────────┘
```

### Key Technologies

- **NOSTR**: Decentralized social protocol for video events (NIP-71)
- **IPFS**: Content-addressed storage for video files
- **MULTIPASS**: Unified identity system with NOSTR keys and uDRIVE storage
- **NIP-42**: Authentication mechanism for secure uploads
- **NIP-101**: UPlanet protocol for decentralized identity, geographic coordination, and constellation synchronization
- **UMAP**: Geographic anchoring of videos (latitude/longitude) - defined in NIP-101

---

## Components

### 1. YouTube Synchronization (`youtube.com.sh`)

Synchronizes liked videos from YouTube to Nostr Tube.

**Location**: `Astroport.ONE/IA/youtube.com.sh`

**Features**:
- Fetches up to 5 liked videos per sync (configurable)
- Uses YouTube cookies for authentication (Netscape format)
- Processes max 2 new videos per day (prevents overload)
- Filters already processed videos
- Checks if videos exist in uDRIVE before downloading
- Sends email notifications after sync

**Workflow**:
```bash
# Manual sync for a player
./youtube.com.sh player@example.com

# Debug mode
./youtube.com.sh player@example.com --debug
```

**Cookie Setup**:
1. Export YouTube cookies using browser extension (e.g., "Get cookies.txt LOCALLY")
2. Upload to `/cookie` endpoint or directly to `~/.zen/game/nostr/{PLAYER}/.cookie.txt`
3. Cookie file must be Netscape format (tab-separated with 7+ columns)

**Tracking Files**:
- Last sync date: `~/.zen/game/nostr/{PLAYER}/.last_youtube_sync`
- Processed videos: `~/.zen/game/nostr/{PLAYER}/.processed_youtube_videos`
- Logs: `~/.zen/tmp/IA.log`

---

### 2. Video Processing (`process_youtube.sh`)

Downloads and processes YouTube videos, then uploads to IPFS.

**Location**: `Astroport.ONE/IA/process_youtube.sh`

**Usage**:
```bash
./process_youtube.sh [--debug] [--json] [--json-file <file>] [--output-dir <dir>] <youtube_url> <format> [player_email]
```

**Options**:
- `--debug`: Enable debug logging
- `--json`: Output pure JSON (no separators) to stdout
- `--json-file <file>`: Write JSON to a separate file (recommended for reliable parsing)
- `--output-dir <dir>`: Specify custom output directory for downloaded files
- `--no-ipfs`: Deprecated (IPFS upload removed for UPlanet_FILE_CONTRACT.md compliance)

**Features**:
- Downloads video in MP4 format (max 720p) or MP3
- Extracts comprehensive metadata (title, duration, uploader, YouTube metadata, etc.)
- Validates video duration (max 3 hours)
- Automatically selects resolution based on video duration to stay under 650MB limit
- Organizes files in uDRIVE structure:
  - Videos → `uDRIVE/Videos/`
  - Audio → `uDRIVE/Music/{artist}/`
- Returns JSON with file path, metadata, and comprehensive YouTube information
- Supports playlist downloads (MP3 format)

**Output Format**:
```json
{
  "ipfs_url": "/ipfs/QmHASH/filename.mp4",
  "title": "Video Title",
  "duration": "3600",
  "uploader": "Channel Name",
  "original_url": "https://youtube.com/watch?v=...",
  "filename": "video.mp4",
  "technical_info": {
    "format": "mp4",
    "file_size": "52428800",
    "download_date": "2024-01-01T12:00:00"
  }
}
```

**Dependencies**:
- `yt-dlp`: YouTube downloader
- `ipfs`: IPFS daemon for content addressing
- `ffmpeg`: Video processing (optional, for metadata extraction)

---

### 3. Webcam Interface (`webcam.html`)

Web-based interface for recording and uploading videos.

**Location**: `UPassport/templates/webcam.html`

**Route**: `GET /webcam`, `POST /webcam`

**Features**:
- **Recording**: Browser-based video recording (3-30 seconds)
- **Upload**: Direct file upload (MP4, WebM, MOV, max 500MB)
- **NOSTR Auth**: Supports extension (nos2x, Alby) or nsec key
- **Geographic Tagging**: UMAP coordinates via map picker or GPS
- **Preview**: Modal with video preview before publishing
- **Mobile Optimized**: Responsive design for mobile devices

**Workflow**:
1. Connect to NOSTR (extension or nsec)
2. Record video or upload file
3. Add title, description, location
4. Upload to IPFS via `/api/fileupload` (returns CID)
5. Publish NOSTR event (kind 21 or 22) via `POST /webcam`

**JavaScript Functions**:
- `handleNostrConnect()`: Authenticate with NOSTR
- `initWebcamFeatures()`: Initialize camera recording
- `handleVideoUpload()`: Process uploaded file
- `publishVideo()`: Upload to IPFS and publish to NOSTR
- `showVideoModal()`: Preview before publishing

---

### 4. File Upload API (`/api/fileupload`)

Secure file upload endpoint with NIP-42 authentication.

**Route**: `POST /api/fileupload`

**Location**: `UPassport/54321.py` (line 3348)

**Authentication**:
- **NIP-42**: NOSTR authentication required via `npub` parameter
- Verification via `verify_nostr_auth()` function
- Checks relay connection and event signature

**Features**:
- Detects file type (image, video, audio, document)
- Organizes files in uDRIVE structure:
  - `Images/` - Images with AI-generated filenames
  - `Videos/` - Video files
  - `Music/` - Audio files organized by artist
  - `Documents/` - Text/PDF files
  - `Apps/` - Application files
- **Cookie Detection**: Special handling for Netscape cookie files
  - Saves to `~/.zen/game/nostr/{hex_pubkey}/.cookie.txt`
  - No IPFS upload for security
- **AI Filenames**: Images get AI-generated descriptive filenames
- IPFS CID generation via `upload2ipfs.sh`

**Request Format**:
```javascript
const formData = new FormData();
formData.append('file', videoFile);
formData.append('npub', userPubkey);

const response = await fetch('/api/fileupload', {
    method: 'POST',
    body: formData
});
```

**Response Format**:
```json
{
  "success": true,
  "message": "File uploaded successfully to IPFS",
  "file_path": "/path/to/file.mp4",
  "file_type": "video",
  "target_directory": "/path/to/uDRIVE/Videos",
  "new_cid": "QmHASH...",
  "timestamp": "2024-01-01T12:00:00",
  "auth_verified": true
}
```

---

### 5. Video Publishing (`POST /webcam`)

Publishes videos as NOSTR events (NIP-71).

**Route**: `POST /webcam`

**Location**: `UPassport/54321.py` (line 2713)

**Process**:
1. Receives IPFS CID from previous upload
2. Validates player email and NOSTR authentication
3. Extracts video metadata (duration, dimensions) via `ffprobe`
4. Generates thumbnail (if possible)
5. Creates NOSTR event with NIP-71 tags
6. Publishes to relay(s)

**NOSTR Event Structure** (NIP-71 + Provenance Extension):

```json
{
  "kind": 21,  // or 22 for short videos (≤60s)
  "content": "🎬 Video Title\n\n📹 Webcam: /ipfs/QmHASH/video.mp4",
  "tags": [
    ["title", "Video Title"],
    ["url", "/ipfs/QmHASH/video.mp4"],
    ["m", "video/mp4"],
    ["imeta", "dim 1280x720", "url /ipfs/QmHASH/video.mp4", "m video/mp4"],
    ["duration", "30"],
    ["published_at", "1704067200"],
    ["t", "YouTubeDownload"],
    ["t", "VideoChannel"],
    ["t", "WebcamRecording"],
    ["t", "Channel-{player}"],
    ["t", "Topic-{keyword}"],
    ["g", "48.8566,2.3522"],  // UMAP coordinates
    ["latitude", "48.8566"],
    ["longitude", "2.3522"],
    ["image", "/ipfs/QmTHUMBNAIL/thumb.jpg"],
    ["r", "/ipfs/QmTHUMBNAIL/thumb.jpg", "Thumbnail"],
    // Provenance & Deduplication Tags (NIP-71 Extension)
    ["x", "abc123..."],  // SHA-256 hash of file (for deduplication)
    ["info", "QmInfoCID..."],  // CID of info.json (metadata reuse)
    ["upload_chain", "pubkey1,pubkey2,..."],  // Distribution chain
    ["e", "original_event_id"],  // Original event (if re-upload)
    ["p", "original_author_pubkey"]  // Original author (if re-upload)
  ]
}
```

**Video Kind Selection**:
- `kind: 21`: Regular videos (>60 seconds)
- `kind: 22`: Short videos (≤60 seconds)

**Tags Explained**:
- `title`: Video title
- `url`: IPFS URL (required for `create_video_channel.py`)
- `m`: Media type (`video/mp4`, `video/webm`, etc.)
  - **Automatic detection** by `upload2ipfs.sh` from file content
  - **Priority**: file magic bytes → file extension → `video/mp4` (default)
  - **For MP4 files**: Will be `video/mp4` (not `video/webm`)
- `imeta`: NIP-71 metadata tag with dimensions and URL
- `duration`: Video duration in seconds
- `g`: Geohash tag (latitude,longitude) for UMAP anchoring
- `Channel-*`: Channel grouping tag
- `Topic-*`: Topic/keyword tags for categorization
- `image`: Thumbnail IPFS URL
- **`x`**: SHA-256 file hash (for deduplication and provenance)
- **`info`**: CID of info.json (metadata reuse, avoids redundant IPFS operations)
- **`upload_chain`**: Distribution chain (comma-separated pubkeys showing file propagation)
- **`e`**: Reference to original event ID (if video is a re-upload)
- **`p`**: Reference to original author pubkey (if video is a re-upload)

**Publishing Script**:
- Uses `~/.zen/Astroport.ONE/tools/nostr_send_note.py`
- Relay discovery via Astroport swarm: each node exposes `myRELAY` in `12345.json`
- Local relay: `ws://127.0.0.1:7777` (strfry local)
- Swarm relays: discovered via `_12345.sh` from compatible Astroport nodes
- Constellation sync: `backfill_constellation.sh` synchronizes video events (kind 21/22) across swarm
- Returns event ID on success

---

### 6. Video Discovery (`/youtube`)

Fetches and displays videos from NOSTR events.

**Route**: `GET /youtube`

**Location**: `UPassport/54321.py` (line 2211)

**Parameters**:
- `html=1`: Return HTML page instead of JSON
- `channel`: Filter by channel name
- `search`: Search in titles and keywords
- `keyword`: Filter by specific keywords (comma-separated)
- `date_from` / `date_to`: Date range filter (YYYY-MM-DD)
- `duration_min` / `duration_max`: Duration filter (seconds)
- `sort_by`: Sort order (`date`, `duration`, `title`, `channel`)
- `lat` / `lon` / `radius`: Geographic filter (decimal degrees, km)

**Process**:
1. Fetches NOSTR events via `create_video_channel.py`
2. Filters events by:
   - Kind: 21 (normal) or 22 (short)
   - Tags: Must have `url` tag with IPFS/YouTube URL
   - Tags: Must have `m` tag with `video` media type
3. Applies user filters (channel, search, date, location)
4. Groups videos by channel
5. Returns JSON or renders HTML template

**Response Format**:
```json
{
  "success": true,
  "total_videos": 42,
  "channels": {
    "ChannelName": {
      "channel_info": {
        "name": "ChannelName",
        "display_name": "Channel Display Name",
        "type": "youtube",
        "video_count": 10,
        "total_duration_seconds": 3600,
        "total_duration_formatted": "1h 0m",
        "total_size_bytes": 524288000,
        "total_size_formatted": "0.50 GB"
      },
      "videos": [...]
    }
  },
  "filtered_videos": [...]
}
```

---

### 7. Channel Creation (`create_video_channel.py`)

Organizes videos into channels from NOSTR events.

**Location**: `Astroport.ONE/IA/create_video_channel.py`

**Usage**:
```bash
# Fetch from NOSTR relay
python3 create_video_channel.py --fetch-nostr --channel ChannelName --output playlist.json

# From JSON file
python3 create_video_channel.py --input videos.json --channel ChannelName --format json
```

**Features**:
- Fetches NOSTR events (kind 21, 22) from relay
- Validates NIP-71 compatibility
- Groups videos by channel (`Channel-*` tags)
- Calculates channel statistics (duration, size, video count)
- Supports export formats: JSON, M3U, CSV

**Event Validation**:
- Must be kind 21 or 22
- Must have `url` tag with IPFS/YouTube URL
- Must have `m` tag indicating video media type
- Filters incompatible events automatically

**Channel Detection**:
- Primary: `Channel-*` tags
- Fallback: Uploader name from metadata
- Format: `Channel-{sanitized_name}`

**Metadata Extraction**:
- Title: From `title` tag or content parsing
- Uploader: From `uploader` tag or channel name
- Duration: From `duration` tag
- File size: From `size` tag
- Dimensions: From `dim` tag or `imeta`
- Location: From `g`, `latitude`, `longitude` tags
- Thumbnail: From `image` or `r` tags

---

### 8. User Interface (`youtube.html`)

Web interface for browsing and watching videos.

**Location**: `UPassport/templates/youtube.html`

**Route**: `GET /youtube?html=1`

**Features**:
- **Sidebar**: Channel navigation, filters, search
- **Video Grid**: Thumbnail grid with video cards
- **Player**: HTML5 video player with IPFS gateway detection
- **Filters**: Channel, search, date, duration, location
- **Map View**: Geographic visualization of videos (UMAP)
- **Responsive**: Mobile-optimized layout

**IPFS Gateway Detection**:
- Auto-detects IPFS gateway based on current Astroport station domain
- Uses gateway from same Astroport swarm (ORIGIN public or ẐEN private)
- Discovery via `_12345.sh`: each node exposes its `myIPFS` gateway in `12345.json`
- Local gateway: `http://127.0.0.1:8080` for localhost access
- Domain-based: `https://ipfs.{domain}` derived from station hostname
- Default: `https://ipfs.copylaradio.com` for UPlanet ORIGIN
- Swarm synchronization: compatible gateways discovered via IPNS swarm map (`~/.zen/tmp/swarm/`)

**Video Card Structure**:
```html
<div class="video-card">
  <img src="/ipfs/{thumbnail_cid}" />
  <div class="video-info">
    <h3>{title}</h3>
    <p>{uploader}</p>
    <span>{duration_formatted}</span>
  </div>
</div>
```

**JavaScript Functions**:
- `loadVideos()`: Fetches videos from `/youtube` API
- `renderVideoGrid()`: Renders video cards
- `openVideoInTheater()`: Opens video in theater mode
- `toggleVideoPlayer()`: Inline video player toggle
- `applyFilters()`: Applies search/filter criteria
- `showMapView()`: Displays geographic map
- `loadAllVideoStats()`: Loads engagement statistics for all videos
- `loadNetworkVideos()`: Loads videos from N² network

**Enhanced Features**:
- Real-time engagement stats on video cards (likes, comments, shares)
- Theater mode integration (double-click video to open)
- NOSTR authentication for likes, comments, bookmarks
- Network-based video recommendations

---

## Workflow Examples

### Example 1: Upload YouTube Liked Video

```bash
# 1. User uploads YouTube cookie
curl -X POST https://uplanet.com/api/fileupload \
  -F "file=@youtube_cookies.txt" \
  -F "npub={npub}"

# 2. Automatic sync runs (via cron)
./youtube.com.sh player@example.com

# 3. Script downloads video and uploads to IPFS
# 4. Video is published as NOSTR event (kind 21)
# 5. Video appears in /youtube interface
```

### Example 2: Record and Publish Webcam Video

```javascript
// 1. Connect to NOSTR (browser)
await handleNostrConnect();

// 2. Record video (3-30 seconds)
const videoBlob = await recordWebcam();

// 3. Upload to IPFS
const uploadResponse = await fetch('/api/fileupload', {
    method: 'POST',
    body: formData  // includes video file and npub
});

const { new_cid } = await uploadResponse.json();

// 4. Publish to NOSTR
const publishResponse = await fetch('/webcam', {
    method: 'POST',
    body: publishFormData  // includes CID, title, location
});
```

### Example 3: View Videos by Channel

```bash
# 1. Fetch channel from NOSTR
curl "https://uplanet.com/youtube?channel=MyChannel&html=1"

# 2. Or via API
curl "https://uplanet.com/youtube?channel=MyChannel" | jq '.channels.MyChannel'
```

### Example 4: Search Videos by Location

```bash
# Find videos within 5km of Paris
curl "https://uplanet.com/youtube?lat=48.8566&lon=2.3522&radius=5"
```

---

## Data Flow

### Upload Flow

```
User Action
    │
    ├─► [Webcam Recording] ──┐
    │                        │
    └─► [File Upload] ───────┼──► /api/fileupload
                             │         │
                             │         ├─► NIP-42 Auth Check
                             │         ├─► File Type Detection
                             │         ├─► Save to uDRIVE
                             │         └─► IPFS Upload
                             │              │
                             │              └─► Returns CID
                             │
                             └──► POST /webcam
                                      │
                                      ├─► Extract Metadata (ffprobe)
                                      ├─► Generate Thumbnail
                                      ├─► Build NOSTR Tags
                                      └─► Publish Event (kind 21/22)
                                           │
                                           └─► Relay Storage
```

### Discovery Flow

```
User Request
    │
    └─► GET /youtube?channel=X&search=Y
           │
           ├─► create_video_channel.py
           │     │
           │     ├─► Fetch from NOSTR Relay
           │     │     └─► Filter kind 21/22
           │     │
           │     └─► Extract Video Metadata
           │
           ├─► Apply Filters (channel, search, location)
           │
           ├─► Group by Channel
           │
           └─► Return JSON/HTML
                │
                └─► youtube.html renders video grid
```

---

## Astroport Swarm Integration & NIP-101 Protocol

Nostr Tube leverages the **Astroport swarm network** and **NIP-101 protocol** for decentralized video distribution, identity management, and geographic coordination.

### NIP-101 Integration

**NIP-101** (UPlanet: Decentralized Identity & Geographic Coordination) is applied to Nostr Tube through:

1. **Hierarchical GeoKeys**: Geographic coordinate-based Nostr keypairs (UMAP, SECTOR, REGION) for location-based video discovery
2. **DID Documents** (kind 30800): W3C-compliant decentralized identities linked to video creators
3. **Constellation Synchronization**: Automatic event sync across Astroport relay network using NIP-101's synchronization protocol

### Protocol N² (Network of Networks)

Nostr Tube implements the **N² protocol** for social graph-based video discovery:

- **N1 (Friends)**: Videos from direct connections (kind 3 contact lists) are prioritized in recommendations
- **N2 (Friends of Friends)**: Videos from extended network (2nd degree) appear in discovery feed
- **Constellation Sync**: `backfill_constellation.sh` synchronizes events across N² network using NIP-101's event kind list

**Event Kinds Synchronized** (per NIP-101):
- Core: 0, 1, 3, 5, 6, 7
- Media: 21, 22 (videos)
- Content: 30023, 30024
- Identity: 30800 (DID Documents)
- Oracle: 30500-30503 (Permit system)
- ORE: 30312-30313 (Environmental verification)
- **Total: 18 event types** automatically synchronized across constellation

### Swarm Discovery (`_12345.sh`)
- Each Astroport node publishes its services via IPNS in `12345.json`
- Contains: `myIPFS` (gateway), `myRELAY` (NOSTR), `myAPI` (UPassport), `ipfsnodeid`
- Swarm map stored in: `~/.zen/tmp/swarm/{ipfsnodeid}/`
- Two swarm levels:
  - **UPlanet ORIGIN**: Public swarm (all Astroport nodes)
  - **UPlanet ẐEN**: Private swarm (cooperative members only)

### Constellation Synchronization (`backfill_constellation.sh`)
- **Implements NIP-101 synchronization protocol** across Astroport relays
- Synchronizes NOSTR events (including video events kind 21/22) across swarm
- Discovers peers via IPNS swarm map
- Uses IPFS P2P tunnels for localhost relays (via `DRAGON_p2p_ssh.sh`)
- Targets constellation members (friends N1 and friends of friends N2) per N² protocol
- Video events are automatically synchronized from swarm peers
- Also synchronizes NIP-101 events (kind 30800, 30500-30503, 30312-30313) for identity and geographic coordination

### Video Gateway Selection
- Videos are served from Astroport IPFS gateways in the same swarm
- Gateway URLs discovered from `12345.json` files in swarm directory
- Local gateway preferred: `http://127.0.0.1:8080`
- Fallback to swarm peers: `https://ipfs.{domain}` from discovered nodes

## NOSTR Event Standards

### NIP-101 Integration

Nostr Tube events are synchronized across Astroport relays according to **NIP-101's Constellation Synchronization** protocol:

**Synchronized Event Kinds**:
- **Core Events**: 0 (Metadata), 1 (Text Notes), 3 (Contact Lists), 5 (Events), 6 (Reposts), 7 (Reactions)
- **Video Events**: 21 (Normal Videos), 22 (Short Videos) - NIP-71
- **Content**: 30023 (Long-form), 30024 (Article)
- **Identity**: 30800 (DID Documents) - NIP-101
- **Oracle**: 30500-30503 (Permit System) - NIP-101
- **ORE**: 30312-30313 (Environmental Verification) - NIP-101

All events are authenticated via **NIP-42** and synchronized through the N² network (friends N1, friends of friends N2).

### NIP-71 Video Events

**Kind 21** (Normal Videos):
- Horizontal/landscape videos
- Longer format content
- Standard viewing experience

**Kind 22** (Short Videos):
- Vertical/portrait videos
- Short-form content (≤60 seconds)
- Stories/reels/shorts format

### Required Tags

- `title`: Video title (required)
- `url`: Primary video URL (IPFS or HTTP) (required)
- `m`: Media type, e.g., `video/mp4`, `video/webm` (required)
  - **Automatic detection** by `upload2ipfs.sh` from file content
  - **Priority**: file magic bytes → file extension → `video/mp4` (default)
  - **For MP4 files**: Will be `video/mp4` (not `video/webm`)
- `published_at`: Unix timestamp (required)
- **`x`**: SHA-256 file hash (required for provenance & deduplication)
- **`info`**: CID of info.json (required for metadata reuse)

### Recommended Tags

- `duration`: Duration in seconds
- `dim`: Video dimensions (e.g., `1920x1080`)
- `image`: Thumbnail URL
- `imeta`: NIP-71 metadata tag with full specs
- `g`: Geographic coordinates (UMAP)
- `Channel-*`: Channel grouping
- `Topic-*`: Topic/keyword tags
- **`upload_chain`**: Distribution chain (pubkeys of uploaders)
- **`e`**: Original event ID (for re-uploads, provenance tracking)
- **`p`**: Original author pubkey (for re-uploads, copyright respect)

### Optional Tags

- `alt`: Accessibility description
- `content-warning`: NSFW warning
- `text-track`: Subtitles/captions (WebVTT)
- `p`: Participant pubkeys
- `r`: Reference links
- `t`: Hashtags

---

## Provenance & Deduplication System 🔐

Nostr Tube implements a comprehensive **provenance tracking and deduplication system** to ensure content integrity, avoid redundant uploads, and respect copyright.

### Key Features

#### 1. File Hash (SHA-256)
- Every file uploaded gets a **SHA-256 hash** calculated by `upload2ipfs.sh`
- Hash is stored in NOSTR event tag: `["x", "sha256_hash"]`
- Enables **client-side deduplication**: identical files are detected before upload
- Published in both:
  - Direct tag: `["x", "hash"]` for quick lookup
  - `imeta` tag: For NIP-71 compatibility

#### 2. Info.json CID
- Complete metadata stored in IPFS as `info.json`
- Includes: duration, dimensions, codecs, thumbnails, animated GIF CIDs
- Tag: `["info", "QmInfoCID"]`

**Format Standardization (v2.0)**:

NostrTube uses a **standardized `info.json` v2.0 format** for metadata:

- **Base structure**: `protocol`, `file`, `ipfs`, `metadata`, `nostr`
- **Media-specific**: `media` section with camelCase fields (v2.0)
  - Object-based dimensions: `{width, height, aspectRatio}`
  - Nested codecs: `{video, audio}`
  - Thumbnails object: `{static, animated}`
- **Source attribution**: `source.youtube` or `source.tmdb` for external content (v2.0)
- **Provenance tracking**: `provenance.uploadChain` with timestamps (v2.0)
- **Backward compatible**: Clients support both v1.0 (snake_case, flat) and v2.0 (camelCase, nested)

📖 **See**: [INFO_JSON_FORMATS.md](INFO_JSON_FORMATS.md) for complete specification

**Format varies by media type and source**:
  - **Video (webcam/personal)**: Base + `media` section
  - **Video (Film/Serie)**: Base + `media` + `source.tmdb`
  - **Video (YouTube)**: Base + `media` + `source.youtube`
  - **Audio (MP3)**: Base + `media` (audio-specific)
  - **Image**: Base + `image` section
  - **PDF/Document**: Base structure only
  - **Re-uploads**: All above + `provenance` section
- **Benefits**:
  - Avoids redundant metadata extraction (expensive ffprobe operations)
  - Enables instant metadata reuse on re-uploads
  - Centralized source of truth for file metadata

#### 3. Upload Chain
- **Distribution tracking**: Records all users who have uploaded this file
- Format: `["upload_chain", "pubkey1,pubkey2,pubkey3"]`
- Shows propagation path through the network
- First pubkey = original uploader
- Subsequent pubkeys = redistributors (sharing via their nodes)

#### 4. Provenance References
- `["e", "original_event_id"]`: Links to the first NOSTR event for this file
- `["p", "original_author_pubkey"]`: Credits the original uploader
- Enables:
  - **Copyright respect**: Original creator is always visible
  - **Content verification**: Users can verify file authenticity
  - **Social graph tracking**: See who in your network shared this content

### Workflow Example

**Alice uploads a video:**
```json
{
  "kind": 21,
  "pubkey": "alice_pubkey",
  "tags": [
    ["x", "abc123hash..."],
    ["info", "QmAliceInfo..."],
    ["upload_chain", "alice_pubkey"]
  ]
}
```

**Bob uploads the SAME video (detected by hash):**
```bash
# upload2ipfs.sh detects existing hash in relay
# OPTIMIZATION: Uses direct tag filter (#x) instead of fetching all events
# Query: kind=21&22, #x=abc123hash, limit=1
# This is ~1000x faster than client-side filtering!
# Reuses Alice's IPFS CID (main file)
# Creates NEW info.json with updated provenance (new CID)
# No redundant upload to IPFS for main file!
```

```json
{
  "kind": 21,
  "pubkey": "bob_pubkey",
  "tags": [
    ["x", "abc123hash..."],  // Same hash
    ["info", "QmBobInfo..."],  // NEW info.json (with updated upload_chain)
    ["upload_chain", "alice_pubkey,bob_pubkey"],  // Bob added to chain
    ["e", "alice_event_id"],  // Reference to Alice's event
    ["p", "alice_pubkey"]  // Credit to Alice
  ]
}
```

**Note**: The main file CID is reused, but a **new info.json is created** with updated timestamp and upload_chain. This allows the upload history to evolve with each re-publication.

### Implementation

**Backend** (`upload2ipfs.sh`):
1. Calculate SHA-256 hash **before** IPFS operations
2. Search relay for existing events with same hash:
   - **OPTIMIZATION**: Uses NIP-01 tag filters (`#x`) for direct server-side filtering
   - Videos: `--kind 21 --tag-x <hash> --limit 1` and `--kind 22 --tag-x <hash> --limit 1`
   - Documents: `--kind 1063 --tag-x <hash> --limit 1`
   - **Performance**: ~1000x faster than fetching all events and filtering client-side
   - **Bandwidth**: Queries return only matching event instead of 1000+ events
3. If found:
   - **Skip `ipfs add`** (file already exists)
   - Use `ipfs get` to fetch existing CID locally (pins automatically)
   - Reuse `info.json` CID for metadata
   - Append current user to `upload_chain`
4. If not found:
   - Upload to IPFS normally
   - Create new `info.json`
   - Initialize `upload_chain` with current user

**Frontend** (`youtube.enhancements.js`):
- `extractVideoMetadata()`: Extracts provenance tags from events
- `loadTheaterProvenance()`: Displays provenance in theater mode
- Shows:
  - File hash (for verification)
  - Link to info.json (view full metadata)
  - Distribution chain (visual badges)
  - Original uploader (if re-upload)

### Benefits

✅ **Bandwidth Savings**: Identical files uploaded only once to IPFS  
✅ **Storage Efficiency**: Main file CID reused, no duplicate uploads  
✅ **Copyright Respect**: Original creator always credited  
✅ **Content Verification**: Users can verify file authenticity via hash  
✅ **Network Transparency**: See distribution path through network  
✅ **Faster Uploads**: Re-uploads are near-instant (no IPFS operations for main file)  
✅ **Living History**: Each re-publication creates new info.json with updated timestamp and upload_chain  
✅ **Event Evolution**: Upload history evolves with new NOSTR events while reusing same file CID  

### Re-publication Behavior

When a user re-uploads an **identical file** (same SHA-256 hash):

**What is reused:**
- ✅ Main file CID (no redundant IPFS upload)
- ✅ Thumbnail CID (if available from original)
- ✅ Animated GIF CID (if available from original)
- ✅ Video metadata (duration, dimensions, codecs) - extracted from original info.json

**What is created new:**
- 🆕 **New NOSTR event** (kind 21/22) with new event ID
- 🆕 **New info.json** with:
  - Updated timestamp (`"date": "2025-11-06 01:30 +0000"`)
  - Updated upload chain (`"upload_chain": "alice_pubkey,bob_pubkey"`)
  - Reference to original event (`"original_event_id": "..."`)
  - Same file CID but new metadata document
- 🆕 **New info.json CID** (because content changed)

**Why this matters:**
- 📜 **History tracking**: Each re-publication is visible in the relay
- 🔗 **Chain evolution**: Upload chain grows with each redistribution
- 🕐 **Temporal context**: Timestamps show when each user shared the content
- 🎯 **Event-based discovery**: Users can find the same content via different events
- 🌐 **Network propagation**: See how content spreads through the N² network

**Example timeline:**
```
Day 1: Alice uploads video → CID: QmABC123, info.json: QmINFO1, event: evt_alice
Day 5: Bob re-uploads → CID: QmABC123 (reused), info.json: QmINFO2 (new), event: evt_bob
Day 9: Carol re-uploads → CID: QmABC123 (reused), info.json: QmINFO3 (new), event: evt_carol
```

Result: **1 file on IPFS, 3 events in NOSTR, 3 info.json documents tracking distribution**

### Security Considerations

- **Hash Collision**: SHA-256 provides 256-bit security (practically impossible to forge)
- **Metadata Integrity**: Info.json is content-addressed (CID = hash of content)
- **Event Authenticity**: All NOSTR events signed by uploader's private key
- **Trust Model**: Users trust their N² network (friends & friends of friends)

---

## Storage Structure

### uDRIVE Organization

```
~/.zen/game/nostr/{hex_pubkey}/
├── .cookie.txt                    # YouTube cookies (Netscape format)
├── .secret.nostr                  # NOSTR private key
├── .last_youtube_sync             # Last sync timestamp
├── .processed_youtube_videos      # Processed video IDs
└── APP/
    └── uDRIVE/
        ├── Videos/                # Video files
        │   ├── video1.mp4
        │   └── video2.webm
        ├── Music/                 # Audio files
        │   └── ArtistName/
        │       └── song.mp3
        ├── Images/                # Images
        ├── Documents/             # Documents
        └── Apps/                  # Applications
```

### IPFS Structure

Videos are stored in IPFS with content addressing:
- CID format: `Qm{hash}`
- URL format: `/ipfs/{cid}/{filename}`
- Thumbnails: Separate IPFS uploads

---

## Security & Authentication

### NIP-42 Authentication

All uploads require NIP-42 authentication:

1. **Client**: Connects to relay and sends `AUTH` event
2. **Relay**: Challenges with random message
3. **Client**: Signs challenge and sends response
4. **Server**: Verifies signature via `verify_nostr_auth()`

**Implementation**:
```python
async def verify_nostr_auth(npub: Optional[str]) -> bool:
    if not npub:
        return False
    
    relay_url = get_nostr_relay_url()
    return await check_nip42_auth(npub, timeout=5)
```

### Cookie Security

- Cookie files are **NOT** uploaded to IPFS
- Stored locally: `~/.zen/game/nostr/{hex}/.domain.cookie`
- Used only for Domain authentication
- Is kept private

---

## Geographic Anchoring (UMAP) - NIP-101

Videos can be anchored to geographic locations using **NIP-101's UMAP system**:

### UMAP Grid Levels (NIP-101)

| Level | Precision | Area Size | Use Case |
|-------|-----------|-----------|----------|
| **UMAP** | 0.01° | ~1.2 km² | Neighborhood-level video discovery |
| **SECTOR** | 0.1° | ~100 km² | City-level video grouping |
| **REGION** | 1.0° | ~10,000 km² | Regional video collections |

### Tag Format (NIP-101 Compatible)
- `g`: `"lat,lon"` (e.g., `["g", "48.8566,2.3522"]`) - Primary geographic tag
- `latitude`: Separate latitude tag (FLOAT_STRING)
- `longitude`: Separate longitude tag (FLOAT_STRING)
- `application`: `"UPlanet"` (identifies UPlanet/NIP-101 events)

**Use Cases**:
- Location-based video discovery
- UMAP visualization
- Geographic filtering in `/youtube` API
- Integration with NIP-101 ORE system (environmental verification at location)
- Local community video feeds (N² network filtered by UMAP)

**Example**:
```json
["g", "48.8566,2.3522"],
["latitude", "48.8566"],
["longitude", "2.3522"],
["application", "UPlanet"],
["location", "48.86,2.35"]
```

### Geographic Video Discovery

Videos tagged with UMAP coordinates can be discovered by:
1. **UMAP-level feeds**: Subscribe to videos from specific neighborhood (0.01° precision)
2. **SECTOR-level feeds**: Browse videos from entire city area (0.1° precision)
3. **REGION-level feeds**: Explore videos from regional collection (1.0° precision)
4. **N² Network filtering**: Combine geographic tags with social graph (friends N1/N2 in same UMAP)

---

## API Endpoints Summary

| Endpoint | Method | Auth | Description |
|----------|--------|------|-------------|
| `/youtube` | GET | No | List videos (with filters) |
| `/theater` | GET | No | Theater mode modal template |
| `/playlist` | GET | No | Playlist manager interface |
| `/webcam` | GET | No | Webcam recording interface |
| `/webcam` | POST | NIP-42 | Publish video to NOSTR |
| `/api/fileupload` | POST | NIP-42 | Upload file to IPFS |
| `/api/delete` | POST | NIP-42 | Delete file from uDRIVE |
| `/cookie` | GET | NIP-42 | Cookie upload guide |

---

## Troubleshooting

### Video Not Appearing in `/youtube`

1. **Check NOSTR Event**:
   - Verify event is kind 21 or 22
   - Ensure `url` tag contains IPFS/YouTube URL
   - Ensure `m` tag indicates video type

2. **Check Relay Connection**:
   - Local relay: `ws://127.0.0.1:7777` (strfry on local node)
   - Swarm relays: Check `~/.zen/tmp/swarm/*/12345.json` for `myRELAY` entries
   - Constellation sync: Verify `backfill_constellation.sh` is running to sync from swarm peers
   - Events must be published successfully

3. **Check Tags**:
   - `create_video_channel.py` filters incompatible events
   - Check logs: `~/.zen/tmp/IA.log`

### YouTube Sync Not Working

1. **Cookie File**:
   - Verify cookie file format (Netscape, tab-separated)
   - Check file location: `~/.zen/game/nostr/{hex}/.cookie.txt`
   - Test with `--debug` flag

2. **Rate Limiting**:
   - YouTube may rate-limit requests
   - Sync runs max once per day
   - Max 2 videos processed per sync

3. **yt-dlp Issues**:
   - Update `yt-dlp`: `pip install -U yt-dlp`
   - 20H12 process takes care about it

### IPFS Upload Fails

1. **IPFS Daemon**:
   - Ensure IPFS daemon is running: `ipfs daemon`
   - Check IPFS version: `ipfs version`

2. **File Size**:
   - Videos max 500MB (webcam upload)
   - YouTube downloads: max 3 hours duration

3. **Disk Space**:
   - Check available space: `df -h`
   - Minimum 1GB required for sync

---

## Enhanced UX Features (Implemented)

Nostr Tube includes advanced UX features to provide a unique and engaging video experience:

### User Tags & Tag Cloud 🏷️
- **Community-driven tagging**: Users can add tags to any video (NIP-32 Labeling)
- **Tag cloud visualization**: Display most popular tags with size-based weighting
- **Tag-based search**: Find videos by user-contributed tags (single or multiple tags with AND/OR operators)
- **Tag aggregation**: See which tags are most popular across all videos
- **Tag management**: Users can add/remove their own tags
- **Standards-compliant**: Uses NIP-32 (Labeling) for tag events (kind 1985)
- **See**: `nostr-nips/71-video-user-tags-extension.md` for full specification

### Theater Mode 🎬
- **Full-screen immersive viewing** with integrated comments panel
- **Real-time comments** with timestamp support (jump to specific moments)
- **Comment timeline** showing markers on video progress bar
- **Live chat** during playback via NOSTR relay WebSocket
- **Related videos** automatically displayed
- **Picture-in-Picture** mode support
- **Provenance Display**: Shows file hash, info.json link, distribution chain, and original uploader
- **Template**: `theater-modal.html` (route: `/theater`)

### Engagement Statistics 📊
- **Real-time stats** displayed on video thumbnails (likes, comments, shares)
- **Live updates** when reactions occur
- **Engagement badges** for trending content
- Integrated with NOSTR reactions (kind 7) and comments

### Playlists 📋
- **Create and manage** video playlists (NIP-51 kind 10001)
- **Add videos** to playlists directly from theater mode
- **Share playlists** with NOSTR links
- **Template**: `playlist-manager.html` (route: `/playlist`)

### N² Network Recommendations 🔗
- **Personalized feed** based on social graph (Protocol N²)
- **Videos from friends** (N1) prioritized - uses NOSTR contact lists (kind 3)
- **Videos from friends of friends** (N2) in discovery section
- **Geographic filtering**: Combines N² network with UMAP tags (NIP-101) for local video discovery
- **Constellation sync**: Events automatically synchronized across N² network via NIP-101 protocol
- **Relay synchronization**: Uses `backfill_constellation.sh` to sync events across Astroport relays

### Enhanced Video Actions 🎯
- **Share with preview** modal showing video card
- **Custom messages** and tags when sharing
- **Copy shareable links** with metadata
- **Bookmark** with custom notes
- All integrated with NOSTR events

### Comment Timeline ⏱️
- **Visual markers** on video progress bar for comments
- **Click to jump** to specific timestamps
- **Submit comments** at current playback position
- Timeline overlay with tooltips

### Related Videos 🔄
- **Same channel** videos
- **Similar tags** matching
- **Same location** (UMAP) videos
- **Videos liked by same users**
- Displayed in theater mode sidebar

## Implementation Files

### Core JavaScript
- **`UPlanet/earth/youtube.enhancements.js`**: All UX enhancement functions
  - Theater mode, VideoStats, LiveVideoChat, Playlists, Related videos, etc.
- **`UPlanet/earth/common.js`**: Core NOSTR functions (already exists)

### Templates
- **`UPassport/templates/youtube.html`**: Main video interface with all enhancements integrated
- **`UPassport/templates/theater-modal.html`**: Theater mode template
- **`UPassport/templates/playlist-manager.html`**: Playlist management interface

### Routes (54321.py)
- **`GET /theater`**: Theater mode modal template
- **`GET /playlist`**: Playlist manager interface
- **`GET /youtube`**: Main video browsing interface

### Integration
All enhancements are loaded via:
```html
<script src="{{ myIPFS }}/ipns/copylaradio.com/nostr.bundle.js"></script>
<script src="{{ myIPFS }}/ipns/copylaradio.com/common.js"></script>
<script src="{{ myIPFS }}/ipns/copylaradio.com/youtube.enhancements.js"></script>
<link rel="stylesheet" href="{{ myIPFS }}/ipns/copylaradio.com/youtube.enhancements.css" />
```

## Future Enhancements

- [ ] **Video Analytics Dashboard**: Creator analytics with views, engagement, geographic distribution
- [ ] **Subtitles**: Automatic subtitle generation and NOSTR-based subtitle tracks
- [ ] **Transcoding**: Multiple quality/format variants for adaptive streaming
- [ ] **Live Streaming**: Real-time video streaming via NOSTR (WebRTC integration)
- [ ] **Video Chapters**: Timestamped chapter markers with titles
- [ ] **Collaborative Playlists**: Shared playlists with multiple contributors
- [ ] **Monetization**: Lightning payments for video creators

---

## NOSTR Event Kinds Used

### Video & Content Events

| Kind | Purpose | Description | NIP Standard |
|------|---------|-------------|--------------|
| **Kind 1** | Text Notes | Video posts, comments, shares | NIP-01 |
| **Kind 7** | Reactions | Likes and reactions on videos | NIP-25 |
| **Kind 21/22** | Video Events | Video content (NIP-71) - 21 for regular, 22 for short videos | NIP-71 |
| **Kind 10001** | Playlists | Video playlists (NIP-51 Lists) | NIP-51 |
| **Kind 30001** | Bookmarks | Video bookmarks | NIP-51 |
| **Kind 3** | Contact Lists | Used for N² network recommendations | NIP-02 |
| **Kind 1985** | User Tags | User-generated tags for videos (NIP-32 Labeling) | NIP-32 |

### NIP-101 Events (Identity & Geographic Coordination)

| Kind | Purpose | Description | Sync |
|------|---------|-------------|------|
| **Kind 30800** | DID Documents | W3C-compliant decentralized identities for video creators | ✅ Constellation |
| **Kind 30500** | Permit Definitions | License/permit type definitions for ORE verifiers | ✅ Constellation |
| **Kind 30501** | Permit Requests | User applications for permits/credentials | ✅ Constellation |
| **Kind 30502** | Permit Attestations | Peer attestations for permit applicants | ✅ Constellation |
| **Kind 30503** | Permit Credentials | W3C Verifiable Credentials issued by Oracle | ✅ Constellation |
| **Kind 30312** | ORE Meeting Spaces | Geographic spaces for environmental verification | ✅ Constellation |
| **Kind 30313** | ORE Verification Meetings | Completed environmental compliance verifications | ✅ Constellation |

**Constellation Synchronization**: All NIP-101 events (kinds 30800, 30500-30503, 30312-30313) are automatically synchronized across Astroport relays via `backfill_constellation.sh` as part of the N² protocol.

## References

### NOSTR Improvement Proposals (NIPs)

- **NIP-01**: Basic protocol flow
- **NIP-02**: Contact Lists
- **NIP-25**: Reactions (likes)
- **NIP-32**: Labeling (user tags for videos - kind 1985)
- **NIP-42**: Relay Authentication (required for all uploads)
- **NIP-51**: Lists (playlists - kind 10001, bookmarks - kind 30001)
- **NIP-71**: Video Events specification (kinds 21/22)
- **NIP-71 Extension**: User Tags for Videos (`nostr-nips/71-video-user-tags-extension.md`)
- **NIP-92**: Media Metadata (imeta tags)
- **NIP-101**: UPlanet protocol - Decentralized Identity & Geographic Coordination
  - DID Documents (kind 30800)
  - Oracle System (kinds 30500-30503)
  - ORE System (kinds 30312-30313)
  - Constellation Synchronization
  - Hierarchical GeoKeys (UMAP, SECTOR, REGION)

### Additional Resources

- **MULTIPASS**: `make_NOSTRCARD.sh` documentation
- **UMAP**: Geographic anchoring system (defined in NIP-101)
- **Protocol N²**: Network of Networks for social graph-based discovery
- **Astroport Swarm**: Decentralized network of Astroport nodes

### NIP-101 Implementation

- **Main Repository**: [github.com/papiche/Astroport.ONE](https://github.com/papiche/Astroport.ONE)
- **NIP-101 Repository**: [github.com/papiche/NIP-101](https://github.com/papiche/NIP-101)
- **Documentation**: See `nostr-nips/101.md` in Astroport.ONE repository

---

## License

This documentation is part of the Astroport.ONE project and follows the project's licensing terms.

