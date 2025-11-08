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

[[ -z "$PLAYER" ]] && echo "Usage: $0 <player_email>" && exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🛒 Starting Leboncoin scraper for ${PLAYER}"

# Get script directory
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Get player directory and cookie file
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"
COOKIE_FILE="${PLAYER_DIR}/.leboncoin.fr.cookie"

if [[ ! -f "$COOKIE_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Cookie file not found at ${COOKIE_FILE}, skipping Leboncoin scraper"
    exit 0
fi

# Get player GPS coordinates for search
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
SEARCH_QUERY="${LEBONCOIN_SEARCH_QUERY:-}"  # Default: empty (all donations)
SEARCH_RADIUS="${LEBONCOIN_SEARCH_RADIUS:-20000}"  # Default: 20km
SEARCH_LIMIT="${LEBONCOIN_SEARCH_LIMIT:-30}"  # Default: 30 results

# Check for custom search parameters in player config
PLAYER_CONFIG="${PLAYER_DIR}/.leboncoin_config"
if [[ -f "$PLAYER_CONFIG" ]]; then
    source "$PLAYER_CONFIG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Using custom search parameters from ${PLAYER_CONFIG}"
fi

RADIUS_KM=$((SEARCH_RADIUS / 1000))
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Search query: '${SEARCH_QUERY:-all donations}', radius: ${SEARCH_RADIUS}m (${RADIUS_KM}km)"

# Output directory for results in ~/.zen/tmp
OUTPUT_DIR="$HOME/.zen/tmp"
mkdir -p "$OUTPUT_DIR"

# Output file with timestamp
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
JSON_OUTPUT_FILE="${OUTPUT_DIR}/leboncoin_${PLAYER}_${TIMESTAMP}.json"
STDERR_FILE="${OUTPUT_DIR}/leboncoin_${PLAYER}_${TIMESTAMP}.stderr"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📝 Results will be saved to: ${JSON_OUTPUT_FILE}"

# Source my.sh for NOSTR tools
[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh

# Function to get user language from LANG file
get_user_language() {
    local email="$1"
    local lang_file="$HOME/.zen/game/nostr/${email}/LANG"
    
    if [[ -f "$lang_file" ]]; then
        local user_lang=$(cat "$lang_file" 2>/dev/null | tr -d '\n' | head -c 10)
        if [[ -n "$user_lang" ]]; then
            echo "$user_lang"
            return 0
        fi
    fi
    
    # Default to French if no language file found
    echo "fr"
    return 1
}

# Call scraper_leboncoin.py
if [[ -f "${MY_PATH}/scraper_leboncoin.py" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Running Leboncoin scraper..."
    
    # Build command with donation-only and JSON output
    CMD_ARGS=(
        "$COOKIE_FILE"
        "${SEARCH_QUERY:-}"
        "$LAT"
        "$LON"
        "$SEARCH_RADIUS"
        "--donation-only"
        "--owner-type" "private"
        "--json"
        "--limit" "$SEARCH_LIMIT"
    )
    
    # Separate stdout (JSON) and stderr (logs)
    python3 "${MY_PATH}/scraper_leboncoin.py" "${CMD_ARGS[@]}" > "$JSON_OUTPUT_FILE" 2> "$STDERR_FILE"
    
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Extract JSON from output (remove stderr messages that might be mixed)
        # The JSON should be the last valid JSON object in the file
        if command -v jq >/dev/null 2>&1; then
            # Try to extract valid JSON
            VALID_JSON=$(jq -c '.' "$JSON_OUTPUT_FILE" 2>/dev/null || echo "")
            if [[ -z "$VALID_JSON" ]]; then
                # Try to extract JSON from end of file (after stderr messages)
                VALID_JSON=$(tail -100 "$JSON_OUTPUT_FILE" | jq -c '.' 2>/dev/null || echo "")
            fi
            
            if [[ -n "$VALID_JSON" ]]; then
                echo "$VALID_JSON" > "$JSON_OUTPUT_FILE"
                result_count=$(jq -r '.total // (.ads | length)' "$JSON_OUTPUT_FILE" 2>/dev/null || echo "0")
                ads_count=$(jq -r '.ads | length' "$JSON_OUTPUT_FILE" 2>/dev/null || echo "0")
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Leboncoin scraper completed successfully for ${PLAYER} (${result_count} total, ${ads_count} returned)"
                
                # Process results and create blog post
                if [[ "$ads_count" -gt 0 ]]; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📝 Processing results to create blog post..."
                    
                    # Get user language
                    USER_LANG=$(get_user_language "$PLAYER")
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🌍 Using language: ${USER_LANG}"
                    
                    # Get player's NOSTR key if available
                    PLAYER_KEYFILE="${PLAYER_DIR}/.secret.nostr"
                    if [[ -f "$PLAYER_KEYFILE" ]]; then
                        source "$PLAYER_KEYFILE"
                        PUBKEY_HEX="$HEX"
                    else
                        # Use CAPTAIN key as fallback
                        source ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
                        PUBKEY_HEX="$HEX"
                    fi
                    
                    # Format ads for AI processing (limit to first 20 for content generation)
                    ADS_SUMMARY=$(jq -r '.ads[0:20] | map("• \(.subject) - \(.location.city_label // "N/A") (\(.location.zipcode // "")) - \(.url)") | join("\n")' "$JSON_OUTPUT_FILE" 2>/dev/null)
                    TOTAL_ADS=$(jq -r '.total' "$JSON_OUTPUT_FILE" 2>/dev/null || echo "$ads_count")
                    
                    # Generate blog content using AI (in user's language)
                    BLOG_TITLE="Annonces de dons autour de ${LAT}, ${LON} (rayon ${RADIUS_KM}km)"
                    BLOG_PROMPT="Create an engaging blog article in ${USER_LANG} language about free items (donations) available on Leboncoin in the area around coordinates ${LAT}, ${LON} within a ${RADIUS_KM}km radius. 

Total ads found: ${TOTAL_ADS}
Sample ads:
${ADS_SUMMARY}

Create a blog post that:
1. Introduces the topic of finding free items locally
2. Highlights interesting items from the list
3. Provides tips for finding and claiming free items
4. Mentions the location and radius
5. Is engaging and useful for readers

IMPORTANT: Write in ${USER_LANG} language, be concise but informative, and make it suitable for a blog post (kind 30023)."
                    
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🤖 Generating blog content with AI (language: ${USER_LANG})..."
                    BLOG_CONTENT="$($MY_PATH/question.py --json "${BLOG_PROMPT}" --pubkey "${PUBKEY_HEX}")"
                    BLOG_CONTENT="$(echo "$BLOG_CONTENT" | jq -r '.answer // .' 2>/dev/null || echo "$BLOG_CONTENT")"
                    
                    # Generate summary (in user's language)
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📄 Generating summary..."
                    ARTICLE_SUMMARY="$($MY_PATH/question.py --json "Create a concise, engaging summary (2-3 sentences) for this blog article in ${USER_LANG} language. The summary should capture the main points and be suitable for a blog article header. IMPORTANT: Respond directly and clearly ONLY in the language ${USER_LANG}. Article content: ${BLOG_CONTENT}" --pubkey "${PUBKEY_HEX}")"
                    ARTICLE_SUMMARY="$(echo "$ARTICLE_SUMMARY" | jq -r '.answer // .' 2>/dev/null || echo "$ARTICLE_SUMMARY")"
                    ARTICLE_SUMMARY="$(echo "$ARTICLE_SUMMARY" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '\n' | sed 's/\s\+/ /g' | sed 's/"/\\"/g' | sed "s/'/\\'/g" | head -c 500)"
                    
                    # Generate tags (in user's language)
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🏷️ Generating tags..."
                    INTELLIGENT_TAGS="$($MY_PATH/question.py --json "Analyze this blog article and generate 5-8 relevant hashtags in ${USER_LANG} language. Focus on: 1) Main topics (free items, donations, local), 2) Location-related tags, 3) Content type tags. IMPORTANT: Return ONLY the hashtags separated by spaces, no explanations. Article content: ${BLOG_CONTENT}" --pubkey "${PUBKEY_HEX}")"
                    INTELLIGENT_TAGS="$(echo "$INTELLIGENT_TAGS" | jq -r '.answer // .' 2>/dev/null || echo "$INTELLIGENT_TAGS")"
                    INTELLIGENT_TAGS="$(echo "$INTELLIGENT_TAGS" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/#//g' | sed 's/\s\+/ /g' | head -c 200)"
                    
                    # Generate illustration
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🎨 Generating illustration..."
                    $MY_PATH/comfyui.me.sh
                    SD_PROMPT="$($MY_PATH/question.py --json "Create a Stable Diffusion prompt for an illustrative image based on this article summary: ${ARTICLE_SUMMARY} --- CRITICAL RULES: 1) Output ONLY the prompt text, no explanations 2) NO emojis, NO special characters, NO text, NO words, NO brands, NO writing 3) ONLY visual elements and descriptive words 4) Use simple English words only 5) Focus on visual composition, colors, style, objects, scenes" --pubkey "${PUBKEY_HEX}")"
                    SD_PROMPT="$(echo "$SD_PROMPT" | jq -r '.answer // .' 2>/dev/null || echo "$SD_PROMPT")"
                    SD_PROMPT=$(echo "$SD_PROMPT" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/\s\+/ /g' | sed 's/🥺🎨✨//g' | sed 's/emoji//g' | sed 's/emojis//g' | head -c 400)
                    
                    # Get user uDRIVE path for image storage
                    USER_UDRIVE_PATH="${PLAYER_DIR}/APP/uDRIVE"
                    mkdir -p "${USER_UDRIVE_PATH}/Images"
                    ILLUSTRATION_URL="$($MY_PATH/generate_image.sh "${SD_PROMPT}" "${USER_UDRIVE_PATH}/Images" 2>/dev/null || echo "")"
                    
                    # Create blog post (kind 30023)
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📰 Publishing blog post..."
                    
                    # Prepare tags
                    temp_json="$HOME/.zen/tmp/tags_leboncoin_${RANDOM}.json"
                    TAG_ARRAY=""
                    if [[ -n "$INTELLIGENT_TAGS" ]]; then
                        IFS=' ' read -ra TAG_LIST <<< "$INTELLIGENT_TAGS"
                        for tag in "${TAG_LIST[@]}"; do
                            if [[ -n "$tag" ]]; then
                                TAG_ARRAY="${TAG_ARRAY}[\"t\", \"$tag\"],"
                            fi
                        done
                        TAG_ARRAY="${TAG_ARRAY%,}"
                    fi
                    
                    STANDARD_TAGS='["t", "leboncoin"], ["t", "donations"], ["t", "gratuit"]'
                    if [[ -n "$TAG_ARRAY" ]]; then
                        ALL_TAGS="${STANDARD_TAGS}, ${TAG_ARRAY}"
                    else
                        ALL_TAGS="${STANDARD_TAGS}"
                    fi
                    
                    # Create d-tag for kind 30023
                    D_TAG="leboncoin_$(date -u +%s)_$(echo -n "${BLOG_TITLE}" | md5sum | cut -d' ' -f1 | head -c 8)"
                    
                    if [[ -n "$ILLUSTRATION_URL" ]]; then
                        jq -n --arg title "$BLOG_TITLE" --arg summary "$ARTICLE_SUMMARY" --arg image "$ILLUSTRATION_URL" --arg published_at "$(date -u +%s)" --arg d_tag "$D_TAG" \
                            --argjson tags "[${ALL_TAGS}]" \
                            '[["d", $d_tag], ["title", $title], ["summary", $summary], ["published_at", $published_at], ["image", $image]] + $tags' > "$temp_json"
                    else
                        jq -n --arg title "$BLOG_TITLE" --arg summary "$ARTICLE_SUMMARY" --arg published_at "$(date -u +%s)" --arg d_tag "$D_TAG" \
                            --argjson tags "[${ALL_TAGS}]" \
                            '[["d", $d_tag], ["title", $title], ["summary", $summary], ["published_at", $published_at]] + $tags' > "$temp_json"
                    fi
                    
                    ExtraTags=$(cat "$temp_json")
                    rm -f "$temp_json"
                    
                    # Publish blog post
                    if [[ -f "$PLAYER_KEYFILE" ]]; then
                        KEYFILE_PATH="$PLAYER_KEYFILE"
                    else
                        KEYFILE_PATH="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
                    fi
                    
                    SEND_RESULT=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
                        --keyfile "$KEYFILE_PATH" \
                        --content "$BLOG_CONTENT" \
                        --relays "$myRELAY" \
                        --tags "$ExtraTags" \
                        --kind "30023" \
                        --json 2>&1)
                    
                    if [[ $? -eq 0 ]]; then
                        EVENT_ID=$(echo "$SEND_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Blog post published successfully! Event ID: ${EVENT_ID}"
                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Failed to publish blog post: $SEND_RESULT"
                    fi
                else
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ No ads found, skipping blog post creation"
                fi
                
                # Cleanup old files (keep last 5)
                cd "$OUTPUT_DIR" && ls -t leboncoin_${PLAYER}_*.json 2>/dev/null | tail -n +6 | xargs -r rm -f
                cd "$OUTPUT_DIR" && ls -t leboncoin_${PLAYER}_*.stderr 2>/dev/null | tail -n +6 | xargs -r rm -f
                
                exit 0
            else
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ No valid JSON found in output"
                exit 1
            fi
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ jq not found, cannot process results"
            exit 1
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Leboncoin scraper failed for ${PLAYER} (exit code: $exit_code)"
        cat "$STDERR_FILE" >&2
        exit $exit_code
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ scraper_leboncoin.py not found at ${MY_PATH}/scraper_leboncoin.py"
    exit 1
fi

