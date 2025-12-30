#!/bin/bash
###################################################################
# google_trends_blog.sh
# Script to create blog posts from Google Trends analysis
#
# Usage: $0 <keyfile_path> [--geo GEO] [--lang LANG] [--force]
#
# Parameters:
#   keyfile_path    Path to .secret.nostr file for NOSTR publishing
#   --geo GEO       Country code for trends (default: FR)
#   --lang LANG     Language for blog article (default: fr)
#   --force         Force publish even if trend is the same
#   --dry-run       Show what would be published without publishing
#
# Example:
#   ./google_trends_blog.sh ~/.zen/game/nostr/alice@example.com/.secret.nostr
#   ./google_trends_blog.sh ~/.zen/game/nostr/alice@example.com/.secret.nostr --geo US --lang en
#
# This script:
# 1. Fetches current trending topics from Google Trends
# 2. Compares with the last processed trend
# 3. If different, performs a Perplexica search (#search)
# 4. Creates and publishes a blog article (kind 30023) via NOSTR
###################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Load common utilities
[[ -s ~/.zen/Astroport.ONE/tools/my.sh ]] && source ~/.zen/Astroport.ONE/tools/my.sh

# Configuration
TRENDS_CACHE_DIR="$HOME/.zen/tmp/google_trends"
TRENDS_URL_BASE="https://trends.google.com/trending"

# Function to get Captain's default settings
get_captain_defaults() {
    # Get CAPTAINEMAIL from my.sh
    if [[ -z "$CAPTAINEMAIL" ]]; then
        echo "Warning: CAPTAINEMAIL not set" >&2
        return 1
    fi
    
    # Default keyfile path
    CAPTAIN_KEYFILE="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    
    # Get Captain's language
    CAPTAIN_LANG_FILE="$HOME/.zen/game/nostr/$CAPTAINEMAIL/LANG"
    if [[ -f "$CAPTAIN_LANG_FILE" ]]; then
        CAPTAIN_LANG=$(cat "$CAPTAIN_LANG_FILE" 2>/dev/null | tr -d '\n' | head -c 10)
    fi
    
    # Default language to fr if not set
    [[ -z "$CAPTAIN_LANG" ]] && CAPTAIN_LANG="fr"
    
    # Get Captain's GPS coordinates
    CAPTAIN_GPS_FILE="$HOME/.zen/game/nostr/$CAPTAINEMAIL/GPS"
    if [[ -f "$CAPTAIN_GPS_FILE" ]]; then
        source "$CAPTAIN_GPS_FILE" 2>/dev/null
        # Only use GPS if coordinates are valid (not 0.00, 0.00)
        if [[ "$LAT" != "0.00" && "$LON" != "0.00" && -n "$LAT" && -n "$LON" ]]; then
            CAPTAIN_LAT="$LAT"
            CAPTAIN_LON="$LON"
        fi
        # Reset LAT/LON to avoid conflict with parameters
        unset LAT LON
    fi
    
    return 0
}

# Convert GPS coordinates to French region code for Google Trends
# Uses approximate bounding boxes for French administrative regions
gps_to_french_region() {
    local lat="$1"
    local lon="$2"
    
    # Convert to integers for comparison (multiply by 100)
    local lat_int=$(echo "$lat * 100" | bc 2>/dev/null | cut -d'.' -f1)
    local lon_int=$(echo "$lon * 100" | bc 2>/dev/null | cut -d'.' -f1)
    
    # Fallback if bc is not available
    [[ -z "$lat_int" ]] && lat_int=$(printf "%.0f" $(echo "$lat * 100" | awk '{print $1 * $3}'))
    [[ -z "$lon_int" ]] && lon_int=$(printf "%.0f" $(echo "$lon * 100" | awk '{print $1 * $3}'))
    
    # French regions with approximate bounding boxes (lat*100, lon*100)
    # Format: min_lat max_lat min_lon max_lon code
    
    # Île-de-France (Paris region)
    if [[ $lat_int -ge 4830 && $lat_int -le 4920 && $lon_int -ge 140 && $lon_int -le 320 ]]; then
        echo "FR-J"
        return 0
    fi
    
    # Provence-Alpes-Côte d'Azur (Marseille, Nice)
    if [[ $lat_int -ge 4300 && $lat_int -le 4450 && $lon_int -ge 450 && $lon_int -le 750 ]]; then
        echo "FR-U"
        return 0
    fi
    
    # Auvergne-Rhône-Alpes (Lyon)
    if [[ $lat_int -ge 4450 && $lat_int -le 4650 && $lon_int -ge 280 && $lon_int -le 720 ]]; then
        echo "FR-V"
        return 0
    fi
    
    # Occitanie (Toulouse, Montpellier)
    if [[ $lat_int -ge 4240 && $lat_int -le 4480 && $lon_int -ge -20 && $lon_int -le 480 ]]; then
        echo "FR-N"
        return 0
    fi
    
    # Nouvelle-Aquitaine (Bordeaux)
    if [[ $lat_int -ge 4420 && $lat_int -le 4680 && $lon_int -ge -180 && $lon_int -le 200 ]]; then
        echo "FR-B"
        return 0
    fi
    
    # Bretagne
    if [[ $lat_int -ge 4730 && $lat_int -le 4880 && $lon_int -ge -500 && $lon_int -le -80 ]]; then
        echo "FR-E"
        return 0
    fi
    
    # Pays de la Loire (Nantes)
    if [[ $lat_int -ge 4650 && $lat_int -le 4820 && $lon_int -ge -250 && $lon_int -le 80 ]]; then
        echo "FR-R"
        return 0
    fi
    
    # Hauts-de-France (Lille)
    if [[ $lat_int -ge 4900 && $lat_int -le 5100 && $lon_int -ge 150 && $lon_int -le 450 ]]; then
        echo "FR-S"
        return 0
    fi
    
    # Grand Est (Strasbourg)
    if [[ $lat_int -ge 4750 && $lat_int -le 4950 && $lon_int -ge 380 && $lon_int -le 800 ]]; then
        echo "FR-A"
        return 0
    fi
    
    # Normandie
    if [[ $lat_int -ge 4850 && $lat_int -le 4990 && $lon_int -ge -200 && $lon_int -le 200 ]]; then
        echo "FR-P"
        return 0
    fi
    
    # Centre-Val de Loire
    if [[ $lat_int -ge 4660 && $lat_int -le 4850 && $lon_int -ge 60 && $lon_int -le 300 ]]; then
        echo "FR-F"
        return 0
    fi
    
    # Bourgogne-Franche-Comté
    if [[ $lat_int -ge 4650 && $lat_int -le 4800 && $lon_int -ge 280 && $lon_int -le 700 ]]; then
        echo "FR-I"
        return 0
    fi
    
    # Corse
    if [[ $lat_int -ge 4130 && $lat_int -le 4300 && $lon_int -ge 850 && $lon_int -le 960 ]]; then
        echo "FR-H"
        return 0
    fi
    
    # Default to France if no match
    echo "FR"
}

# Convert GPS coordinates to country code
gps_to_country() {
    local lat="$1"
    local lon="$2"
    
    # Simple country detection based on GPS bounding boxes
    # France metropolitan
    if (( $(echo "$lat >= 41.0 && $lat <= 51.5 && $lon >= -5.5 && $lon <= 10.0" | bc -l 2>/dev/null) )); then
        echo "FR"
        return 0
    fi
    
    # Germany
    if (( $(echo "$lat >= 47.0 && $lat <= 55.0 && $lon >= 5.5 && $lon <= 15.5" | bc -l 2>/dev/null) )); then
        echo "DE"
        return 0
    fi
    
    # Spain
    if (( $(echo "$lat >= 36.0 && $lat <= 43.8 && $lon >= -9.5 && $lon <= 4.5" | bc -l 2>/dev/null) )); then
        echo "ES"
        return 0
    fi
    
    # Italy
    if (( $(echo "$lat >= 36.0 && $lat <= 47.5 && $lon >= 6.5 && $lon <= 18.5" | bc -l 2>/dev/null) )); then
        echo "IT"
        return 0
    fi
    
    # UK
    if (( $(echo "$lat >= 49.5 && $lat <= 61.0 && $lon >= -8.5 && $lon <= 2.0" | bc -l 2>/dev/null) )); then
        echo "GB"
        return 0
    fi
    
    # Belgium
    if (( $(echo "$lat >= 49.4 && $lat <= 51.6 && $lon >= 2.5 && $lon <= 6.5" | bc -l 2>/dev/null) )); then
        echo "BE"
        return 0
    fi
    
    # Switzerland
    if (( $(echo "$lat >= 45.8 && $lat <= 47.9 && $lon >= 5.9 && $lon <= 10.5" | bc -l 2>/dev/null) )); then
        echo "CH"
        return 0
    fi
    
    # Default to FR
    echo "FR"
}

# Get Google Trends geo code from GPS coordinates
gps_to_geo() {
    local lat="$1"
    local lon="$2"
    
    if [[ -z "$lat" || -z "$lon" ]]; then
        echo ""
        return 1
    fi
    
    # First determine the country
    local country=$(gps_to_country "$lat" "$lon")
    
    # For France, try to get a more specific region
    if [[ "$country" == "FR" ]]; then
        local region=$(gps_to_french_region "$lat" "$lon")
        if [[ -n "$region" && "$region" != "FR" ]]; then
            echo "$region"
            return 0
        fi
    fi
    
    echo "$country"
}

# Get Captain defaults
get_captain_defaults

# Map language to country code for Google Trends
lang_to_geo() {
    local lang="$1"
    case "$lang" in
        fr) echo "FR" ;;
        en) echo "US" ;;
        es) echo "ES" ;;
        de) echo "DE" ;;
        it) echo "IT" ;;
        pt) echo "PT" ;;
        nl) echo "NL" ;;
        pl) echo "PL" ;;
        ru) echo "RU" ;;
        ja) echo "JP" ;;
        zh) echo "CN" ;;
        ko) echo "KR" ;;
        ar) echo "SA" ;;
        *) echo "FR" ;;  # Default to FR
    esac
}

# Set defaults from Captain's settings
DEFAULT_LANG="${CAPTAIN_LANG:-fr}"
DEFAULT_GEO=$(lang_to_geo "$DEFAULT_LANG")
DEFAULT_KEYFILE="${CAPTAIN_KEYFILE:-}"
DEFAULT_LAT="${CAPTAIN_LAT:-}"
DEFAULT_LON="${CAPTAIN_LON:-}"

# Parse arguments
KEYFILE_PATH=""
GEO=""
LANG=""
LAT=""
LON=""
FORCE=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --geo)
            GEO="$2"
            shift 2
            ;;
        --lang)
            LANG="$2"
            shift 2
            ;;
        --lat)
            LAT="$2"
            shift 2
            ;;
        --lon)
            LON="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [keyfile_path] [--geo GEO] [--lang LANG] [--lat LAT --lon LON] [--force] [--dry-run]"
            echo ""
            echo "Creates blog posts from Google Trends analysis"
            echo ""
            echo "Parameters:"
            echo "  keyfile_path    Path to .secret.nostr file (default: Captain's key)"
            echo "  --geo GEO       Country/region code (default: derived from GPS or LANG)"
            echo "  --lang LANG     Language for article (default: Captain's LANG)"
            echo "  --lat LAT       Latitude for regional trends (used with --lon)"
            echo "  --lon LON       Longitude for regional trends (used with --lat)"
            echo "  --force         Force publish even if same trend"
            echo "  --dry-run       Show what would be published"
            echo ""
            echo "Defaults:"
            echo "  Keyfile:  \$CAPTAINEMAIL/.secret.nostr"
            echo "  Language: Read from \$CAPTAINEMAIL/LANG file"
            echo "  GPS:      Read from \$CAPTAINEMAIL/GPS file"
            echo "  GEO:      Derived from GPS -> region code, or LANG -> country"
            echo ""
            echo "GPS to Region mapping (France):"
            echo "  Paris area     -> FR-J (Île-de-France)"
            echo "  Marseille area -> FR-U (PACA)"
            echo "  Lyon area      -> FR-V (Auvergne-Rhône-Alpes)"
            echo "  etc."
            echo ""
            echo "Example:"
            echo "  $0                                        # Use Captain's defaults"
            echo "  $0 --lat 48.8566 --lon 2.3522             # Paris region trends"
            echo "  $0 --geo FR-U --lang fr                   # PACA region trends"
            echo "  $0 ~/.zen/game/nostr/user@mail.com/.secret.nostr"
            exit 0
            ;;
        *)
            if [[ -z "$KEYFILE_PATH" ]]; then
                KEYFILE_PATH="$1"
            fi
            shift
            ;;
    esac
done

# Apply defaults if not specified
[[ -z "$KEYFILE_PATH" ]] && KEYFILE_PATH="$DEFAULT_KEYFILE"
[[ -z "$LANG" ]] && LANG="$DEFAULT_LANG"
[[ -z "$LAT" ]] && LAT="$DEFAULT_LAT"
[[ -z "$LON" ]] && LON="$DEFAULT_LON"

# Validate GPS coordinates - ignore 0.00, 0.00 as it means "not set"
if [[ "$LAT" == "0.00" || "$LAT" == "0" || "$LON" == "0.00" || "$LON" == "0" ]]; then
    LAT=""
    LON=""
fi

# Determine GEO code
# Priority: 1) Explicit --geo, 2) GPS coordinates, 3) Language-based
GPS_DERIVED=false
if [[ -z "$GEO" ]]; then
    if [[ -n "$LAT" && -n "$LON" ]]; then
        # Convert GPS to geo code
        GEO=$(gps_to_geo "$LAT" "$LON")
        if [[ -n "$GEO" ]]; then
            GPS_DERIVED=true
        fi
    fi
    
    # Fallback to language-based
    if [[ -z "$GEO" ]]; then
        GEO=$(lang_to_geo "$LANG")
    fi
fi

# Validate keyfile
if [[ -z "$KEYFILE_PATH" ]]; then
    echo "Error: No keyfile available" >&2
    echo "  - CAPTAINEMAIL not configured or keyfile missing" >&2
    echo "  - Provide a keyfile path as argument" >&2
    echo "" >&2
    echo "Usage: $0 [keyfile_path] [--geo GEO] [--lang LANG]" >&2
    exit 1
fi

if [[ ! -f "$KEYFILE_PATH" ]]; then
    echo "Error: Keyfile not found: $KEYFILE_PATH" >&2
    if [[ "$KEYFILE_PATH" == "$DEFAULT_KEYFILE" ]]; then
        echo "  Captain's keyfile is missing. Check CAPTAINEMAIL configuration." >&2
    fi
    exit 1
fi

# Show Captain info if using defaults
USING_CAPTAIN_KEY=false
if [[ "$KEYFILE_PATH" == "$DEFAULT_KEYFILE" ]]; then
    USING_CAPTAIN_KEY=true
fi

# Create cache directory
mkdir -p "$TRENDS_CACHE_DIR"

# State file for tracking last processed trend (include GPS hash if regional)
if [[ -n "$LAT" && -n "$LON" ]]; then
    GPS_HASH=$(echo -n "${LAT}_${LON}" | md5sum | cut -d' ' -f1 | head -c 8)
    STATE_FILE="$TRENDS_CACHE_DIR/last_trend_${GEO}_${GPS_HASH}.json"
else
    STATE_FILE="$TRENDS_CACHE_DIR/last_trend_${GEO}.json"
fi

echo "🔍 Google Trends Blog Generator"
echo "================================"
if [[ "$USING_CAPTAIN_KEY" == true ]]; then
    echo "👨‍✈️ Using Captain's settings ($CAPTAINEMAIL)"
fi
echo "📍 Region: $GEO"
if [[ -n "$LAT" && -n "$LON" ]]; then
    echo "🌍 GPS: $LAT, $LON"
    if [[ "$GPS_DERIVED" == true ]]; then
        echo "   (Region derived from GPS coordinates)"
    fi
fi
echo "🌐 Language: $LANG"
echo "🔑 Keyfile: $(basename $(dirname "$KEYFILE_PATH"))"
echo ""

# Function to fetch trends using RSS feed (more reliable than scraping)
fetch_trends_rss() {
    local geo="$1"
    local rss_url="https://trends.google.com/trending/rss?geo=${geo}"
    
    echo "📡 Fetching trends from RSS feed..." >&2
    
    local rss_content
    rss_content=$(curl -s -L --max-time 30 \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        -H "Accept: application/rss+xml,application/xml,text/xml" \
        "$rss_url" 2>/dev/null)
    
    if [[ -z "$rss_content" ]]; then
        echo "Warning: Empty RSS response" >&2
        return 1
    fi
    
    # Extract trend titles from RSS (using grep and sed for compatibility)
    local trends
    trends=$(echo "$rss_content" | grep -oP '(?<=<title>)[^<]+' | grep -v "Daily Search Trends" | head -20)
    
    if [[ -z "$trends" ]]; then
        echo "Warning: No trends found in RSS" >&2
        return 1
    fi
    
    echo "$trends"
}

# Function to fetch trends via Google Trends JSON API (alternative method)
fetch_trends_json() {
    local geo="$1"
    local api_url="https://trends.google.com/trends/api/dailytrends?hl=${LANG}&tz=-60&geo=${geo}"
    
    echo "📡 Fetching trends from JSON API..." >&2
    
    local json_content
    json_content=$(curl -s -L --max-time 30 \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        "$api_url" 2>/dev/null)
    
    # Remove JSONP wrapper if present (Google returns )]}' prefix)
    json_content=$(echo "$json_content" | sed 's/^)]}'\''//')
    
    if [[ -z "$json_content" ]]; then
        echo "Warning: Empty JSON response" >&2
        return 1
    fi
    
    # Extract trend titles from JSON
    local trends
    trends=$(echo "$json_content" | jq -r '.default.trendingSearchesDays[0].trendingSearches[].title.query' 2>/dev/null | head -20)
    
    if [[ -z "$trends" ]]; then
        echo "Warning: No trends found in JSON" >&2
        return 1
    fi
    
    echo "$trends"
}

# Function to get search volume info (for article enrichment)
get_trend_details() {
    local trend="$1"
    local geo="$2"
    
    # Build Google Trends explore URL for this trend
    local encoded_trend
    encoded_trend=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$trend'))" 2>/dev/null || echo "$trend")
    
    echo "https://trends.google.com/trends/explore?q=${encoded_trend}&geo=${geo}"
}

# Fetch current trends
echo "📊 Fetching current Google Trends for $GEO..."

TRENDS=""

# Try RSS first (most reliable)
TRENDS=$(fetch_trends_rss "$GEO")

# Fallback to JSON API
if [[ -z "$TRENDS" ]]; then
    echo "⚠️  RSS failed, trying JSON API..." >&2
    TRENDS=$(fetch_trends_json "$GEO")
fi

# If still no trends, try scraping the page
if [[ -z "$TRENDS" ]]; then
    echo "⚠️  API methods failed, attempting page scrape..." >&2
    
    # Use curl to get trends page and extract data
    PAGE_CONTENT=$(curl -s -L --max-time 30 \
        -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36" \
        -H "Accept: text/html" \
        "${TRENDS_URL_BASE}?geo=${GEO}&sort=recency" 2>/dev/null)
    
    # Try to extract trend names from HTML (this is fragile but a fallback)
    TRENDS=$(echo "$PAGE_CONTENT" | grep -oP '(?<=aria-label=")[^"]+(?=" data-index)' | head -20)
fi

if [[ -z "$TRENDS" ]]; then
    echo "❌ Failed to fetch trends from any source" >&2
    exit 1
fi

# Get the first (most recent) trend
CURRENT_TREND=$(echo "$TRENDS" | head -n1 | tr -d '\r')
ALL_TRENDS=$(echo "$TRENDS" | head -n5 | tr '\n' ', ' | sed 's/,$//')

echo ""
echo "📈 Current top trend: $CURRENT_TREND"
echo "📋 Top 5 trends: $ALL_TRENDS"
echo ""

# Load last processed trend
LAST_TREND=""
LAST_TIMESTAMP=""
if [[ -f "$STATE_FILE" ]]; then
    LAST_TREND=$(jq -r '.trend // ""' "$STATE_FILE" 2>/dev/null)
    LAST_TIMESTAMP=$(jq -r '.timestamp // ""' "$STATE_FILE" 2>/dev/null)
    echo "📝 Last processed trend: $LAST_TREND"
    echo "⏰ Last processed: $LAST_TIMESTAMP"
fi

# Check if trend has changed
if [[ "$CURRENT_TREND" == "$LAST_TREND" ]] && [[ "$FORCE" != true ]]; then
    echo ""
    echo "✅ Trend unchanged. No new blog to publish."
    echo "   Use --force to publish anyway."
    exit 0
fi

echo ""
echo "🆕 New trend detected! Processing..."

# Ensure Perplexica is available
echo "🔌 Checking Perplexica availability..."
if ! $MY_PATH/perplexica.me.sh >/dev/null 2>&1; then
    echo "❌ Failed to connect to Perplexica API" >&2
    exit 1
fi
echo "✅ Perplexica API ready"

# Perform search using perplexica_search.sh
echo ""
echo "🔎 Performing Perplexica search for: $CURRENT_TREND"
echo "   Language: $LANG"
echo ""

SEARCH_RESULT=$($MY_PATH/perplexica_search.sh "$CURRENT_TREND" "$LANG" 2>/dev/null)

if [[ -z "$SEARCH_RESULT" ]]; then
    echo "❌ Perplexica search returned empty result" >&2
    exit 1
fi

echo "✅ Search completed successfully"

# Generate article metadata
CURRENT_TIMESTAMP=$(date +%s)
CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_TIME=$(date '+%H:%M:%S')
D_TAG="trends_${GEO}_${CURRENT_TIMESTAMP}_$(echo -n "$CURRENT_TREND" | md5sum | cut -d' ' -f1 | head -c 8)"

# Generate article summary using question.py
echo ""
echo "📝 Generating article summary..."
ARTICLE_SUMMARY=$($MY_PATH/question.py --json "Create a concise, engaging summary (2-3 sentences) for this blog article in ${LANG} language. Article content: ${SEARCH_RESULT}" --pubkey "system" 2>/dev/null | jq -r '.answer // .' 2>/dev/null | head -c 500)

if [[ -z "$ARTICLE_SUMMARY" ]]; then
    ARTICLE_SUMMARY="Article sur la tendance Google: $CURRENT_TREND"
fi

# Clean summary for JSON
ARTICLE_SUMMARY=$(echo "$ARTICLE_SUMMARY" | tr -d '\n' | sed 's/"/\\"/g' | head -c 400)

# Generate tags based on content
echo "🏷️  Generating hashtags..."
INTELLIGENT_TAGS=$($MY_PATH/question.py --json "Generate 5-7 relevant hashtags for this article about '$CURRENT_TREND'. Return ONLY hashtags separated by spaces, no explanations. Article: ${SEARCH_RESULT:0:1000}" --pubkey "system" 2>/dev/null | jq -r '.answer // .' 2>/dev/null)

# Clean and format tags
INTELLIGENT_TAGS=$(echo "$INTELLIGENT_TAGS" | sed 's/#//g' | sed 's/,//g' | tr -s ' ' | head -c 200)

echo "   Tags: $INTELLIGENT_TAGS"

# Generate illustration image (optional, only if ComfyUI is available)
ILLUSTRATION_URL=""
if $MY_PATH/comfyui.me.sh >/dev/null 2>&1; then
    echo ""
    echo "🎨 Generating illustration image..."
    
    # Create an optimized SD prompt
    SD_PROMPT=$($MY_PATH/question.py --json "Create a Stable Diffusion prompt for an image about: ${CURRENT_TREND}. RULES: 1) ONLY visual elements 2) NO text, NO words, NO emojis 3) Use simple English 4) Focus on colors, composition, style" --pubkey "system" 2>/dev/null | jq -r '.answer // .' 2>/dev/null | head -c 300)
    
    if [[ -n "$SD_PROMPT" ]]; then
        ILLUSTRATION_URL=$($MY_PATH/generate_image.sh "$SD_PROMPT" 2>/dev/null)
        if [[ -n "$ILLUSTRATION_URL" ]]; then
            echo "   ✅ Illustration: $ILLUSTRATION_URL"
        fi
    fi
else
    echo "⚠️  ComfyUI not available, skipping illustration"
fi

# Build location info for article
LOCATION_INFO="$GEO"
if [[ -n "$LAT" && -n "$LON" ]]; then
    LOCATION_INFO="$GEO (📍 $LAT, $LON)"
fi

# Build article content with header
ARTICLE_CONTENT="# 📈 Tendance Google: $CURRENT_TREND

📅 *Publié le $CURRENT_DATE à $CURRENT_TIME*
📍 *Région: $LOCATION_INFO*

---

$SEARCH_RESULT

---

## 📊 Contexte

Cette tendance a été détectée sur [Google Trends]($(get_trend_details "$CURRENT_TREND" "$GEO")) comme l'une des recherches les plus populaires en $GEO.

**Autres tendances du moment:** $ALL_TRENDS

---

*Article généré automatiquement par UPlanet IA à partir des tendances Google.*

#GoogleTrends #$GEO #UPlanet #trending"

# Build tags JSON for kind 30023
echo ""
echo "📤 Preparing NOSTR publication..."

# Build tag array
TAG_ARRAY='["d", "'$D_TAG'"], ["title", "📈 Tendance: '"$CURRENT_TREND"'"], ["summary", "'"$ARTICLE_SUMMARY"'"], ["published_at", "'$CURRENT_TIMESTAMP'"], ["t", "GoogleTrends"], ["t", "trending"], ["t", "'$GEO'"], ["t", "UPlanet"]'

# Add intelligent tags
for tag in $INTELLIGENT_TAGS; do
    if [[ -n "$tag" ]]; then
        TAG_ARRAY="$TAG_ARRAY, [\"t\", \"$tag\"]"
    fi
done

# Add image tag if available
if [[ -n "$ILLUSTRATION_URL" ]]; then
    TAG_ARRAY="$TAG_ARRAY, [\"image\", \"$ILLUSTRATION_URL\"]"
fi

# Add geolocation tag if GPS coordinates are available
if [[ -n "$LAT" && -n "$LON" ]]; then
    TAG_ARRAY="$TAG_ARRAY, [\"g\", \"${LAT},${LON}\"]"
fi

TAGS_JSON="[$TAG_ARRAY]"

echo "   Kind: 30023 (Long-form Content)"
echo "   D-tag: $D_TAG"
echo "   Title: Tendance: $CURRENT_TREND"

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "🔍 DRY RUN - Would publish:"
    echo "================================"
    echo "Content preview (first 500 chars):"
    echo "${ARTICLE_CONTENT:0:500}..."
    echo ""
    echo "Tags JSON:"
    echo "$TAGS_JSON" | jq . 2>/dev/null || echo "$TAGS_JSON"
    echo ""
    echo "To publish for real, remove --dry-run flag"
    exit 0
fi

# Publish to NOSTR
echo ""
echo "📡 Publishing to NOSTR relay..."

SEND_RESULT=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
    --keyfile "$KEYFILE_PATH" \
    --content "$ARTICLE_CONTENT" \
    --relays "${myRELAY:-ws://127.0.0.1:7777}" \
    --tags "$TAGS_JSON" \
    --kind 30023 \
    --json 2>&1)

SEND_EXIT_CODE=$?

if [[ $SEND_EXIT_CODE -eq 0 ]]; then
    EVENT_ID=$(echo "$SEND_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
    RELAYS_SUCCESS=$(echo "$SEND_RESULT" | jq -r '.relays_success // 0' 2>/dev/null)
    
    if [[ -n "$EVENT_ID" ]]; then
        echo ""
        echo "✅ Blog published successfully!"
        echo "   Event ID: $EVENT_ID"
        echo "   Relays: $RELAYS_SUCCESS"
        
        # Update state file
        if [[ -n "$LAT" && -n "$LON" ]]; then
            cat > "$STATE_FILE" << EOF
{
    "trend": "$CURRENT_TREND",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "event_id": "$EVENT_ID",
    "geo": "$GEO",
    "lat": "$LAT",
    "lon": "$LON",
    "all_trends": "$ALL_TRENDS"
}
EOF
        else
            cat > "$STATE_FILE" << EOF
{
    "trend": "$CURRENT_TREND",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "event_id": "$EVENT_ID",
    "geo": "$GEO",
    "all_trends": "$ALL_TRENDS"
}
EOF
        fi
        echo ""
        echo "💾 State saved to $STATE_FILE"
        
        # Output JSON result
        echo ""
        echo "📋 Result JSON:"
        echo "$SEND_RESULT" | jq . 2>/dev/null || echo "$SEND_RESULT"
        
        exit 0
    else
        echo "⚠️  Event may not have been published correctly" >&2
        echo "Response: $SEND_RESULT" >&2
        exit 1
    fi
else
    echo "❌ Failed to publish blog" >&2
    echo "Error: $SEND_RESULT" >&2
    exit 1
fi

