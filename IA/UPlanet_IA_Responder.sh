#!/bin/bash
###################################################################
# UPlanet_IA_Responder.sh
# Script de réponse IA pour UPlanet
#
# Usage: $0 "$pubkey" "$event_id" "$latitude" "$longitude" "$content" "$url"
#
# Fonctionnalités:
# - Analyse des messages et médias reçus via UPlanet
# - Détection automatique des #tags (#search, #mp3, #video, etc.)
# - Traitement selon ta tag et médias (conversion, téléchargement, stockage IPFS)
# - Génération de réponses IA via Ollama
# - Publication des réponses sur la clé NOSTR du Capitaine
# Tags spéciaux:
# - #BRO #BOT : Active la réponse IA (par défaut)
# - #search : Perplexica Search
# - #image : Générer une image avec ComfyUI
# - #video : Générer une vidéo avec ComfyUI
# - #music : Générer une musique avec ComfyUI (#parole pour les paroles)
# - #youtube : Télécharger une vidéo (YouTube, Rumble, Vimeo, etc.) (720p max) #mp3 pour convertir en audio
# - #mem : Afficher le contenu de la mémoire de conversation
# - #rec : Enregistrer le message dans la mémoire IA (utilisateur et UMAP)
# - #rec2 : Enregistrer automatiquement la réponse du bot dans la mémoire IA
# - #reset : Effacer la mémoire de conversation
# - #pierre : Synthèse vocale avec la voix Pierre (Orpheus TTS)
# - #amelie : Synthèse vocale avec la voix Aurélie (Orpheus TTS)
# - #plantnet : Reconnaissance de plantes avec PlantNet (image requise)
###################################################################
PUBKEY="$1"
EVENT="$2"
LAT="$3"
LON="$4"
MESSAGE="$5"
URL="$6"
KNAME="$7"
ORIGINAL_GEO_LAT="$8"  # Precise latitude from original message's 'g' tag (optional)
ORIGINAL_GEO_LON="$9"  # Precise longitude from original message's 'g' tag (optional)

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
exec 2>&1 >> ~/.zen/tmp/IA.log

# Function to send error email to CAPTAINEMAIL using mailjet.sh
send_error_email() {
    local error_message="$1"
    local log_file="$2"
    local timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    
    # Create error report
    local error_report="$HOME/.zen/tmp/IA_error_${timestamp}.html"
    cat > "$error_report" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>UPlanet IA Responder Error Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f44336; color: white; padding: 10px; border-radius: 5px; }
        .section { margin: 15px 0; padding: 10px; border-left: 3px solid #2196F3; }
        .code { background-color: #f5f5f5; padding: 10px; border-radius: 3px; font-family: monospace; white-space: pre-wrap; }
        .error { color: #d32f2f; font-weight: bold; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🚨 UPlanet IA Responder Error Report</h1>
        <p>Timestamp: $timestamp</p>
    </div>
    
    <div class="section">
        <h2>❌ Error Details</h2>
        <p class="error">$error_message</p>
    </div>
    
    <div class="section">
        <h2>📋 Parameters</h2>
        <ul>
            <li><strong>PUBKEY:</strong> $PUBKEY</li>
            <li><strong>EVENT:</strong> $EVENT</li>
            <li><strong>LAT:</strong> $LAT</li>
            <li><strong>LON:</strong> $LON</li>
            <li><strong>MESSAGE:</strong> $MESSAGE</li>
            <li><strong>KNAME:</strong> $KNAME</li>
        </ul>
    </div>
    
    <div class="section">
        <h2>📝 Recent Logs</h2>
        <div class="code">$(tail -50 "$log_file" 2>/dev/null || echo "No log file found")</div>
    </div>
    
    <div class="section">
        <h2>🖥️ System Information</h2>
        <div class="code">$(uname -a)
$(date)</div>
    </div>
    
    <div class="section">
        <h2>🔧 Troubleshooting</h2>
        <ul>
            <li>Check if all required services are running (Ollama, ComfyUI, Perplexica)</li>
            <li>Verify NOSTR keys and relay connectivity</li>
            <li>Check disk space and permissions</li>
            <li>Review recent changes to the system</li>
        </ul>
    </div>
</body>
</html>
EOF
    
    # Send email using mailjet.sh
    if [[ -n "$CAPTAINEMAIL" ]]; then
        echo "📧 Sending error email to $CAPTAINEMAIL..." >&2
        $MY_PATH/../tools/mailjet.sh --expire 24h  "$CAPTAINEMAIL" "$error_report" "UPlanet IA Error - $timestamp" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "✅ Error email sent successfully to $CAPTAINEMAIL" >&2
        else
            echo "❌ Failed to send error email to $CAPTAINEMAIL" >&2
        fi
    else
        echo "⚠️ CAPTAINEMAIL not set, cannot send error email" >&2
    fi
    
    # Clean up after 1 hour
    (sleep 3600 && rm -f "$error_report") &
}

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

# Function to get user uDRIVE directory based on email
get_user_udrive_path() {
    local email="$1"
    if [ -z "$email" ]; then
        echo "Error: Email required for uDRIVE path" >&2
        return 1
    fi
    
    # Find user directory by email
    local nostr_base_path="$HOME/.zen/game/nostr"
    local user_dir=""
    
    if [ -d "$nostr_base_path" ]; then
        for email_dir in "$nostr_base_path"/*; do
            if [ -d "$email_dir" ] && [[ "$email_dir" == *"$email"* ]]; then
                user_dir="$email_dir"
                break
            fi
        done
    fi
    
    if [ -n "$user_dir" ] && [ -d "$user_dir" ]; then
        local udrive_path="$user_dir/APP/uDRIVE"
        mkdir -p "$udrive_path"
        echo "$udrive_path"
        return 0
    else
        echo "Error: User directory not found for email: $email" >&2
        return 1
    fi
}

# Function to get user uDRIVE path from KNAME (email format)
get_user_udrive_from_kname() {
    # Check if KNAME is in email format
    if [[ "$KNAME" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        local udrive_path=$(get_user_udrive_path "$KNAME")
        if [ $? -eq 0 ]; then
            echo "Using uDRIVE path: $udrive_path" >&2
            echo "$udrive_path"
            return 0
        else
            echo "Warning: Could not get uDRIVE path for email: $KNAME" >&2
            return 1
        fi
    else
        echo "Warning: KNAME is not in email format: $KNAME" >&2
        return 1
    fi
}

# Optimisation: Pre-compute current timestamp
CURRENT_TIMESTAMP=$(date +%s)
CURRENT_TIME_STR=$(date '+%Y-%m-%d %H:%M:%S')

[[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]] && echo "ERROR. Astroport.ONE is missing !!" && exit 1
source ~/.zen/Astroport.ONE/tools/my.sh ## finding UPLANETNAME

## Maintain Ollama : lsof -i :11434
if ! $MY_PATH/ollama.me.sh; then
    echo "Error: Failed to maintain Ollama connection" >&2
    exit 1
fi

# --- Help function ---
print_help() {
  echo "Usage: $(basename "$0") [--help] <pubkey> <latitude> <longitude> <content> [url] [KNAME]"
  echo ""
  echo "  <pubkey>     Public key (HEX format)."
  echo "  <event_id>   Event ID (HEX format)."
  echo "  <latitude>   Latitude."
  echo "  <longitude>  Longitude."
  echo "  <content>    Text content of the UPlanet message."
  echo "  [url]        URL of an image (optional)."
  echo "  [KNAME]      NOSTR key name (optional)."
  echo ""
  echo "Options:"
  echo "  --help       Display this help message."
  echo ""
  echo "Description:"
  echo "  This script analyzes a UPlanet message and image, generates"
  echo "  Ollama response, and publish it using KNAME NOSTR key."
  echo ""
  echo "Example:"
  echo "  $(basename "$0") <pubkey_hex> <event_id> 0.00 0.00 \"What is it\" https://ipfs.copylaradio.com/ipfs/QmeUMJvPdyPiteR7iQXCnZy4mvKBnghNkYpMTbrpZfMGPq/pipe.jpeg"
}

# --- Handle --help option ---
if [[ "$1" == "--help" ]]; then
  print_help
  exit 0
fi

# --- Check for correct number of arguments ---
if [[ $# -lt 5 ]]; then
  echo "Error: Not enough arguments provided."
  print_help
  exit 1
fi

## Optimisation: Extract URLs once - improved extraction
if [ -z "$URL" ]; then
    # First, try to get URL from original event's imeta tags (most reliable)
    if [[ -n "$EVENT" ]]; then
        local original_event=$(get_event_by_id "$EVENT" 2>/dev/null)
        if [[ -n "$original_event" ]]; then
            # Extract imeta tag with url
            URL=$(echo "$original_event" | jq -r '.tags[] | select(.[0] == "imeta") | .[1] // empty' 2>/dev/null | grep -oP 'url\s+\K[^\s]+' | head -n1)
            if [[ -z "$URL" ]]; then
                # Try alternative imeta format: ["imeta", "url", "https://..."]
                URL=$(echo "$original_event" | jq -r '.tags[] | select(.[0] == "imeta" and .[1] == "url") | .[2] // empty' 2>/dev/null | head -n1)
            fi
        fi
    fi
    
    # If no URL from tags, extract from message text (improved pattern)
    if [[ -z "$URL" ]]; then
        # Extract IPFS URLs more precisely - stop at end of filename
        URL=$(echo "$MESSAGE" | grep -oE 'https?://[^[:space:]#]+/ipfs/[A-Za-z0-9]+/[^[:space:]#]+\.(jpg|jpeg|png|gif|webp|JPG|JPEG|PNG|GIF|WEBP)' | head -n1)
        
        if [[ -z "$URL" ]]; then
            # Fallback: extract any URL ending with image extension, stop at whitespace or #
            URL=$(echo "$MESSAGE" | awk 'match($0, /https?:\/\/[^[:space:]#]+\.(png|gif|jpg|jpeg|webp|PNG|GIF|JPG|JPEG|WEBP)/) { 
                url = substr($0, RSTART, RLENGTH)
                # Remove any trailing characters after extension
                sub(/[^a-zA-Z0-9_.-]+.*$/, "", url)
                print url
            }' | head -n 1)
        fi
    fi
    
    # Extract any URL for general use (first http/https URL found, stop at whitespace)
    ANYURL=$(echo "$MESSAGE" | awk 'match($0, /https?:\/\/[^[:space:]#]+/) { 
        url = substr($0, RSTART, RLENGTH)
        # Stop at whitespace or # character
        sub(/[[:space:]#].*$/, "", url)
        print url
    }' | head -n 1)
fi

# Clean URL if it contains description text after the filename
if [[ -n "$URL" ]]; then
    # Remove everything after the image file extension
    URL=$(echo "$URL" | sed -E 's/(https?:\/\/[^[:space:]#]+\.(jpg|jpeg|png|gif|webp|JPG|JPEG|PNG|GIF|WEBP))[^[:space:]#]*.*/\1/')
fi

echo "Received parameters:" >&2
echo "  PUBKEY: $PUBKEY" >&2
echo "  EVENT: $EVENT" >&2
echo "  LAT: $LAT" >&2
echo "  LON: $LON" >&2
echo "  MESSAGE: $MESSAGE" >&2
echo "  IMAGE: $URL" >&2
echo "  FIRSTURL: $FIRSTURL" >&2
echo "  KNAME: $KNAME" >&2
echo "" >&2

# Define log function
log() {
    echo "[$CURRENT_TIME_STR] $1" >&2
}

# Optimisation: Detect secret mode early
SECRET_MODE=false
[[ "$8" == "--secret" ]] && SECRET_MODE=true

# Initialize PlantNet UMAP mode flag
USE_UMAP_FOR_PLANTNET=false

# Initialize PlantNet JSON variable (will be set by handle_plantnet_recognition)
PLANTNET_JSON=""

# Optimisation: Parse tags once at the beginning
message_text=$(echo "$MESSAGE" | tr '\n' ' ')
declare -A TAGS
TAGS[BRO]=false
TAGS[BOT]=false
TAGS[reset]=false
TAGS[mem]=false
TAGS[search]=false
TAGS[image]=false
TAGS[video]=false
TAGS[music]=false
TAGS[youtube]=false
TAGS[pierre]=false
TAGS[amelie]=false
TAGS[rec2]=false
TAGS[all]=false
TAGS[plantnet]=false
TAGS[cookie]=false
TAGS[inventory]=false
TAGS[plant]=false
TAGS[insect]=false
TAGS[animal]=false
TAGS[person]=false
TAGS[object]=false
TAGS[place]=false

# Single pass tag detection
if [[ "$message_text" =~ \#BRO\ + ]]; then TAGS[BRO]=true; fi
if [[ "$message_text" =~ \#BOT\ + ]]; then TAGS[BOT]=true; fi
if [[ "$message_text" =~ \#reset ]]; then TAGS[reset]=true; fi
if [[ "$message_text" =~ \#mem ]]; then TAGS[mem]=true; fi
if [[ "$message_text" =~ \#search ]]; then TAGS[search]=true; fi
if [[ "$message_text" =~ \#image ]]; then TAGS[image]=true; fi
if [[ "$message_text" =~ \#video ]]; then TAGS[video]=true; fi
if [[ "$message_text" =~ \#music ]]; then TAGS[music]=true; fi
if [[ "$message_text" =~ \#youtube ]]; then TAGS[youtube]=true; fi
if [[ "$message_text" =~ \#pierre ]]; then TAGS[pierre]=true; fi
if [[ "$message_text" =~ \#amelie ]]; then TAGS[amelie]=true; fi
if [[ "$message_text" =~ \#rec2 ]]; then TAGS[rec2]=true; fi
if [[ "$message_text" =~ \#all ]]; then TAGS[all]=true; fi
if [[ "$message_text" =~ \#plantnet ]]; then TAGS[plantnet]=true; fi
if [[ "$message_text" =~ \#cookie ]]; then TAGS[cookie]=true; fi
if [[ "$message_text" =~ \#inventory ]]; then TAGS[inventory]=true; fi
if [[ "$message_text" =~ \#plant ]]; then TAGS[plant]=true; fi
if [[ "$message_text" =~ \#insect ]]; then TAGS[insect]=true; fi
if [[ "$message_text" =~ \#animal ]]; then TAGS[animal]=true; fi
if [[ "$message_text" =~ \#person ]]; then TAGS[person]=true; fi
if [[ "$message_text" =~ \#object ]]; then TAGS[object]=true; fi
if [[ "$message_text" =~ \#place ]]; then TAGS[place]=true; fi

# Detect memory slot once
memory_slot=0
for i in {1..12}; do
    if [[ "$message_text" =~ \#${i}([[:space:]]|$) ]]; then
        memory_slot=$i
        echo "DEBUG: Detected memory slot $i in message: $message_text" >&2
        break
    fi
done
echo "DEBUG: Final memory_slot value: $memory_slot" >&2

# Optimisation: Set user_id once
user_id="$KNAME"
[[ -z "$user_id" ]] && user_id="$PUBKEY"

# Function to check if user has access to memory slots 1-12
check_memory_slot_access() {
    local user_id="$1"
    local slot="$2"
    
    echo "DEBUG: Checking memory access for user: $user_id, slot: $slot" >&2
    
    # Slot 0 is always accessible
    if [[ "$slot" == "0" ]]; then
        echo "DEBUG: Slot 0 is always accessible" >&2
        return 0
    fi
    
    # For slots 1-12, check if user is in ~/.zen/game/players/
    if [[ "$slot" -ge 1 && "$slot" -le 12 ]]; then
        [[ -d "$HOME/.zen/game/players/$user_id" ]] && return 0 || return 1
    fi
    
    return 0  # Default allow for other cases
}

# Function to send memory access denied message
send_memory_access_denied() {
    local pubkey="$1"
    local event_id="$2"
    local slot="$3"
    
    (
    source $HOME/.zen/Astroport.ONE/tools/my.sh
    source ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr ## CAPTAIN SPEAKING
    if [[ "$pubkey" != "$HEX" && "$NSEC" != "" ]]; then
        NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC")
        KEYFILE_PATH="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
        
        DENIED_MSG="⚠️ Accès refusé aux slots de mémoire 1-12.

Pour utiliser les slots de mémoire 1-12, vous devez être sociétaire CopyLaRadio et posséder une ZenCard.

Le slot 0 reste accessible pour tous les utilisateurs autorisés.

Pour devenir sociétaire : $myIPFS/ipns/copylaradio.com

Votre Capitaine.
#CopyLaRadio #mem"

        # Add 1-hour TTL (NIP-40 expiration) for error messages
        EXPIRATION_TS=$(($(date +%s) + 3600))
        TAGS_JSON='[["e","'$event_id'"],["p","'$pubkey'"],["t","MemoryAccessDenied"],["expiration","'$EXPIRATION_TS'"]]'
        
        python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
          --keyfile "$KEYFILE_PATH" \
          --content "$DENIED_MSG" \
          --relays "$myRELAY" \
          --tags "$TAGS_JSON" \
          --kind 1 \
          --json >/dev/null 2>&1
    fi
    ) &
}

# Function to format PlantNet JSON result as text
format_plantnet_json_to_text() {
    local plantnet_json="$1"
    local latitude="$2"
    local longitude="$3"
    local image_url="$4"
    
    if [[ -z "$plantnet_json" ]] || ! echo "$plantnet_json" | jq empty 2>/dev/null; then
        return 1
    fi
    
    local success=$(echo "$plantnet_json" | jq -r '.success // false' 2>/dev/null)
    
    if [[ "$success" == "true" ]]; then
        local scientific_name=$(echo "$plantnet_json" | jq -r '.best_match.scientific_name // ""' 2>/dev/null)
        local common_names=$(echo "$plantnet_json" | jq -r '.best_match.common_names // []' 2>/dev/null)
        local confidence=$(echo "$plantnet_json" | jq -r '.best_match.confidence // 0' 2>/dev/null)
        local confidence_pct=$(echo "$plantnet_json" | jq -r '.best_match.confidence_pct // 0' 2>/dev/null)
        local wikipedia_url=$(echo "$plantnet_json" | jq -r '.best_match.wikipedia_url // ""' 2>/dev/null)
        local alternatives=$(echo "$plantnet_json" | jq -r '.alternatives // []' 2>/dev/null)
        
        # Format common names
        local common_name_str=""
        if [[ "$common_names" != "[]" ]] && [[ -n "$common_names" ]]; then
            local names_array=$(echo "$common_names" | jq -r '.[:3] | join(", ")' 2>/dev/null)
            if [[ -n "$names_array" ]]; then
                common_name_str="\n🏷️  Noms communs : ${names_array}"
            fi
        fi
        
        # Determine confidence level
        local confidence_emoji="🔴"
        local confidence_text="Incertain"
        if [[ $confidence_pct -ge 70 ]]; then
            confidence_emoji="🟢"
            confidence_text="Très probable"
        elif [[ $confidence_pct -ge 50 ]]; then
            confidence_emoji="🟡"
            confidence_text="Probable"
        elif [[ $confidence_pct -ge 30 ]]; then
            confidence_emoji="🟠"
            confidence_text="Possible"
        fi
        
        local result_content="🌿 Reconnaissance de plante

✅ Identification réussie

🔬 Nom scientifique : ${scientific_name}${common_name_str}

${confidence_emoji} Confiance : ${confidence_pct}% (${confidence_text})

📍 Localisation : ${latitude}, ${longitude}

📖 En savoir plus : ${wikipedia_url}
"
        
        # Add alternatives if available
        local alt_count=$(echo "$alternatives" | jq 'length' 2>/dev/null)
        if [[ $alt_count -gt 0 ]]; then
            result_content="${result_content}
🔎 Autres possibilités :
"
            local i=2
            while IFS= read -r alt; do
                local alt_name=$(echo "$alt" | jq -r '.scientific_name // ""' 2>/dev/null)
                local alt_common=$(echo "$alt" | jq -r '.common_names[0] // ""' 2>/dev/null)
                local alt_conf=$(echo "$alt" | jq -r '.confidence // 0' 2>/dev/null)
                local alt_conf_pct=$(awk "BEGIN {printf \"%.0f\", ${alt_conf} * 100}")
                
                local common_str=""
                [[ -n "$alt_common" ]] && common_str=" (${alt_common})"
                
                local bar_length=$(awk "BEGIN {printf \"%.0f\", ${alt_conf_pct} / 10}")
                [[ $bar_length -lt 1 ]] && bar_length=1
                [[ $bar_length -gt 10 ]] && bar_length=10
                
                local bar=""
                for ((j=1; j<=bar_length; j++)); do bar="${bar}▓"; done
                for ((j=$((bar_length+1)); j<=10; j++)); do bar="${bar}░"; done
                
                result_content="${result_content}
${i}. ${alt_name}${common_str}
   ${bar} ${alt_conf_pct}%"
                i=$((i+1))
            done < <(echo "$alternatives" | jq -c '.[:4]' 2>/dev/null | jq -c '.[]' 2>/dev/null)
        fi
        
        result_content="${result_content}

━━━━━━━━━━━━━━━━━━━━━━━━━━

🔬 Source : https://plantnet.org
💡 Astuce : Plus la confiance est élevée, plus l'identification est fiable"
        
        # Note: image_url is already in imeta tags, don't add to content to avoid duplication
        
        echo "$result_content"
    else
        # No results or error
        local error_msg=$(echo "$plantnet_json" | jq -r '.error // "no_match"' 2>/dev/null)
        
        echo "🌿 Reconnaissance de plante

❌ Aucune correspondance trouvée

La plante n'a pas pu être identifiée avec certitude dans la base de données PlantNet.

💡 Conseils pour améliorer la reconnaissance :

📸 Prenez une photo plus claire et nette
🌱 Assurez-vous que la plante occupe la majeure partie de l'image
☀️ Évitez les ombres portées et les reflets
🍃 Photographiez les détails : feuilles, fleurs, fruits ou écorce
🔍 Prenez plusieurs angles si possible

📍 Localisation : ${latitude}, ${longitude}

━━━━━━━━━━━━━━━━━━━━━━━━━━

🔬 Source : https://plantnet.org
💾 Base de données : Plus de 40 000 espèces référencées"
    fi
}

# Function to handle PlantNet recognition with image description and ORE integration
# Returns: plantnet_result (formatted text) on stdout, sets PLANTNET_SUCCESS=true/false globally
# Stores JSON in PLANTNET_JSON global variable
handle_plantnet_recognition() {
    local image_url="$1"
    local latitude="$2"
    local longitude="$3"
    local user_id="$4"
    local event_id="$5"
    local pubkey="$6"
    
    echo "PlantNet: Starting recognition process with ORE integration..." >&2
    PLANTNET_SUCCESS=false
    PLANTNET_JSON=""  # Initialize global JSON variable
    
    # Call PlantNet recognition script ONCE with --json flag
    echo "PlantNet: Calling PlantNet API (JSON mode)..." >&2
    PLANTNET_JSON=$($MY_PATH/plantnet_recognition.py "$image_url" "$latitude" "$longitude" "$user_id" "$event_id" "$pubkey" --json 2>/dev/null)
    
    local exit_code=$?
    if [[ $exit_code -eq 0 && -n "$PLANTNET_JSON" ]] && echo "$PLANTNET_JSON" | jq empty 2>/dev/null; then
        echo "PlantNet: Recognition completed successfully" >&2
        
        local success=$(echo "$PLANTNET_JSON" | jq -r '.success // false' 2>/dev/null)
        if [[ "$success" == "true" ]]; then
            PLANTNET_SUCCESS=true
            
            # Format JSON to text for user display
            local plantnet_result=$(format_plantnet_json_to_text "$PLANTNET_JSON" "$latitude" "$longitude" "$image_url")
            
            # Integrate with ORE system for biodiversity tracking
            # plantnet_ore_integration.py now calls plantnet_recognition.py --json internally
            echo "PlantNet: Recording observation in ORE biodiversity system..." >&2
            local ore_response=""
            if [[ -x "$MY_PATH/plantnet_ore_integration.py" ]]; then
                # New signature: only needs lat, lon, pubkey, event_id, image_url
                ore_response=$("$MY_PATH/plantnet_ore_integration.py" "$latitude" "$longitude" "$pubkey" "$event_id" "$image_url" 2>/dev/null)
                if [[ $? -eq 0 && -n "$ore_response" ]]; then
                    echo "PlantNet: ORE observation recorded successfully" >&2
                    # Append ORE information to PlantNet result
                    plantnet_result="${plantnet_result}${ore_response}"
                else
                    echo "PlantNet: Failed to record ORE observation (non-critical)" >&2
                    # Don't fail if ORE integration fails - still return PlantNet result
                fi
            else
                echo "PlantNet: ORE integration not available (plantnet_ore_integration.py not found)" >&2
            fi
            
            # Return the formatted PlantNet result with ORE data
            echo "$plantnet_result"
        else
            # Recognition failed (no match found)
            echo "PlantNet: No match found" >&2
            local plantnet_result=$(format_plantnet_json_to_text "$PLANTNET_JSON" "$latitude" "$longitude" "$image_url")
            echo "$plantnet_result"
        fi
    else
        echo "PlantNet: Recognition failed with exit code $exit_code" >&2
        echo "PlantNet: Checking for error details in plantnet.log..." >&2
        
        # Try to get error details from log
        local error_details=""
        if [[ -f "/home/fred/.zen/tmp/plantnet.log" ]]; then
            error_details=$(tail -5 "/home/fred/.zen/tmp/plantnet.log" | grep -E "(ERROR|Error|error)" | tail -1)
            echo "PlantNet: Last error from log: $error_details" >&2
        fi
        
        # Fallback to error message if PlantNet fails
        echo "🌿 Reconnaissance de plante

❌ Erreur de reconnaissance

La reconnaissance de la plante a échoué. 

💡 Causes possibles :
• Image de mauvaise qualité ou corrompue
• Problème de connexion à l'API PlantNet
• Clé API PlantNet invalide ou expirée
• Image trop grande ou dans un format non supporté

📍 Localisation : $latitude, $longitude

━━━━━━━━━━━━━━━━━━━━━━━━━━
🔬 Source : https://plantnet.org
"
    fi
}

# Function to update UMAP DID with PlantNet detection
# Uses PLANTNET_JSON global variable (set by handle_plantnet_recognition)
update_umap_did_with_plantnet() {
    local latitude="$1"
    local longitude="$2"
    local event_id="$3"
    local image_url="$4"
    local pubkey="$5"
    
    echo "PlantNet: Updating UMAP DID with detection data..." >&2
    
    # UMAP identifier based on coordinates (format used by UPlanet system)
    local umap_id="UMAP_${latitude}_${longitude}"
    local umap_dir="$HOME/.zen/game/nostr/${umap_id}"
    
    # Create UMAP directory if it doesn't exist
    if [[ ! -d "$umap_dir" ]]; then
        mkdir -p "$umap_dir"
        if [[ -n "$UMAPHEX" ]]; then
            echo "$UMAPHEX" > "${umap_dir}/HEX"
        fi
    fi
    
    # Check if we have UMAP keys
    if [[ -z "$UMAPNSEC" ]] || [[ -z "$UMAPNPUB" ]] || [[ -z "$UMAPHEX" ]]; then
        echo "PlantNet: Warning - UMAP keys not available for DID update" >&2
        return 1
    fi
    
    # Create .secret.nostr for UMAP if it doesn't exist
    local umap_secret_file="${umap_dir}/.secret.nostr"
    if [[ ! -f "$umap_secret_file" ]]; then
        echo "NSEC=${UMAPNSEC}; NPUB=${UMAPNPUB}; HEX=${UMAPHEX};" > "$umap_secret_file"
    fi
    
    # Use PLANTNET_JSON global variable (set by handle_plantnet_recognition)
    # No need to call plantnet_recognition.py again!
    local plantnet_json="$PLANTNET_JSON"
    
    # Update UMAP DID with plant detection using did_manager_nostr.sh
    if [[ -x "$MY_PATH/../tools/did_manager_nostr.sh" ]]; then
        # Store detection in a JSON file that will be referenced in DID metadata
        local detections_file="${umap_dir}/plantnet_detections.json"
        local detection_json=$(mktemp)
        
        if [[ -n "$plantnet_json" ]] && echo "$plantnet_json" | jq empty 2>/dev/null; then
            # Extract key information from PlantNet JSON (corrected paths)
            local scientific_name=$(echo "$plantnet_json" | jq -r '.best_match.scientific_name // ""' 2>/dev/null)
            local common_name=$(echo "$plantnet_json" | jq -r '.best_match.common_names[0] // ""' 2>/dev/null)
            local confidence=$(echo "$plantnet_json" | jq -r '.best_match.confidence // 0' 2>/dev/null)
            local confidence_pct=$(echo "$plantnet_json" | jq -r '.best_match.confidence_pct // 0' 2>/dev/null)
            local wikipedia_url=$(echo "$plantnet_json" | jq -r '.best_match.wikipedia_url // ""' 2>/dev/null)
            
            # Create detection metadata with all useful data for plantnet.html display and ORE contracts
            cat > "$detection_json" <<EOF
{
    "event_id": "${event_id}",
    "observer_pubkey": "${pubkey}",
    "image_url": "${image_url}",
    "scientific_name": "${scientific_name}",
    "common_name": "${common_name}",
    "confidence": ${confidence},
    "confidence_pct": ${confidence_pct},
    "wikipedia_url": "${wikipedia_url}",
    "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "latitude": ${latitude},
    "longitude": ${longitude}
}
EOF
        else
            # Minimal detection data if JSON parsing fails
            cat > "$detection_json" <<EOF
{
    "event_id": "${event_id}",
    "observer_pubkey": "${pubkey}",
    "image_url": "${image_url}",
    "detected_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "latitude": ${latitude},
    "longitude": ${longitude}
}
EOF
        fi
        
        # Read existing detections or create new array
        if [[ -f "$detections_file" ]] && jq empty "$detections_file" 2>/dev/null; then
            # Append new detection to existing array
            jq --argjson new "$(cat "$detection_json")" '.detections += [$new]' "$detections_file" > "${detections_file}.tmp" && mv "${detections_file}.tmp" "$detections_file"
        else
            # Create new detections file
            cat > "$detections_file" <<EOF
{
    "umap_id": "${umap_id}",
    "latitude": ${latitude},
    "longitude": ${longitude},
    "detections": [$(cat "$detection_json")]
}
EOF
        fi
        
        echo "PlantNet: Detection stored in ${detections_file}" >&2
        
        # Update UMAP DID document (kind 30800) with plant detection reference
        # Use did_manager_nostr.sh with PLANTNET_DETECTION type
        # The email parameter is actually the UMAP identifier
        echo "PlantNet: Updating UMAP DID document..." >&2
        $MY_PATH/../tools/did_manager_nostr.sh update "${umap_id}" "PLANTNET_DETECTION" 0 0 "" >/dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo "PlantNet: UMAP DID updated successfully with plant detection" >&2
        else
            echo "PlantNet: Warning - Failed to update UMAP DID, but detection stored locally" >&2
        fi
        
        # Cleanup
        rm -f "$detection_json"
        
        return 0
    else
        echo "PlantNet: Warning - did_manager_nostr.sh not available" >&2
        return 1
    fi
}

# Function to get an event by ID using strfry scan
get_event_by_id() {
    local event_id="$1"
    cd $HOME/.zen/strfry
    ./strfry scan '{"ids":["'"$event_id"'"]}' 2>/dev/null
    cd - 1>&2>/dev/null
}

# Function to get the conversation thread
get_conversation_thread() {
    local event_id="$1"
    local current_content=""
    local current_event=$(get_event_by_id "$event_id")

    if [[ -n "$current_event" ]]; then
        current_content=$(echo "$current_event" | jq -r '.content')

        # Find the event this one is replying to
        local reply_tags=$(echo "$current_event" | jq -c '.tags[] | select(.[0] == "e")')
        local root_id=""
        local reply_id=""

        # Parse tags to find root and reply references (NIP-10)
        while IFS= read -r tag; do
            local marker=$(echo "$tag" | jq -r '.[3] // ""')
            if [[ "$marker" == "root" ]]; then
                root_id=$(echo "$tag" | jq -r '.[1]')
            elif [[ "$marker" == "reply" ]]; then
                reply_id=$(echo "$tag" | jq -r '.[1]')
            fi
        done <<< "$reply_tags"

        if [[ -n "$reply_id" && "$reply_id" != "$root_id" ]]; then
            local parent_content=$(get_event_by_id "$reply_id" | jq -r '.content')
            [[ -n "$parent_content" ]] && current_content="Re: $parent_content \n---\n$current_content"
        fi
        if [[ -n "$root_id" ]]; then
            local root_content=$(get_event_by_id "$root_id" | jq -r '.content')
            [[ -n "$root_content" ]] && current_content="Thread: $root_content \n---\n$current_content"
        fi
    fi
    echo -e "$current_content"
}

## Optimisation: Load GPS data once
if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    if [[ $LAT == "0.00" && $LON == "0.00" ]]; then
        ## Check SWARM account
        isInSwarmGPS=$(ls ${HOME}/.zen/tmp/swarm/*/TW/${KNAME}/GPS 2>/dev/null)
        [[ -n  ${isInSwarmGPS} ]] && source ${isInSwarmGPS}

        ## source NOSTR Card LAT=?;LON=?;
        [[ -s ${HOME}/.zen/game/nostr/${KNAME}/GPS ]] && source ${HOME}/.zen/game/nostr/${KNAME}/GPS
    fi
    # correct empty value
    [[ -z $LAT ]] && LAT="0.00"
    [[ -z $LON ]] && LON="0.00"
fi

echo "UMAP : ${LAT} ${LON}"

# Optimisation: Calculate UMAP values once
UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
UMAPHEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNPUB")

## Do not reply to UPLanet UMAP message
[[ $PUBKEY == $UMAPHEX ]] && exit 0

## UMAP FOLLOW NOSTR CARD
if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    #######################################################################
    # UMAP FOLLOW PUBKEY -> Used nightly to create Journal "NOSTR.UMAP.refresh.sh"
    ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY" 2>/dev/null
    #######################################################################
fi

## Optimisation: Calculate paths once
SLAT="${LAT::-1}"
SLON="${LON::-1}"
RLAT=$(echo ${LAT} | cut -d '.' -f 1)
RLON=$(echo ${LON} | cut -d '.' -f 1)
UMAPPATH="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"

# Create UMAP directories and files once
if [ ! -s ${UMAPPATH}/HEX ]; then
    mkdir -p ${UMAPPATH}
    echo "$UMAPHEX" > ${UMAPPATH}/HEX
fi

if [ ! -s ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX ]; then
    mkdir -p ~/.zen/game/nostr/UMAP_${LAT}_${LON}
    echo "$UMAPHEX" > ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX
fi

################################################################### 
# Optimisation: Main processing logic simplified
if [[ "${TAGS[BRO]}" == true || "${TAGS[BOT]}" == true ]]; then
    
    # Optimisation: Handle memory operations first
    if [[ "${TAGS[reset]}" == true ]]; then
        # Memory reset logic
        reset_slot=0
        [[ $memory_slot -gt 0 ]] && reset_slot=$memory_slot
        
        if [[ "${TAGS[all]}" == true ]]; then
            # Reset all slots (0-12)
            user_dir="$HOME/.zen/tmp/flashmem/${user_id}"
            if [[ -d "$user_dir" ]]; then
                rm -f "$user_dir"/slot*.json
                echo "All memory slots reset for USER: $user_id"
                KeyANSWER="Toutes les mémoires (slots 0-12) ont été réinitialisées. Utilisez #reset #N pour réinitialiser un slot spécifique, ou #reset pour réinitialiser le slot 0."
            else
                echo "No memory directory found for USER: $user_id"
                KeyANSWER="Aucune mémoire trouvée."
            fi
        elif [[ $reset_slot -gt 0 ]]; then
            # Check memory slot access for reset
            if check_memory_slot_access "$user_id" "$reset_slot"; then
                slot_file="$HOME/.zen/tmp/flashmem/${user_id}/slot${reset_slot}.json"
                if [[ -f "$slot_file" ]]; then
                    rm -f "$slot_file"
                    echo "Memory reset for USER: $user_id, SLOT: $reset_slot"
                    KeyANSWER="Mémoire slot $reset_slot réinitialisée."
                else
                    echo "No memory file found for USER: $user_id, SLOT: $reset_slot"
                    KeyANSWER="Pas de mémoire trouvée pour le slot $reset_slot."
                fi
            else
                echo "Memory access denied for reset - USER: $user_id, SLOT: $reset_slot"
                send_memory_access_denied "$PUBKEY" "$EVENT" "$reset_slot"
                KeyANSWER="Accès refusé au slot $reset_slot. Seuls les sociétaires CopyLaRadio peuvent utiliser les slots 1-12."
            fi
        else
            # Reset only slot 0 (default behavior)
            slot_file="$HOME/.zen/tmp/flashmem/${user_id}/slot0.json"
            if [[ -f "$slot_file" ]]; then
                rm -f "$slot_file"
                echo "Memory reset for USER: $user_id, SLOT: 0"
                KeyANSWER="Mémoire slot 0 réinitialisée."
            else
                echo "No memory file found for USER: $user_id, SLOT: 0"
                KeyANSWER="Pas de mémoire trouvée pour le slot 0."
            fi
        fi
    elif [[ "${TAGS[mem]}" == true ]]; then
        # Memory display logic
        mem_slot=0
        [[ $memory_slot -gt 0 ]] && mem_slot=$memory_slot
        
        if [[ $mem_slot -gt 0 ]]; then
            # Check memory slot access for display
            if check_memory_slot_access "$user_id" "$mem_slot"; then
                slot_file="$HOME/.zen/tmp/flashmem/${user_id}/slot${mem_slot}.json"
                if [[ -f "$slot_file" ]]; then
                    echo "Returning memory content for USER: $user_id, SLOT: $mem_slot"
                    temp_mem_file="$HOME/.zen/tmp/memory_${user_id}_slot${mem_slot}.txt"
                    echo "📝 Historique (#mem slot $mem_slot)" > "$temp_mem_file"
                    echo "========================" >> "$temp_mem_file"
                    jq -r '.messages | to_entries | .[-30:] | .[] | "📅 \(.value.timestamp | sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%d/%m/%Y %H:%M"))\n💬 \(.value.content | sub("#BOT "; "") | sub("#BRO "; "") | sub("#bot "; "") | sub("#bro "; ""))\n---"' "$slot_file" >> "$temp_mem_file"
                    KeyANSWER=$(cat "$temp_mem_file")
                    rm -f "$temp_mem_file"
                else
                    echo "No memory file found for USER: $user_id, SLOT: $mem_slot"
                    KeyANSWER="Aucune mémoire trouvée pour le slot $mem_slot."
                fi
            else
                echo "Memory access denied for display - USER: $user_id, SLOT: $mem_slot"
                send_memory_access_denied "$PUBKEY" "$EVENT" "$mem_slot"
                KeyANSWER="Accès refusé au slot $mem_slot. Seuls les sociétaires CopyLaRadio peuvent utiliser les slots 1-12."
            fi
        else
            # Show default slot (0) memory
            slot_file="$HOME/.zen/tmp/flashmem/${user_id}/slot0.json"
            if [[ -f "$slot_file" ]]; then
                echo "Returning memory content for USER: $user_id, SLOT: 0"
                temp_mem_file="$HOME/.zen/tmp/memory_${user_id}_slot0.txt"
                echo "📝 Historique (#mem slot 0)" > "$temp_mem_file"
            echo "========================" >> "$temp_mem_file"
                jq -r '.messages | to_entries | .[-30:] | .[] | "📅 \(.value.timestamp | sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%d/%m/%Y %H:%M"))\n💬 \(.value.content | sub("#BOT "; "") | sub("#BRO "; "") | sub("#bot "; "") | sub("#bro "; ""))\n---"' "$slot_file" >> "$temp_mem_file"
            KeyANSWER=$(cat "$temp_mem_file")
            rm -f "$temp_mem_file"
        else
                echo "No memory file found for USER: $user_id, SLOT: 0"
                KeyANSWER="Aucune mémoire trouvée."
            fi
        fi
    fi

    #######################################################################
    # Optimisation: Process image description once if needed
    if [[ ! -z $URL && -z "$KeyANSWER" ]]; then
        echo "Looking at the image (using ollama + llava / minicpm-v )..."
        DESC="IMAGE : $("$MY_PATH/describe_image.py" "$URL" --json | jq -r '.description')"
    fi

    # Optimisation: Prepare question once
    if [[ -z "$KeyANSWER" ]]; then
    if [[ -n $DESC ]]; then
        QUESTION="[IMAGE received]: $DESC --- $message_text"
    else
        QUESTION="$message_text ---"
    fi
    fi

    AnswerKind="1"
    ExtraTags=""
    ##################################################### ASK IA
    ## KNOWN KNAME & CAPTAIN REPLY
    if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ || $KNAME == "CAPTAIN" ]]; then
        # Only generate an answer if KeyANSWER is not already set
        if [[ -z "$KeyANSWER" ]]; then
            # Optimisation: Process specialized commands
            ######################################################### #search
            if [[ "${TAGS[search]}" == true ]]; then
                $MY_PATH/perplexica.me.sh
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#search//g; s/"//g' <<< "$message_text")
                USER_LANG=$(get_user_language "$KNAME")
                echo "User language for search: $USER_LANG" >&2
                # Capture stderr separately for debugging
                SEARCH_STDERR=$(mktemp)
                KeyANSWER="$($MY_PATH/perplexica_search.sh "${cleaned_text}" "${USER_LANG}" 2>"$SEARCH_STDERR")"
                SEARCH_EXIT_CODE=$?
                SEARCH_DEBUG=$(cat "$SEARCH_STDERR" 2>/dev/null)
                rm -f "$SEARCH_STDERR"
                
                # Check if Perplexica search failed
                # Only check for actual errors (exit code non-zero, empty response, or error in first line)
                if [[ $SEARCH_EXIT_CODE -ne 0 ]] || [[ -z "$KeyANSWER" ]]; then
                    echo "ERROR: Perplexica search failed (exit: $SEARCH_EXIT_CODE)" >&2
                    echo "Search debug: $SEARCH_DEBUG" >&2
                    # Set a user-friendly error message
                    ERROR_DETAIL="${SEARCH_DEBUG:-Aucune réponse du serveur Perplexica}"
                    # Extract only the last error line for user display
                    ERROR_LINE=$(echo "$ERROR_DETAIL" | grep -i "error" | tail -1)
                    [[ -z "$ERROR_LINE" ]] && ERROR_LINE="$ERROR_DETAIL"
                    KeyANSWER="❌ La recherche Perplexica a échoué.

🔍 Requête: ${cleaned_text}

⚠️ Erreur technique lors de la recherche. Veuillez réessayer plus tard ou contacter le support.

Détails: ${ERROR_LINE}"
                    # Skip the rest of the search processing
                    AnswerKind="1"  # Simple note instead of blog article
                else
                
                # Generate intelligent summary using the detected language
                echo "Generating intelligent summary for article..." >&2
                ARTICLE_SUMMARY="$($MY_PATH/question.py --json "Write 2-3 sentences summarizing this article. Language: ${USER_LANG}. START DIRECTLY with the summary, no introduction. Article: ${KeyANSWER}" --pubkey ${PUBKEY})"
                
                # Extract content from JSON response and clean it (less aggressive with JSON)
                ARTICLE_SUMMARY="$(echo "$ARTICLE_SUMMARY" | jq -r '.answer // .' 2>/dev/null || echo "$ARTICLE_SUMMARY")"
                ARTICLE_SUMMARY="$(echo "$ARTICLE_SUMMARY" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '\n' | sed 's/\s\+/ /g' | sed 's/"/\\"/g' | sed "s/'/\\'/g" | head -c 500)"
                
                # Generate intelligent tags based on article content
                echo "Generating intelligent tags for article..." >&2
                INTELLIGENT_TAGS="$($MY_PATH/question.py --json "Output 5-8 hashtags for this article. Format: tag1 tag2 tag3 (space-separated, no # symbol, no explanation). Article: ${KeyANSWER}" --pubkey ${PUBKEY})"
                
                # Extract and clean the tags
                INTELLIGENT_TAGS="$(echo "$INTELLIGENT_TAGS" | jq -r '.answer // .' 2>/dev/null || echo "$INTELLIGENT_TAGS")"
                INTELLIGENT_TAGS="$(echo "$INTELLIGENT_TAGS" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//' | sed 's/#//g' | sed 's/,//g' | sed 's/\s\+/ /g' | head -c 200)"
                
                echo "Generated intelligent tags: $INTELLIGENT_TAGS" >&2
                
                # Generate illustration image for the article
                echo "Generating illustration image for search result..." >&2
                $MY_PATH/comfyui.me.sh
                
                # Use AI to create an optimized Stable Diffusion prompt based on the summary
                echo "Creating AI-generated prompt for illustration based on article summary..." >&2
                SD_PROMPT="$($MY_PATH/question.py --json "Stable Diffusion prompt for: ${ARTICLE_SUMMARY} --- OUTPUT ONLY: visual descriptors in English. NO text/words/emojis/brands. Focus: composition, colors, style, objects." --pubkey ${PUBKEY})"
                
                # Extract content from JSON response and clean the prompt
                SD_PROMPT="$(echo "$SD_PROMPT" | jq -r '.answer // .' 2>/dev/null || echo "$SD_PROMPT")"
                SD_PROMPT=$(echo "$SD_PROMPT" | \
                    sed 's/^[[:space:]]*//' | \
                    sed 's/[[:space:]]*$//' | \
                    sed 's/\s\+/ /g' | \
                    sed 's/🥺🎨✨//g' | \
                    sed 's/emoji//g' | \
                    sed 's/emojis//g' | \
                    head -c 400)
                
                # Get user uDRIVE path for image storage
                USER_UDRIVE_PATH=$(get_user_udrive_from_kname)
                if [ $? -eq 0 ]; then
                    echo "Using user uDRIVE/Images for illustration output: $USER_UDRIVE_PATH/Images" >&2
                    ILLUSTRATION_URL="$($MY_PATH/generate_image.sh "${SD_PROMPT}" "$USER_UDRIVE_PATH/Images")"
                else
                    echo "Using default location for search illustration" >&2
                    ILLUSTRATION_URL="$($MY_PATH/generate_image.sh "${SD_PROMPT}")"
                fi
                
                # Add illustration to the article if generated successfully
                if [[ -n "$ILLUSTRATION_URL" ]]; then
                    echo "Adding illustration to article: $ILLUSTRATION_URL" >&2
                    # Don't add image URL to content, it will be added as a tag
                else
                    echo "Warning: Could not generate illustration for search result" >&2
                fi
                
                AnswerKind="30023"
                # Create JSON tags using jq for proper escaping
                echo "Creating JSON tags for kind 30023..." >&2
                
                # Create a temporary JSON file for jq processing
                temp_json="$HOME/.zen/tmp/tags_${RANDOM}.json"
                
                # Convert intelligent tags to JSON array format
                if [[ -n "$INTELLIGENT_TAGS" ]]; then
                    # Split tags by space and create JSON array
                    TAG_ARRAY=""
                    IFS=' ' read -ra TAG_LIST <<< "$INTELLIGENT_TAGS"
                    for tag in "${TAG_LIST[@]}"; do
                        if [[ -n "$tag" ]]; then
                            TAG_ARRAY="${TAG_ARRAY}[\"t\", \"$tag\"],"
                        fi
                    done
                    # Remove trailing comma
                    TAG_ARRAY="${TAG_ARRAY%,}"
                else
                    TAG_ARRAY=""
                fi
                
                # Add standard tags
                STANDARD_TAGS='["t", "search"], ["t", "perplexica"]'
                if [[ -n "$TAG_ARRAY" ]]; then
                    ALL_TAGS="${STANDARD_TAGS}, ${TAG_ARRAY}"
                else
                    ALL_TAGS="${STANDARD_TAGS}"
                fi
                
                if [[ -n "$ILLUSTRATION_URL" ]]; then
                    jq -n --arg title "$cleaned_text" --arg summary "$ARTICLE_SUMMARY" --arg image "$ILLUSTRATION_URL" --arg published_at "$(date -u +%s)" --arg d_tag "search_$(date -u +%s)_$(echo -n "$cleaned_text" | md5sum | cut -d' ' -f1 | head -c 8)" \
                        --argjson tags "[${ALL_TAGS}]" \
                        '[["d", $d_tag], ["title", $title], ["summary", $summary], ["published_at", $published_at], ["image", $image]] + $tags' > "$temp_json"
                else
                    jq -n --arg title "$cleaned_text" --arg summary "$ARTICLE_SUMMARY" --arg published_at "$(date -u +%s)" --arg d_tag "search_$(date -u +%s)_$(echo -n "$cleaned_text" | md5sum | cut -d' ' -f1 | head -c 8)" \
                        --argjson tags "[${ALL_TAGS}]" \
                        '[["d", $d_tag], ["title", $title], ["summary", $summary], ["published_at", $published_at]] + $tags' > "$temp_json"
                fi
                
                # Read the properly formatted JSON tags
                ExtraTags=$(cat "$temp_json")
                echo "Generated ExtraTags: $ExtraTags" >&2
                rm -f "$temp_json"
                fi  # End of successful Perplexica search processing
            ######################################################### #image
            elif [[ "${TAGS[image]}" == true ]]; then
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#image//g; s/"//g' <<< "$message_text")
                $MY_PATH/comfyui.me.sh
                start_time=$(date +%s.%N)
                
                # Get user uDRIVE path and generate image
                USER_UDRIVE_PATH=$(get_user_udrive_from_kname)
                if [ $? -eq 0 ]; then
                    IMAGE_URL="$($MY_PATH/generate_image.sh "${cleaned_text}" "$USER_UDRIVE_PATH/Images")"
                else
                    echo "Warning: Using default location for image generation" >&2
                    IMAGE_URL="$($MY_PATH/generate_image.sh "${cleaned_text}")"
                fi
                
                end_time=$(date +%s.%N)
                execution_time=$(echo "$end_time - $start_time" | bc)
                if [ -n "$IMAGE_URL" ]; then
                    KeyANSWER=$(echo -e "🖼️ $CURRENT_TIME_STR (⏱️ ${execution_time%.*} s)\n📝 Description: $cleaned_text\n🔗 $IMAGE_URL")
                    # Add tags for image generation
                    ExtraTags="[['t', 'image'], ['t', 'comfyui'], ['t', 'ai-generated']]"
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer l'image demandée."
                fi
            elif [[ "${TAGS[video]}" == true ]]; then
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#video//g; s/#i2v//g; s/"//g' <<< "$message_text")
                $MY_PATH/comfyui.me.sh
                
                # Get user uDRIVE path
                USER_UDRIVE_PATH=$(get_user_udrive_from_kname)
                
                # Check if an image is attached - if yes, use Image-to-Video (i2v)
                # Otherwise use Text-to-Video
                if [[ -n "$URL" ]]; then
                    echo "Image detected: Using Image-to-Video (Wan2.2 14B i2v) workflow" >&2
                    echo "Source image: $URL" >&2
                    echo "Prompt: $cleaned_text" >&2
                    
                    if [ $? -eq 0 ] && [ -n "$USER_UDRIVE_PATH" ]; then
                        VIDEO_AI_RETURN="$($MY_PATH/image_to_video.sh "${cleaned_text}" "$URL" "$USER_UDRIVE_PATH")"
                    else
                        echo "Warning: Using default location for i2v video generation" >&2
                        VIDEO_AI_RETURN="$($MY_PATH/image_to_video.sh "${cleaned_text}" "$URL")"
                    fi
                    
                    if [ -n "$VIDEO_AI_RETURN" ]; then
                        KeyANSWER="$VIDEO_AI_RETURN"
                        # Add tags for i2v video generation
                        ExtraTags="[['t', 'video'], ['t', 'i2v'], ['t', 'comfyui'], ['t', 'ai-generated'], ['imeta', 'url $URL']]"
                    else
                        KeyANSWER="Désolé, je n'ai pas pu générer la vidéo à partir de l'image fournie."
                    fi
                else
                    echo "No image attached: Using Text-to-Video workflow" >&2
                    
                    if [ $? -eq 0 ] && [ -n "$USER_UDRIVE_PATH" ]; then
                        VIDEO_AI_RETURN="$($MY_PATH/generate_video.sh "${cleaned_text}" "$MY_PATH/workflow/video_wan2_2_5B_ti2v.json" "$USER_UDRIVE_PATH")"
                    else
                        echo "Warning: Using default location for video generation" >&2
                        VIDEO_AI_RETURN="$($MY_PATH/generate_video.sh "${cleaned_text}" "$MY_PATH/workflow/video_wan2_2_5B_ti2v.json")"
                    fi
                    
                    if [ -n "$VIDEO_AI_RETURN" ]; then
                        KeyANSWER="$VIDEO_AI_RETURN"
                        # Add tags for text2video generation
                        ExtraTags="[['t', 'video'], ['t', 't2v'], ['t', 'comfyui'], ['t', 'ai-generated']]"
                    else
                        KeyANSWER="Désolé, je n'ai pas pu générer la vidéo demandée."
                    fi
                fi
            ######################################################### #music
            elif [[ "${TAGS[music]}" == true ]]; then
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#music//g; s/"//g' <<< "$message_text")
                $MY_PATH/comfyui.me.sh
                
                # Get user uDRIVE path and generate music
                USER_UDRIVE_PATH=$(get_user_udrive_from_kname)
                if [ $? -eq 0 ]; then
                    MUSIC_URL="$($MY_PATH/generate_music.sh "${cleaned_text}" "$USER_UDRIVE_PATH")"
                else
                    echo "Warning: Using default location for music generation" >&2
                    MUSIC_URL="$($MY_PATH/generate_music.sh "${cleaned_text}")"
                fi
                
                if [ -n "$MUSIC_URL" ]; then
                    KeyANSWER="$MUSIC_URL"
                    # Add tags for music generation
                    ExtraTags="[['t', 'music'], ['t', 'comfyui'], ['t', 'ai-generated']]"
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer la musique demandée."
                fi
            ######################################################### #youtube
            elif [[ "${TAGS[youtube]}" == true ]]; then
                # Extract any video URL that yt-dlp can handle (YouTube, Rumble, Vimeo, etc.)
                video_url=$(echo "$message_text" | awk 'match($0, /https?:\/\/[^ ]+/) { print substr($0, RSTART, RLENGTH) }' | head -n1)
                if [ -z "$video_url" ]; then
                    KeyANSWER="Désolé, Aucune URL vidéo valide trouvée dans votre message."
                else
                    echo "Processing YouTube video: $video_url" >&2
                    
                    # Get user email for video downloads
                    if [[ "$KNAME" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                        echo "Using player email for video download: $KNAME" >&2
                        # Pass player email to process_youtube.sh (supports all yt-dlp platforms)
                        if [[ "$message_text" =~ \#mp3 ]]; then
                            $MY_PATH/process_youtube.sh --debug "$video_url" "mp3" "$KNAME" >/dev/null 2>&1
                        else
                            $MY_PATH/process_youtube.sh --debug "$video_url" "mp4" "$KNAME" >/dev/null 2>&1
                        fi
                    else
                        echo "Warning: Using default location for video download" >&2
                        # Enable debug mode for video processing (supports all yt-dlp platforms)
                        if [[ "$message_text" =~ \#mp3 ]]; then
                            $MY_PATH/process_youtube.sh --debug "$video_url" "mp3" >/dev/null 2>&1
                        else
                            $MY_PATH/process_youtube.sh --debug "$video_url" "mp4" >/dev/null 2>&1
                        fi
                    fi
                    
                    echo "Video processing completed. NOSTR notification sent by process_youtube.sh" >&2
                fi
            ######################################################### #plantnet
            elif [[ "${TAGS[plantnet]}" == true ]]; then
                # PlantNet recognition processing
                echo "Processing PlantNet recognition request (tags: #BRO #plantnet)..." >&2
                
                # Initialize success flag
                PLANTNET_SUCCESS=false
                
                # Extract image URL - use cleaned URL from earlier extraction
                image_url=""
                
                # Method 1: Use cleaned URL variable (already extracted and cleaned earlier)
                if [[ -n "$URL" ]]; then
                    image_url="$URL"
                    echo "PlantNet: Using cleaned URL from parameter: $image_url" >&2
                else
                    # Method 2: Try to get URL from original event's imeta tags (most reliable)
                    if [[ -n "$EVENT" ]]; then
                        original_event=$(cd $HOME/.zen/strfry && ./strfry scan '{"ids":["'"$EVENT"'"]}' 2>/dev/null && cd - >/dev/null)
                        if [[ -n "$original_event" ]]; then
                            # Extract imeta tag with url - format: ["imeta", "url https://..."]
                            local imeta_url=$(echo "$original_event" | jq -r '.tags[] | select(.[0] == "imeta") | .[1] // empty' 2>/dev/null | grep -oP 'url\s+\K[^\s]+' | head -n1)
                            if [[ -n "$imeta_url" ]]; then
                                image_url="$imeta_url"
                                echo "PlantNet: Found image URL from event imeta tag: $image_url" >&2
                            else
                                # Try alternative imeta format: ["imeta", "url", "https://..."]
                                local imeta_url=$(echo "$original_event" | jq -r '.tags[] | select(.[0] == "imeta" and .[1] == "url") | .[2] // empty' 2>/dev/null | head -n1)
                                if [[ -n "$imeta_url" ]]; then
                                    image_url="$imeta_url"
                                    echo "PlantNet: Found image URL from event imeta tag (alt format): $image_url" >&2
                                fi
                            fi
                        fi
                    fi
                    
                    # Method 3: Extract from message text as last resort (with better pattern)
                    if [[ -z "$image_url" ]]; then
                        # Extract IPFS URLs more precisely - stop at end of filename
                        image_url=$(echo "$message_text" | grep -oE 'https?://[^[:space:]#]+/ipfs/[A-Za-z0-9]+/[^[:space:]#]+\.(jpg|jpeg|png|gif|webp|JPG|JPEG|PNG|GIF|WEBP)' | head -n1)
                        
                        if [[ -z "$image_url" ]]; then
                            # Fallback: extract any URL ending with image extension
                            image_url=$(echo "$message_text" | awk 'match($0, /https?:\/\/[^[:space:]#]+\.(jpg|jpeg|png|gif|webp|JPG|JPEG|PNG|GIF|WEBP)/) { 
                                url = substr($0, RSTART, RLENGTH)
                                # Remove any trailing characters after extension
                                sub(/[^a-zA-Z0-9_.-]+.*$/, "", url)
                                print url
                            }' | head -n1)
                        fi
                        
                        if [[ -n "$image_url" ]]; then
                            echo "PlantNet: Found image URL from message text: $image_url" >&2
                        fi
                    fi
                fi
                
                # Final cleanup: ensure URL doesn't have description text appended
                if [[ -n "$image_url" ]]; then
                    # Remove everything after the image file extension
                    image_url=$(echo "$image_url" | sed -E 's/(https?:\/\/[^[:space:]#]+\.(jpg|jpeg|png|gif|webp|JPG|JPEG|PNG|GIF|WEBP))[^[:space:]#]*.*/\1/')
                    echo "PlantNet: Final cleaned image URL: $image_url" >&2
                fi
                
                if [[ -n "$image_url" ]]; then
                    # Use precise coordinates from original message (passed by 1.sh)
                    # Fallback to LAT/LON if ORIGINAL_GEO_* not provided (backward compatibility)
                    ORIGINAL_LAT="$ORIGINAL_GEO_LAT"
                    ORIGINAL_LON="$ORIGINAL_GEO_LON"
                    if [[ -z "$ORIGINAL_LAT" || -z "$ORIGINAL_LON" ]]; then
                        # Fallback: use provided LAT/LON (may already be processed/rounded by 1.sh)
                        ORIGINAL_LAT="$LAT"
                        ORIGINAL_LON="$LON"
                        echo "PlantNet: Using provided coordinates as precise coordinates: ${ORIGINAL_LAT}, ${ORIGINAL_LON}" >&2
                    else
                        echo "PlantNet: Using precise coordinates from original message: ${ORIGINAL_LAT}, ${ORIGINAL_LON}" >&2
                    fi
                    
                    # Calculate UMAP coordinates (rounded to 0.01 precision)
                    UMAP_LAT=$(echo "$ORIGINAL_LAT" | awk '{printf "%.2f", $1}')
                    UMAP_LON=$(echo "$ORIGINAL_LON" | awk '{printf "%.2f", $1}')
                    echo "PlantNet: UMAP coordinates (0.01 precision): ${UMAP_LAT}, ${UMAP_LON}" >&2
                    
                    # Call PlantNet recognition with image description
                    KeyANSWER=$(handle_plantnet_recognition "$image_url" "$ORIGINAL_LAT" "$ORIGINAL_LON" "$user_id" "$EVENT" "$PUBKEY")
                    
                    # Check if recognition was successful
                    if [[ "${PLANTNET_SUCCESS:-false}" == true ]]; then
                        echo "PlantNet: Recognition successful - adding tags and updating UMAP DID" >&2
                        
                        # Generate nprofile of the message sender (PUBKEY) to mention them in the response
                        echo "PlantNet: Generating sender nprofile for mention..." >&2
                        SENDER_NPROFILE=""
                        if [[ -n "$PUBKEY" ]]; then
                            # Generate nprofile using nostr_hex2nprofile.sh with relay hints
                            SENDER_NPROFILE=$($MY_PATH/../tools/nostr_hex2nprofile.sh "$PUBKEY" "$myRELAY" 2>/dev/null)
                            if [[ -n "$SENDER_NPROFILE" ]]; then
                                echo "PlantNet: Sender nprofile generated: ${SENDER_NPROFILE:0:30}..." >&2
                                # Add nostr:profil reference to mention the sender in the response content
                                KeyANSWER="${KeyANSWER}

📍 Observer: nostr:${SENDER_NPROFILE}"
                            else
                                echo "PlantNet: Warning - Failed to generate sender nprofile" >&2
                            fi
                        else
                            echo "PlantNet: Warning - PUBKEY not available for nprofile generation" >&2
                        fi
                        
                        # Add tags for image URL and geolocation (NIP-94 image tag + NIP-52 geolocation)
                        # Preserve precise coordinates from original message in 'g' tag
                        # Add UMAP coordinates (rounded to 0.01) in 'umap' tag for UMAP identification
                        # Add tags #plantnet #UPlanet as Nostr tags ONLY (not in content text)
                        # These tags identify responses with recognized plants (different from requests which have #BRO #plantnet)
                        # This allows plantnet.html to retrieve and display recognized plants on the map
                        echo "PlantNet: Adding Nostr tags: #plantnet #UPlanet (for recognized plants)" >&2
                        echo "PlantNet: Adding precise coordinates (g tag): ${ORIGINAL_LAT}, ${ORIGINAL_LON}" >&2
                        echo "PlantNet: Adding UMAP coordinates (umap tag): ${UMAP_LAT}, ${UMAP_LON}" >&2
                        ExtraTags="[['imeta', 'url $image_url'], ['g', '${ORIGINAL_LAT},${ORIGINAL_LON}'], ['umap', '${UMAP_LAT},${UMAP_LON}'], ['t', 'plantnet'], ['t', 'UPlanet']]"
                        
                        # Note: Tags #plantnet and #UPlanet are in ExtraTags (Nostr tags), NOT in KeyANSWER content
                        # User requests use #BRO #plantnet tags, bot responses use #plantnet #UPlanet tags
                        # Tag 'g' contains precise coordinates from original message
                        # Tag 'umap' contains UMAP coordinates rounded to 0.01 precision for UMAP identification
                        
                        # Update UMAP DID with plant detection (use UMAP coordinates for DID)
                        update_umap_did_with_plantnet "$UMAP_LAT" "$UMAP_LON" "$EVENT" "$image_url" "$PUBKEY"
                        
                        # Set flag to use UMAP key for PlantNet responses
                        USE_UMAP_FOR_PLANTNET=true
                    else
                        echo "PlantNet: Recognition failed - not adding tags" >&2
                        # Don't add #plantnet #UPlanet tags if recognition failed
                        # Still preserve precise coordinates and add UMAP coordinates
                        ExtraTags="[['imeta', 'url $image_url'], ['g', '${ORIGINAL_LAT},${ORIGINAL_LON}'], ['umap', '${UMAP_LAT},${UMAP_LON}']]"
                    fi
                else
                    echo "PlantNet: No valid image URL found in message" >&2
                    KeyANSWER="❌ Aucune image valide trouvée pour la reconnaissance PlantNet.

Veuillez inclure une URL d'image valide dans votre message ou utiliser le tag #plantnet avec une photo.

**Formats supportés :** JPG, JPEG, PNG, GIF, WEBP
**Note :** Seuls les fichiers image sont analysés. Les autres types de fichiers sont ignorés.
"
                fi
            ######################################################### #inventory (multi-type recognition)
            elif [[ "${TAGS[inventory]}" == true || "${TAGS[plant]}" == true || "${TAGS[insect]}" == true || "${TAGS[animal]}" == true || "${TAGS[person]}" == true || "${TAGS[object]}" == true || "${TAGS[place]}" == true ]]; then
                # UPlanet Inventory recognition - multi-type classification
                echo "Processing UPlanet Inventory recognition request..." >&2
                
                # Determine forced type if specific tag is used
                FORCE_TYPE=""
                if [[ "${TAGS[plant]}" == true ]]; then FORCE_TYPE="plant"; fi
                if [[ "${TAGS[insect]}" == true ]]; then FORCE_TYPE="insect"; fi
                if [[ "${TAGS[animal]}" == true ]]; then FORCE_TYPE="animal"; fi
                if [[ "${TAGS[person]}" == true ]]; then FORCE_TYPE="person"; fi
                if [[ "${TAGS[object]}" == true ]]; then FORCE_TYPE="object"; fi
                if [[ "${TAGS[place]}" == true ]]; then FORCE_TYPE="place"; fi
                
                echo "Inventory: Force type = $FORCE_TYPE" >&2
                
                # Extract image URL (same logic as plantnet)
                image_url=""
                if [[ -n "$URL" ]]; then
                    image_url="$URL"
                    echo "Inventory: Using URL from parameter: $image_url" >&2
                else
                    # Extract from message text
                    image_url=$(echo "$message_text" | grep -oE 'https?://[^[:space:]#]+\.(jpg|jpeg|png|gif|webp|JPG|JPEG|PNG|GIF|WEBP)' | head -n1)
                    if [[ -n "$image_url" ]]; then
                        echo "Inventory: Found image URL from message: $image_url" >&2
                    fi
                fi
                
                if [[ -n "$image_url" ]]; then
                    # Get coordinates
                    ORIGINAL_LAT="${ORIGINAL_GEO_LAT:-$LAT}"
                    ORIGINAL_LON="${ORIGINAL_GEO_LON:-$LON}"
                    UMAP_LAT=$(echo "$ORIGINAL_LAT" | awk '{printf "%.2f", $1}')
                    UMAP_LON=$(echo "$ORIGINAL_LON" | awk '{printf "%.2f", $1}')
                    
                    echo "Inventory: Coordinates ${ORIGINAL_LAT}, ${ORIGINAL_LON} (UMAP: ${UMAP_LAT}, ${UMAP_LON})" >&2
                    
                    # Build inventory recognition command
                    INVENTORY_CMD="$MY_PATH/inventory_recognition.py \"$image_url\" $ORIGINAL_LAT $ORIGINAL_LON --json --contract"
                    if [[ -n "$FORCE_TYPE" ]]; then
                        INVENTORY_CMD="$INVENTORY_CMD --type $FORCE_TYPE"
                    fi
                    if [[ -n "$PUBKEY" ]]; then
                        INVENTORY_CMD="$INVENTORY_CMD --pubkey $PUBKEY"
                    fi
                    if [[ -n "$EVENT" ]]; then
                        INVENTORY_CMD="$INVENTORY_CMD --event-id $EVENT"
                    fi
                    
                    echo "Inventory: Running recognition..." >&2
                    INVENTORY_JSON=$(eval $INVENTORY_CMD 2>/dev/null)
                    INVENTORY_EXIT=$?
                    
                    if [[ $INVENTORY_EXIT -eq 0 && -n "$INVENTORY_JSON" ]]; then
                        # Parse JSON response
                        INVENTORY_SUCCESS=$(echo "$INVENTORY_JSON" | jq -r '.success // false' 2>/dev/null)
                        ITEM_TYPE=$(echo "$INVENTORY_JSON" | jq -r '.type // "object"' 2>/dev/null)
                        ITEM_NAME=$(echo "$INVENTORY_JSON" | jq -r '.identification.name // "Non identifié"' 2>/dev/null)
                        ITEM_DESCRIPTION=$(echo "$INVENTORY_JSON" | jq -r '.identification.description // ""' 2>/dev/null)
                        TYPE_ICON=$(echo "$INVENTORY_JSON" | jq -r '.type_info.icon // "🔍"' 2>/dev/null)
                        TYPE_NAME=$(echo "$INVENTORY_JSON" | jq -r '.type_info.name_fr // "Élément"' 2>/dev/null)
                        CONFIDENCE=$(echo "$INVENTORY_JSON" | jq -r '.classification.confidence // 0' 2>/dev/null)
                        CONFIDENCE_PCT=$(echo "$CONFIDENCE" | awk '{printf "%.0f", $1 * 100}')
                        
                        # Extract contract
                        CONTRACT_CONTENT=$(echo "$INVENTORY_JSON" | jq -r '.contract.content // ""' 2>/dev/null)
                        CONTRACT_TITLE=$(echo "$INVENTORY_JSON" | jq -r '.contract.title // ""' 2>/dev/null)
                        
                        if [[ "$INVENTORY_SUCCESS" == "true" ]]; then
                            echo "Inventory: Recognition successful - Type: $ITEM_TYPE, Name: $ITEM_NAME" >&2
                            
                            # Build markdown response content for blog (kind 30023)
                            BLOG_CONTENT=$(echo "$INVENTORY_JSON" | jq -r '.content // ""' 2>/dev/null)
                            
                            # Build plain text response for kind 1 (NO MARKDOWN)
                            # Strip markdown formatting for kind 1 message
                            KeyANSWER="${TYPE_ICON} ${ITEM_NAME}
📍 ${ORIGINAL_LAT}, ${ORIGINAL_LON}
📊 Confiance: ${CONFIDENCE_PCT}%
📸 ${image_url}

👍 Likez pour créditer des Ẑen aux gestionnaires!

#UPlanet #inventory #${ITEM_TYPE} #ORE"
                            
                            # Add tags for inventory (includes imeta for image)
                            ExtraTags="[['imeta', 'url $image_url', 'm image/jpeg'], ['g', '${ORIGINAL_LAT},${ORIGINAL_LON}'], ['umap', '${UMAP_LAT},${UMAP_LON}'], ['t', 'inventory'], ['t', 'UPlanet'], ['t', '$ITEM_TYPE'], ['inventory_type', '$ITEM_TYPE'], ['inventory_name', '$ITEM_NAME']]"
                            
                            # Use UMAP key for inventory responses (like plantnet)
                            USE_UMAP_FOR_PLANTNET=true
                            
                            # Publish contract as ORE-compatible event (kind 30312 - ORE Meeting Space)
                            # Also publish as kind 30023 for blog readers compatibility
                            if [[ -n "$CONTRACT_CONTENT" && -s ~/.zen/game/nostr/${KNAME}/.secret.nostr ]]; then
                                echo "Inventory: Publishing ORE-compatible maintenance contract..." >&2
                                
                                # Generate ORE-compatible d_tag (per ORE_SYSTEM.md)
                                ORE_D_TAG="ore-inventory-${UMAP_LAT}-${UMAP_LON}"
                                TIMESTAMP_NOW=$(date -u +%s)
                                
                                # Build ORE-compatible contract tags (kind 30312 format - NIP-53 compliant)
                                VDO_SERVICE="https://vdo.copylaradio.com/?room=UMAP_ORE_${UMAP_LAT}_${UMAP_LON}"
                                ORE_CONTRACT_TAGS=$(jq -n \
                                    --arg d "$ORE_D_TAG" \
                                    --arg title "$CONTRACT_TITLE" \
                                    --arg summary "Contrat de gestion: $ITEM_NAME ($TYPE_NAME)" \
                                    --arg start "$TIMESTAMP_NOW" \
                                    --arg image "$image_url" \
                                    --arg lat "$ORIGINAL_LAT" \
                                    --arg lon "$ORIGINAL_LON" \
                                    --arg umap "${UMAP_LAT},${UMAP_LON}" \
                                    --arg room "UMAP_ORE_${UMAP_LAT}_${UMAP_LON}" \
                                    --arg service "$VDO_SERVICE" \
                                    --arg item_type "$ITEM_TYPE" \
                                    --arg item_name "$ITEM_NAME" \
                                    '[
                                        ["d", $d],
                                        ["title", $title],
                                        ["summary", $summary],
                                        ["start", $start],
                                        ["status", "open"],
                                        ["image", $image],
                                        ["g", ($lat + "," + $lon)],
                                        ["umap", $umap],
                                        ["room", $room],
                                        ["service", $service],
                                        ["t", "ORE"],
                                        ["t", "contract"],
                                        ["t", "maintenance"],
                                        ["t", "communs"],
                                        ["t", "UPlanet"],
                                        ["t", $item_type],
                                        ["inventory_type", $item_type],
                                        ["inventory_name", $item_name]
                                    ]')
                                
                                # Publish ORE contract with MULTIPASS key (kind 30312)
                                MULTIPASS_KEYFILE="$HOME/.zen/game/nostr/${KNAME}/.secret.nostr"
                                
                                ORE_RESULT=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
                                    --keyfile "$MULTIPASS_KEYFILE" \
                                    --content "$CONTRACT_CONTENT" \
                                    --relays "$myRELAY" \
                                    --tags "$ORE_CONTRACT_TAGS" \
                                    --kind "30312" \
                                    --json 2>&1)
                                
                                ORE_EVENT_ID=$(echo "$ORE_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
                                
                                # Also publish as kind 30023 for blog readers with full markdown content
                                BLOG_D_TAG="contract_${ITEM_TYPE}_${UMAP_LAT}_${UMAP_LON}_${TIMESTAMP_NOW}"
                                
                                # Build rich blog content with image and markdown
                                BLOG_FULL_CONTENT="# ${CONTRACT_TITLE}

![${ITEM_NAME}](${image_url})

## Identification

${BLOG_CONTENT}

---

## Détails du contrat

- **Type**: ${TYPE_NAME}
- **Nom**: ${ITEM_NAME}
- **Localisation**: ${ORIGINAL_LAT}, ${ORIGINAL_LON}
- **UMAP**: ${UMAP_LAT}, ${UMAP_LON}
- **Confiance IA**: ${CONFIDENCE_PCT}%

## Actions

👍 **Likez ce contrat** pour créditer des Ẑen aux gestionnaires de cet élément!

🏠 **Salle de gestion**: [UMAP_ORE_${UMAP_LAT}_${UMAP_LON}](${VDO_SERVICE})

---

*Contrat généré automatiquement par le système ORE UPlanet*

#UPlanet #ORE #inventory #${ITEM_TYPE} #contract #maintenance #communs"
                                
                                BLOG_TAGS=$(jq -n \
                                    --arg d "$BLOG_D_TAG" \
                                    --arg title "$CONTRACT_TITLE" \
                                    --arg summary "Contrat de gestion pour $ITEM_NAME ($TYPE_NAME) à ${UMAP_LAT}, ${UMAP_LON}" \
                                    --arg published_at "$TIMESTAMP_NOW" \
                                    --arg image "$image_url" \
                                    --arg lat "$ORIGINAL_LAT" \
                                    --arg lon "$ORIGINAL_LON" \
                                    --arg ore_ref "$ORE_EVENT_ID" \
                                    --arg item_type "$ITEM_TYPE" \
                                    --arg item_name "$ITEM_NAME" \
                                    '[
                                        ["d", $d],
                                        ["title", $title],
                                        ["summary", $summary],
                                        ["published_at", $published_at],
                                        ["image", $image],
                                        ["imeta", ("url " + $image), "m image/jpeg"],
                                        ["g", ($lat + "," + $lon)],
                                        ["t", "contract"],
                                        ["t", "maintenance"],
                                        ["t", "ORE"],
                                        ["t", "UPlanet"],
                                        ["t", "inventory"],
                                        ["t", $item_type],
                                        ["inventory_type", $item_type],
                                        ["inventory_name", $item_name],
                                        ["e", $ore_ref, "", "mention"]
                                    ]')
                                
                                BLOG_RESULT=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
                                    --keyfile "$MULTIPASS_KEYFILE" \
                                    --content "$BLOG_FULL_CONTENT" \
                                    --relays "$myRELAY" \
                                    --tags "$BLOG_TAGS" \
                                    --kind "30023" \
                                    --json 2>&1)
                                
                                BLOG_EVENT_ID=$(echo "$BLOG_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
                                if [[ -n "$BLOG_EVENT_ID" ]]; then
                                    echo "Inventory: Blog (kind 30023) published - Event ID: $BLOG_EVENT_ID" >&2
                                fi
                                
                                if [[ -n "$ORE_EVENT_ID" ]]; then
                                    echo "Inventory: ORE Contract published - Event ID: $ORE_EVENT_ID" >&2
                                    
                                    # Record observation in extended diversity tracker (ALL inventory types)
                                    # This updates ore_biodiversity.json with plant/insect/animal/object/place/person
                                    echo "Inventory: Recording observation in diversity tracker..." >&2
                                    UMAP_PATH="$HOME/.zen/tmp/${IPFSNODEID}/UPLANET/__/${UMAP_LAT:0:2}/${UMAP_LAT:3:2}/${UMAP_LAT},${UMAP_LON}"
                                    mkdir -p "$UMAP_PATH"
                                    
                                    # Call Python to add inventory observation to diversity tracker
                                    python3 -c "
import sys
sys.path.insert(0, '$HOME/.zen/Astroport.ONE/tools')
from ore_system import OREBiodiversityTracker

try:
    tracker = OREBiodiversityTracker('$UMAP_PATH')
    result = tracker.add_inventory_observation(
        inventory_type='$ITEM_TYPE',
        item_name='$ITEM_NAME',
        item_id='$(echo "$ITEM_NAME" | tr ' ' '_' | tr '[:upper:]' '[:lower:]')_$(date +%Y%m%d)',
        observer_pubkey='$pubkey',
        confidence=$CONFIDENCE,
        image_url='$image_url',
        nostr_event_id='$ORE_EVENT_ID',
        scientific_name='',
        description='Contract: $CONTRACT_TITLE',
        location='${ORIGINAL_LAT},${ORIGINAL_LON}'
    )
    print(f\"✅ Diversity: {result.get('type_icon', '📦')} {result.get('item_name')} recorded\")
    print(f\"   Type: {result.get('inventory_type')} ({result.get('type_count')} total)\")
    print(f\"   Diversity score: {result.get('diversity_score', 0):.2f}\")
except Exception as e:
    print(f'⚠️ Diversity tracker warning: {e}')
" 2>&1 | while read line; do echo "Inventory: $line" >&2; done
                                    
                                    # Update UMAP DID with extended diversity data (ORE_SYSTEM.md compliance)
                                    echo "Inventory: Updating UMAP DID with diversity data..." >&2
                                    $MY_PATH/../tools/did_manager_nostr.sh update "UMAP_${UMAP_LAT}_${UMAP_LON}" "INVENTORY_ITEM" 0 0 "" >/dev/null 2>&1
                                    
                                    # Add contract reference to the inventory response (KIND 1 - NO MARKDOWN!)
                                    # Plain text only for kind 1 messages
                                    KeyANSWER="${KeyANSWER}

📄 Contrat ORE: nostr:nevent1${ORE_EVENT_ID:0:20}..."
                                    
                                    # Add ORE-compatible tags with blog reference
                                    ExtraTags="[['imeta', 'url $image_url', 'm image/jpeg'], ['g', '${ORIGINAL_LAT},${ORIGINAL_LON}'], ['umap', '${UMAP_LAT},${UMAP_LON}'], ['t', 'inventory'], ['t', 'UPlanet'], ['t', 'ORE'], ['t', '$ITEM_TYPE'], ['inventory_type', '$ITEM_TYPE'], ['inventory_name', '$ITEM_NAME'], ['e', '$ORE_EVENT_ID', '', 'mention']$(if [[ -n "$BLOG_EVENT_ID" ]]; then echo ", ['e', '$BLOG_EVENT_ID', '', 'mention']"; fi)]"
                                else
                                    echo "Inventory: Warning - Failed to publish ORE contract" >&2
                                fi
                            fi
                        else
                            echo "Inventory: Recognition failed" >&2
                            KeyANSWER="❌ Reconnaissance échouée

L'élément n'a pas pu être identifié avec certitude.

💡 Conseils :
• Prenez une photo plus claire
• Assurez-vous que l'élément occupe la majeure partie de l'image
• Utilisez un tag spécifique (#plant, #object, #animal, etc.)

📍 Localisation : ${ORIGINAL_LAT}, ${ORIGINAL_LON}

#UPlanet #inventory"
                        fi
                    else
                        echo "Inventory: Recognition script failed with exit code $INVENTORY_EXIT" >&2
                        KeyANSWER="❌ Erreur lors de la reconnaissance

Une erreur technique s'est produite.

📍 Localisation : ${ORIGINAL_LAT:-0}, ${ORIGINAL_LON:-0}

#UPlanet #inventory"
                    fi
                else
                    echo "Inventory: No valid image URL found" >&2
                    KeyANSWER="❌ Aucune image trouvée

Veuillez inclure une image avec votre message pour l'inventaire UPlanet.

**Usage :** #BRO #inventory [image]
**Types spécifiques :** #plant, #insect, #animal, #person, #object, #place

#UPlanet #inventory"
                fi
            ######################################################### #cookie
            elif [[ "${TAGS[cookie]}" == true ]]; then
                # Cookie workflow execution
                echo "Processing cookie workflow execution request..." >&2
                
                # Extract workflow name/ID from message
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#cookie//g; s/"//g' <<< "$message_text")
                workflow_identifier=$(echo "$cleaned_text" | awk '{print $1}' | tr -d '[:space:]')
                
                if [[ -z "$workflow_identifier" ]]; then
                    KeyANSWER="❌ No workflow specified. Usage: #BRO #cookie <workflow_name_or_id>"
                else
                    echo "Executing cookie workflow: $workflow_identifier" >&2
                    
                    # Call workflow engine script
                    if [[ -x "$MY_PATH/cookie_workflow_engine.sh" ]]; then
                        WORKFLOW_RESULT=$("$MY_PATH/cookie_workflow_engine.sh" "$workflow_identifier" "$KNAME" "$PUBKEY" "$EVENT" 2>&1)
                        if [[ $? -eq 0 ]]; then
                            KeyANSWER="✅ Cookie workflow executed successfully: $workflow_identifier

$WORKFLOW_RESULT"
                        else
                            KeyANSWER="❌ Cookie workflow execution failed: $workflow_identifier

Error: $WORKFLOW_RESULT"
                        fi
                    else
                        KeyANSWER="⚠️ Cookie workflow engine not available. Please ensure cookie_workflow_engine.sh is installed and executable."
                    fi
                fi
            ######################################################### #pierre / #amelie
            elif [[ "${TAGS[pierre]}" == true || "${TAGS[amelie]}" == true ]]; then
                # Determine voice
                if [[ "${TAGS[pierre]}" == true ]]; then
                    voice="pierre"
                else
                    voice="amelie"
                fi
                
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#pierre//g; s/#amelie//g; s/"//g' <<< "$message_text")
                
                echo "Génération de synthèse vocale avec la voix: $voice" >&2
                start_time=$(date +%s.%N)
                audio_url=$($MY_PATH/generate_speech.sh "$cleaned_text" "$voice")
                end_time=$(date +%s.%N)
                execution_time=$(echo "$end_time - $start_time" | bc)
                
                if [ -n "$audio_url" ]; then
                    KeyANSWER=$(echo -e "🔊 $CURRENT_TIME_STR (⏱️ ${execution_time%.*} s)\n👤 Voix: $voice\n📝 Texte: $cleaned_text\n🔗 $audio_url")
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer la synthèse vocale demandée."
                fi
            else
                # Default AI response
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#search//g; s/"//g' <<< "$QUESTION")
                if [[ -n "$user_id" ]]; then
                    if check_memory_slot_access "$user_id" "$memory_slot"; then
                        KeyANSWER="$($MY_PATH/question.py "${cleaned_text}" --user-id "${user_id}" --slot ${memory_slot})"
                    else
                        echo "Memory access denied for AI question - USER: $user_id, SLOT: $memory_slot"
                        send_memory_access_denied "$PUBKEY" "$EVENT" "$memory_slot"
                        KeyANSWER="Accès refusé au slot $memory_slot pour l'IA. Seuls les sociétaires CopyLaRadio peuvent utiliser les slots 1-12. Utilisez le slot 0 ou devenez sociétaire."
                    fi
                else
                KeyANSWER="$($MY_PATH/question.py "${cleaned_text}" --pubkey ${PUBKEY})"
                fi
            fi
        fi

        # Priority order for response key:
        # 1. UMAP key for PlantNet responses (geographical location-based responses)
        # 2. User key (KNAME) if available
        # + UMAP key follows
        # 3. CAPTAIN key as fallback
        
        # Check if PlantNet mode requires UMAP key
        if [[ "${USE_UMAP_FOR_PLANTNET:-false}" == true ]]; then
            # Use UMAP key for PlantNet responses
            echo "PlantNet: Using UMAP key for response at location ${LAT}, ${LON}" >&2
            
            # Generate UMAP keys if not already generated
            if [[ -z "$UMAPNSEC" ]]; then
                UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
            fi
            
            # Ensure UMAPNPUB is available
            if [[ -z "$UMAPNPUB" ]]; then
                UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
            fi
            
            # Ensure UMAPHEX is available
            if [[ -z "$UMAPHEX" ]]; then
                UMAPHEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNPUB")
            fi
            
            # Create temporary .secret.nostr file for UMAP key
            UMAP_KEYFILE="$HOME/.zen/tmp/umap_${LAT}_${LON}_${CURRENT_TIMESTAMP}.secret.nostr"
            echo "NSEC=${UMAPNSEC}; NPUB=${UMAPNPUB}; HEX=${UMAPHEX};" > "$UMAP_KEYFILE"
            
            # Set KEYFILE_PATH for sending
            KEYFILE_PATH="$UMAP_KEYFILE"
            
            # UMAP follows the original pubkey
            ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY" 2>/dev/null
            
            echo "PlantNet: Using UMAP keyfile: $KEYFILE_PATH" >&2
        elif [[ -s ~/.zen/game/nostr/${KNAME}/.secret.nostr ]]; then
            # UMAP is following if coordinates are provided
            if [[ "$LAT" != "0.00" && "$LON" != "0.00" && -n "$LAT" && -n "$LON" ]]; then
                echo "Using UMAP key for geographical location : ${LAT}, ${LON}"
                UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
                ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY" 2>/dev/null
            fi
            echo "Using USER key for response: ${KNAME}"
            source ~/.zen/game/nostr/${KNAME}/.secret.nostr
            KEYFILE_PATH="$HOME/.zen/game/nostr/${KNAME}/.secret.nostr"
        else
            # CAPTAIN is following as fallback
            echo "No valid user key, using CAPTAIN key"
            source ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
            ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "$PUBKEY" 2>/dev/null
            KEYFILE_PATH="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
        fi

        # Clean KeyANSWER of BOT and BRO tags
        KeyANSWER=$(echo "$KeyANSWER" | sed 's/#BOT//g; s/#BRO//g; s/#bot//g; s/#bro//g')

        ## SEND REPLY MESSAGE
        if [[ "$SECRET_MODE" == true ]]; then
            # Send encrypted DM
            if [[ -n "$KNAME" ]]; then
                # Capitaine speaking
                KNAME_HEX_FILE="$HOME/.zen/game/nostr/$KNAME/HEX"
                if [[ -f "$KNAME_HEX_FILE" ]]; then
                    KNAME_HEX=$(cat "$KNAME_HEX_FILE")
                    echo "[SECRET] Found KNAME hex key: $KNAME_HEX for $KNAME"
                    
                    if [[ -z "$KeyANSWER" ]]; then
                        echo "[SECRET] KeyANSWER is empty, sending fallback message" >&2
                        KeyANSWER="Réponse IA non générée. Erreur technique. $CURRENT_TIME_STR"
                    fi
                    
                    echo "[SECRET] Sending DM with content: $KeyANSWER" >&2
                    # Note: DM functionality still uses nostr_send_secure_dm.py
                    source ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
                    DM_RESULT=$($HOME/.zen/Astroport.ONE/tools/nostr_send_secure_dm.py "$NSEC" "$KNAME_HEX" "$KeyANSWER" "$myRELAY" 2>&1)
                    DM_EXIT_CODE=$?
                    
                    if [[ $DM_EXIT_CODE -eq 0 ]]; then
                        echo "[SECRET] Private DM sent successfully to $KNAME ($KNAME_HEX) via NOSTR relay (event not stored in strfry)." >&2
                    else
                        echo "[SECRET] Failed to send DM. Exit code: $DM_EXIT_CODE" >&2
                        echo "[SECRET] DM error output: $DM_RESULT" >&2
                        send_error_email "Failed to send private DM to $KNAME. Exit code: $DM_EXIT_CODE. Error: $DM_RESULT" "~/.zen/tmp/IA.log"
                        FALLBACK_MSG="Message privé non envoyé. Erreur technique. $CURRENT_TIME_STR"
                        $HOME/.zen/Astroport.ONE/tools/nostr_send_secure_dm.py "$NSEC" "$KNAME_HEX" "$FALLBACK_MSG" "$myRELAY" >/dev/null 2>&1
                    fi
                else
                    echo "[SECRET] KNAME hex key not found at $KNAME_HEX_FILE, cannot send DM."
                fi
            else
                echo "[SECRET] KNAME not set, cannot send DM."
            fi
            
            # Clean up temporary UMAP keyfile if it was created (even in SECRET mode)
            if [[ "${USE_UMAP_FOR_PLANTNET:-false}" == true && -n "${UMAP_KEYFILE:-}" && -f "$UMAP_KEYFILE" ]]; then
                echo "PlantNet: Cleaning up temporary UMAP keyfile: $UMAP_KEYFILE" >&2
                rm -f "$UMAP_KEYFILE"
            fi
        else
            # Send public message with appropriate tags using nostr_send_note.py
            echo "DEBUG: AnswerKind=$AnswerKind, ExtraTags=$ExtraTags" >&2
            
            # Detect if this is an error message (add 1-hour TTL via NIP-40)
            IS_ERROR_MESSAGE=false
            if [[ "$KeyANSWER" =~ ^❌ ]] || [[ "$KeyANSWER" =~ ^⚠️ ]] || [[ "$KeyANSWER" =~ ^Désolé ]] || \
               [[ "$KeyANSWER" =~ "Erreur" ]] || [[ "$KeyANSWER" =~ "échoué" ]] || [[ "$KeyANSWER" =~ "Accès refusé" ]]; then
                IS_ERROR_MESSAGE=true
                EXPIRATION_TS=$(($(date +%s) + 3600))
                echo "DEBUG: Error message detected - adding 1h TTL (expiration: $EXPIRATION_TS)" >&2
            fi
            
            # Prepare tags in JSON format
            if [[ -n "$ExtraTags" ]]; then
                # For kind 30023, use only the specific blog tags
                if [[ "$AnswerKind" == "30023" ]]; then
                    TAGS_JSON="$ExtraTags"
                else
                    # For other kinds, combine standard tags with extra tags
                    # Convert Python list format to proper JSON
                    ExtraTagsJSON=$(echo "$ExtraTags" | sed "s/'/\"/g")
                    # Remove outer brackets and add standard tags
                    ExtraTagsContent=$(echo "$ExtraTagsJSON" | sed 's/^\[//' | sed 's/\]$//')
                    if [[ "$IS_ERROR_MESSAGE" == true ]]; then
                        TAGS_JSON='[["e","'$EVENT'"],["p","'$PUBKEY'"],["expiration","'$EXPIRATION_TS'"],'$ExtraTagsContent']'
                    else
                        TAGS_JSON='[["e","'$EVENT'"],["p","'$PUBKEY'"],'$ExtraTagsContent']'
                    fi
                fi
            else
                # Use standard tags only
                if [[ "$IS_ERROR_MESSAGE" == true ]]; then
                    TAGS_JSON='[["e","'$EVENT'"],["p","'$PUBKEY'"],["expiration","'$EXPIRATION_TS'"]]'
                else
                    TAGS_JSON='[["e","'$EVENT'"],["p","'$PUBKEY'"]]'
                fi
            fi
            
            echo "DEBUG: Sending to relay $myRELAY with tags: $TAGS_JSON" >&2
            
            # Send event using nostr_send_note.py
            SEND_RESULT=$(python3 "$HOME/.zen/Astroport.ONE/tools/nostr_send_note.py" \
                --keyfile "$KEYFILE_PATH" \
                --content "$KeyANSWER" \
                --relays "$myRELAY" \
                --tags "$TAGS_JSON" \
                --kind "$AnswerKind" \
                --json 2>&1)
            SEND_EXIT_CODE=$?
            
            if [[ $SEND_EXIT_CODE -eq 0 ]]; then
                # Parse JSON response
                EVENT_ID=$(echo "$SEND_RESULT" | jq -r '.event_id // empty' 2>/dev/null)
                RELAYS_SUCCESS=$(echo "$SEND_RESULT" | jq -r '.relays_success // 0' 2>/dev/null)
                
                if [[ -n "$EVENT_ID" && "$RELAYS_SUCCESS" -gt 0 ]]; then
                    echo "✅ Event published successfully - ID: $EVENT_ID (Kind: $AnswerKind)" >&2
                else
                    echo "⚠️ Event may not have been published correctly" >&2
                    echo "Response: $SEND_RESULT" >&2
                    send_error_email "Event published with warnings. Response: $SEND_RESULT" "~/.zen/tmp/IA.log"
                fi
            else
                echo "❌ Failed to send event. Exit code: $SEND_EXIT_CODE" >&2
                echo "Error output: $SEND_RESULT" >&2
                send_error_email "Failed to send Nostr event (kind: $AnswerKind). Exit code: $SEND_EXIT_CODE. Error: $SEND_RESULT" "~/.zen/tmp/IA.log"
            fi
            
            # Clean up temporary UMAP keyfile if it was created
            if [[ "${USE_UMAP_FOR_PLANTNET:-false}" == true && -n "${UMAP_KEYFILE:-}" && -f "$UMAP_KEYFILE" ]]; then
                echo "PlantNet: Cleaning up temporary UMAP keyfile: $UMAP_KEYFILE" >&2
                rm -f "$UMAP_KEYFILE"
            fi
        fi
        
        ## AUTO-RECORD BOT RESPONSE if #rec2 is present
        if [[ "${TAGS[rec2]}" == true ]]; then
            if check_memory_slot_access "$user_id" "$memory_slot"; then
                echo "Auto-recording bot response for USER: $user_id, SLOT: $memory_slot"
                if [[ "$SECRET_MODE" == true ]]; then
                    bot_event_json='{"event":{"id":"secret_bot_response_'$CURRENT_TIMESTAMP'","content":"'"$KeyANSWER"'","pubkey":"'"$UMAPHEX"'","created_at":'$CURRENT_TIMESTAMP'}}'
                else
                    bot_event_json='{"event":{"id":"bot_response_'$CURRENT_TIMESTAMP'","content":"'"$KeyANSWER"'","pubkey":"'"$UMAPHEX"'","created_at":'$CURRENT_TIMESTAMP'}}'
                fi
                $MY_PATH/short_memory.py "$bot_event_json" "$LAT" "$LON" "$memory_slot" "$user_id"
            else
                echo "Memory access denied for auto-recording - USER: $user_id, SLOT: $memory_slot"
                if [[ "$SECRET_MODE" != true ]]; then
                    send_memory_access_denied "$PUBKEY" "$EVENT" "$memory_slot"
                fi
            fi
        fi
    fi
fi

echo ""
echo "--- Summary ---"
echo "PUBKEY: $PUBKEY"
echo "EVENT: $EVENT"
echo "LAT: $LAT"
echo "LON: $LON"
echo "Message: $message_text"
echo "Image: $DESC"
echo "Question: $QUESTION"
echo "Answer: $KeyANSWER"
echo "---------------"

# Error handling: Send email to CAPTAINEMAIL if there was an error
if [[ $? -ne 0 || -z "$KeyANSWER" ]]; then
    echo "❌ Error detected in UPlanet_IA_Responder.sh" >&2
    
    # Create error log file
    ERROR_LOG_FILE="/tmp/uplanet_error_$(date +%Y%m%d_%H%M%S).log"
    {
        echo "=== UPlanet IA Responder Error Report ==="
        echo "Timestamp: $(date)"
        echo "PUBKEY: $PUBKEY"
        echo "EVENT: $EVENT"
        echo "LAT: $LAT"
        echo "LON: $LON"
        echo "MESSAGE: $MESSAGE"
        echo "KNAME: $KNAME"
        echo "KeyANSWER: $KeyANSWER"
        echo ""
        echo "=== Recent Log Entries ==="
        tail -50 ~/.zen/tmp/IA.log 2>/dev/null || echo "No IA.log found"
    } > "$ERROR_LOG_FILE"
    
    # Send error report via mailjet if CAPTAINEMAIL is available
    if [[ -n "$CAPTAINEMAIL" && -s "$MY_PATH/../tools/mailjet.sh" ]]; then
        echo "📧 Sending error report to CAPTAIN: $CAPTAINEMAIL" >&2
        $MY_PATH/../tools/mailjet.sh --expire 24h "$CAPTAINEMAIL" "$ERROR_LOG_FILE" "UPlanet IA Error Report" 2>/dev/null
        echo "✅ Error report sent to $CAPTAINEMAIL" >&2
    else
        echo "⚠️ Cannot send error report - CAPTAINEMAIL or mailjet.sh not available" >&2
    fi
    
    # Clean up error log file
    rm -f "$ERROR_LOG_FILE"
fi

exit 0
