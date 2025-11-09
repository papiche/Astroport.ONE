# Universal Cookie Management System

## Overview

The `/api/fileupload` endpoint supports automatic detection and organization of **single-domain** cookie files. Cookies are stored as **hidden files** (with leading dot) for better security and privacy.

## Features

✅ **Single-Domain Only**: Each cookie file must contain cookies for one domain only  
✅ **Hidden Files**: All cookies saved with leading dot (`.youtube.com.cookie`, `.leboncoin.fr.cookie`)  
✅ **Auto-Detection**: Recognizes Netscape HTTP Cookie File format  
✅ **Domain Extraction**: Parses cookie content to identify the source domain  
✅ **MULTIPASS Compatible**: Cookies stored in EMAIL-based MULTIPASS directories  
❌ **No Multi-Domain**: Multi-domain cookie files are rejected (export per-domain cookies)  

## Directory Structure

```
~/.zen/game/nostr/user@email.com/       # EMAIL-based directory (created by make_NOSTRCARD.sh)
├── .youtube.com.cookie                  # YouTube cookies only (single-domain, hidden file)
├── .leboncoin.fr.cookie                 # Leboncoin cookies only (single-domain, hidden file)
├── .amazon.fr.cookie                    # Amazon cookies only (single-domain, hidden file)
├── .[domain].cookie                     # Any single domain cookie (hidden file)
├── NPUB                                 # NOSTR public key (npub1..., stored as file)
├── HEX                                  # NOSTR public key (hex format, stored as file)
├── .secret.nostr                        # NOSTR private key (nsec, npub, hex - hidden)
└── APP/
    └── uDRIVE/
        ├── Videos/                      # Downloaded videos
        └── Music/                       # Downloaded music
```

**Notes:**
- `.{domain}.cookie` → Single-domain cookies ONLY (e.g., youtube.com + subdomains)
- All cookie files are **hidden files** (starting with dot) at the root of user's EMAIL directory
- **Directory is always EMAIL-based**, NPUB/HEX are stored as files inside
- **Multi-domain cookies are NOT supported** - export cookies separately for each domain

## Cookie File Format

### Supported format:
- **Netscape HTTP Cookie File** (ONLY format accepted)
- **Single-domain only** - cookies must be for one domain and its subdomains

### Cookie File Types:

#### Single-Domain Cookies (ONLY accepted type)
Each uploaded file must contain cookies for **one domain only** (and its subdomains):
- `.youtube.com.cookie` → All cookies for youtube.com and subdomains
- `.leboncoin.fr.cookie` → All cookies for leboncoin.fr and subdomains

#### ❌ Multi-Domain Cookies (REJECTED)
Files containing cookies for **multiple different domains** are **rejected** with an error message.

**Solution:** Export cookies separately for each domain using your browser extension's filter options.

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

#### ❌ Multi-Domain Cookie (Error):f
```json
{
  "detail": "Multi-domain cookie files are not supported. Please export cookies for a single domain only. Detected domains: amazon.fr, leboncoin.fr, youtube.com"
}
```
**Status Code:** 400 Bad Request

## Automated Scraper Execution

### System Architecture

The UPlanet system includes an **extensible domain-based scraper framework** that automatically executes scrapers when cookies are detected.

#### How It Works

1. **Cookie Upload**: User uploads cookie via `/api/fileupload` or `/cookie` interface
2. **Domain Detection**: System extracts primary domain (e.g., `youtube.com`, `leboncoin.fr`)
3. **File Storage**: Cookie saved as `.DOMAIN.cookie` in user's MULTIPASS directory with permissions 600
4. **Daily Scan**: During MULTIPASS refresh (`NOSTRCARD.refresh.sh`), system scans for all `.*.cookie` files
5. **Scraper Lookup**: For each cookie, system looks for `DOMAIN.sh` script in `Astroport.ONE/IA/`
6. **Execution**: If found, script runs with user's email and cookie file path as arguments (once per day)
7. **Notification**: If not found, user receives email explaining how to request a custom scraper (once per domain)

#### Naming Convention for Scrapers

**Scraper Scripts:**
- Format: `DOMAIN.sh` (bash script run by AstrBot)
- Location: `Astroport.ONE/IA/`
- Examples:
  - `youtube.com.sh` → YouTube scraper
  - `leboncoin.fr.sh` → Leboncoin scraper
  - `twitter.com.sh` → Twitter scraper (etc...)

**Python Backend (optional):**
- Format: `scraper_DOMAIN.py`
- Location: `Astroport.ONE/IA/`
- Called by bash script if complex logic required

#### User Notifications

When a cookie is uploaded for a domain without a scraper:
- User receives email: "🍪 Cookie: DOMAIN - MISSING ASTROBOT PROGRAM"
- Email explains how to request a custom scraper via Captain
- Notification sent only once per domain (tracked in `.DOMAIN_notified` file)
- Smart contract workflow: User describes needs → Captain validates → Script added to codebase

#### Execution Tracking

To prevent multiple executions per day:
- Each scraper execution creates a `.done` file: `~/.zen/tmp/${DOMAIN}_sync_${PLAYER}_${TODATE}.done`
- If `.done` file exists for today, scraper is skipped
- Logs are stored in: `~/.zen/tmp/${DOMAIN}_sync_${PLAYER}.log`

See `DOMAIN_SCRAPERS.md` for detailed instructions on creating custom scrapers.

## Using Cookies

### 1. YouTube Sync (automatic)

**Note:** Now handled automatically by `NOSTRCARD.refresh.sh` when `.youtube.com.cookie` is detected.

Manual execution:
```bash
bash youtube.com.sh user@email.com
```

Searches for:
- `~/.zen/game/nostr/user@email.com/.youtube.com.cookie` (domain-specific cookie)

### 2. Leboncoin Scraper (automatic)

**Note:** Now handled automatically by `NOSTRCARD.refresh.sh` when `.leboncoin.fr.cookie` is detected.

Manual execution:
```bash
bash leboncoin.fr.sh user@email.com ~/.zen/game/nostr/user@email.com/.leboncoin.fr.cookie
```

Or call Python scraper directly:
```bash
python3 scraper_leboncoin.py \
  ~/.zen/game/nostr/user@email.com/.leboncoin.fr.cookie \
  "table a donner" \
  48.8566 2.3522 10000
```

### 3. Generic Cookie Helper

```bash
# Find cookie for any domain
COOKIE_PATH=$(bash get_cookie.sh user@email.com youtube.com)
# Returns: ~/.zen/game/nostr/user@email.com/.youtube.com.cookie

# Use in your scripts
COOKIE=$(bash get_cookie.sh $PLAYER_EMAIL leboncoin.fr)
python3 my_scraper.py --cookie "$COOKIE" [...]
```

## Supported Services

| Service | Cookie File | Bash Script | Python Backend |
|---------|-------------|-------------|----------------|
| **YouTube** | `.youtube.com.cookie` | `youtube.com.sh` | (uses yt-dlp + process_youtube.sh) |
| **Leboncoin** | `.leboncoin.fr.cookie` | `leboncoin.fr.sh` | `scraper_leboncoin.py` |
| **Any Domain** | `.{domain}.cookie` | Create `{domain}.sh` | Optional `scraper_{domain}.py` |

All files are stored in `~/.zen/game/nostr/EMAIL/` directory

**Extensible System:**
- Add `DOMAIN.sh` script to `Astroport.ONE/IA/` directory
- System automatically detects and executes it
- No code changes required in main system
- See `DOMAIN_SCRAPERS.md` for instructions

## Security

🔒 **Security Features:**
- Cookies are **NOT** published to IPFS
- Stored in user's **private directory** (not in uDRIVE)
- **NIP-42 authentication** required for upload
- **Hidden files** (leading dot) for extra privacy
- File permissions: **600** (read/write for owner only) - Set automatically on save

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
├── .youtube.com.cookie         # Domain-specific cookie files
├── .leboncoin.fr.cookie
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
- **Only single-domain cookie files** (`.DOMAIN.cookie`) are supported

## Extending to New Services

To add support for a new website:

1. **Upload the cookie file** for ONE domain only (via `/api/fileupload`)
2. **System auto-detects the domain** (e.g., `amazon.fr` → `.amazon.fr.cookie`)
3. **Use in your scripts:**

```bash
# Method 1: Direct path
COOKIE_FILE=~/.zen/game/nostr/$PLAYER/.amazon.fr.cookie
python3 amazon_scraper.py --cookie "$COOKIE_FILE" [...]

# Method 2: Helper script
COOKIE_FILE=$(bash get_cookie.sh $PLAYER amazon.fr)
python3 amazon_scraper.py --cookie "$COOKIE_FILE" [...]
```

## Best Practices

### How to Export Single-Domain Cookies

When using "Get cookies.txt LOCALLY" extension:

1. **Open the website** you want to export cookies for
2. **Click the extension** icon
3. **Filter by current site** (usually done automatically)
4. **Select Netscape format**
5. **Export** - this creates a single-domain cookie file
6. **Upload to UPlanet**

**Important:** Export cookies separately for each domain you want to use. Don't export all browser cookies at once.

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
| `youtube.com.sh` | Auto-sync YouTube liked videos |
| `leboncoin.fr.sh` | Scrape Leboncoin ads |
| `scraper_leboncoin.py` | Python backend for Leboncoin |

## Troubleshooting

### Cookie not found

```bash
# Check cookie files in user directory (EMAIL-based)
ls -la ~/.zen/game/nostr/user@email.com/.*.cookie

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
**Last Updated**: Décembre 2025  
**Maintainer**: Astroport.ONE Team

---

## Related Documentation

- **[COOKIE_SYSTEM_COMPLIANCE.md](./COOKIE_SYSTEM_COMPLIANCE.md)**: Detailed conformity analysis between documentation and implementation
- **[NOSTRCARD.refresh.sh](../RUNTIME/NOSTRCARD.refresh.sh)**: Automated scraper execution script
- **[cookie.html](../../UPassport/templates/cookie.html)**: User interface for cookie upload

