#!/bin/bash
# IA_UPlanet.sh "$pubkey" "$event_id" "$latitude" "$longitude" "$content" "$url"
# Analyse du message et de l'image Uplanet reçu
# Publie la réponse Ollama sur la GeoKey UPlanet 0.01 et 0.1
# et sur la clef NOSTR du Capitaine ?

MY_PATH="$(dirname "$0")"
MY_PATH="$( cd "$MY_PATH" && pwd )"

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
  echo "  $(basename "$0") pubkey_hex 0.00 0.00 \"What is it\" https://ipfs.copylaradio.com/ipfs//ipfs/QmeUMJvPdyPiteR7iQXCnZy4mvKBnghNkYpMTbrpZfMGPq/pipe.jpeg"
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


## Record KNAME localisation
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
## Indicates UMAP is publishing (nostr whitelist), Used by NOSTR.GEO.refresh.sh
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
    QUESTON="IMAGE: $DESC ([MESSAGE]: $message_text) --- Write (in [MESSAGE] language) then IMAGE description. Answer to MESSAGE. Sign 'ASTROBOT'."
else
    QUESTON="Reply to MESSAGE: $message_text. Sign as ASTROBOT."
fi
ANSWER=$($MY_PATH/question.py "${QUESTON}")
#######################################################################
#~ echo "Ollama answer generated."
#~ echo "ANSWER: $ANSWER"

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
