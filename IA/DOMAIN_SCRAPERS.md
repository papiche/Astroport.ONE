# Domain-Based Scraper System

## Overview

The UPlanet MULTIPASS system includes an extensible framework for automatically executing domain-specific scrapers based on uploaded cookies. This allows users to share their authenticated sessions with their AI assistant, enabling personalized data extraction from various websites.

## Architecture

### Cookie Detection

When a user uploads a cookie via the `/api/fileupload` endpoint, the system:

1. Detects the cookie format (Netscape HTTP Cookie File)
2. Extracts the primary domain from the cookie
3. Saves it as a hidden file: `.DOMAIN.cookie` in `~/.zen/game/nostr/EMAIL/`

Example:
- YouTube cookies → `.youtube.com.cookie`
- Leboncoin cookies → `.leboncoin.fr.cookie`

### Automatic Scraper Execution

During the daily MULTIPASS refresh cycle (`NOSTRCARD.refresh.sh`), the system:

1. Scans for all `.*.cookie` files in each user's directory
2. For each cookie found, extracts the domain name
3. Looks for a corresponding scraper script: `DOMAIN.sh` in `Astroport.ONE/IA/`
4. If found, executes the scraper with the user's email and cookie file path
5. If not found, sends an email notification to the user

### Naming Convention

**Cookie Files:**
- Format: `.DOMAIN.cookie` (hidden file)
- Location: `~/.zen/game/nostr/EMAIL/`
- Examples:
  - `.youtube.com.cookie`
  - `.leboncoin.fr.cookie`
  - `.twitter.com.cookie`

**Scraper Scripts:**
- Format: `DOMAIN.sh`
- Location: `Astroport.ONE/IA/`
- Examples:
  - `youtube.com.sh`
  - `leboncoin.fr.sh`
  - `twitter.com.sh`

**Python Backend (optional):**
- Format: `scraper_DOMAIN.py`
- Location: `Astroport.ONE/IA/`
- Examples:
  - `scraper_youtube.py`
  - `scraper_leboncoin.py`

## Creating a New Scraper

### 1. Cookie File

Users upload their cookies via the UPlanet interface at `https://u.copylaradio.com/cookie`. The system automatically:
- Detects the domain
- Renames the file to `.DOMAIN.cookie`
- Stores it in the user's MULTIPASS directory

### 2. Bash Script (DOMAIN.sh)

Create a bash script that:
- Accepts `PLAYER_EMAIL` and `COOKIE_FILE_PATH` as arguments
- Reads user-specific configuration (GPS, preferences, etc.)
- Calls the Python scraper or executes the logic directly
- Saves results to the user's uDRIVE

**Template:**

```bash
#!/bin/bash
################################################################################
# DOMAIN.sh - Scraper for DOMAIN
################################################################################

PLAYER="$1"
COOKIE_FILE="$2"

[[ -z "$PLAYER" || -z "$COOKIE_FILE" ]] && echo "Usage: $0 <player_email> <cookie_file_path>" && exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Starting DOMAIN scraper for ${PLAYER}"

# Get script directory
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Get player directory
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"

# Read user configuration (GPS, preferences, etc.)
GPS_FILE="${PLAYER_DIR}/GPS"
if [[ -f "$GPS_FILE" ]]; then
    source "$GPS_FILE"
fi

# Output directory
OUTPUT_DIR="${PLAYER_DIR}/APP/uDRIVE/DOMAIN_data"
mkdir -p "$OUTPUT_DIR"

# Call Python scraper or execute logic
python3 "${MY_PATH}/scraper_DOMAIN.py" \
    "$COOKIE_FILE" \
    "$PARAM1" \
    "$PARAM2" > "${OUTPUT_DIR}/results_$(date '+%Y%m%d_%H%M%S').json" 2>&1

exit_code=$?
echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ DOMAIN scraper completed (exit code: $exit_code)"
exit $exit_code
```

### 3. Python Scraper (optional)

If the logic is complex, create a Python script:

```python
#!/usr/bin/env python3
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Scraper for DOMAIN")
    parser.add_argument("cookie_file", help="Path to cookie file")
    parser.add_argument("param1", help="Parameter 1")
    args = parser.parse_args()
    
    # Your scraping logic here
    print("Results...")

if __name__ == "__main__":
    main()
```

### 4. Make Executable

```bash
chmod +x Astroport.ONE/IA/DOMAIN.sh
chmod +x Astroport.ONE/IA/scraper_DOMAIN.py
```

## Existing Scrapers

### YouTube (`youtube.com.sh`)

**Purpose:** Synchronizes liked videos from YouTube

**Features:**
- Fetches recent liked videos using `yt-dlp`
- Downloads videos to `uDRIVE/Music/` or `uDRIVE/Videos/`
- Processes metadata and generates AI summaries
- Tracks last synchronization to avoid duplicates

**Configuration:**
- Cookie: `.youtube.com.cookie`
- Script: `youtube.com.sh`
- Backend: Uses `yt-dlp` and `process_youtube.sh`

### Leboncoin (`leboncoin.fr.sh`)

**Purpose:** Searches for geolocated classified ads

**Features:**
- Uses user's GPS coordinates for search location
- Default search: "donne" (free items) within 10km
- Customizable via `.leboncoin_config` file
- Saves results to `leboncoin_results/`

**Configuration:**
- Cookie: `.leboncoin.fr.cookie`
- Script: `leboncoin.fr.sh`
- Backend: `scraper_leboncoin.py`

**Custom Search Parameters:**

Create `~/.zen/game/nostr/EMAIL/.leboncoin_config`:

```bash
LEBONCOIN_SEARCH_QUERY="canapé gratuit"
LEBONCOIN_SEARCH_RADIUS=15000  # 15km
```

## User Notifications

When a user uploads a cookie for a domain without a scraper, they receive an email:

**Subject:** "Cookie détecté: DOMAIN - Service à créer"

**Content:**
- Notification that the cookie was detected
- Explanation that no automated service exists yet
- Instructions to contact the Captain (system administrator)
- List of existing services (YouTube, Leboncoin)

This notification is sent **once per domain** and stored in `.DOMAIN_notified`.

## Smart Contracts

The system is designed to be extended via "smart contracts" - individual scraper scripts added to the official codebase after validation by the Captain.

**Process:**
1. User uploads cookie for new domain
2. User receives notification email
3. User contacts Captain to describe their needs
4. Captain (or developer) creates custom scraper
5. Script is added to `Astroport.ONE/IA/`
6. Next day, scraper runs automatically for that user

## Security Considerations

- **Cookie Privacy:** Cookies are stored as hidden files in user's private MULTIPASS directory
- **Access Control:** Only the user and their AI assistant can access the cookies
- **Encryption:** MULTIPASS directories are protected by NOSTR authentication
- **No Cookie Sharing:** Cookies are never shared between users

## Extensibility

The system is designed for easy extension:

1. **No Code Changes Required:** Just add `DOMAIN.sh` to `IA/` directory
2. **Automatic Detection:** `NOSTRCARD.refresh.sh` scans for all cookies
3. **Per-User Execution:** Each scraper runs independently per user
4. **Background Execution:** Scrapers run in background to avoid blocking
5. **Logging:** Dedicated log file per domain per user

## Testing

To test a new scraper:

1. Upload cookie via UPlanet interface
2. Create `DOMAIN.sh` script in `Astroport.ONE/IA/`
3. Make it executable: `chmod +x DOMAIN.sh`
4. Run manually: `./DOMAIN.sh user@email.com ~/.zen/game/nostr/user@email.com/.DOMAIN.cookie`
5. Check logs: `~/.zen/tmp/DOMAIN_sync_user@email.com.log`
6. Wait for next daily refresh, or trigger manually with `NOSTRCARD.refresh.sh`

## Troubleshooting

**Scraper not running:**
- Check if cookie file exists: `ls -la ~/.zen/game/nostr/EMAIL/.*.cookie`
- Check if script exists: `ls -la Astroport.ONE/IA/DOMAIN.sh`
- Check if script is executable: `ls -l Astroport.ONE/IA/DOMAIN.sh`
- Check logs: `~/.zen/tmp/MULTIPASS.refresh.log`

**Cookie expired:**
- Re-export cookie from website (in private browser window)
- Re-upload via UPlanet interface
- Old cookie will be replaced automatically

**Scraper fails:**
- Check domain-specific log: `~/.zen/tmp/DOMAIN_sync_EMAIL.log`
- Verify cookie format (should be Netscape HTTP Cookie File)
- Test Python scraper independently

## Future Enhancements

- Web-based scraper configuration interface
- AI-powered data extraction without manual scripting
- Multi-domain cookie support in a single file
- Real-time scraping triggers (not just daily)
- User-defined scheduling (hourly, weekly, etc.)

---

**Version:** 0.1  
**Last Updated:** 2025-11-05  
**Author:** Fred (support@qo-op.com)  
**License:** AGPL-3.0

