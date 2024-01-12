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

echo '
########################################################################
# \\///
# qo-op
############# '$MY_PATH/$ME'
########################################################################'
### PLEASE CHANGE YOUR DOMAIN AND KEY ( OR HELP PAYING TRAFIC ;)
## THIS IS A FREE LIMITED ACCOUNT. DO NOT EXAGERATE ;)
mail="$1" # EMAIL DESTINATAIRE
[[ ! $1 ]] && mail="support@qo-op.com"

# mail=geg-la_debrouille@super.chez-moi.com
YUSER=$(echo ${mail} | cut -d '@' -f1)    # YUSER=geg-la_debrouille
LYUSER=($(echo "$YUSER" | sed 's/[^a-zA-Z0-9]/\ /g')) # LYUSER=(geg la debrouille)
CLYUSER=$(printf '%s\n' "${LYUSER[@]}" | tac | tr '\n' '.' ) # CLYUSER=debrouille.la.geg.
YOMAIN=$(echo ${mail} | cut -d '@' -f 2)    # YOMAIN=super.chez-moi.com
pseudo="${CLYUSER}_${YOMAIN}"

messfile="$2" # FICHIER A AJOUTER AU CORPS MESSAGEUP

## add a tittle in message
title="$3"

SUBJECT="[UPlanet] ${title} ${pseudo} : $(myHostName)"

MESSAGESIGN="---<br>this message is relayed to you by <a href=$(myIpfsGw)/ipns/$IPFSNODEID>$(myHostName)</a> ♥BOX Astroport.ONE Station"

echo "
########################################################################
# $SUBJECT + $messfile -> $mail
########################################################################"

### SMTP RELAY
#~ echo "From: support@g1sms.fr
#~ To: EMAIL
#~ Bcc: support@qo-op.com
#~ Subject: SUBJECT
#~ $MESSAGEUP
#~ " > ~/.zen/tmp/email.txt

#~ [[ -s $messfile ]] && cat $messfile >> ~/.zen/tmp/email.txt \
#~ || echo "$messfile" >> ~/.zen/tmp/email.txt

#~ cat ~/.zen/tmp/email.txt | sed "s~EMAIL~${mail}~g" | sed "s~SUBJECT~${SUBJECT}~g" | /usr/sbin/ssmtp ${mail}

############# USING MAILJET API ###############

export MJ_APIKEY_PUBLIC='02b075c3f28b9797d406f0ca015ca984'
export MJ_APIKEY_PRIVATE='58256ba8ea62f68965879f53bbb29f90'
export SENDER_EMAIL='support@g1sms.fr'
export RECIPIENT_EMAIL=${mail}


# + HTML in FILE
rm -f ~/.zen/tmp/email.txt
[[ -s $messfile ]] && cat $messfile >> ~/.zen/tmp/email.txt \
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
                "Name": "UPlanet"
            },
            "To": [
                {
                    "Email": "'${RECIPIENT_EMAIL}'",
                    "Name": "'${pseudo}' Astronaut"
                }
            ],
            "Bcc": [
                {
                    "Email": "support@g1sms.fr",
                    "Name": "SUPPORT"
                }
            ],
            "Subject": "'${SUBJECT}'",
            "TextPart": "'$(myIpfsGw)/ipfs/${EMAILZ}'",
            "HTMLPart": "<h1>Bro</h1><h3>You have a <br><a href=\"'$(myIpfsGw)'/ipfs/'${EMAILZ}'\">'${title}'</a>!</h3> on UPlanet<br />May the good vibes be with you!<br>'${MESSAGESIGN}'"
        }
    ]
}'

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
