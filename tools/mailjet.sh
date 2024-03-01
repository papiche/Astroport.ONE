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

#~ echo "DEST=$mail"
# mail=geg-la_debrouille@super.chez-moi.com
YUSER=$(echo ${mail} | cut -d '@' -f1)    # YUSER=geg-la_debrouille
LYUSER=($(echo "$YUSER" | sed 's/[^a-zA-Z0-9]/\ /g')) # LYUSER=(geg la debrouille)
CLYUSER=$(printf '%s\n' "${LYUSER[@]}" | tac | tr '\n' '.' ) # CLYUSER=debrouille.la.geg.
YOMAIN=$(echo ${mail} | cut -d '@' -f 2)    # YOMAIN=super.chez-moi.com
pseudo="${CLYUSER}${YOMAIN}.${myDOMAIN}"
#~ echo "PSEUDO=$pseudo"

messfile="$2" # FICHIER A AJOUTER AU CORPS MESSAGEUP

## add a tittle in message
title="$3"

SUBJECT="[UPlanet] ${title} ${pseudo}"

MESSAGESIGN="---<br>this message is sent to you by <a href='$(myIpfsGw)/ipns/$IPFSNODEID'>$(myHostName)</a> your ♥BOX Astroport.ONE Station"

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

export TEXTPART="$(myIpfsGw)/ipfs/${EMAILZ}"

[[ $title == "" ]] && title="MESSAGE"

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
            "HTMLPart": "<h1>Bro</h1><h3>You have a <br><a href=\"'$(myIpfsGw)'/ipfs/'${EMAILZ}'\">'${title}'</a>!</h3> on <a href=\"https://qo-op.com\">UPlanet</a><br />May the good vibes be with you!<br>'${MESSAGESIGN}'"
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
