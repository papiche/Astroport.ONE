#!/bin/bash
################################################################################
# Author: Fred (support@qo-op.com)
# Version: 0.1
# License: AGPL-3.0 (https://choosealicense.com/licenses/agpl-3.0/)
################################################################################
MY_PATH="`dirname \"$0\"`"
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
. "$MY_PATH/tools/my.sh"

TS=$(date -u +%s%N | cut -b1-13)

echo "cron_VRFY.sh ON"
###################################################
${MY_PATH}/tools/cron_VRFY.sh ON

echo "(RE)STARTING 12345.sh"
###################################################
[[ -s ~/.zen/.pid ]] && kill -9 $(cat ~/.zen/.pid) \
                                 || ( killall "12345.sh"; killall "_12345.sh"; killall "nc" )

mkdir -p ~/.zen/tmp

~/.zen/Astroport.ONE/12345.sh > ~/.zen/tmp/12345.log &
echo $! > ~/.zen/.pid
