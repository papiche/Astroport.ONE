#!/bin/bash
########################################################################
# Author: Fred (support@qo-op.com)
# Version: 2022.10.28
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"
echo '
########################################################################
# \\///
# qo-op
############# '$MY_PATH/$ME'
########################################################################
# SEND EMAIL $1=SUBJECT $2=TXT $3=HTML $4=DEST
########################################################################'
### PLEASE CHANGE YOUR DOMAIN AND KEY ( OR HELP PAYING TRAFIC ;)
## THIS IS A FREE LIMITED ACCOUNT. DO NOT EXAGERATE ;)
MJ_APIKEY_PUBLIC='fbcd95c1b3d08a67dad0988193ca0795'
MJ_APIKEY_PRIVATE='367a3a753546134eeac030d5bf6e41f0'

SENDER_EMAIL='support@qo-op.com'

RECIPIENT_EMAIL="$4"
[[ ! $RECIPIENT_EMAIL ]] && RECIPIENT_EMAIL='support@qo-op.com'



## NOT WORKING !!! HOW TO MAKE THE RIGHT JSON : TODO
echo '{"Messages":[
                {
                        "From": {
                                "Email": "'$SENDER_EMAIL'",
                                "Name": "qo-op"
                        },
                        "To": [
                                {
                                        "Email": "'$RECIPIENT_EMAIL'",
                                        "Name": "Astroport"
                                }
                        ],
                        "Subject": "'$1'",
                        "TextPart": "'$2'",
                        "HTMLPart": "'$3'"
                }
        ]
    }'

echo "THIS SCRIPT NEED DEBUGGING"
exit 1

# Run:
curl -s -X POST \
    --user "$MJ_APIKEY_PUBLIC:$MJ_APIKEY_PRIVATE" \
    https://api.mailjet.com/v3.1/send \
    -H 'Content-Type: application/json' \
    -d '{"Messages":[
                {
                        "From": {
                                "Email": "'$SENDER_EMAIL'",
                                "Name": "qo-op"
                        },
                        "To": [
                                {
                                        "Email": "'$RECIPIENT_EMAIL'",
                                        "Name": "Astroport"
                                }
                        ],
                        "Subject": "'$1'",
                        "TextPart": "'$2'",
                        "HTMLPart": "'$3'"
                }
        ]
    }' | jq -r


