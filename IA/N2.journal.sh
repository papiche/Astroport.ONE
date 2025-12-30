#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
# N2.journal.sh - Personal N² Network Journal Generator
#
# This script generates personalized journals for MULTIPASS accounts based on
# their N² network (friends + friends of friends) activity.
#
# === JOURNAL HIERARCHY ===
# - Daily: Collects kind 1 messages from N² network (last 24h)
# - Weekly: Synthesizes published daily journals (last 7 days)
# - Monthly: Synthesizes published weekly journals (last 28 days)
# - Yearly: Synthesizes published monthly journals (last 365 days)
#
# === USAGE ===
# ./N2.journal.sh <PLAYER_EMAIL> [--type daily|weekly|monthly|yearly] [--force]
#
# === PARAMETERS ===
# PLAYER_EMAIL : The email of the MULTIPASS account (required)
# --type       : Force a specific summary type (optional, auto-detected by default)
# --force      : Generate journal even if not scheduled (optional)
# --dry-run    : Generate but don't publish (optional)
#
# === OUTPUT ===
# Publishes a kind 30023 (long-form content) event to the MULTIPASS wall
################################################################################

MY_PATH="$(dirname "$0")"
MY_PATH="$(cd "$MY_PATH" && pwd)"

# Source common tools
[[ ! -s "$MY_PATH/../tools/my.sh" ]] && echo "ERROR: Astroport.ONE is missing!" && exit 1
source "$MY_PATH/../tools/my.sh"

# =================== LOGGING SYSTEM ===================
LOGFILE="$HOME/.zen/tmp/N2.journal.log"
mkdir -p "$(dirname "$LOGFILE")"

log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$$] [$level] $*" | tee -a "$LOGFILE"
}

log_metric() {
    local metric="$1"
    local value="$2"
    local player="${3:-GLOBAL}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$$] [METRIC] [$player] $metric=$value" >> "$LOGFILE"
}

# =================== FUNCTIONS ===================

# Validate NIP-23 compliance for kind 30023 events
validate_nip23_event() {
    local content="$1"
    local title="$2"
    local d_tag="$3"
    local tags="$4"
    
    if [[ -z "$content" ]]; then
        log "ERROR" "NIP-23 validation failed: content is empty"
        return 1
    fi
    
    if [[ -z "$title" ]]; then
        log "ERROR" "NIP-23 validation failed: title is empty"
        return 1
    fi
    
    if [[ -z "$d_tag" ]]; then
        log "ERROR" "NIP-23 validation failed: d tag is empty"
        return 1
    fi
    
    if [[ ${#content} -gt 200000 ]]; then
        log "WARN" "NIP-23 validation: content very long (${#content} chars), may be rejected by some relays"
    fi
    
    if [[ ${#title} -gt 200 ]]; then
        log "WARN" "NIP-23 validation: title very long (${#title} chars), may be truncated by clients"
    fi
    
    log "DEBUG" "NIP-23 validation passed: content=${#content} chars, title='$title', d='$d_tag'"
    return 0
}

# Determine summary type based on days since birthdate
determine_summary_type() {
    local birthdate="$1"
    local todate="$2"
    
    local birthdate_seconds=$(date -d "$birthdate" +%s)
    local today_seconds=$(date -d "$todate" +%s)
    local days_since_birth=$(( (today_seconds - birthdate_seconds) / 86400 ))
    
    if [[ $((days_since_birth % 365)) -eq 0 && $days_since_birth -ge 365 ]]; then
        echo "Yearly"
    elif [[ $((days_since_birth % 28)) -eq 0 && $days_since_birth -ge 28 ]]; then
        echo "Monthly"
    elif [[ $((days_since_birth % 7)) -eq 0 && $days_since_birth -ge 7 ]]; then
        echo "Weekly"
    else
        echo "Daily"
    fi
}

# Get summary parameters based on type
get_summary_params() {
    local summary_type="$1"
    local todate="$2"
    
    case "$summary_type" in
        "Yearly")
            echo "365|🗓️ Yearly Friends Activity Summary - $todate"
            ;;
        "Monthly")
            echo "28|📅 Monthly Friends Activity Summary - $todate"
            ;;
        "Weekly")
            echo "7|📊 Weekly Friends Activity Summary - $todate"
            ;;
        *)
            echo "1|📝 Daily Friends Activity Summary - $todate"
            ;;
    esac
}

# Generate AI prompt based on summary type
generate_ai_prompt() {
    local summary_type="$1"
    local player="$2"
    local player_nprofile="$3"
    local summary_file="$4"
    local summary_period="$5"
    local lang_instruction="$6"
    
    local ai_prompt=""
    
    if [[ "$summary_type" == "Daily" ]]; then
        ai_prompt="You are a personal AI assistant creating a reconnection summary for ${player}.

LANGUAGE REQUIREMENT: ${lang_instruction}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Create a personalized daily N² network journal for ${player} (nostr:$player_nprofile)

STRUCTURE:
1. **Executive Summary** (2-3 lines): Brief overview of network activity in the last ${summary_period}
2. **What You Missed**: Most important events, announcements, discussions (grouped by theme)
3. **Active Contributors**: Who posted what, with key insights per author
4. **Key Highlights**: New connections, important discussions, trending topics
5. **Network Insights**: Patterns in your N² network (extended circle)
6. **Follow-up Suggestions**: What to check out next

STYLE GUIDELINES:
- Use emojis for visual appeal (but don't overdo it)
- Write in Markdown (headers, bold, lists, quotes)
- Be conversational and personal (write TO ${player}, not about them)
- Keep it concise but informative
- Never omit an author - each friend matters
- Focus on value: what would ${player} want to know?
- Add relevant hashtags for key topics

NOSTR REFERENCES FORMAT (CRITICAL FOR CORACLE COMPATIBILITY):
- ALWAYS preserve existing nostr: references from source content (e.g., nostr:nprofile1..., nostr:npub1...)
- When mentioning authors, use the EXACT format from source: nostr:nprofile1... or nostr:npub1...
- DO NOT modify, shorten, or reformat nostr: references - they must remain exactly as provided
- Coracle recognizes nostr:nprofile1... and nostr:npub1... formats for clickable profile links

CRITICAL: ${lang_instruction}"

    elif [[ "$summary_type" == "Weekly" ]]; then
        ai_prompt="You are a personal AI assistant creating a weekly reconnection summary for ${player}.

LANGUAGE REQUIREMENT: ${lang_instruction}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Synthesize the week's daily summaries into a weekly overview for ${player}

STRUCTURE:
1. **Weekly Overview** (3-4 lines): What defined this week in your network
2. **Week in Review**: Major events and discussions (grouped by theme/time)
3. **Trending Topics**: What themes emerged over the week
4. **Active Period Analysis**: When was your network most active
5. **Evolution & Changes**: How conversations evolved day-to-day
6. **Weekly Highlights**: Top 5 moments of the week

ANALYSIS FOCUS:
- Identify patterns and trends across daily summaries
- Show progression: how topics evolved over the week
- Highlight connections between different days
- Extract meta-insights about network behavior

STYLE GUIDELINES:
- Use emojis sparingly for section markers
- Create a narrative arc for the week
- Use Markdown for structure
- Be analytical yet accessible
- Focus on big picture, not individual messages

NOSTR REFERENCES FORMAT (CRITICAL FOR CORACLE COMPATIBILITY):
- ALWAYS preserve existing nostr: references from source content
- When referencing authors mentioned in daily summaries, use the EXACT format from source
- DO NOT modify, shorten, or reformat nostr: references

CRITICAL: ${lang_instruction}"

    elif [[ "$summary_type" == "Monthly" ]]; then
        ai_prompt="You are a personal AI assistant creating a monthly reconnection summary for ${player}.

LANGUAGE REQUIREMENT: ${lang_instruction}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Synthesize the month's weekly summaries into a monthly overview for ${player}

STRUCTURE:
1. **Monthly Overview** (4-5 lines): The month at a glance in your network
2. **Month in Review**: Major developments week by week
3. **Trending Themes**: What dominated conversations this month
4. **Network Evolution**: How your community changed/grew
5. **Key Milestones**: Significant events that shaped the month
6. **Monthly Highlights**: Top moments and achievements

ANALYSIS FOCUS:
- Synthesize weekly patterns into monthly trends
- Identify long-term developments
- Show community evolution
- Extract strategic insights
- Connect disparate events into coherent narrative

STYLE GUIDELINES:
- Use emojis for major section markers
- Create a coherent month-long narrative
- Use Markdown for clear structure
- Be strategic and forward-looking
- Focus on impact and significance

NOSTR REFERENCES FORMAT (CRITICAL FOR CORACLE COMPATIBILITY):
- ALWAYS preserve existing nostr: references from source content
- When referencing authors mentioned in weekly summaries, use the EXACT format from source
- DO NOT modify, shorten, or reformat nostr: references

CRITICAL: ${lang_instruction}"

    else
        ai_prompt="You are a personal AI assistant creating a yearly reconnection summary for ${player}.

LANGUAGE REQUIREMENT: ${lang_instruction}

SOURCE CONTENT:
[TEXT]
$(cat "$summary_file")
[/TEXT]

TASK: Synthesize the year's monthly summaries into a yearly overview for ${player}

STRUCTURE:
1. **Yearly Overview** (5-6 lines): The year that was in your network
2. **Year in Review**: Quarter-by-quarter analysis of major developments
3. **Annual Themes**: What defined your network this year
4. **Community Growth**: How your N² network evolved over 12 months
5. **Seasonal Patterns**: Identify recurring themes by season
6. **Key Achievements**: Major milestones and breakthroughs
7. **Looking Forward**: Emerging trends for next year

ANALYSIS FOCUS:
- Identify long-term trends and cycles
- Show annual evolution and growth
- Extract strategic insights from monthly data
- Recognize seasonal patterns
- Celebrate achievements and growth
- Provide forward-looking perspective

STYLE GUIDELINES:
- Use emojis for major section markers
- Create an epic year-long narrative
- Use Markdown with rich formatting
- Be reflective and visionary
- Focus on transformation and impact
- Make it memorable and inspiring

NOSTR REFERENCES FORMAT (CRITICAL FOR CORACLE COMPATIBILITY):
- ALWAYS preserve existing nostr: references from source content
- When referencing authors mentioned in monthly summaries, use the EXACT format from source
- DO NOT modify, shorten, or reformat nostr: references

CRITICAL: ${lang_instruction}"
    fi
    
    echo "$ai_prompt"
}

# Get language instruction based on user preference
get_language_instruction() {
    local user_lang="$1"
    
    case "$user_lang" in
        "fr")
            echo "Rédige EXCLUSIVEMENT en FRANÇAIS. Ne traduis pas, écris directement en français."
            ;;
        "es")
            echo "Escribe EXCLUSIVAMENTE en ESPAÑOL. No traduzcas, escribe directamente en español."
            ;;
        "de")
            echo "Schreibe AUSSCHLIESSLICH auf DEUTSCH. Übersetze nicht, schreibe direkt auf Deutsch."
            ;;
        "it")
            echo "Scrivi ESCLUSIVAMENTE in ITALIANO. Non tradurre, scrivi direttamente in italiano."
            ;;
        "pt")
            echo "Escreva EXCLUSIVAMENTE em PORTUGUÊS. Não traduza, escreva diretamente em português."
            ;;
        *)
            echo "Write EXCLUSIVELY in ENGLISH. Do not translate, write directly in English."
            ;;
    esac
}

# =================== MAIN FUNCTION ===================

generate_n2_journal() {
    local PLAYER="$1"
    local FORCE_TYPE="$2"
    local FORCE="$3"
    local DRY_RUN="$4"
    
    log "INFO" "📝 Starting N² journal generation for ${PLAYER}"
    
    # Validate player directory exists
    local PLAYER_DIR="${HOME}/.zen/game/nostr/${PLAYER}"
    if [[ ! -d "$PLAYER_DIR" ]]; then
        log "ERROR" "Player directory not found: $PLAYER_DIR"
        return 1
    fi
    
    # Load player data
    local HEX=$(cat "$PLAYER_DIR/HEX" 2>/dev/null)
    if [[ -z "$HEX" ]]; then
        log "ERROR" "Missing HEX for $PLAYER"
        return 1
    fi
    
    local BIRTHDATE=$(cat "$PLAYER_DIR/TODATE" 2>/dev/null)
    if [[ -z "$BIRTHDATE" ]]; then
        log "ERROR" "Missing BIRTHDATE for $PLAYER"
        return 1
    fi
    
    # Determine summary type
    local summary_type
    if [[ -n "$FORCE_TYPE" ]]; then
        summary_type="$FORCE_TYPE"
        log "INFO" "Forced summary type: $summary_type"
    else
        summary_type=$(determine_summary_type "$BIRTHDATE" "$TODATE")
        log "INFO" "Auto-detected summary type: $summary_type"
    fi
    
    # Get summary parameters
    local params=$(get_summary_params "$summary_type" "$TODATE")
    local summary_days=$(echo "$params" | cut -d'|' -f1)
    local summary_title=$(echo "$params" | cut -d'|' -f2)
    local summary_period
    
    case "$summary_type" in
        "Yearly") summary_period="365 days" ;;
        "Monthly") summary_period="28 days" ;;
        "Weekly") summary_period="7 days" ;;
        *) summary_period="24 hours" ;;
    esac
    
    log "INFO" "Generating $summary_type friends summary for ${PLAYER} (${summary_period})"
    
    # Get friends list
    local friends_list=($(${MY_PATH}/../tools/nostr_get_N1.sh "$HEX" 2>/dev/null))
    
    if [[ ${#friends_list[@]} -eq 0 ]]; then
        log "DEBUG" "No friends found for ${PLAYER} - skipping N² journal"
        return 0
    fi
    
    log "INFO" "Found ${#friends_list[@]} N1 friends for ${PLAYER}"
    
    # Get friends of friends (N²)
    log "DEBUG" "Starting N² friends generation for ${PLAYER}"
    local n2_start=$(date +%s)
    local n2_friends=()
    
    for friend_hex in "${friends_list[@]}"; do
        local friend_friends=($(${MY_PATH}/../tools/nostr_get_N1.sh "$friend_hex" 2>/dev/null))
        n2_friends+=("${friend_friends[@]}")
    done
    
    local n2_end=$(date +%s)
    local n2_duration=$((n2_end - n2_start))
    log "DEBUG" "N² friends generation completed in ${n2_duration}s"
    
    # Remove duplicates
    local all_friends=("${friends_list[@]}" "${n2_friends[@]}")
    local unique_friends=($(printf '%s\n' "${all_friends[@]}" | sort -u))
    friends_list=("${unique_friends[@]}")
    
    log "INFO" "Total N² network: ${#friends_list[@]} friends for ${PLAYER}"
    
    # Create temporary directory
    local MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    local summary_dir="${HOME}/.zen/tmp/${MOATS}/friends_summary_${PLAYER}"
    mkdir -p "$summary_dir"
    
    # Get player nprofile
    local player_nprofile=$(${MY_PATH}/../tools/nostr_hex2nprofile.sh "$HEX" 2>/dev/null)
    [[ -z "$player_nprofile" ]] && player_nprofile="$HEX"
    
    # Create summary file
    local summary_file="${summary_dir}/personal_n2_journal_${PLAYER}.md"
    
    echo "# $summary_title" > "$summary_file"
    echo "**Date**: $TODATE" >> "$summary_file"
    echo "**MULTIPASS**: $PLAYER" >> "$summary_file"
    echo "**NProfile**: nostr:$player_nprofile" >> "$summary_file"
    echo "**Period**: $summary_period" >> "$summary_file"
    echo "**Type**: Personal N² Journal ($summary_type)" >> "$summary_file"
    echo "**Network**: ${#friends_list[@]} friends (N1 + N²)" >> "$summary_file"
    
    # Add GPS if available
    local player_gps_file="${PLAYER_DIR}/GPS"
    if [[ -f "$player_gps_file" ]]; then
        local player_lat=$(grep "^LAT=" "$player_gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
        local player_lon=$(grep "^LON=" "$player_gps_file" | tail -1 | cut -d'=' -f2 | tr -d ';' | xargs)
        if [[ -n "$player_lat" && -n "$player_lon" && "$player_lat" != "" && "$player_lon" != "" ]]; then
            echo "**Location**: $player_lat, $player_lon" >> "$summary_file"
            echo "**UMAP Zone**: ${player_lat}_${player_lon}" >> "$summary_file"
        fi
    fi
    
    echo "" >> "$summary_file"
    
    # Get messages based on summary type
    local since_timestamp=$(date -d "${summary_days} days ago" +%s)
    local friends_messages=""
    
    if [[ "$summary_type" == "Weekly" ]]; then
        log "INFO" "Fetching daily summaries for Weekly journal"
        friends_messages=$(${MY_PATH}/../tools/nostr_get_events.sh \
            --kind 30023 \
            --author "$HEX" \
            --tag-t "SummaryType:Daily" \
            --since "$since_timestamp" \
            --limit 100 2>/dev/null | \
            jq -c 'select(.kind == 30023) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')
            
    elif [[ "$summary_type" == "Monthly" ]]; then
        log "INFO" "Fetching weekly summaries for Monthly journal"
        friends_messages=$(${MY_PATH}/../tools/nostr_get_events.sh \
            --kind 30023 \
            --author "$HEX" \
            --tag-t "SummaryType:Weekly" \
            --since "$since_timestamp" \
            --limit 100 2>/dev/null | \
            jq -c 'select(.kind == 30023) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')
            
    elif [[ "$summary_type" == "Yearly" ]]; then
        log "INFO" "Fetching monthly summaries for Yearly journal"
        friends_messages=$(${MY_PATH}/../tools/nostr_get_events.sh \
            --kind 30023 \
            --author "$HEX" \
            --tag-t "SummaryType:Monthly" \
            --since "$since_timestamp" \
            --limit 100 2>/dev/null | \
            jq -c 'select(.kind == 30023) | {id: .id, content: .content, created_at: .created_at, tags: .tags}')
            
    else
        # Daily: get raw messages from N² network
        log "INFO" "Fetching kind 1 messages from N² network for Daily journal"
        
        if [[ ${#friends_list[@]} -gt 0 ]]; then
            local friends_comma=$(IFS=','; echo "${friends_list[*]}")
            
            friends_messages=$(${MY_PATH}/../tools/nostr_get_events.sh \
                --kind 1 \
                --author "$friends_comma" \
                --since "$since_timestamp" \
                --limit 500 2>/dev/null | \
                jq -c 'select(.kind == 1) | {id: .id, content: .content, created_at: .created_at, author: .pubkey, tags: .tags}')
        fi
    fi
    
    # Process messages
    local message_count=0
    
    if [[ -n "$friends_messages" && "$friends_messages" != "" ]]; then
        while read -r message; do
            [[ -z "$message" || "$message" == "" ]] && continue
            
            local content=$(echo "$message" | jq -r .content 2>/dev/null)
            local created_at=$(echo "$message" | jq -r .created_at 2>/dev/null)
            
            [[ "$content" == "null" || "$created_at" == "null" ]] && continue
            
            local date_str=$(date -d "@$created_at" '+%Y-%m-%d %H:%M' 2>/dev/null)
            [[ -z "$date_str" ]] && date_str="Unknown date"
            
            if [[ "$summary_type" == "Daily" ]]; then
                local author_hex=$(echo "$message" | jq -r .author 2>/dev/null)
                [[ "$author_hex" == "null" || -z "$author_hex" ]] && continue
                
                local author_nprofile=$(${MY_PATH}/../tools/nostr_hex2nprofile.sh "$author_hex" 2>/dev/null)
                [[ -z "$author_nprofile" ]] && author_nprofile="$author_hex"
                
                local message_application=$(echo "$message" | jq -r '.tags[] | select(.[0] == "application") | .[1]' 2>/dev/null | head -n 1)
                local message_latitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "latitude") | .[1]' 2>/dev/null | head -n 1)
                local message_longitude=$(echo "$message" | jq -r '.tags[] | select(.[0] == "longitude") | .[1]' 2>/dev/null | head -n 1)
                
                echo "### 📝 $date_str" >> "$summary_file"
                echo "**Author**: nostr:$author_nprofile" >> "$summary_file"
                
                if [[ -n "$message_application" && "$message_application" != "null" ]]; then
                    echo "**App**: $message_application" >> "$summary_file"
                fi
                
                if [[ -n "$message_latitude" && -n "$message_longitude" && "$message_latitude" != "null" && "$message_longitude" != "null" ]]; then
                    echo "**Location**: $message_latitude, $message_longitude" >> "$summary_file"
                fi
                
                echo "" >> "$summary_file"
                echo "$content" >> "$summary_file"
                echo "" >> "$summary_file"
                
            elif [[ "$summary_type" == "Weekly" ]]; then
                echo "### 📅 $date_str" >> "$summary_file"
                echo "**Daily Summary**" >> "$summary_file"
                echo "" >> "$summary_file"
                echo "$content" >> "$summary_file"
                echo "" >> "$summary_file"
                echo "---" >> "$summary_file"
                echo "" >> "$summary_file"
                
            elif [[ "$summary_type" == "Monthly" ]]; then
                echo "### 📊 $date_str" >> "$summary_file"
                echo "**Weekly Summary**" >> "$summary_file"
                echo "" >> "$summary_file"
                echo "$content" >> "$summary_file"
                echo "" >> "$summary_file"
                echo "---" >> "$summary_file"
                echo "" >> "$summary_file"
                
            else
                echo "### 🗓️ $date_str" >> "$summary_file"
                echo "**Monthly Summary**" >> "$summary_file"
                echo "" >> "$summary_file"
                echo "$content" >> "$summary_file"
                echo "" >> "$summary_file"
                echo "---" >> "$summary_file"
                echo "" >> "$summary_file"
            fi
            
            ((message_count++))
        done < <(echo "$friends_messages")
    fi
    
    log "INFO" "Processed $message_count messages for ${PLAYER}"
    
    if [[ $message_count -eq 0 ]]; then
        log "DEBUG" "No messages found for ${PLAYER} - skipping journal"
        rm -rf "$summary_dir"
        return 0
    fi
    
    # Determine AI threshold
    local ai_threshold=5
    case "$summary_type" in
        "Weekly") ai_threshold=5 ;;
        "Monthly") ai_threshold=3 ;;
        "Yearly") ai_threshold=8 ;;
        *) ai_threshold=5 ;;
    esac
    
    # Generate AI summary if needed
    if [[ $message_count -gt $ai_threshold ]]; then
        log "INFO" "Generating AI summary ($message_count > $ai_threshold threshold)"
        
        local USER_LANG=$(cat "${PLAYER_DIR}/LANG" 2>/dev/null)
        [[ -z "$USER_LANG" ]] && USER_LANG="en"
        
        local lang_instruction=$(get_language_instruction "$USER_LANG")
        local ai_prompt=$(generate_ai_prompt "$summary_type" "$PLAYER" "$player_nprofile" "$summary_file" "$summary_period" "$lang_instruction")
        
        log "DEBUG" "Starting AI summary generation"
        local ai_start=$(date +%s)
        local ai_summary=$(${MY_PATH}/question.py "$ai_prompt" --model "gemma3:12b")
        local ai_end=$(date +%s)
        local ai_duration=$((ai_end - ai_start))
        log "DEBUG" "AI summary generation completed in ${ai_duration}s"
        
        echo "$ai_summary" > "$summary_file"
    fi
    
    # Prepare for publication
    local summary_content=$(cat "$summary_file")
    local d_tag="personal-n2-journal-${PLAYER}-${summary_type,,}-${TODATE}"
    local published_at=$(date +%s)
    
    # Create summary text for article
    local summary_text=$(echo "$summary_content" | head -c 200 | sed 's/"/\\"/g')
    if [[ ${#summary_content} -gt 200 ]]; then
        summary_text="${summary_text}..."
    fi
    
    # Build NIP-23 compliant tags
    local ExtraTags=$(jq -c -n \
        --arg d "$d_tag" \
        --arg title "$summary_title" \
        --arg summary "$summary_text" \
        --arg published_at "$published_at" \
        --arg type "$summary_type" \
        '[["d", $d], ["title", $title], ["summary", $summary], ["published_at", $published_at], ["t", "PersonalN2Journal"], ["t", "N2Network"], ["t", $type], ["t", "UPlanet"], ["t", "SummaryType:" + $type]]')
    
    # Validate NIP-23 compliance
    if ! validate_nip23_event "$summary_content" "$summary_title" "$d_tag" "$ExtraTags"; then
        log "ERROR" "NIP-23 validation failed for ${PLAYER}, skipping publication"
        rm -rf "$summary_dir"
        return 1
    fi
    
    # Truncate if too long
    if [[ ${#summary_content} -gt 100000 ]]; then
        log "WARN" "Content too long (${#summary_content} chars), truncating to 100k"
        summary_content=$(echo "$summary_content" | head -c 100000)
    fi
    
    # Dry run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY-RUN: Would publish N² journal for ${PLAYER}"
        log "INFO" "  Title: $summary_title"
        log "INFO" "  Type: $summary_type"
        log "INFO" "  Messages: $message_count"
        log "INFO" "  Content length: ${#summary_content} chars"
        cat "$summary_file"
        rm -rf "$summary_dir"
        return 0
    fi
    
    # Publish to NOSTR
    local KEYFILE_PATH="${PLAYER_DIR}/.secret.nostr"
    
    if [[ ! -s "$KEYFILE_PATH" ]]; then
        log "ERROR" "Missing keyfile: $KEYFILE_PATH"
        rm -rf "$summary_dir"
        return 1
    fi
    
    log "DEBUG" "Publishing N² journal to relay: $myRELAY"
    
    local SEND_RESULT=$(python3 "${MY_PATH}/../tools/nostr_send_note.py" \
        --keyfile "$KEYFILE_PATH" \
        --content "$summary_content" \
        --relays "$myRELAY" \
        --tags "$ExtraTags" \
        --kind 30023 \
        --json 2>&1)
    local SEND_EXIT_CODE=$?
    
    if [[ $SEND_EXIT_CODE -eq 0 ]]; then
        local EVENT_ID=$(echo "$SEND_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
        local RELAYS_SUCCESS=$(echo "$SEND_RESULT" | jq -r '.relays_success // 0' 2>/dev/null)
        
        if [[ -n "$EVENT_ID" && "$RELAYS_SUCCESS" -gt 0 ]]; then
            log "INFO" "✅ N² journal published for ${PLAYER} (ID: $EVENT_ID, $message_count messages, type: $summary_type)"
            log_metric "N2_JOURNAL_PUBLISHED" "$message_count" "${PLAYER}"
            echo "$EVENT_ID"
        else
            log "WARN" "⚠️ N² journal may not have been published correctly for ${PLAYER}"
            log "DEBUG" "Response: $SEND_RESULT"
        fi
    else
        log "ERROR" "❌ Failed to publish N² journal for ${PLAYER}. Exit code: $SEND_EXIT_CODE"
        log "DEBUG" "Error output: $SEND_RESULT"
    fi
    
    # Cleanup
    rm -rf "$summary_dir"
    
    return $SEND_EXIT_CODE
}

# =================== ARGUMENT PARSING ===================

show_help() {
    echo "Usage: $0 <PLAYER_EMAIL> [OPTIONS]"
    echo ""
    echo "Generate and publish a personal N² network journal for a MULTIPASS account."
    echo ""
    echo "Arguments:"
    echo "  PLAYER_EMAIL    Email of the MULTIPASS account (required)"
    echo ""
    echo "Options:"
    echo "  --type TYPE     Force summary type: daily, weekly, monthly, yearly"
    echo "                  (default: auto-detected based on days since registration)"
    echo "  --force         Generate journal even if not scheduled"
    echo "  --dry-run       Generate but don't publish (preview mode)"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 user@example.com"
    echo "  $0 user@example.com --type weekly"
    echo "  $0 user@example.com --dry-run"
    echo "  $0 user@example.com --type daily --force"
    echo ""
    echo "Journal Hierarchy:"
    echo "  Daily   → Collects kind 1 messages from N² network (last 24h)"
    echo "  Weekly  → Synthesizes published daily journals (last 7 days)"
    echo "  Monthly → Synthesizes published weekly journals (last 28 days)"
    echo "  Yearly  → Synthesizes published monthly journals (last 365 days)"
}

# Parse arguments
PLAYER=""
FORCE_TYPE=""
FORCE="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            FORCE_TYPE="$2"
            # Capitalize first letter
            FORCE_TYPE="$(echo "${FORCE_TYPE:0:1}" | tr '[:lower:]' '[:upper:]')${FORCE_TYPE:1}"
            shift 2
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$PLAYER" ]]; then
                PLAYER="$1"
            else
                echo "Unknown argument: $1"
                show_help
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required argument
if [[ -z "$PLAYER" ]]; then
    echo "ERROR: PLAYER_EMAIL is required"
    show_help
    exit 1
fi

# Validate force type if provided
if [[ -n "$FORCE_TYPE" ]]; then
    case "$FORCE_TYPE" in
        Daily|Weekly|Monthly|Yearly)
            ;;
        *)
            echo "ERROR: Invalid summary type: $FORCE_TYPE"
            echo "Valid types: daily, weekly, monthly, yearly"
            exit 1
            ;;
    esac
fi

# Run main function
generate_n2_journal "$PLAYER" "$FORCE_TYPE" "$FORCE" "$DRY_RUN"
exit $?

