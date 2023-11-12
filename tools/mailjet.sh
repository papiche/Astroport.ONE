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
[[ ! $1 ]] && mail="fred@g1sms.fr"

messfile="$2" # FICHIER A AJOUTER AU CORPS MESSAGE

SUBJECT="[(♥‿‿♥)] Station Astroport : $(myHostName)"
MESSAGE="( ◕‿◕)\n\n Bonjour $PLAYER\n\n UN MESSAGE POUR VOUS.\n\nAstroport\n/ipns/$IPFSNODEID"

echo "
########################################################################
# $SUBJECT + $messfile -> $mail
########################################################################"


echo "From: support@g1sms.fr
To: EMAIL
Bcc: fred@g1sms.fr
Subject: SUBJECT
MESSAGE
" > ~/.zen/tmp/email.txt

[[ -s $messfile ]] && cat $messfile >> ~/.zen/tmp/email.txt \
|| echo "$messfile" >> ~/.zen/tmp/email.txt


cat ~/.zen/tmp/email.txt | sed "s~EMAIL~${mail}~g" | sed "s~SUBJECT~${SUBJECT}~g" | sed "s~MESSAGE~${MESSAGE}~g" | /usr/sbin/ssmtp ${mail}
