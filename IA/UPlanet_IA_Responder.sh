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

## If No URL : Getting URL from message content - recognize describe_image.py
if [ -z "$URL" ]; then
    # Extraire le premier lien .gif .png ou .jpg de MESSAGE
    URL=$(echo "$MESSAGE" | grep -oE 'http[s]?://[^ ]+\.(png|gif|jpg|jpeg)' | head -n 1)
    ANYURL=$(echo "$MESSAGE" | grep -oE 'http[s]?://[^ ]+' | head -n 1)
fi

echo "Received parameters:" >&2
echo "  PUBKEY: $PUBKEY" >&2
echo "  EVENT: $EVENT" >&2
echo "  LAT: $LAT" >&2
echo "  LON: $LON" >&2
echo "  MESSAGE: $MESSAGE" >&2
echo "  IMAGE: $URL" >&2
echo "  ANYURL: $ANYURL" >&2
echo "  KNAME: $KNAME" >&2
echo "" >&2

# Define log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

# Function to check if user has access to memory slots 1-12
check_memory_slot_access() {
    local user_id="$1"
    local slot="$2"
    
    # Slot 0 is always accessible
    if [[ "$slot" == "0" ]]; then
        return 0
    fi
    
    # For slots 1-12, check if user is in ~/.zen/game/players/
    if [[ "$slot" -ge 1 && "$slot" -le 12 ]]; then
        if [[ -d "$HOME/.zen/game/players/$user_id" ]]; then
            return 0  # User has access
        else
            return 1  # User doesn't have access
        fi
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
    source ~/.zen/game/players/.current/secret.nostr ## CAPTAIN SPEAKING
    if [[ "$pubkey" != "$HEX" && "$NSEC" != "" ]]; then
        NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC")
        
        DENIED_MSG="⚠️ Accès refusé aux slots de mémoire 1-12.

Pour utiliser les slots de mémoire 1-12, vous devez être sociétaire CopyLaRadio et posséder une ZenCard.

Le slot 0 reste accessible pour tous les utilisateurs autorisés.

Pour devenir sociétaire : $myIPFS/ipns/copylaradio.com

Votre Astroport Captain.
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

# Function to get an event by ID using strfry scan
get_event_by_id() {
    local event_id="$1"
    cd $HOME/.zen/strfry
    # Use strfry scan with a filter for the specific event ID
    ./strfry scan '{"ids":["'"$event_id"'"]}' 2>/dev/null
    cd - 1>&2>/dev/null
}

# Function to get the conversation thread :
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

## Getting KNAME default localisation
if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    if [[ $LAT == "0.00" && $LON == "0.00" ]]; then
        ## Check SWARM account
        isInSwarmGPS=$(ls ${HOME}/.zen/tmp/swarm/*/TW/${KNAME}/GPS 2>/dev/null)
        [[ -n  ${isInSwarmGPS} ]] \
            && source ${isInSwarmGPS}

        ## source NOSTR Card LAT=?;LON=?;
        [[ -s ${HOME}/.zen/game/nostr/${KNAME}/GPS ]] \
            && source ${HOME}/.zen/game/nostr/${KNAME}/GPS
    fi
    # correct empty value
    [[ -z $LAT ]] && LAT="0.00"
    [[ -z $LON ]] && LON="0.00"
fi

echo "UMAP : ${LAT} ${LON}"

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

##################################################################""
## Inform Swarm cache (UPLANET.refresh.sh)
SLAT="${LAT::-1}"
SLON="${LON::-1}"
RLAT=$(echo ${LAT} | cut -d '.' -f 1)
RLON=$(echo ${LON} | cut -d '.' -f 1)
##################################################################""
UMAPPATH="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"
## Indicates UMAP HEX to swarm
if [ ! -s ${UMAPPATH}/HEX ]; then
    mkdir -p ${UMAPPATH}
    echo "$UMAPHEX" > ${UMAPPATH}/HEX
fi

# nostr whitelist, Used by NOSTR.UMAP.refresh.sh (completed by NODE.refresh.sh)
if [ ! -s ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX ]; then
    mkdir -p ~/.zen/game/nostr/UMAP_${LAT}_${LON}
    echo "$UMAPHEX" > ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX
fi

##################################################################""
### Extract message
message_text=$(echo "$MESSAGE" | tr '\n' ' ')
#~ echo "Message text from message: '$message_text'"

################################################################### #BRO #BOT
if [[ "$message_text" =~ \#BRO\  || "$message_text" =~ \#BOT\  ]]; then
    #######################################################################
    # Detect slot tag (#1 to #12) for memory context
    slot=0
    for i in {1..12}; do
        if [[ "$message_text" =~ \#${i}\b ]]; then
            slot=$i
            break
        fi
    done
    # Use KNAME (nostr email) if available, else fallback to pubkey
    user_id="$KNAME"
    if [[ -z "$user_id" ]]; then
        user_id="$PUBKEY"
    fi
    
    # Check for #rec2 tag to auto-record bot response
    auto_record_response=false
    if [[ "$message_text" =~ \#rec2 ]]; then
        auto_record_response=true
    fi
    
    # Check for #reset tag to clear user memory
    if [[ "$message_text" =~ \#reset ]]; then
        # Check if reset is for a specific slot
        reset_slot=0
        for i in {1..12}; do
            if [[ "$message_text" =~ \#reset.*\#${i}\b ]]; then
                reset_slot=$i
                break
            fi
        done
        
        # Check if #all is present to reset all slots
        reset_all=false
        if [[ "$message_text" =~ \#all ]]; then
            reset_all=true
        fi
        
        if [[ $reset_slot -gt 0 ]]; then
            # Check memory slot access for reset
            if check_memory_slot_access "$user_id" "$reset_slot"; then
                # Reset specific slot
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
        elif [[ "$reset_all" == true ]]; then
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
    # Check for #mem tag to return memory content
    elif [[ "$message_text" =~ \#mem ]]; then
        # Check if mem is for a specific slot
        mem_slot=0
        for i in {1..12}; do
            if [[ "$message_text" =~ \#mem.*\#${i}\b ]]; then
                mem_slot=$i
                break
            fi
        done
        
        if [[ $mem_slot -gt 0 ]]; then
            # Check memory slot access for display
            if check_memory_slot_access "$user_id" "$mem_slot"; then
                # Show specific slot memory
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
    if [[ ! -z $URL ]]; then
        echo "Looking at the image (using ollama + llava)..."
        DESC="IMAGE : $("$MY_PATH/describe_image.py" "$URL" --json | jq -r '.description')"
    fi

    #######################################################################
    echo "Preparing question for IA..."
    if [[ -n $DESC ]]; then
        QUESTION="[IMAGE received]: $DESC --- $message_text"
    else
        QUESTION="$message_text ---"
    fi


    ##################################################### ASK IA
    ## KNOWN KNAME & CAPTAIN REPLY
    if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ || $KNAME == "CAPTAIN" ]]; then
        # Only generate an answer if KeyANSWER is not already set (e.g., by #reset)
        if [[ -z "$KeyANSWER" ]]; then
            if [[ "$message_text" =~ \#search ]]; then
                # Ensure Perplexica is available
                $MY_PATH/perplexica.me.sh
                ################################################"
                # remove #BRO #search tags from message_text
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#search//g; s/"//g' <<< "$message_text")
                # search = perplexica
                KeyANSWER="$($MY_PATH/perplexica_search.sh "${cleaned_text}")"
                ################################################"
            elif [[ "$message_text" =~ \#image ]]; then
                ################################################
                # remove #BRO #image tags from message_text
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#image//g; s/"//g' <<< "$message_text")
                # Ensure ComfyUI is available
                $MY_PATH/comfyui.me.sh
                # Generate image and measure time
                start_time=$(date +%s.%N)
                IMAGE_URL="$($MY_PATH/generate_image.sh "${cleaned_text}")"
                end_time=$(date +%s.%N)
                execution_time=$(echo "$end_time - $start_time" | bc)
                if [ -n "$IMAGE_URL" ]; then
                    # Get current timestamp
                    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
                    # Format the response with description, timestamp and execution time
                    KeyANSWER=$(echo -e "🖼️ $TIMESTAMP (⏱️ ${execution_time%.*} s)\n📝 Description: $cleaned_text\n🔗 $IMAGE_URL")
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer l'image demandée."
                fi
                ################################################"
            elif [[ "$message_text" =~ \#video ]]; then
                ################################################"
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#video//g; s/"//g' <<< "$message_text")
                # Ensure ComfyUI is available
                $MY_PATH/comfyui.me.sh
                # Generate video using Text2VideoWan2.1 workflow
                VIDEO_AI_RETURN="$($MY_PATH/generate_video.sh "${cleaned_text}" "$MY_PATH/workflow/Text2VideoWan2.1.json")"
                if [ -n "$VIDEO_AI_RETURN" ]; then
                    KeyANSWER="$VIDEO_AI_RETURN"
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer la vidéo demandée."
                fi
                ################################################"
            elif [[ "$message_text" =~ \#music ]]; then
                ################################################"
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#music//g; s/"//g' <<< "$message_text")
                # Ensure ComfyUI is available
                $MY_PATH/comfyui.me.sh
                # Generate music using audio_ace_step_1_t2m workflow
                MUSIC_URL="$($MY_PATH/generate_music.sh "${cleaned_text}")"
                if [ -n "$MUSIC_URL" ]; then
                    KeyANSWER="$MUSIC_URL"
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer la musique demandée."
                fi
                ################################################"
            elif [[ "$message_text" =~ \#youtube ]]; then
                ################################################"
                # Extract YouTube URL from message
                youtube_url=$(echo "$message_text" | grep -oE 'http[s]?://(www\.)?(youtube\.com|youtu\.be)/[^ ]+')
                if [ -z "$youtube_url" ]; then
                    KeyANSWER="Désolé, Aucune URL YouTube valide trouvée dans votre message."
                else
                    # Check if #mp3 tag is present
                    if [[ "$message_text" =~ \#mp3 ]]; then
                        json=$($MY_PATH/process_youtube.sh "$youtube_url" "mp3")
                    else
                        json=$($MY_PATH/process_youtube.sh "$youtube_url" "mp4")
                    fi
                    error=$(echo "$json" | jq -r .error 2>/dev/null)
                    if [[ -n "$error" && "$error" != "null" ]]; then
                        KeyANSWER="Désolé, erreur lors du téléchargement : $error"
                    else
                        ipfs_url=$(echo "$json" | jq -r .ipfs_url)
                        title=$(echo "$json" | jq -r .title)
                        duration=$(echo "$json" | jq -r .duration)
                        uploader=$(echo "$json" | jq -r .uploader)
                        filename=$(echo "$json" | jq -r .filename)
                        original_url=$(echo "$json" | jq -r .original_url)
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
                ################################################"
            elif [[ "$message_text" =~ \#pierre || "$message_text" =~ \#amelie ]]; then
                ################################################"
                # Determine voice based on tag
                if [[ "$message_text" =~ \#pierre ]]; then
                    voice="pierre"
                elif [[ "$message_text" =~ \#amelie ]]; then
                    voice="amelie"
                fi
                
                # Remove tags from message text
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#pierre//g; s/#amelie//g; s/"//g' <<< "$message_text")
                
                echo "Génération de synthèse vocale avec la voix: $voice" >&2
                start_time=$(date +%s.%N)
                audio_url=$($MY_PATH/generate_speech.sh "$cleaned_text" "$voice")
                end_time=$(date +%s.%N)
                execution_time=$(echo "$end_time - $start_time" | bc)
                
                if [ -n "$audio_url" ]; then
                    # Get current timestamp
                    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
                    # Format the response with description, timestamp and execution time
                    KeyANSWER=$(echo -e "🔊 $TIMESTAMP (⏱️ ${execution_time%.*} s)\n👤 Voix: $voice\n📝 Texte: $cleaned_text\n🔗 $audio_url")
                else
                    KeyANSWER="Désolé, je n'ai pas pu générer la synthèse vocale demandée."
                fi
                ################################################"
            else
                ################################################"
                cleaned_text=$(sed 's/#BOT//g; s/#BRO//g; s/#search//g; s/"//g' <<< "$QUESTION")
                # default = ollama (using slot-based memory if available, else PUBKEY MEMORY)
                if [[ -n "$user_id" ]]; then
                    # Check memory slot access for AI question
                    if check_memory_slot_access "$user_id" "$slot"; then
                        KeyANSWER="$($MY_PATH/question.py "${cleaned_text}" --user-id "${user_id}" --slot ${slot})"
                    else
                        echo "Memory access denied for AI question - USER: $user_id, SLOT: $slot"
                        send_memory_access_denied "$PUBKEY" "$EVENT" "$slot"
                        KeyANSWER="Accès refusé au slot $slot pour l'IA. Seuls les sociétaires CopyLaRadio peuvent utiliser les slots 1-12. Utilisez le slot 0 ou devenez sociétaire."
                    fi
                else
                KeyANSWER="$($MY_PATH/question.py "${cleaned_text}" --pubkey ${PUBKEY})"
                fi
                ################################################"
            fi
        fi

        ## LOAD CAPTAIN KEY
        source ~/.zen/game/players/.current/secret.nostr
        # ADD TO CAPTAIN FOLLOW LIST
        ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "$PUBKEY" 2>/dev/null

        ## PREFERED KNAME SELF RESPONSE
        [[ -s ~/.zen/game/nostr/${KNAME}/.secret.nostr ]] \
            && source ~/.zen/game/nostr/${KNAME}/.secret.nostr

        NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC")

        # Clean KeyANSWER of BOT and BRO tags
        KeyANSWER=$(echo "$KeyANSWER" | sed 's/#BOT//g; s/#BRO//g; s/#bot//g; s/#bro//g')

        ## SEND REPLY MESSAGE
        # Détection du mode secret
        SECRET_MODE=false
        if [[ "$8" == "--secret" ]]; then
            SECRET_MODE=true
        fi
        if [[ "$SECRET_MODE" == true ]]; then
            # Envoi en DM NOSTR kind 4 (chiffré) du Capitaine à KNAME
            # KNAME est un email, sa clé hex est dans ~/.zen/game/nostr/{KNAME}/HEX
            if [[ -n "$KNAME" ]]; then
                # Charger la clé privée du Capitaine
                source ~/.zen/game/players/.current/secret.nostr
                NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC")
                
                # Récupérer la clé hex de KNAME
                KNAME_HEX_FILE="$HOME/.zen/game/nostr/$KNAME/HEX"
                if [[ -f "$KNAME_HEX_FILE" ]]; then
                    KNAME_HEX=$(cat "$KNAME_HEX_FILE")
                    echo "[SECRET] Found KNAME hex key: $KNAME_HEX for $KNAME"
                    
                    # En mode secret, l'événement source n'existe pas dans strfry
                    # On envoie un DM simple sans référence à l'événement
                    
                    # Vérifier que KeyANSWER n'est pas vide
                    if [[ -z "$KeyANSWER" ]]; then
                        echo "[SECRET] KeyANSWER is empty, sending fallback message" >&2
                        KeyANSWER="Réponse IA non générée. Erreur technique. $(date '+%Y-%m-%d %H:%M:%S')"
                    fi
                    
                    echo "[SECRET] Sending DM with content: $KeyANSWER" >&2
                    DM_RESULT=$($HOME/.zen/Astroport.ONE/tools/nostr_send_dm.py "$NSEC" "$KNAME_HEX" "$KeyANSWER" "$myRELAY" 2>&1)
                    DM_EXIT_CODE=$?
                    
                    if [[ $DM_EXIT_CODE -eq 0 ]]; then
                        echo "[SECRET] Private DM sent successfully to $KNAME ($KNAME_HEX) via NOSTR relay (event not stored in strfry)." >&2
                    else
                        echo "[SECRET] Failed to send DM. Exit code: $DM_EXIT_CODE" >&2
                        echo "[SECRET] DM error output: $DM_RESULT" >&2
                        # Fallback: send a simple timestamp message to indicate failure
                        FALLBACK_MSG="Message privé non envoyé. Erreur technique. $(date '+%Y-%m-%d %H:%M:%S')"
                        $HOME/.zen/Astroport.ONE/tools/nostr_send_dm.py "$NSEC" "$KNAME_HEX" "$FALLBACK_MSG" "$myRELAY" >/dev/null 2>&1
                    fi
                else
                    echo "[SECRET] KNAME hex key not found at $KNAME_HEX_FILE, cannot send DM."
                fi
            else
                echo "[SECRET] KNAME not set, cannot send DM."
            fi
        else
            # Envoi public classique avec référence à l'événement source
        nostpy-cli send_event \
          -privkey "$NPRIV_HEX" \
          -kind 1 \
          -content "$KeyANSWER" \
          -tags "[['e', '$EVENT'], ['p', '$PUBKEY']]" \
          --relay "$myRELAY"
        fi
        
        ## AUTO-RECORD BOT RESPONSE if #rec2 is present
        if [[ "$auto_record_response" == true ]]; then
            # Check memory slot access for auto-recording
            if check_memory_slot_access "$user_id" "$slot"; then
                echo "Auto-recording bot response for USER: $user_id, SLOT: $slot"
                # Create a fake event JSON for the bot response
                # En mode secret, utiliser un ID différent pour éviter les conflits
                if [[ "$SECRET_MODE" == true ]]; then
                    bot_event_json='{"event":{"id":"secret_bot_response_'$(date +%s)'","content":"'"$KeyANSWER"'","pubkey":"'"$UMAPHEX"'","created_at":'$(date +%s)'}}'
                else
                    bot_event_json='{"event":{"id":"bot_response_'$(date +%s)'","content":"'"$KeyANSWER"'","pubkey":"'"$UMAPHEX"'","created_at":'$(date +%s)'}}'
                fi
                $MY_PATH/short_memory.py "$bot_event_json" "$LAT" "$LON" "$slot" "$user_id"
            else
                echo "Memory access denied for auto-recording - USER: $user_id, SLOT: $slot"
                if [[ "$SECRET_MODE" == true ]]; then
                    # En mode secret, ne pas envoyer de message d'erreur public
                    echo "[SECRET] Memory access denied for auto-recording, but not sending public error message."
                else
                    send_memory_access_denied "$PUBKEY" "$EVENT" "$slot"
                fi
            fi
        fi
        #######################################################################

    fi
    #######################################################################
fi
#######################################################################

#######################################################################
echo ""
echo "--- Summary ---"
echo "PUBKEY: $PUBKEY"
echo "EVENT: $EVENT"
echo "LAT: $LAT"
echo "LON: $LON"
echo "Message: $message_text"
echo "Image: $DESC"
echo "Question: $QUESTION"
echo "Answer: $ANSWER"
echo "---------------"

exit 0
