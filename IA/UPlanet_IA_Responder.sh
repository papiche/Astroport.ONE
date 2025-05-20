#!/bin/bash
###################################################################
# UPlanet_IA_Responder.sh
# Script de réponse IA pour UPlanet
#
# Usage: $0 "$pubkey" "$event_id" "$latitude" "$longitude" "$content" "$url"
#
# Fonctionnalités:
# - Analyse des messages et médias reçus via UPlanet
# - Détection automatique des types de médias (#audio, #video, etc.)
# - Traitement des médias (conversion, téléchargement, stockage IPFS)
# - Génération de réponses IA via Ollama
# - Publication des réponses sur:
#   * La GeoKey UPlanet UMAP correspondante
#   * La clé NOSTR du Capitaine (pour les visiteurs)
#
# Tags spéciaux:
# - #BOT : Active la réponse IA
# - #audio/#video : Spécifie le type de média
###################################################################
PUBKEY="$1"
EVENT="$2"
LAT="$3"
LON="$4"
MESSAGE="$5"
URL="$6"
KNAME="$7"

# Configuration des logs
LOG_FILE="${HOME}/.zen/tmp/IA.log"
LOG_DIR=$(dirname "$LOG_FILE")
mkdir -p "$LOG_DIR"

# Fonction de log
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE"
    echo "[$timestamp] $1"
}

# Gestion des erreurs
set -e
trap 'log "ERROR: Command failed at line $LINENO"' ERR

# Vérification des dépendances
check_dependencies() {
    local deps=("yt-dlp" "jq" "detox" "ipfs")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "ERROR: Required dependency '$dep' is not installed"
            exit 1
        fi
    done
}

# Vérification de l'environnement
check_environment() {
    if [[ ! -s ~/.zen/Astroport.ONE/tools/my.sh ]]; then
        log "ERROR: Astroport.ONE is missing!"
        exit 1
    fi
}

# Initialisation
MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"
exec 2>&1 >> "$LOG_FILE"

log "Starting UPlanet_IA_Responder.sh $KNAME"
check_dependencies
check_environment
source ~/.zen/Astroport.ONE/tools/my.sh

## Maintain Ollama
$MY_PATH/ollama.me.sh

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
  echo "  Ollama response, and publish it on Captain NOSTR key."
  echo ""
  echo "Example:"
  echo "  $(basename "$0") pubkey_hex 0.00 0.00 \"What is it\" https://ipfs.copylaradio.com/ipfs/QmeUMJvPdyPiteR7iQXCnZy4mvKBnghNkYpMTbrpZfMGPq/pipe.jpeg"
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
    ANYURL=$(echo "$MESSAGE" | grep -oE 'https?://[^ ]+' | head -n 1)
fi

echo "Received parameters:"
echo "  PUBKEY: $PUBKEY"
echo "  EVENT: $EVENT"
echo "  LAT: $LAT"
echo "  LON: $LON"
echo "  MESSAGE: $MESSAGE"
echo "  URL: $URL"
echo "  ANYURL: $ANYURL"
echo "  KNAME: $KNAME"
echo ""

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
if [[ -n $KNAME && -d ~/.zen/game/nostr/$KNAME ]]; then
    if [[ $LAT == "0.00" && $LON == "0.00" ]]; then
        ## source NOSTR Card LAT=?;LON=?;
        [[ -s ${HOME}/.zen/game/nostr/${KNAME}/GPS ]] \
            && source ${HOME}/.zen/game/nostr/${KNAME}/GPS
        ## Check SWARM account
        isInSwarmGPS=$(ls ${HOME}/.zen/tmp/swarm/*/TW/${KNAME}/GPS | head -n 1 2>/dev/null)
        [[ -n  ${isInSwarmGPS} ]] \
            && source ${isInSwarmGPS}
    fi
fi

## CHECK if $UMAPNPUB = $PUBKEY Then DO not reply
UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
UMAPHEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNPUB")
[[ $PUBKEY == $UMAPHEX ]] && exit 0

##################################################################""
## Inform Swarm cache (UPLANET.refresh.sh)
SLAT="${LAT::-1}"
SLON="${LON::-1}"
RLAT=$(echo ${LAT} | cut -d '.' -f 1)
RLON=$(echo ${LON} | cut -d '.' -f 1)
UMAPPATH="${HOME}/.zen/tmp/${IPFSNODEID}/UPLANET/__/_${RLAT}_${RLON}/_${SLAT}_${SLON}/_${LAT}_${LON}"
if [ ! -s ${UMAPPATH}/HEX ]; then
    mkdir -p ${UMAPPATH}
    echo "$UMAPHEX" > ${UMAPPATH}/HEX
fi

##################################################################""
## Indicates UMAP is publishing (nostr whitelist), Used by NOSTR.UMAP.refresh.sh
if [ ! -s ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX ]; then
    mkdir -p ~/.zen/game/nostr/UMAP_${LAT}_${LON}
    echo "$UMAPHEX" > ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX
fi

##################################################################""
### Extract message
message_text=$(echo "$MESSAGE" | tr '\n' ' ')

# Check for #BOT tag
if [[ ! "$message_text" =~ \#BOT ]]; then
    log "No #BOT tag found, skipping AI response"
    # UMAP follow and memorize
    if [[ $KNAME != "CAPTAIN" ]]; then
        UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
        ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY"
    fi
    exit 0
fi

# Fonction pour extraire l'URL du message
extract_url() {
    local message="$1"
    local url=""
    
    # Essayer d'abord les images
    url=$(echo "$message" | grep -oE 'http[s]?://[^ ]+\.(png|gif|jpg|jpeg)' | head -n 1)
    
    # Si pas d'image, chercher n'importe quelle URL
    if [[ -z "$url" ]]; then
        url=$(echo "$message" | grep -oE 'https?://[^ ]+' | head -n 1)
    fi
    
    echo "$url"
}

# Fonction pour détecter le type de média
detect_media_type() {
    local message="$1"
    local media_type=""
    
    if [[ "$message" =~ \#(mp3|MP3|mp4|MP4) ]]; then
        media_type=$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
    fi
    
    echo "$media_type"
}

# Fonction pour télécharger et traiter les médias
process_media() {
    local url="$1"
    local media_type="$2"
    local temp_dir="$3"
    local browser="$4"
    
    local media_file=""
    local media_ipfs=""
    
    # Obtenir le titre
    local line=""
    if [[ -n "$browser" ]]; then
        line="$(yt-dlp $browser --print "%(id)s&%(title)s" "$url" 2>/dev/null)"
        if [[ $? -ne 0 ]]; then
            log "Warning: Failed to get video info with browser cookies, trying without"
            line="$(yt-dlp --print "%(id)s&%(title)s" "$url" 2>/dev/null)"
        fi
    else
        line="$(yt-dlp --print "%(id)s&%(title)s" "$url" 2>/dev/null)"
    fi
    
    local yid=$(echo "$line" | cut -d '&' -f 1)
    local media_title=$(echo "$line" | cut -d '&' -f 2- | detox --inline)
    [[ -z "$media_title" ]] && media_title="media-$(date +%s)"
    
    # Télécharger selon le type
    case "$media_type" in
        mp3)
            log "Downloading and converting to MP3..."
            yt-dlp $browser -x --audio-format mp3 --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url"
            ;;
        mp4)
            log "Downloading and converting to MP4..."
            yt-dlp $browser -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
                --no-mtime --embed-thumbnail --add-metadata \
                -o "${temp_dir}/${media_title}.%(ext)s" "$url"
            ;;
    esac
    
    # Trouver le fichier téléchargé
    media_file=$(ls "$temp_dir"/${media_title}.* 2>/dev/null | head -n 1)
    
    if [[ -n "$media_file" ]]; then
        # Ajouter à IPFS
        media_ipfs=$(ipfs add -wq "$media_file" 2>/dev/null | tail -n 1)
        if [[ -n "$media_ipfs" ]]; then
            echo "$myIPFS/ipfs/$media_ipfs/$media_title.$media_type"
        fi
    fi
}

# Extract media type and URL
MEDIA_TYPE=$(detect_media_type "$message_text")
if [[ -z "$URL" ]]; then
    URL=$(extract_url "$message_text")
    ANYURL="$URL"
fi

if [[ -n "$MEDIA_TYPE" ]]; then
    log "Detected media type: $MEDIA_TYPE"
fi

#######################################################################
if [[ ! -z $URL ]]; then
    echo "Looking at the image (using ollama + llava)..."
    DESC="IMAGE : $("$MY_PATH/describe_image.py" "$URL" --json | jq -r '.description')"
fi

#######################################################################
# Fonction pour préparer la question pour l'IA
prepare_question() {
    local message="$1"
    local image_desc="$2"
    
    if [[ -n "$image_desc" ]]; then
        echo "[IMAGE]: $image_desc + [MESSAGE]: $message --- ## Comment [IMAGE] description ## Make a short answer about [MESSAGE] # ANWSER USING THE SAME LANGUAGE"
    else
        echo "$message. # ANWSER USING THE SAME LANGUAGE"
    fi
}

# Fonction pour envoyer la réponse NOSTR
send_nostr_reply() {
    local event_id="$1"
    local pubkey="$2"
    local content="$3"
    local nsec="$4"
    
    local NOSTPY_CLI_PATH="$HOME/.astro/bin/nostpy-cli"

    # Vérifier si nostpy-cli est disponible au chemin spécifié
    if [[ ! -x "$NOSTPY_CLI_PATH" ]]; then
        log "ERROR: nostpy-cli not found or not executable at $NOSTPY_CLI_PATH, skipping NOSTR reply"
        return 1
    fi
    
    # Vérifier les paramètres requis
    if [[ -z "$event_id" || -z "$pubkey" || -z "$content" || -z "$nsec" ]]; then
        log "ERROR: Missing required parameters for NOSTR reply"
        return 1
    fi
    
    # Vérifier le relay
    if [[ -z "$myRELAY" ]]; then
        log "ERROR: NOSTR relay not configured"
        return 1
    }
    
    local npriv_hex=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$nsec")
    if [[ -z "$npriv_hex" ]]; then
        log "ERROR: Failed to convert NSEC to hex"
        return 1
    fi
    
    log "Attempting to send NOSTR reply to event $event_id using $NOSTPY_CLI_PATH..."
    
    # Exécuter la commande et capturer la sortie d'erreur
    local nostr_output=$("$NOSTPY_CLI_PATH" send_event \
        -privkey "$npriv_hex" \
        -kind 1 \
        -content "$content" \
        -tags "[['e', '$event_id'], ['p', '$pubkey']]" \
        --relay "$myRELAY" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        log "ERROR: nostpy-cli command failed with exit code $exit_code"
        log "nostpy-cli output: $nostr_output"
        return 1
    fi
    
    log "NOSTR reply sent successfully"
    # Optionally log successful output as well
    # log "nostpy-cli output: $nostr_output"
    return 0
}

#######################################################################
# QUESTION prepare with image description if present
QUESTION=$(prepare_question "$message_text" "$DESC")

## UMAP FOLLOW NOSTR CARD IF NOT CAPTAIN
if [[ $KNAME != "CAPTAIN" ]]; then
    UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
    #######################################################################
    # UMAP FOLLOW PUBKEY -> Used nightly to create Journal "NOSTR.UMAP.refresh.sh"
    ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY"
    #######################################################################
    #######################################################################
fi

#######################################################################
#######################################################################
## KNOWN KNAME => CAPTAIN REPLY
if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    ## CAPTAIN ANSWER USING PUBKEY MEMORY
    log "Generating Ollama answer..."
    KeyANSWER=$($MY_PATH/question.py "${QUESTION} # NB: REPLY IN TEXT ONLY = DO NOT USE MARKDOWN STYLE !" --pubkey ${PUBKEY})
    
    if [[ -z "$KeyANSWER" ]]; then
        log "ERROR: Failed to generate AI response"
        exit 1
    fi
    
    # If media type detected, and ANYURL is present, process it
    if [[ -n "$MEDIA_TYPE" && -n "$ANYURL" ]]; then
        log "Processing media type: $MEDIA_TYPE"
        # Create temporary directory for media processing
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        BZER=$(xdg-settings get default-web-browser | cut -d '.' -f 1 | cut -d '-' -f 1 | cut -d '_' -f 1)
        if [[ -n "$BZER" ]]; then
            BROWSER="--cookies-from-browser $BZER"
        else
            BROWSER=""
            log "Warning: No Browser found"
        fi

        # Process media and get IPFS link
        MEDIA_IPFS_LINK=$(process_media "$ANYURL" "$MEDIA_TYPE" "$TEMP_DIR" "$BROWSER")
        if [[ -n "$MEDIA_IPFS_LINK" ]]; then
            KeyANSWER="$KeyANSWER\n\n $MEDIA_IPFS_LINK"
        fi

        # Cleanup
        cd - >/dev/null
        rm -rf "$TEMP_DIR"
    fi
    
    source ~/.zen/game/players/.current/secret.nostr ## SET CAPTAIN ID
    if ! send_nostr_reply "$EVENT" "$PUBKEY" "$KeyANSWER" "$NSEC"; then
        log "WARNING: Failed to send NOSTR reply, but continuing execution"
    fi
    
    #######################################################################
    # ADD TO FOLLOW LIST
    ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "$PUBKEY"
fi
#######################################################################
#######################################################################

#######################################################################
log "--- Summary ---"
log "PUBKEY: $PUBKEY"
log "EVENT: $EVENT"
log "LAT: $LAT"
log "LON: $LON"
log "Message: $message_text"
log "Image: $DESC"
log "Media Type: $MEDIA_TYPE"
log "---------------"
log "UMAP_${LAT}_${LON} Answer: $ANSWER"

exit 0
