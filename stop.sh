#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

echo "ASTROPORT.ONE STOP
@@@@@@@@@@@@@@@@@@
$USER@$HOSTNAME
@@@@@@@@@@@@@@@@@@"
echo
echo "astroport stop"
sudo systemctl stop astroport
echo "g1billet stop"
sudo systemctl stop g1billet
echo "ipfs stop"
sudo systemctl stop ipfs

echo "STOPPING PROCESS & CRON"
###################################################
killall 12345.sh; killall "_12345.sh"; killall nc
###################################################
${MY_PATH}/tools/cron_VRFY.sh OFF

exit 0
