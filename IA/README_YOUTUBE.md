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
   - `g` tag: Geohash format (lat,lon) for UMAP anchoring
   - `location` tag: Human-readable coordinates
   - `latitude` and `longitude` tags: Individual coordinate tags
6. **uDRIVE Storage** - Video saved to `uDRIVE/Videos/` directory
7. **Geographic Discovery** - Videos searchable by location via `/youtube` route

### Manual Download Process Flow

1. **User sends message** with `#youtube` tag + YouTube URL
2. **UPlanet_IA_Responder.sh** detects the tag and calls `process_youtube.sh`
3. **process_youtube.sh** tries multiple cookie strategies:
   - **User-uploaded cookies** (`.cookie.txt` from astro_base interface)
   - **Browser cookies** (from Chrome, Firefox, Brave, Edge)
   - **Generated cookies** (basic fallback)
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

## 🍪 Cookie Management

### Why Cookies Are Needed

YouTube blocks bot requests. Fresh browser cookies allow ASTROBOT to download videos as if a real user is accessing them.

### How to Upload Cookies

1. **Export cookies** from your browser using the guide:
   ```
   https://ipfs.copylaradio.com/ipns/copylaradio.com/cookie.html
   ```

2. **Upload the file** via the ASTROBOT interface:
   ```
   https://u.copylaradio.com/astro
   ```

3. **System automatically detects** the Netscape format and saves to:
   ```
   ~/.zen/game/nostr/<your-email>/.cookie.txt
   ```

### Automatic Sync Activation

Once you upload cookies, the system automatically:

- **Detects your cookies** during daily NOSTR refresh cycle
- **Launches YouTube sync** for your liked videos
- **Downloads up to 3 new videos** per day
- **Organizes videos** in your uDRIVE
- **Publishes NOSTR events** for each video
- **Sends email notifications** with sync results

### Cookie File Format

The system expects **Netscape cookie format**. Cookies are automatically detected and stored as `.youtube.com.cookie` in your MULTIPASS directory.

> **📖 For complete cookie management documentation, see [COOKIE_SYSTEM.md](./COOKIE_SYSTEM.md)**

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
2. Upload via astro_base interface
3. Try again

### Issue 2: "Download or IPFS upload failed"

**Causes:**
- YouTube bot detection
- Network issues
- IPFS daemon not running
- Video too long (>3h limit)

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

## 📊 Debug Mode

Debug mode is **automatically enabled** in `UPlanet_IA_Responder.sh` for all YouTube downloads.

To manually enable debug mode:

```bash
# Debug enabled (verbose)
./process_youtube.sh --debug "https://youtube.com/watch?v=ABC123" mp4

# Debug disabled (quiet)
./process_youtube.sh "https://youtube.com/watch?v=ABC123" mp4
```

## 🎬 NIP-71 Video Events

### Event Types Published

The system publishes **two types** of NOSTR events for each video:

1. **Kind 1** - Text message (compatibility with older clients)
2. **Kind 21/22** - NIP-71 video events (modern standard)

### NIP-71 Classification

- **Kind 21** - Normal videos (duration > 30s, horizontal format)
- **Kind 22** - Short videos (duration ≤ 30s OR vertical/square format)

### NIP-71 Tags Structure

The system uses proper NIP-71 compliant tags with **geographic anchoring**:

```json
{
  "title": "Video Title",
  "imeta": [
    "dim 1920x1080",
    "url /ipfs/QmHash...",
    "x sha256_hash",
    "m video/mp4",
    "image /ipfs/thumbnail_hash",
    "fallback /ipfs/QmHash...",
    "service nip96"
  ],
  "duration": "120",
  "published_at": "1640995200",
  "alt": "Video Title by Author",
  "content-warning": "Adult content", // if applicable
  "t": ["YouTubeDownload", "VideoChannel", "Channel-AuthorName", "WebcamRecording"],
  "g": "48.86,2.35",           // NEW: Geohash for UMAP anchoring
  "location": "48.86,2.35",     // NEW: Human-readable location
  "latitude": "48.86",          // NEW: Separate latitude tag
  "longitude": "2.35",          // NEW: Separate longitude tag
  "r": [
    ["https://youtube.com/watch?v=...", "YouTube"],
    ["/ipfs/metadata_hash", "Metadata"],
    ["/ipfs/thumbnail_hash", "Thumbnail"]
  ]
}
```

#### NIP-71 Compliance Features

- **✅ Proper `imeta` tags** with space-separated properties
- **✅ Required `title` tag** for video identification
- **✅ `published_at` timestamp** for publication date
- **✅ `alt` tag** for accessibility
- **✅ `content-warning`** for NSFW content
- **✅ `fallback` URLs** for redundancy
- **✅ `service` tag** for NIP-96 compatibility
- **✅ Smart video classification** (kind 21/22 based on format and duration)
- **✅ Geographic tags** (`g`, `location`, `latitude`, `longitude`) for UMAP anchoring
- **✅ uDRIVE integration** for personal video storage

## 🔧 NIP-71 Compliance

### Full NIP-71 Implementation

Our YouTube download system is now **fully compliant** with NIP-71 Video Events specification:

#### ✅ **Required Elements**
- **Event Kinds**: Correctly uses `kind: 21` (normal) and `kind: 22` (short) videos
- **`title` tag**: Required video title for identification
- **`imeta` tags**: Primary source of video information with proper format
- **`published_at`**: Unix timestamp of video publication
- **`alt` tag**: Accessibility description for screen readers

#### ✅ **Enhanced Features**
- **Smart Classification**: Automatically determines video kind based on:
  - Vertical aspect ratio → kind 22 (short)
  - Square aspect ratio → kind 22 (short)  
  - Small dimensions (≤720p) → kind 22 (short)
  - Duration ≤30s for horizontal videos → kind 22 (short)
- **Redundancy**: Multiple `fallback` URLs for reliable video delivery
- **NIP-96 Compatibility**: `service` tag for decentralized storage
- **Content Warnings**: Automatic detection of NSFW content
- **Rich Metadata**: File size, dimensions, duration, and technical info

#### ✅ **Client Compatibility**
- **Video-focused clients**: Netflix, YouTube, TikTok-like NOSTR clients
- **Search functionality**: Proper tagging for video discovery
- **Accessibility**: Screen reader support with `alt` tags
- **Mobile optimization**: Responsive design for all devices

### Example NIP-71 Event

```json
{
  "kind": 21,
  "content": "🎬 How to Build a Blockchain\n\n📺 YouTube: https://youtube.com/watch?v=...\n🔗 IPFS: $myLIBRA/ipfs/QmHash...",
  "tags": [
    ["title", "How to Build a Blockchain"],
    ["imeta", "dim 1920x1080", "url /ipfs/QmHash...", "x sha256_hash", "m video/mp4", "image /ipfs/thumb_hash", "fallback /ipfs/QmHash...", "service nip96"],
    ["duration", "1200"],
    ["published_at", "1640995200"],
    ["alt", "How to Build a Blockchain by TechChannel"],
    ["t", "YouTubeDownload"],
    ["t", "VideoChannel"],
    ["t", "Channel-TechChannel"],
    ["r", "https://youtube.com/watch?v=...", "YouTube"]
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

- **Video Gallery** - Browse all downloaded and recorded videos
- **NOSTR Integration** - Like videos, view author profiles
- **Geographic Filtering** - Search videos by location (lat, lon, radius)
- **Responsive Design** - Works on PC and mobile
- **IPFS Streaming** - Direct video playback from IPFS
- **Metadata Display** - Duration, file size, dimensions, keywords, location
- **Channel Organization** - Videos grouped by uploader/creator

#### Geographic Search

Filter videos by location using URL parameters:

```
https://u.copylaradio.com/youtube?lat=48.86&lon=2.35&radius=10&html=1
```

Parameters:
- `lat`: Latitude (decimal degrees)
- `lon`: Longitude (decimal degrees)
- `radius`: Search radius in kilometers
- `html=1`: Return HTML view (required for web browser)

The system uses the Haversine formula to calculate geographic distances and filter videos within the specified radius.

### Webcam Recording Interface (`/webcam`)

Record or upload videos with geolocation:

```
https://u.copylaradio.com/webcam
```

#### Features

- **NOSTR Authentication** - Connect via browser extension or nsec key
- **Webcam Recording** - Direct browser recording (3-60 seconds)
- **File Upload** - Upload local video files (.mp4, .webm, .mov, max 500MB)
- **Geolocation** - Interactive map for location selection
- **Preview & Edit** - Review video before publishing
- **IPFS Upload** - Automatic upload via `/api/fileupload`
- **NIP-71 Publishing** - Creates proper video events with geographic tags
- **uDRIVE Storage** - Saves to personal `uDRIVE/Videos/` directory

#### Recording Workflow

1. **Connect NOSTR** - Authenticate with your NOSTR identity
2. **Choose Source**:
   - Record via webcam (adjustable duration)
   - Upload video file from device
3. **Preview** - Review video in modal
4. **Edit Metadata**:
   - Title (required)
   - Description (optional)
   - Geographic location (interactive map or manual input)
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

- **Cookie Upload**: `cookie.html` → `astro_base.html` → `.cookie.txt`
- **Daily Sync**: `NOSTRCARD.refresh.sh` → `youtube.com.sh` → `process_youtube.sh`
- **Webcam Recording**: `/webcam` → NOSTR auth → video capture → `/api/fileupload`
- **IPFS Upload**: `/api/fileupload` → `uDRIVE/Videos/` → IPFS CID
- **NOSTR Publishing**: `/webcam` route → NIP-71 event with geographic tags
- **Video Processing**: `process_youtube.sh` → IPFS → NOSTR → uDRIVE
- **Channel Parsing**: `create_video_channel.py` → Extract NIP-71 events with geolocation
- **User Interface**: `/youtube` route → `youtube.html` with geographic filtering
- **Geographic Discovery**: Haversine formula → filter videos by lat/lon/radius

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


4. Browser console: Check for JavaScript errors in geographic calculations

For more help, contact: support@qo-op.com


4. Browser console: Check for JavaScript errors in geographic calculations

For more help, contact: support@qo-op.com

