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
  echo "  Ollama response, and publish it on UPlanet Geo NOSTR key."
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

PUBKEY="$1"
EVENT="$2"
LAT="$3"
LON="$4"
MESSAGE="$5"
URL="$6"
KNAME="$7"

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
        [[ -s ${HOME}/.zen/game/nostr/${EMAIL}/GPS ]] \
            && source ${HOME}/.zen/game/nostr/${EMAIL}/GPS
        ## Check SWARM account
        isInSwarmGPS=$(ls ${HOME}/.zen/tmp/swarm/*/TW/${EMAIL}/GPS)
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
    echo "No #BOT tag found, skipping AI response"
    # UMAP follow and memorize
    if [[ $KNAME != "CAPTAIN" ]]; then
        UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)
        ${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY"
    fi

    exit 0
fi

# Extract media type from message if present (case insensitive)
MEDIA_TYPE=""
if [[ "$message_text" =~ \#(mp3|MP3|mp4|MP4) ]]; then
    # Convert to upper for consistency
    MEDIA_TYPE=$(echo "${BASH_REMATCH[1]}" | tr '[:upper:]' '[:lower:]')
    echo "Detected media type: $MEDIA_TYPE"
fi

#######################################################################
if [[ ! -z $URL ]]; then
    echo "Looking at the image (using ollama + llava)..."
    DESC="IMAGE : $("$MY_PATH/describe_image.py" "$URL" --json | jq -r '.description')"
fi

#######################################################################
echo "Generating Ollama answer..."
if [[ -n $DESC ]]; then
    QUESTION="[IMAGE]: $DESC + [MESSAGE]: $message_text --- ## Determine Image classification ## Analyse subject ## Make a short answer in plain text # DO NOT USE MARKDOWN STYLE"
else
    QUESTION="$message_text. # ANWSER USING THE SAME LANGUAGE"
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

#######################################################################
#######################################################################
## KNOWN KNAME => CAPTAIN REPLY
if [[ $KNAME =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    ## CAPTAIN ANSWSER USING PUBKEY MEMORY
    KeyANSWER=$($MY_PATH/question.py "${QUESTION} # ANWSER USING THE SAME LANGUAGE # Add CAPTAIN signature" --pubkey ${PUBKEY})
    
    # If media type detected, process it
    if [[ -n "$MEDIA_TYPE" && -n "$ANYURL" ]]; then
        echo "Processing media type: $MEDIA_TYPE"
        # Create temporary directory for media processing
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        
        BZER=$(xdg-settings get default-web-browser | cut -d '.' -f 1 | cut -d '-' -f 1 | cut -d '_' -f 1)
        if [[ -n "$BZER" ]]; then
            BROWSER="--cookies-from-browser $BZER"
        else
            BROWSER=""
            echo "Warning: No Browser found"
        fi

        if [[ -n $BROWSER ]]; then
            # Get title from URL using yt-dlp
            LINE="$(yt-dlp $BROWSER --print "%(id)s&%(title)s" "${ANYURL}" 2>/dev/null)"
            if [[ $? -ne 0 ]]; then
            echo "Warning: Failed to get video info, using fallback method"
            LINE="$(yt-dlp --print "%(id)s&%(title)s" "${ANYURL}" 2>/dev/null)"
            YID=$(echo "$LINE" | cut -d '&' -f 1)
            MEDIA_TITLE=$(echo "$LINE" | cut -d '&' -f 2- | detox --inline)
            # If no title found, use timestamp
            [[ -z "$MEDIA_TITLE" ]] && MEDIA_TITLE="media-$(date +%s)"
            # Download and process media based on type
            case "$MEDIA_TYPE" in
                mp3)
                    echo "Downloading and converting to MP3..."
                    yt-dlp $BROWSER -x --audio-format mp3 --no-mtime --embed-thumbnail --add-metadata \
                        -o "${MEDIA_TITLE}.%(ext)s" "$ANYURL"
                    ;;
                mp4)
                    echo "Downloading and converting to MP4..."
                    yt-dlp $BROWSER -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" \
                        --no-mtime --embed-thumbnail --add-metadata \
                        -o "${MEDIA_TITLE}.%(ext)s" "$ANYURL"
                    ;;
            esac
            
            # Get the downloaded file
            MEDIA_FILE=$(ls "$TEMP_DIR"/${MEDIA_TITLE}.* 2>/dev/null | head -n 1)
            
            if [[ -n "$MEDIA_FILE" ]]; then
                # Add to IPFS
                MEDIA_IPFS=$(ipfs add -wq "$MEDIA_FILE" 2>/dev/null | tail -n 1)
                if [[ -n "$MEDIA_IPFS" ]]; then
                    KeyANSWER="$KeyANSWER\n\n $myIPFS/ipfs/$MEDIA_IPFS/$MEDIA_TITLE.$MEDIA_TYPE"
                fi
            fi
        fi
 
        # Cleanup
        cd - >/dev/null
        rm -rf "$TEMP_DIR"
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
    # ADD TO FOLLOW LIST
    ${MY_PATH}/../tools/nostr_follow.sh "$NSEC" "$PUBKEY"
fi
#######################################################################
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
echo "Media Type: $MEDIA_TYPE"
echo "---------------"
echo "UMAP_${LAT}_${LON} Answer: $ANSWER"

exit 0
