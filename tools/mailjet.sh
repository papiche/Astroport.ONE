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

pseudo=$(echo $mail | cut -d '@' -f 1)

messfile="$2" # FICHIER A AJOUTER AU CORPS MESSAGE

SUBJECT="[UPlanet/Astroport] $pseudo : $(myHostName)"
MESSAGE="Bonjour $PLAYER
UN MESSAGE POUR VOUS.

Astroport
/ipns/$IPFSNODEID
"

echo "
########################################################################
# $SUBJECT + $messfile -> $mail
########################################################################"

### SMTP RELAY
#~ echo "From: support@g1sms.fr
#~ To: EMAIL
#~ Bcc: support@qo-op.com
#~ Subject: SUBJECT
#~ $MESSAGE
#~ " > ~/.zen/tmp/email.txt

#~ [[ -s $messfile ]] && cat $messfile >> ~/.zen/tmp/email.txt \
#~ || echo "$messfile" >> ~/.zen/tmp/email.txt

#~ cat ~/.zen/tmp/email.txt | sed "s~EMAIL~${mail}~g" | sed "s~SUBJECT~${SUBJECT}~g" | /usr/sbin/ssmtp ${mail}

############# USING MAILJET API ###############

export MJ_APIKEY_PUBLIC='02b075c3f28b9797d406f0ca015ca984'
export MJ_APIKEY_PRIVATE='58256ba8ea62f68965879f53bbb29f90'
export SENDER_EMAIL='support@g1sms.fr'
export RECIPIENT_EMAIL=${mail}

# MESSAGE HEADER
echo "$MESSAGE" > ~/.zen/tmp/email.txt

# + HTML in FILE
[[ -s $messfile ]] && cat $messfile >> ~/.zen/tmp/email.txt \
|| echo "$messfile" >> ~/.zen/tmp/email.txt

EMAILZ=$(ipfs add -q ~/.zen/tmp/email.txt)
echo "/ipfs/${EMAILZ}"

TEXTPART=$(cat ~/.zen/tmp/email.txt | sed ':a;N;$!ba;s/\n/\\n/g' | tr '"' '\\\"')
HTMLPART=$(cat ~/.zen/tmp/email.txt | sed ':a;N;$!ba;s/\n/<br>/g' | tr '"' '\\\"')

export TEXTPART="${myIPFS}/ipfs/${EMAILZ}"

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
                    "Name": "Astronaut"
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
            "HTMLPart": "<h3>You have a <br><a href=\"'$(myIpfsGw)'/ipfs/'${EMAILZ}'\">MESSAGE</a>!</h3><br />May the good vibes be with you!<br>Astroport UPlanet"
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
