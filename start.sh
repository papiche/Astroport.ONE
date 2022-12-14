#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
myIP=$(hostname -I | awk '{print $1}' | head -n 1)
isLAN=$(echo $myIP | grep -E "/(^127\.)|(^192\.168\.)|(^10\.)|(^172\.1[6-9]\.)|(^172\.2[0-9]\.)|(^172\.3[0-1]\.)|(^::1$)|(^[fF][cCdD])/")
[[ ! $myIP || $isLAN ]] && myIP="ipfs.localhost"

ME="${0##*/}"
TS=$(date -u +%s%N | cut -b1-13)
MOATS=$(date -u +"%Y%m%d%H%M%S%4N")

echo "cron_VRFY.sh ON"
###################################################
${MY_PATH}/tools/cron_VRFY.sh ON

echo "(RE)STARTING 12345.sh"
###################################################
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid)
# killall "12345.sh"; killall "_12345.sh"; killall "nc"; killall "command.sh"
mkdir -p ~/.zen/tmp

exec ~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &
echo $! > ~/.zen/.pid && wait
