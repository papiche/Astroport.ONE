#!/bin/bash
###################################################################
# IA_UPlanet.sh "$pubkey" "$event_id" "$latitude" "$longitude" "$content" "$url"
# Analyse du message et de l'image (url) Uplanet reçu
# Publie la réponse Ollama sur la GeoKey UPlanet UMAP 0.01
# et depuis la clef NOSTR du Capitaine pour les visiteurs
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

## If No URL : Getting URL from message content
if [ -z "$URL" ]; then
    # Extraire le premier lien .png ou .jpg de MESSAGE
    URL=$(echo "$MESSAGE" | grep -oE 'http[s]?://[^ ]+\.(png|jpg|jpeg)' | head -n 1)
fi

echo "Received parameters:"
echo "  PUBKEY: $PUBKEY"
echo "  EVENT: $EVENT"
echo "  LAT: $LAT"
echo "  LON: $LON"
echo "  MESSAGE: $MESSAGE"
echo "  URL: $URL"
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
message_text=$(echo "$MESSAGE" | sed 's/\n.*//')
#~ echo "Message text from message: '$message_text'"

#######################################################################
if [[ ! -z $URL ]]; then
    echo "Looking at the image (using ollama + llava)..."
    DESC="IMAGE : $("$MY_PATH/describe_image.py" "$URL" --json | jq -r '.description')"
fi

#######################################################################
echo "Generating Ollama answer..."
if [[ -n $DESC ]]; then
    QUESTION="[IMAGE]: $DESC + [MESSAGE]: $message_text ---# You are ASTROBOT_${LAT}_${LON}, in charge of a Geo Spatial Database called UPlanet your mission is to : ## Record any message ## Determine classification ## Analyse subject ## Make a short answer."
else
    QUESTION="Answer to this message: $message_text. Sign as ASTROBOT_${LAT}_${LON}."
fi

## NO CONTEXT
#~ ONSWER=$($MY_PATH/question.py "${QUESTION}")
## USER CONTEXT
ANSWER=$($MY_PATH/question.py "${QUESTION}" --pubkey ${PUBKEY})
if [[ $LAT != "0.00" && $LON != "0.00" ]]; then
    ## UMAP CONTEXT
    GEOANSWER=$($MY_PATH/question.py "${QUESTION}" --lat "${LAT}" --lon "${LON}")
    ANSWER="$ANSWER //Ƹ̵̡Ӝ̵̨̄Ʒ// $GEOANSWER"
fi
#######################################################################
#######################################################################

#######################################################################
#~ echo "Creating GEO Key NOSTR secret..."
UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)

if [[ -z "$UMAPNSEC" ]]; then
  echo "Error: Failed to generate NOSTR key."
  exit 1
fi

#######################################################################
#~ echo "Converting NSEC to HEX for nostpy-cli..."
NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")
if [[ -z "$NPRIV_HEX" ]]; then
  echo "Error: Failed to convert NSEC to HEX."
  exit 1
fi

#######################################################################
#######################################################################
# SEND IA RESPONSE
#######################################################################
#~ echo "Sending IA ANSWER"

nostpy-cli send_event \
  -privkey "$NPRIV_HEX" \
  -kind 1 \
  -content "$ANSWER" \
  -tags "[['e', '$EVENT'], ['p', '$PUBKEY']]" \
  --relay "$myRELAY"

#######################################################################
# ADD TO FOLLOW LIST
${MY_PATH}/../tools/nostr_follow.sh "$UMAPNSEC" "$PUBKEY"

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
