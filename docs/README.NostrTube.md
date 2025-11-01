# Nostr Tube - Web3 Video Platform

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
- **UMAP**: Geographic anchoring of videos (latitude/longitude)

---

## Components

### 1. YouTube Synchronization (`sync_youtube_likes.sh`)

Synchronizes liked videos from YouTube to Nostr Tube.

**Location**: `Astroport.ONE/IA/sync_youtube_likes.sh`

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
./sync_youtube_likes.sh player@example.com

# Debug mode
./sync_youtube_likes.sh player@example.com --debug
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
./process_youtube.sh [--debug] <youtube_url> <format> [player_email]
```

**Features**:
- Downloads video in MP4 format (max 720p) or MP3
- Extracts metadata (title, duration, uploader)
- Validates video duration (max 3 hours)
- Uploads to IPFS via `ipfs add`
- Organizes files in uDRIVE structure:
  - Videos → `uDRIVE/Videos/`
  - Audio → `uDRIVE/Music/{artist}/`
- Returns JSON with IPFS URL and metadata

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

**NOSTR Event Structure** (NIP-71):

```json
{
  "kind": 21,  // or 22 for short videos (≤60s)
  "content": "🎬 Video Title\n\n📹 Webcam: /ipfs/QmHASH/video.mp4",
  "tags": [
    ["title", "Video Title"],
    ["url", "/ipfs/QmHASH/video.mp4"],
    ["m", "video/webm"],
    ["imeta", "dim 1280x720", "url /ipfs/QmHASH/video.mp4", "m video/webm"],
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
    ["r", "/ipfs/QmTHUMBNAIL/thumb.jpg", "Thumbnail"]
  ]
}
```

**Video Kind Selection**:
- `kind: 21`: Regular videos (>60 seconds)
- `kind: 22`: Short videos (≤60 seconds)

**Tags Explained**:
- `title`: Video title
- `url`: IPFS URL (required for `create_video_channel.py`)
- `m`: Media type (`video/webm`, `video/mp4`)
- `imeta`: NIP-71 metadata tag with dimensions and URL
- `duration`: Video duration in seconds
- `g`: Geohash tag (latitude,longitude) for UMAP anchoring
- `Channel-*`: Channel grouping tag
- `Topic-*`: Topic/keyword tags for categorization
- `image`: Thumbnail IPFS URL

**Publishing Script**:
- Uses `~/.zen/Astroport.ONE/tools/nostr_send_note.py`
- Supports multiple relays: `ws://127.0.0.1:7777,wss://relay.copylaradio.com`
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
- Auto-detects best IPFS gateway for video playback
- Supports multiple gateways: `ipfs.io`, `gateway.pinata.cloud`, `dweb.link`
- Falls back to local gateway if available

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
./sync_youtube_likes.sh player@example.com

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

## NOSTR Event Standards

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
- `m`: Media type, e.g., `video/webm` (required)
- `published_at`: Unix timestamp (required)

### Recommended Tags

- `duration`: Duration in seconds
- `dim`: Video dimensions (e.g., `1920x1080`)
- `image`: Thumbnail URL
- `imeta`: NIP-71 metadata tag with full specs
- `g`: Geographic coordinates (UMAP)
- `Channel-*`: Channel grouping
- `Topic-*`: Topic/keyword tags

### Optional Tags

- `alt`: Accessibility description
- `content-warning`: NSFW warning
- `text-track`: Subtitles/captions (WebVTT)
- `p`: Participant pubkeys
- `r`: Reference links
- `t`: Hashtags

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
- Stored locally: `~/.zen/game/nostr/{hex}/.cookie.txt`
- Used only for YouTube authentication
- Should be kept private (file permissions: 600)

---

## Geographic Anchoring (UMAP)

Videos can be anchored to geographic locations:

**Tag Format**:
- `g`: `"lat,lon"` (e.g., `["g", "48.8566,2.3522"]`)
- `latitude`: Separate latitude tag
- `longitude`: Separate longitude tag
- `location`: Human-readable location

**Use Cases**:
- Location-based video discovery
- UMAP visualization
- Geographic filtering in `/youtube` API

**Example**:
```json
["g", "48.8566,2.3522"],
["latitude", "48.8566"],
["longitude", "2.3522"],
["location", "48.86,2.35"]
```

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
| `/cookie` | GET | No | Cookie upload guide |

---

## Troubleshooting

### Video Not Appearing in `/youtube`

1. **Check NOSTR Event**:
   - Verify event is kind 21 or 22
   - Ensure `url` tag contains IPFS/YouTube URL
   - Ensure `m` tag indicates video type

2. **Check Relay Connection**:
   - Relay must be accessible: `ws://127.0.0.1:7777`
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
   - Check YouTube API changes

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

### Theater Mode 🎬
- **Full-screen immersive viewing** with integrated comments panel
- **Real-time comments** with timestamp support (jump to specific moments)
- **Comment timeline** showing markers on video progress bar
- **Live chat** during playback via NOSTR relay WebSocket
- **Related videos** automatically displayed
- **Picture-in-Picture** mode support
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
- **Personalized feed** based on social graph
- **Videos from friends** (N1) prioritized
- **Videos from friends of friends** (N2) in discovery section
- Uses NOSTR contact lists (kind 3) to build network graph

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

| Kind | Purpose | Description |
|------|---------|-------------|
| **Kind 1** | Text Notes | Video posts, comments, shares |
| **Kind 7** | Reactions | Likes and reactions on videos |
| **Kind 21/22** | Video Events | Video content (NIP-71) - 21 for regular, 22 for short videos |
| **Kind 10001** | Playlists | Video playlists (NIP-51 Lists) |
| **Kind 30001** | Bookmarks | Video bookmarks |
| **Kind 3** | Contact Lists | Used for N² network recommendations |

## References

- **NIP-71**: Video Events specification
- **NIP-42**: Relay Authentication
- **NIP-51**: Lists (playlists)
- **NIP-92**: Media Metadata (imeta tags)
- **MULTIPASS**: `make_NOSTRCARD.sh` documentation
- **UMAP**: Geographic anchoring system

---

## License

This documentation is part of the Astroport.ONE project and follows the project's licensing terms.

