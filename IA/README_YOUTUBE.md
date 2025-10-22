# YouTube Download System - Documentation

## 🎯 Overview

The YouTube download system provides **two modes** for downloading YouTube videos via UPlanet:

1. **Manual Download** (`#youtube` tag) - On-demand video downloads
2. **Automatic Sync** - Daily synchronization of liked videos via NOSTR refresh cycle

## 🔧 How It Works

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
3. **YouTube Sync Trigger** - If cookies exist, launches `sync_youtube_likes.sh`
4. **Liked Videos Fetch** - Retrieves up to 3 new liked videos from YouTube
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

The system expects **Netscape cookie format**:

```
# Netscape HTTP Cookie File
.youtube.com	TRUE	/	TRUE	2147483647	CONSENT	YES+cb...
.youtube.com	TRUE	/	TRUE	2147483647	VISITOR_INFO1_LIVE	abc123...
```

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

```json
{
  "url": "/ipfs/QmHash...",
  "m": "video/mp4",
  "x": "sha256_hash",
  "size": "12345678",
  "duration": "120",
  "dim": "1920x1080"
}
```

## 📺 YouTube Channel Interface

### Access Your Videos

Once videos are downloaded and published as NOSTR events, you can access them via:

```
https://u.copylaradio.com/youtube
```

### Features

- **Video Gallery** - Browse all your downloaded videos
- **NOSTR Integration** - Like videos, view author profiles
- **Responsive Design** - Works on PC and mobile
- **IPFS Streaming** - Direct video playback from IPFS
- **Metadata Display** - Duration, file size, dimensions, keywords

## 🔗 Related Files

```
Astroport.ONE/IA/
├── process_youtube.sh           # Main YouTube download script
├── sync_youtube_likes.sh       # Automatic sync of liked videos
├── create_video_channel.py     # NIP-71 channel creation
├── UPlanet_IA_Responder.sh     # Calls process_youtube.sh when #youtube tag detected
└── README_YOUTUBE.md           # This file

Astroport.ONE/RUNTIME/
└── NOSTRCARD.refresh.sh        # Daily refresh cycle (triggers YouTube sync)

UPlanet/earth/
└── cookie.html                 # User guide for cookie export

UPassport/
├── templates/
│   ├── astro_base.html         # File upload interface (detects Netscape cookies)
│   └── youtube.html            # YouTube channel interface
└── 54321.py                    # API endpoint for /youtube route

~/.zen/
├── tmp/
│   ├── IA.log                  # Main log file
│   └── youtube_*/              # Temporary download directories
└── game/nostr/<email>/
    ├── .cookie.txt             # User-uploaded cookies (Netscape format)
    ├── .last_youtube_sync      # Last sync date tracking
    └── .processed_youtube_videos # Processed videos database
```

## 💡 Tips

1. **Cookie lifespan**: YouTube cookies typically last 1-3 months. Re-export when downloads start failing.

2. **Multiple users**: Each user can upload their own cookies. The system automatically uses cookies for the requesting user.

3. **Privacy**: Cookies are stored locally and only used for YouTube downloads. They're not shared or transmitted.

4. **Format detection**: `#youtube` defaults to MP4. Add `#mp3` for audio-only: `#youtube #mp3`

5. **Duration limit**: Videos longer than 3 hours are rejected to prevent resource exhaustion.

6. **Automatic sync**: Upload cookies once and your liked videos will sync automatically every day.

7. **NIP-71 compatibility**: All videos are published as NIP-71 events for maximum client compatibility.

8. **uDRIVE organization**: Videos are automatically organized in your personal uDRIVE storage.

9. **Email notifications**: You'll receive daily summaries of your YouTube sync results.

10. **Channel interface**: Access all your videos via the `/youtube` route with full NOSTR integration.

## 🔄 System Architecture

### Complete YouTube Integration Flow

```
User Uploads Cookies
        ↓
NOSTRCARD.refresh.sh (Daily)
        ↓
sync_youtube_likes.sh (Auto-triggered)
        ↓
process_youtube.sh (Video download)
        ↓
NOSTR Events (kind: 1 + NIP-71)
        ↓
create_video_channel.py (Channel creation)
        ↓
/youtube Interface (User access)
```

### Key Components

- **Cookie Upload**: `cookie.html` → `astro_base.html` → `.cookie.txt`
- **Daily Sync**: `NOSTRCARD.refresh.sh` → `sync_youtube_likes.sh`
- **Video Processing**: `process_youtube.sh` → IPFS → NOSTR
- **Channel Creation**: `create_video_channel.py` → NIP-71 events
- **User Interface**: `/youtube` route → `youtube.html`

## 🆘 Support

If you encounter issues:

1. Check logs: `./youtube_logs.sh -e`
2. Verify cookie file exists and is recent
3. Test with a different YouTube URL
4. Update yt-dlp: `pip install --upgrade yt-dlp`
5. Check IPFS: `ipfs id`
6. Check NOSTR relay: `ws://127.0.0.1:7777`
7. Verify uDRIVE directory exists: `~/.zen/game/nostr/<email>/APP/uDRIVE/`

For more help, contact: support@qo-op.com

