# YouTube Download System - Documentation

## 🎯 Overview

The YouTube download system (`#youtube` tag) allows users to download YouTube videos via UPlanet and ASTROBOT using `yt-dlp`.

## 🔧 How It Works

### Process Flow

1. **User sends message** with `#youtube` tag + YouTube URL
2. **UPlanet_IA_Responder.sh** detects the tag and calls `process_youtube.sh`
3. **process_youtube.sh** tries multiple cookie strategies:
   - **User-uploaded cookies** (`.cookie.txt` from astro_base interface)
   - **Browser cookies** (from Chrome, Firefox, Brave, Edge)
   - **Generated cookies** (basic fallback)
4. **yt-dlp** downloads the video/audio
5. **IPFS** uploads the media
6. **Response** sent back to user with IPFS link

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

## 🔗 Related Files

```
Astroport.ONE/IA/
├── process_youtube.sh           # Main YouTube download script
├── UPlanet_IA_Responder.sh      # Calls process_youtube.sh when #youtube tag detected
└── README_YOUTUBE.md            # This file

UPlanet/earth/
└── cookie.html                  # User guide for cookie export

UPassport/
└── templates/astro_base.html    # File upload interface (detects Netscape cookies)

~/.zen/
├── tmp/
│   ├── IA.log                   # Main log file
│   └── youtube_*/               # Temporary download directories
└── game/nostr/<email>/
    └── .cookie.txt              # User-uploaded cookies (Netscape format)
```

## 💡 Tips

1. **Cookie lifespan**: YouTube cookies typically last 1-3 months. Re-export when downloads start failing.

2. **Multiple users**: Each user can upload their own cookies. The system automatically uses cookies for the requesting user.

3. **Privacy**: Cookies are stored locally and only used for YouTube downloads. They're not shared or transmitted.

4. **Format detection**: `#youtube` defaults to MP4. Add `#mp3` for audio-only: `#youtube #mp3`

5. **Duration limit**: Videos longer than 3 hours are rejected to prevent resource exhaustion.

## 🆘 Support

If you encounter issues:

1. Check logs: `./youtube_logs.sh -e`
2. Verify cookie file exists and is recent
3. Test with a different YouTube URL
4. Update yt-dlp: `pip install --upgrade yt-dlp`
5. Check IPFS: `ipfs id`

For more help, contact: support@qo-op.com

