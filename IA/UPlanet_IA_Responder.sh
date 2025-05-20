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
# - #BOT : Active la réponse IA (par défaut)
# - #search : Perplexica Search
# - #mp3 : Convertir en MP3
# - #mp4 : Convertir en MP4
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
  echo "  Ollama response, and publish it on UPlanet Captain NOSTR key."
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

## Getting KNAME default localisation
if [[ -n $KNAME && -d ~/.zen/game/nostr/$KNAME ]]; then
    if [[ $LAT == "0.00" && $LON == "0.00" ]]; then
        ## Check SWARM account
        isInSwarmGPS=$(ls ${HOME}/.zen/tmp/swarm/*/TW/${KNAME}/GPS)
        [[ -n  ${isInSwarmGPS} ]] \
            && source ${isInSwarmGPS}

        ## source NOSTR Card LAT=?;LON=?;
        [[ -s ${HOME}/.zen/game/nostr/${KNAME}/GPS ]] \
            && source ${HOME}/.zen/game/nostr/${KNAME}/GPS

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
##################################################################""
## Indicates UMAP to swarm 
if [ ! -s ${UMAPPATH}/HEX ]; then
    mkdir -p ${UMAPPATH}
    echo "$UMAPHEX" > ${UMAPPATH}/HEX
fi
# nostr whitelist, Used by NOSTR.UMAP.refresh.sh
if [ ! -s ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX ]; then
    mkdir -p ~/.zen/game/nostr/UMAP_${LAT}_${LON}
    echo "$UMAPHEX" > ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX
fi

##################################################################""
### Extract message
message_text=$(echo "$MESSAGE" | tr '\n' ' ')
#~ echo "Message text from message: '$message_text'"

################################################################### #BOT
if [[ "$message_text" =~ \#BOT ]]; then
    #######################################################################
    if [[ ! -z $URL ]]; then
        echo "Looking at the image (using ollama + llava)..."
        DESC="IMAGE : $("$MY_PATH/describe_image.py" "$URL" --json | jq -r '.description')"
    fi
    #######################################################################
    echo "Generating Ollama answer..."
    if [[ -n $DESC ]]; then
        QUESTION="[IMAGE]: $DESC + [MESSAGE]: $message_text  --- ## Comment [IMAGE] description ## Make a short answer about [MESSAGE] # ANWSER USING THE SAME LANGUAGE"
    else
        QUESTION="$message_text. --- # ANWSER USING THE SAME LANGUAGE"
    fi

    ## UMAP FOLLOW NOSTR CARD
    if [[ $KNAME != "CAPTAIN" ]]; then
        UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
        #######################################################################
        # UMAP FOLLOW PUBKEY -> Used nightly to create Journal "NOSTR.UMAP.refresh.sh"
        ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY"
        #######################################################################
        #######################################################################
    fi

    ##################################################### ASK IA
    ## KNOWN KNAME => CAPTAIN REPLY
    if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        ## CAPTAIN ANSWSER USING PUBKEY MEMORY
        if [[ "$message_text" =~ \#search ]]; then
            KeyANSWER=$($MY_PATH/perplexica_search.py "${QUESTION} # NB: REPLY IN TEXT ONLY ! DO NOT USE HTML or MARKDOWN STYLE !" --pubkey ${PUBKEY})
        else
            KeyANSWER=$($MY_PATH/question.py "${QUESTION} # NB: REPLY IN TEXT ONLY = DO NOT USE MARKDOWN STYLE !" --pubkey ${PUBKEY})
        fi
        source ~/.zen/game/players/.current/secret.nostr ## SET CAPTAIN ID
        NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$NSEC")
        nostpy-cli send_event \
          -privkey "$NPRIV_HEX" \
          -kind 1 \
          -content "$KeyANSWER" \
          -tags "[['e', '$EVENT'], ['p', '$PUBKEY']]" \
          --relay "$myRELAY"
        #######################################################################
        # ADD TO CAPTAIN FOLLOW LIST
        ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "$PUBKEY"
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
echo "---------------"
echo "UMAP_${LAT}_${LON} Answer: $ANSWER"

exit 0
