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
[[ ! $1 ]] \
    && echo "MISSING DESTINATION EMAIL" \
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
[[ ! -s ~/.zen/MJ_APIKEY ]] \
    && echo "MISSING ~/.zen/MJ_APIKEY
    PLEASE PROVIDE MAILJET KEY : MJ_APIKEY_PUBLIC= & MJ_APIKEY_PRIVATE" \
    && exit 1

## LOAD SENDER API KEYS
###################################
######### ~/.zen/MJ_APIKEY contains
# export MJ_APIKEY_PUBLIC='publickey'
# export MJ_APIKEY_PRIVATE='privatekey'
# export SENDER_EMAIL='me@source.tld'
###################################
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

############################################## SEND NOSTR DM
if [[ -n "$HEX" && -n "$NPUB" ]]; then
    echo "📨 Sending NOSTR direct message to ${NPUB}..."
    
    # Prepare NOSTR message content
    NOSTR_MESSAGE="🔔 ${SUBJECT}

📧 Email: ${mail}
📱 NOSTR: ${NPUB}
🌐 Relay: ${RELAY}

📄 Message: ${TEXTPART}

${MESSAGESIGN}"

    # Get captain's NSEC from $HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr
    SENDER_NSEC=""
    if [[ -n "$CAPTAINEMAIL" && -s "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr" ]]; then
        # Source the captain's NOSTR keys
        source "$HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr"
        SENDER_NSEC="$NSEC"
        echo "👨‍✈️ Using captain's NOSTR key: ${NSEC:0:20}..."
    fi
    
    if [[ -n "$SENDER_NSEC" ]]; then
        # Use the relay from NOSTR data or default
        NOSTR_RELAY="${RELAY:-$myRELAY}"
        
        # Send NOSTR DM
        echo "🚀 Sending via NOSTR to ${HEX} on ${NOSTR_RELAY}..."
        python3 $MY_PATH/nostr_send_dm.py "${SENDER_NSEC}" "${HEX}" "${NOSTR_MESSAGE}" "${NOSTR_RELAY}"
        
        if [[ $? -eq 0 ]]; then
            echo "✅ NOSTR message sent successfully"
        else
            echo "❌ Failed to send NOSTR message"
        fi
    else
        echo "⚠️ No captain's NSEC found - skipping NOSTR DM"
        echo "💡 Ensure $HOME/.zen/game/nostr/$CAPTAINEMAIL/.secret.nostr exists with captain's NOSTR keys"
    fi
else
    echo "ℹ️ No NOSTR profile found - email only"
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
