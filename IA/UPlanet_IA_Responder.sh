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
    # Check for #reset tag to clear user memory
    if [[ "$message_text" =~ \#reset ]]; then
        memory_file="$HOME/.zen/strfry/uplanet_memory/pubkey/$PUBKEY.json"
        if [[ -f "$memory_file" ]]; then
            rm -f "$memory_file"
            echo "Memory reset for PUBKEY: $PUBKEY"
            KeyANSWER="Bonjour, je suis ASTROBOT votre assistant personnel IA programmable. Faites appel à moi en utlisant le tag \"BRO\" ou \"BOT\" suivi de votre question et des tags : #search pour lancer une recherche sur internet, #image pour générer une image, #music pour générer une musique, #parole pour ajouter des paroles, #mem pour afficher notre conversation, #reset pour reinitialiser la mémoire."
        else
            echo "No memory file found for PUBKEY: $PUBKEY"
            KeyANSWER="Pas de mémoire existante trouvée."
        fi
    # Check for #mem tag to return memory content
    elif [[ "$message_text" =~ \#mem ]]; then
        memory_file="$HOME/.zen/strfry/uplanet_memory/pubkey/$PUBKEY.json"
        if [[ -f "$memory_file" ]]; then
            echo "Returning memory content for PUBKEY: $PUBKEY"
            # Créer un fichier temporaire pour le formatage
            temp_mem_file="$HOME/.zen/tmp/memory_${PUBKEY}.txt"

            # Extraire et formater les messages
            echo "📝 Historique (#mem)" > "$temp_mem_file" # Add #mem to bypass memory recording (NIP101 : 1.sh)
            echo "========================" >> "$temp_mem_file"

            # Utiliser jq pour extraire et formater les messages avec date et localisation
            jq -r '.messages | to_entries | .[-30:] | .[] | "📅 \(.value.timestamp | sub("\\.[0-9]+Z$"; "Z") | strptime("%Y-%m-%dT%H:%M:%SZ") | strftime("%d/%m/%Y %H:%M"))\n💬 \(.value.content | sub("#BOT "; "") | sub("#BRO "; "") | sub("#bot "; "") | sub("#bro "; ""))\n---"' "$memory_file" >> "$temp_mem_file"

            # Lire le fichier formaté
            KeyANSWER=$(cat "$temp_mem_file")

            # Nettoyer le fichier temporaire
            rm -f "$temp_mem_file"
        else
            echo "No memory file found for PUBKEY: $PUBKEY"
            KeyANSWER="Aucune (#mem) trouvée."
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
                        echo "Téléchargement et conversion en MP3..." >&2
                        media_url=$($MY_PATH/process_youtube.sh "$youtube_url" "mp3")
                    else
                        echo "Téléchargement en MP4 (720p max)..." >&2
                        media_url=$($MY_PATH/process_youtube.sh "$youtube_url" "mp4")
                    fi

                    if [ -n "$media_url" ]; then
                        KeyANSWER="$media_url"
                    else
                        KeyANSWER="Désolé, je n'ai pas pu télécharger la vidéo YouTube."
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
                # default = ollama (using PUBKEY MEMORY)
                KeyANSWER="$($MY_PATH/question.py "${cleaned_text}" --pubkey ${PUBKEY})"
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
        nostpy-cli send_event \
          -privkey "$NPRIV_HEX" \
          -kind 1 \
          -content "$KeyANSWER" \
          -tags "[['e', '$EVENT'], ['p', '$PUBKEY']]" \
          --relay "$myRELAY"
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
