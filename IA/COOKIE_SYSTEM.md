# Universal Cookie Management System

## Overview

The `/api/fileupload` endpoint supports automatic detection and organization of cookie files for any website domain. Cookies are stored as **hidden files** (with leading dot) for better security and privacy.

## Features

✅ **Multi-Domain Support**: Automatically detects and organizes cookies by domain  
✅ **Hidden Files**: All cookies saved with leading dot (`.youtube.com.cookie`, `.leboncoin.fr.cookie`)  
✅ **Auto-Detection**: Recognizes Netscape HTTP Cookie File format  
✅ **Domain Extraction**: Parses cookie content to identify the source domain  
✅ **MULTIPASS Compatible**: Cookies stored in EMAIL-based MULTIPASS directories  

## Directory Structure

```
~/.zen/game/nostr/user@email.com/       # EMAIL-based directory (created by make_NOSTRCARD.sh)
├── .youtube.com.cookie                  # YouTube cookies only (single-domain, hidden file)
├── .leboncoin.fr.cookie                 # Leboncoin cookies only (single-domain, hidden file)
├── .amazon.fr.cookie                    # Amazon cookies only (single-domain, hidden file)
├── .[domain].cookie                     # Any single domain cookie (hidden file)
├── .cookie.txt                          # Multi-domain cookies OR legacy format (hidden file)
├── NPUB                                 # NOSTR public key (npub1..., stored as file)
├── HEX                                  # NOSTR public key (hex format, stored as file)
├── .secret.nostr                        # NOSTR private key (nsec, npub, hex - hidden)
└── APP/
    └── uDRIVE/
        ├── Videos/                      # Downloaded videos
        └── Music/                       # Downloaded music
```

**Notes:**
- `.{domain}.cookie` → Single-domain cookies (e.g., only youtube.com + subdomains)
- `.cookie.txt` → Multi-domain cookies (e.g., youtube.com + leboncoin.fr + amazon.fr) OR legacy format
- All cookie files are **hidden files** (starting with dot) at the root of user's EMAIL directory
- **Directory is always EMAIL-based**, NPUB/HEX are stored as files inside

## Cookie File Format

### Supported formats:
- **Netscape HTTP Cookie File** (recommended)
- Raw cookie string

### Cookie File Types:

#### 1. Single-Domain Cookies
If the uploaded file contains cookies for **one domain only** (or subdomains of the same domain), it's saved as:
- `.youtube.com.cookie` → All cookies are for youtube.com and subdomains
- `.leboncoin.fr.cookie` → All cookies are for leboncoin.fr and subdomains

#### 2. Multi-Domain Cookies
If the uploaded file contains cookies for **multiple different domains**, it's saved as:
- `.cookie.txt` → Full browser cookie export (e.g., youtube.com + leboncoin.fr + amazon.fr)

This is useful when exporting ALL your browser cookies at once.

### Example Netscape format:
```
# Netscape HTTP Cookie File
# https://curl.haxx.se/rfc/cookie_spec.html
# This is a generated file! Do not edit.

.leboncoin.fr	TRUE	/	TRUE	1796910450	__Secure-Install	uuid-value
.leboncoin.fr	TRUE	/	TRUE	1796910450	cnfdVisitorId	visitor-id
.leboncoin.fr	TRUE	/	TRUE	1793886482	datadome	token-value
```

## Upload Cookie

### Via API

```bash
curl -X POST 'http://localhost:54321/api/fileupload' \
  -F 'file=@/path/to/cookies.txt' \
  -F 'npub=npub1...'
```

### Response Examples

#### Single-Domain Cookie:
```json
{
  "success": true,
  "message": "Cookie file uploaded successfully for leboncoin.fr - Leboncoin scraping will now use your authentication",
  "file_path": "USER/.leboncoin.fr.cookie",
  "file_type": "netscape_cookies",
  "target_directory": "/home/user/.zen/game/nostr/USER",
  "new_cid": null,
  "timestamp": "2025-11-05T12:34:56",
  "auth_verified": true,
  "description": "Domain: leboncoin.fr"
}
```

#### Multi-Domain Cookie:
```json
{
  "success": true,
  "message": "Cookie file uploaded successfully for Multiple domains (full browser cookies) - All services will use your authentication",
  "file_path": "USER/.cookie.txt",
  "file_type": "netscape_cookies",
  "target_directory": "/home/user/.zen/game/nostr/USER",
  "new_cid": null,
  "timestamp": "2025-11-05T12:34:56",
  "auth_verified": true,
  "description": "Domain: multi-domain"
}
```

## Using Cookies

### 1. YouTube Sync (automatic)

```bash
bash sync_youtube_likes.sh user@email.com
```

Searches for (in order):
1. `~/.zen/game/nostr/user@email.com/.youtube.com.cookie` (single-domain YouTube)
2. `~/.zen/game/nostr/user@email.com/.cookie.txt` (multi-domain file or legacy)

### 2. Leboncoin Scraper

```bash
python3 scraper_leboncoin.py \
  ~/.zen/game/nostr/user@email.com/.leboncoin.fr.cookie \
  "table a donner" \
  48.8566 2.3522 10000
```

### 3. Generic Cookie Helper

```bash
# Find cookie for any domain (searches in order)
COOKIE_PATH=$(bash get_cookie.sh user@email.com youtube.com)
# Returns:
#   1. ~/.zen/game/nostr/user@email.com/.youtube.com.cookie  (if exists, single-domain)
#   2. ~/.zen/game/nostr/user@email.com/.cookie.txt          (if exists, multi-domain or legacy)

# Use in your scripts
COOKIE=$(bash get_cookie.sh $PLAYER_EMAIL leboncoin.fr)
python3 my_scraper.py --cookie "$COOKIE" [...]
```

## Supported Services

| Service | Cookie File | Script |
|---------|-------------|--------|
| **YouTube** | `.youtube.com.cookie` | `sync_youtube_likes.sh`, `process_youtube.sh` |
| **Leboncoin** | `.leboncoin.fr.cookie` | `scraper_leboncoin.py` |
| **Any Domain** | `.{domain}.cookie` | Use `get_cookie.sh` helper |

All files are stored in `~/.zen/game/nostr/EMAIL/` directory

## Security

🔒 **Security Features:**
- Cookies are **NOT** published to IPFS
- Stored in user's **private directory** (not in uDRIVE)
- **NIP-42 authentication** required for upload
- **Hidden files** (leading dot) for extra privacy
- File permissions: **600** (read/write for owner only)

⚠️ **Best Practices:**
- Never share cookie files publicly
- Regenerate cookies periodically
- Use browser extensions to export cookies safely
- Check cookie expiration dates
- Use HTTPS-only cookies when possible

## MULTIPASS Access

All MULTIPASS identities are created by `make_NOSTRCARD.sh` and stored in EMAIL-based directories:

```
~/.zen/game/nostr/user@email.com/
├── .youtube.com.cookie         # Cookie files
├── .leboncoin.fr.cookie
├── .cookie.txt
├── NPUB                        # NOSTR public key (npub1...)
├── HEX                         # NOSTR public key (hex format)
├── .secret.nostr               # NOSTR private key (nsec, npub, hex)
└── APP/
    └── uDRIVE/
```

**Important**: 
- Directory structure is always based on **EMAIL** (e.g., `user@email.com`)
- NPUB/HEX are stored as **files** inside the EMAIL directory
- There is **NO** separate directory for NPUB
- All services access cookies via the EMAIL path

## Extending to New Services

To add support for a new website:

1. **Upload the cookie file** (via `/api/fileupload`)
2. **System auto-detects the domain** (e.g., `amazon.fr` → `.amazon.fr.cookie`)
3. **Use in your scripts:**

```bash
# Method 1: Direct path
COOKIE_FILE=~/.zen/game/nostr/$PLAYER/.cookies/.amazon.fr.cookie
python3 amazon_scraper.py --cookie "$COOKIE_FILE" [...]

# Method 2: Helper script
COOKIE_FILE=$(bash get_cookie.sh $PLAYER amazon.fr)
python3 amazon_scraper.py --cookie "$COOKIE_FILE" [...]
```

## Migration from Legacy Format

### YouTube Legacy Support

The system maintains backward compatibility:
- **New uploads** create both `.youtube.com.cookie` AND `.cookie.txt`
- **Old scripts** continue working with `.cookie.txt`
- **New scripts** prefer `.youtube.com.cookie`

### Migrating Existing Cookies

```bash
# If you have an old .cookie.txt, simply re-upload it:
curl -X POST 'http://localhost:54321/api/fileupload' \
  -F 'file=@~/.zen/game/nostr/USER/.cookie.txt' \
  -F 'npub=npub1...'

# System will:
# 1. Detect the domain (youtube.com)
# 2. Save as .cookies/.youtube.com.cookie
# 3. Keep .cookie.txt for backward compat
```

## API Endpoints

### Upload File with Cookie Detection
- **Endpoint**: `POST /api/fileupload`
- **Auth**: NIP-42 (npub required)
- **Params**: 
  - `file`: Cookie file (.txt with Netscape format)
  - `npub`: User's NOSTR public key
- **Returns**: Cookie details with detected domain

### Helper Scripts

| Script | Purpose |
|--------|---------|
| `get_cookie.sh` | Find cookie file for a domain |
| `sync_youtube_likes.sh` | Auto-sync YouTube liked videos |
| `process_youtube.sh` | Download YouTube videos/music |
| `scraper_leboncoin.py` | Scrape Leboncoin ads |

## Troubleshooting

### Cookie not found

```bash
# Check cookie files in user directory (EMAIL-based)
ls -la ~/.zen/game/nostr/user@email.com/.*.cookie ~/.zen/game/nostr/user@email.com/.cookie.txt

# Verify cookie file exists
bash get_cookie.sh user@email.com youtube.com

# Re-upload cookie if needed
curl -X POST 'http://localhost:54321/api/fileupload' \
  -F 'file=@cookies.txt' \
  -F 'npub=npub1...'
```

### Cookie expired

Most cookies have expiration dates. If services fail with auth errors:
1. Export fresh cookies from your browser
2. Re-upload via `/api/fileupload`
3. System will automatically replace old cookie

### Domain not detected

If domain detection fails, the system saves as `.cookie.txt` in the user's EMAIL directory. You can manually rename it:

```bash
mv ~/.zen/game/nostr/user@email.com/.cookie.txt \
   ~/.zen/game/nostr/user@email.com/.example.com.cookie
```

## Browser Extensions for Cookie Export

Recommended extensions to export cookies in Netscape format:
- **Chrome/Edge**: "Get cookies.txt LOCALLY"
- **Firefox**: "cookies.txt"
- **Any Browser**: Developer Tools → Application → Cookies (manual export)

## Example: Adding New Service

Let's add support for Twitter/X:

```bash
# 1. Export Twitter cookies using browser extension
# 2. Upload via API (with NPUB from ~/.zen/game/nostr/EMAIL/NPUB)
curl -X POST 'http://localhost:54321/api/fileupload' \
  -F 'file=@twitter_cookies.txt' \
  -F 'npub=npub1...'

# System saves as: ~/.zen/game/nostr/EMAIL/.twitter.com.cookie

# 3. Create your scraper
cat > twitter_scraper.py << 'EOF'
import sys
from get_cookie import read_cookie_from_file

cookie_file = sys.argv[1]
cookie = read_cookie_from_file(cookie_file)

# Use cookie with Twitter API...
EOF

# 4. Use it
COOKIE=$(bash get_cookie.sh user@email.com twitter.com)
python3 twitter_scraper.py "$COOKIE"
```

## Future Enhancements

Planned features:
- [ ] Cookie expiration monitoring
- [ ] Automatic cookie refresh
- [ ] Cookie sharing between UPlanet members (opt-in)
- [ ] Cookie health checks
- [ ] Multi-account cookie management

---

**Documentation**: UPassport Cookie System v1.0  
**Last Updated**: 2025-11-05  
**Maintainer**: Astroport.ONE Team

