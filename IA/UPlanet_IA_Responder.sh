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
# - #youtube : Télécharger une vidéo YouTube (720p max) #mp3 pour convertir en audio (COOKIE PB !)
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

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
exec 2>&1 >> ~/.zen/tmp/IA.log

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

## Optimisation: Extract URLs once
if [ -z "$URL" ]; then
    # Extract image URLs - handle filenames with spaces by collecting tokens until we hit a hashtag
    URL=$(echo "$MESSAGE" | awk '{
        for(i=1; i<=NF; i++) {
            if ($i ~ /^https?:\/\/.*\.(png|gif|jpg|jpeg|webp|PNG|GIF|JPG|JPEG|WEBP)/) {
                url = $i
                # Continue collecting until we hit a # or end
                for(j=i+1; j<=NF; j++) {
                    if ($j ~ /^#/) break
                    url = url " " $j
                }
                # Remove any trailing # tags
                sub(/ *#.*$/, "", url)
                print url
                exit
            }
        }
    }' | head -n 1)
    
    # If no URL found with extension in first token, try matching across multiple tokens
    if [[ -z "$URL" ]]; then
        URL=$(echo "$MESSAGE" | awk '{
            for(i=1; i<=NF; i++) {
                if ($i ~ /^https?:\/\//) {
                    url = $i
                    # Continue collecting until we hit a # or end or find image extension
                    for(j=i+1; j<=NF; j++) {
                        if ($j ~ /^#/) break
                        url = url " " $j
                        if (url ~ /\.(png|gif|jpg|jpeg|webp|PNG|GIF|JPG|JPEG|WEBP)/) {
                            sub(/ *#.*$/, "", url)
                            print url
                            exit
                        }
                    }
                }
            }
        }' | head -n 1)
    fi
    
    # Extract any URL for general use (first http/https URL found)
    ANYURL=$(echo "$MESSAGE" | awk 'match($0, /https?:\/\/[^ ]+/) { print substr($0, RSTART, RLENGTH) }' | head -n 1)
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

# Single pass tag detection
if [[ "$message_text" =~ \#BRO\  ]]; then TAGS[BRO]=true; fi
if [[ "$message_text" =~ \#BOT\  ]]; then TAGS[BOT]=true; fi
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
        
        DENIED_MSG="⚠️ Accès refusé aux slots de mémoire 1-12.

Pour utiliser les slots de mémoire 1-12, vous devez être sociétaire CopyLaRadio et posséder une ZenCard.

Le slot 0 reste accessible pour tous les utilisateurs autorisés.

Pour devenir sociétaire : $myIPFS/ipns/copylaradio.com

Votre Capitaine.
#CopyLaRadio #mem"

        nostpy-cli send_event \
          -privkey "$NPRIV_HEX" \
          -kind 1 \
          -content "$DENIED_MSG" \
          -tags "[['e', '$event_id'], ['p', '$pubkey'], ['t', 'MemoryAccessDenied']]" \
          --relay "$myRELAY" 2>/dev/null
    fi
    ) &
}

# Function to handle PlantNet recognition with image description
handle_plantnet_recognition() {
    local image_url="$1"
    local latitude="$2"
    local longitude="$3"
    local user_id="$4"
    local event_id="$5"
    local pubkey="$6"
    
    echo "PlantNet: Starting recognition process with image description..." >&2
    
    # First, get image description using describe_image.py
    echo "PlantNet: Getting image description..." >&2
    local image_desc=""
    if [[ -n "$image_url" ]]; then
        # Properly quote the URL to handle spaces and special characters
        image_desc=$("$MY_PATH/describe_image.py" "$image_url" --json | jq -r '.description' 2>/dev/null)
        if [[ -z "$image_desc" || "$image_desc" == "null" ]]; then
            image_desc="Image analysis failed"
        fi
        echo "PlantNet: Image description: $image_desc" >&2
    fi
    
    # Call PlantNet recognition script with image description
    echo "PlantNet: Calling PlantNet API..." >&2
    local plantnet_result=""
    plantnet_result=$($MY_PATH/plantnet_recognition.py "$image_url" "$latitude" "$longitude" "$user_id" "$event_id" "$pubkey" 2>/dev/null)
    
    local exit_code=$?
    if [[ $exit_code -eq 0 && -n "$plantnet_result" ]]; then
        echo "PlantNet: Recognition completed successfully" >&2
        # Return the actual PlantNet result instead of generic message
        echo "$plantnet_result"
    else
        echo "PlantNet: Recognition failed with exit code $exit_code" >&2
        echo "PlantNet: Checking for error details in plantnet.log..." >&2
        
        # Try to get error details from log
        local error_details=""
        if [[ -f "/home/fred/.zen/tmp/plantnet.log" ]]; then
            error_details=$(tail -5 "/home/fred/.zen/tmp/plantnet.log" | grep -E "(ERROR|Error|error)" | tail -1)
            echo "PlantNet: Last error from log: $error_details" >&2
        fi
        
        # Fallback to image description if PlantNet fails
        if [[ -n "$image_desc" ]]; then
            echo "🌿 Analyse d'image (PlantNet indisponible)

📸 **Description de l'image :** $image_desc

❌ **PlantNet API indisponible** (code d'erreur: $exit_code)
$error_details

📍 **Localisation :** $latitude, $longitude

💡 **Conseils :**
• Vérifiez que la clé API PlantNet est configurée
• L'image doit être claire et montrer des parties de plante
• Formats supportés : JPG, JPEG, PNG, GIF, WEBP

#PlantNet #BRO #jardinage"
        else
            echo "❌ Erreur lors de l'analyse de l'image

❌ **PlantNet API indisponible** (code d'erreur: $exit_code)
$error_details

📍 **Localisation :** $latitude, $longitude

💡 **Vérifiez :**
• Que la clé API PlantNet est configurée
• Que l'image est accessible et valide
• Les logs pour plus de détails

#PlantNet #BRO #jardinage"
        fi
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

    ##################################################### ASK IA
    ## KNOWN KNAME & CAPTAIN REPLY
    if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ || $KNAME == "CAPTAIN" ]]; then
        # Only generate an answer if KeyANSWER is not already set
        if [[ -z "$KeyANSWER" ]]; then
            # Optimisation: Process specialized commands
            if [[ "${TAGS[search]}" == true ]]; then
                $MY_PATH/perplexica.me.sh
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#search//g; s/"//g' <<< "$message_text")
                KeyANSWER="$($MY_PATH/perplexica_search.sh "${cleaned_text}")"
            elif [[ "${TAGS[image]}" == true ]]; then
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#image//g; s/"//g' <<< "$message_text")
                $MY_PATH/comfyui.me.sh
                start_time=$(date +%s.%N)
                
                # Get user uDRIVE path and generate image
                USER_UDRIVE_PATH=$(get_user_udrive_from_kname)
                if [ $? -eq 0 ]; then
                    IMAGE_URL="$($MY_PATH/generate_image.sh "${cleaned_text}" "$USER_UDRIVE_PATH")"
                else
                    echo "Warning: Using default location for image generation" >&2
                    IMAGE_URL="$($MY_PATH/generate_image.sh "${cleaned_text}")"
                fi
                
                end_time=$(date +%s.%N)
                execution_time=$(echo "$end_time - $start_time" | bc)
                if [ -n "$IMAGE_URL" ]; then
                    KeyANSWER=$(echo -e "🖼️ $CURRENT_TIME_STR (⏱️ ${execution_time%.*} s)\n📝 Description: $cleaned_text\n🔗 $IMAGE_URL")
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer l'image demandée."
                fi
            elif [[ "${TAGS[video]}" == true ]]; then
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#video//g; s/"//g' <<< "$message_text")
                $MY_PATH/comfyui.me.sh
                
                # Get user uDRIVE path and generate video
                USER_UDRIVE_PATH=$(get_user_udrive_from_kname)
                if [ $? -eq 0 ]; then
                    VIDEO_AI_RETURN="$($MY_PATH/generate_video.sh "${cleaned_text}" "$MY_PATH/workflow/Text2VideoWan2.1.json" "$USER_UDRIVE_PATH")"
                else
                    echo "Warning: Using default location for video generation" >&2
                    VIDEO_AI_RETURN="$($MY_PATH/generate_video.sh "${cleaned_text}" "$MY_PATH/workflow/Text2VideoWan2.1.json")"
                fi
                
                if [ -n "$VIDEO_AI_RETURN" ]; then
                    KeyANSWER="$VIDEO_AI_RETURN"
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer la vidéo demandée."
                fi
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
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer la musique demandée."
                fi
            elif [[ "${TAGS[youtube]}" == true ]]; then
                youtube_url=$(echo "$message_text" | awk 'match($0, /https?:\/\/(www\.)?(youtube\.com|youtu\.be)\/[^ ]+/) { print substr($0, RSTART, RLENGTH) }')
                if [ -z "$youtube_url" ]; then
                    KeyANSWER="Désolé, Aucune URL YouTube valide trouvée dans votre message."
                else
                    # Enable debug mode for YouTube processing
                    if [[ "$message_text" =~ \#mp3 ]]; then
                        json=$($MY_PATH/process_youtube.sh --debug "$youtube_url" "mp3")
                    else
                        json=$($MY_PATH/process_youtube.sh --debug "$youtube_url" "mp4")
                    fi
                    error=$(echo "$json" | jq -r .error 2>/dev/null)
                    if [[ -n "$error" && "$error" != "null" ]]; then
                        # Format error message with proper newlines
                        error_formatted=$(echo -e "$error")
                        KeyANSWER="$error_formatted"
                    else
                        # Extract multiple values in one jq call
                        eval $(echo "$json" | jq -r '"ipfs_url=" + .ipfs_url + ";" + "title=" + (.title | @sh) + ";" + "duration=" + (.duration | tostring) + ";" + "uploader=" + (.uploader | @sh) + ";" + "original_url=" + .original_url')
                        
                        # Format duration in H:MM:SS if possible
                        if [[ "$duration" =~ ^[0-9]+$ ]]; then
                            hours=$((duration/3600))
                            mins=$(( (duration%3600)/60 ))
                            secs=$((duration%60))
                            if (( hours > 0 )); then
                                duration_fmt=$(printf "%d:%02d:%02d" $hours $mins $secs)
                            else
                                duration_fmt=$(printf "%02d:%02d" $mins $secs)
                            fi
                        else
                            duration_fmt="$duration"
                        fi
                        KeyANSWER="🎬 Title: $title\n⏱️ Duration: $duration_fmt\n👤 Uploader: $uploader\n🔗 Original: $original_url\n📦 IPFS: $ipfs_url"
                    fi
                fi
            elif [[ "${TAGS[plantnet]}" == true ]]; then
                # PlantNet recognition processing
                echo "Processing PlantNet recognition request..." >&2
                
                # Extract image URL from message or use provided URL
                image_url=""
                if [[ -n "$URL" ]]; then
                    image_url="$URL"
                else
                    # Try to extract image URL from message content
                    image_url=$(echo "$message_text" | awk 'match($0, /https?:\/\/[^ ]+\.(jpg|jpeg|png|gif|webp)/) { print substr($0, RSTART, RLENGTH) }' | head -n1)
                fi
                
                if [[ -n "$image_url" ]]; then
                    echo "PlantNet: Found image URL: $image_url" >&2
                    
                    # Call PlantNet recognition with image description
                    KeyANSWER=$(handle_plantnet_recognition "$image_url" "$LAT" "$LON" "$user_id" "$EVENT" "$PUBKEY")
                else
                    echo "PlantNet: No valid image URL found in message" >&2
                    KeyANSWER="❌ Aucune image valide trouvée pour la reconnaissance PlantNet.

Veuillez inclure une URL d'image valide dans votre message ou utiliser le tag #plantnet avec une photo.

**Formats supportés :** JPG, JPEG, PNG, GIF, WEBP
**Note :** Seuls les fichiers image sont analysés. Les autres types de fichiers sont ignorés.

#PlantNet #BRO #jardinage"
                fi
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
        # 1. User key (KNAME) if available
        # + UMAP key follows
        # 2. CAPTAIN key as fallback
        
        if [[ -s ~/.zen/game/nostr/${KNAME}/.secret.nostr ]]; then
            # UMAP is following if coordinates are provided
            if [[ "$LAT" != "0.00" && "$LON" != "0.00" && -n "$LAT" && -n "$LON" ]]; then
                echo "Using UMAP key for geographical location : ${LAT}, ${LON}"
                UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
                ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY" 2>/dev/null
            fi
            echo "Using USER key for response: ${KNAME}"
            source ~/.zen/game/nostr/${KNAME}/.secret.nostr
        else
            # CAPTAIN is responding as fallback
            echo "No valid user key, using CAPTAIN key"
            source ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
            ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "$PUBKEY" 2>/dev/null
        fi

        NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC")

        # Clean KeyANSWER of BOT and BRO tags
        KeyANSWER=$(echo "$KeyANSWER" | sed 's/#BOT//g; s/#BRO//g; s/#bot//g; s/#bro//g')

        ## SEND REPLY MESSAGE
        if [[ "$SECRET_MODE" == true ]]; then
            # Send encrypted DM
            if [[ -n "$KNAME" ]]; then
                # Capitaine speaking
                source ~/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
                NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC")
                
                KNAME_HEX_FILE="$HOME/.zen/game/nostr/$KNAME/HEX"
                if [[ -f "$KNAME_HEX_FILE" ]]; then
                    KNAME_HEX=$(cat "$KNAME_HEX_FILE")
                    echo "[SECRET] Found KNAME hex key: $KNAME_HEX for $KNAME"
                    
                    if [[ -z "$KeyANSWER" ]]; then
                        echo "[SECRET] KeyANSWER is empty, sending fallback message" >&2
                        KeyANSWER="Réponse IA non générée. Erreur technique. $CURRENT_TIME_STR"
                    fi
                    
                    echo "[SECRET] Sending DM with content: $KeyANSWER" >&2
                    DM_RESULT=$($HOME/.zen/Astroport.ONE/tools/nostr_send_dm.py "$NSEC" "$KNAME_HEX" "$KeyANSWER" "$myRELAY" 2>&1)
                    DM_EXIT_CODE=$?
                    
                    if [[ $DM_EXIT_CODE -eq 0 ]]; then
                        echo "[SECRET] Private DM sent successfully to $KNAME ($KNAME_HEX) via NOSTR relay (event not stored in strfry)." >&2
                    else
                        echo "[SECRET] Failed to send DM. Exit code: $DM_EXIT_CODE" >&2
                        echo "[SECRET] DM error output: $DM_RESULT" >&2
                        FALLBACK_MSG="Message privé non envoyé. Erreur technique. $CURRENT_TIME_STR"
                        $HOME/.zen/Astroport.ONE/tools/nostr_send_dm.py "$NSEC" "$KNAME_HEX" "$FALLBACK_MSG" "$myRELAY" >/dev/null 2>&1
                    fi
                else
                    echo "[SECRET] KNAME hex key not found at $KNAME_HEX_FILE, cannot send DM."
                fi
            else
                echo "[SECRET] KNAME not set, cannot send DM."
            fi
        else
            # Send public message
        nostpy-cli send_event \
          -privkey "$NPRIV_HEX" \
          -kind 1 \
          -content "$KeyANSWER" \
          -tags "[['e', '$EVENT'], ['p', '$PUBKEY']]" \
          --relay "$myRELAY"
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

exit 0
