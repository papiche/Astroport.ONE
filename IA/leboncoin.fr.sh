#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# leboncoin.fr.sh - Leboncoin scraper automation for MULTIPASS
# Called by NOSTRCARD.refresh.sh when .leboncoin.fr.cookie is detected
################################################################################

PLAYER="$1"
COOKIE_FILE="$2"

[[ -z "$PLAYER" || -z "$COOKIE_FILE" ]] && echo "Usage: $0 <player_email> <cookie_file_path>" && exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🛒 Starting Leboncoin scraper for ${PLAYER}"

# Get script directory
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Get player GPS coordinates for search
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"
GPS_FILE="${PLAYER_DIR}/GPS"

if [[ ! -f "$GPS_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ No GPS coordinates found for ${PLAYER}, skipping Leboncoin scraper"
    exit 0
fi

# Source GPS coordinates
source "$GPS_FILE"

if [[ -z "$LAT" || -z "$LON" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Invalid GPS coordinates for ${PLAYER}, skipping Leboncoin scraper"
    exit 0
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📍 Search location: ${LAT}, ${LON}"

# Default search parameters
SEARCH_QUERY="${LEBONCOIN_SEARCH_QUERY:-donne}"  # Default: "donne" (free items)
SEARCH_RADIUS="${LEBONCOIN_SEARCH_RADIUS:-10000}"  # Default: 10km

# Check for custom search parameters in player config
PLAYER_CONFIG="${PLAYER_DIR}/.leboncoin_config"
if [[ -f "$PLAYER_CONFIG" ]]; then
    source "$PLAYER_CONFIG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Using custom search parameters from ${PLAYER_CONFIG}"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Search query: '${SEARCH_QUERY}', radius: ${SEARCH_RADIUS}m"

# Output directory for results
OUTPUT_DIR="${PLAYER_DIR}/leboncoin_results"
mkdir -p "$OUTPUT_DIR"

# Output file with timestamp
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
OUTPUT_FILE="${OUTPUT_DIR}/search_${TIMESTAMP}.json"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📝 Results will be saved to: ${OUTPUT_FILE}"

# Call scraper_leboncoin.py
if [[ -f "${MY_PATH}/scraper_leboncoin.py" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Running Leboncoin scraper..."
    
    python3 "${MY_PATH}/scraper_leboncoin.py" \
        "$COOKIE_FILE" \
        "$SEARCH_QUERY" \
        "$LAT" \
        "$LON" \
        "$SEARCH_RADIUS" > "$OUTPUT_FILE" 2>&1
    
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Count results
        result_count=$(grep -c "^Titre:" "$OUTPUT_FILE" 2>/dev/null || echo "0")
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Leboncoin scraper completed successfully for ${PLAYER} (${result_count} results)"
        
        # Keep only last 10 result files to save space
        cd "$OUTPUT_DIR" && ls -t search_*.json | tail -n +11 | xargs -r rm
        
        exit 0
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Leboncoin scraper failed for ${PLAYER} (exit code: $exit_code)"
        exit $exit_code
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ scraper_leboncoin.py not found at ${MY_PATH}/scraper_leboncoin.py"
    exit 1
fi

