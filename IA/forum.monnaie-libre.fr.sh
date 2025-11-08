#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# forum.monnaie-libre.fr.sh - Discourse forum scraper automation for MULTIPASS
# Called by NOSTRCARD.refresh.sh when .forum.monnaie-libre.fr.cookie is detected
# Creates a daily journal blog post with forum messages from today
################################################################################

PLAYER="$1"

[[ -z "$PLAYER" ]] && echo "Usage: $0 <player_email>" && exit 1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📰 Starting Discourse forum scraper for ${PLAYER}"

# Get script directory
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"

# Get player directory and cookie file
PLAYER_DIR="$HOME/.zen/game/nostr/${PLAYER}"
COOKIE_FILE="${PLAYER_DIR}/.forum.monnaie-libre.fr.cookie"

if [[ ! -f "$COOKIE_FILE" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Cookie file not found at ${COOKIE_FILE}, skipping forum scraper"
    exit 0
fi

# Forum URL
FORUM_URL="${FORUM_MONNAIE_LIBRE_URL:-https://forum.monnaie-libre.fr}"

# Default: fetch posts from last 1 day (today)
DAYS_BACK="${FORUM_DAYS_BACK:-1}"

# Check for custom parameters in player config
PLAYER_CONFIG="${PLAYER_DIR}/.forum.monnaie-libre.fr_config"
if [[ -f "$PLAYER_CONFIG" ]]; then
    source "$PLAYER_CONFIG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Using custom forum parameters from ${PLAYER_CONFIG}"
fi

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🌐 Forum URL: ${FORUM_URL}, Days back: ${DAYS_BACK}"

# Output directory for results in ~/.zen/tmp
OUTPUT_DIR="$HOME/.zen/tmp"
mkdir -p "$OUTPUT_DIR"

# Output file with timestamp
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
JSON_OUTPUT_FILE="${OUTPUT_DIR}/forum_${PLAYER}_${TIMESTAMP}.json"
STDERR_FILE="${OUTPUT_DIR}/forum_${PLAYER}_${TIMESTAMP}.stderr"

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

# Call scraper_forum_discourse.py
if [[ -f "${MY_PATH}/scraper_forum_discourse.py" ]]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚀 Running Discourse forum scraper..."
    
    # Separate stdout (JSON) and stderr (logs)
    python3 "${MY_PATH}/scraper_forum_discourse.py" \
        "$COOKIE_FILE" \
        "$FORUM_URL" \
        --days "$DAYS_BACK" \
        --json > "$JSON_OUTPUT_FILE" 2> "$STDERR_FILE"
    
    exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        # Extract JSON and count posts
        if command -v jq >/dev/null 2>&1; then
            # Try to extract valid JSON
            VALID_JSON=$(jq -c '.' "$JSON_OUTPUT_FILE" 2>/dev/null || echo "")
            if [[ -z "$VALID_JSON" ]]; then
                # Try to extract JSON from end of file (after stderr messages)
                VALID_JSON=$(tail -100 "$JSON_OUTPUT_FILE" | jq -c '.' 2>/dev/null || echo "")
            fi
            
            if [[ -n "$VALID_JSON" ]]; then
                echo "$VALID_JSON" > "$JSON_OUTPUT_FILE"
                posts_count=$(jq -r '.total_posts // (.posts | length)' "$JSON_OUTPUT_FILE" 2>/dev/null || echo "0")
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Forum scraper completed successfully for ${PLAYER} (${posts_count} posts found)"
                
                # If no posts found, try with larger time windows
                if [[ "$posts_count" -eq 0 ]]; then
                    RETRY_DAYS=(3 7 30)
                    FOUND_POSTS=false
                    
                    for RETRY_DAY in "${RETRY_DAYS[@]}"; do
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ No posts found at ${DAYS_BACK} day(s), trying ${RETRY_DAY} days..."
                        
                        RETRY_TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
                        RETRY_JSON_OUTPUT_FILE="${OUTPUT_DIR}/forum_${PLAYER}_retry_${RETRY_DAY}d_${RETRY_TIMESTAMP}.json"
                        RETRY_STDERR_FILE="${OUTPUT_DIR}/forum_${PLAYER}_retry_${RETRY_DAY}d_${RETRY_TIMESTAMP}.stderr"
                        
                        python3 "${MY_PATH}/scraper_forum_discourse.py" \
                            "$COOKIE_FILE" \
                            "$FORUM_URL" \
                            --days "$RETRY_DAY" \
                            --json > "$RETRY_JSON_OUTPUT_FILE" 2> "$RETRY_STDERR_FILE"
                        
                        if [[ $? -eq 0 ]]; then
                            RETRY_VALID_JSON=$(jq -c '.' "$RETRY_JSON_OUTPUT_FILE" 2>/dev/null || echo "")
                            if [[ -z "$RETRY_VALID_JSON" ]]; then
                                RETRY_VALID_JSON=$(tail -100 "$RETRY_JSON_OUTPUT_FILE" | jq -c '.' 2>/dev/null || echo "")
                            fi
                            
                            if [[ -n "$RETRY_VALID_JSON" ]]; then
                                echo "$RETRY_VALID_JSON" > "$RETRY_JSON_OUTPUT_FILE"
                                retry_posts_count=$(jq -r '.total_posts // (.posts | length)' "$RETRY_JSON_OUTPUT_FILE" 2>/dev/null || echo "0")
                                
                                if [[ "$retry_posts_count" -gt 0 ]]; then
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Found ${retry_posts_count} posts at ${RETRY_DAY} days, using these results..."
                                    # Use retry results
                                    JSON_OUTPUT_FILE="$RETRY_JSON_OUTPUT_FILE"
                                    posts_count="$retry_posts_count"
                                    DAYS_BACK="$RETRY_DAY"
                                    FOUND_POSTS=true
                                    break
                                fi
                            fi
                        fi
                    done
                    
                    # If still no posts found after all retries, send error message
                    if [[ "$FOUND_POSTS" != true ]]; then
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ No posts found even after trying up to 30 days, sending error message"
                        
                        # Get user language
                        USER_LANG=$(get_user_language "$PLAYER")
                        
                        # Get player's NOSTR key if available
                        PLAYER_KEYFILE="${PLAYER_DIR}/.secret.nostr"
                        if [[ -f "$PLAYER_KEYFILE" ]]; then
                            source "$PLAYER_KEYFILE"
                            PUBKEY_HEX="$HEX"
                            KEYFILE_PATH="$PLAYER_KEYFILE"
                        else
                            source ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
                            PUBKEY_HEX="$HEX"
                            KEYFILE_PATH="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
                        fi
                        
                        FORUM_NAME=$(echo "$FORUM_URL" | sed 's|https\?://||' | sed 's|/.*||')
                        
                        # Read stderr logs for error details (remove null bytes and control characters)
                        ERROR_LOGS=""
                        if [[ -f "$STDERR_FILE" ]]; then
                            ERROR_LOGS=$(cat "$STDERR_FILE" 2>/dev/null | tr -d '\0' | strings | tail -50)
                        fi
                        
                        # Also check retry stderr files
                        for retry_file in "${OUTPUT_DIR}"/forum_${PLAYER}_retry_*d_*.stderr; do
                            if [[ -f "$retry_file" ]]; then
                                RETRY_LOG=$(cat "$retry_file" 2>/dev/null | tr -d '\0' | strings | tail -30)
                                if [[ -n "$RETRY_LOG" ]]; then
                                    ERROR_LOGS="${ERROR_LOGS}

--- Retry logs from $(basename "$retry_file") ---
${RETRY_LOG}"
                                fi
                            fi
                        done
                        
                        # Calculate expiration timestamp (25 hours from now)
                        EXPIRATION_TIMESTAMP=$(date -d '+25 hours' +%s)
                        
                        ERROR_MSG="❌ Journal du forum ${FORUM_NAME} - Aucun message trouvé

Recherche effectuée sur ${FORUM_NAME}
Fenêtres temporelles testées : 1, 3, 7 et 30 jours
Aucun message trouvé dans ces périodes.

Le forum peut être inactif ou le cookie peut être invalide.

📋 Logs d'erreur :
\`\`\`
${ERROR_LOGS}
\`\`\`

#forum #erreur #monnaie-libre"
                        
                        # Prepare tags with expiration and error report tag
                        ERROR_TAGS="["
                        ERROR_TAGS="${ERROR_TAGS}[\"t\", \"forum\"], "
                        ERROR_TAGS="${ERROR_TAGS}[\"t\", \"erreur\"], "
                        ERROR_TAGS="${ERROR_TAGS}[\"t\", \"monnaie-libre\"], "
                        ERROR_TAGS="${ERROR_TAGS}[\"t\", \"forum_error_report\"], "
                        ERROR_TAGS="${ERROR_TAGS}[\"expiration\", \"${EXPIRATION_TIMESTAMP}\"]"
                        ERROR_TAGS="${ERROR_TAGS}]"
                        
                        SEND_RESULT=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
                            --keyfile "$KEYFILE_PATH" \
                            --content "$ERROR_MSG" \
                            --relays "$myRELAY" \
                            --tags "$ERROR_TAGS" \
                            --kind "1" \
                            --json 2>&1)
                        
                        if [[ $? -eq 0 ]]; then
                            EVENT_ID=$(echo "$SEND_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Error message published (kind 1, expires in 25h). Event ID: ${EVENT_ID}"
                            
                            # Try to analyze error and suggest fixes
                            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔍 Analyzing error for fix suggestions..."
                            
                            # Read the scraper code (full file for better context)
                            SCRAPER_CODE=""
                            if [[ -f "${MY_PATH}/scraper_forum_discourse.py" ]]; then
                                SCRAPER_CODE=$(cat "${MY_PATH}/scraper_forum_discourse.py" 2>/dev/null)
                            fi
                            
                            # Generate fix suggestions using AI
                            FIX_PROMPT="Tu es un expert en développement Python et APIs web. Analyse cette erreur de scraper Discourse et propose des correctifs.

CONTEXTE: Le script Python scraper_forum_discourse.py essaie de récupérer des posts depuis l'API Discourse (https://forum.monnaie-libre.fr/latest.json) mais reçoit une réponse vide ou invalide.

Logs d'erreur du scraper:
${ERROR_LOGS}

Code Python du scraper à corriger (scraper_forum_discourse.py):
\`\`\`python
${SCRAPER_CODE}
\`\`\`

ERREUR CRITIQUE: L'erreur 'Expecting value: line 1 column 1 (char 0)' se produit dans scraper_forum_discourse.py à la ligne ~159 lors de l'appel à response.json(). L'API Discourse retourne une réponse vide ou des données non-JSON.

PROBLÈME À RÉSOUDRE:
- L'API Discourse ne retourne pas de JSON valide
- La réponse est vide ou dans un format inattendu
- Le scraper ne peut pas parser la réponse

Fournis:
1. Analyse de la cause racine: Pourquoi l'API Discourse retourne-t-elle une réponse vide/invalide?
2. Corrections de code spécifiques pour scraper_forum_discourse.py pour gérer ce cas
3. Endpoints API alternatifs ou méthodes alternatives pour récupérer les posts Discourse
4. Recommandations de test

IMPORTANT: 
- Focus UNIQUEMENT sur scraper_forum_discourse.py
- Ne mentionne PAS question.py (ce n'est pas le problème)
- Ne mentionne PAS le script bash (ce n'est pas le problème)
- Écris en français"
                            
                            FIX_SUGGESTIONS="$($MY_PATH/question.py --json "${FIX_PROMPT}" --pubkey "${PUBKEY_HEX}")"
                            FIX_SUGGESTIONS="$(echo "$FIX_SUGGESTIONS" | jq -r '.answer // .' 2>/dev/null || echo "$FIX_SUGGESTIONS")"
                            
                            if [[ -n "$FIX_SUGGESTIONS" && "$FIX_SUGGESTIONS" != "null" ]]; then
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📝 Creating blog article with fix suggestions..."
                                
                                # Generate introduction for the blog article
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📄 Generating introduction..."
                                FIX_INTRO="$($MY_PATH/question.py --json "Create an engaging introduction (2-3 paragraphs) in ${USER_LANG} language for a blog article about fixing a forum scraper error. The introduction should explain the context, the problem encountered, and introduce the solutions that will be presented. IMPORTANT: Write in ${USER_LANG} language. Context: Forum ${FORUM_NAME} scraper failed to retrieve posts. Error: ${ERROR_LOGS}" --pubkey "${PUBKEY_HEX}")"
                                FIX_INTRO="$(echo "$FIX_INTRO" | jq -r '.answer // .' 2>/dev/null || echo "$FIX_INTRO")"
                                
                                # Combine intro and suggestions
                                FIX_CONTENT="${FIX_INTRO}

${FIX_SUGGESTIONS}"
                                
                                # Generate summary for the blog article
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📄 Generating summary..."
                                FIX_SUMMARY="$($MY_PATH/question.py --json "Create a concise, engaging summary (2-3 sentences) for this blog article in ${USER_LANG} language. The summary should capture the main points about the error analysis and fix suggestions. IMPORTANT: Respond directly and clearly ONLY in the language ${USER_LANG}. Article content: ${FIX_CONTENT}" --pubkey "${PUBKEY_HEX}")"
                                FIX_SUMMARY="$(echo "$FIX_SUMMARY" | jq -r '.answer // .' 2>/dev/null || echo "$FIX_SUMMARY")"
                                FIX_SUMMARY="$(echo "$FIX_SUMMARY" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '\n' | sed 's/\s\+/ /g' | sed 's/"/\\"/g' | sed "s/'/\\'/g" | head -c 500)"
                                
                                # Generate tags (in user's language)
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🏷️ Generating tags..."
                                FIX_TAGS_AI="$($MY_PATH/question.py --json "Analyze this blog article about fixing a forum scraper error and generate 5-8 relevant hashtags in ${USER_LANG} language. Focus on: 1) Technical tags (scraper, API, debugging), 2) Forum-related tags, 3) Error fixing tags. IMPORTANT: Return ONLY the hashtags separated by spaces, no explanations. Article content: ${FIX_CONTENT}" --pubkey "${PUBKEY_HEX}")"
                                FIX_TAGS_AI="$(echo "$FIX_TAGS_AI" | jq -r '.answer // .' 2>/dev/null || echo "$FIX_TAGS_AI")"
                                FIX_TAGS_AI="$(echo "$FIX_TAGS_AI" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/#//g' | sed 's/\s\+/ /g' | head -c 200)"
                                
                                # Generate illustration
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🎨 Generating illustration..."
                                $MY_PATH/comfyui.me.sh
                                FIX_SD_PROMPT="$($MY_PATH/question.py --json "Create a Stable Diffusion prompt for an illustrative image based on this article summary: ${FIX_SUMMARY} --- CRITICAL RULES: 1) Output ONLY the prompt text, no explanations 2) NO emojis, NO special characters, NO text, NO words, NO brands, NO writing 3) ONLY visual elements and descriptive words 4) Use simple English words only 5) Focus on visual composition, colors, style, objects, scenes related to debugging, code fixing, technical solutions" --pubkey "${PUBKEY_HEX}")"
                                FIX_SD_PROMPT="$(echo "$FIX_SD_PROMPT" | jq -r '.answer // .' 2>/dev/null || echo "$FIX_SD_PROMPT")"
                                FIX_SD_PROMPT=$(echo "$FIX_SD_PROMPT" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/\s\+/ /g' | sed 's/🥺🎨✨//g' | sed 's/emoji//g' | sed 's/emojis//g' | head -c 400)
                                
                                # Get user uDRIVE path for image storage
                                USER_UDRIVE_PATH="${PLAYER_DIR}/APP/uDRIVE"
                                mkdir -p "${USER_UDRIVE_PATH}/Images"
                                FIX_ILLUSTRATION_URL="$($MY_PATH/generate_image.sh "${FIX_SD_PROMPT}" "${USER_UDRIVE_PATH}/Images" 2>/dev/null || echo "")"
                                
                                # Create blog post (kind 30023) with expiration
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📰 Publishing fix suggestions as blog article..."
                                
                                # Calculate expiration timestamp (22 hours from now)
                                FIX_EXPIRATION=$(date -d '+22 hours' +%s)
                                
                                # Prepare tags
                                FIX_TEMP_JSON="$HOME/.zen/tmp/tags_fix_${RANDOM}.json"
                                FIX_TAG_ARRAY=""
                                if [[ -n "$FIX_TAGS_AI" ]]; then
                                    IFS=' ' read -ra FIX_TAG_LIST <<< "$FIX_TAGS_AI"
                                    for tag in "${FIX_TAG_LIST[@]}"; do
                                        if [[ -n "$tag" ]]; then
                                            FIX_TAG_ARRAY="${FIX_TAG_ARRAY}[\"t\", \"$tag\"],"
                                        fi
                                    done
                                    FIX_TAG_ARRAY="${FIX_TAG_ARRAY%,}"
                                fi
                                
                                FIX_STANDARD_TAGS='["t", "forum"], ["t", "erreur"], ["t", "correctif"], ["t", "monnaie-libre"], ["t", "forum_error_report"]'
                                if [[ -n "$FIX_TAG_ARRAY" ]]; then
                                    FIX_ALL_TAGS="${FIX_STANDARD_TAGS}, ${FIX_TAG_ARRAY}"
                                else
                                    FIX_ALL_TAGS="${FIX_STANDARD_TAGS}"
                                fi
                                
                                # Create d-tag for kind 30023
                                FIX_D_TAG="forum_fix_$(date -u +%s)_$(echo -n "${FORUM_NAME}" | md5sum | cut -d' ' -f1 | head -c 8)"
                                FIX_BLOG_TITLE="🔧 Correctifs suggérés - Scraper Forum ${FORUM_NAME}"
                                
                                if [[ -n "$FIX_ILLUSTRATION_URL" ]]; then
                                    jq -n --arg title "$FIX_BLOG_TITLE" --arg summary "$FIX_SUMMARY" --arg image "$FIX_ILLUSTRATION_URL" --arg published_at "$(date -u +%s)" --arg d_tag "$FIX_D_TAG" --arg expiration "$FIX_EXPIRATION" \
                                        --argjson tags "[${FIX_ALL_TAGS}]" \
                                        '[["d", $d_tag], ["title", $title], ["summary", $summary], ["published_at", $published_at], ["image", $image], ["expiration", $expiration]] + $tags' > "$FIX_TEMP_JSON"
                                else
                                    jq -n --arg title "$FIX_BLOG_TITLE" --arg summary "$FIX_SUMMARY" --arg published_at "$(date -u +%s)" --arg d_tag "$FIX_D_TAG" --arg expiration "$FIX_EXPIRATION" \
                                        --argjson tags "[${FIX_ALL_TAGS}]" \
                                        '[["d", $d_tag], ["title", $title], ["summary", $summary], ["published_at", $published_at], ["expiration", $expiration]] + $tags' > "$FIX_TEMP_JSON"
                                fi
                                
                                FIX_EXTRA_TAGS=$(cat "$FIX_TEMP_JSON")
                                rm -f "$FIX_TEMP_JSON"
                                
                                FIX_RESULT=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
                                    --keyfile "$KEYFILE_PATH" \
                                    --content "$FIX_CONTENT" \
                                    --relays "$myRELAY" \
                                    --tags "$FIX_EXTRA_TAGS" \
                                    --kind "30023" \
                                    --json 2>&1)
                                
                                if [[ $? -eq 0 ]]; then
                                    FIX_EVENT_ID=$(echo "$FIX_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Fix suggestions published as blog article (kind 30023, expires in 22h). Event ID: ${FIX_EVENT_ID}"
                                else
                                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Failed to publish fix suggestions: $FIX_RESULT"
                                fi
                            else
                                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ No fix suggestions generated"
                            fi
                        fi
                        
                        # Cleanup retry files
                        rm -f "$RETRY_JSON_OUTPUT_FILE" "$RETRY_STDERR_FILE" 2>/dev/null
                        exit 0
                    fi
                fi
                
                # Process results and create blog post
                if [[ "$posts_count" -gt 0 ]]; then
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📝 Processing results to create journal blog post..."
                    
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
                    
                    # Format posts with full details for AI analysis (grouped by category)
                    POSTS_DETAILED=$(jq -r '.posts[] | "TITRE: \(.title)\nAUTEUR: \(.author)\nCATÉGORIE: \(.category_name // "Non classé")\nCONTENU: \(.content // "")\nRÉPONSES: \(.reply_count), LIKES: \(.like_count), VUES: \(.views)\nURL: \(.url)\n---"' "$JSON_OUTPUT_FILE" 2>/dev/null | head -100)
                    TOTAL_POSTS=$(jq -r '.total_posts' "$JSON_OUTPUT_FILE" 2>/dev/null || echo "$posts_count")
                    FORUM_NAME=$(echo "$FORUM_URL" | sed 's|https\?://||' | sed 's|/.*||')
                    
                    # Step 1: Classify posts by theme using AI
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🏷️ Classifying posts by theme..."
                    CLASSIFICATION_PROMPT="Analyze these forum posts and classify them by THEME/TOPIC (not just category). Group related discussions together. For each post, identify its main theme.

Posts to classify:
${POSTS_DETAILED}

Return a JSON structure with themes and their associated posts. Each theme should have:
- theme_name: A clear theme name
- posts: Array of post titles that belong to this theme

Focus on grouping by TOPIC/THEME (e.g., 'Économie', 'Technique', 'Gouvernance', 'Questions pratiques', etc.), not just by category.

IMPORTANT: Return ONLY valid JSON, no explanations."
                    
                    THEMES_JSON="$($MY_PATH/question.py --json "${CLASSIFICATION_PROMPT}" --pubkey "${PUBKEY_HEX}")"
                    THEMES_JSON="$(echo "$THEMES_JSON" | jq -r '.answer // .' 2>/dev/null || echo "$THEMES_JSON")"
                    
                    # Step 2: Generate blog content with theme-based analysis
                    TODAY_DATE=$(date '+%Y-%m-%d')
                    BLOG_TITLE="Journal du forum ${FORUM_NAME} - ${TODAY_DATE}"
                    BLOG_PROMPT="Create an engaging blog article (daily journal) in ${USER_LANG} language analyzing forum discussions from ${FORUM_NAME} published in the last ${DAYS_BACK} day(s). 

Total posts found: ${TOTAL_POSTS}

Posts organized by theme:
${THEMES_JSON}

Full posts details:
${POSTS_DETAILED}

CRITICAL INSTRUCTIONS:
1. Use the theme classification provided above to structure your article
2. For EACH theme section, provide:
   - A clear section header: ## [Theme Name]
   - Summary of the discussions in that theme
   - YOUR DETAILED ANALYSIS and OPINION on the users' arguments and positions
   - Critical evaluation: what's valid, what's questionable, what's interesting
   - Highlight contradictions, consensus, disagreements, or notable contributions
   - Identify trends and patterns
3. Structure the article with clear sections for each theme
4. Be ANALYTICAL and CRITICAL - provide insights, not just summaries
5. Give YOUR OPINION on the quality and validity of the arguments presented
6. Mention the forum name and date
7. Write in ${USER_LANG} language

IMPORTANT: 
- Organize by THEMES as provided in the classification
- Give YOUR OPINION and ANALYSIS on what users are saying
- Be critical but fair - evaluate arguments, point out strengths and weaknesses
- Highlight what's interesting, controversial, or noteworthy
- Make it suitable for a blog post (kind 30023)"
                    
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🤖 Generating journal content with theme analysis (language: ${USER_LANG})..."
                    BLOG_CONTENT="$($MY_PATH/question.py --json "${BLOG_PROMPT}" --pubkey "${PUBKEY_HEX}")"
                    BLOG_CONTENT="$(echo "$BLOG_CONTENT" | jq -r '.answer // .' 2>/dev/null || echo "$BLOG_CONTENT")"
                    
                    # Append links section to blog content
                    POSTS_URLS=$(jq -r '.posts[] | "\(.title) - \(.url)"' "$JSON_OUTPUT_FILE" 2>/dev/null)
                    if [[ -n "$POSTS_URLS" ]]; then
                        LINKS_SECTION="

## 🔗 Liens vers les discussions

"
                        while IFS= read -r line; do
                            if [[ -n "$line" ]]; then
                                LINKS_SECTION="${LINKS_SECTION}${line}
"
                            fi
                        done <<< "$POSTS_URLS"
                        BLOG_CONTENT="${BLOG_CONTENT}${LINKS_SECTION}"
                    fi
                    
                    # Generate summary (in user's language)
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📄 Generating summary..."
                    ARTICLE_SUMMARY="$($MY_PATH/question.py --json "Create a concise, engaging summary (2-3 sentences) for this blog article in ${USER_LANG} language. The summary should capture the main points and be suitable for a blog article header. IMPORTANT: Respond directly and clearly ONLY in the language ${USER_LANG}. Article content: ${BLOG_CONTENT}" --pubkey "${PUBKEY_HEX}")"
                    ARTICLE_SUMMARY="$(echo "$ARTICLE_SUMMARY" | jq -r '.answer // .' 2>/dev/null || echo "$ARTICLE_SUMMARY")"
                    ARTICLE_SUMMARY="$(echo "$ARTICLE_SUMMARY" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '\n' | sed 's/\s\+/ /g' | sed 's/"/\\"/g' | sed "s/'/\\'/g" | head -c 500)"
                    
                    # Generate tags (in user's language)
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🏷️ Generating tags..."
                    INTELLIGENT_TAGS="$($MY_PATH/question.py --json "Analyze this blog article and generate 5-8 relevant hashtags in ${USER_LANG} language. Focus on: 1) Main topics discussed, 2) Forum-related tags, 3) Content type tags (journal, forum, daily). IMPORTANT: Return ONLY the hashtags separated by spaces, no explanations. Article content: ${BLOG_CONTENT}" --pubkey "${PUBKEY_HEX}")"
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
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 📰 Publishing journal blog post..."
                    
                    # Prepare tags
                    temp_json="$HOME/.zen/tmp/tags_forum_${RANDOM}.json"
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
                    
                    STANDARD_TAGS='["t", "forum"], ["t", "journal"], ["t", "monnaie-libre"]'
                    if [[ -n "$TAG_ARRAY" ]]; then
                        ALL_TAGS="${STANDARD_TAGS}, ${TAG_ARRAY}"
                    else
                        ALL_TAGS="${STANDARD_TAGS}"
                    fi
                    
                    # Create d-tag for kind 30023 (unique per day)
                    D_TAG="forum_${TODAY_DATE}_$(echo -n "${FORUM_NAME}" | md5sum | cut -d' ' -f1 | head -c 8)"
                    
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
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Journal blog post published successfully! Event ID: ${EVENT_ID}"
                    else
                        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️ Failed to publish blog post: $SEND_RESULT"
                    fi
                fi
                
                # Cleanup old files (keep last 5)
                cd "$OUTPUT_DIR" && ls -t forum_${PLAYER}_*.json 2>/dev/null | tail -n +6 | xargs -r rm -f
                cd "$OUTPUT_DIR" && ls -t forum_${PLAYER}_*.stderr 2>/dev/null | tail -n +6 | xargs -r rm -f
                
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
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Forum scraper failed for ${PLAYER} (exit code: $exit_code)"
        cat "$STDERR_FILE" >&2
        exit $exit_code
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ scraper_forum_discourse.py not found at ${MY_PATH}/scraper_forum_discourse.py"
    exit 1
fi

