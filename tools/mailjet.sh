#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2022.10.28
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)

########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/my.sh"
ME="${0##*/}"

## LOG OUTPUT
exec 2>&1 >> ~/.zen/tmp/mailjet.log

echo '
########################################################################
# \\///
# qo-op
############# '$MY_PATH/$ME'
########################################################################'

# Parse command line arguments
EPHEMERAL_DURATION=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --expire)
            EPHEMERAL_DURATION="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [--expire DURATION] EMAIL MESSAGE_FILE SUBJECT [TW_INDEX]"
            echo ""
            echo "Options:"
            echo "  --expire DURATION    Make message ephemeral with duration (e.g., 1h, 1d, 1w, 3d)"
            echo "  --help, -h          Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 user@example.com message.html 'Subject'"
            echo "  $0 user@example.com message.html 'Subject' tw_index.html"
            echo "  $0 --expire 1h user@example.com message.html 'Ephemeral Subject'"
            echo "  $0 --expire 3d user@example.com message.html '3-day message' tw_index.html"
            echo ""
            echo "Duration formats:"
            echo "  s = seconds (e.g., 60s)"
            echo "  m = minutes (e.g., 30m)"
            echo "  h = hours (e.g., 2h)"
            echo "  d = days (e.g., 7d)"
            echo "  w = weeks (e.g., 2w)"
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

[[ ! $1 ]] \
    && echo "MISSING DESTINATION EMAIL" \
    && echo "Use --help for usage information" \
    && exit 1

mail="$1" # EMAIL DESTINATAIRE
############################################## SEARCH in players
$($MY_PATH/../tools/search_for_this_email_in_players.sh ${mail} | tail -n 1)
echo "ASTROPORT=$ASTROPORT
ASTROTW=$ASTRONAUTENS
ASTROG1=$ASTROG1
ASTROMAIL=$EMAIL
ASTROFEED=$FEEDNS
TW=$TW
source=$source"

############################################## SEARCH in NOSTR
echo "🔍 Searching for NOSTR profile for ${mail}..."
NOSTR_DATA=$($MY_PATH/search_for_this_email_in_nostr.sh ${mail} 2>/dev/null | tail -n 1)
if [[ -n "$NOSTR_DATA" ]]; then
    echo "✅ NOSTR profile found:"
    echo "$NOSTR_DATA"
    # Source the NOSTR data
    eval "$NOSTR_DATA"
    echo "NOSTR_HEX=$HEX"
    echo "NOSTR_NPUB=$NPUB"
    echo "NOSTR_RELAY=$RELAY"
else
    echo "❌ No NOSTR profile found for ${mail}"
    HEX=""
    NPUB=""
    RELAY=""
fi

## Is it UPlanet ORIGIN or Ẑen ?
[[ $UPLANETNAME != "EnfinLibre" ]] && UPLANET="UPlanet Ẑen ${UPLANETG1PUB:0:8}" || UPLANET="UPlanet ORIGIN"

#~ echo "DEST=$mail"
# mail=geg-la_debrouille@super.chez-moi.com
YUSER=$(echo ${mail} | cut -d '@' -f1)    # YUSER=geg-la_debrouille
LYUSER=($(echo "$YUSER" | sed 's/[^a-zA-Z0-9]/\ /g')) # LYUSER=(geg la debrouille)
CLYUSER=$(printf '%s\n' "${LYUSER[@]}" | tac | tr '\n' '.' ) # CLYUSER=debrouille.la.geg.
YOMAIN=$(echo ${mail} | cut -d '@' -f 2)    # YOMAIN=super.chez-moi.com
pseudo="${CLYUSER}${YOMAIN}.${myDOMAIN}"
#~ echo "PSEUDO=$pseudo"

messfile="$2" # FICHIER A AJOUTER AU CORPS MESSAGE

## add a tittle in message
title="$3"

# Function to convert human-readable duration to seconds
convert_duration_to_seconds() {
    local duration="$1"
    local seconds=0
    
    # Remove any whitespace
    duration=$(echo "$duration" | tr -d ' ')
    
    # Check if it's already a number (seconds) or has 's' suffix
    if [[ "$duration" =~ ^[0-9]+$ ]] || [[ "$duration" =~ ^[0-9]+s$ ]]; then
        # Remove 's' suffix if present
        duration=$(echo "$duration" | sed 's/s$//')
        echo "$duration"
        return
    fi
    
    # Parse duration with units
    if [[ "$duration" =~ ^([0-9]+)([smhdw])$ ]]; then
        local value="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2]}"
        
        case "$unit" in
            s) seconds=$((value)) ;;
            m) seconds=$((value * 60)) ;;
            h) seconds=$((value * 3600)) ;;
            d) seconds=$((value * 86400)) ;;
            w) seconds=$((value * 604800)) ;;
        esac
        
        echo "$seconds"
    else
        echo "0"
    fi
}

# Function to convert seconds back to human-readable format
convert_seconds_to_human() {
    local seconds="$1"
    local result=""
    
    # Weeks
    if [[ $seconds -ge 604800 ]]; then
        local weeks=$((seconds / 604800))
        result="${weeks}w"
        seconds=$((seconds % 604800))
    fi
    
    # Days
    if [[ $seconds -ge 86400 ]]; then
        local days=$((seconds / 86400))
        result="${result}${days}d"
        seconds=$((seconds % 86400))
    fi
    
    # Hours
    if [[ $seconds -ge 3600 ]]; then
        local hours=$((seconds / 3600))
        result="${result}${hours}h"
        seconds=$((seconds % 3600))
    fi
    
    # Minutes
    if [[ $seconds -ge 60 ]]; then
        local minutes=$((seconds / 60))
        result="${result}${minutes}m"
        seconds=$((seconds % 60))
    fi
    
    # Seconds
    if [[ $seconds -gt 0 ]]; then
        result="${result}${seconds}s"
    fi
    
    echo "$result"
}

# Convert ephemeral duration to seconds if provided
if [[ -n "$EPHEMERAL_DURATION" ]]; then
    ephemeral_duration=$(convert_duration_to_seconds "$EPHEMERAL_DURATION")
    if [[ "$ephemeral_duration" -eq 0 ]]; then
        echo "ERROR: Invalid duration format: $EPHEMERAL_DURATION"
        echo "Valid formats: 60s, 30m, 2h, 7d, 1w"
        exit 1
    fi
    echo "⏰ Ephemeral message duration: $EPHEMERAL_DURATION = ${ephemeral_duration}s"
else
    ephemeral_duration=""
fi

SUBJECT="[UPlanet] ${title}"

MESSAGESIGN="---<br>message sent by <a href='$(myIpfsGw)/ipns/$IPFSNODEID'>$(myHostName)</a> (Station Astroport.ONE)"

echo "
########################################################################
# $SUBJECT + $messfile -> $mail
########################################################################"

# + HTML in FILE
rm -f ~/.zen/tmp/email.txt
[[ -s $messfile ]] \
    && cat $messfile >> ~/.zen/tmp/email.txt \
    || echo "$messfile" >> ~/.zen/tmp/email.txt

EMAILZ=$(ipfs add -q ~/.zen/tmp/email.txt)
echo "/ipfs/${EMAILZ}"
ipfs pin rm ${EMAILZ}

################### IMPORT MAILJET INTO IF $4=TW
INDEX="$4"
if [[ -s ${INDEX} ]]; then
    echo "INSERT ZINE INTO TW"
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")
    mkdir -p ~/.zen/tmp/${MOATS}

    cat ${MY_PATH}/../templates/data/IFRAME.json \
    | sed -e "s~_MOATS_~${MOATS}~g" \
    -e "s~_TITLE_~/MAILJET/${SUBJECT^^}~g" \
    -e "s~_CID_~${EMAILZ}~g" \
    -e "s~_PLAYER_~${mail}~g" \
        > ~/.zen/tmp/iframe.json

    ### IMPORT INTO TW
    tiddlywiki --load ${INDEX} \
                --import ~/.zen/tmp/iframe.json "application/json" \
                --output ~/.zen/tmp/${MOATS} --render "$:/core/save/all" "newindex.html" "text/plain"

    if [[ -s ~/.zen/tmp/${MOATS}/newindex.html ]]; then

        [[ $(diff ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} ) ]] \
            && mv ~/.zen/tmp/${MOATS}/newindex.html ${INDEX} \
            && echo "===> Mise à jour ${INDEX}"

    else
        echo "Problem with tiddlywiki command. Missing ~/.zen/tmp/${MOATS}/newindex.html"
        echo "XXXXXXXXXXXXXXXXXXXXXXX"
    fi

fi

export TEXTPART="$(myIpfsGw)/ipfs/${EMAILZ}"

[[ $title == "" ]] && title="MESSAGE"

############# GETTING MAILJET API ############### from ~/.zen/MJ_APIKEY
if [[ -s ~/.zen/MJ_APIKEY ]]; then
## LOAD SENDER API KEYS
source ~/.zen/MJ_APIKEY
export RECIPIENT_EMAIL=${mail}

json_payload='{
    "Messages": [
        {
            "From": {
                "Email": "'${SENDER_EMAIL}'",
                "Name": "UPlanet Keeper"
            },
            "To": [
                {
                    "Email": "'${RECIPIENT_EMAIL}'",
                    "Name": "'${pseudo}' Astronaut"
                }
            ],
            "Bcc": [
                {
                    "Email": "'${SENDER_EMAIL}'",
                    "Name": "SUPPORT"
                }
            ],
            "Subject": "'${SUBJECT}'",
            "TextPart": "'$(myIpfsGw)/ipfs/${EMAILZ}'",
            "HTMLPart": "<h1>Bro</h1><h3><a href=\"'${myIPFS}'/ipfs/'${EMAILZ}'\">'${title}'</a></h3><br>/ipfs/'${EMAILZ}'<br><a href=\"'${uSPOT}'/scan\">'${UPLANET}'</a> [ /ipns/'${pseudo}' ]<br /><br>'${MESSAGESIGN}'"
        }
    ]
}'
echo "$json_payload"
# Verify the JSON structure with jq
echo "$json_payload" | jq .
# Run:
# POSSIBLE ! "HTMLPart": "<h3>You have a message <br><a href=\"https://qo-op.com/\">UPlanet</a>!</h3><br />May the good vibes be with you!"
curl -s \
    -X POST \
    --user "${MJ_APIKEY_PUBLIC}:${MJ_APIKEY_PRIVATE}" \
    https://api.mailjet.com/v3.1/send \
    -H 'Content-Type: application/json' \
    -d "$json_payload"

fi


############################################## SEND NOSTR PUBLIC NOTE (Kind 1)
# Try to use destination's NSEC if available, otherwise use captain's NSEC
SENDER_NSEC=""
SENDER_IDENTITY=""
DEST_EMAIL="${mail}"

# First, try to load destination's NOSTR keys
NOSTR_KEYFILE=""
if [[ -s "$HOME/.zen/game/nostr/${DEST_EMAIL}/.secret.nostr" ]]; then
    echo "🔑 Found destination's NOSTR key for ${DEST_EMAIL}"
    NOSTR_KEYFILE="$HOME/.zen/game/nostr/${DEST_EMAIL}/.secret.nostr"
    source "$NOSTR_KEYFILE"
    SENDER_NSEC="$NSEC"
    SENDER_IDENTITY="${DEST_EMAIL}"
    echo "👤 Using destination's NOSTR key: ${NSEC:0:20}..."
elif [[ -n "$CAPTAINEMAIL" && -s "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr" ]]; then
    echo "🔑 Destination's key not found, using captain's key"
    NOSTR_KEYFILE="$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
    source "$NOSTR_KEYFILE"
    SENDER_NSEC="$NSEC"
    SENDER_IDENTITY="${CAPTAINEMAIL} (Captain)"
    echo "👨‍✈️ Using captain's NOSTR key: ${NSEC:0:20}..."
fi

if [[ -n "$SENDER_NSEC" && -n "$NOSTR_KEYFILE" ]]; then
    echo "📝 Preparing NOSTR public note (kind 1)..."
    
    # Prepare NOSTR message content
    NOSTR_MESSAGE="📄 : ${SUBJECT}

${TEXTPART}

---
${HEX:+📱 NOSTR: ${NPUB}}
${RELAY:+🌐 Relay: ${myRELAY}}
${ephemeral_duration:+⏰ $(convert_seconds_to_human ${ephemeral_duration})}
"

    # Discover preferred relays for recipient
    PREFERRED_RELAYS=()
    if [[ -n "$HEX" ]]; then
        echo "🔍 Fetching preferred relays for recipient ${HEX:0:16}..."
        # Query default relay first to find user's relay list
        QUERY_RELAY="${RELAY:-$myRELAY}"
        RELAY_LIST=$(python3 $MY_PATH/nostr_get_relays.py "${HEX}" "${QUERY_RELAY}" 2>/dev/null)
        
        if [[ $? -eq 0 && -n "$RELAY_LIST" ]]; then
            # Convert to array
            readarray -t PREFERRED_RELAYS <<< "$RELAY_LIST"
            echo "✅ Found ${#PREFERRED_RELAYS[@]} preferred relay(s):"
            for r in "${PREFERRED_RELAYS[@]}"; do
                echo "   - $r"
            done
        else
            echo "ℹ️ No preferred relays found, using defaults"
        fi
    fi
    
    # Determine which relays to use
    if [[ ${#PREFERRED_RELAYS[@]} -gt 0 ]]; then
        # Use recipient's preferred relays
        TARGET_RELAYS=("${PREFERRED_RELAYS[@]}")
    else
        # Fallback to known relay or default
        TARGET_RELAYS=("${RELAY:-$myRELAY}")
    fi
    
    # Prepare tags (reference recipient if we have their HEX)
    TAGS_JSON="[]"
    if [[ -n "$HEX" ]]; then
        TAGS_JSON="[[\"p\",\"${HEX}\"]]"
        echo "🏷️ Adding tag for recipient: ${HEX}"
    fi
    
    # Send NOSTR public note to all relays at once (new unified API)
    SUCCESS_COUNT=0
    
    # Convert array to comma-separated string for multi-relay support
    RELAY_LIST=$(IFS=,; echo "${TARGET_RELAYS[*]}")
    
    echo "🚀 Sending public note via NOSTR to ${#TARGET_RELAYS[@]} relay(s)..."
    
    # Check if keyfile exists
    if [[ ! -s "$NOSTR_KEYFILE" ]]; then
        echo "❌ NOSTR keyfile not found: $NOSTR_KEYFILE"
        SUCCESS_COUNT=0
    else
        # Build command arguments array to avoid quoting issues
        NOSTR_ARGS=(
            "python3"
            "$MY_PATH/nostr_send_note.py"
            "--keyfile" "$NOSTR_KEYFILE"
            "--content" "$NOSTR_MESSAGE"
            "--tags" "$TAGS_JSON"
            "--relays" "$RELAY_LIST"
        )
    
    # Add ephemeral flag if set
    if [[ -n "$ephemeral_duration" ]]; then
        echo "⏰ Sending ephemeral message (duration: ${ephemeral_duration}s)"
            NOSTR_ARGS+=("--ephemeral" "$ephemeral_duration")
    fi
    
    # Add JSON output for parsing
        NOSTR_ARGS+=("--json")
    
        # Execute command and capture both stdout and stderr
        RESULT=$("${NOSTR_ARGS[@]}" 2>&1)
        NOSTR_EXIT_CODE=$?
    
        if [[ $NOSTR_EXIT_CODE -eq 0 && -n "$RESULT" ]]; then
            # Extract JSON from output (may contain debug messages before JSON)
            # Find the line number where JSON starts (first line with {)
            JSON_START=$(echo "$RESULT" | grep -n '^{' | head -n 1 | cut -d: -f1)
            
            if [[ -n "$JSON_START" ]]; then
                # Extract from JSON start line to end of output
                JSON_OUTPUT=$(echo "$RESULT" | tail -n +${JSON_START})
            else
                # Fallback: try to extract JSON object on single line
                JSON_OUTPUT=$(echo "$RESULT" | grep -o '{.*}' | tail -n 1)
                
                # If still no JSON found, try last line
                if [[ -z "$JSON_OUTPUT" ]]; then
                    JSON_OUTPUT=$(echo "$RESULT" | tail -n 1 | grep -E '^\{.*\}$')
                fi
            fi
            
            # Try to parse JSON result using jq if available, otherwise use grep
            if command -v jq >/dev/null 2>&1 && [[ -n "$JSON_OUTPUT" ]]; then
                SUCCESS_COUNT=$(echo "$JSON_OUTPUT" | jq -r '.relays_success // 0' 2>/dev/null || echo "0")
                TOTAL_COUNT=$(echo "$JSON_OUTPUT" | jq -r '.relays_total // 0' 2>/dev/null || echo "${#TARGET_RELAYS[@]}")
                EVENT_ID=$(echo "$JSON_OUTPUT" | jq -r '.event_id // ""' 2>/dev/null || echo "")
                SUCCESS=$(echo "$JSON_OUTPUT" | jq -r '.success // false' 2>/dev/null || echo "false")
            else
                # Fallback to grep parsing from RESULT (if JSON_OUTPUT extraction failed)
                # Try to find JSON in RESULT
                if [[ -z "$JSON_OUTPUT" ]]; then
                    JSON_OUTPUT=$(echo "$RESULT" | grep -o '{.*}' | tail -n 1)
                fi
                
                if [[ -n "$JSON_OUTPUT" ]] && command -v jq >/dev/null 2>&1; then
                    # Try jq on extracted JSON
                    SUCCESS_COUNT=$(echo "$JSON_OUTPUT" | jq -r '.relays_success // 0' 2>/dev/null || echo "0")
                    TOTAL_COUNT=$(echo "$JSON_OUTPUT" | jq -r '.relays_total // 0' 2>/dev/null || echo "${#TARGET_RELAYS[@]}")
                    EVENT_ID=$(echo "$JSON_OUTPUT" | jq -r '.event_id // ""' 2>/dev/null || echo "")
                    SUCCESS=$(echo "$JSON_OUTPUT" | jq -r '.success // false' 2>/dev/null || echo "false")
                else
                    # Final fallback: grep parsing
                    SUCCESS_COUNT=$(echo "$RESULT" | grep -o '"relays_success":[[:space:]]*[0-9]*' | grep -o '[0-9]*' || echo "0")
                    TOTAL_COUNT=$(echo "$RESULT" | grep -o '"relays_total":[[:space:]]*[0-9]*' | grep -o '[0-9]*' || echo "${#TARGET_RELAYS[@]}")
                    EVENT_ID=$(echo "$RESULT" | grep -o '"event_id":[[:space:]]*"[^"]*"' | grep -o '[a-f0-9]\{64\}' | head -n 1 || echo "")
                    SUCCESS=$(echo "$RESULT" | grep -o '"success":[[:space:]]*true' >/dev/null && echo "true" || echo "false")
                fi
            fi
            
            if [[ -n "$EVENT_ID" && "$EVENT_ID" != "null" ]]; then
                echo "   📝 Event ID: ${EVENT_ID:0:16}..."
            fi
            
            # Check success based on JSON values
            # SUCCESS_COUNT should be > 0, or SUCCESS should be true
            if [[ "$SUCCESS_COUNT" =~ ^[0-9]+$ ]] && [[ $SUCCESS_COUNT -gt 0 ]]; then
                echo "   ✅ Published successfully to ${SUCCESS_COUNT}/${TOTAL_COUNT} relay(s)"
            elif [[ "$SUCCESS" == "true" ]]; then
                echo "   ✅ Published successfully (confirmed by success flag)"
                SUCCESS_COUNT=1
            else
                echo "   ❌ Failed to publish to any relay"
                echo "   📋 Response: $RESULT"
                SUCCESS_COUNT=0
            fi
    else
            echo "   ❌ NOSTR command failed (exit code: ${NOSTR_EXIT_CODE})"
            echo "   📋 Error output: $RESULT"
        SUCCESS_COUNT=0
        fi
    fi
    
    if [[ $SUCCESS_COUNT -gt 0 ]]; then
        echo "✅ NOSTR note published successfully to ${SUCCESS_COUNT}/${#TARGET_RELAYS[@]} relay(s)"
    else
        echo "❌ Failed to publish NOSTR note to any relay"
    fi
else
    echo "⚠️ No NOSTR keys found - skipping NOSTR notification"
    echo "💡 Ensure either:"
    echo "    - $HOME/.zen/game/nostr/${DEST_EMAIL}/.secret.nostr (destination)"
    echo "    - $HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr (captain)"
fi


# This call sends an email to one recipient.
#~ TEXTPART=$(cat ~/.zen/tmp/email.txt | sed ':a;N;$!ba;s/\n/\\n/g' | tr '"' '\\\"')
#~ HTMLPART=$(cat ~/.zen/tmp/email.txt | sed ':a;N;$!ba;s/\n/<br>/g' | tr '"' '\\\"')
#~ curl -s \
    #~ -X POST \
    #~ --user "$MJ_APIKEY_PUBLIC:$MJ_APIKEY_PRIVATE" \
    #~ https://api.mailjet.com/v3/send \
    #~ -H 'Content-Type: application/json' \
    #~ -d '{
        #~ "FromEmail":"'${SENDER_EMAIL}'",
        #~ "FromName":"UPlanet Support Team",
        #~ "Subject":"Message from Astroport",
        #~ "Text-part":"'${TEXTPART}'",
        #~ "Html-part":"'${HTMLPART}'",
        #~ "Recipients":[{"Email":"'${RECIPIENT_EMAIL}'"}]
    #~ }'
