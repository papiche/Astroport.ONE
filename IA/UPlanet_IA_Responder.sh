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
if [[ $# -lt 6 ]]; then
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

echo "Received parameters:"
echo "  PUBKEY: $PUBKEY"
echo "  EVENT: $EVENT"
echo "  LAT: $LAT"
echo "  LON: $LON"
echo "  MESSAGE: $MESSAGE"
echo "  URL: $URL"
echo "  KNAME: $KNAME"
echo ""

## If No URL : Getting URL from message content
if [ -z "$URL" ]; then
    # Extraire le premier lien .png ou .jpg de MESSAGE
    URL=$(echo "$MESSAGE" | grep -oE 'http[s]?://[^ ]+\.(png|jpg)' | head -n 1)
fi

## CHECK if $UMAPNPUB = $PUBKEY Then DO not reply
UMAPNPUB=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}")
UMAPHEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNPUB")
[[ $PUBKEY == $UMAPHEX ]] && exit 0

##################################################################""
## Authorize UMAP to publish (nostr whitelist), Used by NOSTR.GEO.refresh.sh
mkdir -p ~/.zen/game/nostr/UMAP_${LAT}_${LON}
if [ "$(cat ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX 2>/dev/null)" != "$UMAPHEX" ]; then
  echo "$UMAPHEX" > ~/.zen/game/nostr/UMAP_${LAT}_${LON}/HEX
fi
##################################################################""

### Extract message
message_text=$(echo "$MESSAGE" | sed 's/\n.*//')
echo "Message text from message: '$message_text'"

#######################################################################
if [[ ! -z $URL ]]; then
    echo "Looking at the image (using ollama + llava)..."
    DESC="IMAGE : $("$MY_PATH/describe_image.py" "$URL" --json | jq -r '.description')"
fi

#######################################################################
echo "Generating Ollama answer..."
ANSWER=$($MY_PATH/question.py "$DESC + MESSAGE : $message_text (reformulate or reply if any question is asked, always using the same language as MESSAGE). Sign as ASTROBOT :")

if [[ -z "$ANSWER" ]]; then
  echo "Error: Failed to get answer from question.py"
  exit 1
fi
echo "Ollama answer generated."
echo "ANSWER: $ANSWER"

#######################################################################
echo "Creating GEO Key NOSTR secret..."
UMAPNSEC=$($HOME/.zen/Astroport.ONE/tools/keygen -t nostr "${UPLANETNAME}${LAT}" "${UPLANETNAME}${LON}" -s)

if [[ -z "$UMAPNSEC" ]]; then
  echo "Error: Failed to generate NOSTR key."
  exit 1
fi

## Write nostr message
echo "Sending NOSTR message... copying to IPFS Vault ! DEBUG !! "
if [[ ! -z $KNAME ]]; then
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N") && mkdir -p ~/.zen/game/nostr/$KNAME/MESSAGE
    echo "$ANSWER\nASTROBOT_$LAT_$LON\n$URL" > ~/.zen/game/nostr/$KNAME/MESSAGE/$MOATS.txt ## to IPFS (with NOSTR.refresh.sh)
    echo "LAT=$LAT; LON=$LON" > ~/.zen/game/nostr/$KNAME/UMAP
fi

#######################################################################
echo "Converting NSEC to HEX for nostpy-cli..."
NPRIV_HEX=$($HOME/.zen/Astroport.ONE/tools/nostr2hex.py "$UMAPNSEC")
if [[ -z "$NPRIV_HEX" ]]; then
  echo "Error: Failed to convert NSEC to HEX."
  exit 1
fi
echo "NSEC converted to HEX."

#######################################################################
#######################################################################
# SEND IA RESPONSE
#######################################################################
echo "Sending IA ANSWER"

nostpy-cli send_event \
  -privkey "$NPRIV_HEX" \
  -kind 1 \
  -content "$ANSWER" \
  -tags "[['e', '$EVENT'], ['p', '$PUBKEY']]" \
  --relay "$myRELAY"

#######################################################################
#######################################################################
# ADD TO FOLLOW LIST
#######################################################################
# Query existing event using strfry scan
cd $HOME/.zen/strfry
STRFRY_OUTPUT=$(./strfry scan '{"kinds":[3],"authors":["'$UMAPHEX'"]}' | head -n 1)
cd -
# EXISTING_EVENT was from nostpy-cli, now using output from strfry
EXISTING_EVENT="$STRFRY_OUTPUT"

# Initialize the new tags array
NEW_TAGS="[]"

# Check if an existing event was found
if [[ -n "$EXISTING_EVENT" ]]; then # Check if STRFRY_OUTPUT is not empty
    # Extract the existing tags using jq
    EXISTING_TAGS=$(echo "$EXISTING_EVENT" | jq -r '.tags')

    # Check if existing tags are null or empty string, if so treat as empty array
    if [[ -z "$EXISTING_TAGS" ]] || [[ "$EXISTING_TAGS" == "null" ]]; then
        NEW_TAGS="[['p', '$PUBKEY']]"
    else
        # Append the new 'p' tag to the existing tags using jq
        NEW_TAGS=$(echo "$EXISTING_TAGS" | jq -c '. + [["p", "'"$PUBKEY"'"]]')
    fi
else
    # If no existing event was found, create a new tags array with the new pubkey
    NEW_TAGS="[['p', '$PUBKEY']]"
fi

# Send the updated kind 3 event
# NOTE: If strfry's send_event is intended to interact with a relay, keep --relay "$myRELAY"
#       If strfry is only for local DB management and you need to send to a relay,
#       you might still need nostpy-cli send_event for relay interaction.
#       Assuming here that strfry's send_event is used to publish to relays.

nostpy-cli send_event \
    -privkey "$NPRIV_HEX" \
    -kind 3 \
    -content "" \
    -tags "$NEW_TAGS" \
    --relay "$myRELAY"

echo "updated follow list."

#######################################################################
echo ""
echo "--- Summary ---"
echo "PUBKEY: $PUBKEY"
echo "LAT: $LAT"
echo "LON: $LON"
echo "Message Text: $message_text"
echo "Image Description: $DESC"
echo "Ollama Answer: $ANSWER"

exit 0
