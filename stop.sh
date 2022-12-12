#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "ASTROPORT.ONE $USER@$HOSTNAME
@@@@@@@@@@@@@@@@@@
STOP AT $MOATS
@@@@@@@@@@@@@@@@@@"
echo

echo "STOPPING PROCESS & CRON"
###################################################
killall 12345.sh; killall "_12345.sh"; killall nc
###################################################
${MY_PATH}/tools/cron_VRFY.sh OFF

exit 0
