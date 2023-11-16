#!/bin/bash
########################################################################
# Version: 0.4
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
# ON LINE echo script! LAST LINE export VARIABLE values
########################################################################
MY_PATH="`dirname \"$0\"`"              # relative
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
ME="${0##*/}"

. "${MY_PATH}/my.sh"
### USE 12345 MAP
## EXPLORE SWARM BOOTSTRAP REPLICATED TW CACHE

    start=`date +%s`
    MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

G1DEST="$1"
COMMENT="$2"

# ${MY_PATH}/jaklis/jaklis.py history -p $G1DEST  -n 10 -j
# THIS SCRIPT IS LAUNCHED AFTER A PAYMENT IS DONE
# IT WILL VERIFY IN HISTORY "ASTROID:MOATS" APPEARING

# ELSE IT SENDS A MESSAGE TO PLAYER
## OR COULD TRY AGAIN

echo "export DEST=$DEST COMMENT=$COMMENT ASTROMAIL=$EMAIL ASTROFEED=$FEEDNS"
exit 0
