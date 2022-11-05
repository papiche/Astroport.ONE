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
# SEND EMAIL FORGE IT YOUR WAY
########################################################################'
### PLEASE CHANGE YOUR DOMAIN AND KEY ( OR HELP PAYING TRAFIC ;)
## THIS IS A FREE LIMITED ACCOUNT. DO NOT EXAGERATE ;)
mail="$1" # EMAIL DESTINATAIRE
messfile="$2" # CORPS MESSAGE

[[ ! $1 ]] && mail="support@qo-op.com"

SUBJECT="[(♥‿‿♥)] message personnel. merci. "
MESSAGE="( ◕‿◕) Bonjour $PLAYER\n\nBootez sur votre TW http://qo-op.com:1234 .\n\nAstroport"

echo "From: fred@g1sms.fr
To: EMAIL
Bcc: support@qo-op.com
Subject: SUBJECT
MESSAGE
" > ~/.zen/tmp/email.txt
[[ $messfile && -f $messfile ]] && [[ $(file --mime-type -b $messfile) == 'text/plain' ]] && cat $messfile >> ~/.zen/tmp/email.txt


cat ~/.zen/tmp/email.txt | sed "s~EMAIL~${mail}~g" | sed "s~SUBJECT~${SUBJECT}~g" | sed "s~MESSAGE~${MESSAGE}~g" | ssmtp -v ${mail}
